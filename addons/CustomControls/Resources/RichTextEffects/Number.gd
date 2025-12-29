@tool
extends RichTextEffect
class_name RichTextNumber

# Syntax: [number color][/number]
var bbcode = "number"


var COMMA = GlyphConverter.ord(",")
var SPACE = GlyphConverter.ord(" ")
var PERIOD = GlyphConverter.ord(".")
var ZERO = GlyphConverter.ord("0")
var NINE = GlyphConverter.ord("9")

var _last_char_was_number:bool = false
var _last_word_was_number:bool = false
	
func get_color(s) -> Color:
	if s is Color: return s
	elif s[0] == '#': return Color(s)
	else: return Color.from_string(s, Color.BLACK)


func _process_custom_fx(char_fx):
	var number_color:Color = get_color(char_fx.env.get("color", Color.YELLOW))
	var space_as_glyph_index = GlyphConverter.char_to_glyph_index(char_fx.font, SPACE)
	var period_as_glyph_index = GlyphConverter.char_to_glyph_index(char_fx.font, PERIOD)
	var zero_as_glyph_index = GlyphConverter.char_to_glyph_index(char_fx.font, ZERO)
	var nine_as_glyph_index = GlyphConverter.char_to_glyph_index(char_fx.font, NINE)
	var comma_as_glyph_index = GlyphConverter.char_to_glyph_index(char_fx.font, COMMA)
	
	# Reset on first character.
	if char_fx.relative_index == 0:
		_last_char_was_number = false
		_last_word_was_number = false
	
	# If the following is a word, and it came after a number, we'll colorize it.
	if char_fx.glyph_index == space_as_glyph_index:
		if _last_char_was_number:
			_last_word_was_number = true
		else:
			_last_word_was_number = false
	
	# Colorize characters after a number, except for the period.
	if _last_word_was_number and char_fx.glyph_index != period_as_glyph_index:
		char_fx.color = number_color
	# If character is a number, color it.
	if char_fx.glyph_index >= zero_as_glyph_index and char_fx.glyph_index <= nine_as_glyph_index:
		char_fx.color = number_color
		_last_char_was_number = true
	# Colorize trailing commas and periods.
	elif _last_char_was_number and (char_fx.glyph_index == comma_as_glyph_index):
		char_fx.color = number_color
		_last_char_was_number = false
	else:
		_last_char_was_number = false
	return true
