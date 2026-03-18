shader_type canvas_item;

//* Texture used for the bubbles */
uniform sampler2D bubble_texture;
//* Size of the canvas rect in pixels */
uniform vec2 rect_size = vec2(15.0, 200.0);
//* Base color to tint the bubbles */
uniform vec4 bubble_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
//* Maximum number of bubbles */
uniform int bubble_count = 20;
//* Base vertical speed in pixels per second */
uniform float base_speed = 30.0;
//* Movement direction (1.0 for down, -1.0 for up) */
uniform float direction = -1.0;
//* Base radius of the bubbles in pixels */
uniform float base_size = 6.0;
//* Width of the sideways oscillation in pixels */
uniform float oscillation_amplitude = 3.0;
//* Speed of the sideways oscillation */
uniform float oscillation_frequency = 2.0;


float get_random(vec2 uv) {
	return fract(sin(dot(uv, vec2(12.9898, 78.233))) * 43758.5453);
}


void fragment() {
	vec4 result = COLOR;
	vec2 uv = UV;
	uv.x *= rect_size.x / rect_size.y;
	vec2 pixel_pos = uv * rect_size;
	vec2 tex_size = max(vec2(textureSize(bubble_texture, 0)), vec2(1.0));
	vec2 tex_aspect = tex_size / max(tex_size.x, tex_size.y);
	float max_size = base_size * 2.0;
	float track_length = rect_size.y + max_size * 2.0;
	for (int i = 0; i < bubble_count; i++) {
		float seed = float(i) + 1.0;
		float r_pos = get_random(vec2(seed, 1.0));
		float r_speed = get_random(vec2(seed, 2.0));
		float r_size = get_random(vec2(seed, 3.0));
		float r_color = get_random(vec2(seed, 4.0));
		float r_offset = get_random(vec2(seed, 5.0));
		float current_speed = base_speed * (0.5 + 0.5 * r_speed);
		float travel_dist = TIME * current_speed * direction;
		float y_progress = fract(r_offset + (travel_dist / track_length));
		float y_pos = (y_progress * track_length) - max_size;
		float x_pos = (rect_size.x * r_pos) + sin(TIME * oscillation_frequency + r_offset * 10.0) * oscillation_amplitude;
		vec2 center = vec2(x_pos, y_pos);
		float current_size = base_size * (0.5 + 0.5 * r_size);
		vec2 local_uv = ((pixel_pos - center) / (current_size * tex_aspect)) * 0.5 + vec2(0.5);
		if (local_uv.x >= 0.0 && local_uv.x <= 1.0 && local_uv.y >= 0.0 && local_uv.y <= 1.0) {
			vec4 tex_color = texture(bubble_texture, local_uv);
			vec4 particle_color = mix(bubble_color, vec4(1.0, 1.0, 1.0, bubble_color.a), r_color * 0.4);
			float final_alpha = tex_color.a * particle_color.a;
			result.rgb = mix(result.rgb, tex_color.rgb * particle_color.rgb, final_alpha);
			result.a = max(result.a, final_alpha);
		}
	}
	COLOR = result;
}