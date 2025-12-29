@tool
class_name RichTextEffectTransitionRedacted
extends RichTextEffectTransitionBase

var bbcode = "redacted"
var BLOCK = GlyphConverter.ord("█")
var MID_BLOCK = GlyphConverter.ord("▓")
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
	
	var block_as_glyph_index = GlyphConverter.char_to_glyph_index(char_fx.font, BLOCK)
	var mid_block_as_glyph_index = GlyphConverter.char_to_glyph_index(char_fx.font, MID_BLOCK)
	var space_as_glyph_index = GlyphConverter.char_to_glyph_index(char_fx.font, SPACE)
	
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
			var char_delay = char_index * 0.08
			char_start_times[char_index] = show_all_start_time + char_delay
		
		var char_time: float = char_fx.elapsed_time - char_start_times[char_index]
		
		if char_time < 0:
			_apply_redacted_block(char_fx, 0.0)
			return true
		
		var t = clamp(char_time / effect_duration, 0.0, 1.0)
		_apply_redacted_effect(char_fx, t, char_index, block_as_glyph_index, mid_block_as_glyph_index, space_as_glyph_index)
		return true
	
	var tween_data = get_tween_data()
	if not tween_data: 
		return false
	
	var t1 = tween_data.get_t(char_fx.range.x, false, char_fx.env.get("length", 8.0))
	var t2 = tween_data.get_t(char_fx.range.x+1, false, char_fx.env.get("length", 8.0))
	
	if tween_data.reverse:
		char_fx.color.a = 1.0 - t1
		if t1 != t2:
			char_fx.glyph_index = mid_block_as_glyph_index
	else:
		if t1 > 0.0 and (char_fx.glyph_index != space_as_glyph_index or char_fx.relative_index % 2 == 0):
			var freq:float = char_fx.env.get("freq", 1.0)
			var scale:float = char_fx.env.get("scale", 1.0)
			char_fx.glyph_index = mid_block_as_glyph_index if t1 != t2 else block_as_glyph_index
			char_fx.color = Color.BLACK
			char_fx.offset.y -= sin(char_fx.range.x * freq) * scale
	
	return true

func _apply_redacted_effect(char_fx: CharFXTransform, t: float, char_index: int, block_glyph: int, mid_block_glyph: int, space_glyph: int):
	var freq: float = char_fx.env.get("freq", 1.0)
	var scale: float = char_fx.env.get("scale", 1.0)
	
	if t >= 1.0:
		return
	elif t >= 0.7:
		var fade_t = (t - 0.7) / 0.3
		char_fx.color.a = fade_t
	elif t >= 0.3:
		char_fx.glyph_index = mid_block_glyph
		char_fx.color = Color.BLACK
		char_fx.offset.y -= sin(char_index * freq) * scale
		if sin(char_fx.elapsed_time * 8.0 + char_index) > 0.5:
			char_fx.color.a = 0.7
	else:
		_apply_redacted_block(char_fx, t)

func _apply_redacted_block(char_fx: CharFXTransform, t: float):
	var block_as_glyph_index = GlyphConverter.char_to_glyph_index(char_fx.font, BLOCK)
	var space_as_glyph_index = GlyphConverter.char_to_glyph_index(char_fx.font, SPACE)
	var freq: float = char_fx.env.get("freq", 1.0)
	var scale: float = char_fx.env.get("scale", 1.0)
	
	if char_fx.glyph_index != space_as_glyph_index or char_fx.relative_index % 2 == 0:
		char_fx.glyph_index = block_as_glyph_index
		char_fx.color = Color.BLACK
		char_fx.offset.y -= sin(char_fx.range.x * freq) * scale
