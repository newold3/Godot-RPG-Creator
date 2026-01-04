shader_type canvas_item;

// Main control parameter
uniform float curtain_progress : hint_range(0.0, 1.0) = 0.0; // 0 = closed, 1 = open

// Appearance parameters
uniform vec4 curtain_color : source_color = vec4(0.8, 0.2, 0.2, 1.0);
uniform vec4 curtain_shadow : source_color = vec4(0.4, 0.1, 0.1, 1.0);

// Fold parameters
uniform float fold_frequency : hint_range(5.0, 100.0) = 20.0;
uniform float fold_amplitude : hint_range(0.01, 0.1) = 0.05;
uniform float fold_depth : hint_range(0.1, 1.0) = 0.5;

// Physics and movement parameters
uniform float wave_amplitude : hint_range(0.001, 0.05) = 0.02;
uniform float collision_intensity : hint_range(0.0, 2.0) = 1.0;

// Lighting parameters
uniform float light_intensity : hint_range(0.5, 2.0) = 1.2;
uniform vec2 light_direction = vec2(-0.5, -0.3);

vec2 get_curtain_position(vec2 uv) {
    float curtain_center = 0.5;
    
    // Normalized height (0 at the top, 1 at the bottom)
    float height_factor = uv.y;
    
    // Curtain angle - wider at the bottom, narrower at the top
    float curtain_angle = 0.3; // Adjust this value to change the angle
    float width_at_height = 1.0 - (1.0 - height_factor) * curtain_angle;
    
    // Separation varies with height and progress
    float base_separation = curtain_progress * 0.5;
    float separation = base_separation * width_at_height;
    
    // Determine which side of the curtain
    bool is_left_curtain = uv.x < curtain_center;
    
    // Calculate position of each curtain based on height
    float left_edge = curtain_center - separation;
    float right_edge = curtain_center + separation;
    
    // Create modified UV for each curtain
    vec2 modified_uv = uv;
    
    if (is_left_curtain) {
        // Left curtain
        if (uv.x > left_edge) {
            modified_uv.x = -1.0; // Mark for transparency
        } else {
            // Map considering the triangular shape
            float available_width = left_edge;
            if (available_width > 0.001) {
                modified_uv.x = uv.x / available_width * 0.5;
            } else {
                modified_uv.x = 0.25; // Center of left curtain
            }
        }
    } else {
        // Right curtain
        if (uv.x < right_edge) {
            modified_uv.x = -1.0; // Mark for transparency
        } else {
            // Map and mirror considering the triangular shape
            float available_width = 1.0 - right_edge;
            if (available_width > 0.001) {
                float normalized_x = (uv.x - right_edge) / available_width;
                modified_uv.x = 1.0 - (normalized_x * 0.5 + 0.5);
            } else {
                modified_uv.x = 0.75; // Center of right curtain
            }
        }
    }
    
    return modified_uv;
}

vec3 calculate_static_folds(vec2 uv) {
    // Static folds that do not change during animation
    // Use lower frequency for larger folds
    float main_folds = sin(uv.x * fold_frequency * 0.6) * fold_amplitude;
    float secondary_folds = sin(uv.x * fold_frequency * 1.2 + 1.0) * fold_amplitude * 0.4;
    float detail_folds = sin(uv.x * fold_frequency * 0.3 + 2.0) * fold_amplitude * 0.2;
    
    float fold_pattern = main_folds + secondary_folds + detail_folds;
    
    // Subtle vertical variation
    float height_variation = sin(uv.y * 3.14159) * 0.2 + 0.8;
    fold_pattern *= height_variation;
    
    // Calculate normal for lighting
    float fold_gradient = cos(uv.x * fold_frequency * 0.6) * fold_amplitude * fold_frequency * 0.6;
    fold_gradient += cos(uv.x * fold_frequency * 1.2 + 1.0) * fold_amplitude * fold_frequency * 0.48;
    
    vec3 fold_normal = normalize(vec3(fold_gradient, 0.0, 1.0));
    
    return vec3(fold_pattern, fold_normal.xy);
}

