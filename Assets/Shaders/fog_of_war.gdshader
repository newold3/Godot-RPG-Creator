shader_type canvas_item;

uniform vec4 fog_points[800]; // Máximo número de puntos
uniform int active_fog_points; // Número actual de puntos activos
uniform sampler2D hole_texture; // Textura del agujero
uniform vec2 scale; // Escala inversa para compensar la transformación

void fragment() {
    // Coordenadas del fragmento en el espacio del shader
    vec2 frag_pos = FRAGCOORD.xy * scale;

    // Color inicial del fragmento (la niebla negra por defecto)
    vec4 final_color = vec4(0.0, 0.0, 0.0, 1.0);

    // Obtener el tamaño de la textura del agujero
    vec2 hole_texture_size = vec2(textureSize(hole_texture, 0));

    // Iterar por los puntos activos
    for (int i = 0; i < active_fog_points; i++) {
        vec4 point = fog_points[i];
        
        // Extraer las coordenadas y animación
        float time = point.x;
        float mode = point.y; // 0: desaparecer, 1: aparecer
        vec2 position = point.zw;

        // Evaluar la opacidad del agujero basado en el tiempo
        float alpha = clamp(mode == 1.0 ? time : 1.0 - time, 0.0, 1.0);

        // Calcular las dimensiones del agujero en el espacio del shader
        vec2 adjusted_hole_size = hole_texture_size * scale * alpha;

        // Coordenadas UV relativas a la textura del agujero
        vec2 uv = (frag_pos - position) / adjusted_hole_size + 0.5;

        // Verificar si el fragmento está dentro de la textura del agujero
        if (uv.x >= 0.0 && uv.x <= 1.0 && uv.y >= 0.0 && uv.y <= 1.0) {
            vec4 hole_tex = texture(hole_texture, uv);

            // Mezclar la textura del agujero con el color base
            if (hole_tex.a > 0.0) {
                final_color = mix(final_color, vec4(0.0, 0.0, 0.0, 0.0), hole_tex.a * alpha);
            }
        }
    }

    COLOR = final_color;
}
