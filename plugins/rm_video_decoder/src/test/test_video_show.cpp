#include "video_core.hpp"
#include <iostream>

#include <opencv2/opencv.hpp>

int main() {
    RMVideoDecoder::VideoCore videoCore;
    
    videoCore.setCodecId(AV_CODEC_ID_MJPEG);

    videoCore.init();
    videoCore.start();

    while(1){
        auto readResult = videoCore.getReadFrame();
        AVFrame* frame = readResult.first;
        bool hasNewFrame = readResult.second;

        if(hasNewFrame && frame->width > 0 && frame->height > 0){
            
            // std::cout << "Received frame: " << frame->width << "x" << frame->height 
            //           << " fmt: " << frame->format << std::endl;

            cv::Mat bgrImg;

            // 2. 格式转换处理
            // FFmpeg 默认软解通常输出 YUV420P (Format 0)
            // YUVJ420P (Format 12) 是 MJPEG 常用的
            if (frame->format == AV_PIX_FMT_YUV420P || frame->format == AV_PIX_FMT_YUVJ420P) {
                // 注意：FFmpeg 的 AVFrame 通常有 linesize (padding)，
                // 直接用 data[0] 创建 Mat 可能会导致图像扭曲或崩溃。
                // 最安全的方法是拷贝每一行，或者使用 libswscale。
                // 这里为了演示简单，假设是 YUV420P (I420)，我们需要构建一个指向 Y, U, V 的 Mat。
                // 但 OpenCV 的 cvtColor 并不直接支持从非连续内存的 AVFrame 转换。
                
                // --- 简易方案 (假设数据紧凑，不一定适用于所有分辨率) ---
                // I420 布局: YYYYY... UUU... VVV...
                // 只适用于 frame->linesize[0] == frame->width 的情况
                
                // --- 推荐的更兼容方案：逐行拷贝去除 Padding ---
                cv::Mat yuvImg;
                yuvImg.create(frame->height * 3 / 2, frame->width, CV_8UC1);
                
                // 拷贝 Y 分量
                for (int i = 0; i < frame->height; i++) {
                    memcpy(yuvImg.data + i * frame->width, 
                           frame->data[0] + i * frame->linesize[0], 
                           frame->width);
                }
                // 拷贝 U 分量
                int u_offset = frame->width * frame->height;
                int uv_height = frame->height / 2;
                int uv_width = frame->width / 2;
                for (int i = 0; i < uv_height; i++) {
                    memcpy(yuvImg.data + u_offset + i * uv_width, 
                           frame->data[1] + i * frame->linesize[1], 
                           uv_width);
                }
                // 拷贝 V 分量
                int v_offset = u_offset + uv_width * uv_height;
                for (int i = 0; i < uv_height; i++) {
                    memcpy(yuvImg.data + v_offset + i * uv_width, 
                           frame->data[2] + i * frame->linesize[2], 
                           uv_width);
                }

                // 转换颜色空间: I420 (YUV420P) -> BGR
                cv::cvtColor(yuvImg, bgrImg, cv::COLOR_YUV2BGR_I420);
                
            } else if (frame->format == AV_PIX_FMT_NV12) {
                // 如果是硬解可能有 NV12
                 cv::Mat yuvImg(frame->height * 3 / 2, frame->width, CV_8UC1, frame->data[0]);
                 cv::cvtColor(yuvImg, bgrImg, cv::COLOR_YUV2BGR_NV12);
            } else {
                std::cerr << "Unsupported AVFrame format: " << frame->format << std::endl;
            }

            if (!bgrImg.empty()) {
                cv::imshow("Decoded Video", bgrImg);
                if (cv::waitKey(1) == 27) break; // 按 ESC 退出
            }
        }
        std::this_thread::sleep_for(std::chrono::milliseconds(30));
    }
    
    return 0;
}