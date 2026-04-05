shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec4 shallow_color : source_color = vec4(0.1, 0.6, 0.8, 0.7);
uniform vec4 deep_color : source_color = vec4(0.0, 0.2, 0.5, 0.9);
uniform vec4 foam_color : source_color = vec4(0.9, 0.95, 1.0, 0.8);
uniform float speed = 0.3;

// Hàm tạo vân nước kiểu Voronoi (Caustics)
vec2 random2(vec2 p) {
    return fract(sin(vec2(dot(p,vec2(127.1,311.7)),dot(p,vec2(269.5,183.3))))*43758.5453);
}

float water_caustics(vec2 p) {
    vec2 n = floor(p);
    vec2 f = fract(p);
    float res = 8.0;
    for(int j=-1; j<=1; j++)
    for(int i=-1; i<=1; i++) {
        vec2 g = vec2(float(i),float(j));
        vec2 o = random2(n + g);
        o = 0.5 + 0.5*sin(TIME * speed + 6.2831*o); // Chuyển động lấp lánh
        vec2 r = g + o - f;
        float d = dot(r,r);
        res = min(res, d);
    }
    return sqrt(res);
}

void fragment() {
    vec2 uv = UV * 8.0;
    uv.y += TIME * speed * 0.5;
    
    float c1 = water_caustics(uv);
    float c2 = water_caustics(uv * 1.5 + vec2(TIME * 0.2));
    
    // Trộn 2 lớp caustics tạo độ sâu
    float caustics = c1 * c2 * 2.0;
    
    // Viền bọt nước trắng (Fake edge foam)
    float edge_mask = smoothstep(0.4, 0.5, caustics);
    
    // Màu nước theo độ sâu (Fake)
    vec3 final_color = mix(deep_color.rgb, shallow_color.rgb, caustics);
    final_color = mix(final_color, foam_color.rgb, edge_mask * 0.5);
    
    ALBEDO = final_color;
    ALPHA = mix(deep_color.a, shallow_color.a, caustics);
    ROUGHNESS = 0.05; // Mặt nước bóng
    SPECULAR = 1.0;
    
    // Gợn sóng Normal
    NORMAL_MAP = vec3(c1, c2, 1.0);
}