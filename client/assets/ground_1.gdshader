shader_type spatial;
// Tắt culling vì mặt phẳng model bị lật
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform sampler2D tex_ground_1 : source_color, filter_linear_mipmap, repeat_enable, hint_default_white;
uniform sampler2D tex_ground_2 : source_color, filter_linear_mipmap, repeat_enable, hint_default_transparent;
uniform sampler2D tex_pedestal : source_color, filter_linear_mipmap, repeat_disable, hint_default_transparent;
uniform sampler2D height_map : filter_linear, hint_default_white;

uniform vec2 map_size = vec2(1000.0, 1000.0);
uniform float bump_strength = 3.0;
uniform vec4 global_tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);

varying vec3 world_pos;
varying vec2 world_uv;
// Hàm tính toán vùng mờ viền (feather)
float get_feather_weight(vec2 local_uv, float feather) {
    // Dùng smoothstep để tạo viền mờ. 
    // Ví dụ feather = 0.15 -> 15% viền ngoài sẽ mờ, phần lõi giữa giữ nguyên 100%
    float wx = smoothstep(0.0, feather, local_uv.x) * smoothstep(1.0, 1.0 - feather, local_uv.x);
    float wy = smoothstep(0.0, feather, local_uv.y) * smoothstep(1.0, 1.0 - feather, local_uv.y);
    return wx * wy;
}
void vertex() {
    world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    world_uv = vec2(world_pos.x / map_size.x, world_pos.z / map_size.y);
}

void fragment() {
    vec3 color_base = texture(tex_ground_1, world_uv).rgb;
    
    // --- BẮT ĐẦU: THUẬT TOÁN KHỬ SEAM CHO G2 ---
    vec2 g2_uv = world_uv * 5.0;
    float feather = 0.1; 
    
    // Lấy tọa độ Local (từ 0.0 đến 1.0) của 4 lưới đan xen (offset 0.5)
    vec2 luv1 = fract(g2_uv);
    vec2 luv2 = fract(g2_uv + vec2(0.5, 0.0));
    vec2 luv3 = fract(g2_uv + vec2(0.0, 0.5));
    vec2 luv4 = fract(g2_uv + vec2(0.5, 0.5));

    // Tính Weight cho từng lớp dựa trên độ gần viền
    float w1 = get_feather_weight(luv1, feather);
    float w2 = get_feather_weight(luv2, feather);
    float w3 = get_feather_weight(luv3, feather);
    float w4 = get_feather_weight(luv4, feather);

    // Lấy màu từ 4 lớp. (Sử dụng đúng tọa độ đã offset)
    vec3 c1 = texture(tex_ground_2, g2_uv).rgb;
    
    // MẸO: Ở các lớp bọc lót, ta lật ngược tọa độ (-g2_uv) hoặc hoán đổi X Y (g2_uv.yx) 
    // Điều này không chỉ giấu Seam mà còn phá luôn sự lặp lại (repetition) của hoa văn!
    vec3 c2 = texture(tex_ground_2, vec2(-g2_uv.x, g2_uv.y) + vec2(0.5, 0.0)).rgb;
    vec3 c3 = texture(tex_ground_2, vec2(g2_uv.x, -g2_uv.y) + vec2(0.0, 0.5)).rgb;
    vec3 c4 = texture(tex_ground_2, vec2(-g2_uv.y, -g2_uv.x) + vec2(0.5, 0.5)).rgb;

    // Trộn lại và chuẩn hóa (chia cho tổng weight để màu không bị chói sáng ở phần giao nhau)
    vec3 color_g2 = (c1 * w1 + c2 * w2 + c3 * w3 + c4 * w4) / (w1 + w2 + w3 + w4);
    color_g2 = mix(color_g2, vec3(0.0, 0.5, 0.5), 0.02);
    color_g2 = clamp((color_g2 - 0.5) * 1.04 + 0.5, 0.0, 1.0);
    // --- KẾT THÚC KHỬ SEAM ---
    
    // Phần còn lại của bạn giữ nguyên...
    float dist_t1 = distance(world_pos.xz, vec2(0.0, 1000.0));
    float dist_t2 = distance(world_pos.xz, vec2(1000.0, 0.0));
    float min_dist_base = min(dist_t1, dist_t2);

    float blend_g2 = 1.0 - smoothstep(300.0, 450.0, min_dist_base);
    vec3 final_color = mix(color_base, color_g2, blend_g2);

    float p_radius = 100.0;
    vec2 p1_center = vec2(50.0, 950.0);
    vec2 p2_center = vec2(950.0, 50.0);

    vec4 color_pedestal = vec4(0.0);
    if (distance(world_pos.xz, p1_center) < p_radius) {
        vec2 p_uv = (world_pos.xz - (p1_center - vec2(p_radius))) / (p_radius * 2.0);
        color_pedestal = texture(tex_pedestal, p_uv);
    } else if (distance(world_pos.xz, p2_center) < p_radius) {
        vec2 p_uv = (world_pos.xz - (p2_center - vec2(p_radius))) / (p_radius * 2.0);
        color_pedestal = texture(tex_pedestal, p_uv);
    }

    final_color = mix(final_color, color_pedestal.rgb, color_pedestal.a);

    ALBEDO = final_color * global_tint.rgb;
    ROUGHNESS = 0.95;
    SPECULAR = 0.05;

    vec2 e = vec2(1.0 / 2000.0, 0.0); // Chỉnh step theo scale thật của Model
    float h0 = texture(height_map, world_uv).r * 255.0;
    float hx = texture(height_map, world_uv + e.xy).r * 255.0;
    float hz = texture(height_map, world_uv + e.yx).r * 255.0;

    // Ép vector Y cao lên (8.0) để mặt phẳng lật ngửa cũng bắt được ánh sáng
    vec3 fake_normal = normalize(vec3((h0 - hx) * bump_strength, 8.0, (h0 - hz) * bump_strength));
    NORMAL = normalize((VIEW_MATRIX * vec4(fake_normal, 0.0)).xyz);
}