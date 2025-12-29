/*
    放射状ブラーエフェクト by あるる（きのもと　結衣） @arlez80
    Radial Blur Effect by Yui Kinomoto

    MIT License
*/
shader_type canvas_item;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture;
// Centro del blur
uniform vec2 blur_center = vec2( 0.5, 0.5 );
// Intensidad del blur
uniform float blur_power : hint_range( 0.0, 1.0 ) = 0.01;
// Cantidad de muestras
uniform int sampling_count : hint_range( 1, 64 ) = 6;

// Usaremos la resolución del viewport
uniform vec2 viewport_resolution;

void fragment()
{
    // Relación de aspecto del viewport
    vec2 uv = SCREEN_UV;
    vec2 aspect_ratio = viewport_resolution / min(viewport_resolution.x, viewport_resolution.y);

    // Ajuste de la dirección según la relación de aspecto
    vec2 direction = (uv - blur_center) * aspect_ratio;

    vec3 color = vec3(0.0);
    float weight = 1.0 / float(sampling_count);

    for (int i = 0; i < sampling_count; i++) {
        color += texture(SCREEN_TEXTURE, uv - blur_power * direction * float(i)).rgb * weight;
    }

    COLOR.rgb = color;
}
