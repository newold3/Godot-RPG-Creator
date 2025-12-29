shader_type canvas_item;

// Textura con las siluetas de peces organizadas en filas y columnas
uniform sampler2D fish_sprites;
uniform sampler2D noise_texture;

// Configuración del spritesheet
uniform int sprite_columns : hint_range(1, 8) = 4;
uniform int sprite_rows : hint_range(1, 4) = 3;

// Parámetros de animación
uniform float time_scale : hint_range(0.1, 3.0) = 1.0;
uniform int fish_count : hint_range(3, 20) = 10;
uniform float base_speed : hint_range(0.02, 0.2) = 0.05;
uniform float wave_amplitude : hint_range(0.01, 0.15) = 0.03;
uniform float wave_frequency : hint_range(0.5, 4.0) = 2.0;
uniform float noise_intensity : hint_range(0.0, 0.1) = 0.03;
uniform float swim_sway : hint_range(0.0, 0.5) = 0.1;

// Parámetros de deformación de vértices
uniform float body_wave_amplitude : hint_range(0.0, 0.3) = 0.05;
uniform float body_wave_frequency : hint_range(1.0, 8.0) = 4.0;
uniform float tail_wave_amplitude : hint_range(0.0, 0.5) = 0.15;
uniform float tail_wave_frequency : hint_range(2.0, 12.0) = 6.0;
uniform float body_stretch : hint_range(0.0, 0.2) = 0.02;

// Colores y efectos
uniform vec4 fish_color : source_color = vec4(0.0, 0.0, 0.0, 0.9);
uniform vec4 background_color : source_color = vec4(0.2, 0.6, 1.0, 1.0);
uniform float fish_scale : hint_range(0.3, 2.0) = 0.8;

// Parámetros para variación de opacidad
uniform float opacity_variation : hint_range(0.0, 0.8) = 0.4;
uniform float darkening_variation : hint_range(0.0, 0.6) = 0.3;

uniform vec2 uv_scale = vec2(1.0);

// Función hash para generar valores pseudo-aleatorios
float hash(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

// Función hash para vectores 2D
vec2 hash2(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.xx + p3.yz) * p3.zy);
}

// Función hash para múltiples valores aleatorios
vec4 hash4(vec2 p) {
    vec4 p4 = fract(vec4(p.xyxy) * vec4(0.1031, 0.1030, 0.0973, 0.1099));
    p4 += dot(p4, p4.wzxy + 33.33);
    return fract((p4.xxyz + p4.yzzw) * p4.zywx);
}

// Función para obtener un sprite específico del spritesheet
vec4 get_sprite(vec2 uv, int sprite_index) {
    int total_sprites = sprite_columns * sprite_rows;
    sprite_index = sprite_index % total_sprites;

    int col = sprite_index % sprite_columns;
    int row = sprite_index / sprite_columns;

    vec2 sprite_size = vec2(1.0 / float(sprite_columns), 1.0 / float(sprite_rows));
    vec2 sprite_offset = vec2(float(col), float(row)) * sprite_size;

    vec2 sprite_uv = uv * sprite_size + sprite_offset;

    return texture(fish_sprites, sprite_uv);
}

// Función para rotar UV
vec2 rotate_uv(vec2 uv, vec2 center, float angle) {
    vec2 shifted = uv - center;
    float cos_a = cos(angle);
    float sin_a = sin(angle);
    vec2 rotated = vec2(
        shifted.x * cos_a - shifted.y * sin_a,
        shifted.x * sin_a + shifted.y * cos_a
    );
    return rotated + center;
}

