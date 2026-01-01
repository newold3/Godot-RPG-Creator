shader_type canvas_item;

// Texture with fish silhouettes organized in rows and columns
uniform sampler2D fish_sprites;
uniform sampler2D noise_texture;

// Spritesheet configuration
uniform int sprite_columns : hint_range(1, 8) = 4;
uniform int sprite_rows : hint_range(1, 4) = 3;

// Animation parameters
uniform float time_scale : hint_range(0.1, 3.0) = 1.0;
uniform int fish_count : hint_range(3, 20) = 10;
uniform float base_speed : hint_range(0.02, 0.2) = 0.05;
uniform float wave_amplitude : hint_range(0.01, 0.15) = 0.03;
uniform float wave_frequency : hint_range(0.5, 4.0) = 2.0;
uniform float noise_intensity : hint_range(0.0, 0.1) = 0.03;
uniform float swim_sway : hint_range(0.0, 0.5) = 0.1;

// Vertex deformation parameters
uniform float body_wave_amplitude : hint_range(0.0, 0.3) = 0.05;
uniform float body_wave_frequency : hint_range(1.0, 8.0) = 4.0;
uniform float tail_wave_amplitude : hint_range(0.0, 0.5) = 0.15;
uniform float tail_wave_frequency : hint_range(2.0, 12.0) = 6.0;
uniform float body_stretch : hint_range(0.0, 0.2) = 0.02;

// Colors and effects
uniform vec4 fish_color : source_color = vec4(0.0, 0.0, 0.0, 0.9);
uniform vec4 background_color : source_color = vec4(0.2, 0.6, 1.0, 1.0);
uniform float fish_scale : hint_range(0.3, 2.0) = 0.8;

// Opacity variation parameters
uniform float opacity_variation : hint_range(0.0, 0.8) = 0.4;
uniform float darkening_variation : hint_range(0.0, 0.6) = 0.3;

uniform vec2 uv_scale = vec2(1.0);

// Hash function to generate pseudo-random values
float hash(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

// Hash function for 2D vectors
vec2 hash2(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.xx + p3.yz) * p3.zy);
}

// Hash function for multiple random values
vec4 hash4(vec2 p) {
    vec4 p4 = fract(vec4(p.xyxy) * vec4(0.1031, 0.1030, 0.0973, 0.1099));
    p4 += dot(p4, p4.wzxy + 33.33);
    return fract((p4.xxyz + p4.yzzw) * p4.zywx);
}

// Function to get a specific sprite from the spritesheet
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

// Function to rotate UV
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

// Function to deform fish UV simulating swimming movement
vec2 deform_fish_uv(vec2 local_uv, float time, float fish_phase, float speed_variation) {
    // Center UV in range [-0.5, 0.5] for deformations
    vec2 centered_uv = local_uv - 0.5;

    // Normalized X coordinate (-1 to 1, where -1 is head and 1 is tail)
    float x_normalized = centered_uv.x * 2.0;

    // Body deformation - undulation propagating from head to tail
    float body_wave_phase = time * body_wave_frequency * speed_variation + fish_phase;
    float body_wave = sin(body_wave_phase + x_normalized * 3.14159) * body_wave_amplitude;

    // Deformation intensity increases towards tail
    float tail_intensity = smoothstep(-0.3, 1.0, x_normalized);
    body_wave *= tail_intensity;

    // Tail deformation - more pronounced movement
    float tail_wave_phase = time * tail_wave_frequency * speed_variation + fish_phase;
    float tail_wave = sin(tail_wave_phase + x_normalized * 1.5) * tail_wave_amplitude;

    // Only apply tail deformation at the back of the fish
    float tail_mask = smoothstep(0.2, 1.0, x_normalized);
    tail_wave *= tail_mask;

    // Body stretch during swimming
    float stretch_phase = time * body_wave_frequency * 0.5 * speed_variation + fish_phase;
    float stretch_factor = 1.0 + sin(stretch_phase) * body_stretch * tail_intensity;

    // Apply deformations
    vec2 deformed_uv = centered_uv;

    // Apply vertical undulation
    deformed_uv.y += body_wave + tail_wave;

    // Apply horizontal stretch
    deformed_uv.x *= stretch_factor;

    // Additional deformation to simulate body bending
    float body_bend_phase = time * body_wave_frequency * 0.3 * speed_variation + fish_phase;
    float body_bend = sin(body_bend_phase) * 0.02;
    deformed_uv.x += body_bend * x_normalized * tail_intensity;

    // Return to [0, 1] range
    return deformed_uv + 0.5;
}

