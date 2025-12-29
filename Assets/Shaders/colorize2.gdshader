shader_type canvas_item;


uniform vec4 tint_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float tint_strength : hint_range(0.0, 1.0) = 0.35;

void fragment() {
    vec4 original_color = texture(TEXTURE, UV);

    float luminosity = dot(original_color.rgb, vec3(0.299, 0.587, 0.114));

    vec3 new_color = mix(vec3(luminosity), tint_color.rgb, tint_strength);


    COLOR = vec4(new_color, original_color.a);
}