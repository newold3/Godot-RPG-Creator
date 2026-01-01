shader_type canvas_item;

uniform sampler2D image1;
uniform sampler2D image2;
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float displacement_strength : hint_range(0.0, 0.5) = 0.008;
uniform vec2 rect_size = vec2(600.0, 600.0);

// Easing function
float easeInOutCubic(float t) {
    return t < 0.5 ? 4.0 * t * t * t : 1.0 - pow(-2.0 * t + 2.0, 3.0) / 2.0;
}

void fragment() {
    vec2 uv = UV;
    // Actual texture sizes
    vec2 size1 = vec2(textureSize(image1, 0));
    vec2 size2 = vec2(textureSize(image2, 0));
    vec2 current_size = mix(size1, size2, progress);
    
    // ColorRect size
	
    // Horizontally centered position, anchored bottom
    vec2 offset = vec2(
        (rect_size.x - current_size.x) / 2.0,
        rect_size.y - current_size.y
    );
    
    // Current pixel in ColorRect
    vec2 pixel = uv * rect_size;
    
    // Pixel relative to image
    vec2 local_pixel = pixel - offset;
    
    // If outside image, discard
    if (local_pixel.x < 0.0 || local_pixel.x >= current_size.x ||
        local_pixel.y < 0.0 || local_pixel.y >= current_size.y) {
        discard;
    }
    
    // Convert to texture UV (0-1)
    vec2 tex_uv = local_pixel / current_size;
    
    // Easing
    float eased = easeInOutCubic(progress);
    
    // Displacement
    vec4 disp = texture(image2, tex_uv);
    vec2 disp_dir = (disp.rg * 2.0 - 1.0) * displacement_strength * sin(eased * 3.14159);
    
    // Sample with textureLod (lod 0 = no mipmap interpolation)
    vec4 col1 = textureLod(image1, tex_uv + disp_dir, 0.0);
    vec4 col2 = textureLod(image2, tex_uv, 0.0);
    
    COLOR = mix(col1, col2, eased);
}