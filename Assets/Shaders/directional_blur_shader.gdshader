shader_type canvas_item;

uniform float progress : hint_range(0, 1);
uniform float intensity = 0.1;
uniform int copies = 5;
uniform float start_angle = 0.0;

void fragment() {
    vec2 uv = UV;
    vec4 final_color = vec4(0.0);

    for (int i = 0; i < copies; i++) {
        // Calcula el ángulo de manera uniforme, sumando el ángulo de inicio
        float angle = start_angle + (float(i) / float(copies)) * 6.28318530718; // 2π radianes distribuidos uniformemente
        vec2 dir = vec2(cos(angle), sin(angle));

        // Calcula el desplazamiento proporcional al progreso
        vec2 offset = dir * intensity * progress;

        // Muestra la textura con desplazamiento
        vec4 tex = texture(TEXTURE, uv + offset);

        // Mezcla aditiva
        final_color += tex;
    }

    // Normaliza el color resultante
    final_color /= float(copies);

    COLOR = final_color;
}
