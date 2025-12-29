shader_type canvas_item;

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float target_progress : hint_range(0.0, 1.0) = 0.0;

uniform sampler2D bg_gradient : source_color;
uniform sampler2D fill_gradient : source_color;
uniform sampler2D preview_gradient : source_color;

uniform bool show_preview = true;
uniform bool animate_preview = true;
uniform float preview_pulse_speed : hint_range(0.0, 10.0) = 4.0;
uniform float preview_opacity : hint_range(0.0, 1.0) = 0.6;

uniform int fill_method : hint_enum("Left->Right", "Right->Left", "Center->Out", "Out->Center", "Top->Bottom", "Bottom->Top") = 0;
uniform float center_point : hint_range(0.0, 1.0) = 0.5; 

uniform float glow_intensity : hint_range(0.0, 2.0) = 0.5;
uniform float pulse_speed : hint_range(0.0, 10.0) = 3.0;
uniform bool enable_pulse = true;

uniform float fill_animation_speed : hint_range(0.0, 5.0) = 1.0;
uniform bool enable_fill_animation = false;

uniform float final_opacity: hint_range(0.0, 1.0, 0.01) = 1.0;

uniform bool enable_flare = true;
uniform sampler2D flare_texture : source_color;
uniform float flare_width : hint_range(0.0, 1.0) = 0.15;
uniform float flare_max_width : hint_range(0.0, 1.0) = 0.25;
uniform float flare_intensity : hint_range(0.0, 3.0) = 1.0;
uniform float flare_pulse_speed : hint_range(0.0, 10.0) = 2.0;
uniform float flare_width_speed : hint_range(0.0, 10.0) = 2.0;
uniform float flare_deform_speed : hint_range(0.0, 10.0) = 2.0;
uniform float flare_deform_amount : hint_range(0.0, 10.0) = 2.0;
uniform float flare_deform_freq : hint_range(0.0, 10.0) = 2.0;
uniform float flare_rotation_speed : hint_range(0.0, 10.0) = 1.0;
uniform vec3 flare_color : source_color = vec3(1.0, 1.0, 1.0);

uniform float global_animation_offset : hint_range(0.0, 10.0, 0.01) = 0.0;

vec4 draw_background(vec2 uv) {
    return texture(bg_gradient, uv);
}

bool is_pixel_filled(vec2 uv, float current_progress) {
    if (fill_method == 0) return uv.x <= current_progress;
    if (fill_method == 1) return uv.x >= (1.0 - current_progress);
    if (fill_method == 2) return abs(uv.x - center_point) <= current_progress * 0.5;
    if (fill_method == 3) return min(uv.x, 1.0 - uv.x) <= current_progress * 0.5;
    if (fill_method == 4) return uv.y <= current_progress;
    if (fill_method == 5) return uv.y >= (1.0 - current_progress);
    return uv.x <= current_progress;
}

vec2 get_flare_position(float current_progress) {
    if (fill_method == 0) return vec2(current_progress, 0.5);
    if (fill_method == 1) return vec2(1.0 - current_progress, 0.5);
    if (fill_method == 4) return vec2(0.5, current_progress);
    if (fill_method == 5) return vec2(0.5, 1.0 - current_progress);
    return vec2(current_progress, 0.5);
}

vec4 draw_fill(vec2 uv, float current_progress) {
    if (!is_pixel_filled(uv, current_progress)) return vec4(0.0);
    vec4 color = texture(fill_gradient, uv);
    if (enable_pulse) color.rgb *= 0.8 + 0.4 * sin(TIME * pulse_speed);
    color.rgb *= 1.0 + glow_intensity * (1.0 - abs(uv.y - 0.5) / 0.5);
    return color;
}

bool is_pixel_in_preview(vec2 uv, float current_progress, float final_target_progress) {
    return !is_pixel_filled(uv, current_progress) && is_pixel_filled(uv, final_target_progress);
}

