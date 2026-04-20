shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform vec4 water_color : source_color = vec4(0.1, 0.4, 0.35, 0.6); // Xanh rêu tối
uniform float speed = 0.3;
uniform vec2 bush_size = vec2(40.0, 40.0);

// Hàm hash 2D tạo noise
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

// Distance Field bo góc tròn
float roundedBoxSDF(vec2 CenterPosition, vec2 Size, float Radius) {
    return length(max(abs(CenterPosition) - Size + Radius, 0.0)) - Radius;
}

void fragment() {
    // Chuyển UV về hệ tọa độ thế giới (thực tế của bụi cỏ)
    vec2 local_pos = (UV - 0.5) * bush_size;
    
    // Tạo sóng gợn lăn tăn nhẹ nhàng
    float wave = noise(local_pos * 0.2 + TIME * speed);
    
    // Tính khoảng cách bo góc (Radius bo góc = 1/3 kích thước bụi)
    float radius = min(bush_size.x, bush_size.y) * 0.3;
    float dist = roundedBoxSDF(local_pos, bush_size * 0.5, radius);
    
    // Dùng noise để gặm nhấm viền nước, giúp vũng nước trông tự nhiên hơn
    float edge_noise = noise(local_pos * 0.5 - TIME * 0.1) * 5.0;
    
    // Viền mờ dần
    float alpha_mask = 1.0 - smoothstep(-5.0, 5.0 + edge_noise, dist);
    
    ALBEDO = water_color.rgb;
    ALPHA = water_color.a * alpha_mask * (0.8 + wave * 0.2);
    
    ROUGHNESS = 0.1;
    SPECULAR = 0.5;
}