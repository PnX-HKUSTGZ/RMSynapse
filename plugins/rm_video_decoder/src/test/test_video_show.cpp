#include "video_core.hpp"
#include <iostream>

#include <opencv2/opencv.hpp>

extern "C" {
#include <libswscale/swscale.h>
#include <libavutil/pixdesc.h>
}

int main() {
    RMVideoDecoder::VideoCore videoCore;
    
    // videoCore.setCodecId(AV_CODEC_ID_MJPEG);

    if (!videoCore.init()) {
        std::cerr << "VideoCore init failed." << std::endl;
        return 1;
    }
    videoCore.start();

    SwsContext* sws_ctx = nullptr;

    while(1){
        auto readResult = videoCore.getReadFrame();
        AVFrame* frame = readResult.first;
        bool hasNewFrame = readResult.second;

        if(hasNewFrame && frame->width > 0 && frame->height > 0){
            
            const auto src_fmt = static_cast<AVPixelFormat>(frame->format);
            const char* fmt_name = av_get_pix_fmt_name(src_fmt);
            std::cout << "Received frame: " << frame->width << "x" << frame->height 
                      << " fmt: " << frame->format
                      << (fmt_name ? " (" : "")
                      << (fmt_name ? fmt_name : "")
                      << (fmt_name ? ")" : "")
                      << std::endl;

            cv::Mat bgrImg(frame->height, frame->width, CV_8UC3);

            sws_ctx = sws_getCachedContext(
                sws_ctx,
                frame->width,
                frame->height,
                src_fmt,
                frame->width,
                frame->height,
                AV_PIX_FMT_BGR24,
                SWS_BILINEAR,
                nullptr,
                nullptr,
                nullptr
            );

            if (!sws_ctx) {
                std::cerr << "Failed to create SwsContext for pix_fmt=" << frame->format << std::endl;
                continue;
            }

            uint8_t* dst_data[4] = {bgrImg.data, nullptr, nullptr, nullptr};
            int dst_linesize[4] = {static_cast<int>(bgrImg.step), 0, 0, 0};
            int scaled_h = sws_scale(
                sws_ctx,
                frame->data,
                frame->linesize,
                0,
                frame->height,
                dst_data,
                dst_linesize
            );

            if (scaled_h <= 0) {
                std::cerr << "sws_scale failed for pix_fmt=" << frame->format << std::endl;
                continue;
            }

            cv::imshow("Decoded Video", bgrImg);
            if (cv::waitKey(1) == 27) break; // 按 ESC 退出
        }
        std::this_thread::sleep_for(std::chrono::milliseconds(30));
    }

    if (sws_ctx) {
        sws_freeContext(sws_ctx);
        sws_ctx = nullptr;
    }

    return 0;
}
