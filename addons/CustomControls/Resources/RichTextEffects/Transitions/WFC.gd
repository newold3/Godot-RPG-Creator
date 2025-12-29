@tool
class_name RichTextEffectTransitionWFC
extends RichTextEffectTransitionBase

var bbcode = "wfc"
var ONE = GlyphConverter.ord("1")
var ZERO = GlyphConverter.ord("0")
var char_start_times = {}
var current_index = -1
var is_show_all_mode = false
var show_all_start_time = 0.0
var last_visible_characters = 0
var effect_initialized = false

func _force_reset():
	char_start_times.clear()
	current_index = -1
	is_show_all_mode = false
	show_all_start_time = 0.0
	last_visible_characters = 0
	effect_initialized = false

func _process_custom_fx(char_fx: CharFXTransform) -> bool:
	if char_fx.elapsed_time < 0.05:
		_force_reset()
		
	var char_index = char_fx.range.x
	var visible_characters = get_visible_characters()
	var effect_duration = 1.2
	
	if visible_characters == -1 and last_visible_characters != -1:
		is_show_all_mode = true
		show_all_start_time = char_fx.elapsed_time
		char_start_times.clear()
		effect_initialized = true
	elif visible_characters != -1:
		is_show_all_mode = false
		effect_initialized = false
	
	last_visible_characters = visible_characters
	
	if visible_characters == -1:
		if not char_start_times.has(char_index):
			char_start_times[char_index] = show_all_start_time
		
		var char_time: float = char_fx.elapsed_time - char_start_times[char_index]
		
		if char_time < 0:
			char_start_times[char_index] = char_fx.elapsed_time
			char_time = 0.0
		
		_apply_wfc_effect(char_fx, char_time, effect_duration)
		return true
	
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
	
	if char_time < 0:
		char_start_times[char_index] = char_fx.elapsed_time
		char_time = 0.0
	
	_apply_wfc_effect(char_fx, char_time, effect_duration)
	return true

func _apply_wfc_effect(char_fx: CharFXTransform, char_time: float, duration: float):
	var zero_as_glyph_index = GlyphConverter.char_to_glyph_index(char_fx.font, ZERO)
	var one_as_glyph_index = GlyphConverter.char_to_glyph_index(char_fx.font, ONE)
	var space_as_glyph_index = GlyphConverter.char_to_glyph_index(char_fx.font, SPACE)
	
	var raw_t = clamp(char_time / duration, 0.0, 1.0)
	
	var binary_phase = 0.7
	
	if raw_t < binary_phase and char_fx.glyph_index != space_as_glyph_index:
		char_fx.glyph_index = zero_as_glyph_index if sin(get_rand_time(char_fx, 16.0)) > 0.0 else one_as_glyph_index
		char_fx.color.r = 0.8
		char_fx.color.g = 0.8
		char_fx.color.b = 0.8
		char_fx.color.a = 0.6
	else:
		var fade_t = (raw_t - binary_phase) / (1.0 - binary_phase)
		char_fx.color.a = fade_t
