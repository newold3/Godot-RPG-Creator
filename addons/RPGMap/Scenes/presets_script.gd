@tool
extends PopupMenu

@export var main_node: Node
@export var remove_button: Control
@export var edit_button: Control
@export var button_right_padding: int = 15
@export var button_separation: int = 2
@export var button_size: int = 20


var _scroll_node: VScrollBar


func _ready() -> void:
	window_input.connect(_gui_input)
	visibility_changed.connect(_on_visibility_changed)


func _on_visibility_changed() -> void:
	if remove_button: remove_button.visible = false
	if edit_button: edit_button.visible = false
	
	var extra_width = (button_size * 2) + button_separation + button_right_padding

	if visible:
		size.x += extra_width
		if max_size.y > 0:
			size.y = min(size.y, max_size.y)
	else:
		size.x -= extra_width


func _gui_input(event: InputEvent) -> void:
	if remove_button:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
			set_input_as_handled()
			if remove_button.get_rect().has_point(get_mouse_position()):
				var index = get_focused_item()
				if index != -1:
					if main_node:
						main_node.set_meta("_remove_index", get_item_text(index))
			elif edit_button.get_rect().has_point(get_mouse_position()):
				var index = get_focused_item()
				if index != -1:
					if main_node:
						main_node.set_meta("_edit_index", get_item_text(index))
	if event is InputEventMouseMotion:
		_update_button_position()


func _get_item_height() -> int:
	var font = get_theme_font("font")
	var font_size = get_theme_font_size("font_size")
	
	var text_height = font.get_string_size(" ", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).y
	var v_separation = get_theme_constant("v_separation")
	return text_height + v_separation


func _get_panel_margin_top() -> int:
	var panel_style = get_theme_stylebox("panel")
	if panel_style:
		return panel_style.get_margin(SIDE_TOP)
	return 0


func _get_item_y(index: int) -> int:
	var item_height = _get_item_height()
	var margin_top = _get_panel_margin_top()
	return index * item_height + margin_top


func _update_button_position(select_new_index: bool = false) -> void:
	var index = get_focused_item()
	if index == -1:
		remove_button.visible = false
		edit_button.visible = false
		return
	
	if not _scroll_node:
		var found = find_child("_v_scroll", true, false)
		if found is VScrollBar:
			_scroll_node = found
			if not _scroll_node.value_changed.is_connected(_update_button_position):
				_scroll_node.value_changed.connect(_update_button_position.unbind(1).bind(true))
				
	var scroll_value = _scroll_node.value if _scroll_node else 0
	
	var item_y = _get_item_y(index)
	var item_height = _get_item_height()
	
	remove_button.position.x = size.x - remove_button.size.x - button_right_padding - edit_button.size.x - button_separation
	remove_button.position.y = item_y + (item_height - button_size) * 0.5 - scroll_value
	remove_button.visible = true
	
	edit_button.position.x = remove_button.position.x + remove_button.size.x + button_separation
	edit_button.position.y = remove_button.position.y
	edit_button.visible = true
	
	if select_new_index:
		scroll_to_item(index)
