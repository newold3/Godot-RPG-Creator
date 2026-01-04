shader_type canvas_item;
// Switch to blend_mix for standard shadow/transparency behavior
render_mode blend_mix; 

uniform float blur_size : hint_range(0.0, 5.0) = 1.0;
uniform vec4 overlay_color : source_color = vec4(0.0, 0.0, 0.0, 0.5);

void fragment() {
	vec2 pixel_size = TEXTURE_PIXEL_SIZE;
	float final_alpha = 0.0;

	// Flattened and normalized 5x5 Gaussian kernel
	// The sum of all these values is approx 1.0
	float kernel[25] = float[](
		0.0037, 0.0146, 0.0256, 0.0146, 0.0037,
		0.0146, 0.0586, 0.0952, 0.0586, 0.0146,
		0.0256, 0.0952, 0.1501, 0.0952, 0.0256,
		0.0146, 0.0586, 0.0952, 0.0586, 0.0146,
		0.0037, 0.0146, 0.0256, 0.0146, 0.0037
	);

	int i = 0;
	// Iterate through the kernel
	for(int x = -2; x <= 2; x++) {
		for(int y = -2; y <= 2; y++) {
			// Calculate offset.
			// NOTE: Multiplying by blur_size separates samples. 
			// If blur_size is too high, you will see 'ghosting' (banding).
			vec2 offset = vec2(float(x), float(y)) * pixel_size * blur_size;
			
			// We only care about Alpha for the shadow
			float a = texture(TEXTURE, UV + offset).a;
			
			// Accumulate weighted alpha by kernel
			final_alpha += a * kernel[i];
			i++;
		}
	}

	// Assign overlay color with calculated alpha (blurred)
	// Multiply also by overlay alpha if you want to control global opacity
	COLOR = vec4(overlay_color.rgb, final_alpha * overlay_color.a);
}