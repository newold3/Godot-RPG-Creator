shader_type canvas_item;

uniform vec2 parallax_direction;
uniform float parallax_strength : hint_range(0.0, 1.0) = 0.5;
uniform float parallax_speed : hint_range(0.0, 5.0) = 1.0;

void fragment() {
    vec2 uv_offset = UV + parallax_direction * parallax_strength * TIME * parallax_speed;

    COLOR = texture(TEXTURE, uv_offset);
}
