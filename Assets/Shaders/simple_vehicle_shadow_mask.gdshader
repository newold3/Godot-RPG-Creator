shader_type canvas_item;
render_mode blend_premul_alpha;

// Textura renderizada del entorno
uniform sampler2D vehicle_texture : hint_default_transparent;
// Color de la sombra
uniform vec4 shadow_color : source_color;
uniform vec2 offset = vec2(0);


void fragment() {
	vec2 uv = 1.0 / offset;
	vec4 original_color = texture(TEXTURE, UV);
	vec4 vehicle_color = texture(vehicle_texture, UV);
	if (original_color.a == 0.0 || vehicle_color.a != 0.0) {
		discard;
	}
	else {
		COLOR = shadow_color;
	}
}
