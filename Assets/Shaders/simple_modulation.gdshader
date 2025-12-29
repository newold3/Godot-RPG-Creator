shader_type canvas_item;

uniform vec4 modulate: source_color = vec4(1.0);
uniform sampler2D SCREEN_TEXTURE: hint_screen_texture;

void fragment() {
	vec2 uv = SCREEN_UV;
	vec4 pixel = texture(SCREEN_TEXTURE, SCREEN_UV);
	COLOR = pixel * modulate;
	//COLOR = mix(pixel, vec4(modulate.rgb, 1.0), modulate.a);
}