void fragment() {
    vec2 uv = UV / uv_scale;
    float time = TIME * time_scale;

    vec4 final_color = background_color;

    // Draw multiple fish
    for (int i = 0; i < fish_count; i++) {
        float fish_id = float(i);
        vec2 fish_seed = vec2(fish_id * 0.137 + 12.345, fish_id * 0.419 + 67.891);

        // Generate ALL random values using different seeds
        vec4 random_values_1 = hash4(fish_seed);
        vec4 random_values_2 = hash4(fish_seed + vec2(100.0, 200.0));
        vec4 random_values_3 = hash4(fish_seed + vec2(300.0, 400.0));
        vec4 random_values_4 = hash4(fish_seed + vec2(500.0, 600.0));

        // Generate CONSTANT direction for each fish
        vec2 direction = normalize(random_values_1.xy * 2.0 - 1.0);

        // Unique properties for each fish using random values
        float speed_variation = 0.5 + random_values_1.z * 1.5;
        float size_variation = 0.6 + random_values_1.w * 0.8;
        float phase_offset = random_values_2.x * 6.28318;
        int sprite_index = int(random_values_2.y * float(sprite_columns * sprite_rows));

        // Opacity and color variations
        float opacity_factor = 1.0 - (random_values_2.z * opacity_variation);
        float darkening_factor = 1.0 - (random_values_2.w * darkening_variation);

        // Unique phase for deformation of each fish
        float deform_phase = random_values_3.x * 6.28318;

        // Random start point
        vec2 start_pos = random_values_3.yz * vec2(1.4, 1.2) - vec2(0.2, 0.1);

        // CONSTANT linear movement in fixed direction
        vec2 base_movement = direction * time * base_speed * speed_variation;

        // Apply texture noise for organic movement
        vec2 noise_coord = (start_pos + base_movement) * 2.0 + time * 0.1;
        float noise_sample = texture(noise_texture, noise_coord * 0.1).r;
        vec2 noise_offset = vec2(
            sin(noise_sample * 6.28318 + time),
            cos(noise_sample * 6.28318 + time * 1.3)
        ) * noise_intensity * random_values_3.w; // Individual noise variation

        // Additional undulation based on sine and cosine
        float wave_phase = time * wave_frequency * speed_variation + phase_offset;
        vec2 wave_offset = vec2(
            sin(wave_phase) * wave_amplitude,
            cos(wave_phase * 0.7) * wave_amplitude
        ) * random_values_4.x; // Individual undulation variation

        // Final position
        vec2 fish_center = start_pos + base_movement + noise_offset + wave_offset;

        // Wrapping
        fish_center = mod(fish_center + vec2(0.3, 0.2), vec2(1.6, 1.4)) - vec2(0.3, 0.2);

        // ROTATION CORRECTION: Sprites face right (0 deg)
        // Calculate angle based on movement direction
        float base_angle = atan(direction.y, direction.x);

        // Add sway to simulate swimming movement
        float sway_frequency = wave_frequency + random_values_4.y * 2.0; // Individual sway frequency
        float sway_angle = sin(time * sway_frequency * 2.0 + phase_offset) * swim_sway * random_values_4.z;

        // Total rotation
        float total_rotation = base_angle + sway_angle;

        // Fish size with individual variation
        float individual_scale = 0.7 + random_values_4.w * 0.6; // Individual additional scale
        float fish_size = fish_scale * size_variation * individual_scale * 0.08;

        // Process only visible fish
        if (fish_center.x > -0.2 && fish_center.x < 1.2 &&
            fish_center.y > -0.2 && fish_center.y < 1.2) {

            // Calculate local UV for the fish
            vec2 local_uv = (uv - fish_center) / fish_size;

            // Apply rotation to align with movement direction
            local_uv = rotate_uv(local_uv, vec2(0.0), -total_rotation); // Note the negative sign

            // Center on the sprite
            local_uv = local_uv * 0.5 + 0.5;

            // APPLY VERTEX DEFORMATION with individual speed variation
            vec2 deformed_uv = deform_fish_uv(local_uv, time, deform_phase, speed_variation);

            // Check if inside sprite area
            if (deformed_uv.x >= -0.1 && deformed_uv.x <= 1.1 &&
                deformed_uv.y >= -0.1 && deformed_uv.y <= 1.1) {

                // Clamp UV to avoid out of range sampling
                vec2 clamped_uv = clamp(deformed_uv, vec2(0.0), vec2(1.0));
                vec4 sprite_sample = get_sprite(clamped_uv, sprite_index);

                // Use ONLY sprite alpha
                float fish_mask = sprite_sample.a;

                // Smooth alpha at edges to avoid artifacts
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

                // Fade in/out at screen edges
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

                // Apply individual color and opacity variations
                vec3 individual_color = fish_color.rgb * darkening_factor;
                float individual_alpha = fish_color.a * opacity_factor * fish_mask;

                vec4 final_fish_color = vec4(individual_color, individual_alpha);

                // Mix with background
                final_color = mix(final_color, final_fish_color, final_fish_color.a);
            }
        }
    }

    COLOR = final_color;
}