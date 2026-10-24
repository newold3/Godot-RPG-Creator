shader_type canvas_item;

/* Controls the animation from 1.0 (normal sprite) to 0.0 (fully disintegrated) */
uniform float progress : hint_range(0.0, 1.0, 0.01) = 1.0;

/* Resolution of the square pixel blocks */
uniform float pixel_grid_size : hint_range(16.0, 256.0, 1.0) = 64.0;

/* Maximum upward travel distance in UV space for detached pixels */
uniform float max_rise_distance : hint_range(0.0, 1.0, 0.01) = 0.35;

/* Horizontal amplitude of the sinusoidal wave movement in grid cells */
uniform float sway_amplitude : hint_range(0.0, 5.0, 0.1) = 1.4;

/* Frequency of the sinusoidal oscillation as particles rise */
uniform float sway_frequency : hint_range(1.0, 30.0, 0.5) = 10.0;

/* Radius of the smooth Gaussian aura around each pixel in grid cells */
uniform float aura_radius : hint_range(0.1, 3.0, 0.05) = 1.25;

/* Opacity and strength of the smooth Gaussian aura */
uniform float aura_strength : hint_range(0.0, 3.0, 0.05) = 0.85;

/* Extra top margin in UV space so rising particles are not clipped */
uniform float top_margin : hint_range(0.0, 1.0, 0.05) = 0.45;

/* Extra horizontal margin in UV space for swaying particles and aura */
uniform float side_margin : hint_range(0.0, 0.5, 0.05) = 0.15;

/* UV.y of the topmost visible row of the sprite (0.0 if the sprite fills the texture) */
uniform float content_top : hint_range(0.0, 1.0, 0.01) = 0.0;

/* UV.y of the bottommost visible row of the sprite (1.0 if the sprite fills the texture) */
uniform float content_bottom : hint_range(0.0, 1.0, 0.01) = 1.0;

/* Bright inner core color (pale yellow/white) */
uniform vec4 core_color : source_color = vec4(1.0, 0.98, 0.7, 1.0);

/* Main fire body color (bright orange-gold) */
uniform vec4 mid_color : source_color = vec4(1.0, 0.52, 0.08, 1.0);

/* Outer border and Gaussian aura color (deep red-orange) */
uniform vec4 edge_color : source_color = vec4(0.95, 0.12, 0.02, 1.0);

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

void vertex() {
	vec2 tex_size = 1.0 / TEXTURE_PIXEL_SIZE;
	// Usamos UV (no VERTEX) para decidir el lado: no depende del origen del sprite
	if (UV.y < 0.5) {
		VERTEX.y -= tex_size.y * top_margin;
	}
	if (UV.x < 0.5) {
		VERTEX.x -= tex_size.x * side_margin;
	} else {
		VERTEX.x += tex_size.x * side_margin;
	}
}

