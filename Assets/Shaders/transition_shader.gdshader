shader_type canvas_item;
uniform float fill : hint_range(-0.01, 1.0) = -0.01;
uniform vec4 color : source_color;
uniform sampler2D height_map;
uniform float smooth_amount : hint_range(0.0, 0.1) = 0.01;
uniform bool use_simple_fade = false;
uniform bool reverse = false;

void fragment() {
	if (fill <= 0.0)
		discard;

	vec4 final_color;

	if (!use_simple_fade) {
	    float h = texture(height_map, UV).x;
		if (!reverse)
	    	h = h + smooth_amount * sin(h * 6.28318530718);
		else
			h = 1.0 - (h + smooth_amount * sin(h * 6.28318530718));
		h = clamp(floor(h + fill), 0.0, 1.0);

		final_color = vec4(color.rgb, color.a * h);
	}
	else {
		final_color = vec4(color.rgb, fill);
	}

	if (fill >= 1.0)
		 final_color = color;

    COLOR = final_color;
}