#pragma once

#include "video_core.hpp"
#include <vector>
#include <cstring>
#include <rm_common/logger.hpp>

extern "C" {
#include <libavutil/pixdesc.h>
#include <libavutil/imgutils.h>
#include <libswscale/swscale.h>
}

namespace RMVideoDecoder {

/**
 * Helper that wraps VideoCore and exposes either
 * - RGBA buffer (force_rgba = true, matches test pipeline), or
 * - Y/UV planes for NV12/I420, with RGBA fallback for other formats.
 */
class YuvFrameExtractor {
public:
    enum class UVLayout {
        NV12,
        I420,
        RGBA
    };

    struct Frame {
        int width = 0;
        int height = 0;
        UVLayout layout = UVLayout::NV12;
        std::vector<uint8_t> y;    // w * h
        std::vector<uint8_t> uv;   // interleaved UV, size w * h / 2
        std::vector<uint8_t> rgba; // w * h * 4 when layout == RGBA
    };

    void set_port(int port) { core_.setPort(port); }
    int get_port() const { return core_.getPort(); }

    void set_force_rgba(bool v) { force_rgba_ = v; }
    bool get_force_rgba() const { return force_rgba_; }

    bool init() {
        if (!core_.init()) return false;
        core_.start();
        return true;
    }

    bool is_running() const { return core_.isRunning(); }
    bool is_udp_ok() const { return core_.isUdpOk(); }
    uint64_t get_packet_count() const { return core_.getPacketCount(); }
    uint64_t get_decoded_frame_count() const { return core_.getDecodedFrameCount(); }
    uint64_t get_dropped_packet_count() const { return core_.getDroppedPacketCount(); }
    uint64_t get_decode_error_count() const { return core_.getDecodeErrorCount(); }
    size_t get_active_frame_context_count() const { return core_.getActiveFrameContextCount(); }

    void stop() { core_.stop(); }

    bool poll(Frame& out) {
        auto res = core_.getReadFrame();
        AVFrame* f = res.first;
        if (!res.second || !f || f->width <= 0 || f->height <= 0) return false;

        const int w = f->width;
        const int h = f->height;

        // 日志控制
        static bool FORCE_RGBA_LOG = false;
        static bool SWS_NV12_LOG = false;
        static bool NATIVE_NV12_LOG = false;
        static int last_format = -1;
        
        if (f->format != last_format) {
            const char* fmt_name = av_get_pix_fmt_name(static_cast<AVPixelFormat>(f->format));
            RM_LOGI("rm_video_decoder.YuvFrameExtractor", "Pixel format: %d (%s)", f->format, fmt_name ? fmt_name : "unknown");
            last_format = f->format;
        }

        // 1) Force RGBA path
        if (force_rgba_) {
            if (!FORCE_RGBA_LOG) {
                RM_LOGI("rm_video_decoder.YuvFrameExtractor", "Using forced RGBA output path");
                FORCE_RGBA_LOG = true; SWS_NV12_LOG = false; NATIVE_NV12_LOG = false;
            }
            out.layout = UVLayout::RGBA;
            ensureBuffersRGBA(out, w, h);
            if (!ensureSwscaleRGBA(w, h, static_cast<AVPixelFormat>(f->format))) {
                RM_LOGE("rm_video_decoder.YuvFrameExtractor", "Failed to init swscale RGBA for fmt=%d", f->format);
                return false;
            }
            uint8_t* dst_rgba_data[4] { out.rgba.data(), nullptr, nullptr, nullptr };
            int dst_rgba_linesize[4] { w * 4, 0, 0, 0 };
            const int ret = sws_scale(sws_ctx_rgba_cached_, f->data, f->linesize, 0, h, dst_rgba_data, dst_rgba_linesize);
            if (ret <= 0) {
                RM_LOGE("rm_video_decoder.YuvFrameExtractor", "sws_scale RGBA failed, ret=%d", ret);
                return false;
            }
        }
        // 2) Native NV12 - 直接复制
        else if (f->format == AV_PIX_FMT_NV12) {
            if (!NATIVE_NV12_LOG) {
                RM_LOGI("rm_video_decoder.YuvFrameExtractor", "Using native NV12 output path");
                NATIVE_NV12_LOG = true; SWS_NV12_LOG = false; FORCE_RGBA_LOG = false;
            }
            out.layout = UVLayout::NV12;
            ensureBuffers(out, w, h);
            copyPlane(f->data[0], f->linesize[0], w, h, out.y.data());
            copyPlane(f->data[1], f->linesize[1], w, h / 2, out.uv.data());
        }
        // 3) 其他格式 - 使用swscale转换为NV12
        else {
            if (!SWS_NV12_LOG) {
                RM_LOGI("rm_video_decoder.YuvFrameExtractor", "Using swscale NV12 conversion for fmt=%d", f->format);
                SWS_NV12_LOG = true; NATIVE_NV12_LOG = false; FORCE_RGBA_LOG = false;
            }
            out.layout = UVLayout::NV12;
            ensureBuffers(out, w, h);
            if (!ensureSwscaleNV12(w, h, static_cast<AVPixelFormat>(f->format))) {
                RM_LOGE("rm_video_decoder.YuvFrameExtractor", "Failed to init swscale NV12 for fmt=%d", f->format);
                return false;
            }
            // 设置输出缓冲区
            uint8_t* dst_data[4] = { out.y.data(), out.uv.data(), nullptr, nullptr };
            int dst_linesize[4] = { w, w, 0, 0 };
            const int ret = sws_scale(sws_ctx_nv12_, f->data, f->linesize, 0, h, dst_data, dst_linesize);
            if (ret <= 0) {
                RM_LOGE("rm_video_decoder.YuvFrameExtractor", "sws_scale NV12 failed, ret=%d", ret);
                return false;
            }
        }

        out.width = w;
        out.height = h;
        return true;
    }

