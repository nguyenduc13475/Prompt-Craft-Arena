shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform vec4 color_top : source_color = vec4(0.3, 0.7, 0.2, 1.0);
uniform vec4 color_bottom : source_color = vec4(0.05, 0.25, 0.1, 1.0);
uniform vec4 groove_color : source_color = vec4(0.6, 0.8, 0.1, 1.0); // Vàng xanh rãnh giữa
uniform float wind_speed = 1.5;
uniform float wind_strength = 0.6;

void vertex() {
    // UV.y = 1 ở gốc cỏ, 0 ở ngọn cỏ. Đổi lại để height_factor = 0 ở gốc, 1 ở ngọn
    float height_factor = 1.0 - UV.y; 
    
    // Sóng gió cơ bản lấy theo tọa độ thế giới để cả bãi cỏ đu đưa đồng bộ
    float wind_time = TIME * wind_speed;
    float wind_x = sin(NODE_POSITION_WORLD.x * 0.5 + wind_time) * cos(NODE_POSITION_WORLD.z * 0.5 + wind_time * 0.8);
    float wind_z = cos(NODE_POSITION_WORLD.x * 0.6 + wind_time * 1.2) * sin(NODE_POSITION_WORLD.z * 0.4 + wind_time);
    
    // Gió chỉ tác động mạnh lên ngọn cỏ (height_factor^2 giúp bẻ cong mượt hơn)
    VERTEX.x += wind_x * wind_strength * (height_factor * height_factor);
    VERTEX.z += wind_z * wind_strength * (height_factor * height_factor);
    
    // Bẻ ngọn cỏ oặt xuống đất tự nhiên
    VERTEX.y -= abs(wind_x) * wind_strength * 0.5 * height_factor;
}

void fragment() {
    // Phối màu từ gốc lên ngọn
    vec3 base_color = mix(color_bottom.rgb, color_top.rgb, 1.0 - UV.y);
    
    // --- THÊM SỰ ĐA DẠNG MÀU SẮC (Dựa trên tọa độ World của từng cọng cỏ) ---
    // Sử dụng hàm băm (hash) đơn giản để sinh số ngẫu nhiên từ 0.0 đến 1.0
    float color_variation = fract(sin(dot(NODE_POSITION_WORLD.xz, vec2(12.9898, 78.233))) * 43758.5453);
    
    // Tạo dải màu sáng tối xen kẽ (từ 70% đến 130% độ sáng gốc)
    vec3 varied_color = mix(base_color * 0.7, base_color * 1.3, color_variation);
    
    // Nhấn nhá thêm chút sắc vàng úa ngẫu nhiên ở phần ngọn cỏ
    vec3 yellow_tint = vec3(0.7, 0.7, 0.2);
    varied_color = mix(varied_color, yellow_tint, color_variation * 0.35 * (1.0 - UV.y));
    
    // Tạo rãnh ở giữa lá cỏ (UV.x chạy từ 0 -> 1, giữa là 0.5)
    float groove_mask = 1.0 - smoothstep(0.0, 0.1, abs(UV.x - 0.5));
    float groove_fade = smoothstep(0.0, 0.8, UV.y); // Mờ ở ngọn
    
    vec3 final_color = mix(varied_color, groove_color.rgb, groove_mask * groove_fade * 0.6);
    
    ALBEDO = final_color;
    ROUGHNESS = 0.8; 
    SPECULAR = 0.2;
    
    // Fake Ambient Occlusion cho phần gốc tối đi
    ALBEDO *= mix(0.3, 1.0, 1.0 - UV.y);
}