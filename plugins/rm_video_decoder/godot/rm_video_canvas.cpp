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
    ClassDB::bind_method(D_METHOD("get_display_mode"), &RMVideoCanvas::get_display_mode);
    ClassDB::bind_method(D_METHOD("set_display_mode", "mode"), &RMVideoCanvas::set_display_mode);

    ADD_PROPERTY(PropertyInfo(Variant::INT, "port"), "set_port", "get_port");
    ADD_PROPERTY(PropertyInfo(Variant::BOOL, "use_bt601"), "set_use_bt601", "get_use_bt601");
    ADD_PROPERTY(PropertyInfo(Variant::BOOL, "use_tv_range"), "set_use_tv_range", "get_use_tv_range");
    ADD_PROPERTY(PropertyInfo(Variant::INT, "display_mode", PROPERTY_HINT_ENUM, "Adaptive(keep_aspect),Stretch,Original"), "set_display_mode", "get_display_mode");
}

void RMVideoCanvas::_ready() {
    rm::common::log::godot::install_global_sink();
    extractor_.set_port(port_);
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

void RMVideoCanvas::_process(double) {
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
        return; // no new frame is not an error
    }
    idle_counter = 0;

    if (frame_.layout == RMVideoDecoder::YuvFrameExtractor::UVLayout::RGBA) {
        ensure_textures_rgba(rd, frame_.width, frame_.height);
        upload_frame_rgba(rd, frame_);
    } else {
        ensure_textures(rd, frame_.width, frame_.height);
        upload_frame(rd, frame_);
        if (material_.is_valid()) update_shader_params();
    }
}

void RMVideoCanvas::ensure_texture_rect() {
    if (!rect_) {
        rect_ = memnew(TextureRect);
        rect_->set_anchors_preset(Control::LayoutPreset::PRESET_FULL_RECT);
        rect_->set_stretch_mode(TextureRect::STRETCH_KEEP_ASPECT_CENTERED);
        rect_->set_expand_mode(TextureRect::EXPAND_IGNORE_SIZE); // keep size driven by parent layout
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
        RM_LOGD(kLogTag, "Textures already valid for %dx%d", w, h);
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

    Ref<RDTextureView> view;
    view.instantiate();

    tex_y_ = rd->texture_create(fmt_y, view, init_y);
    tex_uv_ = rd->texture_create(fmt_uv, view, init_uv);
    if (!tex_y_.is_valid() || !tex_uv_.is_valid()) {
        RM_LOGE(kLogTag, "Failed to create textures (RID invalid).");
        return;
    }
    RM_LOGI(kLogTag, "Created textures Y:%dx%d UV:%dx%d", w, h, w/2, h/2);

    tex_y_res_.instantiate();
    tex_y_res_->set_texture_rd_rid(tex_y_);
    tex_uv_res_.instantiate();
    tex_uv_res_->set_texture_rd_rid(tex_uv_);

    if (material_.is_valid()) {
        material_->set_shader_parameter("texture_y", tex_y_res_);
        material_->set_shader_parameter("texture_uv", tex_uv_res_);
    }
    else{
        RM_LOGW(kLogTag, "Material is not valid when setting textures");
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
        RM_LOGD(kLogTag, "RGBA texture already valid for %dx%d", w, h);
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
    PackedByteArray ydata;
    ydata.resize(static_cast<int64_t>(f.y.size()));
    std::memcpy(ydata.ptrw(), f.y.data(), f.y.size());
    rd->texture_update(tex_y_, 0, ydata);

    PackedByteArray uvdata;
    uvdata.resize(static_cast<int64_t>(f.uv.size()));
    std::memcpy(uvdata.ptrw(), f.uv.data(), f.uv.size());
    rd->texture_update(tex_uv_, 0, uvdata);
    RM_LOGD(kLogTag, "Updated frame %dx%d (Y=%d bytes UV=%d bytes)", f.width, f.height, (int)f.y.size(), (int)f.uv.size());
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
    RM_LOGD(kLogTag, "Updated RGBA frame %dx%d (%d bytes)", f.width, f.height, (int)f.rgba.size());
}

void RMVideoCanvas::update_shader_params() {
    if (!material_.is_valid()) return;
    material_->set_shader_parameter("use_bt601", use_bt601_);
    material_->set_shader_parameter("use_tv_range", use_tv_range_);
    RM_LOGD(kLogTag, "Shader params: bt601=%d tv_range=%d", use_bt601_, use_tv_range_);
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
