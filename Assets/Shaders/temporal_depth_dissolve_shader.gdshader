shader_type canvas_item;

const int MAX_DEPTH_POINTS = 500;
uniform vec2 depth_points[MAX_DEPTH_POINTS];
uniform float start_times[MAX_DEPTH_POINTS];
uniform float fade_times[MAX_DEPTH_POINTS];

uniform float depth_radius = 0.025;
uniform float max_depth = 0.5;
uniform vec4 depth_color: source_color = vec4(0.056, 0.059, 0.078, 0.063);
uniform float shadow_intensity = 0.2;
uniform float shadow_radius = 1.5;
uniform float gaussian_blur_strength = 1.2;
uniform float current_time = 0.0;
uniform float appear_duration = 0.3;
uniform float disappear_duration = 0.5;
uniform float fade_smoothness = 2.0;
uniform sampler2D noise_texture;
uniform sampler2D heightmap_texture;
uniform float noise_intensity = 1.0;
uniform float contour_variation_intensity = -0.12;
uniform float initial_size = 0.6;
uniform float heightmap_intensity = 0.6;
uniform float radius_variation = 0.02;

// Debug
uniform bool debug_mode = false;
uniform vec4 debug_color: source_color = vec4(1.0, 0.0, 0.0, 0.5);

// Utilidades
float rand(float x) {
    return fract(sin(x * 12.9898) * 43758.5453);
}

vec2 random_offset(int i) {
    float angle = rand(float(i)) * 6.2831853; // 2π
    return vec2(cos(angle), sin(angle));
}

float get_noise_distortion(vec2 uv, vec2 center, int index) {
    vec2 offset = random_offset(index);
    vec2 noise_uv = (uv - center) * 10.0 + offset * 0.3;

    float noise1 = texture(noise_texture, noise_uv + vec2(current_time * 0.1)).r;
    float noise2 = texture(noise_texture, noise_uv * 2.0 - vec2(current_time * 0.15)).r;
    float noise3 = texture(noise_texture, noise_uv * 0.5 + vec2(current_time * 0.05)).r;

    float total = noise1 * 0.5 + noise2 * 0.3 + noise3 * 0.2;
    return clamp((total * noise_intensity - 1.0), -0.8, 0.8);
}

float contour_variation(vec2 uv, vec2 point_uv, float radius, int index) {
    vec2 dir = normalize(uv - point_uv + random_offset(index) * 0.1);
    vec2 offset_uv = point_uv + dir * radius * 0.4;
    float noise_value = texture(noise_texture, offset_uv * 4.5).r;

    return clamp(noise_value * contour_variation_intensity * radius, -radius * 0.6, radius * 0.6);
}

float gaussian_blur(float distance, float radius, float strength) {
    float x = distance / radius;
    return exp(-strength * x * x);
}

float smooth_fade(float x) {
    return 1.0 - pow(1.0 - x, fade_smoothness);
}

float calculate_depth(vec2 uv, vec2 point_uv, float animation_progress, float fade_factor, int index) {
    if (point_uv == vec2(0.0, 0.0)) return 0.0;

    float size_progress = initial_size + (1.0 - initial_size) * animation_progress;
    float base_radius = max(0.001, depth_radius * size_progress);

    float distortion = get_noise_distortion(uv, point_uv, index);
    float radius_variation_clamped = clamp(radius_variation, -0.2, 0.2);
    float current_radius = base_radius + distortion * radius_variation_clamped;
    current_radius = max(current_radius, 0.005);

    float base_distance = length(uv - point_uv);
    float contoured_distance = base_distance + contour_variation(uv, point_uv, current_radius, index);
    float heightmap_value = texture(heightmap_texture, uv).r;

    float depth = smoothstep(current_radius, current_radius * 0.5, contoured_distance);
    depth *= (1.0 + distortion * 0.3);
    depth *= smoothstep(current_radius * 1.2, 0.0, base_distance);
    depth *= (1.0 + (heightmap_value - 0.5) * heightmap_intensity);

    float blur = gaussian_blur(contoured_distance, current_radius, gaussian_blur_strength);
    float shadow = gaussian_blur(contoured_distance, current_radius * shadow_radius, shadow_intensity);
    depth *= blur;
    depth -= shadow * shadow_intensity;

    return clamp(depth * fade_factor, 0.0, 1.0);
}

float calculate_animation_progress(int point_index, out float fade_factor) {
    if (depth_points[point_index] == vec2(0.0, 0.0)) {
        fade_factor = 0.0;
        return 0.0;
    }

    float time_since_start = current_time - start_times[point_index];

    fade_factor = 1.0;
    if (fade_times[point_index] > 0.0) {
        float fade_time = current_time - fade_times[point_index];
        fade_factor = 1.0 - smooth_fade(clamp(fade_time / disappear_duration, 0.0, 1.0));
    }

    return clamp(time_since_start / appear_duration, 0.0, 1.0);
}

void fragment() {
    vec2 uv = fract(UV);
    float total_depth = 0.0;
    bool point_drawn = false;

    for (int i = 0; i < MAX_DEPTH_POINTS; i++) {
        if (depth_points[i] != vec2(0.0, 0.0)) {
            vec2 point_uv = depth_points[i] / vec2(1.0 / TEXTURE_PIXEL_SIZE);

            if (debug_mode && length(UV - point_uv) < 0.01) {
                total_depth = 0.0;
                point_drawn = true;
                break;
            }

            float fade_factor;
            float animation_progress = calculate_animation_progress(i, fade_factor);
            float depth = calculate_depth(UV, point_uv, animation_progress, fade_factor, i);

            if (depth > 0.001) {
                point_drawn = true;
            }

            total_depth += depth;
        }
    }

    total_depth = clamp(total_depth, 0.0, 1.0);
    vec4 original_color = texture(TEXTURE, UV);

    vec4 final_color = mix(original_color, depth_color, total_depth * max_depth);

    if (debug_mode && !point_drawn) {
        COLOR = vec4(debug_color.rgb, 0.3);
    } else {
        COLOR = final_color;
    }
}
