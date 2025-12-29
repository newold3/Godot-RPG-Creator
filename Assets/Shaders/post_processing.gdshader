shader_type canvas_item;

uniform float brightness : hint_range(-1.0, 1.0);
uniform float contrast : hint_range(0.0, 2.0);
uniform float blur_amount : hint_range(0.0, 2.0);
uniform vec3 color_tint : source_color;

void fragment() {
    // Obtener el color original de la textura
    vec4 color = texture(TEXTURE, UV);

    // Ajuste de brillo
    color.rgb += brightness;

    // Ajuste de contraste
    color.rgb = (color.rgb - 0.5) * contrast + 0.5;

    // Desenfoque
    vec4 blurred_color = vec4(0.0);
    float blur_size = blur_amount * 0.01;
    vec2 blur_direction = vec2(1.0, 1.0);
    for (float i = -4.0; i <= 4.0; i++) {
        blurred_color += textureLod(TEXTURE, UV + i * blur_size * blur_direction, 0.0);
    }
    blurred_color /= 9.0;

    // Mezcla entre el color original y el desenfoque
    color = mix(color, blurred_color, blur_amount);

    // Cambio de color
    color.rgb *= color_tint;

    // Asegurarse de que el color esté dentro del rango [0, 1]
    color.rgb = clamp(color.rgb, 0.0, 1.0);

    // Salida final
    COLOR = color;
}
