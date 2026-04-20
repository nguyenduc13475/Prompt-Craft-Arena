shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform vec4 shallow_color : source_color = vec4(0.126, 0.303, 0.332, 0.75); 
uniform vec4 deep_color : source_color = vec4(0.076, 0.253, 0.282, 0.95);  
uniform vec4 foam_color : source_color = vec4(0.256, 0.433, 0.472, 0.85);
uniform float flow_speed = 0.3;
uniform float displacement_height = 4.0;

vec2 random2(vec2 p) {
    return fract(sin(vec2(dot(p,vec2(127.1,311.7)),dot(p,vec2(269.5,183.3))))*43758.5453);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f*f*(3.0-2.0*f);
    return mix(mix(dot(random2(i + vec2(0.0,0.0)), f - vec2(0.0,0.0)),
                   dot(random2(i + vec2(1.0,0.0)), f - vec2(1.0,0.0)), f.x),
               mix(dot(random2(i + vec2(0.0,1.0)), f - vec2(0.0,1.0)),
                   dot(random2(i + vec2(1.0,1.0)), f - vec2(1.0,1.0)), f.x), f.y) * 0.5 + 0.5;
}

float fbm(vec2 p) {
    float value = 0.0;
    float amplitude = 0.5;
    float frequency = 1.0;
    mat2 rot = mat2(vec2(0.8, -0.6), vec2(0.6, 0.8));
    for (int i = 0; i < 4; i++) {
        value += amplitude * noise(p * frequency);
        p = rot * p;
        frequency *= 2.0; 
        amplitude *= 0.5;
    }
    return value;
}

// HÀM TÍNH TOÁN ĐỘ CAO VẬT LÝ THỰC TẾ
float get_water_height(vec2 world_xz, float time, float edge_dist) {
    float h1 = fbm(world_xz * 0.05 + vec2(time * 0.8, time * 0.2));
    float h2 = fbm(world_xz * 0.1 - vec2(time * 0.5, time * 1.5));
    
    float ridge = 1.0 - abs(h1 - 0.5) * 2.0; 
    float detail = 1.0 - abs(h2 - 0.5) * 2.0;
    float combined_height = pow(ridge * detail, 0.8);
    
    float shore_surge = noise(world_xz * 0.02 + time * 0.5) * 1.0;
    
    float mask = pow(max(0.0, 1.0 - edge_dist), 1.5) + shore_surge * 0.15;
    
    return combined_height * displacement_height * mask;
}

varying vec2 v_uv;
varying float v_edge_dist;
varying vec3 v_world_pos;
varying float v_real_height;

void vertex() {
    v_uv = UV;
    
    v_edge_dist = 1.0 - COLOR.r; 
    
    v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;

    float real_h = get_water_height(v_world_pos.xz, TIME * flow_speed, v_edge_dist);
    VERTEX.y += real_h; 
    
    v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    v_real_height = real_h;
}

void fragment() {
    float time = TIME * flow_speed;
    vec2 flow_uv = v_world_pos.xz * 0.05; 

    // TÍNH TOÁN NORMAL MAP TỪ ĐỘ CAO VẬT LÝ THẬT
    vec2 e = vec2(0.1, 0.0);
    float h0 = v_real_height;
    float hx = get_water_height(v_world_pos.xz + e.xy, time, v_edge_dist);
    float hz = get_water_height(v_world_pos.xz + e.yx, time, v_edge_dist);
    
    vec3 true_normal = normalize(vec3(h0 - hx, e.x, h0 - hz));
    NORMAL = (VIEW_MATRIX * vec4(true_normal, 0.0)).xyz;

    // NƯỚC TRÀN RÚT ALPHA (Nhẹ nhàng hơn)
    float dynamic_shore = 0.6 + (fbm(flow_uv * 2.5 + time) - 0.5) * 1.0;
    float shore_clip = smoothstep(dynamic_shore, dynamic_shore - 0.15, v_edge_dist);

    // BỌT BỜ (Mỏng lại để lộ màu nước)
    float foam_mask = smoothstep(dynamic_shore - 0.15, dynamic_shore, v_edge_dist); // Viền bọt hẹp lại
    float crisp_foam = step(0.5, foam_mask * fbm(flow_uv * 8.0 - time * 2.0) * 2.0);
    float final_foam = clamp(max(foam_mask * 0.4, crisp_foam), 0.0, 1.0);

    // BỌT ĐỈNH SÓNG (Chỉ xuất hiện khi sóng thực sự lên rất cao)
    float crest_foam = smoothstep(displacement_height * 0.6, displacement_height * 0.9, v_real_height) * 0.6;
    final_foam = clamp(final_foam + crest_foam, 0.0, 1.0);

    // CAUSTICS DƯỚI ĐÁY
    float caustic = step(0.8, fbm(flow_uv * 10.0 + vec2(time * 2.0, -time))) * 0.5 * (1.0 - v_edge_dist);

    // TÔ MÀU
    vec3 water_color = mix(deep_color.rgb, shallow_color.rgb, v_edge_dist);
    ALBEDO = mix(water_color, foam_color.rgb, final_foam);
    EMISSION = shallow_color.rgb * caustic; 

    float base_alpha = mix(deep_color.a, shallow_color.a, v_edge_dist);
    ALPHA = base_alpha * shore_clip;
    ALPHA = max(ALPHA, final_foam * shore_clip * 0.8); // Giảm độ đặc của bọt

    // ÁNH SÁNG
    ROUGHNESS = mix(0.02, 0.8, final_foam); 
    METALLIC = 0.05;
    SPECULAR = 0.8 * shore_clip; 
}