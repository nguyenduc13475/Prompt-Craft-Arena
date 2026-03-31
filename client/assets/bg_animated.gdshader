shader_type canvas_item;

uniform vec4 bg_color : source_color = vec4(0.05, 0.05, 0.08, 1.0);
uniform vec4 grid_color : source_color = vec4(0.0, 0.5, 1.0, 0.2);
uniform float speed = 0.5;

void fragment() {
    vec2 uv = UV;
    // Cuộn chéo background
    uv.y += TIME * speed * 0.1;
    uv.x += TIME * speed * 0.05;
    
    // Tạo lưới (Grid)
    vec2 grid = abs(fract(uv * 10.0) - 0.5) * 2.0;
    float line = smoothstep(0.95, 1.0, max(grid.x, grid.y));
    
    COLOR = mix(bg_color, grid_color, line);
}