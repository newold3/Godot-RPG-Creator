shader_type canvas_item;

uniform float progress : hint_range(0.0, 1.0, 0.01) = 1.0;
uniform float margin : hint_range(0.0, 0.8, 0.05) = 0.35;
uniform float halo_size : hint_range(0.005, 0.1, 0.005) = 0.04;
uniform float halo_strength : hint_range(0.0, 3.0, 0.05) = 1.4;
uniform float beam_strength : hint_range(0.0, 2.0, 0.05) = 0.8;
uniform vec4 light_color : source_color = vec4(1.0, 0.92, 0.65, 1.0);

vec4 samp(sampler2D tex, vec2 uv) {
	if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
		return vec4(0.0);
	}
	return textureLod(tex, uv, 0.0);
}

void vertex() {
	vec2 tex_size = 1.0 / TEXTURE_PIXEL_SIZE;
	VERTEX.x += (UV.x < 0.5 ? -1.0 : 1.0) * tex_size.x * margin;
	VERTEX.y += (UV.y < 0.5 ? -1.0 : 1.0) * tex_size.y * margin;
}

void fragment() {
	float k = 1.0 - progress;
	vec2 uv = UV * (1.0 + 2.0 * margin) - margin;

	vec4 tex = samp(TEXTURE, uv);
	float luma = dot(tex.rgb, vec3(0.299, 0.587, 0.114));

	// El cuerpo se vuelve luz
	vec3 col = mix(tex.rgb, light_color.rgb * (luma * 0.5 + 0.8), smoothstep(0.0, 0.5, k));

	// Desvanecimiento de abajo hacia arriba
	float h = 1.0 - uv.y;
	float line = mix(-0.25, 1.0, smoothstep(0.3, 0.9, k));
	float body = tex.a * smoothstep(line, line + 0.2, h);

	// Halo: muestreo en dos anillos alrededor del píxel
	float halo = 0.0;
	for (int i = 0; i < 8; i++) {
		float ang = float(i) * 0.785398;
		vec2 dir = vec2(cos(ang), sin(ang));
		halo += samp(TEXTURE, uv + dir * halo_size).a;
		halo += samp(TEXTURE, uv + dir * halo_size * 2.2).a;
	}
	halo = halo / 16.0;
	float halo_env = smoothstep(0.1, 0.5, k) * (1.0 - smoothstep(0.75, 1.0, k));
	float halo_a = clamp(halo * halo_strength * halo_env, 0.0, 1.0);

	// Pilar de luz vertical
	float bx = (uv.x - 0.5) * 7.0;
	float beam = exp(-bx * bx) * (1.0 - clamp(abs(uv.y - 0.5) * 1.3, 0.0, 1.0));
	float beam_a = beam * beam_strength * smoothstep(0.25, 0.6, k) * (1.0 - smoothstep(0.8, 1.0, k));

	float glow_a = clamp(max(halo_a, beam_a), 0.0, 1.0);
	vec3 rgb = col * body + light_color.rgb * glow_a * (1.0 - body);
	float a = body + glow_a * (1.0 - body);

	COLOR = vec4(rgb / max(a, 0.0001), a);
}