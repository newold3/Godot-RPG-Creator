@tool
class_name RPGMapPassability
extends Resource


## Indicates whether the terrain can be entered from the left side.
@export var left: bool = true : set =_set_left
## Indicates whether the terrain can be entered from the right side.
@export var right: bool = true : set =_set_right
## Indicates whether the terrain can be entered from the top side.
@export var up: bool = true : set =_set_up
## Indicates whether the terrain can be entered from the bottom side.
@export var down: bool = true : set =_set_down
## Sets this tile as high priority. If multiple tiles occupy the same position
## and any high-priority tile permits passage, passage will be granted on that tile.
@export var is_high_priority: bool = false
## If true, this passability is ignored and the tile is treated as passable in all directions.
## (Note: the feature "Keep Events On Top" is  ignored too if disabled is true)
@export var disabled: bool = false


## Directional constants to represent passability.
const DIR_LEFT = 1
const DIR_RIGHT = 2
const DIR_UP = 4
const DIR_DOWN = 8

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


func _set_left(value: bool) -> void:
	left = value
	_redraw_tileset_editor()


func _set_right(value: bool) -> void:
	right = value
	_redraw_tileset_editor()


func _set_up(value: bool) -> void:
	up = value
	_redraw_tileset_editor()


func _set_down(value: bool) -> void:
	down = value
	_redraw_tileset_editor()


## Checks if the terrain is passable in the given direction.
## The direction is provided as a bitmask (e.g., DIR_LEFT, DIR_RIGHT).
func is_passable(direction: int) -> bool:
	if disabled:
		return true
		
	var passable = 0
	if left: passable |= DIR_LEFT
	if right: passable |= DIR_RIGHT
	if up: passable |= DIR_UP
	if down: passable |= DIR_DOWN
	return bool(passable & direction)


func set_disabled(value: bool) -> void:
	disabled = value


# Check if the terrain if full blocked
func is_blocked() -> bool:
	return not (left or right or up or down)


func _to_string() -> String:
	if !left and !right and !up and !down:
		return "❌"
	elif left and right and up and down:
		return "🟢"
	else:
		var emoji_map = {
			"left": "⬅️" if left else "",
			"right": "➡️" if right else "",
			"up": "⬆️" if up else "",
			"down": "⬇️" if down else ""
		}
		
		return "%s%s%s%s" % \
			[emoji_map["left"], emoji_map["right"], emoji_map["up"], emoji_map["down"]]
