shader_type canvas_item;

uniform float progress : hint_range(0, 1);
uniform float intensity = 0.1;
uniform int copies = 5;
uniform float start_angle = 0.0;

void fragment() {
    vec2 uv = UV;
    vec4 final_color = vec4(0.0);

    for (int i = 0; i < copies; i++) {
        // Calculate angle uniformly, adding start angle
        float angle = start_angle + (float(i) / float(copies)) * 6.28318530718; // 2pi radians distributed uniformly
        vec2 dir = vec2(cos(angle), sin(angle));

        // Calculate displacement proportional to progress
        vec2 offset = dir * intensity * progress;

        // Sample texture with displacement
        vec4 tex = texture(TEXTURE, uv + offset);

        // Additive mix
        final_color += tex;
    }

    // Normalize resulting color
    final_color /= float(copies);

    COLOR = final_color;
}
