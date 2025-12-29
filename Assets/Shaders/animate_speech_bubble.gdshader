shader_type canvas_item;

uniform vec2 center = vec2(0.5, 0.5);
uniform float radius_x = 0.4;
uniform float radius_y = 0.3;
uniform float border_thickness = 0.02;
uniform vec4 bubble_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 border_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float min_distortion = 0.01;
uniform float max_distortion = 0.05;
uniform float distortion_amplitude = 5.0;
uniform float sharpness = 3.0;
uniform float rotation_speed = 0.05;
uniform float cycled_selected = 5.0;
uniform float sin_mod: hint_range(0.0, 1.0, 0.01) = 0.968;

float random(vec2 st) {
    return fract(sin(dot(st.xy, vec2(12.9898,78.233))) * 43758.5453123);
}

vec4 get_cycle_params(float cycle) {
    vec2 st = vec2(cycle, cycle * 1.234);
    float r1 = random(st);
    float r2 = random(st + 1.0);
    float r3 = random(st + 2.0);
    float r4 = random(st + 3.0);
    return vec4(r1, r2, r3, r4);
}

float varied_wobble(float angle, float time, float cycle) {
    vec4 params = get_cycle_params(cycle);
    
    float freq1 = mix(1.0, 2.0, params.x);
    float freq2 = mix(1.5, 2.5, params.y);
    float freq3 = mix(0.8, 1.8, params.z);
    
    float phase1 = params.w * 6.28;
    float phase2 = params.x * 6.28;
    float phase3 = params.y * 6.28;
    
    float t = time;
    
    float wobble1 = max(0.1, sin(t * freq1 * 6.28 + angle * 8.0 + phase1));
    float wobble2 = max(0.1, sin(t * freq2 * 6.28 + angle * 12.0 + phase2));
    float wobble3 = max(0.1, sin(t * freq3 * 6.28 + angle * 5.0 + phase3));
	
	wobble1 = pow(wobble1, sharpness);
    wobble2 = pow(wobble2, sharpness);
    wobble3 = pow(wobble3, sharpness);
    
    return (wobble1 * 0.6 + wobble2 * 0.3 + wobble3 * 0.2);
}

void fragment() {
    vec2 uv = UV - center;
    vec2 normalized_uv = vec2(uv.x / radius_x, uv.y / radius_y);
    float dist = length(normalized_uv);
    
    float slow_rotation = TIME * rotation_speed;
    vec2 rotated_uv = vec2(
        normalized_uv.x * cos(slow_rotation) - normalized_uv.y * sin(slow_rotation),
        normalized_uv.x * sin(slow_rotation) + normalized_uv.y * cos(slow_rotation)
    );
    
	float s = ((sin(TIME * distortion_amplitude) + 1.0) * 0.5);
	s = max(sin_mod, abs(s)) * sign(s);
	float distortion = min_distortion + s * max_distortion * distortion_amplitude;
    
    float angle = atan(rotated_uv.y, rotated_uv.x);
    float time = -TIME * rotation_speed;
    float wobble = varied_wobble(angle, time, cycled_selected) * distortion;
    
    float outer_radius = 1.0 + wobble;
    float inner_radius = outer_radius - border_thickness / max(radius_x, radius_y);
    
    if (dist < outer_radius) {
        if (dist < inner_radius) {
            COLOR = bubble_color;
        } else {
            COLOR = border_color;
        }
    } else {
        COLOR = vec4(0.0, 0.0, 0.0, 0.0);
    }
}