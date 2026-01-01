shader_type canvas_item;

// Uniforms for texture and animation
uniform sampler2D particle_texture : hint_default_black;
uniform ivec2 sprite_frames = ivec2(1, 1);
uniform float animation_speed : hint_range(0.1, 10.0) = 1.0;

// Uniforms for particle configuration
uniform int particle_type : hint_enum("Dust", "Embers", "Sparkles", "Smoke", "Coins") = 0;
uniform int particle_count : hint_range(50, 1000) = 150;
uniform float particle_speed : hint_range(0.1, 5.0, 0.001) = 1.0;
uniform float particle_size : hint_range(0.01, 5.0, 0.001) = 2.0;
uniform float min_size_scale : hint_range(0.01, 2.0, 0.01) = 0.5;
uniform float max_size_scale : hint_range(0.01, 5.0, 0.01) = 3.0;

// New uniforms for depth layers
uniform int depth_layers : hint_range(2, 5) = 3;
uniform float depth_size_multiplier : hint_range(0.1, 1.0) = 0.3;
uniform float depth_speed_multiplier : hint_range(0.1, 1.0) = 0.6;
uniform float depth_alpha_multiplier : hint_range(0.1, 1.0) = 0.7;
uniform float layer_separation : hint_range(0.1, 2.0) = 0.8;

// Uniforms for colors
uniform vec4 primary_color : source_color = vec4(1.0, 0.84, 0.0, 1.0); // Gold
uniform vec4 secondary_color : source_color = vec4(1.0, 0.55, 0.2, 1.0); // Orange
uniform vec4 tertiary_color : source_color = vec4(1.0, 1.0, 1.0, 1.0); // White

// Uniforms for behavior
uniform float time_scale : hint_range(0.1, 5.0) = 1.0;
uniform vec2 wind_direction = vec2(0.0, 0.0);
uniform float wind_strength : hint_range(0.0, 2.0) = 0.5;

// Improved pseudo-random noise function
float random(vec2 st) {
    return fract(sin(dot(st.xy, vec2(12.9898, 78.233))) * 43758.5453123);
}

// Hash function for better distribution
float hash(float n) {
    return fract(sin(n) * 43758.5453123);
}

// Function to get correct sprite frame
vec2 get_sprite_uv(vec2 local_uv, int frame_index) {
    int total_frames = sprite_frames.x * sprite_frames.y;
    if (total_frames <= 1) {
        return local_uv; // If no frames, use full UV
    }

    frame_index = frame_index % total_frames;

    int frame_x = frame_index % sprite_frames.x;
    int frame_y = frame_index / sprite_frames.x;

    vec2 frame_size = vec2(1.0) / vec2(sprite_frames);
    vec2 frame_offset = vec2(float(frame_x), float(frame_y)) * frame_size;

    return frame_offset + local_uv * frame_size;
}

// Function to calculate layer properties
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

    // Closer layers (lower index) are larger
    // Further layers (higher index) are smaller
    props.size_scale = 1.0 + layer_factor * 2.0; // Layer 0: 1.0, last layer: 3.0
    props.speed_scale = 1.0 - layer_factor * (1.0 - depth_speed_multiplier);
    props.alpha_scale = 1.0 - layer_factor * (1.0 - depth_alpha_multiplier);
    props.time_offset = layer_factor * layer_separation;

    // Fewer particles in closer layers, more in further layers
    float particle_distribution = 1.0 + layer_factor * 1.5; // Layer 0: 1.0, last: 2.5
    props.particle_count = int(float(particle_count) * particle_distribution / float(depth_layers * 2));

    return props;
}

// Function to calculate particle position with layers and oscillatory movement
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

    // Configure base velocity according to particle type
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

    // Add oscillatory movement
    float oscillation_freq_x = 0.5 + random(seed + vec2(4.0, 0.0)) * 1.0; // Frequency 0.5-1.5
    float oscillation_freq_y = 0.3 + random(seed + vec2(5.0, 0.0)) * 0.8; // Frequency 0.3-1.1
    float oscillation_amp_x = 0.02 + random(seed + vec2(6.0, 0.0)) * 0.08; // Amplitude 0.02-0.1
    float oscillation_amp_y = 0.015 + random(seed + vec2(7.0, 0.0)) * 0.06; // Amplitude 0.015-0.075

    vec2 oscillation = vec2(
        sin(adjusted_time * oscillation_freq_x + fid) * oscillation_amp_x,
        cos(adjusted_time * oscillation_freq_y + fid * 1.3) * oscillation_amp_y
    );

    // Apply wind with layer scale
    vec2 wind_effect = wind_direction * wind_strength * 0.05 * layer_props.speed_scale;

    // Calculate final position with base movement + oscillation
    vec2 pos = start_pos + (base_velocity + wind_effect) * life_time + oscillation;

    // Horizontal wraparound
    pos.x = mod(pos.x + 1.0, 1.0);

    return pos;
}

