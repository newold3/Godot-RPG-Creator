shader_type canvas_item;

uniform vec4 shadow_color : source_color = vec4(0.0, 0.0, 0.0, 0.5);
uniform float blur_size : hint_range(0, 10) = 2.0;
uniform sampler2D mask_texture;

void fragment() {
    // Get current pixel color from shadow texture
    vec4 shadow = texture(TEXTURE, UV);
    
    // Get current pixel color from mask
    vec4 mask = texture(mask_texture, UV);
    
    // Initialize final color
    vec4 final_color = vec4(0.0);
    
    // Check conditions to draw shadow:
    // 1. Shadow pixel is not transparent (using red channel as alpha)
    // 2. Mask has alpha <= 0.4
    // 3. Mask has alpha > 0.4 and its red is less than shadow's red
    if (shadow.r > 0.0 && (mask.a <= 0.4 || (mask.a > 0.4 && mask.r < shadow.r))) {
        // Apply simple blur using average of neighbor pixels
        float total = 0.0;
        vec2 pixel_size = TEXTURE_PIXEL_SIZE * blur_size;
        
        for(float x = -2.0; x <= 2.0; x++) {
            for(float y = -2.0; y <= 2.0; y++) {
                vec2 offset = vec2(x, y) * pixel_size;
                vec4 shadow_sample = texture(TEXTURE, UV + offset);
                total += shadow_sample.r;
            }
        }
        
        // Normalize blur
        total /= 25.0; // 5x5 kernel
        
        // Apply shadow color with calculated intensity
        final_color = shadow_color;
        final_color *= total;
		final_color.a = shadow_color.a;
    }
    
    COLOR = final_color;
}