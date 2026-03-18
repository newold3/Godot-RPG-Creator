shader_type canvas_item;

//* Main water color */
uniform vec4 WATER_COL : source_color =  vec4(0.176471, 0.635294, 0.85098, 1.0);
//* Secondary water color */
uniform vec4 WATER2_COL : source_color =  vec4(0.0588235, 0.529412, 0.776471, 1.0);
//* Foam color */
uniform vec4 FOAM_COL : source_color = vec4(0.87451, 0.988235, 1.0, 1.0);

//* Overall animation speed */
uniform float distortion_speed = 2.0;
//* Tile scale mapping */
uniform vec2 tile = vec2(5.0, 5.0);
//* UV offset */
uniform vec2 offset = vec2(0.0, 0.0);

//* Blends the shader output with the original tilemap texture in water areas (0.0 = full shader, 1.0 = full original) */
uniform float mix_amount : hint_range(0.0, 1.0) = 0.5;

//* First noise texture for organic swaying */
uniform sampler2D noise1 : repeat_enable;
//* Second noise texture for organic swaying */
uniform sampler2D noise2 : repeat_enable;
//* How much the noise textures affect the water pattern coordinates */
uniform float organic_strength : hint_range(0.0, 1.0) = 0.05;

//* Start of land detection based on Red minus Blue color difference */
uniform float land_threshold_low : hint_range(-1.0, 1.0) = 0.0;
//* Point where the pixel is considered fully land (no water drawn) */
uniform float land_threshold_high : hint_range(-1.0, 1.0) = 0.2;
//* Center position of the foam line on the edge */
uniform float foam_position : hint_range(-1.0, 1.0) = 0.05;
//* Thickness of the foam line */
uniform float foam_thickness : hint_range(0.0, 0.5) = 0.05;

const float TWOPI = 6.283185307;
const float SIXPI = 18.84955592;

varying vec2 globalposition;



void vertex() {
	globalposition = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}



float circ(vec2 pos, vec2 c, float s) {
	c = abs(pos - c);
	c = min(c, 1.0 - c);
	return smoothstep(0.0, 0.002, sqrt(s) - sqrt(dot(c, c))) * -1.0;
}



float waterlayer(vec2 uv) {
	uv = mod(uv, 1.0);
	float ret = 1.0;
	ret += circ(uv, vec2(0.37378, 0.277169), 0.0268181);
	ret += circ(uv, vec2(0.0317477, 0.540372), 0.0193742);
	ret += circ(uv, vec2(0.430044, 0.882218), 0.0232337);
	ret += circ(uv, vec2(0.641033, 0.695106), 0.0117864);
	ret += circ(uv, vec2(0.0146398, 0.0791346), 0.0299458);
	ret += circ(uv, vec2(0.43871, 0.394445), 0.0289087);
	ret += circ(uv, vec2(0.909446, 0.878141), 0.028466);
	ret += circ(uv, vec2(0.310149, 0.686637), 0.0128496);
	ret += circ(uv, vec2(0.928617, 0.195986), 0.0152041);
	ret += circ(uv, vec2(0.0438506, 0.868153), 0.0268601);
	ret += circ(uv, vec2(0.308619, 0.194937), 0.00806102);
	ret += circ(uv, vec2(0.349922, 0.449714), 0.00928667);
	ret += circ(uv, vec2(0.0449556, 0.953415), 0.023126);
	ret += circ(uv, vec2(0.117761, 0.503309), 0.0151272);
	ret += circ(uv, vec2(0.563517, 0.244991), 0.0292322);
	ret += circ(uv, vec2(0.566936, 0.954457), 0.00981141);
	ret += circ(uv, vec2(0.0489944, 0.200931), 0.0178746);
	ret += circ(uv, vec2(0.569297, 0.624893), 0.0132408);
	ret += circ(uv, vec2(0.298347, 0.710972), 0.0114426);
	ret += circ(uv, vec2(0.878141, 0.771279), 0.00322719);
	ret += circ(uv, vec2(0.150995, 0.376221), 0.00216157);
	ret += circ(uv, vec2(0.119673, 0.541984), 0.0124621);
	ret += circ(uv, vec2(0.629598, 0.295629), 0.0198736);
	ret += circ(uv, vec2(0.334357, 0.266278), 0.0187145);
	ret += circ(uv, vec2(0.918044, 0.968163), 0.0182928);
	ret += circ(uv, vec2(0.965445, 0.505026), 0.006348);
	ret += circ(uv, vec2(0.514847, 0.865444), 0.00623523);
	ret += circ(uv, vec2(0.710575, 0.0415131), 0.00322689);
	ret += circ(uv, vec2(0.71403, 0.576945), 0.0215641);
	ret += circ(uv, vec2(0.748873, 0.413325), 0.0110795);
	ret += circ(uv, vec2(0.0623365, 0.896713), 0.0236203);
	ret += circ(uv, vec2(0.980482, 0.473849), 0.00573439);
	ret += circ(uv, vec2(0.647463, 0.654349), 0.0188713);
	ret += circ(uv, vec2(0.651406, 0.981297), 0.00710875);
	ret += circ(uv, vec2(0.428928, 0.382426), 0.0298806);
	ret += circ(uv, vec2(0.811545, 0.62568), 0.00265539);
	ret += circ(uv, vec2(0.400787, 0.74162), 0.00486609);
	ret += circ(uv, vec2(0.331283, 0.418536), 0.00598028);
	ret += circ(uv, vec2(0.894762, 0.0657997), 0.00760375);
	ret += circ(uv, vec2(0.525104, 0.572233), 0.0141796);
	ret += circ(uv, vec2(0.431526, 0.911372), 0.0213234);
	ret += circ(uv, vec2(0.658212, 0.910553), 0.000741023);
	ret += circ(uv, vec2(0.514523, 0.243263), 0.0270685);
	ret += circ(uv, vec2(0.0249494, 0.252872), 0.00876653);
	ret += circ(uv, vec2(0.502214, 0.47269), 0.0234534);
	ret += circ(uv, vec2(0.693271, 0.431469), 0.0246533);
	ret += circ(uv, vec2(0.415, 0.884418), 0.0271696);
	ret += circ(uv, vec2(0.149073, 0.41204), 0.00497198);
	ret += circ(uv, vec2(0.533816, 0.897634), 0.00650833);
	ret += circ(uv, vec2(0.0409132, 0.83406), 0.0191398);
	ret += circ(uv, vec2(0.638585, 0.646019), 0.0206129);
	ret += circ(uv, vec2(0.660342, 0.966541), 0.0053511);
	ret += circ(uv, vec2(0.513783, 0.142233), 0.00471653);
	ret += circ(uv, vec2(0.124305, 0.644263), 0.00116724);
	ret += circ(uv, vec2(0.99871, 0.583864), 0.0107329);
	ret += circ(uv, vec2(0.894879, 0.233289), 0.00667092);
	ret += circ(uv, vec2(0.246286, 0.682766), 0.00411623);
	ret += circ(uv, vec2(0.0761895, 0.16327), 0.0145935);
	ret += circ(uv, vec2(0.949386, 0.802936), 0.0100873);
	ret += circ(uv, vec2(0.480122, 0.196554), 0.0110185);
	ret += circ(uv, vec2(0.896854, 0.803707), 0.013969);
	ret += circ(uv, vec2(0.292865, 0.762973), 0.00566413);
	ret += circ(uv, vec2(0.0995585, 0.117457), 0.00869407);
	ret += circ(uv, vec2(0.377713, 0.00335442), 0.0063147);
	ret += circ(uv, vec2(0.506365, 0.531118), 0.0144016);
	ret += circ(uv, vec2(0.408806, 0.894771), 0.0243923);
	ret += circ(uv, vec2(0.143579, 0.85138), 0.00418529);
	ret += circ(uv, vec2(0.0902811, 0.181775), 0.0108896);
	ret += circ(uv, vec2(0.780695, 0.394644), 0.00475475);
	ret += circ(uv, vec2(0.298036, 0.625531), 0.00325285);
	ret += circ(uv, vec2(0.218423, 0.714537), 0.00157212);
	ret += circ(uv, vec2(0.658836, 0.159556), 0.00225897);
	ret += circ(uv, vec2(0.987324, 0.146545), 0.0288391);
	ret += circ(uv, vec2(0.222646, 0.251694), 0.00092276);
	ret += circ(uv, vec2(0.159826, 0.528063), 0.00605293);
	return max(ret, 0.0);
}



