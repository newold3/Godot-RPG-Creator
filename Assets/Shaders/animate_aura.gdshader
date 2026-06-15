shader_type canvas_item;

/* Distance in pixels to expand the drawing area. */
uniform float expansion_margin : hint_range(0.0, 150.0) = 50.0;

/* Vertical offset for the aura center relative to the sprite. */
uniform float vertical_offset = 0.0;

/* IMPORTANT! Packed texture. RED channel main noise. GREEN channel secondary noise. */
uniform sampler2D packed_noise_texture : repeat_enable, filter_linear_mipmap;

/* Gradient defining the outer aura look. */
uniform sampler2D aura_gradient : source_color, filter_linear;

/* Toggle to use the gradient in grayscale before tinting. */
uniform bool use_grayscale_gradient = true;

/* Main color to tint the gradient and inner aura. */
uniform vec4 aura_modulate : source_color = vec4(1.0, 0.5, 0.1, 1.0);

/* Strength of character heat deformation. */
uniform float distortion_strength : hint_range(0.0, 0.1) = 0.02;

/* Speed multiplier for distortion. */
uniform float distortion_speed_mult : hint_range(0.1, 2.0) = 0.5;

/* Defines from what height the distortion starts 0.0 feet 1.0 head. */
uniform float distortion_vertical_start : hint_range(0.0, 1.0) = 0.0;

/* Base speed of main noise flow R channel. */
uniform vec2 noise_speed = vec2(0.0, -2.0);

/* Scale of the main noise R channel. */
uniform float noise_scale : hint_range(0.1, 5.0) = 1.0;

/* Speed of the secondary noise G channel. */
uniform vec2 secondary_noise_speed = vec2(0.5, -1.5);

/* Scale of the secondary noise G channel. */
uniform float secondary_noise_scale : hint_range(0.1, 5.0) = 2.0;

/* Blending weight of the secondary noise. */
uniform float secondary_noise_weight : hint_range(0.0, 1.0) = 0.5;

/* Frequency of the internal UV swirl. */
uniform float swirl_frequency : hint_range(0.0, 20.0) = 3.0;

/* Amplitude of the internal UV swirl. */
uniform float swirl_amplitude : hint_range(0.0, 0.2) = 0.03;

/* Frequency of the edge boundary wobble. */
uniform float edge_wobble_frequency : hint_range(0.0, 20.0) = 6.0;

/* Speed of the edge boundary wobble. */
uniform float edge_wobble_speed : hint_range(0.0, 10.0) = 4.0;

/* Amplitude of the edge boundary wobble. */
uniform float edge_wobble_amplitude : hint_range(0.0, 0.2) = 0.04;

/* Density of the outer aura. */
uniform float aura_density : hint_range(0.0, 2.0) = 1.0;

/* Horizontal span of the aura. */
uniform float aura_span_x : hint_range(0.1, 2.0) = 0.8;

/* Vertical span of the aura. */
uniform float aura_span_y : hint_range(0.1, 2.0) = 0.8;

/* Amount to pinch the aura at the top. */
uniform float aura_taper : hint_range(0.0, 5.0) = 1.0;

/* Smoothness of the aura edges. */
uniform float aura_edge_softness : hint_range(0.01, 1.0) = 0.2;

/* Noise offset for the inner aura. */
uniform vec2 inner_noise_offset = vec2(0.5, 0.5);

/* Speed multiplier for the inner aura. */
uniform float inner_speed_mult : hint_range(0.1, 5.0) = 1.5;

/* Opacity of the inner energy. */
uniform float inner_aura_intensity : hint_range(0.0, 2.0) = 1.0;

/* Toggle to draw only the aura and hide the original sprite. */
uniform bool aura_only = false;

varying vec2 uv_scaling;



void vertex() {
	vec2 texture_size = 1.0 / TEXTURE_PIXEL_SIZE;
	vec2 expansion_ratio = (expansion_margin * 2.0) / texture_size;
	
	VERTEX.x += (UV.x - 0.5) * (expansion_margin * 2.0);
	VERTEX.y += (UV.y - 0.5) * (expansion_margin * 2.0);
	
	uv_scaling = 1.0 + expansion_ratio;
}