    bool restart() { return core_.restartUdp(); }

    ~YuvFrameExtractor() {
        if (sws_ctx_) sws_freeContext(sws_ctx_);
        if (sws_ctx_rgba_cached_) sws_freeContext(sws_ctx_rgba_cached_);
        if (sws_ctx_nv12_) sws_freeContext(sws_ctx_nv12_);
    }

private:
    VideoCore core_;
    SwsContext* sws_ctx_ = nullptr;
    int sws_w_ = 0;
    int sws_h_ = 0;
    AVPixelFormat sws_src_fmt_ = AV_PIX_FMT_NONE;
    std::vector<uint8_t> sws_buf_;
    uint8_t* dst_data_[4] { nullptr, nullptr, nullptr, nullptr };
    int dst_linesize_[4] {0,0,0,0};

    SwsContext* sws_ctx_rgba_cached_ = nullptr;
    int sws_rgba_w_ = 0;
    int sws_rgba_h_ = 0;
    AVPixelFormat sws_rgba_src_fmt_ = AV_PIX_FMT_NONE;

    SwsContext* sws_ctx_nv12_ = nullptr;
    int sws_nv12_w_ = 0;
    int sws_nv12_h_ = 0;
    AVPixelFormat sws_nv12_src_fmt_ = AV_PIX_FMT_NONE;

    bool fallback_to_rgba_ = true;
    bool force_rgba_ = false;

    bool ensureSwscale(int w, int h, AVPixelFormat src_fmt) {
        if (sws_ctx_ && sws_w_ == w && sws_h_ == h && sws_src_fmt_ == src_fmt) return true;
        if (sws_ctx_) {
            sws_freeContext(sws_ctx_);
            sws_ctx_ = nullptr;
        }
        sws_ctx_ = sws_getContext(w, h, src_fmt, w, h, AV_PIX_FMT_YUV420P, SWS_BILINEAR, nullptr, nullptr, nullptr);
        if (!sws_ctx_) return false;

        const int buf_size = av_image_get_buffer_size(AV_PIX_FMT_YUV420P, w, h, 1);
        if (buf_size < 0) return false;
        sws_buf_.resize(static_cast<size_t>(buf_size));
        av_image_fill_arrays(dst_data_, dst_linesize_, sws_buf_.data(), AV_PIX_FMT_YUV420P, w, h, 1);

        sws_w_ = w;
        sws_h_ = h;
        sws_src_fmt_ = src_fmt;
        return true;
    }

    bool ensureSwscaleRGBA(int w, int h, AVPixelFormat src_fmt) {
        if (sws_ctx_rgba_cached_ && sws_rgba_w_ == w && sws_rgba_h_ == h && sws_rgba_src_fmt_ == src_fmt) return true;
        sws_ctx_rgba_cached_ = sws_getCachedContext(
            sws_ctx_rgba_cached_,
            w, h, src_fmt,
            w, h, AV_PIX_FMT_RGBA,
            SWS_BILINEAR, nullptr, nullptr, nullptr);
        if (!sws_ctx_rgba_cached_) return false;
        sws_rgba_w_ = w;
        sws_rgba_h_ = h;
        sws_rgba_src_fmt_ = src_fmt;
        return true;
    }

    bool ensureSwscaleNV12(int w, int h, AVPixelFormat src_fmt) {
        if (sws_ctx_nv12_ && sws_nv12_w_ == w && sws_nv12_h_ == h && sws_nv12_src_fmt_ == src_fmt) return true;
        sws_ctx_nv12_ = sws_getCachedContext(
            sws_ctx_nv12_,
            w, h, src_fmt,
            w, h, AV_PIX_FMT_NV12,
            SWS_BILINEAR, nullptr, nullptr, nullptr);
        if (!sws_ctx_nv12_) return false;
        sws_nv12_w_ = w;
        sws_nv12_h_ = h;
        sws_nv12_src_fmt_ = src_fmt;
        return true;
    }

    static void copyPlane(const uint8_t* src, int src_stride, int w, int h, uint8_t* dst) {
        for (int j = 0; j < h; ++j) {
            std::memcpy(dst + j * w, src + j * src_stride, static_cast<size_t>(w));
        }
    }

    static void ensureBuffers(Frame& f, int w, int h) {
        const size_t y_size = static_cast<size_t>(w) * h;
        const size_t uv_size = static_cast<size_t>(w) * h / 2;
        if (f.y.size() != y_size) f.y.resize(y_size);
        if (f.uv.size() != uv_size) f.uv.resize(uv_size);
        f.rgba.clear();
    }

    static void ensureBuffersRGBA(Frame& f, int w, int h) {
        const size_t rgba_size = static_cast<size_t>(w) * h * 4;
        if (f.rgba.size() != rgba_size) f.rgba.resize(rgba_size);
        f.y.clear();
        f.uv.clear();
    }
};

} // namespace RMVideoDecoder
