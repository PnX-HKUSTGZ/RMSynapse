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
#include <algorithm>
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

struct HevcNalUnit {
    int type = -1;
    size_t start = 0;
    size_t header = 0;
    size_t end = 0;
};

uint16_t readU16Be(const uint8_t* data) {
    return static_cast<uint16_t>((static_cast<uint16_t>(data[0]) << 8) | data[1]);
}

uint16_t readU16Le(const uint8_t* data) {
    return static_cast<uint16_t>((static_cast<uint16_t>(data[1]) << 8) | data[0]);
}

uint32_t readU32Be(const uint8_t* data) {
    return (static_cast<uint32_t>(data[0]) << 24) |
           (static_cast<uint32_t>(data[1]) << 16) |
           (static_cast<uint32_t>(data[2]) << 8) |
           static_cast<uint32_t>(data[3]);
}

uint32_t readU32Le(const uint8_t* data) {
    return (static_cast<uint32_t>(data[3]) << 24) |
           (static_cast<uint32_t>(data[2]) << 16) |
           (static_cast<uint32_t>(data[1]) << 8) |
           static_cast<uint32_t>(data[0]);
}

ParsedPacketHeader parsePacketHeaderAs(const uint8_t* buffer, HeaderByteOrder order) {
    if (order == HeaderByteOrder::LittleEndian) {
        return {
            readU16Le(buffer),
            readU16Le(buffer + 2),
            readU32Le(buffer + 4),
        };
    }
    return {
        readU16Be(buffer),
        readU16Be(buffer + 2),
        readU32Be(buffer + 4),
    };
}

const char* byteOrderName(HeaderByteOrder order) {
    switch (order) {
        case HeaderByteOrder::BigEndian:
            return "big-endian";
        case HeaderByteOrder::LittleEndian:
            return "little-endian";
        case HeaderByteOrder::Unknown:
        default:
            return "unknown";
    }
}

bool isFrameSizePlausible(const ParsedPacketHeader& header, size_t payloadLen, uint32_t maxFrameBytes) {
    return header.total_size >= payloadLen && header.total_size <= maxFrameBytes;
}

HeaderByteOrder detectHeaderByteOrder(const uint8_t* buffer, size_t len, uint32_t maxFrameBytes) {
    const size_t payloadLen = len > sizeof(VideoPacketHeader) ? len - sizeof(VideoPacketHeader) : 0;
    const ParsedPacketHeader be = parsePacketHeaderAs(buffer, HeaderByteOrder::BigEndian);
    const ParsedPacketHeader le = parsePacketHeaderAs(buffer, HeaderByteOrder::LittleEndian);
    const bool bePlausible = isFrameSizePlausible(be, payloadLen, maxFrameBytes);
    const bool lePlausible = isFrameSizePlausible(le, payloadLen, maxFrameBytes);

    if (bePlausible && !lePlausible) return HeaderByteOrder::BigEndian;
    if (lePlausible && !bePlausible) return HeaderByteOrder::LittleEndian;

    return HeaderByteOrder::BigEndian;
}

bool parsePacketHeader(const uint8_t* buffer, size_t len, HeaderByteOrder order, ParsedPacketHeader& out) {
    if (len < sizeof(VideoPacketHeader)) return false;

    out = parsePacketHeaderAs(buffer, order);
    return true;
}

bool isStartCodeAt(const std::vector<uint8_t>& data, size_t pos, size_t& codeSize) {
    if (pos + 3 <= data.size() && data[pos] == 0x00 && data[pos + 1] == 0x00 && data[pos + 2] == 0x01) {
        codeSize = 3;
        return true;
    }
    if (pos + 4 <= data.size() && data[pos] == 0x00 && data[pos + 1] == 0x00 &&
        data[pos + 2] == 0x00 && data[pos + 3] == 0x01) {
        codeSize = 4;
        return true;
    }
    return false;
}

