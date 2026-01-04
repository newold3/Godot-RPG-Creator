shader_type canvas_item;

uniform vec2 center = vec2(0.5, 0.5);
uniform float time_factor = 1.0;
uniform float distortion_strength = 0.03;
uniform float wave_count = 10.0;
uniform float wave_speed = 5.0;
uniform float ring_width = 0.05;
uniform vec4 ripple_color : source_color = vec4(1.0, 1.0, 1.0, 0.4);
uniform float spawn_rate = 2.0;

void fragment() {
    // Calculate distance to center
    vec2 diff = UV - center;
    float dist = length(diff);
    
    // Calculate max distance to edge (90% of the way to the nearest edge)
    float max_distance = min(min(center.x, 1.0 - center.x), min(center.y, 1.0 - center.y)) * 0.9;
    
    // Calculate alpha based on distance
    float alpha = 1.0 - smoothstep(0.0, max_distance, dist);
    
    float time = TIME * time_factor;
    vec4 final_color = vec4(0.0);
    
    // Generate ripples
    for(float i = 0.0; i < 5.0; i++) {
        float time_offset = i * (1.0 / spawn_rate);
        float wave_time = mod(time + time_offset, 5.0);
        
        float effective_dist = dist - wave_time * 0.2;
        
        if (effective_dist > 0.0) {
            float wave = sin(effective_dist * wave_count - time * wave_speed);
            float ring = 1.0 - smoothstep(0.0, ring_width, abs(mod(effective_dist, 0.3) - 0.15));
            
            float ripple_intensity = ring * abs(wave);
            final_color += ripple_color * ripple_intensity;
        }
    }
    
    // Apply alpha based on distance
    final_color.a *= alpha;
    
    COLOR = final_color;
}