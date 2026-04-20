@tool
extends Button

var _base_text: String = "Change Extra Configs"
var _mode_text: String = ""
var _mode_color: Color = Color.WHITE
var _is_hovering: bool = false
var _selection_color: Color = Color("#00aaff")
var _margin_side: int = 48


func _ready() -> void:
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	text = ""


## Actualiza la información del modo y solicita el redibujado del botón
func _update_extra_config_label(current_page: RPGEventPage) -> void:
	var options = current_page.options
	var is_pressure = current_page.condition.use_pressure
	
	_mode_text = ""
	_mode_color = Color.WHITE
	
	if options.event_type == 1:
		_mode_text = "(LIFTABLE MODE Enabled)"
		_mode_color = Color("#a0fec3")
	elif options.event_type == 2:
		_mode_text = "(MOVEABLE MODE Enabled)"
		_mode_color = Color("#ff9500")
	elif is_pressure:
		_mode_text = "(PRESSURE MODE Enabled)"
		_mode_color = Color("#fce9a0")
		
	queue_redraw()


func _draw() -> void:
	if not _base_text: return
	
	var font = get_theme_font("font")
	var font_size = get_theme_font_size("font_size")
	var vertical_pos = (size.y + font.get_ascent(font_size) - font.get_descent(font_size)) / 2
	
	var mode_width = font.get_string_size(_mode_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var right_pos = size.x - mode_width - _margin_side
	
	if _is_hovering:
		draw_string(font, Vector2(_margin_side, vertical_pos), _base_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, _selection_color)
		draw_string(font, Vector2(right_pos, vertical_pos), _mode_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, _selection_color)
	else:
		draw_string(font, Vector2(_margin_side, vertical_pos), _base_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)
		draw_string(font, Vector2(right_pos, vertical_pos), _mode_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, _mode_color)


func _on_mouse_entered() -> void:
	_is_hovering = true
	queue_redraw()


func _on_mouse_exited() -> void:
	_is_hovering = false
	queue_redraw()
