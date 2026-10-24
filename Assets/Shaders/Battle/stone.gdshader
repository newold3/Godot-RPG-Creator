shader_type canvas_item;

/* Progress from 0.0 (normal) to 1.0 (fully stone) */
uniform float progress : hint_range(0.0, 1.0, 0.01) = 0.0;

/* Stone tint color */
uniform vec4 stone_color : source_color = vec4(0.45, 0.43, 0.48, 1.0);

float random(vec2 st) {
    return fract(sin(dot(st.xy, vec2(12.9898, 78.233))) * 43758.5453123);
}

void fragment() {
    vec4 tex_color = texture(TEXTURE, UV);
    
    // Escala de grises (luminancia)
    float luma = dot(tex_color.rgb, vec3(0.299, 0.587, 0.114));
    vec3 gray = vec3(luma);
    
    // Ruido fino para simular la textura rugosa de la piedra
    float grain = (random(UV * 300.0) - 0.5) * 0.15;
    
    // Mezclar el color original con el efecto de piedra
    vec3 stone_shaded = (gray * stone_color.rgb) + grain;
    
    vec3 final_rgb = mix(tex_color.rgb, stone_shaded, progress);
    
    COLOR = vec4(final_rgb, tex_color.a);
}