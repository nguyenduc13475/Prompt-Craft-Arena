shader_type spatial;
// BẮT BUỘC: depth_draw_always để SSR nhận diện bề mặt trong suốt
render_mode blend_mix, depth_draw_always, cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform vec4 shallow_color : source_color = vec4(0.1, 0.5, 0.7, 0.6); 
uniform vec4 deep_color : source_color = vec4(0.02, 0.2, 0.45, 0.9);   
uniform vec4 foam_color : source_color = vec4(0.9, 0.95, 1.0, 0.8);
uniform float base_speed = 0.6;
uniform float wave_strength = 0.4;

uniform vec4 river_points[20]; 
uniform int point_count = 0;

// Truyền dữ liệu từ Vertex sang Fragment để tối ưu hiệu năng
varying vec2 v_world_pos;
varying float v_logic_depth;
varying vec2 v_flow_dir;
varying float v_edge_noise;

// Hàm tạo noise tự nhiên
float random(vec2 p) {
    return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

// Tính khoảng cách SDF tới đoạn thẳng (Capsule)
void sdCapsuleAndDir(vec2 p, vec2 a, vec2 b, float rA, float rB, out float dist, out float r, out vec2 flow_dir) {
    vec2 pa = p - a, ba = b - a;
    float dot_ba_ba = dot(ba, ba);
    float h = 0.0;
    if (dot_ba_ba > 0.0001) {
        h = clamp(dot(pa, ba) / dot_ba_ba, 0.0, 1.0);
    }
    vec2 closest_pt = a + ba * h;
    dist = length(p - closest_pt);
    r = mix(rA, rB, h); 
    
    if (dot_ba_ba > 0.0001) {
        flow_dir = normalize(ba); 
    } else {
        flow_dir = vec2(1.0, 0.0);
    }
}

void vertex() {
    v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
    
    if (point_count < 2) {
        v_logic_depth = -1.0;
        return;
    }
    
    float min_dist = 9999.0;
    float current_radius = 1.0;
    vec2 current_flow = vec2(1.0, 0.0);
    
    // Tìm đoạn sông gần nhất
    for(int i = 0; i < 19; i++) {
        if (i >= point_count - 1) break; 
        
        vec2 p1 = river_points[i].xy; float r1 = river_points[i].z;
        vec2 p2 = river_points[i+1].xy; float r2 = river_points[i+1].z;
        
        float d, r; vec2 dir;
        sdCapsuleAndDir(v_world_pos, p1, p2, r1, r2, d, r, dir);
        
        if (d < min_dist) {
            min_dist = d; current_radius = r; current_flow = dir;
        }
    }
    
    // Tạo noise xé rách bờ sông để bớt giả trân
    v_edge_noise = random(floor(v_world_pos * 0.05)) * 12.0;
    v_logic_depth = current_radius - (min_dist + v_edge_noise);
    v_flow_dir = current_flow;
    
    // TẠO SÓNG VẬT LÝ NƯỚC (Chỉ nhấp nhô ở giữa sông, ven bờ dẹp lép)
    if (v_logic_depth > 0.0) {
        float time = TIME * base_speed;
        // Chia nhỏ sóng ra (tần số cao hơn) để khớp với scale của Tướng
        float wave = sin(v_world_pos.x * 0.3 + time) * cos(v_world_pos.y * 0.3 + time * 0.8);
        
        // QUAN TRỌNG NHẤT: Ép bẹp sóng khi gần bờ (khoảng cách < 8.0 units)
        float shore_flatten = smoothstep(0.0, 8.0, v_logic_depth);
        VERTEX.y += wave * 1.5 * shore_flatten; 
    }
}

void fragment() {
    // Cắt bỏ phần không phải sông
    if (v_logic_depth <= 0.0) discard; 
    
    vec2 flow_uv = v_world_pos * 0.05; // Thu nhỏ vân nước
    float time = TIME * base_speed;
    
    // Layer sóng 1 trôi theo dòng
    float wave1 = sin((flow_uv.x + v_flow_dir.x * time) * 3.0) * cos((flow_uv.y + v_flow_dir.y * time) * 3.0);
    // Layer sóng 2 trôi chéo tạo nhiễu ngẫu nhiên
    float wave2 = sin((flow_uv.x - v_flow_dir.y * time * 0.5) * 5.0) * cos((flow_uv.y + v_flow_dir.x * time * 0.5) * 5.0);
    float noise_tex = (wave1 + wave2) * 0.5 + 0.5;
    
    // Pha màu nước: Nông -> Sâu
    float depth_blend = smoothstep(0.0, 25.0, v_logic_depth);
    vec3 water_color = mix(shallow_color.rgb, deep_color.rgb, depth_blend);
    
    // Bọt biển đập vào bờ: Nằm sát bờ (depth từ 0 -> 4) + ngẫu nhiên xé bọt
    float foam_mask = smoothstep(0.0, 3.0, v_logic_depth) * (1.0 - smoothstep(1.0, 5.0, v_logic_depth));
    foam_mask *= smoothstep(0.4, 0.8, noise_tex); // Bọt đứt đoạn theo sóng
    
    ALBEDO = mix(water_color, foam_color.rgb, foam_mask);
    
    // Alpha cũng mờ dần khi sát mép đất để hòa quyện không bị vạch kẻ cứng
    float alpha_edge = smoothstep(0.0, 2.0, v_logic_depth);
    ALPHA = clamp(mix(shallow_color.a, deep_color.a, depth_blend) + foam_mask, 0.0, 1.0) * alpha_edge;
    
    // ĐỂ SSR (BÓNG PHẢN CHIẾU) HOẠT ĐỘNG HOÀN HẢO
    METALLIC = 1.0;   // Mặt nước là tấm gương
    ROUGHNESS = 0.02; // Độ nhám cực thấp để soi rõ Huan Rose
    SPECULAR = 1.0;
    
    // Normal map tự tạo từ wave để bóng phản chiếu bị bẻ cong lấp lánh
    NORMAL_MAP = normalize(vec3(wave1 * wave_strength, wave2 * wave_strength, 1.0));
}