// Function to calculate particle alpha with layers
float calculate_particle_alpha(int particle_id, int layer_index, float time, vec2 pos) {
    LayerProperties layer_props = get_layer_properties(layer_index);

    float fid = float(particle_id);
    vec2 seed = vec2(fid * 0.1234 + float(layer_index) * 0.987, fid * 0.5678 + float(layer_index) * 0.432);

    float speed_multiplier = particle_speed * time_scale * layer_props.speed_scale;
    float life_duration = 8.0 + random(seed) * 4.0;
    float adjusted_time = time + layer_props.time_offset;
    float life_time = mod(adjusted_time * speed_multiplier + fid * 0.1, life_duration);
    float life_progress = life_time / life_duration;

    // Smooth fade in/out
    float alpha = 1.0;
    if (life_progress < 0.2) {
        alpha = smoothstep(0.0, 0.2, life_progress);
    } else if (life_progress > 0.7) {
        alpha = smoothstep(1.0, 0.7, life_progress);
    }

    // Check if on screen
    if (pos.x < -0.05 || pos.x > 1.05 || pos.y < -0.05 || pos.y > 1.05) {
        alpha = 0.0;
    }

    // Apply layer alpha scale
    alpha *= layer_props.alpha_scale;

    return alpha * (0.4 + random(seed) * 0.4);
}

// Function to get particle color with variation by layer
vec4 get_particle_color(int type, int particle_id, int layer_index, float time) {
    float fid = float(particle_id);
    vec2 seed = vec2(fid * 0.1234 + float(layer_index) * 0.987, fid * 0.5678 + float(layer_index) * 0.432);
    float variation = random(seed);

    // Further layers have slightly more desaturated colors
    float layer_factor = float(layer_index) / float(depth_layers - 1);
    float desaturation = layer_factor * 0.3; // Max 30% desaturation

    vec4 base_color;

    if (type == 0) { // Dust - Gold
        base_color = mix(primary_color, secondary_color, variation * 0.3);
    } else if (type == 1) { // Embers - Orange/Red
        vec4 ember_color = vec4(1.0, 0.2, 0.0, secondary_color.a);
        base_color = mix(secondary_color, ember_color, variation * 0.5);
    } else if (type == 2) { // Sparkles - White/Gold
        base_color = mix(tertiary_color, primary_color, variation * 0.4);
    } else if (type == 3) { // Smoke - Gray
        vec4 smoke_base = vec4(0.8, 0.8, 0.8, 0.6);
        base_color = smoke_base * (0.5 + variation * 0.5);
    } else if (type == 4) { // Coins - Gold
        base_color = primary_color;
    } else {
        base_color = primary_color;
    }

    // Apply desaturation for further layers
    float luminance = dot(base_color.rgb, vec3(0.299, 0.587, 0.114));
    base_color.rgb = mix(base_color.rgb, vec3(luminance), desaturation);

    return base_color;
}

void fragment() {
    vec2 uv = UV;
    vec4 final_color = vec4(0.0);
    float time = TIME * time_scale;

    // Process each layer from furthest to nearest
    for (int layer = depth_layers - 1; layer >= 0; layer--) {
        LayerProperties layer_props = get_layer_properties(layer);

        // Process particles for this layer (each layer has different amount)
        for (int i = 0; i < layer_props.particle_count; i++) {
            int particle_id = layer * 1000 + i; // Use large offset to avoid collisions

            vec2 particle_pos = calculate_particle_position(particle_id, layer, time);

            // Calculate distance from current UV to particle position
            vec2 diff = uv - particle_pos;
            float distance = length(diff);

            // Particle size with clear differentiation by layers
            float fid = float(particle_id);
            float size_variation = min_size_scale + random(vec2(fid * 0.1234, fid * 0.5678)) * (max_size_scale - min_size_scale);

            // Apply layer scaling: closer layers larger, further smaller
            float base_size = particle_size * 0.015 * size_variation;
            float size = base_size;

            // Apply inverted layer factor so layer 0 is larger
            float layer_factor = float(layer) / float(depth_layers - 1);
            if (layer == 0) {
                size *= 2.5; // Closest layer: very large
            } else if (layer == 1 && depth_layers > 2) {
                size *= 1.8; // Second layer: large
            } else if (layer == depth_layers - 1) {
                size *= 0.3; // Furthest layer: very small
            } else {
                size *= (1.5 - layer_factor * 0.8); // Intermediate layers: gradual scaling
            }

            if (distance < size) {
                // Calculate local UV for particle
                vec2 local_uv = (diff / size) * 0.5 + 0.5;

                // Ensure local_uv is in range [0,1]
                if (local_uv.x >= 0.0 && local_uv.x <= 1.0 &&
                    local_uv.y >= 0.0 && local_uv.y <= 1.0) {

                    // Calculate animation frame correctly
                    float frame_time = time * animation_speed + fid * 0.1;
                    int total_frames = sprite_frames.x * sprite_frames.y;
                    int frame_index = 0;

                    if (total_frames > 1) {
                        frame_index = int(floor(frame_time)) % total_frames;
                    }

                    vec2 sprite_uv = get_sprite_uv(local_uv, frame_index);

                    // Get texture color
                    vec4 tex_color = texture(particle_texture, sprite_uv);

                    // Only process if texture has alpha
                    if (tex_color.a > 0.01) {
                        // Get particle color with variation by layer
                        vec4 particle_color = get_particle_color(particle_type, particle_id, layer, time);

                        // Apply particle color respecting its transparency
                        tex_color.rgb *= particle_color.rgb;
                        tex_color.a *= particle_color.a;

                        // Calculate additional alpha
                        float additional_alpha = calculate_particle_alpha(particle_id, layer, time, particle_pos);

                        // Apply smooth circular falloff
                        float falloff = 1.0 - smoothstep(0.7, 1.0, distance / size);
                        additional_alpha *= falloff;

                        // Apply additional alpha
                        tex_color.a *= additional_alpha;

                        // Combine with final color using alpha blending
                        // Further layers blend more subtly
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