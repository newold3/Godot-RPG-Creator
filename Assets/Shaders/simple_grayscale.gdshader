shader_type canvas_item;

uniform bool grayscale = false;
uniform float brightness : hint_range(-1.0, 1.0) = 0.0;
uniform float opacity : hint_range(0.0, 1.0, 0.01) = 1.0;

void fragment() {
    vec4 color = texture(TEXTURE, UV);

    if (grayscale) {
        // Método luminancia estándar para grayscale
        float gray = dot(color.rgb, vec3(0.299, 0.587, 0.114));
        // Aplicar ajuste de brillo al grayscale
        gray = clamp(gray + brightness, 0.0, 1.0);
        COLOR = vec4(gray, gray, gray, color.a);
    } else {
        COLOR = color;
    }

	COLOR.a = COLOR.a * opacity;
}