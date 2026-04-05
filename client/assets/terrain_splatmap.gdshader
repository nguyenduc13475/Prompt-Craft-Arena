shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec4 grass_color : source_color = vec4(0.12, 0.22, 0.15, 1.0);
uniform vec4 dirt_color : source_color = vec4(0.30, 0.25, 0.20, 1.0);
uniform vec4 rock_color : source_color = vec4(0.08, 0.1, 0.12, 1.0);
uniform vec4 river_bed_color : source_color = vec4(0.05, 0.15, 0.22, 1.0);
uniform vec4 grid_color : source_color = vec4(0.0, 0.0, 0.0, 0.15);

uniform float noise_scale = 0.02;

// Hàm tạo Noise tự nhiên
vec2 random2(vec2 p) {
    return fract(sin(vec2(dot(p,vec2(127.1,311.7)),dot(p,vec2(269.5,183.3))))*43758.5453);
}

float voronoi(vec2 x) {
    vec2 n = floor(x);
    vec2 f = fract(x);
    float res = 8.0;
    for(int j=-1; j<=1; j++)
    for(int i=-1; i<=1; i++) {
        vec2 g = vec2(float(i),float(j));
        vec2 o = random2(n + g);
        vec2 r = g + o - f;
        float d = dot(r,r);
        res = min(res, d);
    }
    return sqrt(res);
}

// Hàm tính khoảng cách đến đường thẳng dầy (Capsule)
float sdCapsule( vec2 p, vec2 a, vec2 b, float r ) {
    vec2 pa = p - a, ba = b - a;
    float h = clamp( dot(pa,ba)/dot(ba,ba), 0.0, 1.0 );
    return length( pa - ba*h ) - r;
}

void fragment() {
    vec2 uv = UV; 
    vec2 world_pos = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xz;
    
    // Tạo 2 lớp noise để pha trộn tự nhiên
    float n_base = voronoi(world_pos * noise_scale);
    float n_detail = voronoi(world_pos * noise_scale * 4.0);
    float noise_blend = (n_base * 0.6) + (n_detail * 0.4);

    // --- VẼ 3 ĐƯỜNG (Lanes) ---
    // Độ dầy đường đi r = 0.04 (~40 world units)
    float r_lane = 0.04;
    
    // Top Lane
    float d_top1 = sdCapsule(uv, vec2(0.1, 0.9), vec2(0.1, 0.1), r_lane);
    float d_top2 = sdCapsule(uv, vec2(0.1, 0.1), vec2(0.9, 0.1), r_lane);
    float top_lane = min(d_top1, d_top2);
    
    // Bot Lane
    float d_bot1 = sdCapsule(uv, vec2(0.1, 0.9), vec2(0.9, 0.9), r_lane);
    float d_bot2 = sdCapsule(uv, vec2(0.9, 0.9), vec2(0.9, 0.1), r_lane);
    float bot_lane = min(d_bot1, d_bot2);
    
    // Mid Lane
    float mid_lane = sdCapsule(uv, vec2(0.1, 0.9), vec2(0.9, 0.1), r_lane);
    
    float lanes = min(min(top_lane, bot_lane), mid_lane);
    
    // Dùng smoothstep kết hợp noise để làm mờ viền đường (không bị vuông vức)
    float path_mask = 1.0 - smoothstep(0.0, 0.03 + (noise_blend * 0.05), lanes);

    // --- VẼ SÔNG (River) ---
    float river_dist = sdCapsule(uv, vec2(0.0, 0.0), vec2(1.0, 1.0), 0.05);
    float river_mask = 1.0 - smoothstep(0.0, 0.06 + (noise_blend * 0.04), river_dist);

    // --- VẼ CĂN CỨ (Base) ---
    float base1 = 1.0 - smoothstep(0.0, 0.15, distance(uv, vec2(0.1, 0.9)));
    float base2 = 1.0 - smoothstep(0.0, 0.15, distance(uv, vec2(0.9, 0.1)));
    float base_mask = max(base1, base2);
    path_mask = max(path_mask, base_mask); // Nhập căn cứ vào đường đi

    // --- RỪNG (Jungle) ---
    float jungle_mask = smoothstep(0.4, 0.7, noise_blend);

    // --- PHỐI MÀU (Stylized Blending) ---
    vec3 final_color = mix(grass_color.rgb, grass_color.rgb * 0.7, n_detail); // Cỏ lốm đốm
    
    final_color = mix(final_color, rock_color.rgb, jungle_mask * 0.5); // Thêm mảng tối cho rừng
    final_color = mix(final_color, dirt_color.rgb, path_mask); // Đè đường đất lên
    final_color = mix(final_color, river_bed_color.rgb, river_mask); // Đè sông lên cùng
    
    // --- VẼ LƯỚI TỌA ĐỘ ẨN (Làm map trông chuyên nghiệp hơn) ---
    vec2 grid = abs(fract(world_pos * 0.05) - 0.5) * 2.0;
    float line = smoothstep(0.9, 1.0, max(grid.x, grid.y));
    final_color = mix(final_color, grid_color.rgb, line * 0.3 * (1.0 - river_mask));

    ALBEDO = final_color;
    
    // Tinh chỉnh độ bóng (Sông thì bóng, đất cỏ thì nhám)
    ROUGHNESS = mix(mix(0.9, 0.95, path_mask), 0.4, river_mask); 
    SPECULAR = mix(0.1, 0.5, river_mask);
}