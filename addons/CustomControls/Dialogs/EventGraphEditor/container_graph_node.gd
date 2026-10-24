@tool
class_name ContainerGraphNode
extends GraphNode

## Visual group container for GraphNodes.
## Allows moving grouped panels together, renaming via double-click, color coding,
## expanding/collapsing cleanly to header height, and interactive member management
## (moving members via Ctrl+Click, auto-expanding area, removing on complete drop-outside,
## and accepting new members on edge touch).

signal ungroup_requested(node: ContainerGraphNode)
signal delete_requested(node: ContainerGraphNode)
signal collapse_toggled(node: ContainerGraphNode, is_collapsed: bool)
signal container_modified(node: ContainerGraphNode)
signal member_dragged_outside(node: ContainerGraphNode, member: GraphNode)

var container_id: String = ""
var member_node_names: Array[StringName] = []
var is_collapsed: bool = false
var container_title: String = "📦 Contenedor"
var container_color: Color = Color("#2d3748")
var expanded_size: Vector2 = Vector2(360, 240)

var title_label: Label
var title_edit: LineEdit
var collapse_btn: Button
var color_btn: Button
var ungroup_btn: Button
var close_btn: Button
var content_container: Control

var _last_position_offset: Vector2 = Vector2.ZERO
var _internal_moving_members: bool = false

# Ctrl-drag state for members
var _is_ctrl_dragging: bool = false
var _ctrl_drag_target: GraphNode = null
var _ctrl_drag_start_mouse: Vector2 = Vector2.ZERO
var _ctrl_drag_start_node_pos: Vector2 = Vector2.ZERO
var _ctrl_drag_did_move: bool = false

const MARGIN_LEFT: float = 30.0
const MARGIN_RIGHT: float = 30.0
const MARGIN_TOP: float = 65.0
const MARGIN_BOTTOM: float = 30.0
const MIN_CONTAINER_SIZE: Vector2 = Vector2(320.0, 200.0)

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
	position_offset_changed.connect(_on_position_offset_changed)
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
	
	# Populate titlebar HBox
	var tb_hbox = get_titlebar_hbox()
	if tb_hbox:
		for child in tb_hbox.get_children():
			if child.name in ["CollapseButton", "TitleLabel", "TitleEdit", "ColorPaletteButton", "UngroupButton", "CloseButton"]:
				tb_hbox.remove_child(child)
				child.queue_free()
			elif child is Label:
				child.visible = false
				
		tb_hbox.add_theme_constant_override("separation", 6)
		
		collapse_btn = Button.new()
		collapse_btn.name = "CollapseButton"
		collapse_btn.text = "▶" if is_collapsed else "▼"
		collapse_btn.flat = true
		collapse_btn.tooltip_text = "[title]Contraer / Expandir Contenedor[/title]\nOculta o muestra los nodos agrupados en este contenedor."
		collapse_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		collapse_btn.focus_mode = Control.FOCUS_NONE
		collapse_btn.pressed.connect(_on_collapse_pressed)
		tb_hbox.add_child(collapse_btn)
		
		title_label = Label.new()
		title_label.name = "TitleLabel"
		title_label.text = _get_display_title()
		title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		title_label.add_theme_font_size_override("font_size", 16)
		title_label.mouse_filter = Control.MOUSE_FILTER_PASS
		title_label.tooltip_text = "[title]%s[/title]\nArrastra desde el título para mover el contenedor.\nDoble clic para editar el nombre." % container_title
		title_label.gui_input.connect(_on_title_label_gui_input)
		tb_hbox.add_child(title_label)
		
		title_edit = LineEdit.new()
		title_edit.name = "TitleEdit"
		title_edit.text = container_title
		title_edit.placeholder_text = "Nombre del Contenedor..."
		title_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		title_edit.flat = true
		title_edit.add_theme_font_size_override("font_size", 16)
		title_edit.visible = false
		title_edit.text_submitted.connect(_finish_editing_title)
		title_edit.focus_exited.connect(func():
			if title_edit.visible:
				_finish_editing_title(title_edit.text)
		)
		title_edit.gui_input.connect(func(event: InputEvent):
			if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
				_cancel_editing_title()
				title_edit.accept_event()
		)
		tb_hbox.add_child(title_edit)
		
		color_btn = Button.new()
		color_btn.name = "ColorPaletteButton"
		color_btn.text = "🎨"
		color_btn.flat = true
		color_btn.tooltip_text = "[title]Cambiar Color[/title]\nCambia el color distintivo de este contenedor."
		color_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		color_btn.focus_mode = Control.FOCUS_NONE
		color_btn.pressed.connect(_on_cycle_color_pressed)
		tb_hbox.add_child(color_btn)
		
		ungroup_btn = Button.new()
		ungroup_btn.name = "UngroupButton"
		ungroup_btn.text = "⏏"
		ungroup_btn.flat = true
		ungroup_btn.tooltip_text = "[title]Desagrupar Contenedor[/title]\nDisuelve este contenedor manteniendo todos los nodos en el grafo."
		ungroup_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		ungroup_btn.focus_mode = Control.FOCUS_NONE
		ungroup_btn.pressed.connect(func(): ungroup_requested.emit(self))
		tb_hbox.add_child(ungroup_btn)
		
		close_btn = Button.new()
		close_btn.name = "CloseButton"
		close_btn.text = "×"
		close_btn.flat = true
		close_btn.tooltip_text = "[title]Eliminar Contenedor[/title]\nElimina el contenedor del grafo sin borrar sus nodos."
		close_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		close_btn.focus_mode = Control.FOCUS_NONE
		close_btn.pressed.connect(func(): delete_requested.emit(self))
		tb_hbox.add_child(close_btn)
	
	# Content Body (hidden when collapsed to avoid layout fight / tall box)
	var existing_body = get_node_or_null("ContentBody")
	if existing_body:
		content_container = existing_body
	else:
		content_container = Control.new()
		content_container.name = "ContentBody"
		content_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
		content_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		content_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(content_container)
	content_container.visible = !is_collapsed
	
	_apply_color_style()


