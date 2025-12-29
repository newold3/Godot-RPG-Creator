shader_type canvas_item;

uniform sampler2D shadow_texture : hint_default_transparent;
uniform sampler2D mask_texture   : hint_default_transparent;

uniform vec4 overlay_color : source_color = vec4(0.0, 0.0, 0.0, 0.5);

// --- HEIGHTMAP / DESPLAZAMIENTO ---
uniform float height_strength = 0.01;
uniform vec2 shadow_direction = vec2(0.0, -1.0);

const float border_width = 1.5;

void fragment() {

	vec4 shadow_tex = texture(shadow_texture, UV);
	vec4 mask_tex   = texture(mask_texture, UV);

	float shadow_alpha = shadow_tex.a;
	float mask_alpha   = mask_tex.a;

	float shadow_y = shadow_tex.r;
	float mask_y   = mask_tex.r;

	if (shadow_alpha < 0.01) {
		discard;
	}

	bool should_discard = false;

	// ------------------------------------------------
	// LÓGICA DE PROFUNDIDAD (SIN TOCAR)
	// ------------------------------------------------
	if (mask_alpha > 0.09) {

		float depth_margin = 0.001;
		bool caster_is_in_front = shadow_y > (mask_y + depth_margin);

		if (!caster_is_in_front) {

			vec2 ps = vec2(1.0) / vec2(textureSize(mask_texture, 0));

			float a_up    = texture(mask_texture, UV + vec2(0.0, -ps.y * border_width)).a;
			float a_down  = texture(mask_texture, UV + vec2(0.0,  ps.y * border_width)).a;
			float a_left  = texture(mask_texture, UV + vec2(-ps.x * border_width, 0.0)).a;
			float a_right = texture(mask_texture, UV + vec2( ps.x * border_width, 0.0)).a;

			bool is_edge =
				a_up    < 0.02 ||
				a_down  < 0.02 ||
				a_left  < 0.02 ||
				a_right < 0.02;

			if (!is_edge) {
				should_discard = true;
			}
		}
	}

	if (should_discard && shadow_alpha < 0.1) {
		discard;
	}

	// ------------------------------------------------
	// DESPLAZAMIENTO POR CONTACTO (NO MODULA COLOR)
	// ------------------------------------------------

	vec2 final_uv = UV;

	// Solo desplazamos si hay contacto con la máscara
	if (mask_alpha > 0.09) {

		// Altura desde la máscara
		float height = mask_tex.r;

		// Offset suave y controlado
		vec2 offset = shadow_direction * height * height_strength;

		final_uv += offset;
	}

	// Re-sampleamos SOLO para saber si hay sombra
	float displaced_alpha = texture(shadow_texture, final_uv).a;

	if (displaced_alpha < 0.01) {
		discard;
	}

	// ------------------------------------------------
	// COLOR FINAL FIJO
	// ------------------------------------------------

	COLOR = overlay_color;
}
