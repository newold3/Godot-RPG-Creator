shader_type canvas_item;

/* Flash intensity (0.0 = normal, 1.0 = pure white flash) */
uniform float flash_intensity : hint_range(0.0, 1.0, 0.01) = 0.0;

/* Color of the flash (usually white or light blue for magic) */
uniform vec4 flash_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

void fragment() {
    vec4 tex_color = texture(TEXTURE, UV);
    
    // Mezcla el color de la textura con el color del destello manteniendo el canal Alfa intacto
    vec3 flashed_rgb = mix(tex_color.rgb, flash_color.rgb, flash_intensity);
    
    COLOR = vec4(flashed_rgb, tex_color.a);
}