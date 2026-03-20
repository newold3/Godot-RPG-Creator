shader_type canvas_item;

//* The seamless snow texture to be drawn over the map */
uniform sampler2D snow_texture : repeat_enable;
//* Tiling factor to scale the snow texture independently of the mask */
uniform vec2 snow_uv_scale = vec2(5.0, 5.0);
//* Maximum opacity of the snow layer over the map (0.0 to 1.0) */
uniform float max_snow_alpha : hint_range(0.0, 1.0) = 1.0;
//* Thickness of the simulated wall edge inside the trails */
uniform float edge_thickness : hint_range(0.0, 0.05) = 0.003;
//* Opacity of the depth shadow created by the edge detection */
uniform float shadow_opacity : hint_range(0.0, 1.0) = 0.8;


void fragment() {
	vec2 base_uv = UV;
	float mask_value = texture(TEXTURE, base_uv).r;
	
	vec2 offset_uv = base_uv - vec2(edge_thickness, edge_thickness);
	float offset_mask_value = texture(TEXTURE, offset_uv).r;
	
	float depth_shadow = clamp((mask_value - offset_mask_value) * 10.0, 0.0, 1.0);
	depth_shadow *= shadow_opacity;
	
	vec4 snow_color = texture(snow_texture, base_uv * snow_uv_scale);
	snow_color.rgb -= depth_shadow;
	
	float final_alpha = mask_value * snow_color.a * max_snow_alpha * COLOR.a;
	COLOR = vec4(snow_color.rgb, final_alpha);
}