#include "rm_video_canvas.hpp"

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/utility_functions.hpp>
#include <godot_cpp/classes/engine.hpp>
#include <cstring>

using namespace godot;
using namespace rm_video_gd;

namespace {
constexpr const char* kLogTag = "rm_video_gd.RMVideoCanvas";
const char* kShaderPath = "res://bin/video_yuv.gdshader";
}

RMVideoCanvas::~RMVideoCanvas() {
    extractor_.stop();
    RenderingServer* rs = RenderingServer::get_singleton();
    if (rs) {
        if (tex_y_.is_valid()) rs->free_rid(tex_y_);
        if (tex_uv_.is_valid()) rs->free_rid(tex_uv_);
    }
}

void RMVideoCanvas::_bind_methods() {
    ClassDB::bind_method(D_METHOD("get_port"), &RMVideoCanvas::get_port);
    ClassDB::bind_method(D_METHOD("set_port", "port"), &RMVideoCanvas::set_port);
    ClassDB::bind_method(D_METHOD("get_use_bt601"), &RMVideoCanvas::get_use_bt601);
    ClassDB::bind_method(D_METHOD("set_use_bt601", "use"), &RMVideoCanvas::set_use_bt601);
    ClassDB::bind_method(D_METHOD("get_use_tv_range"), &RMVideoCanvas::get_use_tv_range);
    ClassDB::bind_method(D_METHOD("set_use_tv_range", "use"), &RMVideoCanvas::set_use_tv_range);
    ClassDB::bind_method(D_METHOD("get_force_rgba"), &RMVideoCanvas::get_force_rgba);
    ClassDB::bind_method(D_METHOD("set_force_rgba", "force"), &RMVideoCanvas::set_force_rgba);
    ClassDB::bind_method(D_METHOD("get_no_frame_timeout"), &RMVideoCanvas::get_no_frame_timeout);
    ClassDB::bind_method(D_METHOD("set_no_frame_timeout", "seconds"), &RMVideoCanvas::set_no_frame_timeout);
    ClassDB::bind_method(D_METHOD("get_placeholder_texture"), &RMVideoCanvas::get_placeholder_texture);
    ClassDB::bind_method(D_METHOD("set_placeholder_texture", "texture"), &RMVideoCanvas::set_placeholder_texture);
    // ClassDB::bind_method(D_METHOD("get_placeholder_color"), &RMVideoCanvas::get_placeholder_color);
    // ClassDB::bind_method(D_METHOD("set_placeholder_color", "color"), &RMVideoCanvas::set_placeholder_color);
    ClassDB::bind_method(D_METHOD("get_display_mode"), &RMVideoCanvas::get_display_mode);
    ClassDB::bind_method(D_METHOD("set_display_mode", "mode"), &RMVideoCanvas::set_display_mode);

    ADD_PROPERTY(PropertyInfo(Variant::INT, "port"), "set_port", "get_port");
    ADD_PROPERTY(PropertyInfo(Variant::BOOL, "use_bt601"), "set_use_bt601", "get_use_bt601");
    ADD_PROPERTY(PropertyInfo(Variant::BOOL, "use_tv_range"), "set_use_tv_range", "get_use_tv_range");
    ADD_PROPERTY(PropertyInfo(Variant::BOOL, "force_rgba"), "set_force_rgba", "get_force_rgba");
    ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "no_frame_timeout_sec", PROPERTY_HINT_RANGE, "0.0,10.0,0.1"), "set_no_frame_timeout", "get_no_frame_timeout");
    ADD_PROPERTY(PropertyInfo(Variant::OBJECT, "placeholder_texture", PROPERTY_HINT_RESOURCE_TYPE, "Texture2D"), "set_placeholder_texture", "get_placeholder_texture");
    // ADD_PROPERTY(PropertyInfo(Variant::COLOR, "placeholder_color"), "set_placeholder_color", "get_placeholder_color");
    ADD_PROPERTY(PropertyInfo(Variant::INT, "display_mode", PROPERTY_HINT_ENUM, "Adaptive(keep_aspect),Stretch,Original"), "set_display_mode", "get_display_mode");

    // Signal when stream state changes (true = has frames, false = placeholder)
    ClassDB::add_signal(get_class_static(), MethodInfo("stream_state_changed",
        PropertyInfo(Variant::BOOL, "is_streaming")));
}

