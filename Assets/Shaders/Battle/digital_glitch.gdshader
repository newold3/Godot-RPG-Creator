shader_type canvas_item;

uniform float progress : hint_range(0.0, 1.0, 0.01) = 1.0;
uniform float side_margin : hint_range(0.0, 0.5, 0.05) = 0.2;
uniform float slices : hint_range(4.0, 64.0, 1.0) = 24.0;
uniform float max_shift : hint_range(0.0, 0.6, 0.01) = 0.3;
uniform float rgb_split : hint_range(0.0, 0.08, 0.005) = 0.03;
uniform float pixelate_min : hint_range(4.0, 64.0, 1.0) = 10.0;
uniform vec4 glitch_tint : source_color = vec4(0.0, 0.85, 1.0, 1.0);

float hash11(float n) {
	return fract(sin(n * 127.1) * 43758.5453);
}

vec4 samp(sampler2D tex, vec2 uv) {
	if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
		return vec4(0.0);
	}
	return texture(tex, uv);
}

void vertex() {
	vec2 tex_size = 1.0 / TEXTURE_PIXEL_SIZE;
	if (UV.x < 0.5) {
		VERTEX.x -= tex_size.x * side_margin;
	} else {
		VERTEX.x += tex_size.x * side_margin;
	}
}

void fragment() {
	float k = 1.0 - progress;
	vec2 uv = vec2(UV.x * (1.0 + 2.0 * side_margin) - side_margin, UV.y);

	float row = floor(uv.y * slices);
	float t = floor(TIME * 12.0);
	float r = hash11(row + t * 7.0);

	// Cuantas más franjas "rotas" cuanto más avanza la muerte
	float glitched = step(r, k * 1.5);
	float shift = (hash11(row * 3.1 + t) - 0.5) * 2.0 * max_shift * k * glitched;

	vec2 suv = uv + vec2(shift, 0.0);

	// Pixelado progresivo
	float levels = mix(256.0, pixelate_min, k * k);
	vec2 puv = floor(suv * levels) / levels;
	suv = mix(suv, puv, smoothstep(0.0, 0.1, k));

	// Separación de canales RGB
	float rs = rgb_split * k;
	vec4 cr = samp(TEXTURE, suv + vec2(rs, 0.0));
	vec4 cg = samp(TEXTURE, suv);
	vec4 cb = samp(TEXTURE, suv - vec2(rs, 0.0));

	vec3 col = vec3(cr.r, cg.g, cb.b);
	float a = max(max(cr.a, cg.a), cb.a);

	col += glitch_tint.rgb * glitched * 0.35;

	// Parpadeo y desvanecimiento final
	float flicker = mix(1.0, step(0.2, hash11(row + t * 3.0)), smoothstep(0.2, 0.8, k));
	a *= flicker * (1.0 - smoothstep(0.7, 1.0, k));

	COLOR = vec4(col, a);
}