void fragment() {
	vec2 corrected_uv = (UV - 0.5) * uv_scaling + 0.5;
	vec4 main_texture = vec4(0.0);
	
	if (corrected_uv.x >= 0.01 && corrected_uv.x <= 0.99 && corrected_uv.y >= 0.01 && corrected_uv.y <= 0.99) {
		vec2 distortion_uv = corrected_uv * noise_scale + (TIME * noise_speed * distortion_speed_mult);
		vec2 distortion_noise_raw = texture(packed_noise_texture, distortion_uv).rr;
		vec2 distortion_offset = (distortion_noise_raw - 0.5) * distortion_strength;
		
		float start_y_inverted = 1.0 - distortion_vertical_start;
		float vertical_distortion_mask = smoothstep(start_y_inverted + 0.05, start_y_inverted - 0.05, corrected_uv.y);
		
		vec2 final_distorted_uv = clamp(corrected_uv + (distortion_offset * vertical_distortion_mask), 0.01, 0.99);
		main_texture = texture(TEXTURE, final_distorted_uv);
	}
	
	vec2 center = vec2(0.5, 0.5 + vertical_offset);
	
	vec2 swirl_offset = vec2(
		sin(corrected_uv.y * swirl_frequency + TIME * 2.0),
		cos(corrected_uv.x * swirl_frequency + TIME * 2.0)
	) * swirl_amplitude;
	
	vec2 noise_uv_main = corrected_uv * noise_scale + (TIME * noise_speed) + swirl_offset;
	float noise_value_main = texture(packed_noise_texture, noise_uv_main).r;
	
	vec2 noise_uv_sec = corrected_uv * secondary_noise_scale + (TIME * secondary_noise_speed) - swirl_offset;
	float noise_value_sec = texture(packed_noise_texture, noise_uv_sec).g;
	
	float noise_value = noise_value_main * mix(1.0, noise_value_sec * 2.0, secondary_noise_weight);
	noise_value = pow(clamp(noise_value, 0.0, 1.0), 2.0);
	
	vec2 centered_uv = corrected_uv - center;
	
	float taper_mask = smoothstep(0.0, -0.5, centered_uv.y);
	float current_taper = 1.0 + (taper_mask * aura_taper);
	centered_uv.x *= current_taper;
	
	float angle = atan(centered_uv.y, centered_uv.x);
	float safe_wobble_freq = round(edge_wobble_frequency);
	float boundary_wobble = sin(angle * safe_wobble_freq + TIME * edge_wobble_speed) * edge_wobble_amplitude;
	
	vec2 span_scale = vec2(aura_span_x, aura_span_y);
	float dist_from_center = length(centered_uv / span_scale) + boundary_wobble;
	float base_mask = 1.0 - smoothstep(0.1, 1.0, dist_from_center);
	
	float final_mask_value = clamp(base_mask - noise_value * (2.0 - aura_density), 0.0, 1.0);
	
	vec4 raw_outer_aura = texture(aura_gradient, vec2(final_mask_value, 0.0));
	vec4 outer_aura;
	
	if (use_grayscale_gradient) {
		float luminance = dot(raw_outer_aura.rgb, vec3(0.299, 0.587, 0.114));
		outer_aura = vec4(vec3(luminance) * aura_modulate.rgb, raw_outer_aura.a * aura_modulate.a);
	} else {
		outer_aura = raw_outer_aura * aura_modulate;
	}
	
	outer_aura.a *= smoothstep(0.0, aura_edge_softness, final_mask_value);
	
	vec2 inner_noise_uv = (corrected_uv * noise_scale) + swirl_offset + (TIME * noise_speed * inner_speed_mult) + inner_noise_offset;
	float inner_noise_value = texture(packed_noise_texture, inner_noise_uv).r;
	
	float inner_mask = main_texture.a * inner_noise_value * inner_aura_intensity;
	vec4 inner_aura = aura_modulate * inner_mask;
	
	vec3 blended_character = mix(main_texture.rgb, inner_aura.rgb, inner_mask * 0.7); 
	vec4 character_with_inner = vec4(blended_character, main_texture.a);
	
	float edge_blend = smoothstep(0.0, 0.5, main_texture.a) * smoothstep(1.0, 0.5, main_texture.a);
	vec4 edge_glow = outer_aura * edge_blend;
	character_with_inner.rgb += edge_glow.rgb * edge_glow.a;
	
	if (aura_only) {
		vec4 final_aura_only = outer_aura;
		final_aura_only.a *= (1.0 - main_texture.a);
		final_aura_only.rgb = mix(final_aura_only.rgb, inner_aura.rgb, inner_mask);
		final_aura_only.a = clamp(final_aura_only.a + inner_mask, 0.0, 1.0);
		COLOR = final_aura_only;
	} else {
		COLOR = mix(outer_aura, character_with_inner, character_with_inner.a);
	}
}