// Función para deformar el UV del pez simulando movimiento de nado
vec2 deform_fish_uv(vec2 local_uv, float time, float fish_phase, float speed_variation) {
    // Centrar el UV en el rango [-0.5, 0.5] para las deformaciones
    vec2 centered_uv = local_uv - 0.5;

    // Coordenada X normalizada (-1 a 1, donde -1 es la cabeza y 1 es la cola)
    float x_normalized = centered_uv.x * 2.0;

    // Deformación del cuerpo - ondulación que se propaga de cabeza a cola
    float body_wave_phase = time * body_wave_frequency * speed_variation + fish_phase;
    float body_wave = sin(body_wave_phase + x_normalized * 3.14159) * body_wave_amplitude;

    // Intensidad de la deformación aumenta hacia la cola
    float tail_intensity = smoothstep(-0.3, 1.0, x_normalized);
    body_wave *= tail_intensity;

    // Deformación de la cola - movimiento más pronunciado
    float tail_wave_phase = time * tail_wave_frequency * speed_variation + fish_phase;
    float tail_wave = sin(tail_wave_phase + x_normalized * 1.5) * tail_wave_amplitude;

    // Solo aplicar deformación de cola en la parte trasera del pez
    float tail_mask = smoothstep(0.2, 1.0, x_normalized);
    tail_wave *= tail_mask;

    // Estiramiento del cuerpo durante el nado
    float stretch_phase = time * body_wave_frequency * 0.5 * speed_variation + fish_phase;
    float stretch_factor = 1.0 + sin(stretch_phase) * body_stretch * tail_intensity;

    // Aplicar deformaciones
    vec2 deformed_uv = centered_uv;

    // Aplicar ondulación vertical
    deformed_uv.y += body_wave + tail_wave;

    // Aplicar estiramiento horizontal
    deformed_uv.x *= stretch_factor;

    // Deformación adicional para simular la flexión del cuerpo
    float body_bend_phase = time * body_wave_frequency * 0.3 * speed_variation + fish_phase;
    float body_bend = sin(body_bend_phase) * 0.02;
    deformed_uv.x += body_bend * x_normalized * tail_intensity;

    // Volver al rango [0, 1]
    return deformed_uv + 0.5;
}

