@tool
class_name TextureStyleBox
extends Texture2D

## The StyleBox used to draw the texture
@export var stylebox: StyleBox: set = _set_stylebox
## The physical size of the texture updated by its owner
@export var texture_size: Vector2 = Vector2(64, 64): set = _set_texture_size
## Click to update the texture size from the currently selected Control node in the editor
@export var update_from_selection: bool = false: set = _update_from_selection


## Sets the stylebox and connects the changed signal
func _set_stylebox(value: StyleBox) -> void:
	if stylebox != value:
		if stylebox and stylebox.changed.is_connected(_on_stylebox_changed):
			stylebox.changed.disconnect(_on_stylebox_changed)
		stylebox = value
		if stylebox and not stylebox.changed.is_connected(_on_stylebox_changed):
			stylebox.changed.connect(_on_stylebox_changed)
		emit_changed()


## Sets the physical size of the texture and emits changed
func _set_texture_size(value: Vector2) -> void:
	if texture_size != value:
		texture_size = value
		emit_changed()


## Updates the texture size from the currently selected Control in the editor
func _update_from_selection(value: bool) -> void:
	if Engine.is_editor_hint() and value:
		var selection = EditorInterface.get_selection().get_selected_nodes()
		if selection.size() == 1 and selection[0] is Control:
			_set_texture_size(selection[0].size)


## Emits changed when the stylebox updates internally
func _on_stylebox_changed() -> void:
	emit_changed()


## Returns the current width of the texture
func _get_width() -> int:
	return int(texture_size.x)


## Returns the current height of the texture
func _get_height() -> int:
	return int(texture_size.y)


## Indicates that the texture has an alpha channel
func _has_alpha() -> bool:
	return true


## Draws the texture at the given position
func _draw(to_canvas_item: RID, pos: Vector2, modulate: Color, transpose: bool) -> void:
	if stylebox:
		stylebox.draw(to_canvas_item, Rect2(pos, texture_size))


## Draws the texture filling the provided rect exactly
func _draw_rect(to_canvas_item: RID, rect: Rect2, tile: bool, modulate: Color, transpose: bool) -> void:
	if stylebox:
		stylebox.draw(to_canvas_item, rect)


## Draws a region of the texture
func _draw_rect_region(to_canvas_item: RID, rect: Rect2, src_rect: Rect2, modulate: Color, transpose: bool, clip_uv: bool) -> void:
	if stylebox:
		stylebox.draw(to_canvas_item, rect)
