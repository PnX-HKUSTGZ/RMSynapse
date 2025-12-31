#pragma once

#include <thread>
#include <atomic>
#include <functional>
#include <mutex>
#include <array>
#include <memory>
#include <utility>
#include <vector>
#include <map>
#include <chrono>

extern "C" {
#include <libavcodec/avcodec.h>
#include <libavutil/imgutils.h>
}

namespace RMVideoDecoder {

#pragma pack(push, 1)
// 自定义视频包头结构体
struct VideoPacketHeader {
    // 帧序号，从0开始递增，溢出后回0
    // 注：按网络传输习惯，字段通常使用网络字节序（大端）；接收端应做 ntohs/ntohl 转换
    uint16_t frame_seq;
    // 该帧内的分片序号
    uint16_t fragment_seq;
    // 该帧的总大小（字节数）
    uint32_t total_size;
};
#pragma pack(pop)

// 帧缓冲区结构体
struct CompleteFrame {
    // 帧序号，从0开始递增，溢出后回0
    uint16_t frame_seq;
    // 帧数据
    std::vector<uint8_t> data;
};


class VideoCore {
public:
    VideoCore() = default;
    ~VideoCore();

    // 初始化网络和解码器
    bool init();
    
    // 启动接收线程
    void start();
    
    // 停止
    void stop();

    // setter / getter

    // port
    int getPort() const { return port_; }
    void setPort(int port) { port_ = port; }

    // codec id
    AVCodecID getCodecId() const { return codec_id_; }
    void setCodecId(AVCodecID codec_id) { codec_id_ = codec_id; }

    bool isUdpOk() const { return udp_ok_.load(); }
    bool isRunning() const { return running_.load(); }

    // 重启 UDP 套接字
    bool restartUdp();

    std::pair<AVFrame*, bool> getReadFrame() {
        return triple_buffer_->getReadBuffer();
    }

private:
    struct FrameContext;

    // 参数
    int port_ = 3334;
    AVCodecID codec_id_ = AV_CODEC_ID_HEVC;
    static constexpr uint32_t kMaxFrameBytes = 16 * 1024 * 1024; // 16MB safety cap
    static constexpr size_t kFrameContextBufferSize = 8;

    // --- 内部处理函数 ---

    // UDP 接收循环
    void networkLoop();
    // 协议解析与拼包
    void processPacket(const uint8_t* buffer, size_t len);
    // FFmpeg 解码
    void decodeFrame(std::vector<uint8_t>&& frameData);
    // 拼包：获取/创建上下文槽位
    FrameContext& getOrCreateFrameContext(uint16_t frameSeq, uint32_t totalSize);

    inline void setUdpStatus(bool s) { udp_ok_.store(s); }

    // 设置 UDP 套接字
    bool setupUdpSocket();

    // 清理 UDP 套接字
    bool cleanupUdpSocket();

    // --- 成员变量 ---

    // FFmpeg 上下文
    struct FFmpegContext {
        const AVCodec* codec = nullptr;       // 解码器实例（只读，不用释放）
        AVCodecContext* codec_ctx = nullptr;   // 解码器上下文（需释放）
        AVPacket* avPacket_ = nullptr;         // AVPacket 实例（需释放）

        FFmpegContext() = default;
        /**
         * 初始化 FFmpeg 解码器，使用AV_CODEC_ID_HEVC解码器
         */
        bool init(AVCodecID codec_id = AV_CODEC_ID_HEVC);
        ~FFmpegContext();
    };

    // 拼包上下文
    struct FrameContext {
        uint16_t frame_seq = 0;
        bool active = false; // 该槽位是否被占用
        std::chrono::steady_clock::time_point last_update; // 上次更新的时间点
        uint32_t total_size = 0;
        uint32_t received_size = 0;
        std::map<uint16_t, std::vector<uint8_t>> fragments;

        // 判断是否拼包完成
        bool isComplete() const {
            return received_size >= total_size && total_size > 0;
        }

        // 重置状态
        void reset() {
            active = false;
            frame_seq = 0;
            total_size = 0;
            received_size = 0;
            fragments.clear();
        }

        // 更新时间戳
        void updateTimestamp() {
            last_update = std::chrono::steady_clock::now();
        }

        // 标记为活跃并初始化
        void markActive(uint16_t seq, uint32_t total) {
            active = true;
            frame_seq = seq;
            total_size = total;
            received_size = 0;
            fragments.clear();
            updateTimestamp();
        }

        // 插入分片数据
        void insertFragment(uint16_t fragSeq, const std::vector<uint8_t>& data) {
            if (fragments.find(fragSeq) == fragments.end()) {
                fragments[fragSeq] = data;
                received_size += data.size();
                updateTimestamp();
            }
        }

        // 判断是否过期
        bool isOutdated(std::chrono::seconds timeout = std::chrono::seconds(1)) const {
            return std::chrono::steady_clock::now() - last_update > timeout;
        }

        // 是否可以被重用
        bool isActive() const {
            return active && !isOutdated();
        }

    };

    // 三缓冲视频帧，与godot渲染线程交互
    struct TripleBuffer {
        AVFrame* buffers[3] = {nullptr, nullptr, nullptr};
        const int write_index = 0;
        const int read_index = 1;
        const int ready_index = 2;
        bool has_new_frame = false;
        std::mutex mutex_;

        TripleBuffer() = default;
        bool init();
        ~TripleBuffer();

        // 获取 ffmpeg 写入数据的缓冲区
        AVFrame* getWriteBuffer();

        // 得到安全的读取缓冲区
        std::pair<AVFrame*, bool> getReadBuffer();

        // 将写入缓冲区交换到就绪缓冲区
        void swapWriteToReadyBuffers();
    };

    // UDP 套接字
    int sockfd_ = -1;
    // FFmpeg 解码上下文
    std::unique_ptr<FFmpegContext> ffmpeg_ctx_ = nullptr;

    // 三缓冲区
    std::unique_ptr<TripleBuffer> triple_buffer_ = nullptr;

    // 接收函数是否运行
    std::atomic<bool> running_{false};

    std::atomic<bool> udp_ok_{false};

    // 接收线程
    std::thread receive_thread_;
    
    // 拼包缓冲区（支持乱序/丢包时多帧并发）
    std::array<FrameContext, kFrameContextBufferSize> buffers_{};
};

} // namespace RMVideoDecoder
