shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec4 grass_color : source_color = vec4(0.18, 0.35, 0.20, 1.0); // Xanh cỏ tươi
uniform vec4 dirt_color : source_color = vec4(0.35, 0.28, 0.20, 1.0);  // Nâu đất đường mòn
uniform vec4 dark_grass_color : source_color = vec4(0.10, 0.22, 0.12, 1.0); // Xanh đậm cho khu vực rừng

uniform float noise_scale = 0.015;
uniform float height_scale = 3.0;

// Hàm Hash & Noise tiêu chuẩn
float hash(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }

// Value Noise
float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i + vec2(0.0, 0.0)), hash(i + vec2(1.0, 0.0)), u.x),
               mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

// Fractal Brownian Motion (FBM) tạo chi tiết phong cách hand-painted
float fbm(vec2 p) {
    float value = 0.0;
    float amplitude = 0.5;
    for (int i = 0; i < 4; i++) {
        value += amplitude * noise(p);
        p *= 2.0;
        amplitude *= 0.5;
    }
    return value;
}

void vertex() {
    vec2 world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
    float h = fbm(world_pos * noise_scale * 0.5);
    VERTEX.y += h * height_scale;
}

void fragment() {
    vec2 world_pos = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xz;
    
    float n1 = fbm(world_pos * noise_scale);
    float n2 = fbm(world_pos * noise_scale * 3.0 + vec2(5.2, 1.3));
    
    // Stylized blending (Tạo viền sắc nét giữa đất và cỏ thay vì mờ nhòe)
    float mask = smoothstep(0.4, 0.45, n1 + n2 * 0.2);
    float dark_mask = smoothstep(0.65, 0.7, n1);
    
    vec3 final_color = mix(dirt_color.rgb, grass_color.rgb, mask);
    final_color = mix(final_color, dark_grass_color.rgb, dark_mask);
    
    // Đổ bóng fake (Fake Ambient Occlusion từ độ nhấp nhô)
    float fake_ao = smoothstep(0.0, 1.0, n1);
    final_color *= mix(0.7, 1.1, fake_ao);

    ALBEDO = final_color;
    ROUGHNESS = 1.0; 
    SPECULAR = 0.0; // Đất cỏ không phản quang
}