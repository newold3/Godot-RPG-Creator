@tool
class_name ContainerGraphNode
extends GraphNode

## Visual group container for GraphNodes.
## Allows moving grouped panels together, renaming, color coding,
## and expanding/collapsing the container.

signal ungroup_requested(node: ContainerGraphNode)
signal delete_requested(node: ContainerGraphNode)
signal collapse_toggled(node: ContainerGraphNode, is_collapsed: bool)
signal container_modified(node: ContainerGraphNode)

var container_id: String = ""
var member_node_names: Array[StringName] = []
var is_collapsed: bool = false
var container_title: String = "📦 Contenedor"
var container_color: Color = Color("#2d3748")
var expanded_size: Vector2 = Vector2(360, 240)

var title_edit: LineEdit
var collapse_btn: Button
var color_btn: Button
var ungroup_btn: Button
var close_btn: Button
var content_container: VBoxContainer
var summary_label: Label

var _last_position_offset: Vector2 = Vector2.ZERO

const PALETTE = [
	Color("#2d3748"), # Dark Slate
	Color("#1a365d"), # Navy Blue
	Color("#234e52"), # Deep Teal
	Color("#22543d"), # Forest Green
	Color("#44337a"), # Deep Purple
	Color("#742a2a"), # Dark Crimson
	Color("#744210")  # Dark Amber
]


func _ready() -> void:
	resizable = true
	_last_position_offset = position_offset
	dragged.connect(_on_dragged)
	resize_request.connect(_on_resize_request)
	_build_ui()


func setup_container(p_id: String, p_title: String, p_member_names: Array[StringName], p_pos: Vector2, p_size: Vector2 = Vector2(360, 240), p_color: Color = Color("#2d3748"), p_collapsed: bool = false) -> void:
	container_id = p_id
	container_title = p_title
	member_node_names = p_member_names.duplicate()
	position_offset = p_pos
	_last_position_offset = p_pos
	expanded_size = p_size
	container_color = p_color
	is_collapsed = p_collapsed
	
	_build_ui()
	_apply_color_style()
	if is_collapsed:
		_set_collapsed_state(true, false)
	else:
		size = expanded_size


func _build_ui() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
		
	title = ""
	
	# Header Row (inside Titlebar or top row)
	var header_hbox = HBoxContainer.new()
	header_hbox.name = "HeaderHBox"
	header_hbox.add_theme_constant_override("separation", 6)
	
	collapse_btn = Button.new()
	collapse_btn.name = "CollapseButton"
	collapse_btn.text = "▶" if is_collapsed else "▼"
	collapse_btn.flat = true
	collapse_btn.tooltip_text = "[title]Contraer / Expandir Contenedor[/title]\nOculta o muestra los nodos agrupados en este contenedor."
	collapse_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	collapse_btn.focus_mode = Control.FOCUS_NONE
	collapse_btn.pressed.connect(_on_collapse_pressed)
	header_hbox.add_child(collapse_btn)
	
	title_edit = LineEdit.new()
	title_edit.name = "TitleEdit"
	title_edit.text = container_title
	title_edit.placeholder_text = "Nombre del Contenedor..."
	title_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_edit.flat = true
	title_edit.add_theme_font_size_override("font_size", 13)
	title_edit.text_changed.connect(func(new_text: String):
		container_title = new_text
		container_modified.emit(self)
	)
	header_hbox.add_child(title_edit)
	
	color_btn = Button.new()
	color_btn.name = "ColorPaletteButton"
	color_btn.text = "🎨"
	color_btn.flat = true
	color_btn.tooltip_text = "[title]Cambiar Color[/title]\nCambia el color distintivo de este contenedor."
	color_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	color_btn.focus_mode = Control.FOCUS_NONE
	color_btn.pressed.connect(_on_cycle_color_pressed)
	header_hbox.add_child(color_btn)
	
	ungroup_btn = Button.new()
	ungroup_btn.name = "UngroupButton"
	ungroup_btn.text = "⏏"
	ungroup_btn.flat = true
	ungroup_btn.tooltip_text = "[title]Desagrupar Contenedor[/title]\nDisuelve este contenedor manteniendo todos los nodos en el grafo."
	ungroup_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	ungroup_btn.focus_mode = Control.FOCUS_NONE
	ungroup_btn.pressed.connect(func(): ungroup_requested.emit(self))
	header_hbox.add_child(ungroup_btn)
	
	close_btn = Button.new()
	close_btn.name = "CloseButton"
	close_btn.text = "×"
	close_btn.flat = true
	close_btn.tooltip_text = "[title]Eliminar Contenedor[/title]\nElimina el contenedor del grafo sin borrar sus nodos."
	close_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	close_btn.focus_mode = Control.FOCUS_NONE
	close_btn.pressed.connect(func(): delete_requested.emit(self))
	header_hbox.add_child(close_btn)
	
	add_child(header_hbox)
	
	# Content Body
	content_container = VBoxContainer.new()
	content_container.name = "ContentBody"
	content_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	summary_label = Label.new()
	summary_label.name = "SummaryLabel"
	summary_label.text = "📦 %d paneles agrupados" % member_node_names.size()
	summary_label.add_theme_font_size_override("font_size", 12)
	summary_label.modulate = Color(0.85, 0.85, 0.9)
	summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content_container.add_child(summary_label)
	
	add_child(content_container)
	_apply_color_style()


