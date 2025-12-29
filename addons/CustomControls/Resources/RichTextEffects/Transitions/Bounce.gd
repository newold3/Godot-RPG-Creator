@tool
class_name RichTextEffectTransitionBounce
extends RichTextEffectTransitionBase

var bbcode = "bounce"
var char_start_times = {}
var current_index = -1
var is_show_all_mode = false
var show_all_start_time = 0.0
var last_visible_characters = 0
var effect_initialized = false

func bounce(t, wave=8.0) -> float:
	return sin(13.0 * HALFPI * t) * pow(2.0, wave * (t - 1.0))

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
	var effect_duration = 0.8
	
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
		
		var t = clamp(char_time / effect_duration, 0.0, 1.0)
		var intensity = max(0.1, 8.0 - char_fx.env.get("intensity", 8.0))
		
		char_fx.offset.y = bounce(t, intensity) * 8.0
		
		char_fx.color.a = t
		
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
	
	var t = clamp(char_time / effect_duration, 0.0, 1.0)
	var intensity = max(0.1, 8.0 - char_fx.env.get("intensity", 8.0))
	
	char_fx.offset.y = bounce(t, intensity) * 8.0
	
	char_fx.color.a = t
	
	return true