std::vector<HevcNalUnit> findHevcNalUnits(const std::vector<uint8_t>& data) {
    std::vector<HevcNalUnit> units;
    size_t pos = 0;
    while (pos + 3 < data.size()) {
        size_t codeSize = 0;
        if (!isStartCodeAt(data, pos, codeSize)) {
            ++pos;
            continue;
        }

        const size_t nalHeader = pos + codeSize;
        if (nalHeader + 1 >= data.size()) {
            break;
        }

        size_t next = nalHeader + 2;
        while (next + 3 < data.size()) {
            size_t nextCodeSize = 0;
            if (isStartCodeAt(data, next, nextCodeSize)) {
                break;
            }
            ++next;
        }

        units.push_back({
            static_cast<int>((data[nalHeader] >> 1) & 0x3f),
            pos,
            nalHeader,
            next < data.size() ? next : data.size(),
        });
        pos = next;
    }
    return units;
}

bool isHevcParameterNal(int nalType) {
    return nalType == 32 || nalType == 33 || nalType == 34;
}

bool isHevcIdrNal(int nalType) {
    return nalType == 19 || nalType == 20 || nalType == 21;
}

size_t hevcParameterIndex(int nalType) {
    return static_cast<size_t>(nalType - 32);
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
    resetStreamState();

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
                if (current_frame_.active && current_frame_.isComplete()) {
                    finalizeCurrentFrame("UDP timeout complete");
                } else if (current_frame_.active && current_frame_.isOutdated()) {
                    dropped_packet_count_.fetch_add(1, std::memory_order_relaxed);
                    RM_LOGW_STREAM(kLogTag, "Dropping stale incomplete frame_seq=" << current_frame_.frame_seq);
                    current_frame_.reset();
                }
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
    if (len <= sizeof(VideoPacketHeader)) {
        dropped_packet_count_.fetch_add(1, std::memory_order_relaxed);
        return;
    }

    if (header_byte_order_ == HeaderByteOrder::Unknown) {
        header_byte_order_ = detectHeaderByteOrder(buffer, len, kMaxFrameBytes);
        RM_LOGI(kLogTag, "Detected UDP video packet header byte order: %s", byteOrderName(header_byte_order_));
    }

    ParsedPacketHeader header{};
    if (!parsePacketHeader(buffer, len, header_byte_order_, header)) {
        dropped_packet_count_.fetch_add(1, std::memory_order_relaxed);
        return;
    }

    uint16_t frameSeq = header.frame_seq;
    uint16_t fragSeq = header.fragment_seq;
    uint32_t totalSize = header.total_size;

    const size_t payloadLen = len - sizeof(VideoPacketHeader);
    const uint8_t* payloadData = buffer + sizeof(VideoPacketHeader);

    if (payloadLen == 0) {
        dropped_packet_count_.fetch_add(1, std::memory_order_relaxed);
        return;
    }

    if (totalSize > kMaxFrameBytes) {
        dropped_packet_count_.fetch_add(1, std::memory_order_relaxed);
        RM_LOGW_STREAM(kLogTag, "Dropping packet: frame_size=" << totalSize << " exceeds cap, frame_seq=" << frameSeq);
        return;
    }

    if (!current_frame_.active) {
        current_frame_.markActive(frameSeq, totalSize);
    } else if (current_frame_.frame_seq != frameSeq) {
        const HeaderByteOrder orderBeforeFinalize = header_byte_order_;
        finalizeCurrentFrame("frame rollover");
        if (header_byte_order_ != orderBeforeFinalize &&
            parsePacketHeader(buffer, len, header_byte_order_, header)) {
            frameSeq = header.frame_seq;
            fragSeq = header.fragment_seq;
            totalSize = header.total_size;
        }
        current_frame_.markActive(frameSeq, totalSize);
    } else if (current_frame_.total_size == 0 && totalSize > 0) {
        current_frame_.total_size = totalSize;
    }

    current_frame_.insertFragment(fragSeq, std::vector<uint8_t>(payloadData, payloadData + payloadLen));

    if (current_frame_.received_size > kMaxFrameBytes) {
        dropped_packet_count_.fetch_add(1, std::memory_order_relaxed);
        RM_LOGW_STREAM(kLogTag, "Dropping frame_seq=" << current_frame_.frame_seq << " because assembled bytes exceed cap");
        current_frame_.reset();
        return;
    }

    if (current_frame_.isComplete()) {
        finalizeCurrentFrame("frame size complete");
    }
}

