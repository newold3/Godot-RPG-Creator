@tool
extends RichTextEffect
class_name RichTextWoo


# Syntax: [woo scale=1.0 freq=8.0][/woo]
var bbcode = "woo"

func _process_custom_fx(char_fx):
	var scale:float = char_fx.env.get("scale", 1.0)
	var freq:float = char_fx.env.get("freq", 8.0)
	if sin(char_fx.elapsed_time * freq + char_fx.range.x * scale) < 0:
		if char_fx.glyph_index >= GlyphConverter.char_to_glyph_index(char_fx.font, 65) and char_fx.glyph_index <= GlyphConverter.char_to_glyph_index(char_fx.font, 90):
			char_fx.glyph_index += 32
		elif char_fx.glyph_index >= GlyphConverter.char_to_glyph_index(char_fx.font, 97) and char_fx.glyph_index <= GlyphConverter.char_to_glyph_index(char_fx.font, 122):
			char_fx.glyph_index -= 32
	return true