vec4 draw_preview(vec2 uv, float current_progress, float final_target_progress) {
    if (!show_preview) return vec4(0.0);

    // determinar rango horizontal del preview
    float start = current_progress;
    float end = final_target_progress;

    // quick reject: fuera del rango preview
    if (uv.x < start || uv.x > end) return vec4(0.0);

    // remap uv.x del rango [start, end] a [0,1] para sampling
    float local_x = (uv.x - start) / max(end - start, 0.0001); // evitar división por 0
    vec2 sample_uv = vec2(local_x, uv.y);

    vec4 color = texture(preview_gradient, sample_uv);
    float alpha = preview_opacity;
    if (animate_preview) alpha *= 0.7 + 0.3 * sin((TIME + global_animation_offset) * preview_pulse_speed);
    color.a *= alpha;
    return color;
}


vec4 draw_flare(vec2 uv, float current_progress) {
    if (!enable_flare || current_progress <= 0.0) return vec4(0.0);

    // flare center in UV space (0..1)
    vec2 flare_pos = get_flare_position(current_progress);

    // sanitize widths
    float wmin = clamp(flare_width, 0.0001, 1.0);
    float wmax = clamp(flare_max_width, wmin, 1.0);

    // animate width between min and max
    float width_phase = 0.5 + 0.5 * sin((TIME + global_animation_offset) * max(flare_width_speed, 0.0001));
    float dynamic_width = mix(wmin, wmax, width_phase);

    // rectangle bounds in global UV space
    float halfw = dynamic_width * 0.5;
    float left = flare_pos.x - halfw;
    float right = flare_pos.x + halfw;

    // quick reject: outside horizontal rect -> no flare
    if (uv.x < left || uv.x > right) return vec4(0.0);

    // Map uv into local rectangle UV (x: 0..1 across dynamic_width, y: 0..1 full height)
    float safe_w = max(dynamic_width, 0.0001);
    vec2 local = vec2((uv.x - left) / safe_w, uv.y); // local.x ∈ [0,1], local.y ∈ [0,1]

    // Center around (0.5,0.5) for rotation/deform
    vec2 centered = local - vec2(0.5, 0.5);

    // Deformation: horizontal offset that varies along vertical (local.y)
    float deform = sin((local.y * flare_deform_freq + TIME * flare_deform_speed) * 6.28318);
    // weight deformation stronger near the center of the flare (fade to edges)
    float edge_falloff = 1.0 - smoothstep(0.0, 0.5, abs(centered.x));
    centered.x += deform * flare_deform_amount * edge_falloff;

    // Rotation around center of local rect
    float ang = (TIME + global_animation_offset) * flare_rotation_speed;
    mat2 rot = mat2(
        vec2(cos(ang), -sin(ang)),
        vec2(sin(ang),  cos(ang))
    );
    vec2 rotated = rot * centered;

    // back to local UV space
    vec2 sample_uv = rotated + vec2(0.5, 0.5);

    // ensure we only sample inside [0,1] to avoid artifacts (mask)
    float inside =
        step(0.0, sample_uv.x) * step(sample_uv.x, 1.0) *
        step(0.0, sample_uv.y) * step(sample_uv.y, 1.0);
    if (inside <= 0.0) return vec4(0.0);

    // sample texture and apply tint/pulse/intensity
    vec4 tex = texture(flare_texture, sample_uv);

    float pulse = 0.85 + 0.15 * sin((TIME + global_animation_offset) * flare_pulse_speed);
    vec3 tinted = tex.rgb * flare_color * flare_intensity * pulse;

    return vec4(tinted, tex.a * pulse) * inside;
}

void fragment() {
    vec2 uv = UV;
    float current_progress = enable_fill_animation 
        ? progress * (0.5 + 0.5 * sin((TIME + global_animation_offset) * fill_animation_speed)) 
        : progress;
    float safe_target_progress = max(target_progress, current_progress);

    vec4 color = draw_background(uv);
    vec4 preview = draw_preview(uv, current_progress, safe_target_progress);
    color = mix(color, preview, preview.a);
    vec4 fill = draw_fill(uv, current_progress);
    color = mix(color, fill, fill.a);

    vec4 flare = draw_flare(uv, current_progress);
    color.rgb += flare.rgb * flare.a;
    color.a = max(color.a, flare.a);

    color.a *= final_opacity;
    COLOR = color;
}
