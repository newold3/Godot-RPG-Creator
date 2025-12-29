shader_type canvas_item;

uniform float global_progress : hint_range(0.0, 1.0) = 1.0;
uniform vec4 cover_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float edge_softness : hint_range(0.001, 0.1) = 0.073;
uniform float flicker_intensity : hint_range(0.0, 0.5) = 0.045;
uniform float flicker_speed : hint_range(0.1, 10.0) = 1.721;
uniform float circle_irregularity : hint_range(0.0, 1.0) = 0.02;

// Light points array (maximum 16 lights for performance)
uniform int num_lights : hint_range(0, 16) = 1;
uniform vec2 light_positions[16];
uniform float light_radii[16];
uniform float light_intensities[16]; // 0.0 = no light, 1.0 = full light

// Alternative: single light for backwards compatibility
uniform vec2 hole_position = vec2(0.5, 0.5);
uniform float hole_radius : hint_range(0.0, 1.0) = 0.2;

float calculate_light_contribution(vec2 uv, vec2 light_pos, float radius, float intensity, float aspect_ratio) {
    // Calculate position relative to light center with aspect ratio correction
    vec2 pos_diff = uv - light_pos;

    // Apply aspect ratio correction
    if (aspect_ratio > 1.0) {
        pos_diff.y *= aspect_ratio;
    } else {
        pos_diff.x /= aspect_ratio;
    }

    // Add irregularity distortion
    float angle = atan(pos_diff.y, pos_diff.x);
    float distortion = sin(angle * 5.0 + TIME * 2.0) * circle_irregularity * 0.1;
    float distance = length(pos_diff) + distortion;

    // Add flicker effect
    float flicker = sin(TIME * flicker_speed + light_pos.x * 10.0 + light_pos.y * 7.0) * flicker_intensity;
    float current_radius = radius * global_progress + (flicker * radius * global_progress);

    // Calculate light contribution
    if (current_radius <= 0.0) return 1.0; // No light, full darkness

    float light_factor = smoothstep(
        current_radius + edge_softness,
        current_radius - edge_softness,
        distance
    );

    return 1.0 - (light_factor * intensity);
}

void fragment() {
    vec2 uv = UV;

    // Get screen resolution for proper aspect ratio calculation
    vec2 resolution = 1.0 / SCREEN_PIXEL_SIZE;
    float aspect_ratio = resolution.x / resolution.y;

    float total_darkness = 1.0;

    // Process multiple light points
    if (num_lights > 0) {
        for (int i = 0; i < num_lights && i < 16; i++) {
            if (light_intensities[i] > 0.0) {
                float light_contribution = calculate_light_contribution(
                    uv,
                    light_positions[i],
                    light_radii[i],
                    light_intensities[i],
                    aspect_ratio
                );
                total_darkness *= light_contribution;
            }
        }
    } else {
        // Backwards compatibility: use single hole
        float light_contribution = calculate_light_contribution(
            uv,
            hole_position,
            hole_radius,
            1.0,
            aspect_ratio
        );
        total_darkness = light_contribution;
    }

    // Clamp to avoid artifacts
    total_darkness = clamp(total_darkness, 0.0, 1.0);

    // Apply final color
    COLOR = vec4(cover_color.rgb, cover_color.a * total_darkness);
}