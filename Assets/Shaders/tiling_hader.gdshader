shader_type canvas_item;

// Number of horizontal repetitions
uniform int columns: hint_range(0, 100, 1) = 2;
// Number of vertical repetitions
uniform int rows: hint_range(0, 100, 1) = 2;


void fragment() {
	// Scale the UV by the number of desired tiles
	// and use fract() to repeat the texture.
	vec2 tiled_uv = fract(UV * vec2(float(columns), float(rows)));
	
	// Sample the texture using the new calculated coordinates
	COLOR = texture(TEXTURE, tiled_uv);
}