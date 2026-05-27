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
#include <iomanip>
#include <sstream>
#include <string>

namespace RMVideoDecoder {

namespace {
constexpr std::string_view kLogTag = "rm_video_decoder.VideoCore";
constexpr int kRequestedUdpReceiveBufferBytes = 20 * 1024 * 1024;
constexpr size_t kMaxFrameContexts = 32;

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

bool isHevcIrapNal(int nalType) {
    return nalType >= 16 && nalType <= 21;
}

size_t hevcParameterIndex(int nalType) {
    return static_cast<size_t>(nalType - 32);
}

const char* hevcNalName(int nalType) {
    switch (nalType) {
        case 16: return "BLA_W_LP";
        case 17: return "BLA_W_RADL";
        case 18: return "BLA_N_LP";
        case 19: return "IDR_W_RADL";
        case 20: return "IDR_N_LP";
        case 21: return "CRA_NUT";
        case 32: return "VPS";
        case 33: return "SPS";
        case 34: return "PPS";
        case 35: return "AUD";
        case 39: return "PREFIX_SEI";
        case 40: return "SUFFIX_SEI";
        default: return "NAL";
    }
}

std::string firstBytesHex(const std::vector<uint8_t>& data, size_t maxBytes = 24) {
    std::ostringstream oss;
    oss << std::hex << std::setfill('0');
    const size_t count = std::min(maxBytes, data.size());
    for (size_t i = 0; i < count; ++i) {
        oss << std::setw(2) << static_cast<unsigned>(data[i]);
    }
    return oss.str();
}

std::string nalTypeSummary(const std::vector<HevcNalUnit>& units, size_t maxUnits = 12) {
    if (units.empty()) {
        return "none";
    }

    std::ostringstream oss;
    const size_t count = std::min(maxUnits, units.size());
    for (size_t i = 0; i < count; ++i) {
        if (i > 0) {
            oss << ",";
        }
        oss << units[i].type << "(" << hevcNalName(units[i].type) << ")";
    }
    if (units.size() > count) {
        oss << ",...";
    }
    return oss.str();
}

const char* fragmentModeName(bool offsetMode) {
    return offsetMode ? "byte-offset" : "ordinal";
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
    int rcvbuf = kRequestedUdpReceiveBufferBytes;
    if (setsockopt(static_cast<SOCKET>(sockfd_), SOL_SOCKET, SO_RCVBUF, reinterpret_cast<const char*>(&rcvbuf), sizeof(rcvbuf)) < 0) {
        RM_LOGW(kLogTag, "Failed to request UDP receive buffer size %d: %s",
                kRequestedUdpReceiveBufferBytes,
                lastSocketErrorMessage().c_str());
    }

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

    int actualRcvbuf = 0;
#ifdef _WIN32
    int actualRcvbufLen = sizeof(actualRcvbuf);
#else
    socklen_t actualRcvbufLen = sizeof(actualRcvbuf);
#endif
    if (getsockopt(static_cast<SOCKET>(sockfd_), SOL_SOCKET, SO_RCVBUF, reinterpret_cast<char*>(&actualRcvbuf), &actualRcvbufLen) < 0) {
        RM_LOGW(kLogTag, "Could not read UDP receive buffer size: %s", lastSocketErrorMessage().c_str());
    }

    RM_LOGI(kLogTag,
            "UDP video receiver ready on 0.0.0.0:%d requested_rcvbuf=%d actual_rcvbuf=%d protocol=RoboMaster UDP HEVC AnnexB frame fragments mode=byte-offset header=frame_id:uint16 packet_id:uint16 frame_size:uint32 hevc_gate=wait_vps_sps_pps_then_irap",
            port_,
            kRequestedUdpReceiveBufferBytes,
            actualRcvbuf);
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
                dropStaleFrameContexts();
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
        RM_LOGI(kLogTag,
                "Detected UDP video packet header byte order: %s. Packet header is frame_id:uint16 packet_id:uint16 frame_size:uint32.",
                byteOrderName(header_byte_order_));
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
        RM_LOGW_STREAM(kLogTag, "Dropping empty UDP video packet frame_id=" << frameSeq
                                                                            << " packet_id=" << fragSeq
                                                                            << " frame_size=" << totalSize);
        return;
    }

