#include "video_core.hpp"
#include <rm_common/logger.hpp>
#include <cerrno>
#ifdef _WIN32
#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif
#include <winsock2.h>
#include <ws2tcpip.h>
#include <windows.h>
#else
#include <arpa/inet.h>
#include <netinet/in.h>
#include <sys/socket.h>
#include <unistd.h>
using SOCKET = int;
#endif
#include <cstring>
#include <string>

namespace RMVideoDecoder {

namespace {
constexpr std::string_view kLogTag = "rm_video_decoder.VideoCore";

#ifdef _WIN32
std::string socketErrorMessage(int errorCode = WSAGetLastError()) {
    wchar_t* message = nullptr;
    const DWORD flags = FORMAT_MESSAGE_ALLOCATE_BUFFER | FORMAT_MESSAGE_FROM_SYSTEM | FORMAT_MESSAGE_IGNORE_INSERTS;
    const DWORD len = FormatMessageW(flags, nullptr, static_cast<DWORD>(errorCode), 0, reinterpret_cast<wchar_t*>(&message), 0, nullptr);
    std::string result;
    if (len > 0 && message) {
        const int utf8_len = WideCharToMultiByte(CP_UTF8, 0, message, static_cast<int>(len), nullptr, 0, nullptr, nullptr);
        if (utf8_len > 0) {
            result.resize(static_cast<size_t>(utf8_len));
            WideCharToMultiByte(CP_UTF8, 0, message, static_cast<int>(len), result.data(), utf8_len, nullptr, nullptr);
        }
    }
    if (result.empty()) {
        result = "Winsock error " + std::to_string(errorCode);
    }
    if (message) {
        LocalFree(message);
    }
    while (!result.empty() && (result.back() == '\r' || result.back() == '\n')) {
        result.pop_back();
    }
    return result;
}

bool startWinsock() {
    WSADATA data{};
    const int ret = WSAStartup(MAKEWORD(2, 2), &data);
    if (ret != 0) {
        RM_LOGE(kLogTag, "WSAStartup failed: %s", socketErrorMessage(ret).c_str());
        return false;
    }
    return true;
}

void closeSocket(SocketHandle& socket) {
    if (socket != kInvalidSocket) {
        closesocket(static_cast<SOCKET>(socket));
        socket = kInvalidSocket;
    }
}

bool isRecvTimeoutError() {
    const int err = WSAGetLastError();
    return err == WSAETIMEDOUT || err == WSAEWOULDBLOCK;
}

std::string lastSocketErrorMessage() {
    return socketErrorMessage();
}
#else
void closeSocket(SocketHandle& socket) {
    if (socket != kInvalidSocket) {
        close(socket);
        socket = kInvalidSocket;
    }
}

bool isRecvTimeoutError() {
    return errno == EAGAIN || errno == EWOULDBLOCK;
}

std::string lastSocketErrorMessage() {
    return std::strerror(errno);
}
#endif

struct ParsedPacketHeader {
    uint16_t frame_seq = 0;
    uint16_t fragment_seq = 0;
    uint32_t total_size = 0;
};

bool parsePacketHeader(const uint8_t* buffer, size_t len, uint32_t maxFrameBytes, ParsedPacketHeader& out) {
    if (len < sizeof(VideoPacketHeader)) return false;

    uint16_t frameSeqBe = 0;
    uint16_t fragSeqBe = 0;
    uint32_t totalSizeBe = 0;

    std::memcpy(&frameSeqBe, buffer, sizeof(frameSeqBe));
    std::memcpy(&fragSeqBe, buffer + sizeof(frameSeqBe), sizeof(fragSeqBe));
    std::memcpy(&totalSizeBe, buffer + sizeof(frameSeqBe) + sizeof(fragSeqBe), sizeof(totalSizeBe));

    const ParsedPacketHeader netOrder{
        ntohs(frameSeqBe),
        ntohs(fragSeqBe),
        ntohl(totalSizeBe),
    };

    const ParsedPacketHeader hostOrder{
        frameSeqBe,
        fragSeqBe,
        totalSizeBe,
    };

    const auto plausible = [&](const ParsedPacketHeader& h) {
        return h.total_size > 0 && h.total_size <= maxFrameBytes;
    };

    if (plausible(netOrder)) {
        out = netOrder;
        return true;
    }
    if (plausible(hostOrder)) {
        out = hostOrder;
        return true;
    }
    out = netOrder;
    return true;
}
} // namespace

//  =============== FFmpegContext ===============

bool VideoCore::FFmpegContext::init(AVCodecID codec_id) {
    codec = avcodec_find_decoder(codec_id);
    if (!codec) {
        RM_LOGE(kLogTag, "Decoder not found.");
        return false;
    }

    codec_ctx = avcodec_alloc_context3(codec);
    if (!codec_ctx) {
        RM_LOGE(kLogTag, "Failed to allocate codec context.");
        return false;
    }
    if (avcodec_open2(codec_ctx, codec, nullptr) < 0) {
        RM_LOGE(kLogTag, "Failed to open codec.");
        avcodec_free_context(&codec_ctx);
        return false;
    }

    avPacket_ = av_packet_alloc();
    if (!avPacket_) {
        RM_LOGE(kLogTag, "Failed to allocate AVPacket.");
        avcodec_free_context(&codec_ctx);
        return false;
    }

    return true;
}

VideoCore::FFmpegContext::~FFmpegContext() {
    if (codec_ctx) {
        avcodec_free_context(&codec_ctx);
        codec_ctx = nullptr;
    }
    if (avPacket_) {
        av_packet_free(&avPacket_);
        avPacket_ = nullptr;
    }
}


// =============== TripleBuffer ===============

bool VideoCore::TripleBuffer::init() {
    for (int i = 0; i < 3; ++i) {
        buffers[i] = av_frame_alloc();
        if (!buffers[i]) {
            RM_LOGE(kLogTag, "Failed to allocate AVFrame for TripleBuffer.");
            return false;
        }
    }
    return true;
}

VideoCore::TripleBuffer::~TripleBuffer() {
    for (int i = 0; i < 3; ++i) {
        if (buffers[i]) {
            av_frame_free(&buffers[i]);
            buffers[i] = nullptr;
        }
    }
}

AVFrame* VideoCore::TripleBuffer::getWriteBuffer() {
    AVFrame* frame = buffers[write_index];
    av_frame_unref(frame); 
    return buffers[write_index];
}

std::pair<AVFrame*, bool> VideoCore::TripleBuffer::getReadBuffer() {
    std::lock_guard<std::mutex> lock(mutex_);
    if (!has_new_frame) {
        return {buffers[read_index], false};
    }
    std::swap(buffers[ready_index], buffers[read_index]);
    has_new_frame = false;
    return {buffers[read_index], true};
}

void VideoCore::TripleBuffer::swapWriteToReadyBuffers() {
    std::lock_guard<std::mutex> lock(mutex_);
    std::swap(buffers[write_index], buffers[ready_index]);
    has_new_frame = true; 
}


// =============== VideoCore ===============

VideoCore::~VideoCore() {
    // 停止线程
    stop();
    // 销毁ffmpeg上下文
    ffmpeg_ctx_.reset();
    // 关闭socket
    cleanupUdpSocket();
}

bool VideoCore::setupUdpSocket(){
#ifdef _WIN32
    if (!winsock_started_) {
        winsock_started_ = startWinsock();
        if (!winsock_started_) {
            return false;
        }
    }
#endif
    // 初始化 UDP Socket
    sockfd_ = static_cast<SocketHandle>(socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP));
    if (sockfd_ == kInvalidSocket){
        RM_LOGE(kLogTag, "Failed to create UDP socket: %s", lastSocketErrorMessage().c_str());
        cleanupUdpSocket();
        return false;
    }

