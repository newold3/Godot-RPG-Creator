@tool
extends RichTextEffectTransitionBase


# Syntax: [word][/word]
var bbcode = "word"


var SPLITTERS = [GlyphConverter.ord(" "), GlyphConverter.ord("."), GlyphConverter.ord(",")]


var _index = 0
var _last = 999


func _process_custom_fx(char_fx):
	var as_char = GlyphConverter.glyph_index_to_char(char_fx)
	if char_fx.range.x < _last or as_char in SPLITTERS:
		_index = char_fx.range.x
	
	_last = char_fx.range.x
	
	var tween_data = get_tween_data()
	if not tween_data: return
	
	var t = 1.0 - tween_data.get_t(_index, true, char_fx.env.get("length", 8.0))
	char_fx.color.a *= t
	return true
