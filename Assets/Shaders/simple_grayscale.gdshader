shader_type canvas_item;

//* Enable or disable the grayscale effect */
uniform bool grayscale = false;

//* Grayscale blend intensity */
uniform float intensity : hint_range(0.0, 1.0) = 0.0;

//* Brightness adjustment */
uniform float brightness : hint_range(-1.0, 1.0) = 0.0;

//* Overall opacity */
uniform float opacity : hint_range(0.0, 1.0, 0.01) = 1.0;


void fragment() {
	vec4 color = texture(TEXTURE, UV);
	vec3 final_rgb = color.rgb;

	if (grayscale) {
		float gray = dot(color.rgb, vec3(0.299, 0.587, 0.114));
		gray = clamp(gray + brightness, 0.0, 1.0);
		final_rgb = mix(color.rgb, vec3(gray), intensity);
	}

	COLOR = vec4(final_rgb, color.a * opacity);
}