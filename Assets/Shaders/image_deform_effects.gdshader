shader_type canvas_item;

// Tipo de curvatura
uniform int curve_type : hint_enum("None", "Arc", "Arc Down", "Arc Up", "Wave", "Bridge Down", "Bridge Up") = 0;

// Parámetros de deformación
uniform float bend : hint_range(-100.0, 100.0) = 0.0; // Curvatura tipo Photoshop
uniform float horizontal_distortion : hint_range(-100.0, 100.0) = 0.0; // Estiramiento/compresión horizontal
uniform float vertical_distortion : hint_range(-100.0, 100.0) = 0.0; // Estiramiento/compresión vertical

// Esferizar
uniform float spherize_amount : hint_range(-1.0, 1.0) = 0.0;

// Centro del efecto (normalizado 0.0 a 1.0)
uniform vec2 center = vec2(0.5, 0.5);

void fragment() {
    vec2 uv = UV;
    vec2 offset = vec2(0.0);

    float normalized_bend = bend / 100.0;
    float normalized_h_dist = horizontal_distortion / 100.0;
    float normalized_v_dist = vertical_distortion / 100.0;

    // Desplazamientos
    float dx = uv.x - center.x;
    float dy = uv.y - center.y;

    if (curve_type != 0) {
        if (curve_type == 1) { // Arc
            offset.y = normalized_bend * (dx * dx) * 2.5; // Más fuerte que otros
        }
        else if (curve_type == 2) { // Arc Down
            offset.y = -normalized_bend * (dx * dx) * 1.5;
        }
        else if (curve_type == 3) { // Arc Up
            offset.y = normalized_bend * (dx * dx) * 1.5;
        }
        else if (curve_type == 4) { // Wave
            offset.y = normalized_bend * sin(dx * 12.0) * 0.2;
        }
        else if (curve_type == 5) { // Bridge Down
            float factor = abs(dx) * 2.0;
            offset.y = -normalized_bend * factor;
        }
        else if (curve_type == 6) { // Bridge Up
            float factor = abs(dx) * 2.0;
            offset.y = normalized_bend * factor;
        }
    }

    // Distorsión horizontal/vertical
    offset.x += normalized_h_dist * dx * abs(dx);
    offset.y += normalized_v_dist * dy * abs(dy);

    // Esferizar
    if (spherize_amount != 0.0) {
        float r = distance(uv, center);
        if (r > 0.0) {
            float spherize_strength = spherize_amount * (1.0 - r * r);
            vec2 dir = normalize(uv - center);
            offset += dir * r * spherize_strength;
        }
    }

    vec2 final_uv = uv + offset;

    // Muestreamos la textura final
    vec4 color = texture(TEXTURE, final_uv);

    // Si UV está fuera, ponemos transparencia
    if (final_uv.x < 0.0 || final_uv.x > 1.0 || final_uv.y < 0.0 || final_uv.y > 1.0) {
        COLOR = vec4(0.0, 0.0, 0.0, 0.0);
    } else {
        COLOR = color;
    }
}
