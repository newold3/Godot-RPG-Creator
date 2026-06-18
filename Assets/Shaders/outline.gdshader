shader_type canvas_item;

uniform vec4 color : source_color = vec4(1.0);
uniform float width : hint_range(0, 10) = 1.0;
uniform int pattern : hint_range(0, 2) = 0; // diamond, circle, square
uniform bool inside = false;
uniform bool add_margins = true; // only useful when inside is false
uniform vec2 number_of_images = vec2(1.0); // number of horizontal and vertical images in the sprite sheet
uniform bool disabled = false;

void vertex() {
	if (add_margins && !disabled) {
		VERTEX += sign(VERTEX) * width; // replace sign(VERTEX) by (sign(VERTEX) * 2.0 - 1.0) if not Centered
	}
}

bool hasContraryNeighbour(vec2 uv, vec2 texture_pixel_size, vec2 image_top_left, vec2 image_bottom_right, sampler2D texture) {
	for (float i = -ceil(width); i <= ceil(width); i++) {
		float x = abs(i) > width ? width * sign(i) : i;
		float offset;
		
		if (pattern == 0) {
			offset = width - abs(x);
		} else if (pattern == 1) {
			offset = floor(sqrt(pow(width + 0.5, 2) - x * x));
		} else if (pattern == 2) {
			offset = width;
		}
		
		for (float j = -ceil(offset); j <= ceil(offset); j++) {
			float y = abs(j) > offset ? offset * sign(j) : j;
			vec2 xy = uv + texture_pixel_size * vec2(x, y);
			
			if ((xy != clamp(xy, image_top_left, image_bottom_right) || texture(texture, xy).a <= 0.0) == inside) {
				return true;
			}
		}
	}
	
	return false;
}

void fragment() {
	if (!disabled){
		vec2 uv = UV;
		vec2 image_top_left = floor(uv * number_of_images) / number_of_images;
		vec2 image_bottom_right = image_top_left + vec2(1.0) / number_of_images;
		
		float alpha = COLOR.a;

		if (add_margins) {
			vec2 texture_pixel_size = vec2(1.0) / (vec2(1.0) / TEXTURE_PIXEL_SIZE + vec2(width * 2.0) * number_of_images);
			
			uv = (uv - texture_pixel_size * width - image_top_left) * TEXTURE_PIXEL_SIZE / texture_pixel_size + image_top_left;
			
			if (uv != clamp(uv, image_top_left, image_bottom_right)) {
				COLOR.a = 0.0;
			} else {
				COLOR = texture(TEXTURE, uv);
			}
		} else {
			COLOR = texture(TEXTURE, uv);
		}
		
		if ((COLOR.a > 0.0) == inside && hasContraryNeighbour(uv, TEXTURE_PIXEL_SIZE, image_top_left, image_bottom_right, TEXTURE)) {
			COLOR.rgb = inside ? mix(COLOR.rgb, color.rgb, color.a) : color.rgb;
			COLOR.a += (1.0 - COLOR.a) * color.a;
		}
		
		COLOR.a *= alpha;
	}
}