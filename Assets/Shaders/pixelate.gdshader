shader_type canvas_item;

uniform float pixel_size : hint_range(1.0, 100.0) = 4.0;

uniform sampler2D SCREEN_TEXTURE: hint_screen_texture;

void fragment() {
    vec2 screen_size = 1.0 / SCREEN_PIXEL_SIZE;

    // Calculamos el tamaño del pixel en coordenadas UV
    vec2 pixel_uv = pixel_size / screen_size;

    // Dividimos las coordenadas UV por el tamaño del pixel y redondeamos
    vec2 pixelated_uv = floor(SCREEN_UV / pixel_uv) * pixel_uv;

    // Añadimos la mitad del tamaño del pixel para centrar
    pixelated_uv += pixel_uv * 0.5;

    // Obtenemos el color de la textura pixelada
    COLOR = texture(SCREEN_TEXTURE, pixelated_uv);
}