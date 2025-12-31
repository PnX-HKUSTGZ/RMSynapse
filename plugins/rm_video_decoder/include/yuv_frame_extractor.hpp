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
 * Helper that wraps VideoCore and exposes contiguous Y / UV planes
 * suitable for uploading to two GPU textures (R8 for Y, RG8 for UV).
 */
class YuvFrameExtractor {
public:
    enum class UVLayout {
        NV12,
        I420,
        RGBA // when source is unsupported, we convert to BGRA and pack here
    };

    struct Frame {
        int width = 0;
        int height = 0;
        UVLayout layout = UVLayout::NV12;
        std::vector<uint8_t> y;   // width * height
        std::vector<uint8_t> uv;  // interleaved UV, size width * height / 2 * 2 == width * height
        std::vector<uint8_t> rgba; // used when layout == RGBA, size width*height*4
    };

    void set_port(int port) { core_.setPort(port); }
    int get_port() const { return core_.getPort(); }

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

        if (f->format == AV_PIX_FMT_NV12) {
            out.layout = UVLayout::NV12;
            ensureBuffers(out, w, h);
            copyPlane(f->data[0], f->linesize[0], w, h, out.y.data());
            copyPlane(f->data[1], f->linesize[1], w, h / 2, out.uv.data());
        } else if (f->format == AV_PIX_FMT_YUV420P || f->format == AV_PIX_FMT_YUVJ420P) {
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
        } else {
            const char* name = av_get_pix_fmt_name(static_cast<AVPixelFormat>(f->format));
            if (!warned_unsupported_once_) {
                RM_LOGW("rm_video_decoder.YuvFrameExtractor", "Unsupported pixel format %d (%s), converting via swscale", f->format, name ? name : "unknown");
                warned_unsupported_once_ = true;
            }
            if (fallback_to_rgba_) {
                out.layout = UVLayout::RGBA;
                ensureBuffersRGBA(out, w, h);
                // Directly convert to BGRA
                if (!ensureSwscaleRGBA(w, h, static_cast<AVPixelFormat>(f->format))) {
                    RM_LOGE("rm_video_decoder.YuvFrameExtractor", "Failed to init swscale RGBA for fmt=%d", f->format);
                    return false;
                }
                const int ret = sws_scale(sws_ctx_rgba_, f->data, f->linesize, 0, h, dst_rgba_data_, dst_rgba_linesize_);
                if (ret <= 0) {
                    RM_LOGE("rm_video_decoder.YuvFrameExtractor", "sws_scale RGBA failed, ret=%d", ret);
                    return false;
                }
                copyPlane(dst_rgba_data_[0], dst_rgba_linesize_[0], w * 4, h, out.rgba.data());
            } else {
                if (!ensureSwscale(w, h, static_cast<AVPixelFormat>(f->format))) {
                    RM_LOGE("rm_video_decoder.YuvFrameExtractor", "Failed to init swscale for fmt=%d", f->format);
                    return false;
                }
                int ret = sws_scale(sws_ctx_, f->data, f->linesize, 0, h, dst_data_, dst_linesize_);
                if (ret <= 0) {
                    RM_LOGE("rm_video_decoder.YuvFrameExtractor", "sws_scale failed, ret=%d", ret);
                    return false;
                }
                out.layout = UVLayout::I420;
                ensureBuffers(out, w, h);
                copyPlane(dst_data_[0], dst_linesize_[0], w, h, out.y.data());
                const int uv_w = w / 2;
                const int uv_h = h / 2;
                uint8_t* dst = out.uv.data();
                for (int j = 0; j < uv_h; ++j) {
                    const uint8_t* urow = dst_data_[1] + j * dst_linesize_[1];
                    const uint8_t* vrow = dst_data_[2] + j * dst_linesize_[2];
                    for (int i = 0; i < uv_w; ++i) {
                        *dst++ = urow[i];
                        *dst++ = vrow[i];
                    }
                }
            }
        }

