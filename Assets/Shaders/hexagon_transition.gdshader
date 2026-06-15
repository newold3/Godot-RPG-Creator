shader_type canvas_item;

/* Texture of the screen */
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;

/* Transition progress from 0.0 to 1.0 */
uniform float progress : hint_range(0.0, 1.0) = 0.0;

/* Number of hexagons across the screen width */
uniform float hex_scale = 20.0;

/* Screen aspect ratio */
uniform float aspect_ratio = 1.777777;

/* Radius of the hexagon */
uniform float hex_radius : hint_range(0.1, 1.0) = 0.5;

/* Border thickness relative to the hexagon */
uniform float border_thickness : hint_range(0.0, 0.5) = 0.08;

/* Color of the border */
uniform vec4 border_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

/* Initial scale of the hexagons when appearing */
uniform float start_scale = 2.0;

/* Final scale of the hexagons when disappearing */
uniform float target_scale = 2.0;

/* Duration of the appear animation phase */
uniform float phase_appear_duration = 0.2;

/* Duration of the resting phase */
uniform float phase_rest_duration = 0.3;

/* Duration of the disappear animation phase */
uniform float phase_disappear_duration = 0.5;



float hash(vec2 p) {
    return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}



void fragment() {
    vec4 final_color = vec4(0.0, 0.0, 0.0, progress);
    
    vec2 p = UV * vec2(aspect_ratio, 1.0) * hex_scale;
    
    float grid_radius = 0.5;
    
    float q = (p.x * 0.5773502 - p.y * 0.3333333) / grid_radius;
    float r_hex = p.y * 0.6666667 / grid_radius;
    float s = -q - r_hex;
    
    float rq = round(q);
    float rr = round(r_hex);
    float rs = round(s);
    
    float q_diff = abs(rq - q);
    float r_diff = abs(rr - r_hex);
    float s_diff = abs(rs - s);
    
    if (q_diff > r_diff && q_diff > s_diff) {
        rq = -rr - rs;
    } else if (r_diff > s_diff) {
        rr = -rq - rs;
    }
    
    float total_phase_time = phase_appear_duration + phase_rest_duration + phase_disappear_duration;
    float n_appear = phase_appear_duration / total_phase_time;
    float n_rest = phase_rest_duration / total_phase_time;
    float n_disappear = phase_disappear_duration / total_phase_time;
    
    float end_appear = n_appear;
    float end_rest = n_appear + n_rest;
    
    float p1 = 0.0;
    if (n_appear > 0.0) {
        p1 = clamp(progress / end_appear, 0.0, 1.0);
    }
    
    float p3 = 0.0;
    if (n_disappear > 0.0) {
        p3 = clamp((progress - end_rest) / n_disappear, 0.0, 1.0);
    }
    
    float aa_width = 1.0 / hex_scale;
    
    for (int dq = -2; dq <= 2; dq++) {
        for (int dr = -2; dr <= 2; dr++) {
            if (abs(dq + dr) > 2) {
                continue;
            }
            
            float nq = rq + float(dq);
            float nr = rr + float(dr);
            
            vec2 center = vec2(grid_radius * 1.7320508 * (nq + nr * 0.5), grid_radius * 1.5 * nr);
            
            float h = hash(vec2(nq, nr));
            
            float appear = clamp((p1 - h * 0.8) / 0.2, 0.0, 1.0);
            float fly = clamp((p3 - h * 0.8) / 0.2, 0.0, 1.0);
            
            float current_alpha = appear * (1.0 - fly);
            if (current_alpha <= 0.0) {
                continue;
            }
            
            float current_scale = mix(start_scale, 1.0, appear) * mix(1.0, target_scale, fly);
            if (current_scale <= 0.001) {
                continue;
            }
            
            vec2 local_p = (p - center) / current_scale;
            
            float d = max(abs(local_p.x), abs(local_p.x) * 0.5 + abs(local_p.y) * 0.8660254);
            float b_dist = d / hex_radius;
            
            if (b_dist < 1.0 + aa_width) {
                float edge_aa = smoothstep(1.0 + aa_width, 1.0 - aa_width, b_dist);
                float border_aa = smoothstep(1.0 - border_thickness + aa_width, 1.0 - border_thickness - aa_width, b_dist);
                
                vec2 center_uv = center / hex_scale;
                center_uv.x /= aspect_ratio;
                vec2 local_uv = local_p / hex_scale;
                local_uv.x /= aspect_ratio;
                
                vec4 tex_color = texture(screen_texture, center_uv + local_uv);
                vec4 hex_color = mix(border_color, tex_color, border_aa);
                
                hex_color.a *= edge_aa * current_alpha;
                
                float out_a = hex_color.a + final_color.a * (1.0 - hex_color.a);
                if (out_a > 0.0) {
                    vec3 out_rgb = (hex_color.rgb * hex_color.a + final_color.rgb * final_color.a * (1.0 - hex_color.a)) / out_a;
                    final_color = vec4(out_rgb, out_a);
                }
            }
        }
    }
    
    COLOR = final_color;
}