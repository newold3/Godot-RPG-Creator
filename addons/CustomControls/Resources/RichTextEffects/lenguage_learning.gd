@tool
extends RichTextEffect
class_name RichTextLanguageLearning

# Syntax: [learn progress=0.5, use_var=false, var=1][/learn]
var bbcode = "learn"

# Caracteres de sustitución para codificar
var substitution_chars = [
	GlyphConverter.ord("a"), GlyphConverter.ord("e"), GlyphConverter.ord("i"), GlyphConverter.ord("o"), GlyphConverter.ord("u"),
	GlyphConverter.ord("b"), GlyphConverter.ord("c"), GlyphConverter.ord("d"), GlyphConverter.ord("f"), GlyphConverter.ord("g"),
	GlyphConverter.ord("h"), GlyphConverter.ord("j"), GlyphConverter.ord("k"), GlyphConverter.ord("l"), GlyphConverter.ord("m"),
	GlyphConverter.ord("n"), GlyphConverter.ord("p"), GlyphConverter.ord("q"), GlyphConverter.ord("r"), GlyphConverter.ord("s"),
	GlyphConverter.ord("t"), GlyphConverter.ord("v"), GlyphConverter.ord("w"), GlyphConverter.ord("x"), GlyphConverter.ord("y"),
	GlyphConverter.ord("z")
]

# Función hash determinística simple
func simple_hash(value: int, seed: int = 0) -> int:
	var hash_val = value + seed
	hash_val = ((hash_val >> 16) ^ hash_val) * 0x45d9f3b
	hash_val = ((hash_val >> 16) ^ hash_val) * 0x45d9f3b
	hash_val = (hash_val >> 16) ^ hash_val
	return abs(hash_val)

# Función para determinar si un carácter debe ser codificado
func should_encode_char(char_code: int, position: int, progress: float) -> bool:
	if progress >= 1.0:
		return false
	if progress <= 0.0:
		return true
	
	# Usar hash basado en el carácter y su posición para consistencia
	var hash_val = simple_hash(char_code + position * 31)
	var threshold = progress * 1000.0  # Escalar para mejor precisión
	return (hash_val % 1000) >= int(threshold)

# Función para obtener carácter de sustitución
func get_substitution_char(original_char: int, position: int) -> int:
	# Usar hash para seleccionar un carácter de sustitución consistente
	var hash_val = simple_hash(original_char + position * 17)
	var index = hash_val % substitution_chars.size()
	return substitution_chars[index]

# Función para verificar si es un carácter alfabético
func is_alphabetic(char_code: int) -> bool:
	return (char_code >= GlyphConverter.ord("a") and char_code <= GlyphConverter.ord("z")) or \
		   (char_code >= GlyphConverter.ord("A") and char_code <= GlyphConverter.ord("Z")) or \
		   (char_code >= GlyphConverter.ord("á") and char_code <= GlyphConverter.ord("ÿ"))

func _process_custom_fx(char_fx: CharFXTransform) -> bool:
	# Obtener el parámetro progress (por defecto 0.0 si no se especifica)
	var progress = char_fx.env.get("progress", 0.0)
	var use_var = char_fx.env.get("use_var", false)
	var var_id = char_fx.env.get("var", 1)
	
	if use_var:
		var obj_value = GameManager.get_text_variable(var_id)
		progress = float(obj_value)
	
	# Convertir a float si viene como string
	if progress is String:
		progress = float(progress)
	
	# Asegurar que progress esté en el rango [0.0, 1.0]
	progress = clamp(progress, 0.0, 1.0)
	
	# Obtener el carácter actual
	var current_char = GlyphConverter.glyph_index_to_char(char_fx)
	
	# Solo procesar caracteres alfabéticos
	if not is_alphabetic(current_char):
		return true
	
	# Determinar si este carácter debe ser codificado
	if should_encode_char(current_char, char_fx.relative_index, progress):
		# Obtener carácter de sustitución
		var substitution = get_substitution_char(current_char, char_fx.relative_index)
		
		# Mantener la capitalización original
		if current_char >= GlyphConverter.ord("A") and current_char <= GlyphConverter.ord("Z"):
			# Si el original era mayúscula, hacer mayúscula la sustitución
			if substitution >= GlyphConverter.ord("a") and substitution <= GlyphConverter.ord("z"):
				substitution = substitution - GlyphConverter.ord("a") + GlyphConverter.ord("A")
		
		# Aplicar la sustitución
		char_fx.glyph_index = GlyphConverter.char_to_glyph_index(char_fx.font, substitution)
	
	return true
