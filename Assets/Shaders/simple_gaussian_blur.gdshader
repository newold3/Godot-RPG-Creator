shader_type canvas_item;

uniform float blur_strength : hint_range(0.0, 10.0) = 2.0;

uniform sampler2D SCREEN_TEXTURE: hint_screen_texture;

void fragment() {
	vec2 pixel_size = SCREEN_PIXEL_SIZE;
	vec3 color = vec3(0.0);
	float weight_sum = 0.0;
	
	// Gaussian blur with 9x9 kernel
	for(int x = -4; x <= 4; x++) {
		for(int y = -4; y <= 4; y++) {
			float distance = float(x * x + y * y);
			float weight = exp(-distance / (2.0 * blur_strength * blur_strength));
			
			vec2 offset = vec2(float(x), float(y)) * pixel_size * blur_strength;
			color += texture(SCREEN_TEXTURE, SCREEN_UV + offset).rgb * weight;
			weight_sum += weight;
		}
	}
	
	color /= weight_sum;
	COLOR = vec4(color, 1.0);
}