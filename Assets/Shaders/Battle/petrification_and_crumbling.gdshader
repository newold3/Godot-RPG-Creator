shader_type canvas_item;

uniform float progress : hint_range(0.0, 1.0, 0.01) = 1.0;

/* Grietas */
uniform float crack_scale : hint_range(2.0, 20.0, 0.5) = 7.0;
uniform float crack_width : hint_range(0.01, 0.2, 0.005) = 0.05;
uniform float noise_scale : hint_range(2.0, 40.0, 0.5) = 14.0;
uniform float jitter : hint_range(0.0, 1.0, 0.05) = 0.7;

/* Caída de los trozos */
uniform float fall_distance : hint_range(0.1, 2.0, 0.05) = 0.7;
uniform float spread : hint_range(0.0, 1.0, 0.01) = 0.25;
uniform float max_rotation : hint_range(0.0, 3.0, 0.05) = 1.2;

/* Márgenes para que los trozos no se corten al salir del sprite */
uniform float side_margin : hint_range(0.0, 0.5, 0.05) = 0.3;
uniform float bottom_margin : hint_range(0.0, 1.5, 0.05) = 0.6;

uniform vec4 stone_tint : source_color = vec4(0.62, 0.6, 0.58, 1.0);
uniform vec4 dust_color : source_color = vec4(0.75, 0.68, 0.55, 1.0);

vec2 hash22(vec2 p) {
	p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
	return fract(sin(p) * 43758.5453);
}

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

/* Punto semilla de cada celda: cerca del centro, así las celdas tienen tamaño acotado */
vec2 cell_point(vec2 id) {
	return id + 0.5 + (hash22(id) - 0.5) * jitter;
}

/* Distancia al borde de la celda de Voronoi más cercana (las grietas) */
float voronoi_edge(vec2 p) {
	vec2 g = floor(p);
	float d1 = 8.0;
	float d2 = 8.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 r = cell_point(g + vec2(float(x), float(y))) - p;
			float d = dot(r, r);
			if (d < d1) {
				d2 = d1;
				d1 = d;
			} else if (d < d2) {
				d2 = d;
			}
		}
	}
	return sqrt(d2) - sqrt(d1);
}

/* Id de la celda de Voronoi que contiene el punto p */
vec2 voronoi_id(vec2 p) {
	vec2 g = floor(p);
	float best = 1e9;
	vec2 best_id = g;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 id = g + vec2(float(x), float(y));
			vec2 r = cell_point(id) - p;
			float d = dot(r, r);
			if (d < best) {
				best = d;
				best_id = id;
			}
		}
	}
	return best_id;
}

/* Color final de un trozo en el punto q (espacio de celdas). Alfa 0 = no hay nada que dibujar */
vec4 shade_piece(sampler2D tex_s, vec2 q, float local, float petrify, float aspect) {
	vec2 uv_q = vec2(q.x / aspect, q.y) / crack_scale;
	if (uv_q.x < 0.0 || uv_q.x > 1.0 || uv_q.y < 0.0 || uv_q.y > 1.0) {
		return vec4(0.0);
	}
	vec4 tex = textureLod(tex_s, uv_q, 0.0);
	if (tex.a < 0.01) {
		return vec4(0.0);
	}

	float luma = dot(tex.rgb, vec3(0.299, 0.587, 0.114));
	float grain = vnoise(uv_q * noise_scale * 3.0);
	vec3 stone = stone_tint.rgb * (luma * 0.9 + 0.15) * (0.85 + 0.3 * grain);
	vec3 col = mix(tex.rgb, stone, petrify);

	// Las grietas se calculan en el espacio original, así viajan con cada trozo
	float edge = voronoi_edge(q);
	float crack = (1.0 - smoothstep(0.0, crack_width, edge)) * smoothstep(0.3, 0.8, petrify);
	col = mix(col, vec3(0.05, 0.04, 0.04), crack * 0.85);

	// Al caer, el trozo se vuelve polvo y se desvanece
	col = mix(col, dust_color.rgb, local * 0.6);
	float a = 1.0 - smoothstep(0.55, 1.0, local);

	return vec4(col, tex.a * a);
}

void vertex() {
	vec2 tex_size = 1.0 / TEXTURE_PIXEL_SIZE;
	if (UV.x < 0.5) {
		VERTEX.x -= tex_size.x * side_margin;
	} else {
		VERTEX.x += tex_size.x * side_margin;
	}
	if (UV.y > 0.5) {
		VERTEX.y += tex_size.y * bottom_margin;
	}
}

