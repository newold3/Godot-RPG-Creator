@tool
extends Control
class_name EquipItemButton

enum ButtonState {
	NORMAL,
	HOVER,
	SELECTED
}

var slot_icon: Texture2D
var slot_name: String = ""
var item_icon: Texture2D
var item_name: String = ""

@export var text_color: Color = Color.WHITE
@export var slot_text_color: Color = Color.GRAY
@export var item_text_color: Color = Color.WHITE
@export var outline_color: Color = Color.BLACK

@export var outline_size: int = 6

@export var margin_left: int = 5
@export var margin_right: int = 5
@export var margin_vertical: int = 2
@export var icon_size: Vector2 = Vector2(16, 16)
@export var font_size: int = 14
@export_range(0, 100, 1) var slot_section_percent: int = 35
@export var slot_item_spacing: int = 20

@export var normal_stylebox: StyleBox
@export var hover_stylebox: StyleBox
@export var selected_stylebox: StyleBox
@export var disabled_stylebox: StyleBox
@export var hover_disabled_stylebox: StyleBox
@export var expand_background: int = 0
@export var background_margin_left: int = 0
@export var background_margin_right: int = 0

@export var line_stylebox: StyleBox
@export var line_height: int = 2
@export var line_margin: int = 4

@export var custom_font: Font

@export var disabled: bool : set = set_disabled
@export var is_toggle_button: bool = false : set = set_toggle_mode
@export var is_untoggleable : bool = true
@export var button_group: EquipItemButtonGroup

@export var update_all: bool :
	set(value):
		queue_redraw()

var current_state: ButtonState = ButtonState.NORMAL
var is_selected: bool = false
var mouse_inside: bool = false


signal pressed
signal toggled(pressed: bool)


func _ready() -> void:
	visibility_changed.connect(_on_viibility_changed)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	focus_entered.connect(queue_redraw)
	#toggled.connect(_on_toggled)
	#focus_exited.connect(_on_focus_exited)

	if button_group:
		button_group.add_button(self)


func _on_viibility_changed() -> void:
	if visible and button_group:
		button_group.add_button(self)


func _on_toggled(value: bool, _button: EquipItemButton) -> void:
	if value and button_group:
		var buttons = button_group.get_buttons()
		for button in buttons:
			if button != self and button.is_selected:
				button.set_selected(false)


func _on_focus_exited() -> void:
	if button_group:
		var button_selected = button_group.get_selected_button()
		if button_selected:
			var buttons = button_group.get_buttons()
			for button in buttons:
				button.set_selected(button == button_selected)
			


func _gui_input(event: InputEvent) -> void:
	if disabled: return
	
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			current_state = ButtonState.SELECTED
			queue_redraw()
		else:
			if mouse_inside:
				if is_toggle_button and (not is_selected or is_untoggleable):
					is_selected = !is_selected
					toggled.emit(is_selected, self)
				pressed.emit()

				current_state = ButtonState.HOVER if mouse_inside else ButtonState.NORMAL
				if is_selected:
					current_state = ButtonState.SELECTED
			else:
				current_state = ButtonState.NORMAL
			queue_redraw()


func _on_mouse_entered() -> void:
	mouse_inside = true
	if current_state != ButtonState.SELECTED and not is_selected:
		current_state = ButtonState.HOVER
		set_selected(true)
		queue_redraw()


func _on_mouse_exited() -> void:
	mouse_inside = false
	if current_state != ButtonState.SELECTED:
		current_state = ButtonState.SELECTED if is_selected else ButtonState.NORMAL
		queue_redraw()


func setup_button(slot_icon_tex: Texture, slot_col: Color, slot_nm: String, item_icon_tex: Variant, item_col: Color, item_nm: String) -> void:
	slot_icon = slot_icon_tex
	slot_text_color = slot_col
	slot_name = slot_nm
	item_icon = item_icon_tex
	item_text_color = item_col
	item_name = item_nm
	
	#if slot_icon is SpritesetAnimationTexture:
		#slot_icon.frame_changed.connect(queue_redraw)
	#elif item_icon is SpritesetAnimationTexture:
		#item_icon.frame_changed.connect(queue_redraw)

	custom_minimum_size = get_calculated_minimum_size()
	queue_redraw()


func setup_item(item_icon_tex: Variant, item_col: Color, item_nm: String) -> void:
	setup_button(slot_icon, slot_text_color, slot_name, item_icon_tex, item_col, item_nm)


func set_toggle_mode(toggle: bool) -> void:
	is_toggle_button = toggle


func set_disabled(value: bool) -> void:
	disabled = value
	if !value:
		current_state = ButtonState.SELECTED if is_selected else ButtonState.NORMAL
	queue_redraw()


func set_selected(selected: bool) -> void:
	if not is_inside_tree(): return
	if selected: grab_focus()
	is_selected = selected
	current_state = ButtonState.SELECTED if selected else ButtonState.NORMAL

	await get_tree().process_frame
	
	if is_toggle_button:
		toggled.emit(selected)
	queue_redraw()


func get_content_rect() -> Rect2:
	var content_height := get_content_height()
	return Rect2(
		Vector2(background_margin_left, 0),
		Vector2(size.x - background_margin_left - background_margin_right, content_height + margin_vertical * 2)
	)


func get_line_rect() -> Rect2:
	var y := size.y - line_height
	var width := size.x - background_margin_left - background_margin_right
	return Rect2(background_margin_left, y, width, line_height)