vec3 water(vec2 uv, vec3 cdir, float iTime) {
	uv *= vec2(0.25);
	
	vec2 a = 0.025 * cdir.xz / cdir.y;
	float h = sin(uv.x + iTime);
	uv += a * h;
	h = sin(0.841471 * uv.x - 0.540302 * uv.y + iTime);
	uv += a * h;
	
	float d1 = mod(uv.x + uv.y, TWOPI);
	float d2 = mod((uv.x + uv.y + 0.25) * 1.3, SIXPI);
	d1 = iTime * 0.07 + d1;
	d2 = iTime * 0.5 + d2;
	
	vec2 dist = vec2(
		sin(d1) * 0.15 + sin(d2) * 0.05,
		cos(d1) * 0.15 + cos(d2) * 0.05
	);
	
	vec3 ret = mix(WATER_COL.rgb, WATER2_COL.rgb, waterlayer(uv + dist.xy));
	ret = mix(ret, FOAM_COL.rgb, waterlayer(vec2(1.0) - uv - dist.yx));
	return ret;
}



void fragment() {
	vec4 original_color = texture(TEXTURE, UV);
	vec2 uv = globalposition / 32.0;
	
	vec2 noise_uv = globalposition * 0.01;
	float n1 = texture(noise1, noise_uv + TIME * 0.05).r;
	float n2 = texture(noise2, noise_uv - TIME * 0.03).r;
	float combined_noise = (n1 + n2) * 0.5;
	
	vec2 organic_uv = uv * tile + offset + vec2(combined_noise) * organic_strength;
	vec3 generated_water = water(organic_uv, vec3(0.0, 1.0, 0.0), TIME * distortion_speed);
	
	float edge_diff = original_color.r - original_color.b;
	
	float land_mask = smoothstep(land_threshold_low, land_threshold_high, edge_diff);
	
	float noisy_edge = edge_diff + (combined_noise - 0.5) * 0.1;
	float foam_line = smoothstep(foam_position - foam_thickness, foam_position, noisy_edge) 
					- smoothstep(foam_position, foam_position + foam_thickness, noisy_edge);
	foam_line = clamp(foam_line, 0.0, 1.0);
	
	vec3 water_area = mix(generated_water, original_color.rgb, mix_amount);
	
	vec3 final_rgb = mix(water_area, original_color.rgb, land_mask);
	final_rgb = mix(final_rgb, FOAM_COL.rgb, foam_line);
	
	COLOR = vec4(final_rgb, original_color.a);
}