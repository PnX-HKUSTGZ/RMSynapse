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

    void stop() { core_.stop(); }

    bool poll(Frame& out) {
        auto res = core_.getReadFrame();
        AVFrame* f = res.first;
        if (!res.second || !f || f->width <= 0 || f->height <= 0) return false;

        const int w = f->width;
        const int h = f->height;

        // 1) Force RGBA path (matches standalone test: single swscale to BGRA)
        if (force_rgba_) {
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
        // 2) Native NV12
        else if (f->format == AV_PIX_FMT_NV12) {
            out.layout = UVLayout::NV12;
            ensureBuffers(out, w, h);
            copyPlane(f->data[0], f->linesize[0], w, h, out.y.data());
            copyPlane(f->data[1], f->linesize[1], w, h / 2, out.uv.data());
        }
        // 3) Native I420
        else if (f->format == AV_PIX_FMT_YUV420P || f->format == AV_PIX_FMT_YUVJ420P) {
            out.layout = UVLayout::I420;
            ensureBuffers(out, w, h);
            copyPlane(f->data[0], f->linesize[0], w, h, out.y.data());
            const int uv_w = w / 2;
            const int uv_h = h / 2;
            uint8_t* dst = out.uv.data();
            for (int j = 0; j < uv_h; ++j) {
                const uint8_t* urow = f->data[1] + j * f->linesize[1];
                const uint8_t* vrow = f->data[2] + j * f->linesize[2];
                for (int i = 0; i < uv_w; ++i) {
                    *dst++ = urow[i];
                    *dst++ = vrow[i];
                }
            }
        }
        // 4) Fallback: convert to RGBA via swscale
        else {
            if (!warned_unsupported_once_) {
                const char* name = av_get_pix_fmt_name(static_cast<AVPixelFormat>(f->format));
                RM_LOGW("rm_video_decoder.YuvFrameExtractor", "Unsupported pixel format %d (%s), converting via swscale", f->format, name ? name : "unknown");
                warned_unsupported_once_ = true;
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

        out.width = w;
        out.height = h;
        return true;
    }

    bool restart() { return core_.restartUdp(); }

    ~YuvFrameExtractor() {
        if (sws_ctx_) sws_freeContext(sws_ctx_);
        if (sws_ctx_rgba_cached_) sws_freeContext(sws_ctx_rgba_cached_);
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

    bool fallback_to_rgba_ = true;
    bool force_rgba_ = false;
    bool warned_unsupported_once_ = false;

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
            w, h, AV_PIX_FMT_BGRA,
            SWS_BILINEAR, nullptr, nullptr, nullptr);
        if (!sws_ctx_rgba_cached_) return false;
        sws_rgba_w_ = w;
        sws_rgba_h_ = h;
        sws_rgba_src_fmt_ = src_fmt;
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
