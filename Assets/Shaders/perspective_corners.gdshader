shader_type canvas_item;

/* Top left offset */
uniform vec2 top_left = vec2(0.0, 0.0);
/* Top right offset */
uniform vec2 top_right = vec2(0.0, 0.0);
/* Bottom left offset */
uniform vec2 bottom_left = vec2(0.0, 0.0);
/* Bottom right offset */
uniform vec2 bottom_right = vec2(0.0, 0.0);

/* Total width of the book */
uniform float book_width = 1024.0;
/* Total height of the book */
uniform float book_height = 820.0;
/* Node X position to align local vertices with global book center */
uniform float node_x_offset = 0.0;
/* Node Y position to align local vertices vertically */
uniform float node_y_offset = 0.0;
/* Node scale to counteract transform scaling on absolute offsets */
uniform vec2 node_scale = vec2(1.0, 1.0);
/* Horizontal scale correction applied directly to the mesh vertices */
uniform float dynamic_scale_corr = 1.0;

void vertex() {
	VERTEX.x *= dynamic_scale_corr;

	float real_x = (VERTEX.x * node_scale.x) + node_x_offset;
	float real_y = (VERTEX.y * node_scale.y) + node_y_offset;
	
	vec2 norm_pos = vec2(
		(real_x + (book_width * 0.5)) / book_width,
		(real_y + (book_height * 0.5)) / book_height
	);
	
	vec2 top_offset = mix(top_left, top_right, norm_pos.x);
	vec2 bottom_offset = mix(bottom_left, bottom_right, norm_pos.x);
	vec2 final_offset = mix(top_offset, bottom_offset, norm_pos.y);
	
	vec2 safe_scale = node_scale;
	if (abs(safe_scale.x) < 0.0001) safe_scale.x = 0.0001 * sign(safe_scale.x != 0.0 ? safe_scale.x : 1.0);
	if (abs(safe_scale.y) < 0.0001) safe_scale.y = 0.0001 * sign(safe_scale.y != 0.0 ? safe_scale.y : 1.0);
	
	VERTEX += final_offset / safe_scale;
}