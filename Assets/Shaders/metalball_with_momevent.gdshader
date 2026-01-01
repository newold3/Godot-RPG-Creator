shader_type canvas_item;
render_mode blend_add;

uniform vec2 resolution = vec2(600.0, 400.0);
uniform float speed: hint_range(0.0, 3.0, 0.01) = 1.0;
instance uniform vec2 direction = vec2(0.7, 0.4);
instance uniform vec2 emitter_pos = vec2(0.0, -1.5);
instance uniform int max_balls: hint_range(1, 128) = 32;
instance uniform float anim_offset: hint_range(0.0, 1.0) = 0.0;
instance uniform vec3 inst_color_a: source_color = vec3(0.991, 0.701, 0.815);
instance uniform vec3 inst_color_b: source_color = vec3(0.95, 0.9, 0.9);
instance uniform vec3 inst_color_c: source_color = vec3(0.9, 0.95, 0.9);
uniform float spawn_spread = 0.3;
uniform float min_life = 2.0;
uniform float max_life = 6.0;
uniform float noise_strength: hint_range(0.0, 1.0, 0.01) = 0.4;
uniform float noise_frequency: hint_range(0.5, 5.0, 0.1) = 2.0;
uniform float final_alpha: hint_range(0.0, 2.0, 0.01) = 1.0;
uniform bool clamped = false;

// Improved hash for more varied values
float hash(float n) {
    return fract(sin(n * 43758.5453123) * 43758.5453123);
}

// Perlin-like 1D noise using derivatives
float noise(float x) {
    float i = floor(x);
    float f = fract(x);
    float u = f * f * (3.0 - 2.0 * f);
    float a = hash(i);
    float b = hash(i + 1.0);
    return mix(a, b, u);
}

// 2D noise combining two 1D noises
vec2 noise2d(vec2 p) {
    return vec2(
        noise(p.x * noise_frequency + p.y * 0.3),
        noise(p.y * noise_frequency - p.x * 0.3)
    );
}

float ball(vec2 uv, float radius) {
    return radius / dot(uv, uv);
}

void fragment() {
    vec2 uv = UV * 2.0 - 1.0;
    uv.x *= resolution.x / resolution.y;
    
    vec2 dir = normalize(direction);
    
    vec3 color_field = vec3(0.0);
    float total_influence = 0.0;
    
    for (int i = 0; i < max_balls; i++) {
        float fi = float(i);
        
        // Random values for this metaball
        float rnd1 = hash(fi * 11.3);
        float rnd2 = hash(fi * 31.7);
        float rnd3 = hash(fi * 91.9);
        float rnd4 = hash(fi * 47.2);
        
        float radius = mix(0.015, 0.06, rnd1);
        float life = mix(min_life, max_life, rnd2);
        float delay = rnd3 * life;
        
        // Normalized time (0 to 1) with instance offset
        float t = mod(TIME * speed + delay + anim_offset * 10.0, life) / life;
        
        // Progressive fade in at birth (first 20%) and fade out at death (last 15%)
        float fade_in = smoothstep(0.0, 0.2, t);
        float fade_out = smoothstep(1.0, 0.85, t);
        float fade = fade_in * fade_out;
        
        // Initial position always at emitter
        vec2 start = emitter_pos;
        
        // Base movement from emitter
        vec2 base_pos = start + dir * (t * 4.0);
        
        // Smooth movement variation using Perlin noise (no jumps)
        float noise_x = noise(TIME * speed * 0.5 + fi * 2.1);
        float noise_y = noise(TIME * speed * 0.5 + fi * 3.7);
        
        // Smooth variation to avoid abrupt jumps
        vec2 direction_variation = normalize(vec2(noise_x - 0.5, noise_y - 0.5)) * 0.15;
        base_pos += direction_variation * (t * 4.0);
        
        // Small smooth and continuous lateral oscillations
        vec2 lateral_offset = vec2(
            sin(TIME * speed * 1.2 + fi * 1.23) * 0.06,
            cos(TIME * speed * 0.9 + fi * 4.56) * 0.06
        ) * fade;
        
        vec2 pos = base_pos + lateral_offset;
        
        float influence = ball(uv - pos, radius) * fade;
        
        // Color based on index
        vec3 ball_color;
        int color_index = i % 3;
        if (color_index == 0) {
            ball_color = inst_color_a;
        } else if (color_index == 1) {
            ball_color = inst_color_b;
        } else {
            ball_color = inst_color_c;
        }
        
        color_field += ball_color * influence;
        total_influence += influence;
    }
    
    vec3 final_color = vec3(0.0);
    if (total_influence > 0.001) {
        final_color = color_field / total_influence;
    }
    
    float alpha = smoothstep(0.5, 2.0, total_influence);
    if (clamped) {
        alpha = step(1.0, total_influence);
    }
    
    COLOR = vec4(final_color, alpha * final_alpha);
}