shader_type canvas_item;

uniform float layers: hint_range(10.0, 200.0, 0.1) = 50.0;
uniform float depth: hint_range(0.0, 1.0, 0.01) = 0.5;
uniform float density: hint_range(0.0, 1.0, 0.01) = 0.5;
uniform float speed: hint_range(0.0, 1.0, 0.01) = 0.5;
uniform float wind: hint_range(-2.0, 2.0, 0.01) = 0.0;
uniform vec2 snowflake_scale = vec2(1.0, 1.0);

const mat3 p = mat3(
	vec3(13.0, 23.0, 21.0),
	vec3(21.0, 28.0, 11.0),
	vec3(21.0, 14.0, 61.0)
);

void fragment() {
	vec2 uv = -UV;
	vec2 resolution = 1.0 / TEXTURE_PIXEL_SIZE;

	// Aplicamos el factor de escala a las coordenadas de los copos
	uv /= snowflake_scale;
	uv.x *= resolution.x / resolution.y;

	float time = TIME * speed;
	vec3 color = vec3(0.0);
	for (float i = 0.0; i < layers; i++) {
		vec2 flake = uv * (1.0 + i * depth);
		float wind_shift = (density * (mod(i * PI, 1.0) - (wind + 0.5)));
		float fall = time / (1.0 + i * depth * 0.03);
		flake += vec2(flake.y * wind_shift, fall);
		vec3 tile_id = vec3(floor(flake), i);
		vec3 tile_shift = floor(tile_id) * 1e-5 + fract(tile_id);
		vec3 flake_shift = fract((PI * 1e3 + tile_shift) / fract(p * tile_shift));
		vec2 shape = abs(mod(flake, 1.0) - 1.0 + flake_shift.xy);
		shape += 0.01 * abs(2.0 * fract(10.0 * flake) - 1.0);
		float dist = 0.5 * max(shape.x - shape.y, shape.x + shape.y) + max(shape.x, shape.y) - 0.01;
		float edge = 0.05 * min(0.5 * abs(i - 5.0), 1.0);
		color += vec3(smoothstep(edge, -edge, dist) * (flake_shift.x / (1.0 + 0.02 * i * depth)));
	}

	COLOR = vec4(vec3(color), 1.0);
}