void RMVideoCanvas::_ready() {
    rm::common::log::godot::install_global_sink();
    extractor_.set_port(port_);
    extractor_.set_force_rgba(force_rgba_); // match standalone test by default
    if (!extractor_.init()) {
        RM_LOGE(kLogTag, "Failed to init VideoCore");
        return;
    }
    RM_LOGI(kLogTag, "RMVideoCanvas ready. Port=%d", port_);
    running_ = true;
    ensure_texture_rect();

    // Prepare material with shader
    Ref<Shader> shd = ResourceLoader::get_singleton()->load(kShaderPath);
    if (shd.is_valid()) {
        material_.instantiate();
        material_->set_shader(shd);
        if (rect_) rect_->set_material(material_);
        update_shader_params();
    } else {
        RM_LOGE(kLogTag, "Failed to load shader at %s", kShaderPath);
    }
}

void RMVideoCanvas::set_port(int p) {
    RM_LOGI(kLogTag, "Set port from %d to %d (will restart extractor)", port_, p);
    port_ = p;
    extractor_.stop();
    extractor_.set_port(port_);
    if (running_) {
        if (!extractor_.init()) {
            RM_LOGE(kLogTag, "Re-init VideoCore failed after port change");
            running_ = false;
        }
    }
}

void RMVideoCanvas::set_force_rgba(bool v) {
    if (force_rgba_ == v) return;
    force_rgba_ = v;
    extractor_.set_force_rgba(force_rgba_);
    
    // 切换模式时需要清理所有纹理并重建
    RenderingServer* rs = RenderingServer::get_singleton();
    if (rs) {
        if (tex_y_.is_valid()) { rs->free_rid(tex_y_); tex_y_ = RID(); }
        if (tex_uv_.is_valid()) { rs->free_rid(tex_uv_); tex_uv_ = RID(); }
        if (tex_rgba_.is_valid()) { rs->free_rid(tex_rgba_); tex_rgba_ = RID(); }
    }
    tex_w_ = 0;
    tex_h_ = 0;
    
    RM_LOGI(kLogTag, "Force RGBA set to %d, textures cleared", force_rgba_);
}

void RMVideoCanvas::show_placeholder() {
    ensure_texture_rect();
    hide_placeholder();
    Ref<Texture2D> tex = placeholder_tex_.is_valid() ? placeholder_tex_ : get_fallback_placeholder();
    if (rect_ && tex.is_valid()) {
        rect_->set_material(Ref<Material>());
        rect_->set_texture(tex);
        rect_->set_modulate(Color(1, 1, 1, 1));
        placeholder_visible_ = true;
    } else if (!tex.is_valid()) {
        RM_LOGE(kLogTag, "Placeholder texture invalid; nothing to display");
    }
}

void RMVideoCanvas::hide_placeholder() {
    if (!rect_) return;
    rect_->set_modulate(Color(1, 1, 1, 1));
    placeholder_visible_ = false;
}

Ref<Texture2D> RMVideoCanvas::get_fallback_placeholder() {
    if (placeholder_generated_.is_valid()) return placeholder_generated_;
    Ref<Image> img = Image::create(10, 10, false, Image::FORMAT_RGBA8);
    if (!img.is_valid() || img->is_empty()) {
        RM_LOGE(kLogTag, "Failed to create Image for placeholder");
        return Ref<Texture2D>();
    }
    
    img->fill(placeholder_color_);

    Ref<ImageTexture> tex;
    tex.instantiate();
    if (!tex.is_valid()) {
        RM_LOGE(kLogTag, "Failed to instantiate ImageTexture for placeholder");
        return Ref<Texture2D>();
    }
    tex->create_from_image(img);
    placeholder_generated_ = tex;
    return placeholder_generated_;
}

