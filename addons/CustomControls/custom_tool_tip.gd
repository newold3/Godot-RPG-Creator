extends PanelContainer


var title: String
var contents: String


func _ready() -> void:
	var font = get_theme_default_font()
	var font_size = get_theme_default_font_size()
	var s1 = font.get_multiline_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var s2 = font.get_multiline_string_size(contents, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	custom_minimum_size = Vector2(
		s1.x + s2.x,
		s1.y + s2.y
	)
	contents = contents.replace("\\n", "\n")
	%Title.text = title
	%Contents.text = contents
	
	size = custom_minimum_size + Vector2(16, 16)
