shader_type canvas_item;

uniform sampler2D texture_y : filter_linear;
uniform sampler2D texture_uv : filter_linear;

void fragment() {
    float y_val = texture(texture_y, UV).r;
    vec2 uv_val = texture(texture_uv, UV).rg;
    
    // 标准NV12: R=U, G=V
    float u = uv_val.r - 0.5;
    float v = uv_val.g - 0.5;
    
    // BT.601 矩阵
    vec3 rgb;
    rgb.r = y_val + 1.402 * v;
    rgb.g = y_val - 0.344136 * u - 0.714136 * v;
    rgb.b = y_val + 1.772 * u;
    
    // 交换R和B
    COLOR = vec4(rgb.b, rgb.g, rgb.r, 1.0);
}
