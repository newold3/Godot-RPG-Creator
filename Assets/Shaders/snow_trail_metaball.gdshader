shader_type canvas_item;

uniform vec2 canvas_size = vec2(1.0, 1.0);
uniform vec2 trail_positions[16]; // Posiciones de los trails
uniform float trail_intensities[16]; // Intensidades de los trails
uniform int trail_count = 0; // Número de trails activos
uniform float trail_radius = 0.1; // Radio de cada trail
uniform float metaball_smoothness = 2.0; // Suavidad de la fusión
uniform sampler2D hole_texture : hint_default_white, repeat_enable; // Textura del agujero
uniform vec4 hole_color : source_color = vec4(1.0, 1.0, 1.0, 1.0); // Color de la textura

float metaball_function(vec2 pixel_pos, vec2 ball_pos, float radius, float intensity) {
    float dist = distance(pixel_pos, ball_pos);
    // Función de metaball: decae rápidamente con la distancia
    return intensity * pow(max(0.0, 1.0 - dist / radius), metaball_smoothness);
}

void fragment() {
    // Calcula el efecto de trail
    float total_trail_effect = 0.0;

    // Suma los efectos de todos los trails
    for (int i = 0; i < trail_count; i++) {
        // Calcula el efecto de metaball para este trail
        float ball_effect = metaball_function(
            UV,
            trail_positions[i],
            trail_radius,
            trail_intensities[i]
        );
        // Suma acumulativa de los efectos
        total_trail_effect += ball_effect;
    }

    // Limita el efecto total
    total_trail_effect = clamp(total_trail_effect, 0.0, 1.0);

    // Muestrea la textura del agujero
    vec4 texture_sample = texture(hole_texture, UV);

    // Combina el color de la textura con el color uniforme
    vec3 final_color = texture_sample.rgb * hole_color.rgb;

    // Establece el color final con alpha basado en el efecto de trail
    COLOR = vec4(final_color, texture_sample.a * total_trail_effect);
}