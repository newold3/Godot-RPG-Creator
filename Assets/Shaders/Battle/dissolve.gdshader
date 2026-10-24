shader_type canvas_item;

uniform float progress : hint_range(0.0, 1.0, 0.01) = 1.0;
uniform float noise_scale : hint_range(2.0, 40.0, 0.5) = 12.0;
uniform float edge_width : hint_range(0.01, 0.3, 0.01) = 0.08;
uniform float glow : hint_range(0.0, 4.0, 0.1) = 2.0;
uniform vec4 edge_color : source_color = vec4(1.0, 0.45, 0.05, 1.0);
uniform vec4 hot_color : source_color = vec4(1.0, 0.95, 0.6, 1.0);

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * vnoise(p);
		p *= 2.0;
		a *= 0.5;
	}
	return v;
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float n = fbm(UV * noise_scale);

	// t sube de -edge_width (nada disuelto) a 1.0 (todo disuelto)
	float t = mix(-edge_width, 1.0, 1.0 - progress);
	float alive = step(t, n);
	float edge = (1.0 - smoothstep(0.0, edge_width, n - t)) * alive;

	vec3 fire = mix(edge_color.rgb, hot_color.rgb, edge * edge);
	vec3 col = mix(tex.rgb, fire * glow, edge);

	COLOR = vec4(col, tex.a * alive);
}