## simple_follower.gd
class_name SimpleFollower
extends CharacterBody2D


## Distance to maintain from the target.
@export var stop_distance: float = 26.0
## Number of physics frames to delay.
@export var frame_delay: int = 15
## Speed to interpolate position visually.
@export var follow_speed: float = 8.0
## Constant speed of the walk animation (frames per second).
@export var animation_fps: float = 24.0
## Time the walk animation persists after movement stops.
@export var walk_persist_time: float = 0.07


var _frame_queue: Array[Dictionary] = []
var _is_fading: bool = false
var is_invalid_event: bool = false
var target_node: Node2D
var follower_id: int = 0
var _target_snapshot: Dictionary

var current_direction: int = CharacterBase.DIRECTIONS.DOWN
var current_animation: String = "idle"
var current_frame: int = 0
var current_weapon_data: Dictionary = {}
var current_weapon_images: Dictionary = {}

var _frame_timer: float = 0.0
var _idle_timer: float = 0.0
var _last_pos: Vector2 = Vector2.ZERO
## Tracks the target's position in the last physics frame to detect warps.
var _last_target_pos_check: Vector2 = Vector2.ZERO


@onready var animations = {
	"player": RPGSYSTEM.player_animations_data.animations,
	"weapon": RPGSYSTEM.weapon_animations_data.animations
}
@onready var wings: Sprite2D = %WingsBack
@onready var hands_back: Sprite2D = %HandsBack
@onready var body: Sprite2D = %Body
@onready var hands_front: Sprite2D = %HandsFront


func _ready() -> void:
	for sprite in [wings, hands_back, body, hands_front]:
		sprite.region_enabled = true
	
	_last_pos = global_position
	_initialize_queue()


func _physics_process(_delta: float) -> void:
	if not target_node or is_invalid_event:
		return
	_handle_target_warp()
	
	var current_snap = _get_target_snapshot()
	_frame_queue.push_back(current_snap)
	
	if _frame_queue.size() > frame_delay:
		_target_snapshot = _frame_queue.pop_front()
	
	_last_target_pos_check = target_node.global_position


func _process(delta: float) -> void:
	if _target_snapshot.is_empty() or _is_fading:
		return
		
	var dist_to_target = global_position.distance_to(target_node.global_position)
	
	if dist_to_target > stop_distance:
		global_position = global_position.lerp(_target_snapshot.pos, follow_speed * delta)
		
		if follower_id == 1:
			current_direction = _target_snapshot.direction
		else:
			_update_facing_direction()
	else:
		_update_facing_direction()
	
	var is_moving_this_frame = global_position.distance_to(_last_pos) > 0.1
	_last_pos = global_position
	
	if is_moving_this_frame:
		_idle_timer = walk_persist_time
		current_animation = "walk"
		
		_frame_timer += delta
		var frame_duration = 1.0 / animation_fps
		if _frame_timer >= frame_duration:
			current_frame += 1
			_frame_timer = 0.0
	else:
		_idle_timer = max(0.0, _idle_timer - delta)
		if _idle_timer <= 0.0:
			current_animation = "idle"
			current_frame = 0
			_frame_timer = 0.0
	
	run_animation()


func _update_facing_direction() -> void:
	if not target_node:
		return
		
	var diff = target_node.global_position - global_position
	if diff.length() < 2.0:
		return
		
	if abs(diff.x) > abs(diff.y):
		current_direction = CharacterBase.DIRECTIONS.RIGHT if diff.x > 0 else CharacterBase.DIRECTIONS.LEFT
	else:
		current_direction = CharacterBase.DIRECTIONS.DOWN if diff.y > 0 else CharacterBase.DIRECTIONS.UP


func run_animation() -> void:
	if not is_inside_tree() or _is_fading:
		return
	
	if current_animation == "idle" and "idle" in current_weapon_images:
		hands_back.texture = current_weapon_images.idle.back
		hands_front.texture = current_weapon_images.idle.front
	elif current_animation == "walk" and "walk" in current_weapon_images:
		hands_back.texture = current_weapon_images.walk.back
		hands_front.texture = current_weapon_images.walk.front
	
	var anim_data = get_current_animation()
	var weapon_anim_data = get_current_weapon_animation()

	if anim_data.is_empty() and weapon_anim_data.is_empty():
		return
	
	if anim_data.is_empty():
		anim_data = weapon_anim_data
	
	if weapon_anim_data.is_empty():
		weapon_anim_data = anim_data
	
	if current_frame >= anim_data.frames.size():
		current_frame = 0

	var weapon_current_frame = min(current_frame, weapon_anim_data.frames.size() - 1)
	var normal_animation_current_frame = min(current_frame, anim_data.frames.size() - 1)
	
	var player_frame: Array = anim_data.frames[normal_animation_current_frame]
	var weapon_frame: Array = weapon_anim_data.frames[weapon_current_frame]
	var player_size = anim_data.frame_size
	
	var rect = Rect2(player_frame[0], player_frame[1], player_size[0], player_size[1])
	body.region_rect = rect
	wings.region_rect = rect
	
	if (
		(hands_back.texture and hands_back.texture.get_size() == body.texture.get_size()) or
		(hands_front.texture and hands_front.texture.get_size() == body.texture.get_size())
	):
		hands_back.region_rect = body.region_rect
	else:
		hands_back.region_rect = Rect2(weapon_frame[0], weapon_frame[1], 192, 192)
		
	hands_front.region_rect = hands_back.region_rect


