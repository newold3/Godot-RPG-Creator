shader_type canvas_item;

// Texture used to define the energy colors (usually a GradientTexture1D).
uniform sampler2D energy_gradient : source_color;
// Procedural noise texture for the energy pattern.
uniform sampler2D noise_texture : repeat_enable;
// This color will modulate the final gradient result.
uniform vec4 modulate_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
// Individual scaling for the noise texture to avoid stretching.
uniform vec2 noise_scale = vec2(1.0, 1.0);
// Speed of the energy movement.
uniform vec2 speed = vec2(0.05, 0.1);
// Intensity of the glow effect.
uniform float intensity : hint_range(0.0, 10.0) = 2.0;
// Balance between the base texture and the energy effect.
uniform float energy_mix_factor : hint_range(0.0, 1.0) = 0.5;


void fragment() {
	vec4 base_tex = texture(TEXTURE, UV);
	
	// Create moving coordinates for the noise with scale adjustment
	vec2 animated_uv = (UV * noise_scale) + (TIME * speed);
	float noise_value = texture(noise_texture, animated_uv).r;
	
	// Sample the gradient and multiply by the modulation color
	vec4 gradient_sampled = texture(energy_gradient, vec2(noise_value, 0.0));
	vec4 energy_final = gradient_sampled * modulate_color * intensity;
	
	// Ensure the energy respects the original texture's transparency
	energy_final.a *= base_tex.a;
	
	// Blend the base texture with the modulated energy
	vec3 combined_rgb = mix(base_tex.rgb, energy_final.rgb, energy_mix_factor);
	
	COLOR = vec4(combined_rgb, base_tex.a);
	COLOR.a *= base_tex.a;
}