void RMVideoCanvas::_process(double delta) {
    // Defensive: ensure the TextureRect exists even if _ready wasn't called for some reason.
    ensure_texture_rect();
    if (!running_) {
        RM_LOGW(kLogTag, "Not running; skip frame");
        return;
    }
    RenderingServer* rs = RenderingServer::get_singleton();
    if (!rs) {
        RM_LOGE(kLogTag, "RenderingServer singleton is null");
        return;
    }
    RenderingDevice* rd = rs->get_rendering_device();
    if (!rd) {
        RM_LOGE(kLogTag, "RenderingDevice is null");
        return;
    }
    static int idle_counter = 0;
    if (!extractor_.poll(frame_)) {
        if (++idle_counter % 120 == 0) {
            RM_LOGD(kLogTag, "No new frame yet.");
        }
        no_frame_elapsed_ += delta;
        if (no_frame_elapsed_ > no_frame_timeout_s_ && !placeholder_visible_) {
            if (streaming_) {
                streaming_ = false;
                emit_signal("stream_state_changed", streaming_);
            }
            show_placeholder();
        }
        return; // no new frame is not an error
    }
    idle_counter = 0;
    no_frame_elapsed_ = 0.0;
    if (!streaming_) {
        streaming_ = true;
        emit_signal("stream_state_changed", streaming_);
        hide_placeholder();
    }

    if (frame_.layout == RMVideoDecoder::YuvFrameExtractor::UVLayout::RGBA) {
        ensure_textures_rgba(rd, frame_.width, frame_.height);
        upload_frame_rgba(rd, frame_);
        if (rect_) {
            rect_->set_texture(tex_rgba_res_);
        }
    } else {
        ensure_textures(rd, frame_.width, frame_.height);
        upload_frame(rd, frame_);
        if (rect_) {
            rect_->set_material(material_);
            rect_->set_texture(tex_y_res_);
        }
        if (material_.is_valid()) update_shader_params();
    }
}

void RMVideoCanvas::ensure_texture_rect() {
    if (!rect_) {
        rect_ = memnew(TextureRect);
        rect_->set_anchors_preset(Control::LayoutPreset::PRESET_FULL_RECT);
        rect_->set_stretch_mode(TextureRect::STRETCH_KEEP_ASPECT_CENTERED);
        rect_->set_expand_mode(TextureRect::EXPAND_IGNORE_SIZE); // keep size driven by parent layout
        rect_->set_modulate(Color(1, 1, 1, 1));
        add_child(rect_);
        set_display_mode(display_mode_);
    }
}

