shader_type canvas_item;

/* Shader by FencerDevLog - https://www.youtube.com/watch?v=HvdDbu0lPtY */

/* Horizontal shake frequency */
uniform float freq_x: hint_range(0.0, 100.0, 0.1) = 20.0;

/* Vertical shake frequency */
uniform float freq_y: hint_range(0.0, 100.0, 0.1) = 20.0;

/* Horizontal shake amplitude */
uniform float amp_x: hint_range(0.0, 10.0, 0.01) = 1.0;

/* Vertical shake amplitude */
uniform float amp_y: hint_range(0.0, 10.0, 0.01) = 1.0;

/* Noise field scale */
uniform float scale: hint_range(1.0, 100.0, 0.1) = 20.0;

const int OCTAVES = 4;

float hash(vec2 p) {
	p = fract(p * vec2(127.1, 311.7));
	p += dot(p, p + 19.19);
	return fract(p.x * p.y);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float fbm(vec2 uv) {
	float result = 0.0;
	float amp = 1.0;
	float freq = 1.0;
	for (int i = 0; i < OCTAVES; i++) {
		result += value_noise(uv * freq) * amp;
		uv *= 2.0;
		amp *= 0.5;
	}
	return result;
}

void fragment() {
	vec2 uv = UV;
	float noise = fbm(uv * scale);
	vec2 shift = vec2(
		sin(TIME * freq_x + noise) * amp_x,
		cos(TIME * freq_y + noise) * amp_y
	);
	COLOR = texture(TEXTURE, uv + shift * 0.01);
}