func _on_title_label_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.double_click and event.pressed:
			_start_editing_title()
			title_label.accept_event()


func _start_editing_title() -> void:
	if is_collapsed:
		return
	title_label.visible = false
	title_edit.visible = true
	title_edit.text = container_title
	if title_edit.is_inside_tree():
		title_edit.grab_focus()
		title_edit.select_all()


func _finish_editing_title(new_text: String) -> void:
	var trimmed = new_text.strip_edges()
	if not trimmed.is_empty():
		container_title = trimmed
	title_edit.visible = false
	title_label.visible = true
	_update_title_display()
	container_modified.emit(self)


func _cancel_editing_title() -> void:
	title_edit.visible = false
	title_label.visible = true
	_update_title_display()


func _update_title_display() -> void:
	if title_label:
		title_label.text = _get_display_title()
		title_label.tooltip_text = "[title]%s[/title]\nArrastra desde el título para mover el contenedor.\nDoble clic para editar el nombre." % container_title
	if title_edit and not title_edit.has_focus():
		title_edit.text = container_title


func _get_display_title() -> String:
	if is_collapsed:
		return "%s (%d)" % [container_title, member_node_names.size()]
	return container_title


func _on_position_offset_changed() -> void:
	if _internal_moving_members:
		return
	var delta = position_offset - _last_position_offset
	_last_position_offset = position_offset
	if delta == Vector2.ZERO:
		return
		
	var parent_graph = get_parent()
	if not parent_graph:
		return
		
	_internal_moving_members = true
	for node_name in member_node_names:
		var n = parent_graph.get_node_or_null(NodePath(node_name))
		if n and n is GraphNode and n != self:
			n.position_offset += delta
	_internal_moving_members = false
	container_modified.emit(self)


func _on_dragged(_from: Vector2, to: Vector2) -> void:
	_last_position_offset = to
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
	if collapse_btn:
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
		if content_container:
			content_container.visible = false
		custom_minimum_size = Vector2(260, 40)
		resizable = false
		reset_size()
	else:
		if content_container:
			content_container.visible = true
		custom_minimum_size = Vector2(280, 160)
		resizable = true
		size = expanded_size
		
	_update_title_display()
		
	if emit_sig:
		collapse_toggled.emit(self, is_collapsed)
		container_modified.emit(self)


func add_member(p_name: StringName) -> void:
	if not member_node_names.has(p_name):
		member_node_names.append(p_name)
		_update_title_display()
		container_modified.emit(self)


func remove_member(p_name: StringName) -> void:
	if member_node_names.has(p_name):
		member_node_names.erase(p_name)
		_update_title_display()
		container_modified.emit(self)


func recalculate_bounds() -> void:
	if is_collapsed:
		_update_title_display()
		return
	var parent_graph = get_parent()
	if not parent_graph:
		return
		
	# Clean any members that were freed
	var valid_members: Array[StringName] = []
	for m_name in member_node_names:
		var n = parent_graph.get_node_or_null(NodePath(m_name))
		if n and is_instance_valid(n) and n is GraphNode and n != self:
			valid_members.append(m_name)
	member_node_names = valid_members
	
	if member_node_names.is_empty():
		_update_title_display()
		container_modified.emit(self)
		return
		
	var min_pos = Vector2(INF, INF)
	var max_pos = Vector2(-INF, -INF)
	var found_any: bool = false
	
	for m_name in member_node_names:
		var n = parent_graph.get_node_or_null(NodePath(m_name)) as GraphNode
		if n and is_instance_valid(n):
			found_any = true
			min_pos.x = min(min_pos.x, n.position_offset.x)
			min_pos.y = min(min_pos.y, n.position_offset.y)
			max_pos.x = max(max_pos.x, n.position_offset.x + n.size.x)
			max_pos.y = max(max_pos.y, n.position_offset.y + n.size.y)
			
	if not found_any:
		_update_title_display()
		return
		
	# Required bounds to enclose all members with margins
	var req_min_x = min_pos.x - MARGIN_LEFT
	var req_min_y = min_pos.y - MARGIN_TOP
	var req_max_x = max_pos.x + MARGIN_RIGHT
	var req_max_y = max_pos.y + MARGIN_BOTTOM
	
	# Current container outer rect bounds
	var cur_min_x = position_offset.x
	var cur_min_y = position_offset.y
	var cur_max_x = position_offset.x + size.x
	var cur_max_y = position_offset.y + size.y
	
	# Container NEVER shrinks on its own; it only expands if needed to wrap members!
	var new_min_x = min(cur_min_x, req_min_x)
	var new_min_y = min(cur_min_y, req_min_y)
	var new_max_x = max(cur_max_x, req_max_x)
	var new_max_y = max(cur_max_y, req_max_y)
	
	var new_pos = Vector2(new_min_x, new_min_y)
	var new_size = Vector2(
		max(new_max_x - new_min_x, MIN_CONTAINER_SIZE.x),
		max(new_max_y - new_min_y, MIN_CONTAINER_SIZE.y)
	)
	
	if new_pos != position_offset or new_size != size:
		_internal_moving_members = true
		position_offset = new_pos
		_last_position_offset = new_pos
		_internal_moving_members = false
		
		expanded_size = new_size
		size = new_size
		
	_update_title_display()
	container_modified.emit(self)


