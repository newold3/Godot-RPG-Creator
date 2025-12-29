shader_type canvas_item;

uniform bool debug = false;
uniform float border_scale = 2.0;
uniform vec2 shadow_offset = vec2(-10.0, -10.0);
uniform vec4 color : source_color;
uniform float blur_amount : hint_range(0.0, 5.0) = 0.0;
uniform float shadow_scale = 1.5;
uniform bool disable_rotating = false;

// X-axis deformation and new elongation control
uniform vec2 deform_x = vec2(0.0, 0.0); // X-axis deformation (min, max)
uniform vec2 elongation = vec2(1.0, 1.0); // Shadow elongation (x, y)
uniform float deform_intensity : hint_range(0.0, 2.0) = 0.5; // Deformation strength

varying flat vec4 modulate;
varying flat float sprite_rotation;

void vertex() {
    float final_scale = max(border_scale, border_scale * shadow_scale);
    VERTEX.xy *= vec2(final_scale);
    modulate = COLOR;
    sprite_rotation = atan(MODEL_MATRIX[0][1], MODEL_MATRIX[0][0]);
}

vec2 rotate_point(vec2 point, float angle) {
    float s = sin(angle);
    float c = cos(angle);
    return vec2(
        point.x * c - point.y * s,
        point.x * s + point.y * c
    );
}

vec4 sample_texture_safe(sampler2D tex, vec2 uv) {
    return (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0)
        ? vec4(0.0)
        : texture(tex, uv);
}

vec4 apply_gaussian_blur(sampler2D tex, vec2 uv, vec2 pixel_size) {
    if (blur_amount <= 0.0) return sample_texture_safe(tex, uv);

    vec4 color_blur = vec4(0.0);
    float total_weight = 0.0;
    int kernel_size = int(blur_amount * 3.0);

    for (int x = -kernel_size; x <= kernel_size; x++) {
        for (int y = -kernel_size; y <= kernel_size; y++) {
            vec2 blur_offset = vec2(float(x), float(y)) * pixel_size;
            float weight = exp(-0.5 * (float(x * x + y * y)) / (blur_amount * blur_amount));
            color_blur += sample_texture_safe(tex, uv + blur_offset) * weight;
            total_weight += weight;
        }
    }

    return total_weight > 0.0 ? color_blur / total_weight : vec4(0.0);
}

// X-axis deformation function
vec2 apply_x_deformation(vec2 uv) {
    // X-deformation based on vertical position
    float x_deform = mix(deform_x.x, deform_x.y, uv.y) * deform_intensity;
    uv.x += x_deform * (uv.y - 0.5);
    return uv;
}

// Elongation function
vec2 apply_elongation(vec2 uv) {
    // Center the UV
    uv = (uv - 0.5) * elongation + 0.5;
    return uv;
}

float calculate_fade(float coord, float scale) {
    if (coord < 0.0) {
        return 1.0 + (coord / (scale - 1.0));
    } else if (coord > 1.0) {
        return 1.0 - ((coord - 1.0) / (scale - 1.0));
    }
    return 1.0;
}

vec4 process_texture(vec2 uv, sampler2D tex, bool is_main, vec2 pixel_size) {
    // Apply deformations only to shadow
    if (!is_main) {
        // First apply X-deformation
        uv = apply_x_deformation(uv);

        // Then apply elongation
        uv = apply_elongation(uv);
    }

    if (is_main) {
        return sample_texture_safe(tex, uv) * modulate;
    }

    vec4 blurred = apply_gaussian_blur(tex, uv, pixel_size);
    float fade_x = calculate_fade(uv.x, shadow_scale);
    float fade_y = calculate_fade(uv.y, shadow_scale);
    float fade = smoothstep(0.0, 1.0, min(fade_x, fade_y));

    return vec4(color.rgb, (blurred.a - (1.0 - color.a)) * modulate.a * fade);
}

void fragment() {
    float final_scale = max(border_scale, border_scale * shadow_scale);
    vec2 scaled_uv = UV * final_scale - (0.5 * (final_scale - 1.0));

    vec4 main_texture = process_texture(scaled_uv, TEXTURE, true, TEXTURE_PIXEL_SIZE);

    vec2 adjusted_offset = disable_rotating ? shadow_offset : rotate_point(shadow_offset, -sprite_rotation);
    vec2 shadow_uv = scaled_uv + adjusted_offset * TEXTURE_PIXEL_SIZE;

    vec4 shadow = process_texture(shadow_uv, TEXTURE, false, TEXTURE_PIXEL_SIZE);

    vec4 res = mix(shadow, main_texture, main_texture.a);
	vec4 debug_layer = vec4(1.0, 0.0, 0.0, 0.3);
	COLOR = mix(debug ? debug_layer : res, res, res.a);
}