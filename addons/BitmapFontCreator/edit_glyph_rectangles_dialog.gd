@tool
extends Window

const DRAG_NONE := 0
const DRAG_MOVE := 1
const DRAG_LEFT := 2
const DRAG_RIGHT := 3
const DRAG_TOP := 4
const DRAG_BOTTOM := 5
const DRAG_CREATE := 6
const EDGE_MARGIN := 6

var letter_scene: PackedScene
var letters_parent: Node
var letters_data: Array[PanelContainer] = []
var base_tex: Texture2D

var selected_index: int = -1
var hovered_index: int = -1
var dragging: bool = false
var panning: bool = false
var drag_mode: int = DRAG_NONE
var drag_start_rect: Rect2i
var drag_start_pos: Vector2
var creation_rect: Rect2i
var zoom: float = 1.0

var undo_redo := UndoRedo.new()
var _deleted_nodes_pool: Array[PanelContainer] = []

@onready var item_list: ItemList = %ItemList
@onready var canvas: TextureRect = %Canvas

signal rects_changed()
signal new_letter_created(letter_node: PanelContainer)



## Initializes signals, connects inputs, and sets up window bounds
func _ready() -> void:
	close_requested.connect(queue_free)
	item_list.item_selected.connect(_on_list_item_selected)
	canvas.draw.connect(_on_canvas_draw)
	canvas.gui_input.connect(_on_canvas_gui_input)



## Cleanup deleted nodes that remain outside the SceneTree when the dialog is destroyed
func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		for node in _deleted_nodes_pool:
			if is_instance_valid(node) and not node.is_inside_tree():
				node.queue_free()



## Captures keyboard shortcuts for Undo (Ctrl+Z) and Redo (Ctrl+Y / Ctrl+Shift+Z) globally in the window
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.is_pressed():
		if event.ctrl_pressed:
			if event.keycode == KEY_Z:
				if event.shift_pressed:
					if undo_redo.has_redo(): undo_redo.redo()
				else:
					if undo_redo.has_undo(): undo_redo.undo()
					
				get_viewport().set_input_as_handled()
				
			elif event.keycode == KEY_Y:
				if undo_redo.has_redo(): undo_redo.redo()
				
				get_viewport().set_input_as_handled()



## Populates the editor with the current texture and the active letter nodes
func set_data(texture: Texture2D, letters: Array[Node], p_letter_scene: PackedScene, p_parent: Node) -> void:
	base_tex = texture
	letter_scene = p_letter_scene
	letters_parent = p_parent
	
	canvas.texture = base_tex
	canvas.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	canvas.stretch_mode = TextureRect.STRETCH_SCALE
	
	undo_redo.clear_history()
	_apply_zoom(1.0, Vector2.ZERO)
	
	letters_data.clear()
	
	for node in letters:
		if node is PanelContainer and node.atlas_texture != null:
			letters_data.append(node)
			
	_refresh_list()



## Handles zoom logic and defers the scrollbar updates to keep the mouse centered
func _apply_zoom(new_zoom: float, mouse_pos: Vector2) -> void:
	var old_zoom := zoom
	zoom = clamp(new_zoom, 0.2, 5.0)
	
	var scroll: ScrollContainer = canvas.get_parent()
	var local_scroll_pos := mouse_pos - Vector2(scroll.scroll_horizontal, scroll.scroll_vertical)
	
	canvas.custom_minimum_size = base_tex.get_size() * zoom
	canvas.size = canvas.custom_minimum_size
	
	if old_zoom != zoom:
		var new_target := mouse_pos * (zoom / old_zoom)
		_update_scroll.call_deferred(scroll, new_target, local_scroll_pos)
		
	canvas.queue_redraw()



## Safely applies scroll values, delegating to SmoothScrollContainer methods if available
func _update_scroll(scroll: ScrollContainer, new_target: Vector2, local_scroll_pos: Vector2) -> void:
	var h_val: int = int(new_target.x - local_scroll_pos.x)
	var v_val: int = int(new_target.y - local_scroll_pos.y)
	
	if scroll.has_method("set_h_scroll"):
		scroll.set_h_scroll(h_val)
		scroll.set_v_scroll(v_val)
	else:
		scroll.scroll_horizontal = h_val
		scroll.scroll_vertical = v_val



## Rebuilds the ItemList using the assigned character or a default ID
func _refresh_list() -> void:
	item_list.clear()
	
	for i in range(letters_data.size()):
		var letter_node: PanelContainer = letters_data[i]
		var text: String = letter_node.current_character
		
		if text.is_empty():
			text = "Char #%d" % i
			
		item_list.add_item(text)
		
	if selected_index >= 0 and selected_index < item_list.get_item_count():
		item_list.select(selected_index)
	else:
		selected_index = -1



