shader_type canvas_item;
render_mode blend_premul_alpha;

// Parámetros ajustables
uniform vec4 mask_color : source_color = vec4(0.0, 0.0, 0.0, 1.0); // Color a eliminar (negro por defecto)
uniform float threshold : hint_range(0.0, 1.0, 0.01) = 0.1; // Umbral de tolerancia

void fragment() {
    vec4 tex_color = texture(TEXTURE, UV);

    float diff = distance(tex_color.rgb, mask_color.rgb);

    if (diff <= threshold) {
        COLOR.a = 0.01;
    } else {
        COLOR = tex_color;
    }
}