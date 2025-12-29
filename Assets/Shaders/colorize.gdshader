shader_type canvas_item;

// --- Uniforms ---
uniform vec4[256] palette1 : source_color;
uniform vec4[256] palette2 : source_color;
uniform vec4[256] palette3 : source_color;

uniform float lightness1 : hint_range(0.0, 1.0, 0.1);
uniform float lightness2 : hint_range(0.0, 1.0, 0.1);
uniform float lightness3 : hint_range(0.0, 1.0, 0.1);

uniform sampler2D mask1 : hint_default_black;
uniform sampler2D mask2 : hint_default_black;
uniform sampler2D mask3 : hint_default_black;

uniform bool use_custom_alpha = false;
uniform float alpha : hint_range(0.0, 1.0, 0.01) = 1.0;

uniform bool use_recolor = true;

uniform int highlight_color = -1;
uniform int highlight_palette_id = 0;

void fragment() {
	vec4 color_base = texture(TEXTURE, UV);
	vec4 mask_golor = vec4(1.0, 1.0, 0.0, 1.0);
	vec4 new_color;

	// Calculate highlight pulsing color (Black <-> White smooth animation)
	// Speed is controlled by the multiplier (15.0). 
	// The formula maps sin(-1..1) to (0..1) range.
	float pulse = 0.5 + 0.5 * sin(TIME * 15.0);
	vec3 highlight_pixel = vec3(pulse); 

	// Base mask check
	if (
		(color_base.a <= 0.1) ||
		(color_base == mask_golor) ||
		(texture(mask1, UV) == mask_golor) ||
		(texture(mask2, UV) == mask_golor) ||
		(texture(mask3, UV) == mask_golor))
	{
		new_color = vec4(0.0);
	}
	else if (use_recolor) {
		int color_index = int(color_base.b * 255.0);

		// Palette 1 Logic
		if (color_base.r == 0.0 && color_base.g == 0.0) { 
			if (color_index == highlight_color && highlight_palette_id == 1){
				// Apply the animated grayscale pulse
				new_color = vec4(highlight_pixel, 1.0);
			}
			else{
				new_color = vec4(palette1[color_index].rgb, 0.0);
				new_color *= (1.0 + lightness1);
			}
		}
		// Palette 2 Logic
		else if (color_base.r == 0.0 && color_base.g == 1.0) { 
			if (color_index == highlight_color && highlight_palette_id == 2){
				new_color = vec4(highlight_pixel, 1.0);
			}
			else{
				new_color = vec4(palette2[color_index].rgb, 0.0);
				new_color *= (1.0 + lightness2);
			}
		}
		// Palette 3 Logic
		else if (color_base.r == 1.0 && color_base.g == 0.0) { 
			if (color_index == highlight_color && highlight_palette_id == 3){
				new_color = vec4(highlight_pixel, 1.0);
			}
			else{
				new_color = vec4(palette3[color_index].rgb, 0.0);
				new_color *= (1.0 + lightness3);
			}
		}
		
		// Apply original alpha to keep transparency shapes
		new_color.a = color_base.a;
	}
	else {
		new_color = color_base;
	}

	// Final alpha compositing
	if (new_color.a > 0.0 && use_custom_alpha) {
		float a = new_color.a;
		if (alpha < a){
			a = alpha;
		}
		COLOR = vec4(new_color.rgb, a);
	}
	else {
		COLOR = new_color;
	}
}