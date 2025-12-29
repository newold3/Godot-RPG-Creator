shader_type canvas_item;
// Cambiamos a blend_mix para un comportamiento estándar de sombras/transparencias
render_mode blend_mix; 

uniform float blur_size : hint_range(0.0, 5.0) = 1.0;
uniform vec4 overlay_color : source_color = vec4(0.0, 0.0, 0.0, 0.5);

void fragment() {
	vec2 pixel_size = TEXTURE_PIXEL_SIZE;
	float final_alpha = 0.0;

	// Kernel gaussiano 5x5 aplanado y normalizado
	// La suma de todos estos valores es aprox 1.0
	float kernel[25] = float[](
		0.0037, 0.0146, 0.0256, 0.0146, 0.0037,
		0.0146, 0.0586, 0.0952, 0.0586, 0.0146,
		0.0256, 0.0952, 0.1501, 0.0952, 0.0256,
		0.0146, 0.0586, 0.0952, 0.0586, 0.0146,
		0.0037, 0.0146, 0.0256, 0.0146, 0.0037
	);

	int i = 0;
	// Recorremos el kernel
	for(int x = -2; x <= 2; x++) {
		for(int y = -2; y <= 2; y++) {
			// Calculamos el offset.
			// NOTA: Multiplicar por blur_size separa las muestras. 
			// Si blur_size es muy alto, verás "fantasmas" (banding).
			vec2 offset = vec2(float(x), float(y)) * pixel_size * blur_size;
			
			// Solo nos interesa el Alpha para la sombra
			float a = texture(TEXTURE, UV + offset).a;
			
			// Acumulamos el alpha ponderado por el kernel
			final_alpha += a * kernel[i];
			i++;
		}
	}

	// Asignamos el color del overlay con el alpha calculado (desenfocado)
	// Multiplicamos también por el alpha del propio overlay si quieres controlar opacidad global
	COLOR = vec4(overlay_color.rgb, final_alpha * overlay_color.a);
}