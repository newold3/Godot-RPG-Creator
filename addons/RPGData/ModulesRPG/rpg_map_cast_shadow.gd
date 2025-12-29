@tool
class_name RPGMapCastShadow
extends  Resource

## Displays a shadow over the selected tile


## Number of tiles affected by horizontal shading
## (Note: If a tile in the tileset spans multiple tiles, add a single shadow
## resource to the top-left tile and set its actual width and height in tiles.)
@export_range(1, 256, 1) var width: int = 1 : set = set_width
## Number of tiles affected by vertical shading
## (Note: If a tile in the tileset spans multiple tiles, add a single shadow
## resource to the top-left tile and set its actual width and height in tiles.)
@export_range(1, 256, 1) var height: int = 1 : set = set_height
## Offset to narrow the lower vertices of the shadow so that it has a more trapezoidal appearance.
@export_range(1, 256, 1) var feet_offset: int  = 3

var _tileset_editor_cache: Node = null


func _get_tileset_editor() -> Node:
	if _tileset_editor_cache == null:
		var root = EditorInterface.get_base_control()
		_tileset_editor_cache = root.find_child("*TileAtlasView*", true, false)
	return _tileset_editor_cache


func _redraw_tileset_editor() -> void:
	if Engine.is_editor_hint():
		var tileset_atlas = _get_tileset_editor()
		if tileset_atlas:
			tileset_atlas.propagate_call("queue_redraw")


func set_width(value: int) -> void:
	width = value
	_redraw_tileset_editor()


func set_height(value: int) -> void:
	height = value
	_redraw_tileset_editor()


func _to_string() -> String:
	return "⬛%sx%s (🔻%s)" % [width, height, feet_offset]
