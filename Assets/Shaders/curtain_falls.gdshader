shader_type canvas_item;

// Parámetro principal de control
uniform float curtain_progress : hint_range(0.0, 1.0) = 0.0; // 0 = cerrada, 1 = abierta

// Parámetros de apariencia
uniform vec4 curtain_color : source_color = vec4(0.8, 0.2, 0.2, 1.0);
uniform vec4 curtain_shadow : source_color = vec4(0.4, 0.1, 0.1, 1.0);

// Parámetros de pliegues
uniform float fold_frequency : hint_range(5.0, 100.0) = 20.0;
uniform float fold_amplitude : hint_range(0.01, 0.1) = 0.05;
uniform float fold_depth : hint_range(0.1, 1.0) = 0.5;

// Parámetros de física y movimiento
uniform float wave_amplitude : hint_range(0.001, 0.05) = 0.02;
uniform float collision_intensity : hint_range(0.0, 2.0) = 1.0;

// Parámetros de iluminación
uniform float light_intensity : hint_range(0.5, 2.0) = 1.2;
uniform vec2 light_direction = vec2(-0.5, -0.3);

vec2 get_curtain_position(vec2 uv) {
    float curtain_center = 0.5;
    
    // Altura normalizada (0 en la parte superior, 1 en la inferior)
    float height_factor = uv.y;
    
    // Ángulo de la cortina - más ancho abajo, más estrecho arriba
    float curtain_angle = 0.3; // Ajusta este valor para cambiar el ángulo
    float width_at_height = 1.0 - (1.0 - height_factor) * curtain_angle;
    
    // Separación que varía con la altura y el progreso
    float base_separation = curtain_progress * 0.5;
    float separation = base_separation * width_at_height;
    
    // Determinar qué lado de la cortina
    bool is_left_curtain = uv.x < curtain_center;
    
    // Calcular posición de cada cortina según la altura
    float left_edge = curtain_center - separation;
    float right_edge = curtain_center + separation;
    
    // Crear UV modificada para cada cortina
    vec2 modified_uv = uv;
    
    if (is_left_curtain) {
        // Cortina izquierda
        if (uv.x > left_edge) {
            modified_uv.x = -1.0; // Marca para transparencia
        } else {
            // Mapear considerando la forma triangular
            float available_width = left_edge;
            if (available_width > 0.001) {
                modified_uv.x = uv.x / available_width * 0.5;
            } else {
                modified_uv.x = 0.25; // Centro de la cortina izquierda
            }
        }
    } else {
        // Cortina derecha
        if (uv.x < right_edge) {
            modified_uv.x = -1.0; // Marca para transparencia
        } else {
            // Mapear y espejar considerando la forma triangular
            float available_width = 1.0 - right_edge;
            if (available_width > 0.001) {
                float normalized_x = (uv.x - right_edge) / available_width;
                modified_uv.x = 1.0 - (normalized_x * 0.5 + 0.5);
            } else {
                modified_uv.x = 0.75; // Centro de la cortina derecha
            }
        }
    }
    
    return modified_uv;
}

vec3 calculate_static_folds(vec2 uv) {
    // Pliegues estáticos que no cambian durante la animación
    // Usar frecuencia más baja para pliegues más grandes
    float main_folds = sin(uv.x * fold_frequency * 0.6) * fold_amplitude;
    float secondary_folds = sin(uv.x * fold_frequency * 1.2 + 1.0) * fold_amplitude * 0.4;
    float detail_folds = sin(uv.x * fold_frequency * 0.3 + 2.0) * fold_amplitude * 0.2;
    
    float fold_pattern = main_folds + secondary_folds + detail_folds;
    
    // Variación vertical sutil
    float height_variation = sin(uv.y * 3.14159) * 0.2 + 0.8;
    fold_pattern *= height_variation;
    
    // Calcular normal para iluminación
    float fold_gradient = cos(uv.x * fold_frequency * 0.6) * fold_amplitude * fold_frequency * 0.6;
    fold_gradient += cos(uv.x * fold_frequency * 1.2 + 1.0) * fold_amplitude * fold_frequency * 0.48;
    
    vec3 fold_normal = normalize(vec3(fold_gradient, 0.0, 1.0));
    
    return vec3(fold_pattern, fold_normal.xy);
}

