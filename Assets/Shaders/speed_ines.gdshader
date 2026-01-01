shader_type canvas_item;

uniform sampler2D noise: repeat_enable;
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;
uniform vec4 border_color: source_color = vec4(1.0, 1.0, 1.0, 0.8);
uniform vec4 depth_color: source_color = vec4(0.5, 0.7, 1.0, 0.6);
uniform float line_count: hint_range(0.0, 2.0, 0.05) = 0.5;
uniform float line_density: hint_range(0.0, 1.0) = 0.5;
uniform float line_faloff: hint_range(0.0, 1.0) = 0.25;
uniform float mask_size: hint_range(0.0, 1.0) = 0.1;
uniform float mask_edge: hint_range(0.0, 1.0) = 0.5;
uniform float animation_speed: hint_range(1.0, 200.0) = 5.0;
uniform float rotation_speed: hint_range(-10.0, 10.0, 0.01) = 2.0;
uniform float height_animation: hint_range(0.0, 1.0) = 0.3;
uniform float blur_strength: hint_range(0.0, 10.0) = 2.0;
uniform float final_alpha: hint_range(0.0, 1.0, 0.01) = 1.0;

float inv_lerp(float from, float to, float value){
	return (value - from) / (to - from);
}

vec2 polar_coordinates(vec2 uv, vec2 center, float zoom, float repeat)
{
	vec2 dir = uv - center;
	float radius = length(dir) * 2.0;
	float angle = atan(dir.y, dir.x) * 1.0/(PI * 2.0);
	return mod(vec2(radius * zoom, angle * repeat), 1.0);
}

vec2 rotate_uv(vec2 uv, vec2 pivot, float rotation) {
    float cosa = cos(rotation);
    float sina = sin(rotation);
    uv -= pivot;
    return vec2(
        cosa * uv.x - sina * uv.y,
        cosa * uv.y + sina * uv.x 
    ) + pivot;
}

// Function to apply Gaussian blur to background
vec4 gaussian_blur_background(vec2 uv, float blur_size) {
    if (blur_size <= 0.0) return texture(SCREEN_TEXTURE, uv);
    
    vec4 color = vec4(0.0);
    float total_weight = 0.0;
    
    // Calculate texel size
    vec2 texel_size = vec2(ivec2(1) / textureSize(SCREEN_TEXTURE, 0));
    
    // 5x5 blur kernel
    for(int x = -2; x <= 2; x++) {
        for(int y = -2; y <= 2; y++) {
            vec2 offset = vec2(float(x), float(y)) * blur_size * texel_size;
            float weight = exp(-0.5 * float(x*x + y*y) / 2.0);
            color += texture(SCREEN_TEXTURE, uv + offset) * weight;
            total_weight += weight;
        }
    }
    
    return color / total_weight;
}

void fragment(){
	vec2 center = vec2(0.5);
	vec2 dir = UV - center;
	float angle = atan(dir.y, dir.x);
	
	// Calculate triangle index based on angle
	float triangle_index = floor((angle + PI) / (2.0 * PI) * line_count * 50.0);
	
	// Create unique delay for each triangle using simple hash
	float triangle_delay = fract(sin(triangle_index * 12.9898) * 43758.5453);
	
	// Stretch/shrink animation with delay per triangle (NO rotation)
	float stretch_phase = TIME * animation_speed * 0.3 + triangle_delay * 6.28318; // 2*PI for full distribution
	float stretch_factor = 0.8 + 0.4 * sin(stretch_phase); // oscillates between 0.4 and 1.2
	stretch_factor = mix(1.0, stretch_factor, height_animation);
	
	// Independent and continuous rotation of the whole figure
	float rotation_angle = TIME * rotation_speed * 0.5; // Continuous rotation
	
	// Polar coordinates with continuous rotation applied
	vec2 polar_uv = polar_coordinates(
		rotate_uv(UV, center, rotation_angle), 
		center, 
		0.01, 
		line_count
	);
	
	vec3 lines = texture(noise, polar_uv).rgb;
	
	// Base mask with stretch factor applied
	float mask_value = length(UV - center);
	float dynamic_mask_edge = mask_edge * stretch_factor;
	float dynamic_mask_size = mask_size * stretch_factor;
	
	float mask = inv_lerp(dynamic_mask_size, dynamic_mask_edge, mask_value);
	float result = 1.0 - (mask * line_density);
	
	// Create main line pattern
	float line_result = smoothstep(result, result + line_faloff, lines.r);
	
	// Create edges for triangles/lines
	float border_thickness = 0.05;
	float border_result = smoothstep(result - border_thickness, result - border_thickness + line_faloff, lines.r);
	border_result -= line_result; // Only edges
	
	// Create depth effect based on distance to center
	float depth_factor = smoothstep(mask_size, mask_edge, mask_value);
	float depth_result = line_result * depth_factor;
	
	// Get background with or without blur
	vec4 background;
	if (blur_strength > 0.0) {
		background = gaussian_blur_background(SCREEN_UV, blur_strength);
	} else {
		background = texture(SCREEN_TEXTURE, SCREEN_UV);
	}
	
	// Mix triangle colors
	vec3 triangle_color = vec3(0.0);
	float triangle_alpha = 0.0;
	
	// Apply depth color (inside triangles)
	triangle_color += depth_color.rgb * depth_result;
	triangle_alpha += depth_color.a * depth_result;
	
	// Apply border color (triangle edges)
	triangle_color += border_color.rgb * border_result;
	triangle_alpha += border_color.a * border_result;
	
	// Combine background with triangles
	COLOR.rgb = mix(background.rgb, triangle_color, triangle_alpha);
	COLOR.a = background.a * final_alpha;
}