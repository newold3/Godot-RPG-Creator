shader_type canvas_item;

uniform float progress : hint_range(0.0, 1.0, 0.01) = 1.0;
uniform float shake : hint_range(0.0, 0.1, 0.005) = 0.04;
uniform float arc_scale : hint_range(2.0, 20.0, 0.5) = 8.0;
uniform float arc_width : hint_range(0.005, 0.1, 0.005) = 0.03;
uniform vec4 bolt_color : source_color = vec4(0.5, 0.8, 1.0, 1.0);

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

void fragment() {
	float k = 1.0 - progress;
	float t = floor(TIME * 20.0);

	// Sacudida horizontal por franjas
	float row = floor(UV.y * 40.0);
	float jit = (hash12(vec2(row, t)) - 0.5) * shake * smoothstep(0.0, 0.2, k);
	vec2 uv = UV + vec2(jit, 0.0);

	vec4 tex = vec4(0.0);
	if (uv.x >= 0.0 && uv.x <= 1.0) {
		tex = texture(TEXTURE, uv);
	}
	vec3 col = tex.rgb;

	// Destellos con inversión de color
	float flash = step(0.6, hash12(vec2(t, 7.0))) * smoothstep(0.0, 0.15, k) * (1.0 - smoothstep(0.55, 0.75, k));
	col = mix(col, (vec3(1.0) - col) * bolt_color.rgb * 1.5, flash);

	// Arcos: líneas finas donde el ruido cruza 0.5
	float n = vnoise(UV * arc_scale + vec2(t * 3.7, t * 1.3));
	float arc = (1.0 - smoothstep(0.0, arc_width, abs(n - 0.5))) * smoothstep(0.0, 0.1, k) * (1.0 - smoothstep(0.7, 0.9, k));
	col += bolt_color.rgb * arc * 2.5;

	// Carbonizado
	col = mix(col, vec3(0.04, 0.035, 0.03), smoothstep(0.45, 0.8, k));

	// Deshacerse en chispas al final
	float cell = hash12(floor(UV * 48.0) + 13.0);
	float gone = smoothstep(0.7, 1.0, k);
	float alive = step(gone, cell);
	float spark = (1.0 - alive) * 0.0 + (1.0 - smoothstep(0.0, 0.12, cell - gone)) * alive;
	col += bolt_color.rgb * spark * 1.5;

	float a = max(tex.a, arc * 0.6) * alive * COLOR.a;
	COLOR = vec4(col, a);
}