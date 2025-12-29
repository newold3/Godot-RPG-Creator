extends Control
class_name EquipItemLabel

var icon_texture: Texture2D
var item_name: String = ""
var current_value: int = 0
var new_value: int = 0
var use_percent: bool = false

@export var increase_color: Color = Color.GREEN
@export var decrease_color: Color = Color.RED
@export var no_change_color: Color = Color.WHITE
@export var text_color: Color = Color.WHITE


@export var arrow_symbol: String = " → "
@export var margin_left: int = 5
@export var margin_right: int = 5
@export var margin_vertical: int = 2
@export var icon_size: Vector2 = Vector2(16, 16)
@export var font_size: int = 14
@export var spacing: int = 5
@export var line_stylebox: StyleBox
@export var line_height: int = 2

@export var show_comparison: bool = true : set = set_show_comparison

@export var custom_font: Font





func _ready() -> void:
	resized.connect(_on_resized)


func _on_resized() -> void:
	queue_redraw()


func setup_label(p_icon: Texture2D, p_name: String, p_current: int, p_new_val: int, p_use_percent: bool) -> void:
	icon_texture = p_icon
	item_name = p_name
	current_value = p_current
	new_value = p_new_val
	use_percent = p_use_percent
	custom_minimum_size = get_calculated_minimum_size()
	queue_redraw()


func update_values(current: int, new_val: int) -> void:
	current_value = current
	new_value = new_val
	queue_redraw()


func set_show_comparison(show: bool) -> void:
	show_comparison = show
	queue_redraw()


func _draw() -> void:
	var font: Font = custom_font if custom_font else ThemeDB.fallback_font
	var current_x: float = margin_left
	var content_height: float = get_content_height()
	var y_center: float = margin_vertical + content_height * 0.5

	if icon_texture:
		var icon_rect := Rect2(
			Vector2(current_x, y_center - icon_size.y * 0.5),
			icon_size
		)
		draw_texture_rect(icon_texture, icon_rect, false)
		current_x += icon_size.x + spacing

	if item_name != "":
		var text_pos := Vector2(current_x, y_center + font_size * 0.3)
		draw_string(font, text_pos, item_name, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, text_color)

		var text_width: float = font.get_string_size(item_name, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		current_x += text_width + spacing

	var value1 = GameManager.get_number_formatted(current_value, 0, "", ("" if not use_percent and not show_comparison else "%"))
	var value2 = GameManager.get_number_formatted(new_value, 0, "", ("" if not use_percent else "%"))
	var values_width: float = font.get_string_size(value1, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var new_value_text: String = str(new_value) + ("" if not use_percent else "%")

	if show_comparison:
		var arrow_width: float = font.get_string_size(arrow_symbol, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		var new_value_width: float = font.get_string_size(new_value_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		values_width += arrow_width + new_value_width

	var values_start_x: float = size.x - margin_right - values_width

	if values_start_x < current_x:
		values_start_x = current_x

	var current_value_pos := Vector2(values_start_x, y_center + font_size * 0.3)
	draw_string(font, current_value_pos, value1, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, text_color)

	if show_comparison:
		values_start_x += font.get_string_size(value1, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x

		var arrow_pos := Vector2(values_start_x, y_center + font_size * 0.3)
		draw_string(font, arrow_pos, arrow_symbol, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, text_color)

		values_start_x += font.get_string_size(arrow_symbol, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x

		var new_value_color: Color = get_value_color()
		var new_value_pos := Vector2(values_start_x, y_center + font_size * 0.3)
		draw_string(font, new_value_pos, new_value_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, new_value_color)

	if line_stylebox:
		var line_y: float = margin_vertical + content_height + spacing
		var line_rect := Rect2(0, line_y, size.x, line_height)
		line_stylebox.draw(get_canvas_item(), line_rect)


func get_value_color() -> Color:
	if new_value > current_value:
		return increase_color
	elif new_value < current_value:
		return decrease_color
	else:
		return no_change_color


func setup_stat_label(stat_name: String, current_val: int, new_val: int, icon: Texture2D = null, use_percent: bool = false) -> void:
	setup_label(icon, stat_name, current_val, new_val, use_percent)


func show_current_only() -> void:
	set_show_comparison(false)


func show_full_comparison() -> void:
	set_show_comparison(true)


func get_content_height() -> float:
	var font: Font = custom_font if custom_font else ThemeDB.fallback_font
	var text_height: float = font_size
	var icon_height: float = icon_size.y if icon_texture else 0
	return max(text_height, icon_height)


func get_calculated_minimum_size() -> Vector2:
	var font: Font = custom_font if custom_font else ThemeDB.fallback_font
	var min_width: float = margin_left + margin_right
	var content_height: float = get_content_height()
	var min_height: float = margin_vertical * 2 + content_height

	if line_stylebox:
		min_height += spacing + line_height

	if icon_texture:
		min_width += icon_size.x + spacing

	if item_name != "":
		min_width += font.get_string_size(item_name, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + spacing

	var values_text: String = str(current_value)
	if show_comparison:
		values_text += arrow_symbol + str(new_value)

	min_width += font.get_string_size(values_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x

	return Vector2(min_width, min_height)


func get_minimum_size() -> Vector2:
	return get_calculated_minimum_size()
