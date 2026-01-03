#pragma once

#include <godot_cpp/classes/control.hpp>
#include <godot_cpp/classes/texture_rect.hpp>
#include <godot_cpp/classes/shader_material.hpp>
#include <godot_cpp/classes/resource_loader.hpp>
#include <godot_cpp/classes/rendering_device.hpp>
#include <godot_cpp/classes/rendering_server.hpp>
#include <godot_cpp/classes/texture2drd.hpp>
#include <godot_cpp/classes/rd_texture_format.hpp>
#include <godot_cpp/classes/rd_texture_view.hpp>
#include <godot_cpp/variant/typed_array.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>

#include "yuv_frame_extractor.hpp"
#include <rm_common/godot_log_sink.hpp>

namespace rm_video_gd {

class RMVideoCanvas : public godot::Control {
    GDCLASS(RMVideoCanvas, godot::Control);

public:
    enum DisplayMode {
        DISPLAY_ADAPTIVE = 0, // 保持比例居中适配
        DISPLAY_STRETCH = 1,  // 拉伸填满
        DISPLAY_ORIGINAL = 2  // 原始尺寸居中
    };

    RMVideoCanvas() = default;
    ~RMVideoCanvas() override;

    void _ready();
    void _process(double delta);

    int get_port() const { return port_; }
    void set_port(int p);

    bool get_use_bt601() const { return use_bt601_; }
    void set_use_bt601(bool b) { use_bt601_ = b; update_shader_params(); }

    bool get_use_tv_range() const { return use_tv_range_; }
    void set_use_tv_range(bool b) { use_tv_range_ = b; update_shader_params(); }

    bool get_force_rgba() const { return force_rgba_; }
    void set_force_rgba(bool v);

    int get_display_mode() const { return display_mode_; }
    void set_display_mode(int m);

protected:
    static void _bind_methods();

private:
    void ensure_texture_rect();
    void ensure_textures(godot::RenderingDevice* rd, int w, int h);
    void upload_frame(godot::RenderingDevice* rd, const RMVideoDecoder::YuvFrameExtractor::Frame& f);
    void ensure_textures_rgba(godot::RenderingDevice* rd, int w, int h);
    void upload_frame_rgba(godot::RenderingDevice* rd, const RMVideoDecoder::YuvFrameExtractor::Frame& f);
    void update_shader_params();
    void apply_display_layout();

    RMVideoDecoder::YuvFrameExtractor extractor_;
    RMVideoDecoder::YuvFrameExtractor::Frame frame_;

    int port_ = 3334;
    bool running_ = false;
    int tex_w_ = 0;
    int tex_h_ = 0;
    bool use_bt601_ = false;
    bool use_tv_range_ = false;
    bool force_rgba_ = true;
    int display_mode_ = DISPLAY_ADAPTIVE;

    godot::RID tex_y_;
    godot::RID tex_uv_;
    godot::RID tex_rgba_;
    godot::Ref<godot::Texture2DRD> tex_y_res_;
    godot::Ref<godot::Texture2DRD> tex_uv_res_;
    godot::Ref<godot::Texture2DRD> tex_rgba_res_;

    godot::Ref<godot::ShaderMaterial> material_;
    godot::TextureRect* rect_ = nullptr;

    // YUV 数据缓冲区，避免每帧重新分配
    
    godot::PackedByteArray buf_y_;
    godot::PackedByteArray buf_uv_;
};

} // namespace rm_video_gd
