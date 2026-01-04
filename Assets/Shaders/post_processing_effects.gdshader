shader_type canvas_item;

// Screen texture
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap_anisotropic;

// === Parameters by effect ===
group_uniforms GrayscaleParameters;
uniform bool enable_grayscale = false;

group_uniforms SepiaParameters;
uniform bool enable_sepia = false;
uniform float sepia_strength : hint_range(0.0, 1.0) = 1.0;

group_uniforms GrainParameters;
uniform bool enable_grain = false;
uniform float grain_amount : hint_range(0.0, 3.0, 0.001) = 0.23;
uniform float grain_speed : hint_range(0.0, 10.0, 0.001) = 0.74;

group_uniforms CartoonParameters;
uniform bool enable_cartoon = false;
uniform float cartoon_levels : hint_range(2.0, 16.0) = 5.518;

group_uniforms PosterizeParameters;
uniform bool enable_posterize = false;
uniform float posterize_levels : hint_range(2.0, 32.0) = 8.0;

group_uniforms VignetteParameters;
uniform bool enable_vignette = false;
uniform float vignette_intensity : hint_range(0.0, 2.0) = 0.8;
uniform float vignette_smoothness : hint_range(0.1, 2.0) = 0.5;

group_uniforms ChromaticAberrationParameters;
uniform bool enable_chromatic_aberration = false;
uniform float aberration_strength : hint_range(0.0, 0.05) = 0.01;

group_uniforms ScanlinesParameters;
uniform bool enable_scanlines = false;
uniform float scanlines_count : hint_range(100.0, 1000.0) = 300.0;
uniform float scanlines_intensity : hint_range(0.0, 1.0) = 0.5;

group_uniforms PixelateParameters;
uniform bool enable_pixelate = false;
uniform int pixel_size : hint_range(2, 50) = 8;

group_uniforms BlurParameters;
uniform bool enable_blur = false;
uniform float blur_amount : hint_range(0.0, 0.01) = 0.003;

group_uniforms SharpenParameters;
uniform bool enable_sharpen = false;
uniform float sharpen_amount : hint_range(0.0, 5.0) = 1.5;
uniform float sharpen_offset : hint_range(0.001, 0.01) = 0.003;

group_uniforms InvertParameters;
uniform bool enable_invert = false;

group_uniforms NightVisionParameters;
uniform bool enable_night_vision = false;
uniform vec3 night_vision_color : source_color = vec3(0.1, 1.0, 0.2);
uniform float night_vision_noise : hint_range(0.0, 1.0) = 0.3;

group_uniforms ThermalParameters;
uniform bool enable_thermal_vision = false;
uniform float thermal_intensity : hint_range(0.0, 2.0) = 1.0;
uniform float thermal_sensitivity : hint_range(0.1, 3.0) = 1.0;
uniform float thermal_offset : hint_range(-0.5, 0.5) = 0.0;

group_uniforms WarpParameters;
uniform bool enable_warp = false;
uniform float warp_amount : hint_range(-5.0, 5.0, 0.001) = 1.0;

group_uniforms FilmGrainParameters;
uniform bool enable_film_grain = false;
uniform float film_grain_amount : hint_range(0.0, 1.0) = 0.5;
uniform float film_grain_size : hint_range(0.1, 2.0) = 1.0;
uniform float film_grain_speed : hint_range(0.0, 2.0) = 0.3;
uniform float film_grain_rotation : hint_range(0.0, 6.28318) = 1.57;

group_uniforms DistortionParameters;
uniform bool enable_distortion = false;
uniform float distortion_strength : hint_range(0.0, 0.5) = 0.1;

group_uniforms ColorShiftParameters;
uniform bool enable_color_shift = false;
uniform float color_shift_amount : hint_range(0.0, 1.0) = 0.5;
uniform float color_shift_speed : hint_range(0.0, 5.0) = 1.0;

group_uniforms BloomParameters;
uniform bool enable_bloom = false;
uniform float bloom_intensity : hint_range(0.0, 2.0) = 1.0;
uniform float bloom_threshold : hint_range(0.0, 1.0) = 0.8;
uniform float bloom_radius : hint_range(0.001, 0.01) = 0.005;

group_uniforms DesaturateParameters;
uniform bool enable_desaturate = false;
uniform float desaturate_amount : hint_range(0.0, 1.0) = 0.7;

group_uniforms FisheyeParameters;
uniform bool enable_fisheye = false;
uniform float fisheye_strength : hint_range(0.0, 2.0) = 1.0;

group_uniforms ColorizeParameters;
uniform bool enable_colorize = false;
uniform vec3 colorize_color : source_color = vec3(1.0, 0.5, 0.2);
uniform float colorize_intensity : hint_range(0.0, 1.0) = 0.5;
uniform float colorize_brightness : hint_range(0.0, 2.0) = 1.0;

float random(vec2 uv) {
    return fract(sin(dot(uv, vec2(12.9898, 78.233))) * 43758.5453);
}