    if (totalSize > kMaxFrameBytes) {
        dropped_packet_count_.fetch_add(1, std::memory_order_relaxed);
        RM_LOGW_STREAM(kLogTag, "Dropping packet: frame_size=" << totalSize
                                                               << " exceeds cap, frame_id=" << frameSeq
                                                               << " packet_id=" << fragSeq
                                                               << " payload_len=" << payloadLen);
        return;
    }

    const auto packetCount = packet_count_.load(std::memory_order_relaxed);
    std::vector<uint8_t> payloadPrefix(payloadData, payloadData + std::min<size_t>(payloadLen, 16));
    if (packetCount <= 8 || totalSize < payloadLen) {
        RM_LOGI_STREAM(kLogTag, "UDP video packet frame_id=" << frameSeq
                                                            << " packet_id=" << fragSeq
                                                            << " payload_len=" << payloadLen
                                                            << " frame_size=" << totalSize
                                                            << " byte_order=" << byteOrderName(header_byte_order_)
                                                            << " prefix_hex=" << firstBytesHex(payloadPrefix, 16));
    }

    if (totalSize < payloadLen) {
        dropped_packet_count_.fetch_add(1, std::memory_order_relaxed);
        RM_LOGW_STREAM(kLogTag, "Dropping packet because frame_size is smaller than payload_len"
                                << " frame_id=" << frameSeq
                                << " packet_id=" << fragSeq
                                << " frame_size=" << totalSize
                                << " payload_len=" << payloadLen);
        return;
    }

    if (static_cast<uint32_t>(fragSeq) >= totalSize && totalSize > 0) {
        RM_LOGW_STREAM(kLogTag, "UDP video packet_id is outside frame_size for official byte-offset mode"
                                << " frame_id=" << frameSeq
                                << " packet_id=" << fragSeq
                                << " frame_size=" << totalSize
                                << " payload_len=" << payloadLen
                                << " prefix_hex=" << firstBytesHex(payloadPrefix, 16));
    }

    dropStaleFrameContexts();

    auto frameIt = frame_contexts_.find(frameSeq);
    if (frameIt == frame_contexts_.end()) {
        if (frame_contexts_.size() >= kMaxFrameContexts) {
            evictOldestFrameContext("context limit");
        }
        FrameContext frame;
        frame.markActive(frameSeq, totalSize);
        frameIt = frame_contexts_.emplace(frameSeq, std::move(frame)).first;
        active_frame_context_count_.store(frame_contexts_.size(), std::memory_order_relaxed);
    }

    FrameContext& frame = frameIt->second;
    if (frame.total_size == 0 && totalSize > 0) {
        frame.total_size = totalSize;
    } else if (totalSize > 0 && frame.total_size > 0 && frame.total_size != totalSize) {
        dropped_packet_count_.fetch_add(1, std::memory_order_relaxed);
        RM_LOGW_STREAM(kLogTag, "Dropping active frame because frame_size changed inside one frame_id"
                                << " frame_id=" << frameSeq
                                << " old_size=" << frame.total_size
                                << " new_size=" << totalSize
                                << " packet_id=" << fragSeq);
        frame_contexts_.erase(frameSeq);
        active_frame_context_count_.store(frame_contexts_.size(), std::memory_order_relaxed);
        return;
    }

    const size_t fragmentCountBefore = frame.fragments.size();
    frame.insertFragment(fragSeq, std::vector<uint8_t>(payloadData, payloadData + payloadLen));
    if (frame.fragments.size() == fragmentCountBefore) {
        RM_LOGW_STREAM(kLogTag, "Ignoring duplicate UDP video fragment"
                                << " frame_id=" << frameSeq
                                << " packet_id=" << fragSeq
                                << " payload_len=" << payloadLen
                                << " fragments=" << frame.fragments.size());
        return;
    }