float calculate_curtain_thickness(vec2 uv, float progress) {
    float curtain_center = 0.5;
    
    // Distance from original center
    float distance_from_center = abs(uv.x - curtain_center);
    
    // Keep thickness very similar - max factor of 2.0 as requested
    float thickness_multiplier = 1.0 + distance_from_center * progress * 0.8;
    
    // Limit max factor to 2.0
    thickness_multiplier = min(thickness_multiplier, 2.0);
    
    // Very little compression when closed
    if (progress < 0.2) {
        thickness_multiplier *= 1.0 + (0.2 - progress) * 0.15;
    }
    
    return thickness_multiplier;
}

vec2 apply_curtain_physics(vec2 uv, float progress) {
    vec2 modified_uv = uv;
    float curtain_center = 0.5;
    
    // Only apply minor physics effects
    float distance_from_center = abs(uv.x - curtain_center);
    
    // Small undulation from movement (very subtle)
    if (progress > 0.1 && progress < 0.9) {
        float movement_wave = sin(uv.y * 8.0) * wave_amplitude * 0.5;
        movement_wave *= sin(progress * 3.14159); // Max in the middle of movement
        movement_wave *= distance_from_center * 2.0; // More effect away from center
        
        modified_uv.x += movement_wave;
    }
    
    // Very subtle collision effect when closing
    if (progress < 0.2) {
        float collision_wave = sin(uv.y * 12.0) * collision_intensity * wave_amplitude * 0.3;
        collision_wave *= (0.2 - progress) * 5.0;
        collision_wave *= exp(-distance_from_center * 3.0);
        
        modified_uv.x += collision_wave;
    }
    
    return modified_uv;
}

vec4 apply_lighting(vec4 base_color, vec3 normal, vec2 uv, float thickness) {
    // Basic lighting
    vec3 light_dir = normalize(vec3(light_direction, 0.5));
    float lighting = dot(normal, light_dir) * 0.5 + 0.5;
    lighting = pow(lighting, 1.2) * light_intensity;
    
    // Shadows in folds
    float shadow_factor = 1.0 - abs(normal.x) * fold_depth;
    shadow_factor *= thickness; // Thicker parts are darker
    
    // Mix base color with shadows
    vec4 lit_color = mix(curtain_shadow, base_color, shadow_factor);
    lit_color.rgb *= lighting;
    
    // Subtle highlights
    float highlight = pow(max(0.0, dot(normal, vec3(0.0, 0.0, 1.0))), 4.0) * 0.2;
    lit_color.rgb += highlight;
    
    // Color variation by thickness (much more subtle)
    lit_color.rgb *= mix(1.0, 0.95, (thickness - 1.0) * 0.3);
    
    return lit_color;
}

void fragment() {
    vec2 uv = UV;
    
    // Get curtain position
    vec2 curtain_uv = get_curtain_position(uv);
    
    // Initialize final color as transparent
    vec4 final_color = vec4(0.0, 0.0, 0.0, 0.0);
    
    // Only process if not marked for transparency
    if (curtain_uv.x >= 0.0) {
        // Apply subtle physics
        vec2 physics_uv = apply_curtain_physics(curtain_uv, curtain_progress);
        
        // Calculate static folds
        vec3 fold_data = calculate_static_folds(physics_uv);
        
        // Calculate curtain thickness
        float thickness = calculate_curtain_thickness(uv, curtain_progress);
        
        // Apply fold displacement
        vec2 final_uv = physics_uv;
        final_uv.x += fold_data.x * thickness;
        
        // Surface normal for lighting
        vec3 surface_normal = vec3(fold_data.yz, sqrt(max(0.001, 1.0 - dot(fold_data.yz, fold_data.yz))));
        
        // Base color
        vec4 base_color = curtain_color;
        
        // If you have a texture:
        // base_color *= texture(TEXTURE, final_uv);
        
        // Apply lighting
        final_color = apply_lighting(base_color, surface_normal, final_uv, thickness);
        
        // Full Alpha - NO blur on any edge
        final_color.a = base_color.a;
    }
    
    COLOR = final_color;
}