## Updates the canvas selection when an item is clicked in the list
func _on_list_item_selected(index: int) -> void:
	selected_index = index
	canvas.queue_redraw()



## Custom draw function applying the zoom transform and rendering the highlights and handles
func _on_canvas_draw() -> void:
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2(zoom, zoom))
	
	if dragging and drag_mode == DRAG_CREATE:
		canvas.draw_rect(creation_rect, Color.CYAN, false, max(1.0, 2.0 / zoom))
		canvas.draw_rect(creation_rect, Color(0.0, 1.0, 1.0, 0.15), true)
		
	for i in range(letters_data.size()):
		var rect: Rect2i = letters_data[i].atlas_texture.region
		
		if i == selected_index:
			canvas.draw_rect(rect, Color.GREEN, false, max(1.0, 2.0 / zoom))
			
			var center_x := rect.position.x + rect.size.x / 2.0
			var center_y := rect.position.y + rect.size.y / 2.0
			var handle_size := Vector2(EDGE_MARGIN, EDGE_MARGIN) / zoom
			
			canvas.draw_rect(Rect2(Vector2(rect.position.x - handle_size.x / 2.0, center_y - handle_size.y / 2.0), handle_size), Color.RED)
			canvas.draw_rect(Rect2(Vector2(rect.end.x - handle_size.x / 2.0, center_y - handle_size.y / 2.0), handle_size), Color.RED)
			canvas.draw_rect(Rect2(Vector2(center_x - handle_size.x / 2.0, rect.position.y - handle_size.y / 2.0), handle_size), Color.RED)
			canvas.draw_rect(Rect2(Vector2(center_x - handle_size.x / 2.0, rect.end.y - handle_size.y / 2.0), handle_size), Color.RED)
			
		elif i == hovered_index:
			canvas.draw_rect(rect, Color(1.0, 1.0, 1.0, 0.2), true)
			canvas.draw_rect(rect, Color.YELLOW, false, max(1.0, 1.5 / zoom))
			
		else:
			canvas.draw_rect(rect, Color(1.0, 0.5, 0.0, 0.5), false, max(1.0, 1.0 / zoom))



## Routes canvas mouse inputs converting global events into unscaled local positions
func _on_canvas_gui_input(event: InputEvent) -> void:
	var local_pos := Vector2.ZERO
	
	if event is InputEventMouse:
		local_pos = event.position / zoom
		
	if event is InputEventMouseButton:
		if event.ctrl_pressed:
			if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.is_pressed():
				_apply_zoom(zoom + 0.1, event.position)
				get_viewport().set_input_as_handled()
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.is_pressed():
				_apply_zoom(zoom - 0.1, event.position)
				get_viewport().set_input_as_handled()
			return
			
		if event.button_index == MOUSE_BUTTON_MIDDLE:
			if event.is_pressed():
				panning = true
				canvas.mouse_default_cursor_shape = Control.CURSOR_DRAG
			else:
				panning = false
				_update_mouse_cursor(local_pos)
			return
			
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.is_pressed():
				_handle_left_click_down(local_pos)
			else:
				if dragging:
					dragging = false
					
					if drag_mode == DRAG_CREATE:
						_commit_rect_creation()
					elif drag_mode != DRAG_NONE:
						_commit_rect_edit_action()
						
					drag_mode = DRAG_NONE
					canvas.queue_redraw()
					
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.is_pressed():
			_handle_right_click(local_pos)
			
	elif event is InputEventMouseMotion:
		if panning:
			var scroll: ScrollContainer = canvas.get_parent()
			if scroll.has_method("update_scroll"):
				scroll.update_scroll(-event.relative, true)
			else:
				scroll.scroll_horizontal -= int(event.relative.x)
				scroll.scroll_vertical -= int(event.relative.y)
				
		elif dragging and (selected_index != -1 or drag_mode == DRAG_CREATE):
			_process_drag(local_pos)
			
		else:
			_update_hover(local_pos)
			_update_mouse_cursor(local_pos)



## Creates an UndoRedo action to instantiate a new rect based on the drag area
func _commit_rect_creation() -> void:
	if creation_rect.size.x < 4 or creation_rect.size.y < 4:
		return
		
	var new_node = letter_scene.instantiate()
	new_node.name = "Letter_" + str(Time.get_ticks_msec())
	
	var atlas := AtlasTexture.new()
	atlas.atlas = base_tex
	atlas.region = creation_rect
	new_node.set_image(atlas)
	
	undo_redo.create_action("Create Rect")
	undo_redo.add_do_method(_do_create_rect.bind(new_node))
	undo_redo.add_undo_method(_undo_create_rect.bind(new_node))
	undo_redo.commit_action()



