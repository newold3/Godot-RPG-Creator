shader_type canvas_item;

uniform sampler2D SCREEN_TEXTURE: hint_screen_texture, filter_linear;
uniform sampler2D NOISE_TEXTURE: repeat_enable;
uniform float strength: hint_range(0.0, 5, 0.1) = 1.0;
uniform float uv_scaling: hint_range (0.0, 1.0, 0.05) = 1.0;
uniform vec2 movement_direction = vec2(1, 0);
uniform float movement_speed: hint_range (0.0, 0.5, 0.01) = 0.1;

uniform vec2 scale = vec2(1.0);

void fragment() {
	vec2 uv = SCREEN_UV / scale;
	vec4 screen_texture = texture(SCREEN_TEXTURE, uv);
	vec2 movement_factor = movement_direction * movement_speed * TIME;
	float noise_value = texture(NOISE_TEXTURE, uv*uv_scaling + movement_factor).r - 0.5;
	uv += noise_value * SCREEN_PIXEL_SIZE * strength;
	COLOR = texture(SCREEN_TEXTURE, uv);
}