void fragment() {
	if (progress <= 0.0) {
		COLOR = vec4(0.0);
	} else {
		// Remapeo de UVs: el quad ampliado vuelve a coincidir con el sprite original
		vec2 adjusted_uv = UV;
		adjusted_uv.y = UV.y * (1.0 + top_margin) - top_margin;
		adjusted_uv.x = UV.x * (1.0 + 2.0 * side_margin) - side_margin;

		float ignition = clamp((1.0 - progress) / 0.15, 0.0, 1.0);
		// sweep: 0 en progress 0.85  ->  1 en progress 0.0
		float sweep = clamp((0.85 - progress) / 0.85, 0.0, 1.0);

		vec2 cell_size = vec2(1.0 / pixel_grid_size);
		vec2 pos_grid = adjusted_uv * pixel_grid_size;
		vec2 grid_id = floor(pos_grid);

		vec4 base_sprite = vec4(0.0);
		if (adjusted_uv.x >= 0.0 && adjusted_uv.x <= 1.0 && adjusted_uv.y >= 0.0 && adjusted_uv.y <= 1.0) {
			base_sprite = textureLod(TEXTURE, adjusted_uv, 0.0);
		}

		int max_rise_steps = int(ceil(max_rise_distance * pixel_grid_size)) + 2;
		int aura_pad = int(ceil(aura_radius));
		int x_pad = int(ceil(sway_amplitude + aura_radius));

		float content_height = max(content_bottom - content_top, 0.001);

		vec3 core_rgb = vec3(0.0);
		float core_alpha = 0.0;
		vec3 aura_accum = vec3(0.0);
		float aura_alpha_accum = 0.0;

		for (int dy = -aura_pad; dy <= max_rise_steps + aura_pad; dy++) {
			for (int dx = -x_pad; dx <= x_pad; dx++) {
				vec2 src_id = grid_id + vec2(float(dx), float(dy));
				vec2 src_uv = (src_id + 0.5) * cell_size;

				if (src_uv.x < 0.0 || src_uv.x > 1.0 || src_uv.y < 0.0 || src_uv.y > 1.0) {
					continue;
				}

				vec4 src_tex = textureLod(TEXTURE, src_uv, 0.0);
				if (src_tex.a < 0.1) {
					continue;
				}

				float r1 = hash12(src_id);
				float r2 = hash12(src_id + vec2(19.37, 47.11));
				float r3 = hash12(src_id + vec2(73.19, 11.83));

				// start_sweep + life_duration <= 1.0 siempre:
				// la última partícula termina exactamente en sweep = 1.0
				float life_duration = mix(0.16, 0.38, r2);
				float y_norm = clamp((content_bottom - src_uv.y) / content_height, 0.0, 1.0);
				float t_start = clamp(y_norm * 0.75 + r1 * 0.25, 0.0, 1.0);
				float start_sweep = t_start * (1.0 - life_duration);
				float local_age = clamp((sweep - start_sweep) / life_duration, 0.0, 1.0);

				if (local_age >= 1.0) {
					continue;
				}

				// Fade: empieza en age 0.3 y llega a 0 en age 0.92 (sin cola residual)
				float fade_x = clamp((0.92 - local_age) / 0.62, 0.0, 1.0);
				float alpha_fade = pow(fade_x, 1.5) * src_tex.a;
				if (alpha_fade < 0.004) {
					continue;
				}

				float rise_speed = mix(0.35, 1.0, r1);
				float rise_cells = pow(local_age, 1.15) * max_rise_distance * rise_speed * pixel_grid_size;

				float sway_envelope = smoothstep(0.0, 0.15, local_age);
				float sway_offset = sin(local_age * sway_frequency + r3 * 6.283185) * sway_amplitude * sway_envelope;

				vec2 particle_center = (src_id + 0.5) + vec2(sway_offset, -rise_cells);
				vec2 diff = pos_grid - particle_center;

				float box_dist = max(abs(diff.x), abs(diff.y));
				float radial_dist = length(diff);

				if (radial_dist > aura_radius + 0.6) {
					continue;
				}

				float u_step = cell_size.x;
				float v_step = cell_size.y;
				float a_up = textureLod(TEXTURE, clamp(src_uv + vec2(0.0, -v_step), vec2(0.0), vec2(1.0)), 0.0).a;
				float a_down = textureLod(TEXTURE, clamp(src_uv + vec2(0.0, v_step), vec2(0.0), vec2(1.0)), 0.0).a;
				float a_left = textureLod(TEXTURE, clamp(src_uv + vec2(-u_step, 0.0), vec2(0.0), vec2(1.0)), 0.0).a;
				float a_right = textureLod(TEXTURE, clamp(src_uv + vec2(u_step, 0.0), vec2(0.0), vec2(1.0)), 0.0).a;
				float interior = a_up * a_down * a_left * a_right;

				float luma = dot(src_tex.rgb, vec3(0.299, 0.587, 0.114));
				float heat = clamp((0.45 + 0.55 * interior) * (0.7 + 0.3 * luma), 0.0, 1.0);
				heat *= (1.0 - local_age * 0.85);
				heat = clamp(heat - (r2 * 0.2), 0.0, 1.0);

				vec3 fire_col;
				if (heat < 0.5) {
					fire_col = mix(edge_color.rgb, mid_color.rgb, heat * 2.0);
				} else {
					fire_col = mix(mid_color.rgb, core_color.rgb, (heat - 0.5) * 2.0);
				}

				float shrink = mix(0.48, 0.16, local_age * local_age);

				float pixel_mask = 1.0 - smoothstep(shrink - 0.05, shrink + 0.05, box_dist);
				if (pixel_mask * alpha_fade > core_alpha) {
					core_alpha = pixel_mask * alpha_fade;
					core_rgb = fire_col;
				}

				float sigma = max(aura_radius * 0.45, 0.001);
				float gaussian = exp(-(radial_dist * radial_dist) / (2.0 * sigma * sigma));
				float window = 1.0 - smoothstep(aura_radius * 0.65, aura_radius, radial_dist);
				float aura_w = gaussian * window * alpha_fade * aura_strength * 0.28;

				vec3 p_aura_col = mix(edge_color.rgb, mid_color.rgb, heat * 0.45);
				aura_accum += p_aura_col * aura_w;
				aura_alpha_accum += aura_w;
			}
		}

		float final_aura_a = clamp(1.0 - exp(-aura_alpha_accum * 1.6), 0.0, 1.0);
		vec3 final_aura_rgb = aura_alpha_accum > 0.0001 ? clamp(aura_accum / aura_alpha_accum + aura_accum * 0.25, 0.0, 1.0) : edge_color.rgb;

		float out_a = core_alpha + final_aura_a * (1.0 - core_alpha);
		vec3 out_rgb = vec3(0.0);
		if (out_a > 0.0001) {
			out_rgb = (core_rgb * core_alpha + final_aura_rgb * final_aura_a * (1.0 - core_alpha)) / out_a;
		}

		vec4 effect_color = vec4(out_rgb, out_a);

		if (progress > 0.85) {
			COLOR = vec4(
				mix(base_sprite.rgb, effect_color.rgb, ignition),
				mix(base_sprite.a, effect_color.a, ignition)
			);
		} else {
			COLOR = effect_color;
		}
	}
}