func _find_member_at(p_graph_pos: Vector2) -> GraphNode:
	var parent_graph = get_parent()
	if not parent_graph:
		return null
	for i in range(member_node_names.size() - 1, -1, -1):
		var m_name = member_node_names[i]
		var n = parent_graph.get_node_or_null(NodePath(m_name)) as GraphNode
		if n and is_instance_valid(n) and n.visible:
			var rect = Rect2(n.position_offset, n.size)
			if rect.has_point(p_graph_pos):
				return n
	return null


func _gui_input(event: InputEvent) -> void:
	if is_collapsed:
		return
		
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				if event.ctrl_pressed:
					var click_graph_pos = position_offset + event.position
					var target = _find_member_at(click_graph_pos)
					if target:
						_is_ctrl_dragging = true
						_ctrl_drag_target = target
						_ctrl_drag_start_mouse = event.global_position
						_ctrl_drag_start_node_pos = target.position_offset
						_ctrl_drag_did_move = false
						var parent_graph = get_parent()
						if parent_graph:
							parent_graph.move_child(target, -1)
						accept_event()
						return
			else:
				if _is_ctrl_dragging:
					var target = _ctrl_drag_target
					var did_move = _ctrl_drag_did_move
					_is_ctrl_dragging = false
					_ctrl_drag_target = null
					accept_event()
					
					if target and is_instance_valid(target):
						if did_move:
							var cont_rect = Rect2(position_offset, size)
							var node_rect = Rect2(target.position_offset, target.size)
							if cont_rect.intersects(node_rect, true):
								recalculate_bounds()
							else:
								remove_member(target.name)
								member_dragged_outside.emit(self, target)
							container_modified.emit(self)
						else:
							var parent_graph = get_parent() as GraphEdit
							if parent_graph:
								for child in parent_graph.get_children():
									if child is GraphNode:
										child.selected = false
								target.selected = true
								parent_graph.move_child(target, -1)
					return
					
	elif event is InputEventMouseMotion:
		if _is_ctrl_dragging and _ctrl_drag_target and is_instance_valid(_ctrl_drag_target):
			var parent_graph = get_parent() as GraphEdit
			var zoom = parent_graph.zoom if parent_graph else 1.0
			var delta_mouse = event.global_position - _ctrl_drag_start_mouse
			if delta_mouse.length() > 3.0:
				_ctrl_drag_did_move = true
			_ctrl_drag_target.position_offset = _ctrl_drag_start_node_pos + (delta_mouse / zoom)
			accept_event()
			return


func _on_cycle_color_pressed() -> void:
	var current_idx = PALETTE.find(container_color)
	var next_idx = (current_idx + 1) % PALETTE.size()
	container_color = PALETTE[next_idx]
	_apply_color_style()
	container_modified.emit(self)


func _apply_color_style() -> void:
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(container_color.r, container_color.g, container_color.b, 0.28)
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
	
	var tb_sb = StyleBoxFlat.new()
	tb_sb.bg_color = Color(container_color.r * 0.75, container_color.g * 0.75, container_color.b * 0.75, 0.9)
	tb_sb.border_color = container_color.lightened(0.3)
	tb_sb.border_width_left = 2
	tb_sb.border_width_right = 2
	tb_sb.border_width_top = 2
	tb_sb.border_width_bottom = 1
	tb_sb.corner_radius_top_left = 6
	tb_sb.corner_radius_top_right = 6
	tb_sb.content_margin_left = 8
	tb_sb.content_margin_right = 8
	tb_sb.content_margin_top = 4
	tb_sb.content_margin_bottom = 4
	add_theme_stylebox_override("titlebar", tb_sb)
	add_theme_stylebox_override("titlebar_selected", tb_sb)


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
