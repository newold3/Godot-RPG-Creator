class_name SimpleFollower
extends Sprite2D

@export var target_node: Node2D
@export var lag_steps: int = 10 
@export var animation_fps: float = 12.0

var _visual_history: Array[Dictionary] = []
var _max_history_size: int = 300
var _last_recorded_pos: Vector2 = Vector2.ZERO
var _last_recorded_direction: int = -1
var _record_threshold_squared: float = 16.0

var _current_direction_value: int = 1
var _previous_frame_pos: Vector2


func _ready() -> void:
	hframes = 9
	vframes = 4
	
	_previous_frame_pos = global_position
	_initialize_own_history()


func _physics_process(_delta: float) -> void:
	if not target_node or not target_node.has_method("get_visual_snapshot"):
		return
	
	_record_my_state_conditional()

	var snapshot: Dictionary = target_node.get_visual_snapshot(lag_steps)
	if snapshot.is_empty(): return

	global_position = snapshot.pos
	z_index = snapshot.z
	scale = snapshot.scale
	modulate = snapshot.modulate
	rotation = snapshot.rotation
	skew = snapshot.skew
	if "centered" in snapshot:
		centered = snapshot.centered
		offset = snapshot.offset
		flip_h = snapshot.flip_h
		flip_v = snapshot.flip_v
	
	_current_direction_value = snapshot.dir
	
	frame_coords.y = _get_row_from_direction(_current_direction_value)
		
	var dist_sq = global_position.distance_squared_to(_previous_frame_pos)
	var is_moving = dist_sq > 0.0001
	
	if is_moving:
		var walk_frames_count = 8
		var current_time = Time.get_ticks_msec() / 1000.0
		var frame_offset = int(current_time * animation_fps) % walk_frames_count
		frame_coords.x = 1 + frame_offset
	else:
		frame_coords.x = 0
		
	_previous_frame_pos = global_position


func _get_row_from_direction(dir_value: int) -> int:
	match dir_value:
		CharacterBase.DIRECTIONS.LEFT: return 0
		CharacterBase.DIRECTIONS.DOWN: return 1
		CharacterBase.DIRECTIONS.RIGHT: return 2
		CharacterBase.DIRECTIONS.UP: return 3
	return 1


func _record_my_state_conditional() -> void:
	var dist_sq = global_position.distance_squared_to(_last_recorded_pos)
	
	if dist_sq < _record_threshold_squared and _current_direction_value == _last_recorded_direction:
		return 

	var snapshot = {
		"pos": global_position,
		"z": z_index,
		"scale": scale,
		"modulate": modulate,
		"dir": _current_direction_value,
		"rotation": rotation,
		"skew": skew,
		"centered": centered,
		"offset": offset,
		"flip_h": flip_h,
		"flip_v": flip_v,
	}
	
	_visual_history.push_front(snapshot)
	if _visual_history.size() > _max_history_size:
		_visual_history.pop_back()
		
	_last_recorded_pos = global_position
	_last_recorded_direction = _current_direction_value


func _initialize_own_history() -> void:
	var initial_snapshot = {
		"pos": global_position,
		"z": z_index,
		"scale": scale,
		"modulate": modulate,
		"dir": _current_direction_value,
		"rotation": rotation,
		"skew": skew,
		"centered": centered,
		"offset": offset,
		"flip_h": flip_h,
		"flip_v": flip_v
	}
	_last_recorded_pos = global_position
	_last_recorded_direction = 1
	for i in range(_max_history_size):
		_visual_history.append(initial_snapshot)


func get_visual_snapshot(steps: int) -> Dictionary:
	if _visual_history.is_empty(): return {}
	var index = clampi(steps, 0, _visual_history.size() - 1)
	return _visual_history[index]
