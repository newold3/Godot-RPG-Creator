shader_type canvas_item;

uniform mat4 TRANSFORM;
uniform vec2 DEPTH;
uniform bool REPEAT_X;
uniform bool REPEAT_Y;
uniform bool FLIP;
uniform float SCALE : hint_range(0.1, 5.0) = 1.0;
uniform float ROTATION : hint_range(0.0, 6.283) = 0.0;

void fragment() {
	// Create the matrix. A workaround is used to modify the matrix's W column
	// because Godot's transforms are 3x4, not 4x4.
	mat4 mat = mat4(1.0);
	mat[0].w = DEPTH.x;
	mat[1].w = DEPTH.y;

	// Transform UV into [-1, 1] range
	vec2 uv = UV * 2.0 - vec2(1, 1);

	// Mode 7 style affine transformation
	// Calculate transformation matrix coefficients
	float cos_rot = cos(ROTATION);
	float sin_rot = sin(ROTATION);

	// Apply scaling to the transformation matrix (Mode 7 style)
	float a = cos_rot / SCALE;
	float b = -sin_rot / SCALE;
	float c = sin_rot / SCALE;
	float d = cos_rot / SCALE;

	// Apply affine transformation (Mode 7 formula)
	vec2 transformed_uv;
	transformed_uv.x = a * uv.x + b * uv.y;
	transformed_uv.y = c * uv.x + d * uv.y;

	uv = transformed_uv;

	// Turn position into 4d vector
	vec4 pos = vec4(uv, 1.0, 1.0);
	pos = mat * pos;
	pos.xy = pos.xy / pos.w;

	// Apply transformation to position
	float w = pos.w;
	pos.z = 0.0;
	pos.w = 1.0;

	// Apply depth to position
	pos = TRANSFORM * pos;

	// divide position by w coordinate; this applies perspective
	// Set UV to position; transform its range to [0, 1]
	uv = (pos.xy + vec2(1, 1)) * 0.5;

	// Determine if uv is in range or repeating pattern
	if (((uv.x > 0.0 && uv.x < 1.0) || REPEAT_X) && ((uv.y > 0.0 && uv.y < 1.0) || REPEAT_Y) && (w > 0.0 || FLIP)) {
		// Apply texture
		uv = mod(uv, 1.0);
		COLOR = texture(TEXTURE, uv);
	} else {
		COLOR = vec4(0, 0, 0, 0);
	}
}