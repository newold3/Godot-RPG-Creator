shader_type canvas_item;

uniform float progress : hint_range(0.0, 1.0, 0.01) = 1.0;
uniform float spin : hint_range(0.0, 20.0, 0.5) = 8.0;
uniform vec4 void_color : source_color = vec4(0.5, 0.1, 0.9, 1.0);

void fragment() {
	float k = 1.0 - progress;
	vec2 c = UV - 0.5;
	float r = length(c);

	// Giro más fuerte en el centro
	float ang = k * spin * (1.0 - clamp(r * 1.5, 0.0, 1.0));
	float s = sin(ang);
	float co = cos(ang);
	vec2 rc = vec2(c.x * co - c.y * s, c.x * s + c.y * co);

	// Escala: el sprite se encoge hacia el centro
	float scale = max(progress, 0.0001);
	vec2 uv = rc / scale + 0.5;

	vec4 tex = vec4(0.0);
	if (uv.x >= 0.0 && uv.x <= 1.0 && uv.y >= 0.0 && uv.y <= 1.0) {
		tex = texture(TEXTURE, uv);
	}

	float luma = dot(tex.rgb, vec3(0.299, 0.587, 0.114));
	vec3 col = mix(tex.rgb, void_color.rgb * (luma + 0.3), clamp(k * 1.5, 0.0, 1.0));

	COLOR = vec4(col, tex.a * smoothstep(0.0, 0.15, progress));
}