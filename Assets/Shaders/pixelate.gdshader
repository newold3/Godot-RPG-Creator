shader_type canvas_item;

uniform float pixel_size : hint_range(1.0, 100.0) = 4.0;

uniform sampler2D SCREEN_TEXTURE: hint_screen_texture;

void fragment() {
    vec2 screen_size = 1.0 / SCREEN_PIXEL_SIZE;

    // Calculate pixel size in UV coordinates
    vec2 pixel_uv = pixel_size / screen_size;

    // Divide UV coordinates by pixel size and round
    vec2 pixelated_uv = floor(SCREEN_UV / pixel_uv) * pixel_uv;

    // Add half pixel size to center
    pixelated_uv += pixel_uv * 0.5;

    // Get pixelated texture color
    COLOR = texture(SCREEN_TEXTURE, pixelated_uv);
}