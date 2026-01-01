shader_type canvas_item;
render_mode blend_premul_alpha;

uniform sampler2D fish_atlas;
uniform vec2 screen_size;
uniform int fish_count = 100;

uniform int atlas_columns = 4;
uniform int atlas_rows = 4;

uniform float min_speed = 20.0;
uniform float max_speed = 80.0;
uniform float base_wiggle = 1.0;

// New parameter to control compensation
uniform float wiggle_compensation_factor = 1.0; // Default value 1.0 (adjustable from editor)

uniform float min_lifespan = 6.0;
uniform float max_lifespan = 20.0;

uniform float fade_in_time = 1.0;
uniform float fade_out_time = 1.0;

uniform float fish_scale_min = 0.1;
uniform float fish_scale_max = 6.0; // Max scale of 6 as you mentioned

uniform vec4 fish_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

uniform vec2 global_scale = vec2(1.0);

float rand(float n) {
    return fract(sin(n) * 43758.5453);
}

vec2 get_sprite_uv(vec2 local_uv, int index) {
    float cols = float(atlas_columns);
    float rows = float(atlas_rows);
    float col = float(index % atlas_columns);
    float row = float(index / atlas_columns);
    vec2 tile_size = vec2(1.0 / cols, 1.0 / rows);

    vec2 tex_size = vec2(textureSize(fish_atlas, 0));
    vec2 inset = vec2(0.5) / tex_size;
    vec2 clamped_uv = clamp(local_uv, inset, vec2(1.0) - inset);

    return clamped_uv * tile_size + vec2(col, row) * tile_size;
}

void fragment() {
    vec2 tex_size = vec2(textureSize(fish_atlas, 0));
    vec2 scaled_screen_size = screen_size / global_scale;
    vec2 frame_size = tex_size / vec2(float(atlas_columns), float(atlas_rows));

    vec2 pixel_uv = UV * screen_size / global_scale;
    vec4 final_color = vec4(0.0);

    for (int i = 0; i < fish_count; i++) {
        float id = float(i);

        float lifespan = mix(min_lifespan, max_lifespan, rand(id * 9.7));
        float total_life = fade_in_time + lifespan + fade_out_time;
        float offset = rand(id * 10.1) * total_life;
        float local_time = TIME + offset;

        if (local_time < 0.0) continue;

        float cycle_num = floor(local_time / total_life);
        float t_in_cycle = mod(local_time, total_life);

        float fade = 1.0;
        if (t_in_cycle < fade_in_time) {
            fade = smoothstep(0.0, 1.0, t_in_cycle / fade_in_time);
        } else if (t_in_cycle > fade_in_time + lifespan) {
            float fade_out_pos = (t_in_cycle - (fade_in_time + lifespan)) / fade_out_time;
            fade = 1.0 - smoothstep(0.0, 1.0, fade_out_pos);
        }

        float angle = rand(id * 1.1) * 6.2831;
        vec2 dir = vec2(cos(angle), sin(angle));
        float speed = mix(min_speed, max_speed, rand(id * 2.1));
        float scale = mix(fish_scale_min, fish_scale_max, rand(id * 3.3));
        vec2 start_pos = vec2(rand(id * 4.4), rand(id * 5.5)) * scaled_screen_size;

        vec2 fish_pos_raw = start_pos + dir * speed * local_time;
        vec2 fish_pos = mod(fish_pos_raw, scaled_screen_size);

        // IMPROVED WIGGLE COMPENSATION
        // Calculate compensation based on scale and control factor
        float normalized_scale = scale / fish_scale_max; // Normalize scale (0-1)
        float compensation_curve = pow(normalized_scale, 2.5); // More aggressive curve for large scales
        float wiggle_compensation = 1.0 / (1.0 + compensation_curve * wiggle_compensation_factor * 3.0);
        float compensated_wiggle = base_wiggle * wiggle_compensation;

        for (int dx = -1; dx <= 1; dx++) {
            for (int dy = -1; dy <= 1; dy++) {
                vec2 wrapped_pos = fish_pos + vec2(float(dx), float(dy)) * scaled_screen_size;
                vec2 rel_pos = pixel_uv - wrapped_pos;

                float ca = cos(-angle);
                float sa = sin(-angle);
                vec2 rotated = vec2(
                    rel_pos.x * ca - rel_pos.y * sa,
                    rel_pos.x * sa + rel_pos.y * ca
                );

                vec2 fish_uv = rotated / (frame_size * scale);

                if (any(greaterThan(abs(fish_uv), vec2(0.5)))) continue;

                vec2 sprite_uv = fish_uv + vec2(0.5);

                // Apply compensated wiggle
                float amp = compensated_wiggle * mix(10.0, 15.0, rand(id * 5.1)) * min(scale, 3.0); // Limit scale influence
                float freq = mix(4.0, 8.0, rand(id * 6.6));
                float wave_speed = mix(1.0, 3.0, rand(id * 7.7));
                float wave = sin(sprite_uv.x * freq + local_time * wave_speed) * (amp / frame_size.y);
                sprite_uv.y += wave;

                int sprite_index = int(floor(rand(id * 8.8) * float(atlas_columns * atlas_rows)));
                vec2 atlas_uv = get_sprite_uv(sprite_uv, sprite_index);
                vec4 tex_color = texture(fish_atlas, atlas_uv);

                if (tex_color.a < 0.01) continue;

                vec4 modulated = fish_color;
                modulated.a *= tex_color.a * fade;

                final_color = mix(final_color, modulated, modulated.a);
            }
        }
    }

    COLOR = final_color;
}