func get_current_animation() -> Dictionary:
	if not animations:
		return {}
		
	var dir_key = CharacterBase.DIRECTIONS.find_key(current_direction)
	if dir_key == null:
		return {}
	
	var animation_id = current_animation.to_lower() + "_" + dir_key.to_lower()

	for animation in animations.player:
		if animation.id == animation_id:
			return animation
		
	return {}


func get_current_weapon_animation() -> Dictionary:
	if not animations:
		return {}
		
	var dir_key = CharacterBase.DIRECTIONS.find_key(current_direction)
	if dir_key == null:
		return {}
	
	var animation_id = current_animation.to_lower() + "_" + dir_key.to_lower()
	
	if ["dagger2"].has(current_weapon_data.get("id", "")) and ["idle", "walk"].has(current_animation.to_lower()):
		animation_id = "small_" + animation_id

	for animation in animations.weapon:
		if animation.id == animation_id:
			return animation

	return {}


func _get_target_snapshot() -> Dictionary:
	if not target_node:
		return {}
	
	return {
		"direction": target_node.get("current_direction"),
		"animation": target_node.get("current_animation"),
		"pos": target_node.global_position,
		"z": target_node.z_index,
		"scale": target_node.scale,
		"modulate": target_node.modulate
	}


func _initialize_queue() -> void:
	_frame_queue.clear()
	var initial_snap = _get_target_snapshot()
	initial_snap.pos = global_position
	
	for i in range(frame_delay):
		_frame_queue.push_back(initial_snap.duplicate())
	
	_target_snapshot = initial_snap.duplicate()
	_last_target_pos_check = target_node.global_position if target_node else global_position


## Adjusts follower position and movement history when the target warps.
func _handle_target_warp() -> void:
	if _last_target_pos_check == Vector2.ZERO: return
	
	var distance_sq = target_node.global_position.distance_squared_to(_last_target_pos_check)
	
	if distance_sq > 65536:
		var warp_offset = target_node.global_position - _last_target_pos_check
		
		global_position += warp_offset
		_last_pos += warp_offset
		
		for snap in _frame_queue:
			snap.pos += warp_offset
		
		if not _target_snapshot.is_empty():
			_target_snapshot.pos += warp_offset


func get_character_sprite() -> Sprite2D:
	return body


func get_shadow_data() -> Dictionary:
	if is_queued_for_deletion() or has_meta("_disable_shadow"):
		return {}
	
	var shadow = {
		"main_node": body,
		"sprites": [wings, hands_back, body, hands_front],
		"position": body.global_position,
		"feet_offset": 16
	}
	
	if GameManager.current_map:
		shadow.cell = Vector2i(global_position / Vector2(GameManager.current_map.tile_size))
	
	return shadow


func update_appearance_cascade(actor_id: int, instant: bool = false) -> void:
	_is_fading = true
	var actor = RPGSYSTEM.database.actors[actor_id]
	name = "Follower_" + actor.name
	var char_data: RPGLPCCharacter = load(actor.character_data_file)
	
	if FileAccess.file_exists(char_data.equipment_parts.mainhand.config_path):
		var f = FileAccess.open(char_data.equipment_parts.mainhand.config_path, FileAccess.READ)
		current_weapon_data = JSON.parse_string(f.get_as_text())
		f.close()
	else:
		current_weapon_data = {}
	
	modulate.a = 1.0 if instant else 0.0
	
	var baker = GameManager.get_character_baker()
	if baker:
		var bake_id = "follower_" + str(get_instance_id())
		baker.request_bake_character(bake_id, char_data, "walk", wings, hands_back, body, hands_front)
		await baker.character_baked
	
	if not instant:
		var tween_in = create_tween()
		tween_in.tween_property(self, "modulate:a", 1.0, 0.4)
		await tween_in.finished
		
	_is_fading = false


func _manage_animator() -> void:
	var node = get_node_or_null("%MainAnimator")
	if node and node is AnimationPlayer and node.has_animation("Breathing"):
		if node.is_playing():
			node.stop()
		var restart_time: float = randf_range(0.1, 1.2)
		var t = create_tween()
		t.tween_interval(restart_time)
		t.tween_callback(
			func():
				node.speed_scale = randf_range(0.6, 0.7)
				node.play("Breathing")
		)
