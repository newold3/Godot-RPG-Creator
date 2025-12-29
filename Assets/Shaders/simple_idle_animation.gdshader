shader_type canvas_item;

uniform bool enable_breathing = true;
uniform bool force_disable_breathing = false;
uniform float amplitude : hint_range(0.0, 0.2, 0.001) = 0.01;
uniform float breath_cycle : hint_range(0.5, 6.0) = 3.0; // Duración total del ciclo (más bajo = más rápido)
uniform float inhale_speed : hint_range(0.01, 20.0, 0.01) = 0.6; // Proporción de inhalación dentro del ciclo (0-1)
uniform float exhale_speed : hint_range(0.01, 20.0, 0.01) = 1.2; // Proporción de exhalación dentro del ciclo (0-1)
uniform float pause_duration : hint_range(0.0, 2.0) = 0.5; // Pausa entre respiraciones
uniform float random_offset = 0.0;
uniform float pivot = 0.75;
uniform vec4 blend_color: source_color = vec4(1.0);
uniform int blend_mode: hint_enum("Mix", "Add", "Subtract", "Multiply", "Premultiplied Alpha") = 0;
uniform sampler2D SCREEN_TEXTURE: hint_screen_texture, filter_nearest;

// Función para crear un ciclo de respiración natural
float breathing_cycle(float time) {
    // Normalizar el tiempo dentro del ciclo
    float cycle_time = mod(time, breath_cycle);
    float total_active = inhale_speed + exhale_speed;
    float cycle_normalized = cycle_time / total_active;

    // Fase de inhalación
    if (cycle_time < inhale_speed) {
        float t = cycle_time / inhale_speed;
        // Inhalación rápida con easing
        return sin(t * 3.14159 / 2.0); // Ease-out
    }
    // Fase de exhalación
    else if (cycle_time < (inhale_speed + exhale_speed)) {
        float t = (cycle_time - inhale_speed) / exhale_speed;
        // Exhalación lenta y controlada
        return mix(1.0, 0.0, t * t); // Ease-in quadratic
    }
    // Pausa (sin movimiento)
    else {
        return 0.0;
    }
}

// Función suavizada con easing
float ease_in_out_cubic(float t) {
    return t < 0.5 ? 4.0 * t * t * t : 1.0 - pow(-2.0 * t + 2.0, 3.0) / 2.0;
}

void fragment() {
    vec2 uv = UV;
    vec2 uv_displacement = uv;

    if (enable_breathing && !force_disable_breathing) {
        if (uv_displacement.y < pivot) {
            // Obtener el ciclo de respiración
            float breath = breathing_cycle(TIME + random_offset);

            // Aplicar amplitud con suavizado
            float factor = breath * amplitude;

            // Desplazar UV
            uv_displacement.y = pivot + (uv.y - pivot) * (1.0 + factor);
        }
    }

    vec4 tex_displacement = texture(TEXTURE, uv_displacement);
    vec4 screen_tex = texture(SCREEN_TEXTURE, SCREEN_UV);
    vec4 blended_tex = tex_displacement * blend_color;

    if (blended_tex.a == 0.0)
        discard;

    if (blend_mode == 0) // MIX
        COLOR = blended_tex;
    else if (blend_mode == 1) // ADD
        COLOR = screen_tex + blended_tex;
    else if (blend_mode == 2) { // SUBTRACT
        COLOR.rgb = screen_tex.rgb - blended_tex.rgb;
        COLOR.a = screen_tex.a;
    }
    else if (blend_mode == 3) { // MULTIPLY
        COLOR.rgb = screen_tex.rgb * blended_tex.rgb;
        COLOR.a = screen_tex.a * blended_tex.a;
    }
    else if (blend_mode == 4) // PREMULTIPLIED ALPHA
        COLOR = vec4(
            screen_tex.rgb * (1.0 - blended_tex.a) + blended_tex.rgb * blended_tex.a,
            screen_tex.a + blended_tex.a - screen_tex.a * blended_tex.a
        );
}