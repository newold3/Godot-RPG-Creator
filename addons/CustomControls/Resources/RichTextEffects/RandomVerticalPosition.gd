@tool
extends RichTextEffect
class_name RichRandomVerticalPosition

var bbcode = "randomypos"

func _process_custom_fx(char_fx: CharFXTransform):
	var min_offset_y = int(char_fx.env.get("min_offset_y", -1))
	var max_offset_y = int(char_fx.env.get("max_offset_y", 1))
	var fix_letters = char_fx.env.get("fix_letters", true)
	
	if max_offset_y < min_offset_y:
		var bak = min_offset_y
		min_offset_y = max_offset_y
		max_offset_y = bak

	var seed_value: int

	if fix_letters:
		seed_value = char_fx.glyph_index
	else:
		seed_value = char_fx.relative_index

	var value = int((seed_value * 1103515245 + 12345) & 0x7fffffff)

	var range_size = max_offset_y - min_offset_y + 1
	char_fx.offset.y = min_offset_y + (value % range_size)

	return true
