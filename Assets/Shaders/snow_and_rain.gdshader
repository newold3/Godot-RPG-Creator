// Rain and Snow shader by Brian Smith (steampunkdemon.itch.io)
// MIT licence

shader_type canvas_item;

uniform float rain_amount = 200.0;
uniform float near_rain_length : hint_range(0.01, 1.0) = 0.2;
uniform float far_rain_length : hint_range(0.01, 1.0) = 0.1;
uniform float near_rain_width : hint_range(0.1, 1.0) = 1.0;
uniform float far_rain_width : hint_range(0.1, 1.0) = 0.5;
uniform float near_rain_transparency : hint_range(0.1, 1.0) = 1.0;
uniform float far_rain_transparency : hint_range(0.1, 1.0) = 0.5;
uniform vec4 rain_color : source_color = vec4(0.8, 0.8, 0.8, 1.0);
uniform float base_rain_speed : hint_range(0.1, 1.0) = 0.5;
uniform float additional_rain_speed : hint_range(0.1, 1.0) = 0.5;
uniform float time_scale : hint_range(0.1, 50.0) = 0.6;
uniform bool snow_mode = false;

// Nuevo uniform para controlar la dirección de la lluvia
uniform vec2 rain_direction = vec2(0.2, -1.0); // Controla la inclinación y caída de la lluvia

uniform vec2 scale = vec2(1.0, 1.0);

void fragment() {
    float time = 10000.0 + TIME * time_scale;

    // Ajuste de las coordenadas UV según la escala del sprite
    vec2 uv = UV / scale;

    // Ajuste de la dirección de la lluvia con rain_direction
    float remainder = mod(uv.x - uv.y * rain_direction.x, 1.0 / rain_amount);
    uv.x = (uv.x - uv.y * rain_direction.x) - remainder;

    float rn = fract(sin(uv.x * rain_amount));
    uv.y = fract(uv.y + rn);

    // Modifica la velocidad de caída en función de rain_direction.y
    float adjusted_time = time * (base_rain_speed + additional_rain_speed * rn) * rain_direction.y;

    if (!snow_mode) {
        // Blurred trail for rain:
        COLOR = mix(COLOR, rain_color, smoothstep(
            1.0 - (far_rain_length + (near_rain_length - far_rain_length) * rn),
            1.0,
            fract(uv.y - adjusted_time)
        ) * (far_rain_transparency + (near_rain_transparency - far_rain_transparency) * rn)
          * step(remainder * rain_amount, far_rain_width + (near_rain_width - far_rain_width) * rn));
    } else {
        // No trail for snow:
        COLOR = mix(COLOR, rain_color, step(
            1.0 - (far_rain_length + (near_rain_length - far_rain_length) * rn),
            fract(uv.y - adjusted_time)
        ) * (far_rain_transparency + (near_rain_transparency - far_rain_transparency) * rn)
          * step(remainder * rain_amount, far_rain_width + (near_rain_width - far_rain_width) * rn));
    }
}
