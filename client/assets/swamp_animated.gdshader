shader_type spatial;
// Sử dụng depth_draw_opaque để không bị lỗi Z-fighting khi đè lên nhau
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform vec4 mud_color_1 : source_color = vec4(0.005, 0.005, 0.005, 0.9); // Nâu rất thẫm (đáy sâu)
uniform vec4 mud_color_2 : source_color = vec4(0.03, 0.01, 0.01, 0.8); // Nâu sẫm
uniform vec4 mud_color_3 : source_color = vec4(0.05, 0.04, 0.02, 0.7); // Nâu đỏ cam
uniform vec4 mud_color_4 : source_color = vec4(0.1, 0.2, 0.1, 0.7); // Nâu trung tính
uniform vec4 mud_color_5 : source_color = vec4(0.3, 0.3, 0.18, 0.9); // Nâu nhạt (mảng bùn nổi li ti)
uniform vec4 bubble_color : source_color = vec4(0.70, 0.40, 0.20, 0.8); // Bong bóng sáng rực
uniform float flow_speed = 0.25; // Nhanh gấp đôi bản cũ
uniform float displacement_height = 5.0; // Sục sôi, nhấp nhô cực mạnh

varying vec3 v_world_pos;
varying float v_edge_dist;

// Hàm Hash 2D siêu tốc
vec2 hash2(vec2 p) {
    p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
    return fract(sin(p) * 43758.5453123);
}

// 2D Value Noise
float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(dot(hash2(i + vec2(0.0, 0.0)), f - vec2(0.0, 0.0)),
                   dot(hash2(i + vec2(1.0, 0.0)), f - vec2(1.0, 0.0)), u.x),
               mix(dot(hash2(i + vec2(0.0, 1.0)), f - vec2(0.0, 1.0)),
                   dot(hash2(i + vec2(1.0, 1.0)), f - vec2(1.0, 1.0)), u.x), u.y) * 0.5 + 0.5;
}

// FBM 6 Lớp (Tăng từ 5 lên 6 để hạt fine grain sắc nét hơn)
float fbm(vec2 p) {
    float v = 0.0; float a = 0.5;
    mat2 rot = mat2(vec2(0.8, -0.6), vec2(0.6, 0.8));
    for (int i = 0; i < 6; ++i) {
        v += a * noise(p); p = rot * p * 2.0; a *= 0.5;
    }
    return v;
}

void vertex() {
    v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    v_edge_dist = 1.0 - COLOR.r; 

    // DISPLACEMENT BẠO LỰC: Dùng pow() để ép các đỉnh nhọn vút lên và các rãnh sâu hoắm xuống
    float d_noise = fbm(v_world_pos.xz * 0.08 + TIME * flow_speed);
    d_noise = pow(d_noise, 1.5); 
    
    // Ép phẳng khi ra tới mép vật lý
    float mask = smoothstep(1.0, 0.4, v_edge_dist);
    VERTEX.y += d_noise * displacement_height * mask;
}

void fragment() {
    vec2 uv = v_world_pos.xz * 0.03; 
    float t = TIME * flow_speed;

    // --- 1. LỚP BÙN XÔ ĐẨY NHAU DỮ DỘI KÈM FINE GRAIN ---
    // Thêm layer noise n4 với tần số cao để tạo hạt/mảng nhỏ đan xen
    float n1 = fbm(uv + vec2(t, t * 0.6));
    float n2 = fbm(uv * 2.5 - vec2(t * 1.5, -t * 0.5));
    float n3 = fbm(uv * 4.5 + vec2(-t, t * 1.2));
    float n4 = fbm(uv * 10.0 + vec2(t * 2.0, t * 0.8)); // Layer noise mới mịn hơn

    // Đan xen 5 màu nâu tạo độ sâu và phức tạp
    vec3 mud = mix(mud_color_1.rgb, mud_color_2.rgb, smoothstep(0.5, 0.7, n1));
    mud = mix(mud, mud_color_3.rgb, n2 * 0.85);
    mud = mix(mud, mud_color_4.rgb, n3 * 0.7); 
    mud = mix(mud, mud_color_5.rgb, n4 * 0.6); // Phủ hạt nâu nhạt nổi lên trên

    // --- 2. BONG BÓNG LỤP BỤP (RIM & CORE) ---
    float b_noise = noise(uv * 35.0 - vec2(0.0, t * 2.5));
    // Tạo vành ngoài (Rim)
    float bubble_ring = smoothstep(0.70, 0.85, b_noise) - smoothstep(0.85, 0.95, b_noise);
    // Tạo lõi trong (Core) sắp nổ
    float bubble_core = smoothstep(0.88, 1.0, b_noise);
    // Nhịp đập nổ (Pop)
    float pop = sin(uv.x * 120.0 + t * 20.0) * 0.5 + 0.5; 
    
    float final_bubbles = (bubble_ring * 0.9 + bubble_core * 1.5) * pop * (n1 + 0.3);
    mud = mix(mud, bubble_color.rgb, clamp(final_bubbles, 0.0, 1.0));

    // --- 3. EROSION MASK: RÌA LỬA MẶT TRỜI (TĂNG ĐỘ DÀY VIỀN MỜ) ---
    // Tần số cực cao, dao động cực mạnh
    float flare = fbm(uv * 15.0 - vec2(t * 1.5, t * 2.0)); 
    
    // Threshold dancing: Biên độ nhảy múa từ 0.2 đến 0.9.
    float threshold = 0.2 + flare * 0.7; 
    float alpha_mask = 1.0 - smoothstep(threshold - 0.15, threshold + 0.35, v_edge_dist);

    ALBEDO = mud;
    ALPHA = alpha_mask * 0.85;

    // --- 4. ÁNH SÁNG & NORMAL MAP SÂU ---
    // Bùn khô nhám ráp, bong bóng bóng loáng như kim loại chói
    ROUGHNESS = mix(mix(0.95, 0.6, n2), 0.05, final_bubbles); 
    SPECULAR = mix(0.05, 1.0, final_bubbles);
    METALLIC = mix(0.0, 0.4, final_bubbles);
    
    // Normal Fake gắt hơn 
    vec2 e = vec2(0.03, 0.0);
    float h0 = fbm(uv);
    float hx = fbm(uv + e.xy);
    float hy = fbm(uv + e.yx);
    vec3 normal_fake = normalize(vec3(h0 - hx, 0.3, h0 - hy)); 
    
    // Thêm normal nổi cục tại vị trí bong bóng
    vec3 bubble_normal = normalize(vec3(-bubble_ring, 1.0, bubble_ring));
    normal_fake = normalize(mix(normal_fake, bubble_normal, final_bubbles * 0.5));
    
    NORMAL = normalize(VIEW_MATRIX * vec4(normal_fake, 0.0)).xyz;
}