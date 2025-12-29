shader_type canvas_item;

uniform sampler2D NOISE_TEXTURE : hint_default_white;
uniform float depth_intensity : hint_range(0.0, 1.0) = 0.5;
uniform float bevel_width : hint_range(0.0, 0.5) = 0.2;
uniform float darkness : hint_range(0.0, 1.0) = 0.3;
uniform float edge_detection_radius : hint_range(1.0, 10.0) = 2.0;
uniform float noise_strength : hint_range(0.0, 1.0) = 0.2;
uniform float noise_scale : hint_range(0.1, 10.0) = 1.0;
uniform float noise_time_scale : hint_range(0.0, 2.0) = 0.2;

float get_surrounding_alpha(sampler2D tex, vec2 uv, float radius, vec2 pixel_size) {
    float total_alpha = 0.0;
    int samples = 0;
    
    for(float x = -radius; x <= radius; x += 1.0) {
        for(float y = -radius; y <= radius; y += 1.0) {
            vec2 offset = vec2(x, y) * pixel_size;
            if(length(offset) <= radius * pixel_size.x) {
                vec4 color = texture(tex, uv + offset);
                total_alpha += color.a;
                samples++;
            }
        }
    }
    
    return total_alpha / float(samples);
}

void fragment() {
    vec4 original_color = texture(TEXTURE, UV);
    
    // Si el píxel es transparente, descartarlo
    if (original_color.a < 0.01) {
        COLOR = vec4(0.0);
    }
	else{
	    // Muestreamos el ruido con movimiento
	    vec2 noise_uv = UV * noise_scale + vec2(TIME * noise_time_scale);
	    float noise = texture(NOISE_TEXTURE, noise_uv).r * 2.0 - 1.0;
	    
	    // Detectamos transparencia en los alrededores
	    float surrounding_alpha = get_surrounding_alpha(TEXTURE, UV, edge_detection_radius, TEXTURE_PIXEL_SIZE);
	    
	    // Calculamos el bevel con influencia del ruido
	    float alpha_diff = original_color.a - surrounding_alpha;
	    float bevel = smoothstep(0.0, bevel_width, alpha_diff + noise * noise_strength);
	    
	    // Efecto de profundidad con ruido
	    float depth = 1.0 - (1.0 - bevel) * depth_intensity;
	    depth += noise * noise_strength * depth_intensity;
	    
	    // Oscurecimiento central con ruido
	    float center_darkness = 1.0 - darkness * (1.0 - surrounding_alpha);
	    center_darkness += noise * noise_strength * 0.5;
	    
	    // Color final con todos los efectos
	    vec3 final_color = original_color.rgb * depth * center_darkness;
	    
	    COLOR = vec4(final_color, original_color.a);
	}
}