@tool
class_name RichTextEffectTransitionEmber
extends RichTextEffectTransitionBase

var bbcode = "embers"
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
		
		_apply_ember_effect(char_fx, char_time, effect_duration)
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
	
	_apply_ember_effect(char_fx, char_time, effect_duration)
	return true

func _apply_ember_effect(char_fx: CharFXTransform, char_time: float, duration: float):
	var t = clamp(char_time / duration, 0.0, 1.0)
	
	if t >= 1.0:
		return
	
	var ember = GlyphConverter.ord(char_fx.env.get("ember", "."))
	var ember_as_glyph_index = GlyphConverter.char_to_glyph_index(char_fx.font, ember)
	var scale = char_fx.env.get("scale", 16.0)
	var clr1 = char_fx.env.get("color", Color.RED)
	if !clr1 is Color:
		clr1 = Color(clr1)
	var clr2 = clr1
	clr2.a = 0.0
	
	var r = get_rand(char_fx) * PI * 2.0
	
	var ember_phase = 0.7
	if t < ember_phase:
		char_fx.glyph_index = ember_as_glyph_index
		char_fx.offset -= Vector2(16, 8)
		var ember_t = t / ember_phase
		char_fx.color = lerp(clr1, clr2, ember_t)
		char_fx.offset += Vector2(cos(r) * scale * ember_t, sin(r) * scale * ember_t)
	else:
		var fade_t = (t - ember_phase) / (1.0 - ember_phase)
		char_fx.color.a = fade_t
