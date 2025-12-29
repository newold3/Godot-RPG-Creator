shader_type canvas_item;
render_mode unshaded;
uniform sampler2D gradient_texture; // Gradient
uniform bool use_text_gradient = true; // Activate to make a gradient to text
uniform vec2 size; // Text Label Size
uniform bool use_pixelate_gradient = true; // Draw gradient pixelated or no.
uniform float pixel_scale : hint_range(1.0, 50.0) = 8.0; // Pixel scaling factor
instance uniform vec4 modulate : source_color = vec4(1.0);
instance uniform float mix_amount : hint_range(0.0, 1.0, 0.01) = 0.5;
uniform float brightness: hint_range(0.0, 1.0, 0.01) = 1.0;
varying vec2 iuv;

void vertex() {
    if (use_text_gradient)
        iuv = VERTEX.xy / size;
    else
        iuv = UV;
}

void fragment() {
    vec2 uv;
    if (use_pixelate_gradient) {
        // Create pixelated UV
        vec2 grid = floor(iuv * pixel_scale);
        vec2 pixel_center = (grid + 0.5) / pixel_scale;
        uv = pixel_center;
    }
    else{
        // Non Pixelated gradient
        uv = iuv;
    }

    vec4 color = texture(gradient_texture, uv) * COLOR;
	color.rgb *= brightness;
    COLOR = color;
}