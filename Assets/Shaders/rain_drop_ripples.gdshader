shader_type canvas_item;
render_mode blend_mul; // Try 'blend_mix' if it darkens too much

#define iResolution 1.0 / SCREEN_PIXEL_SIZE
#define iTime TIME
#define MAX_RADIUS 2
#define DOUBLE_HASH 0
#define HASHSCALE1 .1031
#define HASHSCALE3 vec3(.1031, .1030, .0973)

// --- Uniforms ---
uniform float size = 5.0;
uniform sampler2D iChannel0: repeat_enable; // Background/Noise texture
uniform vec4 ripple_points[500]; // Ripple array: (x, y, time, alpha)
uniform int ripple_point_count = 0; // Number of active ripples
uniform float ripple_strength = 0.5;
uniform vec2 scale = vec2(1.0, 1.0);

// Ripple control
uniform float ripple_decay_speed = 1.0;
uniform float ripple_frequency = 31.0;
uniform float ripple_amplitude = 0.5;
uniform float ripple_variation = 0.3;

uniform bool use_random_points = true;

// --- Utility Functions ---

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * HASHSCALE1);
	p3 += dot(p3, p3.yzx + 19.19);
	return fract((p3.x + p3.y) * p3.z);
}

vec2 hash22(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * HASHSCALE3);
	p3 += dot(p3, p3.yzx + 19.19);
	return fract((p3.xx + p3.yz) * p3.zy);
}

vec2 wrap_coordinates(vec2 p, float res) {
	vec2 wrapped = mod(p, res);
	vec2 quadrant = floor(p / res);
	vec2 hashOffset = hash22(quadrant) * 0.0;
	return wrapped + hashOffset;
}

// Calculate individual ripple
vec2 calculate_ripple(vec2 v, float dist, float time, float alpha) {
	float max_radius = float(MAX_RADIUS) + 1.0;

	// Non-linear time progression
	float dynamic_time = pow(time, 1.0 + ripple_variation * sin(time * 5.0));

	// Frequency and amplitude variation
	float freq_mod = ripple_frequency * (1.0 + 0.2 * sin(time * 10.0));

	// Amplitude decreases with distance
	float amp_mod = ripple_amplitude * (1.0 - dist / (max_radius * 2.0));

	float d = dist - max_radius * dynamic_time;
	float h = 1e-3;
	float d1 = d - h;
	float d2 = d + h;

	// Edge softening
	float edge_softness = mix(0.3, 0.6, sin(time * 2.0));
	float p1 = sin(freq_mod * d1) *
			   smoothstep(-edge_softness, -edge_softness * 0.5, d1) *
			   smoothstep(0.0, -edge_softness * 0.5, d1);
	float p2 = sin(freq_mod * d2) *
			   smoothstep(-edge_softness, -edge_softness * 0.5, d2) *
			   smoothstep(0.0, -edge_softness * 0.5, d2);

	// Decay over time
	float decay = pow(1.0 - time, ripple_decay_speed);

	return 0.5 * amp_mod * normalize(v) *
		   ((p2 - p1) / (2.0 * h) * decay * alpha);
}

// --- Main Fragment Shader ---

void fragment() {
	float resolution = size * 2.0;
	vec2 uv = (UV * resolution) / scale;
	vec2 uv2 = wrap_coordinates(uv, resolution) * vec2(1.0, SCREEN_PIXEL_SIZE.x / SCREEN_PIXEL_SIZE.y);
	vec2 p0 = fract(uv2);
	vec2 circles = vec2(0.0);

	// 1. Background Random Ripples (Optional)
	if (use_random_points) {
		for (int j = -MAX_RADIUS; j <= MAX_RADIUS; ++j) {
			for (int i = -MAX_RADIUS; i <= MAX_RADIUS; ++i) {
				vec2 pi = floor(uv2) + vec2(float(i), float(j));
				vec2 wrapped_pi = wrap_coordinates(pi, resolution);

				#if DOUBLE_HASH
				vec2 hsh = hash22(wrapped_pi);
				#else
				vec2 hsh = wrapped_pi;
				#endif

				vec2 p = wrapped_pi + hash22(hsh);
				float t = fract(0.3 * iTime + hash12(hsh));
				vec2 v = p - wrap_coordinates(uv2, resolution);
				float d = length(v) - (float(MAX_RADIUS) + 1.0) * t;
				float h = 1e-3;
				float d1 = d - h;
				float d2 = d + h;
				float p1 = sin(31.0 * d1) * smoothstep(-0.6, -0.3, d1) * smoothstep(0.0, -0.3, d1);
				float p2 = sin(31.0 * d2) * smoothstep(-0.6, -0.3, d2) * smoothstep(0.0, -0.3, d2);
				circles += 0.5 * normalize(v) * ((p2 - p1) / (2.0 * h) * (1.0 - t) * (1.0 - t));
			}
		}
		circles /= float((MAX_RADIUS * 2 + 1) * (MAX_RADIUS * 2 + 1));
	}

	// 2. Specific Ripples (Player/Rain interaction)
	for (int i = 0; i < ripple_point_count; i++) {
		vec4 ripple_data = ripple_points[i];

		// OPTIMIZATION 1: Skip if alpha is near zero
		if (ripple_data.w < 0.01) continue;

		vec2 ripple_pos = ripple_data.xy / vec2(1.0 / TEXTURE_PIXEL_SIZE);
		float ripple_time = fract(ripple_data.z + 0.3);
		float ripple_alpha = ripple_data.w;

		vec2 wrapped_ripple_point = ripple_pos * resolution;
		vec2 v = uv - wrapped_ripple_point;

		// OPTIMIZATION 2: Squared Distance Check
		// Max effective radius is approx 6.0 units. 6.0^2 = 36.0. Using 40.0 margin.
		// Skip calculation if pixel is further than that.
		if (dot(v, v) > 40.0) continue;

		float dist = length(v);

		vec2 ripple_circles = calculate_ripple(v, dist, ripple_time, ripple_alpha);
		circles += ripple_circles * ripple_strength;
	}

	// 3. Final Mix and Color
	// Soft intensity variation
	float intensity = mix(0.01, 0.15, smoothstep(0.1, 0.6, abs(fract(0.05 * iTime + 0.5) * 2.0 - 1.0)));

	// Calculate Normal
	vec3 n = vec3(circles, sqrt(1.0 - dot(circles, circles)));

	// Sample texture with distortion
	vec3 color = texture(iChannel0, p0 - intensity * n.xy).rgb + 5.0 * pow(clamp(dot(n, normalize(vec3(1.0, 0.7, 0.5))), 0.0, 1.0), 6.0);

	COLOR = vec4(color, 1.0);
}