void RMVideoCanvas::ensure_textures(RenderingDevice* rd, int w, int h) {
    if (w <= 0 || h <= 0) {
        RM_LOGE(kLogTag, "Invalid frame size %dx%d", w, h);
        return;
    }
    if (w == tex_w_ && h == tex_h_ && tex_y_.is_valid() && tex_uv_.is_valid()){
        // RM_LOGD(kLogTag, "Textures already valid for %dx%d", w, h);
        return;
    }

    RenderingServer* rs = RenderingServer::get_singleton();
    if (rs) {
        if (tex_y_.is_valid()) rs->free_rid(tex_y_);
        if (tex_uv_.is_valid()) rs->free_rid(tex_uv_);
    }

    Ref<RDTextureFormat> fmt_y;
    fmt_y.instantiate();
    fmt_y->set_format(RenderingDevice::DATA_FORMAT_R8_UNORM);
    fmt_y->set_width(w);
    fmt_y->set_height(h);
    fmt_y->set_usage_bits(RenderingDevice::TEXTURE_USAGE_SAMPLING_BIT | RenderingDevice::TEXTURE_USAGE_CAN_UPDATE_BIT);

    Ref<RDTextureFormat> fmt_uv;
    fmt_uv.instantiate();
    fmt_uv->set_format(RenderingDevice::DATA_FORMAT_R8G8_UNORM);
    fmt_uv->set_width(w / 2);
    fmt_uv->set_height(h / 2);
    fmt_uv->set_usage_bits(RenderingDevice::TEXTURE_USAGE_SAMPLING_BIT | RenderingDevice::TEXTURE_USAGE_CAN_UPDATE_BIT);

    TypedArray<PackedByteArray> init_y;
    PackedByteArray blank_y;
    blank_y.resize(static_cast<int64_t>(w * h));
    init_y.push_back(blank_y);

    TypedArray<PackedByteArray> init_uv;
    PackedByteArray blank_uv;
    blank_uv.resize(static_cast<int64_t>(w * h / 2)); // RG8 => w*h/2 bytes
    init_uv.push_back(blank_uv);

    // Y纹理的view：只使用R通道
    Ref<RDTextureView> view_y;
    view_y.instantiate();
    view_y->set_swizzle_r(RenderingDevice::TEXTURE_SWIZZLE_R);
    view_y->set_swizzle_g(RenderingDevice::TEXTURE_SWIZZLE_R); // 复制R到G方便调试
    view_y->set_swizzle_b(RenderingDevice::TEXTURE_SWIZZLE_R); // 复制R到B方便调试
    view_y->set_swizzle_a(RenderingDevice::TEXTURE_SWIZZLE_ONE);

    // UV纹理的view：使用默认的RG通道
    Ref<RDTextureView> view_uv;
    view_uv.instantiate();
    // 默认swizzle即可：R->R, G->G, B->0, A->1

    tex_y_ = rd->texture_create(fmt_y, view_y, init_y);
    tex_uv_ = rd->texture_create(fmt_uv, view_uv, init_uv);
    if (!tex_y_.is_valid() || !tex_uv_.is_valid()) {
        RM_LOGE(kLogTag, "Failed to create textures (RID invalid).");
        return;
    }
    RM_LOGI(kLogTag, "Created textures Y:%dx%d UV:%dx%d", w, h, w/2, h/2);

    tex_y_res_.instantiate();
    tex_y_res_->set_texture_rd_rid(tex_y_);
    tex_uv_res_.instantiate();
    tex_uv_res_->set_texture_rd_rid(tex_uv_);

    RM_LOGI(kLogTag, "tex_y_res valid: %d, tex_uv_res valid: %d", 
            tex_y_res_.is_valid() ? 1 : 0, tex_uv_res_.is_valid() ? 1 : 0);

    if (material_.is_valid()) {
        material_->set_shader_parameter("texture_y", tex_y_res_);
        material_->set_shader_parameter("texture_uv", tex_uv_res_);
        RM_LOGI(kLogTag, "Shader parameters set successfully");
    }
    else{
        RM_LOGW(kLogTag, "Material is not valid when setting textures");
    }

    if (rect_) {
        // 确保应用了 Shader Material
        if (rect_->get_material() != material_) {
            rect_->set_material(material_);
        }
        // 将 Y 纹理设为主纹理
        rect_->set_texture(tex_y_res_);
        set_display_mode(display_mode_);
    }

    tex_w_ = w;
    tex_h_ = h;
    apply_display_layout();
}

void RMVideoCanvas::ensure_textures_rgba(RenderingDevice* rd, int w, int h) {
    if (w <= 0 || h <= 0) {
        RM_LOGE(kLogTag, "Invalid RGBA frame size %dx%d", w, h);
        return;
    }
    if (w == tex_w_ && h == tex_h_ && tex_rgba_.is_valid()) {
        // RM_LOGD(kLogTag, "RGBA texture already valid for %dx%d", w, h);
        return;
    }

    RenderingServer* rs = RenderingServer::get_singleton();
    if (rs && tex_rgba_.is_valid()) rs->free_rid(tex_rgba_);

    Ref<RDTextureFormat> fmt;
    fmt.instantiate();
    fmt->set_format(RenderingDevice::DATA_FORMAT_R8G8B8A8_UNORM);
    fmt->set_width(w);
    fmt->set_height(h);
    fmt->set_usage_bits(RenderingDevice::TEXTURE_USAGE_SAMPLING_BIT | RenderingDevice::TEXTURE_USAGE_CAN_UPDATE_BIT);

    TypedArray<PackedByteArray> init;
    PackedByteArray blank;
    blank.resize(static_cast<int64_t>(w * h * 4));
    init.push_back(blank);

    Ref<RDTextureView> view;
    view.instantiate();
    tex_rgba_ = rd->texture_create(fmt, view, init);
    if (!tex_rgba_.is_valid()) {
        RM_LOGE(kLogTag, "Failed to create RGBA texture");
        return;
    }

    tex_rgba_res_.instantiate();
    tex_rgba_res_->set_texture_rd_rid(tex_rgba_);

    // RGBA 不需要 YUV shader，直接赋值给 TextureRect
    if (rect_) {
        rect_->set_material(Ref<Material>()); // remove shader material
        rect_->set_texture(tex_rgba_res_);
        set_display_mode(display_mode_);
    }

    tex_w_ = w;
    tex_h_ = h;
    apply_display_layout();
}