void fragment() {
    vec2 uv = UV / uv_scale;
    float time = TIME * time_scale;

    vec4 final_color = background_color;

    // Dibujar múltiples peces
    for (int i = 0; i < fish_count; i++) {
        float fish_id = float(i);
        vec2 fish_seed = vec2(fish_id * 0.137 + 12.345, fish_id * 0.419 + 67.891);

        // Generar TODOS los valores aleatorios usando diferentes seeds
        vec4 random_values_1 = hash4(fish_seed);
        vec4 random_values_2 = hash4(fish_seed + vec2(100.0, 200.0));
        vec4 random_values_3 = hash4(fish_seed + vec2(300.0, 400.0));
        vec4 random_values_4 = hash4(fish_seed + vec2(500.0, 600.0));

        // Generar dirección CONSTANTE para cada pez
        vec2 direction = normalize(random_values_1.xy * 2.0 - 1.0);

        // Propiedades únicas para cada pez usando los valores aleatorios
        float speed_variation = 0.5 + random_values_1.z * 1.5;
        float size_variation = 0.6 + random_values_1.w * 0.8;
        float phase_offset = random_values_2.x * 6.28318;
        int sprite_index = int(random_values_2.y * float(sprite_columns * sprite_rows));

        // Variaciones de opacidad y color
        float opacity_factor = 1.0 - (random_values_2.z * opacity_variation);
        float darkening_factor = 1.0 - (random_values_2.w * darkening_variation);

        // Fase única para deformación de cada pez
        float deform_phase = random_values_3.x * 6.28318;

        // Punto de inicio aleatorio
        vec2 start_pos = random_values_3.yz * vec2(1.4, 1.2) - vec2(0.2, 0.1);

        // Movimiento lineal CONSTANTE en la dirección fija
        vec2 base_movement = direction * time * base_speed * speed_variation;

        // Aplicar ruido de la textura para movimiento orgánico
        vec2 noise_coord = (start_pos + base_movement) * 2.0 + time * 0.1;
        float noise_sample = texture(noise_texture, noise_coord * 0.1).r;
        vec2 noise_offset = vec2(
            sin(noise_sample * 6.28318 + time),
            cos(noise_sample * 6.28318 + time * 1.3)
        ) * noise_intensity * random_values_3.w; // Variación individual del ruido

        // Ondulación adicional basada en seno y coseno
        float wave_phase = time * wave_frequency * speed_variation + phase_offset;
        vec2 wave_offset = vec2(
            sin(wave_phase) * wave_amplitude,
            cos(wave_phase * 0.7) * wave_amplitude
        ) * random_values_4.x; // Variación individual de la ondulación

        // Posición final
        vec2 fish_center = start_pos + base_movement + noise_offset + wave_offset;

        // Wrapping
        fish_center = mod(fish_center + vec2(0.3, 0.2), vec2(1.6, 1.4)) - vec2(0.3, 0.2);

        // CORRECCIÓN DE ROTACIÓN: Los sprites miran hacia la derecha (0°)
        // Calcular ángulo basado en la dirección de movimiento
        float base_angle = atan(direction.y, direction.x);

        // Añadir balanceo/sway para simular el movimiento de nado
        float sway_frequency = wave_frequency + random_values_4.y * 2.0; // Frecuencia de balanceo individual
        float sway_angle = sin(time * sway_frequency * 2.0 + phase_offset) * swim_sway * random_values_4.z;

        // Rotación total
        float total_rotation = base_angle + sway_angle;

        // Tamaño del pez con variación individual
        float individual_scale = 0.7 + random_values_4.w * 0.6; // Escala adicional individual
        float fish_size = fish_scale * size_variation * individual_scale * 0.08;

        // Solo procesar peces visibles
        if (fish_center.x > -0.2 && fish_center.x < 1.2 &&
            fish_center.y > -0.2 && fish_center.y < 1.2) {

            // Calcular UV local para el pez
            vec2 local_uv = (uv - fish_center) / fish_size;

            // Aplicar rotación para alinear con la dirección de movimiento
            local_uv = rotate_uv(local_uv, vec2(0.0), -total_rotation); // Nota el signo negativo

            // Centrar en el sprite
            local_uv = local_uv * 0.5 + 0.5;

            // APLICAR DEFORMACIÓN DE VÉRTICES con variación de velocidad individual
            vec2 deformed_uv = deform_fish_uv(local_uv, time, deform_phase, speed_variation);

            // Verificar si estamos dentro del área del sprite
            if (deformed_uv.x >= -0.1 && deformed_uv.x <= 1.1 &&
                deformed_uv.y >= -0.1 && deformed_uv.y <= 1.1) {

                // Clamp UV para evitar sampling fuera de rango
                vec2 clamped_uv = clamp(deformed_uv, vec2(0.0), vec2(1.0));
                vec4 sprite_sample = get_sprite(clamped_uv, sprite_index);

                // Usar SOLO el alpha del sprite
                float fish_mask = sprite_sample.a;

                // Suavizar el alpha en los bordes para evitar artefactos
                float edge_softness = 0.05;
                if (deformed_uv.x < edge_softness) {
                    fish_mask *= smoothstep(0.0, edge_softness, deformed_uv.x);
                }
                if (deformed_uv.x > 1.0 - edge_softness) {
                    fish_mask *= smoothstep(1.0, 1.0 - edge_softness, deformed_uv.x);
                }
                if (deformed_uv.y < edge_softness) {
                    fish_mask *= smoothstep(0.0, edge_softness, deformed_uv.y);
                }
                if (deformed_uv.y > 1.0 - edge_softness) {
                    fish_mask *= smoothstep(1.0, 1.0 - edge_softness, deformed_uv.y);
                }

                // Fade in/out en los bordes de la pantalla
                float screen_fade = 1.0;
                float margin = 0.1;

                if (fish_center.x < margin) {
                    screen_fade *= smoothstep(0.0, margin, fish_center.x * 0.5);
                }
                if (fish_center.x > 1.0 - margin) {
                    screen_fade *= smoothstep(1.0, 1.0 - margin, fish_center.x);
                }
                if (fish_center.y < margin) {
                    screen_fade *= smoothstep(0.0, margin, fish_center.y);
                }
                if (fish_center.y > 1.0 - margin) {
                    screen_fade *= smoothstep(1.0, 1.0 - margin, fish_center.y);
                }

                fish_mask *= screen_fade;

                // Aplicar variaciones de color y opacidad individuales
                vec3 individual_color = fish_color.rgb * darkening_factor;
                float individual_alpha = fish_color.a * opacity_factor * fish_mask;

                vec4 final_fish_color = vec4(individual_color, individual_alpha);

                // Mezclar con el fondo
                final_color = mix(final_color, final_fish_color, final_fish_color.a);
            }
        }
    }

    COLOR = final_color;
}