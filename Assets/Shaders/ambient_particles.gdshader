shader_type canvas_item;

// Uniforms para textura y animación
uniform sampler2D particle_texture : hint_default_black;
uniform ivec2 sprite_frames = ivec2(1, 1);
uniform float animation_speed : hint_range(0.1, 10.0) = 1.0;

// Uniforms para configuración de partículas
uniform int particle_type : hint_enum("Dust", "Embers", "Sparkles", "Smoke", "Coins") = 0;
uniform int particle_count : hint_range(50, 1000) = 150;
uniform float particle_speed : hint_range(0.1, 5.0, 0.001) = 1.0;
uniform float particle_size : hint_range(0.01, 5.0, 0.001) = 2.0;
uniform float min_size_scale : hint_range(0.01, 2.0, 0.01) = 0.5;
uniform float max_size_scale : hint_range(0.01, 5.0, 0.01) = 3.0;

// Nuevos uniforms para capas de profundidad
uniform int depth_layers : hint_range(2, 5) = 3;
uniform float depth_size_multiplier : hint_range(0.1, 1.0) = 0.3;
uniform float depth_speed_multiplier : hint_range(0.1, 1.0) = 0.6;
uniform float depth_alpha_multiplier : hint_range(0.1, 1.0) = 0.7;
uniform float layer_separation : hint_range(0.1, 2.0) = 0.8;

// Uniforms para colores
uniform vec4 primary_color : source_color = vec4(1.0, 0.84, 0.0, 1.0); // Dorado
uniform vec4 secondary_color : source_color = vec4(1.0, 0.55, 0.2, 1.0); // Naranja
uniform vec4 tertiary_color : source_color = vec4(1.0, 1.0, 1.0, 1.0); // Blanco

// Uniforms para comportamiento
uniform float time_scale : hint_range(0.1, 5.0) = 1.0;
uniform vec2 wind_direction = vec2(0.0, 0.0);
uniform float wind_strength : hint_range(0.0, 2.0) = 0.5;

// Función de ruido pseudo-aleatoria mejorada
float random(vec2 st) {
    return fract(sin(dot(st.xy, vec2(12.9898, 78.233))) * 43758.5453123);
}

// Función hash para mejor distribución
float hash(float n) {
    return fract(sin(n) * 43758.5453123);
}

// Función para obtener el frame de sprite correcto
vec2 get_sprite_uv(vec2 local_uv, int frame_index) {
    int total_frames = sprite_frames.x * sprite_frames.y;
    if (total_frames <= 1) {
        return local_uv; // Si no hay frames, usar UV completa
    }

    frame_index = frame_index % total_frames;

    int frame_x = frame_index % sprite_frames.x;
    int frame_y = frame_index / sprite_frames.x;

    vec2 frame_size = vec2(1.0) / vec2(sprite_frames);
    vec2 frame_offset = vec2(float(frame_x), float(frame_y)) * frame_size;

    return frame_offset + local_uv * frame_size;
}

// Función para calcular las propiedades de una capa
struct LayerProperties {
    float size_scale;
    float speed_scale;
    float alpha_scale;
    float time_offset;
    int particle_count;
};

LayerProperties get_layer_properties(int layer_index) {
    LayerProperties props;
    float layer_factor = float(layer_index) / float(depth_layers - 1);

    // Las capas más cercanas (menor índice) son más grandes
    // Las capas más alejadas (mayor índice) son más pequeñas
    props.size_scale = 1.0 + layer_factor * 2.0; // Capa 0: 1.0, última capa: 3.0
    props.speed_scale = 1.0 - layer_factor * (1.0 - depth_speed_multiplier);
    props.alpha_scale = 1.0 - layer_factor * (1.0 - depth_alpha_multiplier);
    props.time_offset = layer_factor * layer_separation;

    // Menos partículas en capas cercanas, más en capas lejanas
    float particle_distribution = 1.0 + layer_factor * 1.5; // Capa 0: 1.0, última: 2.5
    props.particle_count = int(float(particle_count) * particle_distribution / float(depth_layers * 2));

    return props;
}

