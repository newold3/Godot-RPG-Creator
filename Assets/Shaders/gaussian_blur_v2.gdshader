// Shader: position_blur.shader
shader_type canvas_item;
uniform float radius = 5.0;

void fragment() {
    vec4 total = vec4(0.0);
    float weight = 0.0;

    for (float x = -radius; x <= radius; x++) {
        for (float y = -radius; y <= radius; y++) {
            vec2 offset = vec2(x, y) * TEXTURE_PIXEL_SIZE;
            vec4 sample_col = texture(TEXTURE, UV + offset);
            float sample_weight = 1.0 / (length(offset) + 0.0001);
            total += sample_col * sample_weight;
            weight += sample_weight;
        }
    }

    COLOR = total / weight;
}