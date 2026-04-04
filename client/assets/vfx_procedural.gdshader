shader_type spatial;
render_mode blend_add, depth_draw_opaque, cull_disabled, unshaded; // unshaded để vfx luôn sáng

uniform vec4 base_color : source_color = vec4(1.0, 0.5, 0.0, 1.0);
uniform float speed = 3.0;
uniform float noise_scale = 10.0;
uniform sampler2D ugc_texture : source_color; // Nạp hình người chơi vẽ vào đây

float random(vec2 uv) { return fract(sin(dot(uv.xy, vec2(12.9898,78.233))) * 43758.5453123); }

void vertex() {
    // Cấu hình Billboard: Bắt mặt phẳng luôn quay về hướng Camera
    MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
    MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0), vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
    MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

void fragment() {
    vec2 uv = UV;
    float time_scroll = TIME * speed;
    float noise = random(floor(uv * noise_scale) - vec2(time_scroll, time_scroll));
    
    vec4 tex_color = texture(ugc_texture, UV);
    // Nếu UGC chưa có màu (trắng đen), nhuộm bằng base_color của Server
    vec4 final_color = tex_color * base_color;
    
    // Tự động thêm độ mềm ở viền (Feather) để không bị vuông vức
    float dist_to_center = distance(UV, vec2(0.5, 0.5));
    float alpha_mask = smoothstep(0.5, 0.2, dist_to_center);
    
    ALBEDO = final_color.rgb * 2.0; // * 2.0 để tạo hiệu ứng Glow (Cần bật WorldEnvironment Glow)
    ALPHA = tex_color.a * alpha_mask * noise; // Phân rã theo noise
}