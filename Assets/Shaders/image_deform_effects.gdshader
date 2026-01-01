shader_type canvas_item;

// Curvature type
uniform int curve_type : hint_enum("None", "Arc", "Arc Down", "Arc Up", "Wave", "Bridge Down", "Bridge Up") = 0;

// Deformation parameters
uniform float bend : hint_range(-100.0, 100.0) = 0.0; // Photoshop-style curvature
uniform float horizontal_distortion : hint_range(-100.0, 100.0) = 0.0; // Horizontal stretch/compression
uniform float vertical_distortion : hint_range(-100.0, 100.0) = 0.0; // Vertical stretch/compression

// Spherize
uniform float spherize_amount : hint_range(-1.0, 1.0) = 0.0;

// Effect center (normalized 0.0 to 1.0)
uniform vec2 center = vec2(0.5, 0.5);

void fragment() {
    vec2 uv = UV;
    vec2 offset = vec2(0.0);

    float normalized_bend = bend / 100.0;
    float normalized_h_dist = horizontal_distortion / 100.0;
    float normalized_v_dist = vertical_distortion / 100.0;

    // Displacements
    float dx = uv.x - center.x;
    float dy = uv.y - center.y;

    if (curve_type != 0) {
        if (curve_type == 1) { // Arc
            offset.y = normalized_bend * (dx * dx) * 2.5; // Stronger than others
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

    // Horizontal/vertical distortion
    offset.x += normalized_h_dist * dx * abs(dx);
    offset.y += normalized_v_dist * dy * abs(dy);

    // Spherize
    if (spherize_amount != 0.0) {
        float r = distance(uv, center);
        if (r > 0.0) {
            float spherize_strength = spherize_amount * (1.0 - r * r);
            vec2 dir = normalize(uv - center);
            offset += dir * r * spherize_strength;
        }
    }

    vec2 final_uv = uv + offset;

    // Sample final texture
    vec4 color = texture(TEXTURE, final_uv);

    // If UV is outside, set transparency
    if (final_uv.x < 0.0 || final_uv.x > 1.0 || final_uv.y < 0.0 || final_uv.y > 1.0) {
        COLOR = vec4(0.0, 0.0, 0.0, 0.0);
    } else {
        COLOR = color;
    }
}