        out.width = w;
        out.height = h;
        return true;
    }

    bool restart() {
        return core_.restartUdp();
    }

private:
    VideoCore core_;
    SwsContext* sws_ctx_ = nullptr;
    SwsContext* sws_ctx_rgba_ = nullptr;
    int sws_w_ = 0;
    int sws_h_ = 0;
    AVPixelFormat sws_src_fmt_ = AV_PIX_FMT_NONE;
    std::vector<uint8_t> sws_buf_;
    uint8_t* dst_data_[4] { nullptr, nullptr, nullptr, nullptr };
    int dst_linesize_[4] {0,0,0,0};
    std::vector<uint8_t> sws_rgba_buf_;
    uint8_t* dst_rgba_data_[4] { nullptr, nullptr, nullptr, nullptr };
    int dst_rgba_linesize_[4] {0,0,0,0};
    int sws_rgba_w_ = 0;
    int sws_rgba_h_ = 0;
    AVPixelFormat sws_rgba_src_fmt_ = AV_PIX_FMT_NONE;
    bool fallback_to_rgba_ = true;
    bool warned_unsupported_once_ = false;

    bool ensureSwscale(int w, int h, AVPixelFormat src_fmt) {
        if (sws_ctx_ && sws_w_ == w && sws_h_ == h && sws_src_fmt_ == src_fmt) return true;
        if (sws_ctx_) {
            sws_freeContext(sws_ctx_);
            sws_ctx_ = nullptr;
        }
        sws_ctx_ = sws_getContext(
            w, h, src_fmt,
            w, h, AV_PIX_FMT_YUV420P,
            SWS_BILINEAR, nullptr, nullptr, nullptr);
        if (!sws_ctx_) return false;

        int buf_size = av_image_alloc(dst_data_, dst_linesize_, w, h, AV_PIX_FMT_YUV420P, 1);
        if (buf_size < 0) return false;
        sws_buf_.assign(dst_data_[0], dst_data_[0] + buf_size);
        av_image_fill_arrays(dst_data_, dst_linesize_, sws_buf_.data(), AV_PIX_FMT_YUV420P, w, h, 1);

        sws_w_ = w;
        sws_h_ = h;
        sws_src_fmt_ = src_fmt;
        return true;
    }

    bool ensureSwscaleRGBA(int w, int h, AVPixelFormat src_fmt) {
        if (sws_ctx_rgba_ && sws_rgba_w_ == w && sws_rgba_h_ == h && sws_rgba_src_fmt_ == src_fmt) return true;
        if (sws_ctx_rgba_) {
            sws_freeContext(sws_ctx_rgba_);
            sws_ctx_rgba_ = nullptr;
        }
        sws_ctx_rgba_ = sws_getContext(
            w, h, src_fmt,
            w, h, AV_PIX_FMT_BGRA,
            SWS_BILINEAR, nullptr, nullptr, nullptr);
        if (!sws_ctx_rgba_) return false;
        int buf_size = av_image_alloc(dst_rgba_data_, dst_rgba_linesize_, w, h, AV_PIX_FMT_BGRA, 1);
        if (buf_size < 0) return false;
        sws_rgba_buf_.assign(dst_rgba_data_[0], dst_rgba_data_[0] + buf_size);
        av_image_fill_arrays(dst_rgba_data_, dst_rgba_linesize_, sws_rgba_buf_.data(), AV_PIX_FMT_BGRA, w, h, 1);
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
        const size_t uv_size = static_cast<size_t>(w) * h / 2; // interleaved UV bytes (w * h/2 *2 = w*h/2)
        if (f.y.size() != y_size) f.y.resize(y_size);
        if (f.uv.size() != uv_size) f.uv.resize(uv_size);
    }

    static void ensureBuffersRGBA(Frame& f, int w, int h) {
        const size_t rgba_size = static_cast<size_t>(w) * h * 4;
        if (f.rgba.size() != rgba_size) f.rgba.resize(rgba_size);
    }
};

} // namespace RMVideoDecoder