func _on_dragged(from: Vector2, to: Vector2) -> void:
	var delta = to - from
	_last_position_offset = to
	
	var parent_graph = get_parent()
	if not parent_graph:
		return
		
	for node_name in member_node_names:
		var n = parent_graph.get_node_or_null(NodePath(node_name))
		if n and n is GraphNode and n != self:
			n.position_offset += delta
			
	container_modified.emit(self)


func _on_resize_request(new_size: Vector2) -> void:
	if not is_collapsed:
		expanded_size = new_size
		size = new_size
		container_modified.emit(self)


func _on_collapse_pressed() -> void:
	_set_collapsed_state(not is_collapsed, true)


func _set_collapsed_state(p_collapsed: bool, emit_sig: bool = true) -> void:
	is_collapsed = p_collapsed
	collapse_btn.text = "▶" if is_collapsed else "▼"
	
	var parent_graph = get_parent()
	if parent_graph:
		for node_name in member_node_names:
			var n = parent_graph.get_node_or_null(NodePath(node_name))
			if n and n is GraphNode and n != self:
				n.visible = !is_collapsed
				
	if is_collapsed:
		if size.y > 70:
			expanded_size = size
		custom_minimum_size = Vector2(240, 60)
		size = Vector2(240, 60)
		resizable = false
		summary_label.visible = true
		summary_label.text = "📦 %d paneles agrupados (contraído)" % member_node_names.size()
	else:
		custom_minimum_size = Vector2(280, 160)
		size = expanded_size
		resizable = true
		summary_label.text = "📦 %d paneles agrupados" % member_node_names.size()
		
	if emit_sig:
		collapse_toggled.emit(self, is_collapsed)
		container_modified.emit(self)


func add_member(p_name: StringName) -> void:
	if not member_node_names.has(p_name):
		member_node_names.append(p_name)
		update_summary()
		container_modified.emit(self)


func remove_member(p_name: StringName) -> void:
	if member_node_names.has(p_name):
		member_node_names.erase(p_name)
		update_summary()
		container_modified.emit(self)


func update_summary() -> void:
	if summary_label:
		if is_collapsed:
			summary_label.text = "📦 %d paneles agrupados (contraído)" % member_node_names.size()
		else:
			summary_label.text = "📦 %d paneles agrupados" % member_node_names.size()


func _on_cycle_color_pressed() -> void:
	var current_idx = PALETTE.find(container_color)
	var next_idx = (current_idx + 1) % PALETTE.size()
	container_color = PALETTE[next_idx]
	_apply_color_style()
	container_modified.emit(self)


func _apply_color_style() -> void:
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(container_color.r, container_color.g, container_color.b, 0.35)
	sb.border_color = container_color.lightened(0.3)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	
	add_theme_stylebox_override("panel", sb)
	add_theme_stylebox_override("panel_selected", sb)
	add_theme_color_override("resizer_color", container_color.lightened(0.5))


func to_dict() -> Dictionary:
	return {
		"id": container_id,
		"title": container_title,
		"pos": [position_offset.x, position_offset.y],
		"size": [expanded_size.x, expanded_size.y],
		"color": container_color.to_html(false),
		"collapsed": is_collapsed,
		"member_nodes": member_node_names
	}
