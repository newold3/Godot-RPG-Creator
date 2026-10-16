shader_type canvas_item;

uniform float blur_strength : hint_range(0.0, 10.0) = 2.0;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear, repeat_disable;

void fragment() {
	if (blur_strength <= 0.0001) {
		COLOR = vec4(0.0);
	} else {
		vec2 pixel_size = SCREEN_PIXEL_SIZE;
		vec3 color = vec3(0.0);
		float weight_sum = 0.0;
		float denom = 2.0 * blur_strength * blur_strength;
		
		// Gaussian blur with 9x9 kernel
		for(int x = -4; x <= 4; x++) {
			for(int y = -4; y <= 4; y++) {
				float distance = float(x * x + y * y);
				float weight = exp(-distance / denom);
				
				vec2 offset = vec2(float(x), float(y)) * pixel_size * blur_strength;
				color += textureLod(SCREEN_TEXTURE, SCREEN_UV + offset, 0.0).rgb * weight;
				weight_sum += weight;
			}
		}
		
		if (weight_sum > 0.0001) {
			color /= weight_sum;
		} else {
			color = textureLod(SCREEN_TEXTURE, SCREEN_UV, 0.0).rgb;
		}
		
		if (isnan(color.r) || isnan(color.g) || isnan(color.b)) {
			color = textureLod(SCREEN_TEXTURE, SCREEN_UV, 0.0).rgb;
		}
		
		COLOR = vec4(color, 1.0);
	}
}