// Función para calcular posición de partícula con capas y movimiento oscilatorio
vec2 calculate_particle_position(int particle_id, int layer_index, float time) {
    LayerProperties layer_props = get_layer_properties(layer_index);

    float fid = float(particle_id);
    vec2 seed = vec2(fid * 0.1234 + float(layer_index) * 0.987, fid * 0.5678 + float(layer_index) * 0.432);

    float speed_multiplier = particle_speed * time_scale * layer_props.speed_scale;
    float life_duration = 8.0 + random(seed) * 4.0;
    float adjusted_time = time + layer_props.time_offset;
    float life_time = mod(adjusted_time * speed_multiplier + fid * 0.1, life_duration);

    vec2 start_pos = vec2(random(seed), random(seed + vec2(1.0, 0.0)));
    vec2 base_velocity = vec2(0.0);

    // Configurar velocidad base según tipo de partícula
    if (particle_type == 0) { // Dust
        base_velocity = vec2(
            (random(seed + vec2(2.0, 0.0)) - 0.5) * 0.05,
            (random(seed + vec2(3.0, 0.0)) - 0.5) * 0.05
        );
    } else if (particle_type == 1) { // Embers
        start_pos.y = 1.1 + random(seed) * 0.2;
        base_velocity = vec2(
            (random(seed + vec2(2.0, 0.0)) - 0.5) * 0.1,
            -0.3 - random(seed + vec2(3.0, 0.0)) * 0.3
        );
    } else if (particle_type == 2) { // Sparkles
        base_velocity = vec2(
            (random(seed + vec2(2.0, 0.0)) - 0.5) * 0.15,
            (random(seed + vec2(3.0, 0.0)) - 0.5) * 0.15
        );
    } else if (particle_type == 3) { // Smoke
        base_velocity = vec2(
            (random(seed + vec2(2.0, 0.0)) - 0.5) * 0.08,
            -0.08 - random(seed + vec2(3.0, 0.0)) * 0.12
        );
    } else if (particle_type == 4) { // Coins
        start_pos.y = -0.1 - random(seed) * 0.2;
        base_velocity = vec2(
            (random(seed + vec2(2.0, 0.0)) - 0.5) * 0.05,
            0.2 + random(seed + vec2(3.0, 0.0)) * 0.2
        );
    }

    // Añadir movimiento oscilatorio
    float oscillation_freq_x = 0.5 + random(seed + vec2(4.0, 0.0)) * 1.0; // Frecuencia 0.5-1.5
    float oscillation_freq_y = 0.3 + random(seed + vec2(5.0, 0.0)) * 0.8; // Frecuencia 0.3-1.1
    float oscillation_amp_x = 0.02 + random(seed + vec2(6.0, 0.0)) * 0.08; // Amplitud 0.02-0.1
    float oscillation_amp_y = 0.015 + random(seed + vec2(7.0, 0.0)) * 0.06; // Amplitud 0.015-0.075

    vec2 oscillation = vec2(
        sin(adjusted_time * oscillation_freq_x + fid) * oscillation_amp_x,
        cos(adjusted_time * oscillation_freq_y + fid * 1.3) * oscillation_amp_y
    );

    // Aplicar viento con escala de capa
    vec2 wind_effect = wind_direction * wind_strength * 0.05 * layer_props.speed_scale;

    // Calcular posición final con movimiento base + oscilación
    vec2 pos = start_pos + (base_velocity + wind_effect) * life_time + oscillation;

    // Wraparound horizontal
    pos.x = mod(pos.x + 1.0, 1.0);

    return pos;
}

// Función para calcular alpha de partícula con capas
float calculate_particle_alpha(int particle_id, int layer_index, float time, vec2 pos) {
    LayerProperties layer_props = get_layer_properties(layer_index);

    float fid = float(particle_id);
    vec2 seed = vec2(fid * 0.1234 + float(layer_index) * 0.987, fid * 0.5678 + float(layer_index) * 0.432);

    float speed_multiplier = particle_speed * time_scale * layer_props.speed_scale;
    float life_duration = 8.0 + random(seed) * 4.0;
    float adjusted_time = time + layer_props.time_offset;
    float life_time = mod(adjusted_time * speed_multiplier + fid * 0.1, life_duration);
    float life_progress = life_time / life_duration;

    // Fade in/out suave
    float alpha = 1.0;
    if (life_progress < 0.2) {
        alpha = smoothstep(0.0, 0.2, life_progress);
    } else if (life_progress > 0.7) {
        alpha = smoothstep(1.0, 0.7, life_progress);
    }

    // Verificar si está en pantalla
    if (pos.x < -0.05 || pos.x > 1.05 || pos.y < -0.05 || pos.y > 1.05) {
        alpha = 0.0;
    }

    // Aplicar escala de alpha de la capa
    alpha *= layer_props.alpha_scale;

    return alpha * (0.4 + random(seed) * 0.4);
}

