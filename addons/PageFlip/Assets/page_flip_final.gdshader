shader_type canvas_item;

uniform sampler2D front_texture : source_color, filter_linear_mipmap;
uniform sampler2D back_texture : source_color, filter_linear_mipmap;

// --- SOMBRA DINÁMICA ---
// Pásale aquí un GradientTexture1D (De Negro a Transparente)
uniform sampler2D spine_shadow_gradient : source_color, filter_linear, repeat_disable;

// Este valor lo animaremos desde el AnimationPlayer (0.0 = Cerrado/Plano, 1.0 = Max Curva)
uniform float shadow_intensity : hint_range(0.0, 1.0) = 0.0;

// Cuánto ocupa la sombra como máximo (ej. 0.3 = 30% de la página)
uniform float max_shadow_spread : hint_range(0.0, 1.0) = 0.35;

uniform bool debug_mode = false;

void fragment() {
	// 1. DETECCIÓN DE CARA
	vec2 uv_dx = dFdx(UV);
	vec2 uv_dy = dFdy(UV);
	float face_dir = uv_dx.x * uv_dy.y - uv_dx.y * uv_dy.x;
	bool is_front = face_dir > 0.0;

	// 2. TEXTURA BASE
	vec4 base_color;
	if (is_front) {
		base_color = texture(front_texture, UV);
		if (debug_mode) base_color = vec4(0.0, 1.0, 0.0, 0.5);
	} else {
		base_color = texture(back_texture, vec2(1.0 - UV.x, UV.y));
		if (debug_mode) base_color = vec4(1.0, 0.0, 0.0, 0.5);
	}

	// 3. CÁLCULO DE SOMBRA DINÁMICA
	// Evitamos división por cero con un pequeño epsilon
	float current_spread = max_shadow_spread * (shadow_intensity + 0.001);

	// Mapeamos UV.x al espacio del gradiente.
	// Si UV.x es 0 (lomo), sample_x es 0.
	// Si UV.x alcanza el 'current_spread', sample_x será 1.
	float sample_x = UV.x / current_spread;

	// Leemos la textura del gradiente.
	// Asumimos que el gradiente es vertical u horizontal, leemos en (x, 0)
	float shadow_alpha = texture(spine_shadow_gradient, vec2(sample_x, 0.0)).a;

	// Si nos pasamos del ancho, cortamos la sombra
	if (sample_x > 1.0) {
		shadow_alpha = 0.0;
	}

	// Modulamos también la opacidad global con la intensidad para suavizar la entrada/salida
	shadow_alpha *= shadow_intensity;

	// 4. APLICAR SOMBRA (MULTIPLY)
	// Asumimos que la sombra es negra. Si quieres sombra de color, usa mix() con un color.
	vec3 final_rgb = mix(base_color.rgb, vec3(0.0, 0.0, 0.0), shadow_alpha);

	COLOR = vec4(final_rgb, base_color.a);
}