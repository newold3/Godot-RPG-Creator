@tool
extends RichTextEffect
class_name RichTextCuss


# Syntax: [cuss][/cuss]
var bbcode = "cuss"

var VOWELS = [GlyphConverter.ord("a"), GlyphConverter.ord("e"), GlyphConverter.ord("i"), GlyphConverter.ord("o"), GlyphConverter.ord("u"),
			  GlyphConverter.ord("A"), GlyphConverter.ord("E"), GlyphConverter.ord("I"), GlyphConverter.ord("O"), GlyphConverter.ord("U")]
var CHARS = [GlyphConverter.ord("&"), GlyphConverter.ord("$"), GlyphConverter.ord("!"), GlyphConverter.ord("@"), GlyphConverter.ord("*"), GlyphConverter.ord("#"), GlyphConverter.ord("%")]
var SPACE = GlyphConverter.ord(" ")

var _was_space = false

func _process_custom_fx(char_fx):
	var glyph_index_as_char = GlyphConverter.glyph_index_to_char(char_fx)
		
	if not _was_space and not char_fx.relative_index == 0 and not glyph_index_as_char == SPACE:
		var t = char_fx.elapsed_time + char_fx.glyph_index * 10.2 + char_fx.range.x * 2
		t *= 4.3
		if glyph_index_as_char in VOWELS or sin(t) > 0.0:
			char_fx.glyph_index = GlyphConverter.char_to_glyph_index(char_fx.font, CHARS[int(t) % len(CHARS)])
	
	_was_space = glyph_index_as_char == SPACE
	
	return true
