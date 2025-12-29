shader_type canvas_item;
uniform sampler2D overlay_tex: repeat_enable, filter_nearest;
uniform float scale = 0.006944444; // calculated by 1/texture size e.g. 1/144
uniform vec4 mask_color: source_color = vec4(1.0, 0.0, 0.0, 1.0);
uniform float overlay_alpha: hint_range(0.0, 1.0, 0.1) = 1.0;
uniform float color_tolerance: hint_range(0.0, 0.2, 0.01) = 0.05;
varying vec2 world_position;

void vertex(){
	// calculate the world position for use in the fragment shader
    world_position = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	float r_diff = abs(COLOR.r - mask_color.r);
	float g_diff = abs(COLOR.g - mask_color.g);
	float b_diff = abs(COLOR.b - mask_color.b);

	if (r_diff <= color_tolerance && g_diff <= color_tolerance && b_diff <= color_tolerance) {
		vec4 overlay_color = texture(overlay_tex, world_position * scale);

		float blend_factor = overlay_color.a * overlay_alpha;

		vec3 blended_rgb = mix(COLOR.rgb, overlay_color.rgb, blend_factor);

		COLOR = vec4(blended_rgb, COLOR.a);
	}
}