shader_type canvas_item;

uniform sampler2D noise_texture: repeat_enable;
uniform float speed = 1.0;
uniform vec2 direction = vec2(1.0, 0.0);
uniform float threshold = 0.5;
uniform float smoothing_factor = 0.1;
uniform float animation_speed = 1.0;
uniform float deformation_strength = 0.1;
uniform float deformation_frequency = 2.0;
uniform vec2 scale = vec2(1.0, 1.0);

void fragment() {
    // Compensate for the sprite's scale
    vec2 scaled_uv = UV / scale;
    
    vec2 moving_uv = scaled_uv + (direction * speed * (TIME * animation_speed));
    
    // Apply animated deformation to the UV coordinates
    vec2 deformed_uv = moving_uv + (vec2(
        texture(noise_texture, moving_uv * deformation_frequency).x,
        texture(noise_texture, (moving_uv + vec2(0.5)) * deformation_frequency).y
    ) * deformation_strength * sin(TIME * deformation_frequency * animation_speed));
    
    float noise = texture(noise_texture, deformed_uv).r;
    
    // Apply a smoothing function to the noise
    float smoothed_noise = smoothstep(threshold - smoothing_factor, threshold + smoothing_factor, noise);
    
    // Mix the original color with the color modified by the noise
    COLOR = mix(vec4(0.0), texture(TEXTURE, UV), smoothed_noise);
}