## Creates an UndoRedo action to save the final position/size of the manipulated rect
func _commit_rect_edit_action() -> void:
	if selected_index == -1:
		return
		
	var final_rect: Rect2i = letters_data[selected_index].atlas_texture.region
	
	if final_rect != drag_start_rect:
		letters_data[selected_index].atlas_texture.region = drag_start_rect
		
		undo_redo.create_action("Edit Rect")
		undo_redo.add_do_property(letters_data[selected_index].atlas_texture, "region", final_rect)
		undo_redo.add_undo_property(letters_data[selected_index].atlas_texture, "region", drag_start_rect)
		undo_redo.add_do_method(_on_undo_redo_changed)
		undo_redo.add_undo_method(_on_undo_redo_changed)
		undo_redo.commit_action()
	else:
		rects_changed.emit()



## Triggers view update after an Undo or Redo property change occurs
func _on_undo_redo_changed() -> void:
	canvas.queue_redraw()
	rects_changed.emit()



## Determines if the mouse is hovering over a rect and triggers a redraw if changed
func _update_hover(local_pos: Vector2) -> void:
	var new_hover := -1
	
	for i in range(letters_data.size() - 1, -1, -1):
		if letters_data[i].atlas_texture.region.has_point(local_pos):
			new_hover = i
			break
			
	if new_hover != hovered_index:
		hovered_index = new_hover
		canvas.queue_redraw()



## Identifies the targeted rect or edge based on unscaled coordinates to begin a drag action
func _handle_left_click_down(pos: Vector2) -> void:
	if selected_index != -1:
		var rect: Rect2i = letters_data[selected_index].atlas_texture.region
		drag_mode = _get_drag_mode(pos, rect)
		
		if drag_mode != DRAG_NONE:
			dragging = true
			drag_start_pos = pos
			drag_start_rect = rect
			return
			
	for i in range(letters_data.size() - 1, -1, -1):
		var rect: Rect2i = letters_data[i].atlas_texture.region
		
		if rect.has_point(pos):
			selected_index = i
			item_list.select(selected_index)
			item_list.ensure_current_is_visible.call_deferred()
			canvas.queue_redraw()
			
			drag_mode = DRAG_MOVE
			dragging = true
			drag_start_pos = pos
			drag_start_rect = rect
			return
			
	selected_index = -1
	item_list.deselect_all()
	
	drag_mode = DRAG_CREATE
	dragging = true
	drag_start_pos = pos
	creation_rect = Rect2i(int(pos.x), int(pos.y), 0, 0)
	
	canvas.queue_redraw()



## Prepares and commits an UndoRedo action for deleting a rect
func _handle_right_click(pos: Vector2) -> void:
	for i in range(letters_data.size() - 1, -1, -1):
		var rect: Rect2i = letters_data[i].atlas_texture.region
		
		if rect.has_point(pos):
			var node_to_delete: PanelContainer = letters_data[i]
			var parent := node_to_delete.get_parent()
			
			if not _deleted_nodes_pool.has(node_to_delete):
				_deleted_nodes_pool.append(node_to_delete)
				
			undo_redo.create_action("Delete Rect")
			undo_redo.add_do_method(_do_delete_rect.bind(node_to_delete, parent))
			undo_redo.add_undo_method(_undo_delete_rect.bind(node_to_delete, parent, i))
			undo_redo.commit_action()
			return



## Executes the actual removal of the rect node
func _do_delete_rect(node: PanelContainer, parent: Node) -> void:
	if parent and node.get_parent() == parent:
		parent.remove_child(node)
		
	if letters_data.has(node):
		var idx := letters_data.find(node)
		letters_data.remove_at(idx)
		
		if selected_index == idx:
			selected_index = -1
		elif selected_index > idx:
			selected_index -= 1
			
	_refresh_list()
	canvas.queue_redraw()
	rects_changed.emit()



## Restores a previously removed rect node to its original state
func _undo_delete_rect(node: PanelContainer, parent: Node, original_index: int) -> void:
	if parent and node.get_parent() == null:
		parent.add_child(node)
		
	var insert_idx := clamp(original_index, 0, letters_data.size())
	letters_data.insert(insert_idx, node)
	
	_refresh_list()
	canvas.queue_redraw()
	rects_changed.emit()



