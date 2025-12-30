#include "video_core.hpp"
#include <iostream>
#include <sys/socket.h>
#include <netinet/in.h>
#include <unistd.h>
#include <cstring>

namespace RMVideoDecoder {

//  =============== FFmpegContext ===============

bool VideoCore::FFmpegContext::init(AVCodecID codec_id) {
    codec = avcodec_find_decoder(codec_id);
    if (!codec) {
        std::cerr << "HEVC Decoder not found!" << std::endl;
        return false;
    }

    codec_ctx = avcodec_alloc_context3(codec);
    if (avcodec_open2(codec_ctx, codec, nullptr) < 0) {
        std::cerr << "Failed to open codec" << std::endl;
        return false;
    }

    avPacket_ = av_packet_alloc();
    if (!avPacket_) {
        std::cerr << "Failed to allocate AVPacket" << std::endl;
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
            std::cerr << "Failed to allocate AVFrame for TripleBuffer" << std::endl;
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
    std::swap(buffers[ready_index], buffers[read_index]);
    std::pair<AVFrame*, bool> res = {buffers[read_index], has_new_frame};
    has_new_frame = false;
    return res;
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
    if (sockfd_ > 0) {
        close(sockfd_);
        sockfd_ = -1;
    }
}

bool VideoCore::setupUdpSocket(){
    // 初始化 UDP Socket
    sockfd_ = socket(AF_INET, SOCK_DGRAM, 0);
    if (sockfd_ < 0){
        std::cerr << "Failed to create socket" << std::endl;
        return false;
    }

    // 设置接收缓冲区大小，防止高码率下内核丢包
    int rcvbuf = 1024 * 1024; // 1MB
    setsockopt(sockfd_, SOL_SOCKET, SO_RCVBUF, &rcvbuf, sizeof(rcvbuf));

    // 设置等待时间
    struct timeval tv;
    tv.tv_sec = 1;  // 超时时间 1秒
    tv.tv_usec = 0;
    if (setsockopt(sockfd_, SOL_SOCKET, SO_RCVTIMEO, (const char*)&tv, sizeof tv) < 0) {
        std::cerr << "Failed to set socket options" << std::endl;
        return false;
    }

    sockaddr_in addr;
    memset(&addr, 0, sizeof(addr));
    addr.sin_family = AF_INET;
    addr.sin_addr.s_addr = htonl(INADDR_ANY);
    addr.sin_port = htons(port_);

    if (bind(sockfd_, (sockaddr*)&addr, sizeof(addr)) < 0) {
        perror("Bind failed");
        return false;
    }

    return true;

}

bool VideoCore::cleanupUdpSocket(){
    if (sockfd_ > 0) {
        close(sockfd_);
        sockfd_ = -1;
    }
    return true;
}

bool VideoCore::init() {

    if(!setupUdpSocket()){
        return false;
    }

    // 初始化 FFmpeg 解码器
    ffmpeg_ctx_ = std::make_unique<FFmpegContext>();
    if (!ffmpeg_ctx_->init(codec_id_)) {
        std::cerr << "Failed to initialize FFmpeg context" << std::endl;
        return false;
    }

    // 初始化三缓冲区
    triple_buffer_ = std::make_unique<TripleBuffer>();
    triple_buffer_->init();

    return true;
}

void VideoCore::start() {
    running_ = true;
    receive_thread_ = std::thread(&VideoCore::networkLoop, this);
    std::cout << "VideoCore started receiving thread." << std::endl;
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

    while (running_) {
        // 尝试接收
        ssize_t received = recvfrom(sockfd_, buffer, BUF_SIZE, 0, nullptr, nullptr);

        if (received > 0) {
            // 收到数据，正常处理
            processPacket(buffer, static_cast<size_t>(received));
            setUdpStatus(true);
        } else {
            if (errno == EAGAIN || errno == EWOULDBLOCK) {
                std::cout << "recvfrom timeout, no data received." << std::endl;
                setUdpStatus(false);
                continue;
            } else {
                std::cerr << "recvfrom error: " << strerror(errno) << std::endl;
                setUdpStatus(false);
                continue;
            }
        }
    }
}

// 协议解析与重组 (Assembler)
void VideoCore::processPacket(const uint8_t* buffer, size_t len) {
    if (len < sizeof(VideoPacketHeader)) return;

    const VideoPacketHeader* header = reinterpret_cast<const VideoPacketHeader*>(buffer);
    
    // @todo 检测大小端，并做转换。先默认发送端和我们一致。
    uint16_t frameSeq = header->frame_seq;
    uint16_t fragSeq = header->fragment_seq;
    uint32_t totalSize = header->total_size;

    size_t payloadLen = len - sizeof(VideoPacketHeader);
    const uint8_t* payloadData = buffer + sizeof(VideoPacketHeader);

    // 储存分片

    int target_buffer_index = -1;

    // 更新缓冲区时间戳状态
    for(int i=0; i < FrameContextBufferSize; ++i){
        FrameContext& ctx = buffers_[i];
        if(ctx.isActive() && ctx.frame_seq == frameSeq){
            target_buffer_index = i;
            break;
        }
    }

    if(target_buffer_index == -1){
        // 寻找空闲槽位
        for(int i=0; i < FrameContextBufferSize; ++i){
            if(!buffers_[i].isActive()){
                buffers_[i].markActive(frameSeq, totalSize);
                target_buffer_index = i;
                break;
            }
        }
    }

    if(target_buffer_index == -1){
        // 删除最旧的
        int oldest_index = 0;
        for(int i=1; i < FrameContextBufferSize; ++i){
            if(buffers_[i].last_update < buffers_[oldest_index].last_update){
                oldest_index = i;
            }
        }
        buffers_[oldest_index].reset();
        buffers_[oldest_index].markActive(frameSeq, totalSize);
        target_buffer_index = oldest_index;
        std::cout<<"Warning: All FrameContext slots are busy. Reusing the oldest slot for frame_seq "<<frameSeq<<std::endl;
    }

    // 插入分片
    FrameContext& targetCtx = buffers_[target_buffer_index];
    targetCtx.insertFragment(fragSeq, std::vector<uint8_t>(payloadData, payloadData + payloadLen));
    // 检查是否完成
    if (targetCtx.isComplete()) {
        // 拼接完整帧数据
        std::vector<uint8_t> frameData;
        frameData.reserve(targetCtx.total_size);
        for (const auto& fragPair : targetCtx.fragments) {
            frameData.insert(frameData.end(), fragPair.second.begin(), fragPair.second.end());
        }
        // 解码该帧
        decodeFrame(std::move(frameData));
        // 重置该缓冲区
        targetCtx.reset();

        // std::cout<<"Frame "<<frameSeq<<" reassembled and sent for decoding."<<std::endl;
    }
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
        std::cerr << "Failed to create AVBufferRef" << std::endl;
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
        std::cerr << "Error sending packet: " << ret << std::endl;
        return;
    }

    // 接收解码帧 (TripleBuffer 逻辑)
    while (true) {
        ret = avcodec_receive_frame(ffmpeg_ctx_->codec_ctx, triple_buffer_->getWriteBuffer());
        if (ret == 0) {
            // 成功解码
            triple_buffer_->swapWriteToReadyBuffers();
        } else if (ret == AVERROR(EAGAIN) || ret == AVERROR_EOF) {
            break; 
        } else {
            std::cerr << "Error during decoding: " << ret << std::endl;
            break;
        }
    }
}

bool VideoCore::restartUdp() {
    // 停止接收线程
    stop();
    cleanupUdpSocket();
    if(!setupUdpSocket()){
        return false;
    }
    return true;
}

} // namespace RMVideoDecoder