void fragment() {
	float k = 1.0 - progress;
	float petrify = smoothstep(0.0, 0.45, k);
	float crumble = clamp((k - 0.5) / 0.5, 0.0, 1.0);

	// UV del sprite real (el quad está ampliado por los lados y por abajo)
	vec2 auv = vec2(UV.x * (1.0 + 2.0 * side_margin) - side_margin, UV.y * (1.0 + bottom_margin));

	// Espacio de celdas con proporción correcta (las celdas salen cuadradas)
	float aspect = TEXTURE_PIXEL_SIZE.y / TEXTURE_PIXEL_SIZE.x;
	vec2 p = vec2(auv.x * aspect, auv.y) * crack_scale;
	vec2 pc = floor(p);

	float fall_cells = fall_distance * crack_scale;
	float spread_cells = spread * crack_scale;
	int ry = int(ceil(fall_cells)) + 3;
	int rx = int(ceil(spread_cells)) + 3;

	// Los dos trozos más adelantados en este píxel (delante y detrás)
	vec4 front = vec4(0.0);
	float front_local = -1.0;
	vec4 back = vec4(0.0);
	float back_local = -1.0;

	if (crumble <= 0.0) {
		front = shade_piece(TEXTURE, p, 0.0, petrify, aspect);
	} else {
		// Los trozos caen hacia abajo, así que su origen está ARRIBA del píxel
		for (int dy = -ry; dy <= 3; dy++) {
			for (int dx = -rx; dx <= rx; dx++) {
				vec2 id = pc + vec2(float(dx), float(dy));
				vec2 f = cell_point(id);

				float r1 = hash12(id + vec2(17.3, 5.1));
				float r2 = hash12(id + vec2(41.7, 9.9));
				float r3 = hash12(id + vec2(83.1, 23.5));

				// Arriba rompe antes; delay + 0.45 <= 1.0 => todos terminan en progress 0
				float delay = clamp(f.y / crack_scale, 0.0, 1.0) * 0.35 + r1 * 0.2;
				float local = clamp((crumble - delay) / 0.45, 0.0, 1.0);

				vec2 q;
				if (local <= 0.0) {
					// Aún pegado: tiembla justo antes de soltarse
					float pre = smoothstep(delay - 0.12, delay, crumble);
					vec2 tremble = pre * 0.05 * vec2(sin(TIME * 70.0 + r1 * 40.0), cos(TIME * 83.0 + r2 * 40.0));
					q = p - tremble;
				} else {
					float ang = (r2 - 0.5) * 2.0 * max_rotation * local;
					float c = cos(ang);
					float s = sin(ang);
					float sc = mix(1.0, 0.55, local * local);
					vec2 off = vec2((r3 - 0.5) * 2.0 * spread_cells * local,
									fall_cells * local * local * (0.6 + 0.4 * r1));
					vec2 v = (p - f - off) / sc;
					// Rotación inversa para volver al espacio original del trozo
					q = f + vec2(c * v.x + s * v.y, -s * v.x + c * v.y);
				}

				// Descarte rápido: el punto original debe estar cerca del centro del trozo
				vec2 dq = q - f;
				if (dot(dq, dq) > 3.0) {
					continue;
				}

				// El punto original tiene que pertenecer realmente a esta celda
				vec2 qid = voronoi_id(q);
				if (abs(qid.x - id.x) + abs(qid.y - id.y) > 0.5) {
					continue;
				}

				// Color del trozo en este punto; si es transparente, no tapa a nadie
				vec4 c_piece = shade_piece(TEXTURE, q, local, petrify, aspect);
				if (c_piece.a < 0.01) {
					continue;
				}

				if (local > front_local) {
					back = front;
					back_local = front_local;
					front = c_piece;
					front_local = local;
				} else if (local > back_local) {
					back = c_piece;
					back_local = local;
				}
			}
		}
	}

	// Composición: el trozo de delante sobre el de detrás
	float out_a = front.a + back.a * (1.0 - front.a);
	vec3 out_rgb = vec3(0.0);
	if (out_a > 0.0001) {
		out_rgb = (front.rgb * front.a + back.rgb * back.a * (1.0 - front.a)) / out_a;
	}

	COLOR = vec4(out_rgb, out_a);
}