bool VideoCore::assembleCurrentFrame(std::vector<uint8_t>& frameData) const {
    if (!current_frame_.active || current_frame_.fragments.empty()) {
        return false;
    }

    uint16_t expected = 0;
    uint32_t assembledSize = 0;
    for (const auto& fragPair : current_frame_.fragments) {
        if (fragPair.first != expected) {
            return false;
        }
        assembledSize += static_cast<uint32_t>(fragPair.second.size());
        if (assembledSize > kMaxFrameBytes) {
            return false;
        }
        if (expected == UINT16_MAX) {
            break;
        }
        ++expected;
    }

    frameData.clear();
    frameData.reserve(assembledSize);
    for (const auto& fragPair : current_frame_.fragments) {
        frameData.insert(frameData.end(), fragPair.second.begin(), fragPair.second.end());
    }
    return !frameData.empty();
}

bool VideoCore::currentFrameLooksByteSwapped() const {
    if (current_frame_.fragments.size() < 2) {
        return false;
    }

    uint16_t expected = 0;
    for (const auto& fragPair : current_frame_.fragments) {
        if (fragPair.first % 256 != 0) {
            return false;
        }
        if (fragPair.first / 256 != expected) {
            return false;
        }
        if (expected == UINT16_MAX) {
            break;
        }
        ++expected;
    }
    return true;
}

void VideoCore::finalizeCurrentFrame(const char* reason) {
    if (!current_frame_.active) {
        return;
    }

    if (!current_frame_.hasFragments()) {
        current_frame_.reset();
        return;
    }

    frames_seen_ += 1;

    std::vector<uint8_t> frameData;
    if (!assembleCurrentFrame(frameData)) {
        dropped_packet_count_.fetch_add(1, std::memory_order_relaxed);
        if (currentFrameLooksByteSwapped()) {
            header_byte_order_ = header_byte_order_ == HeaderByteOrder::BigEndian
                                     ? HeaderByteOrder::LittleEndian
                                     : HeaderByteOrder::BigEndian;
            RM_LOGW(kLogTag,
                    "Detected byte-swapped UDP shard sequence; switching video packet header byte order to %s",
                    byteOrderName(header_byte_order_));
        }
        RM_LOGW_STREAM(kLogTag, "Dropping frame_seq=" << current_frame_.frame_seq
                                                      << " because UDP shards are not contiguous from 0");
        current_frame_.reset();
        return;
    }

    if (current_frame_.total_size > 0 && frameData.size() != current_frame_.total_size) {
        RM_LOGW_STREAM(kLogTag, "Frame_seq=" << current_frame_.frame_seq << " assembled size=" << frameData.size()
                                             << " differs from header frame_size=" << current_frame_.total_size
                                             << "; decoding contiguous shards like receive_video.py");
    }

    if (!logged_first_frame_) {
        RM_LOGI_STREAM(kLogTag, "First assembled UDP video frame: frame_seq=" << current_frame_.frame_seq
                                                                              << " bytes=" << frameData.size()
                                                                              << " reason=" << reason);
        logged_first_frame_ = true;
    }

    frameData = prepareHevcAccessUnit(std::move(frameData));
    if (!frameData.empty()) {
        frames_ok_ += 1;
        decodeFrame(std::move(frameData));
    }

    const auto now = std::chrono::steady_clock::now();
    if (last_stats_log_.time_since_epoch().count() == 0 || now - last_stats_log_ >= std::chrono::seconds(1)) {
        const auto packets = packet_count_.load(std::memory_order_relaxed);
        const auto decoded = decoded_frame_count_.load(std::memory_order_relaxed);
        const auto dropped = dropped_packet_count_.load(std::memory_order_relaxed);
        RM_LOGI_STREAM(kLogTag, "UDP video stats: packets=" << packets
                                                            << " frames=" << frames_seen_
                                                            << " accepted=" << frames_ok_
                                                            << " decoded=" << decoded
                                                            << " dropped=" << dropped
                                                            << " stream_ready=" << (hevc_stream_ready_ ? 1 : 0));
        last_stats_log_ = now;
    }

    current_frame_.reset();
}

