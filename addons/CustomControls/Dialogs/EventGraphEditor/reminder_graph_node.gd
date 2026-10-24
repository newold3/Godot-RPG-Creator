@tool
class_name ReminderGraphNode
extends GraphNode

## Sticky Note / Reminder node for leaving developer notes on the graph canvas.
## Persisted in the map graph JSON configuration.

signal delete_requested(node: ReminderGraphNode)
signal reminder_modified(node: ReminderGraphNode)

var reminder_id: String = ""
var reminder_title: String = "📝 Recordatorio"
var reminder_text: String = ""
var reminder_color: Color = Color("#d69e2e") # Classic amber/yellow note

var title_edit: LineEdit
var color_btn: Button
var close_btn: Button
var text_edit: TextEdit

const PALETTE = [
	Color("#d69e2e"), # Warm Amber / Yellow
	Color("#319795"), # Mint / Teal
	Color("#3182ce"), # Soft Blue
	Color("#dd6b20"), # Coral / Orange
	Color("#805ad5"), # Lavender / Purple
	Color("#38a169")  # Soft Green
]


func _ready() -> void:
	resizable = true
	resize_request.connect(func(new_size: Vector2):
		size = new_size
		reminder_modified.emit(self)
	)
	_build_ui()


func setup_reminder(p_id: String, p_title: String, p_text: String, p_pos: Vector2, p_size: Vector2 = Vector2(240, 160), p_color: Color = Color("#d69e2e")) -> void:
	reminder_id = p_id
	reminder_title = p_title
	reminder_text = p_text
	position_offset = p_pos
	size = p_size
	reminder_color = p_color
	
	_build_ui()
	_apply_color_style()


func _build_ui() -> void:
	var existing_header = get_node_or_null("HeaderHBox")
	var existing_text = get_node_or_null("BodyTextEdit")
	
	if not existing_header or not existing_text:
		for child in get_children():
			remove_child(child)
			child.queue_free()
			
		title = ""
		custom_minimum_size = Vector2(220, 140)
		
		# Header Row
		var header_hbox = HBoxContainer.new()
		header_hbox.name = "HeaderHBox"
		header_hbox.add_theme_constant_override("separation", 6)
		
		title_edit = LineEdit.new()
		title_edit.name = "TitleEdit"
		title_edit.text = reminder_title
		title_edit.placeholder_text = "Título del recordatorio..."
		title_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		title_edit.flat = true
		title_edit.add_theme_font_size_override("font_size", 16)
		header_hbox.add_child(title_edit)
		
		color_btn = Button.new()
		color_btn.name = "ColorPaletteButton"
		color_btn.text = "🎨"
		color_btn.flat = true
		color_btn.tooltip_text = "[title]Cambiar Color de Nota[/title]\nCambia el color de este recordatorio."
		color_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		color_btn.focus_mode = Control.FOCUS_NONE
		header_hbox.add_child(color_btn)
		
		close_btn = Button.new()
		close_btn.name = "CloseButton"
		close_btn.text = "×"
		close_btn.flat = true
		close_btn.tooltip_text = "[title]Eliminar Recordatorio[/title]\nElimina esta nota del grafo."
		close_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		close_btn.focus_mode = Control.FOCUS_NONE
		header_hbox.add_child(close_btn)
		
		add_child(header_hbox)
		
		# Body TextEdit
		text_edit = TextEdit.new()
		text_edit.name = "BodyTextEdit"
		text_edit.text = reminder_text
		text_edit.placeholder_text = "Escribe aquí una nota o recordatorio..."
		text_edit.size_flags_vertical = Control.SIZE_EXPAND_FILL
		text_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
		text_edit.add_theme_font_size_override("font_size", 16)
		add_child(text_edit)
	else:
		title_edit = existing_header.get_node_or_null("TitleEdit")
		color_btn = existing_header.get_node_or_null("ColorPaletteButton")
		close_btn = existing_header.get_node_or_null("CloseButton")
		text_edit = existing_text
		if title_edit:
			title_edit.text = reminder_title
		if text_edit:
			text_edit.text = reminder_text

	if title_edit:
		var on_title_changed = func(new_text: String):
			reminder_title = new_text
			reminder_modified.emit(self)
		if not title_edit.text_changed.is_connected(on_title_changed):
			title_edit.text_changed.connect(on_title_changed)
			
	if color_btn and not color_btn.pressed.is_connected(_on_cycle_color_pressed):
		color_btn.pressed.connect(_on_cycle_color_pressed)
		
	if close_btn:
		var on_del = func(): delete_requested.emit(self)
		if not close_btn.pressed.is_connected(on_del):
			close_btn.pressed.connect(on_del)
			
	if text_edit:
		var on_text_changed = func():
			reminder_text = text_edit.text
			reminder_modified.emit(self)
		if not text_edit.text_changed.is_connected(on_text_changed):
			text_edit.text_changed.connect(on_text_changed)
			
	_apply_color_style()


func _on_cycle_color_pressed() -> void:
	var current_idx = PALETTE.find(reminder_color)
	var next_idx = (current_idx + 1) % PALETTE.size()
	reminder_color = PALETTE[next_idx]
	_apply_color_style()
	reminder_modified.emit(self)


func _apply_color_style() -> void:
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(reminder_color.r, reminder_color.g, reminder_color.b, 0.25)
	sb.border_color = reminder_color.lightened(0.2)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	
	add_theme_stylebox_override("panel", sb)
	add_theme_stylebox_override("panel_selected", sb)
	add_theme_color_override("resizer_color", reminder_color.lightened(0.4))


func to_dict() -> Dictionary:
	return {
		"id": reminder_id,
		"title": reminder_title,
		"text": reminder_text,
		"pos": [position_offset.x, position_offset.y],
		"size": [size.x, size.y],
		"color": reminder_color.to_html(false)
	}
