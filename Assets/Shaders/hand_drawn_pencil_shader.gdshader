shader_type canvas_item;

uniform vec4 pencil_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);

uniform float pencil_strength : hint_range(0.0, 2.0) = 1.0;
uniform float shade_levels : hint_range(0.0, 16.0) = 6.0;
uniform float noise_scale = 400.0;
/* Blend ratio between original color and shader effect */
uniform float mix_amount : hint_range(0.0, 1.0) = 1.0;


float rand(vec2 p) {
    return fract(sin(dot(p, vec2(12.9898,78.233))) * 43758.5453);
}


void fragment() {
    vec2 uv = UV;

    vec4 tex = texture(TEXTURE, uv);

    float gray = dot(tex.rgb, vec3(0.299, 0.587, 0.114));

    // Posterización
    gray = floor(gray * shade_levels) / shade_levels;

    // Ruido tipo papel
    float noise = rand(floor(uv * noise_scale));
    gray += (noise - 0.5) * 0.15 * pencil_strength;

    // Trazos diagonales
    float hatch1 = sin((uv.x + uv.y) * 800.0) * 0.5 + 0.5;
    float hatch2 = sin((uv.x - uv.y) * 600.0) * 0.5 + 0.5;

    float hatch = mix(hatch1, hatch2, 0.5);

    float pencil = mix(gray, gray * hatch, pencil_strength);
    pencil = clamp(pencil, 0.0, 1.0);

    // Aplicar color del lápiz
    vec3 final_color = mix(vec3(1.0), pencil_color.rgb, 1.0 - pencil);
    final_color = mix(tex.rgb, final_color, mix_amount);

    COLOR = vec4(final_color, COLOR.a);
}