    // 设置接收缓冲区大小，防止高码率下内核丢包
    int rcvbuf = 1024 * 1024; // 1MB
    setsockopt(static_cast<SOCKET>(sockfd_), SOL_SOCKET, SO_RCVBUF, reinterpret_cast<const char*>(&rcvbuf), sizeof(rcvbuf));

    // 设置等待时间
#ifdef _WIN32
    DWORD timeout_ms = 1000;
    if (setsockopt(static_cast<SOCKET>(sockfd_), SOL_SOCKET, SO_RCVTIMEO, reinterpret_cast<const char*>(&timeout_ms), sizeof(timeout_ms)) < 0) {
#else
    struct timeval tv;
    tv.tv_sec = 1;  // 超时时间 1秒
    tv.tv_usec = 0;
    if (setsockopt(sockfd_, SOL_SOCKET, SO_RCVTIMEO, reinterpret_cast<const char*>(&tv), sizeof tv) < 0) {
#endif
        RM_LOGE(kLogTag, "Failed to set UDP socket timeout option: %s", lastSocketErrorMessage().c_str());
        cleanupUdpSocket();
        return false;
    }

    sockaddr_in addr;
    memset(&addr, 0, sizeof(addr));
    addr.sin_family = AF_INET;
    addr.sin_addr.s_addr = htonl(INADDR_ANY);
    addr.sin_port = htons(port_);

    if (bind(static_cast<SOCKET>(sockfd_), reinterpret_cast<sockaddr*>(&addr), sizeof(addr)) < 0) {
        RM_LOGE(kLogTag, "Bind failed: %s", lastSocketErrorMessage().c_str());
        cleanupUdpSocket();
        return false;
    }

    RM_LOGI(kLogTag, "UDP socket bound on 0.0.0.0:%d", port_);
    return true;

}

bool VideoCore::cleanupUdpSocket(){
    closeSocket(sockfd_);
#ifdef _WIN32
    if (winsock_started_) {
        WSACleanup();
        winsock_started_ = false;
    }
#endif
    return true;
}

bool VideoCore::init() {

    if(!setupUdpSocket()){
        return false;
    }

    // 初始化 FFmpeg 解码器
    ffmpeg_ctx_ = std::make_unique<FFmpegContext>();
    if (!ffmpeg_ctx_->init(codec_id_)) {
        RM_LOGE(kLogTag, "Failed to initialize FFmpeg context.");
        cleanupUdpSocket();
        ffmpeg_ctx_.reset();
        return false;
    }

    // 初始化三缓冲区
    triple_buffer_ = std::make_unique<TripleBuffer>();
    if (!triple_buffer_->init()) {
        RM_LOGE(kLogTag, "Failed to initialize TripleBuffer.");
        cleanupUdpSocket();
        ffmpeg_ctx_.reset();
        triple_buffer_.reset();
        return false;
    }

    return true;
}

void VideoCore::start() {
    running_ = true;
    receive_thread_ = std::thread(&VideoCore::networkLoop, this);
    RM_LOGI(kLogTag, "VideoCore started receiving thread.");
}

void VideoCore::stop() {
    running_ = false;
    if (receive_thread_.joinable()) {
        receive_thread_.join();
    }
}

// 网络接收循环
void VideoCore::networkLoop() {
    const int BUF_SIZE = 65535;
    uint8_t buffer[BUF_SIZE];
    bool last_udp_ok = udp_ok_.load();

    while (running_) {
        // 尝试接收
        const int received = recvfrom(static_cast<SOCKET>(sockfd_), reinterpret_cast<char*>(buffer), BUF_SIZE, 0, nullptr, nullptr);

        if (received > 0) {
            packet_count_.fetch_add(1, std::memory_order_relaxed);
            // 收到数据，正常处理
            processPacket(buffer, static_cast<size_t>(received));
            if (!last_udp_ok) {
                RM_LOGI(kLogTag, "UDP receiving resumed.");
                last_udp_ok = true;
            }
            setUdpStatus(true);
        } else {
            if (isRecvTimeoutError()) {
                if (last_udp_ok) {
                    RM_LOGW(kLogTag, "UDP recv timeout, no data received.");
                    last_udp_ok = false;
                }
                setUdpStatus(false);
                continue;
            } else {
                RM_LOGE(kLogTag, "recvfrom error: %s", lastSocketErrorMessage().c_str());
                setUdpStatus(false);
                continue;
            }
        }
    }
}

// 协议解析与重组 (Assembler)
void VideoCore::processPacket(const uint8_t* buffer, size_t len) {
    ParsedPacketHeader header{};
    if (!parsePacketHeader(buffer, len, kMaxFrameBytes, header)) {
        dropped_packet_count_.fetch_add(1, std::memory_order_relaxed);
        return;
    }

    const uint16_t frameSeq = header.frame_seq;
    const uint16_t fragSeq = header.fragment_seq;
    const uint32_t totalSize = header.total_size;

    if (totalSize == 0 || totalSize > kMaxFrameBytes) {
        dropped_packet_count_.fetch_add(1, std::memory_order_relaxed);
        RM_LOGW_STREAM(kLogTag, "Dropping packet: unreasonable total_size=" << totalSize << " for frame_seq=" << frameSeq);
        return;
    }

    size_t payloadLen = len - sizeof(VideoPacketHeader);
    const uint8_t* payloadData = buffer + sizeof(VideoPacketHeader);

    if (payloadLen == 0 || payloadLen > totalSize) {
        dropped_packet_count_.fetch_add(1, std::memory_order_relaxed);
        RM_LOGW_STREAM(kLogTag, "Dropping packet: payloadLen=" << payloadLen << " totalSize=" << totalSize
                                                               << " frame_seq=" << frameSeq);
        return;
    }

    FrameContext& targetCtx = getOrCreateFrameContext(frameSeq, totalSize);
    targetCtx.insertFragment(fragSeq, std::vector<uint8_t>(payloadData, payloadData + payloadLen));

    if (!targetCtx.isComplete()) return;

    std::vector<uint8_t> frameData;
    frameData.reserve(targetCtx.total_size);
    for (const auto& fragPair : targetCtx.fragments) {
        frameData.insert(frameData.end(), fragPair.second.begin(), fragPair.second.end());
        if (frameData.size() >= targetCtx.total_size) break;
    }
    if (frameData.size() < targetCtx.total_size) {
        dropped_packet_count_.fetch_add(1, std::memory_order_relaxed);
        targetCtx.reset();
        return;
    }
    if (frameData.size() > targetCtx.total_size) {
        frameData.resize(targetCtx.total_size);
    }

    decodeFrame(std::move(frameData));
    targetCtx.reset();
}

VideoCore::FrameContext& VideoCore::getOrCreateFrameContext(uint16_t frameSeq, uint32_t totalSize) {
    for (auto& ctx : buffers_) {
        if (ctx.isActive() && ctx.frame_seq == frameSeq) {
            if (ctx.total_size != totalSize) {
                ctx.reset();
                ctx.markActive(frameSeq, totalSize);
            }
            return ctx;
        }
    }

    for (auto& ctx : buffers_) {
        if (!ctx.isActive()) {
            ctx.markActive(frameSeq, totalSize);
            return ctx;
        }
    }

    auto oldestIt = buffers_.begin();
    for (auto it = buffers_.begin() + 1; it != buffers_.end(); ++it) {
        if (it->last_update < oldestIt->last_update) {
            oldestIt = it;
        }
    }

    const uint16_t droppedSeq = oldestIt->frame_seq;
    oldestIt->reset();
    oldestIt->markActive(frameSeq, totalSize);
    dropped_packet_count_.fetch_add(1, std::memory_order_relaxed);
    RM_LOGW_STREAM(kLogTag, "All FrameContext slots are busy. Dropping frame_seq " << droppedSeq
                                                                                   << " and reusing slot for frame_seq "
                                                                                   << frameSeq);
    return *oldestIt;
}

void VideoCore::decodeFrame(std::vector<uint8_t>&& frameData) {
    if (frameData.empty()) return;

    // padding

    size_t actual_size = frameData.size();
    frameData.resize(actual_size + AV_INPUT_BUFFER_PADDING_SIZE); 
    
    memset(frameData.data() + actual_size, 0, AV_INPUT_BUFFER_PADDING_SIZE);

    auto* persistent_vector = new std::vector<uint8_t>(std::move(frameData));

    // 定义回调：当 FFmpeg 用完数据后，释放 vector
    auto free_vector_callback = [](void* opaque, uint8_t* data) {
        auto* vec = static_cast<std::vector<uint8_t>*>(opaque);
        delete vec; // 这里释放内存
    };

    // 创建 AVBufferRef (零拷贝挂载)
    // 注意：这里传入的大小包含 Padding，但这只是 Buffer 的大小
    AVBufferRef* buf_ref = av_buffer_create(
        persistent_vector->data(), 
        persistent_vector->size(), 
        free_vector_callback, 
        persistent_vector, 
        0
    );

    if (!buf_ref) {
        decode_error_count_.fetch_add(1, std::memory_order_relaxed);
        RM_LOGE(kLogTag, "Failed to create AVBufferRef.");
        delete persistent_vector;
        return;
    }

    // 填充 AVPacket
    av_packet_unref(ffmpeg_ctx_->avPacket_); // 确保 Packet 是干净的
    ffmpeg_ctx_->avPacket_->buf = buf_ref;   // 挂载引用计数 Buffer
    ffmpeg_ctx_->avPacket_->data = persistent_vector->data(); // 数据指针
    ffmpeg_ctx_->avPacket_->size = static_cast<int>(actual_size); // !!! 关键：告诉解码器有效数据大小（不含Padding）

    // 发送解码
    int ret = avcodec_send_packet(ffmpeg_ctx_->codec_ctx, ffmpeg_ctx_->avPacket_);
    
    // 减少我们手动的引用，所有权移交给解码器内部的队列
    // 当解码器用完后，会自动调用上面的 free_vector_callback
    av_packet_unref(ffmpeg_ctx_->avPacket_);

    if (ret < 0) {
        decode_error_count_.fetch_add(1, std::memory_order_relaxed);
        RM_LOGE_STREAM(kLogTag, "Error sending packet: " << ret);
        return;
    }

    // 接收解码帧 (TripleBuffer 逻辑)
    while (true) {
        ret = avcodec_receive_frame(ffmpeg_ctx_->codec_ctx, triple_buffer_->getWriteBuffer());
        if (ret == 0) {
            // 成功解码
            triple_buffer_->swapWriteToReadyBuffers();
            decoded_frame_count_.fetch_add(1, std::memory_order_relaxed);
        } else if (ret == AVERROR(EAGAIN) || ret == AVERROR_EOF) {
            break; 
        } else {
            decode_error_count_.fetch_add(1, std::memory_order_relaxed);
            RM_LOGE_STREAM(kLogTag, "Error during decoding: " << ret);
            break;
        }
    }
}

size_t VideoCore::getActiveFrameContextCount() const {
    size_t count = 0;
    for (const auto& ctx : buffers_) {
        if (ctx.isActive()) {
            ++count;
        }
    }
    return count;
}

bool VideoCore::restartUdp() {
    // 停止接收线程
    stop();
    cleanupUdpSocket();
    if(!setupUdpSocket()){
        return false;
    }
    start();
    return true;
}

} // namespace RMVideoDecoder
