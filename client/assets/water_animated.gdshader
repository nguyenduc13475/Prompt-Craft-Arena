shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_burley, specular_schlick_ggx;

// MÀU CHUẨN MOBA: Xanh dương thẫm ở giữa, xanh lơ mờ ở ven bờ
uniform vec4 shallow_color : source_color = vec4(0.0, 0.4, 0.6, 0.65); 
uniform vec4 deep_color : source_color = vec4(0.0, 0.15, 0.4, 0.95);   
uniform vec4 foam_color : source_color = vec4(0.8, 0.95, 1.0, 0.9);
uniform float base_speed = 0.5;
uniform float wave_strength = 0.2;

uniform vec4 river_points[20]; 
uniform int point_count = 0;

varying vec2 v_world_pos;

void vertex() {
    v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

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

void fragment() {
    if (point_count < 2) discard;
    
    float min_dist = 9999.0;
    float current_radius = 1.0;
    vec2 current_flow = vec2(1.0, 0.0);
    
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
    
    // Khoảng cách từ mép sông vào tâm (logic_depth)
    float logic_depth = current_radius - min_dist;
    if (logic_depth <= 0.0) discard;
    
    // --- 1. GỢN SÓNG VÀ DÒNG CHẢY ---
    vec2 flow_uv = v_world_pos * 0.03;
    float time = TIME * base_speed;
    
    // 2 lớp sóng nhiễu trượt theo hướng nước
    float wave1 = sin((flow_uv.x + current_flow.x * time) * 3.0) * cos((flow_uv.y + current_flow.y * time) * 3.0);
    float wave2 = sin((flow_uv.x - current_flow.y * time * 0.5) * 5.0) * cos((flow_uv.y + current_flow.x * time * 0.5) * 5.0);
    float noise = (wave1 + wave2) * 0.5 + 0.5;
    
    // --- 2. PHỐI MÀU BẰNG TOÁN HỌC ---
    // Càng vào giữa sông (logic_depth lớn) thì càng dùng màu Deep Color
    float depth_blend = smoothstep(0.0, current_radius * 0.6, logic_depth);
    vec3 water_color = mix(shallow_color.rgb, deep_color.rgb, depth_blend);
    
    // --- 3. BỌT VEN BỜ (FOAM) ---
    // Đánh bọt ở sát mép sông (logic_depth từ 2 đến 8)
    float foam_mask = smoothstep(0.0, 4.0, logic_depth) * (1.0 - smoothstep(2.0, 8.0, logic_depth));
    foam_mask *= smoothstep(0.4, 0.8, noise); // Đánh tơi bọt
    
    ALBEDO = mix(water_color, foam_color.rgb, foam_mask);
    
    // --- 4. ĐỘ TRONG SUỐT TỰ NHIÊN ---
    float alpha_base = mix(shallow_color.a, deep_color.a, depth_blend);
    ALPHA = clamp(alpha_base + foam_mask, 0.0, 1.0) * smoothstep(0.0, 3.0, logic_depth);
    
    // --- 5. REFLECT SIÊU THỰC ---
    ROUGHNESS = 0.08; // Láng mịn để phản chiếu bầu trời / cây cối
    SPECULAR = 1.0;   // Ăn sáng tối đa
    METALLIC = 0.1;
    
    // Đẩy Normal Map lên để làm méo hình ảnh phản chiếu
    NORMAL_MAP = normalize(vec3(wave1 * wave_strength, wave2 * wave_strength, 1.0));
}