void RMVideoCanvas::upload_frame(RenderingDevice* rd, const RMVideoDecoder::YuvFrameExtractor::Frame& f) {
    int64_t y_size = static_cast<int64_t>(f.y.size());
    int64_t uv_size = static_cast<int64_t>(f.uv.size());

    // 调试：检查UV数据
    static bool once = false;
    if (!once) {
        RM_LOGI(kLogTag, "UV data size: %d bytes, tex_uv valid: %d", (int)uv_size, tex_uv_.is_valid() ? 1 : 0);
        once = true;
    }

    // 只有当 buffer 大小不够时才 resize，复用内存
    if (buf_y_.size() != y_size) buf_y_.resize(y_size);
    if (buf_uv_.size() != uv_size) buf_uv_.resize(uv_size);

    // 使用 memcpy 直接拷贝到写指针
    std::memcpy(buf_y_.ptrw(), f.y.data(), f.y.size());
    std::memcpy(buf_uv_.ptrw(), f.uv.data(), f.uv.size());

    rd->texture_update(tex_y_, 0, buf_y_);
    rd->texture_update(tex_uv_, 0, buf_uv_);
    // RM_LOGD(kLogTag, "Updated YUV frame %dx%d (Y:%d bytes UV:%d bytes)", f.width, f.height, (int)f.y.size(), (int)f.uv.size());
}

void RMVideoCanvas::upload_frame_rgba(RenderingDevice* rd, const RMVideoDecoder::YuvFrameExtractor::Frame& f) {
    if (!tex_rgba_.is_valid()) {
        RM_LOGE(kLogTag, "RGBA texture not valid");
        return;
    }
    PackedByteArray data;
    data.resize(static_cast<int64_t>(f.rgba.size()));
    std::memcpy(data.ptrw(), f.rgba.data(), f.rgba.size());
    rd->texture_update(tex_rgba_, 0, data);
    // RM_LOGD(kLogTag, "Updated RGBA frame %dx%d (%d bytes)", f.width, f.height, (int)f.rgba.size());
}

void RMVideoCanvas::update_shader_params() {
    if (!material_.is_valid()) return;
    material_->set_shader_parameter("use_bt601", use_bt601_);
    material_->set_shader_parameter("use_tv_range", use_tv_range_);
    // RM_LOGD(kLogTag, "Shader params: bt601=%d tv_range=%d", use_bt601_, use_tv_range_);
}

void RMVideoCanvas::set_display_mode(int m) {
    display_mode_ = m;
    ensure_texture_rect();
    if (!rect_) return;
    apply_display_layout();
}

void RMVideoCanvas::apply_display_layout() {
    ensure_texture_rect();
    if (!rect_) return;
    // Only tweak anchors/stretch. Do NOT call set_size / set_custom_minimum_size to avoid altering rect_ size.
    switch (display_mode_) {
        case DISPLAY_STRETCH:
            rect_->set_anchors_preset(Control::PRESET_FULL_RECT);
            rect_->set_stretch_mode(TextureRect::STRETCH_SCALE);
            break;
        case DISPLAY_ORIGINAL:
            rect_->set_anchors_preset(Control::PRESET_CENTER);
            rect_->set_stretch_mode(TextureRect::STRETCH_KEEP);
            break;
        case DISPLAY_ADAPTIVE:
        default:
            rect_->set_anchors_preset(Control::PRESET_FULL_RECT);
            rect_->set_stretch_mode(TextureRect::STRETCH_KEEP_ASPECT_CENTERED);
            break;
    }
}
