shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform vec4 color_top : source_color = vec4(0.2, 0.6, 0.2, 1.0);
uniform vec4 color_bottom : source_color = vec4(0.05, 0.25, 0.1, 1.0);
uniform float wind_speed = 1.5;
uniform float wind_strength = 0.4;
uniform float blade_width = 0.5;

void vertex() {
    float height_factor = 1.0 - UV.y; 
    
    // Vuốt nhọn ngọn cỏ bằng cách ép Vertex X lại dựa theo độ cao (UV.y)
    VERTEX.x *= mix(blade_width, 0.0, height_factor);
    
    // Tạo sóng gió ngẫu nhiên kết hợp Noise để cỏ rung tự nhiên hơn
    float wind = sin(NODE_POSITION_WORLD.x * 0.8 + TIME * wind_speed) * cos(NODE_POSITION_WORLD.z * 0.8 + TIME * wind_speed * 0.8);
                 
    VERTEX.x += wind * wind_strength * height_factor * height_factor; // Càng lên cao càng lắc mạnh
    VERTEX.z += wind * wind_strength * 0.3 * height_factor;
}

void fragment() {
    vec3 base_color = mix(color_bottom.rgb, color_top.rgb, 1.0 - UV.y);
    ALBEDO = base_color;
    ROUGHNESS = 0.9; // Cỏ ít phản quang
    SPECULAR = 0.1;
    
    // Fake Ambient Occlusion ở gốc cỏ cho tối đi
    ALBEDO *= mix(0.4, 1.0, 1.0 - UV.y);
}