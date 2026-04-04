shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec4 water_color : source_color = vec4(0.0, 0.5, 0.8, 0.75);
uniform vec4 foam_color : source_color = vec4(1.0, 1.0, 1.0, 0.9);
uniform float speed = 0.5;

float hash(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i + vec2(0.0, 0.0)), hash(i + vec2(1.0, 0.0)), u.x),
               mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

void fragment() {
    vec2 uv = UV * 5.0;
    uv.y += TIME * speed;
    uv.x += sin(TIME * speed * 0.5) * 0.2;
    
    float n = noise(uv);
    
    // Tạo bọt nước (Foam) ở các vân nhiễu cao
    float is_foam = smoothstep(0.75, 0.8, n);
    
    ALBEDO = mix(water_color.rgb, foam_color.rgb, is_foam);
    ALPHA = water_color.a;
    ROUGHNESS = 0.1;
    SPECULAR = 0.8;
}