// Función para obtener color de partícula con variación por capa
vec4 get_particle_color(int type, int particle_id, int layer_index, float time) {
    float fid = float(particle_id);
    vec2 seed = vec2(fid * 0.1234 + float(layer_index) * 0.987, fid * 0.5678 + float(layer_index) * 0.432);
    float variation = random(seed);

    // Las capas más alejadas tienen colores ligeramente más desaturados
    float layer_factor = float(layer_index) / float(depth_layers - 1);
    float desaturation = layer_factor * 0.3; // Máximo 30% de desaturación

    vec4 base_color;

    if (type == 0) { // Dust - Dorado
        base_color = mix(primary_color, secondary_color, variation * 0.3);
    } else if (type == 1) { // Embers - Naranja/Rojo
        vec4 ember_color = vec4(1.0, 0.2, 0.0, secondary_color.a);
        base_color = mix(secondary_color, ember_color, variation * 0.5);
    } else if (type == 2) { // Sparkles - Blanco/Dorado
        base_color = mix(tertiary_color, primary_color, variation * 0.4);
    } else if (type == 3) { // Smoke - Gris
        vec4 smoke_base = vec4(0.8, 0.8, 0.8, 0.6);
        base_color = smoke_base * (0.5 + variation * 0.5);
    } else if (type == 4) { // Coins - Dorado
        base_color = primary_color;
    } else {
        base_color = primary_color;
    }

    // Aplicar desaturación para capas más alejadas
    float luminance = dot(base_color.rgb, vec3(0.299, 0.587, 0.114));
    base_color.rgb = mix(base_color.rgb, vec3(luminance), desaturation);

    return base_color;
}

void fragment() {
    vec2 uv = UV;
    vec4 final_color = vec4(0.0);
    float time = TIME * time_scale;

    // Procesar cada capa desde la más alejada hasta la más cercana
    for (int layer = depth_layers - 1; layer >= 0; layer--) {
        LayerProperties layer_props = get_layer_properties(layer);

        // Procesar partículas de esta capa (cada capa tiene diferente cantidad)
        for (int i = 0; i < layer_props.particle_count; i++) {
            int particle_id = layer * 1000 + i; // Usar offset grande para evitar colisiones

            vec2 particle_pos = calculate_particle_position(particle_id, layer, time);

            // Calcular distancia desde UV actual a posición de partícula
            vec2 diff = uv - particle_pos;
            float distance = length(diff);

            // Tamaño de partícula con clara diferenciación por capas
            float fid = float(particle_id);
            float size_variation = min_size_scale + random(vec2(fid * 0.1234, fid * 0.5678)) * (max_size_scale - min_size_scale);

            // Aplicar escalado de capa: capas cercanas más grandes, lejanas más pequeñas
            float base_size = particle_size * 0.015 * size_variation;
            float size = base_size;

            // Aplicar factor de capa invertido para que capa 0 sea más grande
            float layer_factor = float(layer) / float(depth_layers - 1);
            if (layer == 0) {
                size *= 2.5; // Capa más cercana: muy grande
            } else if (layer == 1 && depth_layers > 2) {
                size *= 1.8; // Segunda capa: grande
            } else if (layer == depth_layers - 1) {
                size *= 0.3; // Capa más lejana: muy pequeña
            } else {
                size *= (1.5 - layer_factor * 0.8); // Capas intermedias: escalado gradual
            }

            if (distance < size) {
                // Calcular UV local para la partícula
                vec2 local_uv = (diff / size) * 0.5 + 0.5;

                // Asegurar que local_uv esté en rango [0,1]
                if (local_uv.x >= 0.0 && local_uv.x <= 1.0 &&
                    local_uv.y >= 0.0 && local_uv.y <= 1.0) {

                    // Calcular frame de animación correctamente
                    float frame_time = time * animation_speed + fid * 0.1;
                    int total_frames = sprite_frames.x * sprite_frames.y;
                    int frame_index = 0;

                    if (total_frames > 1) {
                        frame_index = int(floor(frame_time)) % total_frames;
                    }

                    vec2 sprite_uv = get_sprite_uv(local_uv, frame_index);

                    // Obtener color de textura
                    vec4 tex_color = texture(particle_texture, sprite_uv);

                    // Solo procesar si la textura tiene alpha
                    if (tex_color.a > 0.01) {
                        // Obtener color de partícula con variación por capa
                        vec4 particle_color = get_particle_color(particle_type, particle_id, layer, time);

                        // Aplicar color de partícula respetando su transparencia
                        tex_color.rgb *= particle_color.rgb;
                        tex_color.a *= particle_color.a;

                        // Calcular alpha adicional
                        float additional_alpha = calculate_particle_alpha(particle_id, layer, time, particle_pos);

                        // Aplicar falloff circular suave
                        float falloff = 1.0 - smoothstep(0.7, 1.0, distance / size);
                        additional_alpha *= falloff;

                        // Aplicar alpha adicional
                        tex_color.a *= additional_alpha;

                        // Combinar con color final usando alpha blending
                        // Las capas más alejadas se mezclan de manera más sutil
                        float blend_factor = 1.0 - layer_factor * 0.3;
                        final_color.rgb += tex_color.rgb * tex_color.a * blend_factor;
                        final_color.a = max(final_color.a, tex_color.a);
                    }
                }
            }
        }
    }

    COLOR = final_color;
}