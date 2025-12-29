shader_type canvas_item;
render_mode blend_premul_alpha;

uniform vec4 color : source_color;
uniform float timescale = 0.2;
uniform sampler2D noise_texture1;
uniform sampler2D noise_texture2;
uniform sampler2D noise_texture3;
uniform sampler2D hole_texture;
uniform float noise_weight1 = 0.5;
uniform float noise_weight2 = 0.3;
uniform float noise_weight3 = 0.2;
uniform float noiseScale = 1.0;
uniform vec2 scrollDirection1 = vec2(1.0, 0.5);
uniform vec2 scrollDirection2 = vec2(-0.7, 0.3);
uniform vec2 scrollDirection3 = vec2(0.3, -0.8);
uniform vec2 holeScrollDirection = vec2(0.2, -0.2);
uniform float density_threshold : hint_range(0.0, 1.0, 0.01) = 0.5;
uniform float edge_softness : hint_range(0.0, 0.5, 0.01) = 0.1;

uniform vec2 scale = vec2(1.0);


void fragment() {
    vec2 global_uv = UV / scale;

    // Aplicamos el escalado a las coordenadas globales
    vec2 scaled_uv = global_uv * noiseScale;

    // Obtenemos las coordenadas UV para cada textura con desplazamiento
    vec2 uv1 = scaled_uv - TIME * timescale * scrollDirection1;
    vec2 uv2 = scaled_uv - TIME * timescale * scrollDirection2;
    vec2 uv3 = scaled_uv - TIME * timescale * scrollDirection3;
    vec2 hole_uv = scaled_uv - TIME * timescale * holeScrollDirection;

    // Usamos fract para asegurar que las UVs se repitan correctamente (wrapping)
    uv1 = fract(uv1);
    uv2 = fract(uv2);
    uv3 = fract(uv3);
    hole_uv = fract(hole_uv);

    // Muestreamos las texturas de ruido
    float noise1 = texture(noise_texture1, uv1).r;
    float noise2 = texture(noise_texture2, uv2).r;
    float noise3 = texture(noise_texture3, uv3).r;
    float hole_value = texture(hole_texture, hole_uv).r;

    // Combinamos los ruidos con sus pesos
    float density = (noise1 * noise_weight1 +
                    noise2 * noise_weight2 +
                    noise3 * noise_weight3) / (noise_weight1 + noise_weight2 + noise_weight3);

    // Modificamos la densidad con la textura de huecos
    density *= hole_value;

    // Aplicamos el umbral con suavizado
    float alpha;
    if (density < density_threshold - edge_softness) {
        alpha = 0.0;
    } else if (density > density_threshold + edge_softness) {
        alpha = density;
    } else {
        float t = (density - (density_threshold - edge_softness)) / (2.0 * edge_softness);
        alpha = smoothstep(0.0, 1.0, t) * density;
    }

    vec3 final_color = color.rgb;
    COLOR = vec4(final_color, alpha);
}