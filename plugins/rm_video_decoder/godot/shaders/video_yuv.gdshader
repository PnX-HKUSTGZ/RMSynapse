[gdshader type="canvas_item" language="glsl"]

// Sample shader for Y + UV (NV12/I420 interleaved UV) textures.

uniform sampler2D texture_y : hint_albedo;
uniform sampler2D texture_uv : hint_albedo;

// Set to 1 for BT.601, 0 for BT.709
uniform bool use_bt601 = false;
// Set to true if source is TV range (16-235 / 16-240)
uniform bool use_tv_range = false;

vec3 yuv_to_rgb(float y, vec2 uv) {
    // Adjust range
    if (use_tv_range) {
        y = (y - 16.0 / 255.0) * (255.0 / 219.0);
        uv = (uv - vec2(0.5)) * (255.0 / 224.0);
    } else {
        uv -= vec2(0.5);
    }

    vec3 rgb;
    if (use_bt601) {
        rgb.r = y + 1.4020 * uv.y;
        rgb.g = y - 0.3441 * uv.x - 0.7141 * uv.y;
        rgb.b = y + 1.7720 * uv.x;
    } else { // BT.709
        rgb.r = y + 1.5748 * uv.y;
        rgb.g = y - 0.1873 * uv.x - 0.4681 * uv.y;
        rgb.b = y + 1.8556 * uv.x;
    }
    return rgb;
}

void fragment() {
    float y = texture(texture_y, UV).r;
    vec2 uv = texture(texture_uv, UV).rg;
    vec3 rgb = yuv_to_rgb(y, uv);
    COLOR = vec4(rgb, 1.0);
}
