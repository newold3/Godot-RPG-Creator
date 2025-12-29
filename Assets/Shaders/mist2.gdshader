shader_type canvas_item;

uniform vec4 base_color : source_color;
uniform float location_fade;

void fragment() {
	vec3 fog_color_1 = texture(TEXTURE, vec2(UV.x / 2.0 + TIME / 100.0, UV.y / 4.0 - TIME / 100.0)).rgb;
	vec3 fog_color_2 = texture(TEXTURE, vec2(UV.x / 2.0 + 0.5 + TIME / 50.0, UV.y / 4.0 + 0.5 - TIME / 100.0)).rgb;
	vec3 fog_color_3 = texture(TEXTURE, vec2(UV.x / 2.0 + 0.25 + TIME / 25.0, UV.y / 4.0 - 0.25 + TIME / 100.0)).rgb;
	
	vec3 fog_color = mix(fog_color_3, mix(fog_color_1, fog_color_2, 0.5), 0.7);
	COLOR.a *= base_color.a * fog_color.r * 1.5;
	COLOR.rgb = fog_color * base_color.rgb;
	COLOR.rgb *= location_fade;
}