std::vector<uint8_t> VideoCore::prepareHevcAccessUnit(std::vector<uint8_t>&& frameData) {
    if (codec_id_ != AV_CODEC_ID_HEVC || frameData.empty()) {
        return std::move(frameData);
    }

    const auto units = findHevcNalUnits(frameData);
    if (units.empty()) {
        return std::move(frameData);
    }

    bool hasParam = false;
    bool hasIdr = false;
    bool hasVps = false;
    bool hasSps = false;
    bool hasPps = false;

    for (const auto& unit : units) {
        if (isHevcParameterNal(unit.type)) {
            hasParam = true;
            const size_t index = hevcParameterIndex(unit.type);
            if (index < hevc_parameter_sets_.size() && unit.end > unit.start && unit.end <= frameData.size()) {
                hevc_parameter_sets_[index].assign(frameData.begin() + static_cast<std::ptrdiff_t>(unit.start),
                                                   frameData.begin() + static_cast<std::ptrdiff_t>(unit.end));
            }
        }
        if (unit.type == 32) hasVps = true;
        if (unit.type == 33) hasSps = true;
        if (unit.type == 34) hasPps = true;
        if (isHevcIdrNal(unit.type)) hasIdr = true;
    }

    const bool hadStreamReady = hevc_stream_ready_;
    hevc_stream_ready_ = hevc_stream_ready_ || hasParam ||
                         (!hevc_parameter_sets_[0].empty() &&
                          !hevc_parameter_sets_[1].empty() &&
                          !hevc_parameter_sets_[2].empty());

    if (!hadStreamReady && hevc_stream_ready_) {
        RM_LOGI(kLogTag, "HEVC stream parameters received; decoder can start accepting frames.");
    }

    if (!hevc_stream_ready_ && !hasParam) {
        dropped_packet_count_.fetch_add(1, std::memory_order_relaxed);
        RM_LOGW(kLogTag, "Dropping HEVC access unit before VPS/SPS/PPS parameter data is available.");
        return {};
    }

    if (hasIdr) {
        const bool frameHasAllParams = hasVps && hasSps && hasPps;
        const bool cacheHasAllParams = !hevc_parameter_sets_[0].empty() &&
                                       !hevc_parameter_sets_[1].empty() &&
                                       !hevc_parameter_sets_[2].empty();
        if (!frameHasAllParams && cacheHasAllParams) {
            std::vector<uint8_t> withHeaders;
            withHeaders.reserve(hevc_parameter_sets_[0].size() +
                                hevc_parameter_sets_[1].size() +
                                hevc_parameter_sets_[2].size() +
                                frameData.size());
            for (const auto& param : hevc_parameter_sets_) {
                withHeaders.insert(withHeaders.end(), param.begin(), param.end());
            }
            withHeaders.insert(withHeaders.end(), frameData.begin(), frameData.end());
            return withHeaders;
        }
    }

    return std::move(frameData);
}

void VideoCore::resetStreamState() {
    current_frame_.reset();
    header_byte_order_ = HeaderByteOrder::Unknown;
    for (auto& param : hevc_parameter_sets_) {
        param.clear();
    }
    hevc_stream_ready_ = false;
    logged_first_frame_ = false;
    frames_seen_ = 0;
    frames_ok_ = 0;
    last_stats_log_ = {};
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
    return current_frame_.isActive() ? 1 : 0;
}

bool VideoCore::restartUdp() {
    // 停止接收线程
    stop();
    cleanupUdpSocket();
    resetStreamState();
    if(!setupUdpSocket()){
        return false;
    }
    start();
    return true;
}

} // namespace RMVideoDecoder
