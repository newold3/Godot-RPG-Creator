shader_type canvas_item;

uniform sampler2D SCREEN_TEXTURE: hint_screen_texture;
uniform sampler2D mask;
uniform float intensity: hint_range(0.0, 1.0, 0.01) = 1.0;


void fragment() {
	vec4 mask_color = texture(mask, UV);
    vec4 color = texture(SCREEN_TEXTURE, SCREEN_UV);
    float grey = dot(color.rgb, vec3(0.299, 0.587, 0.114));

    vec4 final_color = vec4(grey, grey, grey, color.a);
    COLOR = mix(vec4(0.0), final_color, mask_color.a * intensity);
}