@tool
class_name RichTextEffectTransitionConsole
extends RichTextEffectTransitionBase

var bbcode = "console"
var last_char = -1
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
	var effect_duration = 1.5
	
	var cursor = GlyphConverter.ord(char_fx.env.get("cursor", "┃"))
	var base_color = char_fx.color
	var color = char_fx.env.get("color", base_color)
	if !color is Color:
		color = Color(color)
	
	var cursor_as_glyph_index = GlyphConverter.char_to_glyph_index(char_fx.font, cursor)
	var space_as_glyph_index = GlyphConverter.char_to_glyph_index(char_fx.font, SPACE)
	
	if visible_characters == -1 and last_visible_characters != -1:
		is_show_all_mode = true
		show_all_start_time = char_fx.elapsed_time
		char_start_times.clear()
		effect_initialized = true
		last_char = -1
	elif visible_characters != -1:
		is_show_all_mode = false
		effect_initialized = false
	
	last_visible_characters = visible_characters
	
	if visible_characters == -1:
		if not char_start_times.has(char_index):
			var char_delay = char_index * 0.05
			char_start_times[char_index] = show_all_start_time + char_delay
		
		var char_time: float = char_fx.elapsed_time - char_start_times[char_index]
		
		if char_time < 0:
			char_fx.color.a = 0.0
			return true
		
		var t = clamp(char_time / 0.1, 0.0, 1.0)
		
		var current_last_char = -1
		for i in range(1000):
			if char_start_times.has(i):
				var other_char_time = char_fx.elapsed_time - char_start_times[i]
				if other_char_time >= 0:
					current_last_char = i
		
		if t >= 1.0:
			char_fx.color.a = 1.0
			
			if char_fx.range.x == current_last_char and sin(char_fx.elapsed_time * 16.0) > 0.0:
				char_fx.glyph_index = cursor_as_glyph_index
				char_fx.color = color
		else:
			char_fx.glyph_index = cursor_as_glyph_index
			char_fx.color = color
			char_fx.color.a = t
		
		return true
	
	var tween_data = get_tween_data()
	if not tween_data: 
		return false
	
	if tween_data.reverse:
		char_fx.offset.y -= 32 * (1.0 - tween_data.time)
		char_fx.color.a *= pow(tween_data.time, 8.0)
	else:
		if tween_data.time == 1.0:
			if char_fx.range.x == last_char and sin(char_fx.elapsed_time * 16.0) > 0.0:
				char_fx.glyph_index = cursor_as_glyph_index
				char_fx.color = color
		else:
			if char_fx.relative_index == 0:
				last_char = -1
			var t1 = tween_data.get_t(char_fx.range.x, false, char_fx.env.get("length", 1.0))
			var t2 = tween_data.get_t(char_fx.range.x+1, false, char_fx.env.get("length", 1.0))
			if t1 > 0.0 and char_fx.glyph_index != space_as_glyph_index:
				if t1 != t2:
					char_fx.glyph_index = cursor_as_glyph_index
					char_fx.color = color
				else:
					char_fx.glyph_index = space_as_glyph_index
			
			if char_fx.range.x > last_char:
				last_char = char_fx.range.x
	
	return true