vec3 rgb2hsv(vec3 c) {
    vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
    vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
    vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
    float d = q.x - min(q.w, q.y);
    float e = 1.0e-10;
    return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

vec3 hsv2rgb(vec3 c) {
    vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
    vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

// Warp curvature function
vec2 warp(vec2 uv){
	vec2 delta = uv - 0.5;
	float delta2 = dot(delta.xy, delta.xy);
	float delta4 = delta2 * delta2;
	float delta_offset = delta4 * abs(warp_amount);

	vec2 warped;
	if (warp_amount >= 0.0) {
		// Outward curvature (convex) - original behavior
		warped = uv + delta * delta_offset;
		return (warped - 0.5) / mix(1.0, 1.2, warp_amount/5.0) + 0.5;
	} else {
		// Inward curvature (concave) - sink towards center
		warped = uv - delta * delta_offset;
		return warped;
	}
}

void fragment() {
    vec2 uv = SCREEN_UV;
    vec4 col = texture(SCREEN_TEXTURE, uv);

    // Apply effects in order

    // Distortion effects (modify UV first)
    if (enable_warp) {
        vec2 warped_uv = warp(uv);

        if (warped_uv.x < 0.0 || warped_uv.x > 1.0 || warped_uv.y < 0.0 || warped_uv.y > 1.0) {
            col = vec4(0.0, 0.0, 0.0, 1.0);
        } else {
            col = texture(SCREEN_TEXTURE, warped_uv);
        }
    }

    if (enable_fisheye) {
        vec2 center = uv - 0.5;
        float dist = length(center);
        float distortion = 1.0 + dist * fisheye_strength;
        vec2 fisheye_uv = center / distortion + 0.5;

        if (fisheye_uv.x < 0.0 || fisheye_uv.x > 1.0 || fisheye_uv.y < 0.0 || fisheye_uv.y > 1.0) {
            col = vec4(0.0);
        } else {
            col = texture(SCREEN_TEXTURE, fisheye_uv);
        }
    }

    if (enable_distortion) {
        vec2 center = uv - 0.5;
        float dist = length(center);
        vec2 distorted_uv = uv + center * sin(dist * 10.0) * distortion_strength;
        col = texture(SCREEN_TEXTURE, distorted_uv);
    }

    if (enable_pixelate) {
        vec2 screen_size = 1.0 / SCREEN_PIXEL_SIZE;
        vec2 pixel_uv = floor(uv * screen_size / float(pixel_size)) * float(pixel_size) / screen_size;
        col = texture(SCREEN_TEXTURE, pixel_uv);
    }

    // Chromatic effects
    if (enable_chromatic_aberration) {
        vec2 offset = aberration_strength * (uv - 0.5);
        col.r = texture(SCREEN_TEXTURE, uv + offset).r;
        col.g = texture(SCREEN_TEXTURE, uv).g;
        col.b = texture(SCREEN_TEXTURE, uv - offset).b;
    }

    // Blur/Sharpen effects
    if (enable_blur) {
        vec4 blur_col = vec4(0.0);
        for(int x = -2; x <= 2; x++) {
            for(int y = -2; y <= 2; y++) {
                blur_col += texture(SCREEN_TEXTURE, uv + vec2(float(x), float(y)) * blur_amount);
            }
        }
        col = blur_col / 25.0;
    }

    if (enable_sharpen) {
        vec4 sharp = texture(SCREEN_TEXTURE, uv) * 5.0;
        sharp -= texture(SCREEN_TEXTURE, uv + vec2(sharpen_offset, 0.0));
        sharp -= texture(SCREEN_TEXTURE, uv - vec2(sharpen_offset, 0.0));
        sharp -= texture(SCREEN_TEXTURE, uv + vec2(0.0, sharpen_offset));
        sharp -= texture(SCREEN_TEXTURE, uv - vec2(0.0, sharpen_offset));
        col = mix(col, sharp, sharpen_amount);
    }

    // Color effects
    if (enable_grayscale) {
        float gray = dot(col.rgb, vec3(0.299, 0.587, 0.114));
        col.rgb = vec3(gray);
    }

    if (enable_sepia) {
        vec3 sepia_color = vec3(
            dot(col.rgb, vec3(0.393, 0.769, 0.189)),
            dot(col.rgb, vec3(0.349, 0.686, 0.168)),
            dot(col.rgb, vec3(0.272, 0.534, 0.131))
        );
        col.rgb = mix(col.rgb, sepia_color, sepia_strength);
    }

    if (enable_cartoon) {
        col.rgb = floor(col.rgb * cartoon_levels) / cartoon_levels;
    }

    // Posterize effect (different from cartoon)
    if (enable_posterize) {
        // Posterize works in HSV space for better color preservation
        vec3 hsv = rgb2hsv(col.rgb);
        hsv.z = floor(hsv.z * posterize_levels) / posterize_levels;
        col.rgb = hsv2rgb(hsv);
    }

    if (enable_invert) {
        col.rgb = 1.0 - col.rgb;
    }

    if (enable_desaturate) {
        float gray = dot(col.rgb, vec3(0.299, 0.587, 0.114));
        col.rgb = mix(col.rgb, vec3(gray), desaturate_amount);
    }

    if (enable_colorize) {
        float gray = dot(col.rgb, vec3(0.299, 0.587, 0.114));
        vec3 colorized = colorize_color * gray * colorize_brightness;
        col.rgb = mix(col.rgb, colorized, colorize_intensity);
    }

    if (enable_color_shift) {
        vec3 hsv = rgb2hsv(col.rgb);
        hsv.x += sin(TIME * color_shift_speed) * color_shift_amount;
        col.rgb = hsv2rgb(hsv);
    }

    // Special vision modes
    if (enable_night_vision) {
        float luminance = dot(col.rgb, vec3(0.299, 0.587, 0.114));
        vec3 night_color = night_vision_color * luminance;
        float noise = random(uv + TIME) * night_vision_noise;
        col.rgb = night_color + noise;
    }

    if (enable_thermal_vision) {
        float temp = dot(col.rgb, vec3(0.299, 0.587, 0.114)) * thermal_sensitivity + thermal_offset;
        temp = clamp(temp, 0.0, 1.0);

        vec3 thermal_color;
        if (temp < 0.25) {
            thermal_color = mix(vec3(0.0, 0.0, 1.0), vec3(0.0, 1.0, 1.0), temp * 4.0);
        } else if (temp < 0.5) {
            thermal_color = mix(vec3(0.0, 1.0, 1.0), vec3(0.0, 1.0, 0.0), (temp - 0.25) * 4.0);
        } else if (temp < 0.75) {
            thermal_color = mix(vec3(0.0, 1.0, 0.0), vec3(1.0, 1.0, 0.0), (temp - 0.5) * 4.0);
        } else {
            thermal_color = mix(vec3(1.0, 1.0, 0.0), vec3(1.0, 0.0, 0.0), (temp - 0.75) * 4.0);
        }
        col.rgb = thermal_color * thermal_intensity;
    }

    // Overlay/texture effects
    if (enable_scanlines) {
        float scanline = sin(uv.y * scanlines_count) * 0.5 + 0.5;
        col.rgb = mix(col.rgb, col.rgb * scanline, scanlines_intensity);
    }

    if (enable_grain) {
        float noise = (fract(sin(dot(UV, vec2(12.9898, 78.233))) * round(TIME * grain_speed) * 8.5453) - 0.5) * 1.5;
        col.rgb += noise * grain_amount;
        col.rgb = clamp(col.rgb, 0.0, 1.0);
    }

    if (enable_film_grain) {
        // Rotate UV coordinates for grain pattern
        vec2 grain_uv = uv;
        float cos_rot = cos(film_grain_rotation);
        float sin_rot = sin(film_grain_rotation);
        grain_uv = vec2(
            grain_uv.x * cos_rot - grain_uv.y * sin_rot,
            grain_uv.x * sin_rot + grain_uv.y * cos_rot
        );

        // Apply time-based movement for subtle animation
        grain_uv += TIME * film_grain_speed * 0.1;

        // Generate multiple grain layers for more realistic texture
        float grain1 = random(grain_uv * film_grain_size);
        float grain2 = random(grain_uv * film_grain_size * 1.7 + vec2(0.5, 0.3));
        float grain3 = random(grain_uv * film_grain_size * 0.6 + vec2(0.2, 0.8));

        // Combine grain layers with different weights
        float grain = (grain1 * 0.5 + grain2 * 0.3 + grain3 * 0.2) * film_grain_amount;

        // Apply grain as overlay blend for more realistic look
        col.rgb = mix(col.rgb, vec3(grain), 0.3);
    }

    // Final effects
    if (enable_bloom) {
        float luminance = dot(col.rgb, vec3(0.299, 0.587, 0.114));
        if (luminance > bloom_threshold) {
            // Simple bloom with radius
            vec4 bloom_col = vec4(0.0);
            int samples = 8;
            for(int i = 0; i < samples; i++) {
                float angle = float(i) / float(samples) * 6.28318;
                vec2 offset = vec2(cos(angle), sin(angle)) * bloom_radius;
                bloom_col += texture(SCREEN_TEXTURE, uv + offset);
            }
            bloom_col /= float(samples);
            vec3 bloom_color = bloom_col.rgb * bloom_intensity;
            col.rgb = mix(col.rgb, bloom_color, 0.5);
        }
    }

    if (enable_vignette) {
        vec2 center = uv - 0.5;
        float dist = length(center);
        float vignette = smoothstep(vignette_intensity, vignette_intensity - vignette_smoothness, dist);
        col.rgb = mix(col.rgb, vec3(0.0), 1.0 - vignette);
    }

    COLOR = col;
}