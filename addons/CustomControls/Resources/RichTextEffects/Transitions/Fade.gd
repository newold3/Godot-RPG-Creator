@tool
class_name RichTextEffectTransitionFade
extends RichTextEffectTransitionBase

var bbcode = "transition_fade"
var char_start_times = {}
var current_index = -1
var is_show_all_mode = false
var show_all_start_time = 0.0
var last_visible_characters = 0
var effect_initialized = false

func _process_custom_fx(char_fx: CharFXTransform) -> bool:
	var char_index = char_fx.range.x
	var visible_characters = get_visible_characters()
	var fade_duration = 0.35
	
	# Reset completo cuando cambia el texto o se reinicia
	if visible_characters == 0 or (visible_characters == 1 and char_index == 0):
		_reset_effect()
		effect_initialized = false
	
	# Detectar cambio a modo "mostrar todo"
	if visible_characters == -1:
		if not is_show_all_mode or not effect_initialized:
			_initialize_show_all_mode(char_fx.elapsed_time)
		
		# Asegurar que el carácter tiene tiempo de inicio
		if not char_start_times.has(char_index):
			char_start_times[char_index] = show_all_start_time
		
		var char_time: float = char_fx.elapsed_time - char_start_times[char_index]
		
		# Protección contra tiempos negativos
		if char_time < 0:
			char_start_times[char_index] = char_fx.elapsed_time
			char_time = 0.0
		
		var alpha = clamp(char_time / fade_duration, 0.0, 1.0)
		char_fx.color.a = alpha
		
		return true
	
	# Modo normal
	is_show_all_mode = false
	
	if visible_characters <= 1 and char_start_times:
		char_start_times.clear()
		
	if char_index >= visible_characters:
		return false
	
	if char_index > current_index:
		if char_index == 0:
			char_start_times.clear()
		current_index = char_index
	
	if not char_start_times.has(char_index):
		char_start_times[char_index] = char_fx.elapsed_time
	
	var char_time: float = char_fx.elapsed_time - char_start_times[char_index]
	
	# Protección contra tiempos negativos
	if char_time < 0:
		char_start_times[char_index] = char_fx.elapsed_time
		char_time = 0.0
	
	var alpha = clamp(char_time / fade_duration, 0.0, 1.0)
	char_fx.color.a = alpha
	
	return true

func _initialize_show_all_mode(current_time: float):
	is_show_all_mode = true
	show_all_start_time = current_time
	char_start_times.clear()
	effect_initialized = true
	last_visible_characters = -1

func _reset_effect():
	char_start_times.clear()
	current_index = -1
	is_show_all_mode = false
	show_all_start_time = 0.0
	last_visible_characters = 0
