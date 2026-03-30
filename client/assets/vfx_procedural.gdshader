shader_type canvas_item;

uniform vec4 base_color : source_color = vec4(1.0, 0.5, 0.0, 1.0);
uniform float speed = 5.0;
uniform float noise_scale = 15.0;
uniform int vfx_mode = 0; // 0: Lửa/Năng lượng, 1: Băng/Điện

float random(vec2 uv) {
    return fract(sin(dot(uv.xy, vec2(12.9898,78.233))) * 43758.5453123);
}

void fragment() {
    vec2 uv = UV;
    float time_scroll = TIME * speed;
    float noise = random(floor(uv * noise_scale) - vec2(time_scroll, time_scroll));
    
    // Lấy màu từ Texture UGC đã vẽ (nếu có, không thì mặc định là trắng tinh)
    vec4 tex_color = texture(TEXTURE, UV);
    
    // Pha trộn hình vẽ UGC với màu Base của Shader hệ thống
    vec4 final_color = tex_color * base_color;
    
    // Áp noise vào độ trong suốt tạo hiệu ứng phân rã ma thuật
    final_color.a *= noise; 
    
    // Tạo Soft Circle
    float dist_to_center = distance(UV, vec2(0.5, 0.5));
    final_color.a *= smoothstep(0.5, 0.2, dist_to_center);
    
    // Hiệu ứng Glow/Phát sáng ở trung tâm
    final_color.rgb += final_color.rgb * (1.0 - dist_to_center) * 2.0;

    COLOR = final_color;
}