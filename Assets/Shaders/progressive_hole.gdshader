shader_type canvas_item;

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform vec4 cover_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform vec2 hole_position = vec2(0.5, 0.5);
uniform float edge_softness : hint_range(0.001, 0.1) = 0.073;
uniform float flicker_intensity : hint_range(0.0, 0.5) = 0.045;
uniform float flicker_speed : hint_range(0.1, 10.0) = 1.721;
uniform float circle_irregularity : hint_range(0.0, 1.0) = 0.02; // 0 = perfect circle, 1 = max distortion

void fragment() {
    vec2 uv = UV;

	vec2 resolution = 1.0 / TEXTURE_PIXEL_SIZE;

    // Adjust UV for aspect ratio correction
    vec2 aspect_ratio = vec2(SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x, 1.0);
    vec2 adjusted_uv = (uv - hole_position) * aspect_ratio;

    // Irregularity distortion (simple noise-like offset)
    float angle = atan(adjusted_uv.y, adjusted_uv.x);
    float distortion = sin(angle * 5.0 + TIME * 2.0) * circle_irregularity * 0.2;

    float distance = length(adjusted_uv) + distortion;

    float max_radius = length(vec2(1.0, 1.0));
    float base_radius = progress * max_radius;

    float flicker = sin(TIME * flicker_speed) * flicker_intensity;
    float current_radius = base_radius + (flicker * base_radius);

    vec4 final_color = cover_color;

    if (current_radius > 0.0) {
        float alpha_factor = smoothstep(
            current_radius - edge_softness,
            current_radius + edge_softness,
            distance
        );
        final_color.a = cover_color.a * alpha_factor;
    }

    COLOR = final_color;
}
