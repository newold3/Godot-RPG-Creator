@tool
extends HFlowContainer


var command_buttons: Array
var _drop_index: int = -1
var is_dragging: bool = false
var _dragged_id: int = -1

const FAVORITE_BUTTON = preload("uid://bawafq08jue4j")

signal create_command_requested(id: int)


#region notification
## Handles drag notifications for visual feedback and outside drops.
func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		if is_dragging and _dragged_id != -1:
			_apply_drop(_dragged_id, _drop_index)
		
		is_dragging = false
		_drop_index = -1
		_dragged_id = -1
		queue_redraw()
	elif what == NOTIFICATION_DRAG_BEGIN:
		is_dragging = true
#endregion


#region process
## Updates the drop indicator position during a drag operation.
func _process(delta: float) -> void:
	if is_dragging:
		_update_drop_indicator()
#endregion


#region fill
## Refreshes the container with the favorite commands.
func fill() -> void:
	var favorites = FileCache.options.get("current_favorite_commands", [])
	var node = self

	if command_buttons.is_empty():
		var buttons_dialog = load("res://addons/CustomControls/Dialogs/event_commands_dialog.tscn").instantiate()
		buttons_dialog.visible = false
		add_child(buttons_dialog)
		command_buttons = buttons_dialog.get_buttons()
		for i in command_buttons.size():
			command_buttons[i] = command_buttons[i].duplicate()
		buttons_dialog.queue_free()

	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()

	size.y = 0

	for favorite_id in favorites:
		var b = FAVORITE_BUTTON.instantiate()
		b.custom_minimum_size = Vector2(24, 24)
		b.set_meta("favorite_id", favorite_id)

		var real_button = command_buttons.filter(func(button): return int(button.name) == favorite_id)

		if not real_button.is_empty():
			var button = real_button[0]
			b.text = button.text.get_slice(" ", 0)
			
			var help_text = button.get_meta("current_tooltip") if button.has_meta("current_tooltip") else button.tooltip_text
			b.tooltip_text = help_text
			b.mouse_filter = MOUSE_FILTER_PASS
			b.z_index = 10
			
			b.pressed.connect(
				func():
					create_command_requested.emit(favorite_id)
			)
			b.gui_input.connect(_on_button_gui_input.bind(favorite_id))
			node.add_child(b)
#endregion


#region update_drop_indicator
## Calculates the indicator position while dragging.
func _update_drop_indicator() -> void:
	var node = self
	var mouse_pos = node.get_local_mouse_position()
	var children = node.get_children()

	_drop_index = -1

	for child in children:
		if mouse_pos.x < child.position.x + child.size.x / 2:
			_drop_index = child.get_index()
			break

	queue_redraw()
#endregion


#region on_button_gui_input
## Handles the removal of favorites via middle mouse click.
func _on_button_gui_input(event: InputEvent, id: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_MIDDLE and event.pressed:
		var favorites = FileCache.options.get("current_favorite_commands", [])
		favorites.erase(id)
		_save_favorites(favorites)
		fill()
#endregion


#region get_drag_data
## Prepares data for the drag operation.
func _get_drag_data(_at_position: Vector2) -> Variant:
	var node = self

	for child in node.get_children():
		if child.get_rect().has_point(node.get_local_mouse_position()):
			var drag_preview = child.duplicate()
			drag_preview.custom_minimum_size = child.size
			set_drag_preview(drag_preview)
			
			var fav_id = child.get_meta("favorite_id")
			_dragged_id = fav_id
			
			return {"id": fav_id, "node": child}

	return null
#endregion


#region can_drop_data
## Validates if the dragged element can be dropped.
func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return typeof(data) == TYPE_DICTIONARY and data.has("id")
#endregion


#region drop_data
## Handles reordering from Godot's built-in drag system.
func _drop_data(at_position: Vector2, data: Variant) -> void:
	_apply_drop(data.id, _drop_index)
	_dragged_id = -1
#endregion


#region apply_drop
## Applies the logic to reorder and save the favorite list.
func _apply_drop(id: int, index: int) -> void:
	var favorites = FileCache.options.get("current_favorite_commands", [])
	var old_index = favorites.find(id)

	if old_index != -1:
		favorites.erase(id)
		
		if index == -1:
			favorites.append(id)
		else:
			if old_index < index:
				index -= 1
			favorites.insert(index, id)

	_save_favorites(favorites)
	fill()
#endregion


#region save_favorites
## Saves the updated list of favorites to the cache.
func _save_favorites(new_list: Array) -> void:
	FileCache.options["current_favorite_commands"] = new_list
#endregion


#region draw
## Draws the drop indicator.
func _draw() -> void:
	var container = self
	
	if _drop_index != -1 and container.get_child_count() > _drop_index:
		var node = container.get_child(_drop_index)
		var draw_x = node.position.x - 2
		var draw_y = node.position.y
		
		if _drop_index == 0:
			draw_x += 4
			
		if container != self:
			draw_x += container.position.x
			draw_y += container.position.y
			
		draw_rect(
			Rect2(draw_x, draw_y, 3, node.size.y),
			Color.YELLOW
		)
	elif is_dragging and container.get_child_count() > 0:
		var node = container.get_child(container.get_child_count() - 1)
		var draw_x = node.position.x + node.size.x + 2
		var draw_y = node.position.y
		
		if container != self:
			draw_x += container.position.x
			draw_y += container.position.y
			
		draw_rect(
			Rect2(draw_x, draw_y, 3, node.size.y),
			Color.YELLOW
		)
#endregion