    if (frame.received_size > kMaxFrameBytes) {
        dropped_packet_count_.fetch_add(1, std::memory_order_relaxed);
        RM_LOGW_STREAM(kLogTag, "Dropping frame_id=" << frame.frame_seq << " because assembled bytes exceed cap");
        frame_contexts_.erase(frameSeq);
        active_frame_context_count_.store(frame_contexts_.size(), std::memory_order_relaxed);
        return;
    }

    if (frame.isComplete()) {
        finalizeFrameContext(frame, "frame size complete");
        frame_contexts_.erase(frameSeq);
        active_frame_context_count_.store(frame_contexts_.size(), std::memory_order_relaxed);
    }
}

bool VideoCore::assembleFrame(const FrameContext& frame, std::vector<uint8_t>& frameData, std::string* assembleMode) {
    if (!frame.active || frame.fragments.empty()) {
        return false;
    }

    auto assembleOrdinalFragments = [&]() -> bool {
        uint16_t expected = 0;
        uint32_t assembledSize = 0;
        for (const auto& fragPair : frame.fragments) {
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
        for (const auto& fragPair : frame.fragments) {
            frameData.insert(frameData.end(), fragPair.second.begin(), fragPair.second.end());
        }
        if (assembleMode) {
            *assembleMode = fragmentModeName(false);
        }
        return !frameData.empty();
    };

    auto assembleByteOffsetFragments = [&]() -> bool {
        if (frame.total_size == 0 || frame.total_size > kMaxFrameBytes) {
            return false;
        }

        uint32_t expectedOffset = 0;
        frameData.clear();
        frameData.reserve(frame.total_size);

        for (const auto& fragPair : frame.fragments) {
            const uint32_t offset = fragPair.first;
            const auto& fragment = fragPair.second;
            if (offset != expectedOffset) {
                RM_LOGW_STREAM(kLogTag, "UDP video byte-offset gap frame_id=" << frame.frame_seq
                                                                              << " expected_offset=" << expectedOffset
                                                                              << " packet_id=" << offset
                                                                              << " fragment_size=" << fragment.size()
                                                                              << " fragments=" << frame.fragments.size());
                return false;
            }
            if (fragment.size() > frame.total_size - expectedOffset) {
                RM_LOGW_STREAM(kLogTag, "UDP video fragment exceeds frame_size frame_id=" << frame.frame_seq
                                                                                         << " packet_id=" << offset
                                                                                         << " fragment_size=" << fragment.size()
                                                                                         << " expected_remaining=" << (frame.total_size - expectedOffset));
                return false;
            }
            frameData.insert(frameData.end(), fragment.begin(), fragment.end());
            expectedOffset += static_cast<uint32_t>(fragment.size());
        }

        if (expectedOffset != frame.total_size) {
            RM_LOGW_STREAM(kLogTag, "UDP video byte-offset assembled size mismatch frame_id=" << frame.frame_seq
                                                                                             << " assembled_size=" << expectedOffset
                                                                                             << " frame_size=" << frame.total_size
                                                                                             << " fragments=" << frame.fragments.size());
            return false;
        }
        if (assembleMode) {
            *assembleMode = fragmentModeName(true);
        }
        return !frameData.empty();
    };

    if (assembleByteOffsetFragments()) {
        if (!logged_byte_offset_fragment_mode_) {
            RM_LOGI_STREAM(kLogTag, "Detected official UDP video fragment mode: byte-offset"
                                    << " frame_id=" << frame.frame_seq
                                    << " fragments=" << frame.fragments.size()
                                    << " frame_size=" << frame.total_size);
            logged_byte_offset_fragment_mode_ = true;
        }
        return true;
    }
    if (assembleOrdinalFragments()) {
        RM_LOGW_STREAM(kLogTag, "UDP video frame_id=" << frame.frame_seq
                                                      << " assembled with legacy ordinal packet_id fallback; official mode is byte-offset.");
        if (!logged_ordinal_fragment_mode_) {
            RM_LOGW_STREAM(kLogTag, "Detected legacy UDP video fragment mode: ordinal packet_id fallback"
                                    << " frame_id=" << frame.frame_seq
                                    << " fragments=" << frame.fragments.size()
                                    << " frame_size=" << frame.total_size);
            logged_ordinal_fragment_mode_ = true;
        }
        return true;
    }
    return false;
}

bool VideoCore::frameLooksByteSwapped(const FrameContext& frame) const {
    if (frame.fragments.size() < 2) {
        return false;
    }

    uint16_t expected = 0;
    for (const auto& fragPair : frame.fragments) {
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

void VideoCore::finalizeFrameContext(FrameContext& frame, const char* reason) {
    if (!frame.active) {
        return;
    }

    if (!frame.hasFragments()) {
        frame.reset();
        return;
    }

    frames_seen_ += 1;

    std::vector<uint8_t> frameData;
    std::string assembleMode;
    if (!assembleFrame(frame, frameData, &assembleMode)) {
        dropped_packet_count_.fetch_add(1, std::memory_order_relaxed);
        if (frameLooksByteSwapped(frame)) {
            header_byte_order_ = header_byte_order_ == HeaderByteOrder::BigEndian
                                     ? HeaderByteOrder::LittleEndian
                                     : HeaderByteOrder::BigEndian;
            RM_LOGW(kLogTag,
                    "Detected byte-swapped UDP shard sequence; switching video packet header byte order to %s",
                    byteOrderName(header_byte_order_));
        }
        RM_LOGW_STREAM(kLogTag, "Dropping frame_id=" << frame.frame_seq
                                                     << " because UDP fragments are not contiguous as byte offsets or legacy ordinals"
                                                     << " fragments=" << frame.fragments.size()
                                                     << " received_size=" << frame.received_size
                                                     << " frame_size=" << frame.total_size);
        frame.reset();
        return;
    }

    if (frame.total_size > 0 && frameData.size() != frame.total_size) {
        dropped_packet_count_.fetch_add(1, std::memory_order_relaxed);
        incomplete_frames_ += 1;
        RM_LOGW_STREAM(kLogTag, "Dropping incomplete frame_id=" << frame.frame_seq
                                                                 << " assembled_size=" << frameData.size()
                                                                 << " expected_size=" << frame.total_size
                                                                 << " fragments=" << frame.fragments.size()
                                                                 << " assemble_mode=" << assembleMode);
        frame.reset();
        return;
    }

    if (!logged_first_frame_) {
        RM_LOGI_STREAM(kLogTag, "First assembled UDP video frame: frame_id=" << frame.frame_seq
                                                                              << " bytes=" << frameData.size()
                                                                              << " fragments=" << frame.fragments.size()
                                                                              << " assemble_mode=" << assembleMode
                                                                              << " reason=" << reason
                                                                              << " prefix_hex=" << firstBytesHex(frameData));
        logged_first_frame_ = true;
    }

    const uint16_t frameSeq = frame.frame_seq;
    const size_t fragmentCount = frame.fragments.size();
    const auto nowBeforeDecode = std::chrono::steady_clock::now();
    const bool detailLogDue = frames_seen_ <= 8 ||
                              last_frame_detail_log_.time_since_epoch().count() == 0 ||
                              nowBeforeDecode - last_frame_detail_log_ >= std::chrono::seconds(2);
    if (detailLogDue) {
        const auto units = findHevcNalUnits(frameData);
        RM_LOGI_STREAM(kLogTag, "Completed UDP video frame frame_id=" << frameSeq
                                                                      << " fragments=" << fragmentCount
                                                                      << " bytes=" << frameData.size()
                                                                      << " assemble_mode=" << assembleMode
                                                                      << " nal_types=" << nalTypeSummary(units)
                                                                      << " cache=" << hevcParameterCacheSummary()
                                                                      << " prefix_hex=" << firstBytesHex(frameData));
        last_frame_detail_log_ = nowBeforeDecode;
    }

    frameData = prepareHevcAccessUnit(std::move(frameData));
    if (!frameData.empty()) {
        frames_ok_ += 1;
        decodeFrame(std::move(frameData), frameSeq);
    }

    const auto now = std::chrono::steady_clock::now();
    if (last_stats_log_.time_since_epoch().count() == 0 || now - last_stats_log_ >= std::chrono::seconds(1)) {
        const auto packets = packet_count_.load(std::memory_order_relaxed);
        const auto decoded = decoded_frame_count_.load(std::memory_order_relaxed);
        const auto dropped = dropped_packet_count_.load(std::memory_order_relaxed);
        const size_t pendingFrames = getActiveFrameContextCount() - (frame.active ? 1 : 0);
        RM_LOGI_STREAM(kLogTag, "UDP video stats: packets=" << packets
                                                            << " frames=" << frames_seen_
                                                            << " accepted=" << frames_ok_
                                                            << " decoded=" << decoded
                                                            << " dropped=" << dropped
                                                            << " incomplete_frames=" << incomplete_frames_
                                                            << " wait_params=" << hevc_waiting_param_frames_
                                                            << " wait_irap=" << hevc_waiting_irap_frames_
                                                            << " no_start_code=" << hevc_no_start_code_frames_
                                                            << " decode_errors=" << decode_error_count_.load(std::memory_order_relaxed)
                                                            << " pending_frames=" << pendingFrames
                                                            << " stream_ready=" << (hevc_stream_ready_ ? 1 : 0)
                                                            << " cache=" << hevcParameterCacheSummary()
                                                            << " param_updates=" << hevc_param_update_frames_
                                                            << " injected_params=" << hevc_injected_param_frames_);
        last_stats_log_ = now;
    }

    frame.reset();
}

void VideoCore::dropStaleFrameContexts() {
    for (auto it = frame_contexts_.begin(); it != frame_contexts_.end();) {
        FrameContext& frame = it->second;
        if (!frame.active || !frame.isOutdated()) {
            ++it;
            continue;
        }

        dropped_packet_count_.fetch_add(1, std::memory_order_relaxed);
        incomplete_frames_ += 1;
        RM_LOGW_STREAM(kLogTag, "Dropping stale incomplete UDP video frame"
                                << " frame_id=" << frame.frame_seq
                                << " fragments=" << frame.fragments.size()
                                << " received_size=" << frame.received_size
                                << " frame_size=" << frame.total_size);
        it = frame_contexts_.erase(it);
    }
    active_frame_context_count_.store(frame_contexts_.size(), std::memory_order_relaxed);
}

void VideoCore::evictOldestFrameContext(const char* reason) {
    if (frame_contexts_.empty()) {
        return;
    }

    auto oldest = frame_contexts_.begin();
    for (auto it = frame_contexts_.begin(); it != frame_contexts_.end(); ++it) {
        if (it->second.last_update < oldest->second.last_update) {
            oldest = it;
        }
    }

    dropped_packet_count_.fetch_add(1, std::memory_order_relaxed);
    incomplete_frames_ += 1;
    RM_LOGW_STREAM(kLogTag, "Evicting incomplete UDP video frame context"
                            << " frame_id=" << oldest->second.frame_seq
                            << " reason=" << reason
                            << " fragments=" << oldest->second.fragments.size()
                            << " received_size=" << oldest->second.received_size
                            << " frame_size=" << oldest->second.total_size
                            << " active_contexts=" << frame_contexts_.size());
    frame_contexts_.erase(oldest);
    active_frame_context_count_.store(frame_contexts_.size(), std::memory_order_relaxed);
}

std::vector<uint8_t> VideoCore::prepareHevcAccessUnit(std::vector<uint8_t>&& frameData) {
    if (codec_id_ != AV_CODEC_ID_HEVC || frameData.empty()) {
        return std::move(frameData);
    }

    const auto units = findHevcNalUnits(frameData);
    const std::string nalSummary = nalTypeSummary(units);
    if (units.empty()) {
        hevc_no_start_code_frames_ += 1;
        dropped_packet_count_.fetch_add(1, std::memory_order_relaxed);
        RM_LOGW_STREAM(kLogTag, "Dropping HEVC frame without AnnexB start code"
                                << " bytes=" << frameData.size()
                                << " no_start_code_frames=" << hevc_no_start_code_frames_
                                << " cache=" << hevcParameterCacheSummary()
                                << " prefix_hex=" << firstBytesHex(frameData));
        return {};
    }

    bool hasIrap = false;
    bool hasVps = false;
    bool hasSps = false;
    bool hasPps = false;
    bool updatedParam = false;

    for (const auto& unit : units) {
        if (isHevcParameterNal(unit.type)) {
            const size_t index = hevcParameterIndex(unit.type);
            if (index < hevc_parameter_sets_.size() && unit.end > unit.start && unit.end <= frameData.size()) {
                hevc_parameter_sets_[index].assign(frameData.begin() + static_cast<std::ptrdiff_t>(unit.start),
                                                   frameData.begin() + static_cast<std::ptrdiff_t>(unit.end));
                updatedParam = true;
            }
        }
        if (unit.type == 32) hasVps = true;
        if (unit.type == 33) hasSps = true;
        if (unit.type == 34) hasPps = true;
        if (isHevcIrapNal(unit.type)) hasIrap = true;
    }

    if (updatedParam) {
        hevc_param_update_frames_ += 1;
        const auto now = std::chrono::steady_clock::now();
        if (hevc_param_update_frames_ <= 5 ||
            last_hevc_param_log_.time_since_epoch().count() == 0 ||
            now - last_hevc_param_log_ >= std::chrono::seconds(2)) {
            RM_LOGI_STREAM(kLogTag, "HEVC parameter NAL received"
                                    << " updates=" << hevc_param_update_frames_
                                    << " nal_types=" << nalSummary
                                    << " frame_has_vps=" << (hasVps ? 1 : 0)
                                    << " frame_has_sps=" << (hasSps ? 1 : 0)
                                    << " frame_has_pps=" << (hasPps ? 1 : 0)
                                    << " cache=" << hevcParameterCacheSummary());
            last_hevc_param_log_ = now;
        }
    }

    const bool hadStreamReady = hevc_stream_ready_;
    const bool paramsReady = hasCompleteHevcParameters();
    hevc_stream_ready_ = hevc_stream_ready_ || (paramsReady && hasIrap);

    if (!hadStreamReady && hevc_stream_ready_) {
        RM_LOGI(kLogTag, "HEVC stream ready after VPS/SPS/PPS and IRAP frame. %s", hevcParameterCacheSummary().c_str());
    }

    if (!paramsReady) {
        dropped_packet_count_.fetch_add(1, std::memory_order_relaxed);
        logWaitingForHevcParams(frameData, nalSummary, "waiting for complete VPS/SPS/PPS");
        return {};
    }

    if (!hevc_stream_ready_ && !hasIrap) {
        dropped_packet_count_.fetch_add(1, std::memory_order_relaxed);
        hevc_waiting_irap_frames_ += 1;
        const auto now = std::chrono::steady_clock::now();
        if (hevc_waiting_irap_frames_ <= 5 ||
            last_hevc_wait_log_.time_since_epoch().count() == 0 ||
            now - last_hevc_wait_log_ >= std::chrono::seconds(2)) {
            RM_LOGW_STREAM(kLogTag, "Waiting for HEVC IRAP/I frame before decoding"
                                    << " wait_irap_frames=" << hevc_waiting_irap_frames_
                                    << " bytes=" << frameData.size()
                                    << " nal_types=" << nalSummary
                                    << " cache=" << hevcParameterCacheSummary()
                                    << " prefix_hex=" << firstBytesHex(frameData));
            last_hevc_wait_log_ = now;
        }
        return {};
    }

    if (hasIrap) {
        const bool frameHasAllParams = hasVps && hasSps && hasPps;
        if (!frameHasAllParams && paramsReady) {
            std::vector<uint8_t> withHeaders;
            withHeaders.reserve(hevc_parameter_sets_[0].size() +
                                hevc_parameter_sets_[1].size() +
                                hevc_parameter_sets_[2].size() +
                                frameData.size());
            for (const auto& param : hevc_parameter_sets_) {
                withHeaders.insert(withHeaders.end(), param.begin(), param.end());
            }
            withHeaders.insert(withHeaders.end(), frameData.begin(), frameData.end());
            hevc_injected_param_frames_ += 1;
            RM_LOGI_STREAM(kLogTag, "Prepended cached HEVC VPS/SPS/PPS before IRAP frame"
                                    << " nal_types=" << nalSummary
                                    << " cache=" << hevcParameterCacheSummary()
                                    << " injected_frames=" << hevc_injected_param_frames_);
            return withHeaders;
        }
    }

    return std::move(frameData);
}

bool VideoCore::hasCompleteHevcParameters() const {
    return !hevc_parameter_sets_[0].empty() &&
           !hevc_parameter_sets_[1].empty() &&
           !hevc_parameter_sets_[2].empty();
}

std::string VideoCore::hevcParameterCacheSummary() const {
    std::ostringstream oss;
    oss << "vps=" << hevc_parameter_sets_[0].size()
        << " sps=" << hevc_parameter_sets_[1].size()
        << " pps=" << hevc_parameter_sets_[2].size();
    return oss.str();
}

void VideoCore::logWaitingForHevcParams(const std::vector<uint8_t>& frameData, const std::string& nalSummary, const char* reason) {
    hevc_waiting_param_frames_ += 1;

    const auto now = std::chrono::steady_clock::now();
    if (hevc_waiting_param_frames_ <= 5 ||
        last_hevc_wait_log_.time_since_epoch().count() == 0 ||
        now - last_hevc_wait_log_ >= std::chrono::seconds(2)) {
        RM_LOGW_STREAM(kLogTag, "Waiting for HEVC VPS/SPS/PPS before decoding"
                                << " wait_frames=" << hevc_waiting_param_frames_
                                << " reason=" << reason
                                << " bytes=" << frameData.size()
                                << " nal_types=" << nalSummary
                                << " cache=" << hevcParameterCacheSummary()
                                << " prefix_hex=" << firstBytesHex(frameData));
        last_hevc_wait_log_ = now;
    }
}

void VideoCore::resetStreamState() {
    frame_contexts_.clear();
    active_frame_context_count_.store(0, std::memory_order_relaxed);
    header_byte_order_ = HeaderByteOrder::Unknown;
    for (auto& param : hevc_parameter_sets_) {
        param.clear();
    }
    hevc_stream_ready_ = false;
    logged_first_frame_ = false;
    frames_seen_ = 0;
    frames_ok_ = 0;
    incomplete_frames_ = 0;
    hevc_waiting_param_frames_ = 0;
    hevc_waiting_irap_frames_ = 0;
    hevc_no_start_code_frames_ = 0;
    hevc_param_update_frames_ = 0;
    hevc_injected_param_frames_ = 0;
    logged_byte_offset_fragment_mode_ = false;
    logged_ordinal_fragment_mode_ = false;
    last_stats_log_ = {};
    last_hevc_wait_log_ = {};
    last_frame_detail_log_ = {};
    last_hevc_param_log_ = {};
}

void VideoCore::decodeFrame(std::vector<uint8_t>&& frameData, uint16_t frameSeq) {
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
        RM_LOGE(kLogTag, "Failed to create AVBufferRef for frame_id=%u bytes=%zu.", frameSeq, actual_size);
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
        RM_LOGE_STREAM(kLogTag, "FFmpeg avcodec_send_packet failed"
                                << " frame_id=" << frameSeq
                                << " bytes=" << actual_size
                                << " ret=" << ret
                                << " decode_errors=" << decode_error_count_.load(std::memory_order_relaxed));
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
            RM_LOGE_STREAM(kLogTag, "FFmpeg avcodec_receive_frame failed"
                                    << " frame_id=" << frameSeq
                                    << " ret=" << ret
                                    << " decode_errors=" << decode_error_count_.load(std::memory_order_relaxed));
            break;
        }
    }
}

size_t VideoCore::getActiveFrameContextCount() const {
    return active_frame_context_count_.load(std::memory_order_relaxed);
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
