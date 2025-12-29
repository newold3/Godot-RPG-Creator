shader_type canvas_item;

uniform float progress : hint_range(0.0, 1.0);
uniform float radius : hint_range(0.0, 1.0) = 0.5;
uniform float angle : hint_range(-25.0, 25.0) = 12.0;
uniform vec2 center = vec2(0.5, 0.5);
uniform vec4 target_color : source_color = vec4(1.0, 0.0, 0.0, 1.0);
uniform float scale : hint_range(0.5, 2.0) = 1.0; // Factor de escala para la textura

void fragment() {
    vec2 toCenter = UV - center;
    float dist = length(toCenter);
    float percent = (radius - dist) / radius;
    
    vec4 tex_color;
    
    if (dist <= radius) {
        float theta = percent * percent * angle * progress;
        float s = sin(theta);
        float c = cos(theta);
        
        vec2 rotatedUV = center + vec2(
            toCenter.x * c - toCenter.y * s,
            toCenter.x * s + toCenter.y * c
        );
        
        // Aplicar la escala a las coordenadas UV de la textura
        vec2 scaledUV = center + (rotatedUV - center) / scale;
        
        tex_color = texture(TEXTURE, scaledUV);
    } else {
        tex_color = texture(TEXTURE, (UV - center) / scale + center);
    }
    
    // Interpolación entre el color original y el color objetivo
    COLOR = mix(tex_color, target_color, progress);
}
