@tool
extends RichTextEffect
class_name RichTextHeart


# Syntax: [heart scale=1.0 freq=8.0][/heart]
var bbcode = "heart"

var HEART = GlyphConverter.ord("♡")
var TO_CHANGE = [GlyphConverter.ord("o"), GlyphConverter.ord("O"), GlyphConverter.ord("a"), GlyphConverter.ord("A")]


func _process_custom_fx(char_fx):
	var scale:float = char_fx.env.get("scale", 16.0)
	var freq:float = char_fx.env.get("freq", 2.0)

	var x =  char_fx.range.x / scale - char_fx.elapsed_time * freq
	var t = abs(cos(x)) * max(0.0, smoothstep(0.712, 0.99, sin(x))) * 2.5;
	char_fx.color = lerp(char_fx.color, lerp(Color.BLUE, Color.RED, t), t)
	char_fx.offset.y -= t * 4.0
	
	var glyph_index_as_char = GlyphConverter.glyph_index_to_char(char_fx)
	if char_fx.offset.y < -1.0:
		if glyph_index_as_char in TO_CHANGE:
			var font = GlyphConverter.UNIFONT.get_rids()[0]
			char_fx.glyph_index = GlyphConverter.char_to_glyph_index(font, HEART)
	
	return true