func _draw() -> void:
	var font := custom_font if custom_font else ThemeDB.fallback_font
	draw_button_background()

	var y_center := (size.y - get_total_line_height()) * 0.5

	var draw_origin_x := background_margin_left
	var draw_width := size.x - background_margin_left - background_margin_right
	var content_x := draw_origin_x + margin_left
	var content_width := draw_width - margin_left - margin_right

	var slot_width := content_width * (slot_section_percent / 100.0)

	# SLOT
	var current_x := content_x
	if slot_icon:
		var icon_rect := Rect2(Vector2(current_x, y_center - icon_size.y * 0.5), icon_size)
		draw_texture_rect(slot_icon, icon_rect, false, slot_text_color)
		current_x += icon_size.x + 4

	var max_slot_text_width := slot_width - (current_x - content_x)
	var slot_text := trim_text_to_width(slot_name, font, max_slot_text_width, ": ")

	if slot_name != "":
		var text_pos := Vector2(current_x, y_center + font_size * 0.3)
		draw_string_outline(font, text_pos, slot_text, HORIZONTAL_ALIGNMENT_LEFT, slot_width, font_size, outline_size,  outline_color)
		draw_string(font, text_pos, slot_text, HORIZONTAL_ALIGNMENT_LEFT, slot_width, font_size, slot_text_color)

	# ITEM
	current_x = content_x + slot_width

	if item_icon:
		var icon_rect := Rect2(Vector2(current_x, y_center - icon_size.y * 0.5), icon_size)
		draw_texture_rect(item_icon, icon_rect, false)
		current_x += icon_size.x + 4

	var item_text_max_width := content_x + content_width - current_x
	if item_name != "":
		var item_text := trim_text_to_width(item_name, font, item_text_max_width)
		var text_pos := Vector2(current_x, y_center + font_size * 0.3)
		draw_string_outline(font, text_pos, item_text, HORIZONTAL_ALIGNMENT_LEFT, item_text_max_width, font_size, outline_size,  outline_color)
		draw_string(font, text_pos, item_text, HORIZONTAL_ALIGNMENT_LEFT, item_text_max_width, font_size, item_text_color)

	draw_bottom_line()


func trim_text_to_width(text: String, font: Font, max_width: float, suffix: String = "") -> String:
	var full_text := text + suffix
	var full_width := font.get_string_size(full_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x

	# Si texto completo + sufijo cabe, devolver directamente
	if full_width <= max_width:
		return full_text

	# Si no cabe, recortar texto para que quepa texto recortado + "…" + sufijo
	var trimmed := text
	var ellipsis := "…"

	# Reducir texto hasta que texto recortado + ellipsis + sufijo quepan
	while trimmed.length() > 0:
		trimmed = trimmed.substr(0, trimmed.length() - 1)
		var trial_text = trimmed.strip_edges() + ellipsis + suffix
		var trial_width = font.get_string_size(trial_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		if trial_width <= max_width:
			return trial_text

	# Si ni siquiera "…"+suffix cabe, devolver solo sufijo recortado para que quepa (opcional)
	var fallback := suffix
	while fallback.length() > 0 and font.get_string_size(fallback, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > max_width:
		fallback = fallback.substr(0, fallback.length() - 1)
	return fallback


func draw_button_background() -> void:
	var bg_x := background_margin_left
	var bg_width := size.x - background_margin_left - background_margin_right
	var bg_height := size.y - get_total_line_height()
	var bg_rect := Rect2(bg_x, 0, bg_width, bg_height)

	var stylebox_to_use: StyleBox
	if disabled:
		if current_state == ButtonState.HOVER:
			stylebox_to_use = hover_disabled_stylebox
		else:
			stylebox_to_use = disabled_stylebox
	else:
		match current_state:
			ButtonState.NORMAL: stylebox_to_use = normal_stylebox
			ButtonState.HOVER: stylebox_to_use = hover_stylebox
			ButtonState.SELECTED: stylebox_to_use = selected_stylebox

	if stylebox_to_use:
		draw_style_box(stylebox_to_use, bg_rect)


func draw_bottom_line() -> void:
	if line_stylebox and line_height > 0:
		#var line_y := size.y - expand_background
		#var line_rect := Rect2(0, line_y, size.x, line_height)
		var line_rect = get_line_rect()
		draw_style_box(line_stylebox, line_rect)


func get_content_height() -> float:
	var text_height: float = font_size
	var icon_height: float = icon_size.y if (slot_icon or item_icon) else 0.0
	return max(text_height, icon_height)


func get_calculated_minimum_size() -> Vector2:
	var font := custom_font if custom_font else ThemeDB.fallback_font
	var width := margin_left + margin_right
	var height := margin_vertical * 2 + get_content_height() + expand_background * 2

	if slot_icon:
		width += icon_size.x + slot_section_percent

	if slot_name != "":
		width += font.get_string_size(slot_name, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + slot_item_spacing

	if item_icon:
		width += icon_size.x + slot_section_percent

	if item_name != "":
		width += font.get_string_size(item_name, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x

	if line_stylebox and line_height > 0:
		height += line_margin + line_height

	return Vector2(width, height)


func get_total_line_height() -> float:
	return (line_margin + line_height) if line_stylebox and line_height > 0 else 0


func get_minimum_size() -> Vector2:
	return get_calculated_minimum_size()