float calculate_curtain_thickness(vec2 uv, float progress) {
    float curtain_center = 0.5;
    
    // Distancia desde el centro original
    float distance_from_center = abs(uv.x - curtain_center);
    
    // Mantener el grosor muy similar - máximo factor de 2.0 como pediste
    float thickness_multiplier = 1.0 + distance_from_center * progress * 0.8;
    
    // Limitar el factor máximo a 2.0
    thickness_multiplier = min(thickness_multiplier, 2.0);
    
    // Muy poca compresión cuando está cerrada
    if (progress < 0.2) {
        thickness_multiplier *= 1.0 + (0.2 - progress) * 0.15;
    }
    
    return thickness_multiplier;
}

vec2 apply_curtain_physics(vec2 uv, float progress) {
    vec2 modified_uv = uv;
    float curtain_center = 0.5;
    
    // Solo aplicar efectos de física menores
    float distance_from_center = abs(uv.x - curtain_center);
    
    // Pequeña ondulación por el movimiento (muy sutil)
    if (progress > 0.1 && progress < 0.9) {
        float movement_wave = sin(uv.y * 8.0) * wave_amplitude * 0.5;
        movement_wave *= sin(progress * 3.14159); // Máximo en el medio del movimiento
        movement_wave *= distance_from_center * 2.0; // Más efecto lejos del centro
        
        modified_uv.x += movement_wave;
    }
    
    // Efecto de colisión muy sutil cuando se cierra
    if (progress < 0.2) {
        float collision_wave = sin(uv.y * 12.0) * collision_intensity * wave_amplitude * 0.3;
        collision_wave *= (0.2 - progress) * 5.0;
        collision_wave *= exp(-distance_from_center * 3.0);
        
        modified_uv.x += collision_wave;
    }
    
    return modified_uv;
}

vec4 apply_lighting(vec4 base_color, vec3 normal, vec2 uv, float thickness) {
    // Iluminación básica
    vec3 light_dir = normalize(vec3(light_direction, 0.5));
    float lighting = dot(normal, light_dir) * 0.5 + 0.5;
    lighting = pow(lighting, 1.2) * light_intensity;
    
    // Sombras en los pliegues
    float shadow_factor = 1.0 - abs(normal.x) * fold_depth;
    shadow_factor *= thickness; // Las partes más gruesas son más oscuras
    
    // Mezclar color base con sombras
    vec4 lit_color = mix(curtain_shadow, base_color, shadow_factor);
    lit_color.rgb *= lighting;
    
    // Highlights sutiles
    float highlight = pow(max(0.0, dot(normal, vec3(0.0, 0.0, 1.0))), 4.0) * 0.2;
    lit_color.rgb += highlight;
    
    // Variación de color por grosor (mucho más sutil)
    lit_color.rgb *= mix(1.0, 0.95, (thickness - 1.0) * 0.3);
    
    return lit_color;
}

void fragment() {
    vec2 uv = UV;
    
    // Obtener la posición de la cortina
    vec2 curtain_uv = get_curtain_position(uv);
    
    // Inicializar color final como transparente
    vec4 final_color = vec4(0.0, 0.0, 0.0, 0.0);
    
    // Solo procesar si no está marcado para transparencia
    if (curtain_uv.x >= 0.0) {
        // Aplicar física sutil
        vec2 physics_uv = apply_curtain_physics(curtain_uv, curtain_progress);
        
        // Calcular pliegues estáticos
        vec3 fold_data = calculate_static_folds(physics_uv);
        
        // Calcular grosor de la cortina
        float thickness = calculate_curtain_thickness(uv, curtain_progress);
        
        // Aplicar desplazamiento de pliegues
        vec2 final_uv = physics_uv;
        final_uv.x += fold_data.x * thickness;
        
        // Normal de superficie para iluminación
        vec3 surface_normal = vec3(fold_data.yz, sqrt(max(0.001, 1.0 - dot(fold_data.yz, fold_data.yz))));
        
        // Color base
        vec4 base_color = curtain_color;
        
        // Si tienes una textura:
        // base_color *= texture(TEXTURE, final_uv);
        
        // Aplicar iluminación
        final_color = apply_lighting(base_color, surface_normal, final_uv, thickness);
        
        // Alpha completo - SIN difuminado en ningún borde
        final_color.a = base_color.a;
    }
    
    COLOR = final_color;
}