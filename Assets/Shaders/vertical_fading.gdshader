shader_type canvas_item;

uniform sampler2D mask_texture;

void fragment() {
    // Obtener el color original de la textura
    vec4 original_color = texture(TEXTURE, UV);

    // Obtener el valor de la máscara
    vec4 mask_color = texture(mask_texture, UV);

    // Aplicar alpha solo si hay color en el pixel original
    float final_alpha = original_color.a > 0.0 ? mask_color.a : 0.0;

    COLOR = vec4(original_color.rgb, final_alpha);
}