shader_type canvas_item;

uniform vec4 shadow_color : source_color = vec4(0.0, 0.0, 0.0, 0.5);
uniform float blur_size : hint_range(0, 10) = 2.0;
uniform sampler2D mask_texture;

void fragment() {
    // Obtener el color del pixel actual en la textura de sombra
    vec4 shadow = texture(TEXTURE, UV);
    
    // Obtener el color del pixel actual en la máscara
    vec4 mask = texture(mask_texture, UV);
    
    // Inicializar el color final
    vec4 final_color = vec4(0.0);
    
    // Verificar las condiciones para dibujar la sombra:
    // 1. El pixel de sombra no es transparente (usamos el canal rojo como alpha)
    // 2. La máscara tiene alpha <= 0.4
    // 3. La máscara tiene alpha > 0.4 y su rojo es menor que el rojo de la sombra
    if (shadow.r > 0.0 && (mask.a <= 0.4 || (mask.a > 0.4 && mask.r < shadow.r))) {
        // Aplicar blur simple usando un promedio de píxeles vecinos
        float total = 0.0;
        vec2 pixel_size = TEXTURE_PIXEL_SIZE * blur_size;
        
        for(float x = -2.0; x <= 2.0; x++) {
            for(float y = -2.0; y <= 2.0; y++) {
                vec2 offset = vec2(x, y) * pixel_size;
                vec4 shadow_sample = texture(TEXTURE, UV + offset);
                total += shadow_sample.r;
            }
        }
        
        // Normalizar el blur
        total /= 25.0; // 5x5 kernel
        
        // Aplicar el color de la sombra con la intensidad calculada
        final_color = shadow_color;
        final_color *= total;
		final_color.a = shadow_color.a;
    }
    
    COLOR = final_color;
}