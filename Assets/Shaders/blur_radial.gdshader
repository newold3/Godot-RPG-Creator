shader_type canvas_item;

// Parámetros ajustables para controlar la curva
uniform float curvature_intensity : hint_range(-1.0, 1.0) = 0.2; // Intensidad de la curvatura
uniform float curvature_offset : hint_range(-1.0, 1.0) = 0.0; // Desplazamiento vertical de la curva
uniform bool vertical_arc = false; // Si es true, curva verticalmente en lugar de horizontalmente

void fragment() {
    // Coordenadas normalizadas (0-1)
    vec2 uv = UV;

    if (vertical_arc) {
        // Deformación vertical (arco horizontal)
        float relative_x = uv.x - 0.5; // Centrado en X
        float displacement = curvature_intensity * relative_x * relative_x;

        // Aplicamos la deformación en Y
        uv.y = uv.y - displacement + curvature_offset;
    } else {
        // Deformación horizontal (arco vertical)
        float relative_y = uv.y - 0.5; // Centrado en Y
        float displacement = curvature_intensity * relative_y * relative_y;

        // Aplicamos la deformación en X
        uv.x = uv.x - displacement + curvature_offset;
    }

    // Muestreamos el color original con las nuevas coordenadas UV
    COLOR = texture(TEXTURE, uv);

    // Opcionalmente, podemos manejar las áreas que quedan fuera de los límites
    // Si uv está fuera del rango [0,1], hacemos ese píxel transparente
    if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
        COLOR.a = 0.0; // Transparente
    }
}