@tool
extends RichTextEffect
class_name RichTextL33T

# Syntax: [l33t][/l33t]
var bbcode = "l33t"


var leet = {
	GlyphConverter.ord("L"): GlyphConverter.ord("1"),
	GlyphConverter.ord("l"): GlyphConverter.ord("1"),
	GlyphConverter.ord("I"): GlyphConverter.ord("1"),
	GlyphConverter.ord("i"): GlyphConverter.ord("1"),
	GlyphConverter.ord("E"): GlyphConverter.ord("3"),
	GlyphConverter.ord("e"): GlyphConverter.ord("3"),
	GlyphConverter.ord("T"): GlyphConverter.ord("7"),
	GlyphConverter.ord("t"): GlyphConverter.ord("7"),
	GlyphConverter.ord("S"): GlyphConverter.ord("5"),
	GlyphConverter.ord("s"): GlyphConverter.ord("5"),
	GlyphConverter.ord("A"): GlyphConverter.ord("4"),
	GlyphConverter.ord("a"): GlyphConverter.ord("4"),
	GlyphConverter.ord("O"): GlyphConverter.ord("0"),
	GlyphConverter.ord("o"): GlyphConverter.ord("0"),
}

func _process_custom_fx(char_fx):
	var glyph_index_as_char = GlyphConverter.glyph_index_to_char(char_fx)
	if glyph_index_as_char in leet:
		char_fx.glyph_index = GlyphConverter.char_to_glyph_index(char_fx.font, leet[glyph_index_as_char])
	return true
