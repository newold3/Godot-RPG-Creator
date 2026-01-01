shader_type canvas_item;

uniform vec2 canvas_size = vec2(1.0, 1.0);
uniform vec2 trail_positions[16]; // Trail positions
uniform float trail_intensities[16]; // Trail intensities
uniform int trail_count = 0; // Number of active trails
uniform float trail_radius = 0.1; // Radius of each trail
uniform float metaball_smoothness = 2.0; // Merge smoothness
uniform sampler2D hole_texture : hint_default_white, repeat_enable; // Hole texture
uniform vec4 hole_color : source_color = vec4(1.0, 1.0, 1.0, 1.0); // Texture color

float metaball_function(vec2 pixel_pos, vec2 ball_pos, float radius, float intensity) {
    float dist = distance(pixel_pos, ball_pos);
    // Metaball function: decays rapidly with distance
    return intensity * pow(max(0.0, 1.0 - dist / radius), metaball_smoothness);
}

void fragment() {
    // Calculate trail effect
    float total_trail_effect = 0.0;

    // Sum effects of all trails
    for (int i = 0; i < trail_count; i++) {
        // Calculate metaball effect for this trail
        float ball_effect = metaball_function(
            UV,
            trail_positions[i],
            trail_radius,
            trail_intensities[i]
        );
        // Cumulative sum of effects
        total_trail_effect += ball_effect;
    }

    // Limit total effect
    total_trail_effect = clamp(total_trail_effect, 0.0, 1.0);

    // Sample hole texture
    vec4 texture_sample = texture(hole_texture, UV);

    // Combine texture color with uniform color
    vec3 final_color = texture_sample.rgb * hole_color.rgb;

    // Set final color with alpha based on trail effect
    COLOR = vec4(final_color, texture_sample.a * total_trail_effect);
}