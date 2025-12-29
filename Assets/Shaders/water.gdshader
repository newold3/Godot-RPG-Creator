shader_type canvas_item;

uniform sampler2D noise_texture : filter_linear_mipmap, repeat_enable;
uniform sampler2D foam_noise_texture : filter_linear_mipmap, repeat_enable;
uniform sampler2D foam_gradient : filter_linear_mipmap, repeat_enable; // Nueva textura para el gradiente del foam
uniform vec4 water_color : source_color = vec4(0.0, 0.4, 0.8, 1.0);
uniform float noise_scale = 10.0;
uniform float noise_speed = 0.1;
uniform float noise_strength = 0.02;
uniform float wave_frequency = 2.0;
uniform float wave_amplitude = 0.005;
uniform float foam_threshold = 0.7;
uniform float foam_amount = 0.2;
uniform float foam_scale = 20.0;
uniform float foam_speed = 0.05;
uniform float foam_noise_scale = 15.0;
uniform float foam_noise_speed = 0.08;
uniform vec2 direction = vec2(1.0, 0.0);

float random(vec2 uv) {
    return fract(sin(dot(uv, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
    vec4 original_color = texture(TEXTURE, UV);
    float blue_factor = original_color.b;

    vec2 normalized_direction = normalize(direction);

    vec2 water_noise_uv = UV * noise_scale + TIME * noise_speed * normalized_direction;
    float water_noise = texture(noise_texture, water_noise_uv).r;
    float wave = sin(dot(UV, normalized_direction) * wave_frequency + TIME) * wave_amplitude;
    vec2 displacement = (normalized_direction * water_noise * 2.0 - 1.0 + vec2(0.0, wave)) * noise_strength;

    vec2 foam_loc_uv = UV * foam_scale + TIME * foam_speed * normalized_direction * 0.5;
    float foam_loc = texture(noise_texture, foam_loc_uv).r;

    vec2 foam_anim_uv = UV * foam_noise_scale + TIME * foam_noise_speed * normalized_direction;
    float foam_anim = texture(foam_noise_texture, foam_anim_uv).r;

    float foam_shape = mix(foam_loc, foam_anim, 0.5);

    float foam_random = texture(foam_noise_texture, UV).r + random(UV);

    float foam_intensity = smoothstep(foam_threshold, foam_threshold + foam_amount, foam_shape);
    foam_intensity *= foam_random * smoothstep(0.4, 0.6, foam_loc);
    //foam_intensity *= blue_factor;

    vec2 final_displacement = displacement * blue_factor;
    vec4 water_color_final = texture(TEXTURE, UV + final_displacement);

    // Usar la textura gradiente para el color del foam
    vec4 foam_color = texture(foam_gradient, vec2(foam_intensity, 0.5));

    vec4 final_color = mix(water_color_final, foam_color, foam_intensity);
    COLOR = mix(original_color, final_color, blue_factor);
}