## Instantiates and registers a newly drawn rect node
func _do_create_rect(node: PanelContainer) -> void:
	if node.get_parent() == null:
		letters_parent.add_child(node)
		
	if not letters_data.has(node):
		letters_data.append(node)
		
	selected_index = letters_data.size() - 1
	
	if _deleted_nodes_pool.has(node):
		_deleted_nodes_pool.erase(node)
		
	if not node.has_meta("signals_connected"):
		new_letter_created.emit(node)
		node.set_meta("signals_connected", true)
		
	_refresh_list()
	canvas.queue_redraw()
	rects_changed.emit()



## Reverts the creation of a newly drawn rect node
func _undo_create_rect(node: PanelContainer) -> void:
	if letters_parent and node.get_parent() == letters_parent:
		letters_parent.remove_child(node)
		
	if letters_data.has(node):
		var idx := letters_data.find(node)
		letters_data.remove_at(idx)
		
		if selected_index == idx:
			selected_index = -1
		elif selected_index > idx:
			selected_index -= 1
			
	if not _deleted_nodes_pool.has(node):
		_deleted_nodes_pool.append(node)
		
	_refresh_list()
	canvas.queue_redraw()
	rects_changed.emit()



## Returns the active drag zone considering the current zoom scale for the margins
func _get_drag_mode(pos: Vector2, rect: Rect2i) -> int:
	var margin := EDGE_MARGIN / zoom
	
	if abs(pos.x - rect.position.x) <= margin and pos.y >= rect.position.y and pos.y <= rect.end.y:
		return DRAG_LEFT
	if abs(pos.x - rect.end.x) <= margin and pos.y >= rect.position.y and pos.y <= rect.end.y:
		return DRAG_RIGHT
	if abs(pos.y - rect.position.y) <= margin and pos.x >= rect.position.x and pos.x <= rect.end.x:
		return DRAG_TOP
	if abs(pos.y - rect.end.y) <= margin and pos.x >= rect.position.x and pos.x <= rect.end.x:
		return DRAG_BOTTOM
	if rect.has_point(pos):
		return DRAG_MOVE
		
	return DRAG_NONE



## Applies the movement offset directly to the rect data and requests a redraw
func _process_drag(pos: Vector2) -> void:
	if drag_mode == DRAG_CREATE:
		var min_x := min(drag_start_pos.x, pos.x)
		var min_y := min(drag_start_pos.y, pos.y)
		var max_x := max(drag_start_pos.x, pos.x)
		var max_y := max(drag_start_pos.y, pos.y)
		
		creation_rect = Rect2i(int(min_x), int(min_y), int(max_x - min_x), int(max_y - min_y))
		canvas.queue_redraw()
		return
		
	var delta_x: int = int(pos.x - drag_start_pos.x)
	var delta_y: int = int(pos.y - drag_start_pos.y)
	var new_rect: Rect2i = drag_start_rect
	
	match drag_mode:
		DRAG_MOVE:
			new_rect.position.x += delta_x
			new_rect.position.y += delta_y
		DRAG_LEFT:
			new_rect.position.x += delta_x
			new_rect.size.x -= delta_x
		DRAG_RIGHT:
			new_rect.size.x += delta_x
		DRAG_TOP:
			new_rect.position.y += delta_y
			new_rect.size.y -= delta_y
		DRAG_BOTTOM:
			new_rect.size.y += delta_y
			
	if new_rect.size.x < 1:
		new_rect.size.x = 1
	if new_rect.size.y < 1:
		new_rect.size.y = 1
		
	letters_data[selected_index].atlas_texture.region = new_rect
	canvas.queue_redraw()



## Dynamically changes the cursor shape based on what lies under the mouse
func _update_mouse_cursor(local_pos: Vector2) -> void:
	if dragging and drag_mode == DRAG_CREATE:
		canvas.mouse_default_cursor_shape = Control.CURSOR_CROSS
		return
		
	if selected_index != -1:
		var rect: Rect2i = letters_data[selected_index].atlas_texture.region
		var hover_mode: int = _get_drag_mode(local_pos, rect)
		
		match hover_mode:
			DRAG_LEFT, DRAG_RIGHT:
				canvas.mouse_default_cursor_shape = Control.CURSOR_HSIZE
				return
			DRAG_TOP, DRAG_BOTTOM:
				canvas.mouse_default_cursor_shape = Control.CURSOR_VSIZE
				return
			DRAG_MOVE:
				canvas.mouse_default_cursor_shape = Control.CURSOR_DRAG
				return
				
	if hovered_index != -1:
		canvas.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	else:
		canvas.mouse_default_cursor_shape = Control.CURSOR_CROSS


func _on_cancel_button_pressed() -> void:
	queue_free()
