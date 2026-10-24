shader_type canvas_item;

uniform float progress : hint_range(0.0, 1.0, 0.01) = 1.0;
uniform float bottom_margin : hint_range(0.0, 1.0, 0.05) = 0.5;
uniform float drip_strength : hint_range(0.0, 1.0, 0.01) = 0.6;
uniform float drip_scale : hint_range(2.0, 40.0, 0.5) = 14.0;
uniform float noise_scale : hint_range(2.0, 30.0, 0.5) = 10.0;
uniform vec4 acid_color : source_color = vec4(0.45, 1.0, 0.15, 1.0);

float hash12(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash12(i), hash12(i + vec2(1.0, 0.0)), f.x),
			   mix(hash12(i + vec2(0.0, 1.0)), hash12(i + vec2(1.0, 1.0)), f.x), f.y);
}

void vertex() {
	vec2 tex_size = 1.0 / TEXTURE_PIXEL_SIZE;
	if (UV.y > 0.5) {
		VERTEX.y += tex_size.y * bottom_margin;
	}
}

void fragment() {
	float k = 1.0 - progress;
	vec2 uv = vec2(UV.x, UV.y * (1.0 + bottom_margin));

	// Cada columna gotea a distinta velocidad; más estiramiento cuanto más abajo
	float col_n = vnoise(vec2(uv.x * drip_scale, 3.7));
	float offset = k * drip_strength * (0.3 + col_n);
	vec2 suv = vec2(uv.x, uv.y - offset * smoothstep(0.0, 1.0, uv.y));

	vec4 tex = vec4(0.0);
	if (suv.y >= 0.0 && suv.y <= 1.0) {
		tex = textureLod(TEXTURE, suv, 0.0);
	}

	float luma = dot(tex.rgb, vec3(0.299, 0.587, 0.114));
	vec3 col = mix(tex.rgb, acid_color.rgb * (luma + 0.35), smoothstep(0.0, 0.4, k));

	// Disolución con burbujeo; lo de arriba se va primero
	float n = vnoise(uv * noise_scale + vec2(0.0, TIME * 0.6));
	float v = n * 0.7 + clamp(uv.y, 0.0, 1.0) * 0.3;
	float t = k * 1.05;
	float alive = smoothstep(t, t + 0.04, v);
	float band = (1.0 - smoothstep(0.0, 0.12, v - t)) * alive;
	col += acid_color.rgb * band * 1.6;

	COLOR = vec4(col, tex.a * alive);
}