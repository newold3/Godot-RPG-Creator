@tool
extends RichTextEffect
class_name RichTextUwU


# Syntax: [uwu][/uwu]
var bbcode = "uwu"

var r = GlyphConverter.ord("r")
var R = GlyphConverter.ord("R")
var l = GlyphConverter.ord("l")
var L = GlyphConverter.ord("L")

var w = GlyphConverter.ord("w")
var W = GlyphConverter.ord("W")

func _process_custom_fx(char_fx):
	var this_char = GlyphConverter.glyph_index_to_char(char_fx)
	match this_char:
		r, l: char_fx.glyph_index = GlyphConverter.char_to_glyph_index(char_fx.font, w)
		R, L: char_fx.glyph_index = GlyphConverter.char_to_glyph_index(char_fx.font, W)
	return true
