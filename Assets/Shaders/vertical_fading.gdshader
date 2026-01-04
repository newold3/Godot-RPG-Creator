shader_type canvas_item;

uniform sampler2D mask_texture;

void fragment() {
    // Get original texture color
    vec4 original_color = texture(TEXTURE, UV);

    // Get mask value
    vec4 mask_color = texture(mask_texture, UV);

    // Apply alpha only if there is color in original pixel
    float final_alpha = original_color.a > 0.0 ? mask_color.a : 0.0;

    COLOR = vec4(original_color.rgb, final_alpha);
}