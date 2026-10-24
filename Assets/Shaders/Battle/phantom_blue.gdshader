shader_type canvas_item;

uniform float progress : hint_range(0.0, 1.0, 0.01) = 1.0;
uniform vec4 ghost_color : source_color = vec4(0.55, 0.85, 1.0, 1.0);
uniform float wave_amplitude : hint_range(0.0, 0.1, 0.005) = 0.03;
uniform float wave_frequency : hint_range(1.0, 40.0, 0.5) = 18.0;
uniform float softness : hint_range(0.05, 0.6, 0.01) = 0.25;
uniform float glow_strength : hint_range(0.0, 3.0, 0.1) = 1.5;

void fragment() {
	float k = 1.0 - progress;

	vec2 uv = UV;
	uv.x += sin(uv.y * wave_frequency + TIME * 6.0) * wave_amplitude * smoothstep(0.0, 0.3, k);

	vec4 tex = vec4(0.0);
	if (uv.x >= 0.0 && uv.x <= 1.0) {
		tex = texture(TEXTURE, uv);
	}

	// Desvanecimiento de abajo hacia arriba
	float h = 1.0 - UV.y;
	float line = mix(-softness, 1.0, k);
	float fade = smoothstep(line, line + softness, h);

	// Tinte fantasmal
	float luma = dot(tex.rgb, vec3(0.299, 0.587, 0.114));
	vec3 tinted = ghost_color.rgb * (luma + 0.4);
	vec3 col = mix(tex.rgb, tinted, smoothstep(0.0, 0.35, k));

	// Brillo en la franja de transición
	float band = fade * (1.0 - fade) * 4.0;
	col += ghost_color.rgb * band * glow_strength;

	COLOR = vec4(col, tex.a * fade);
}