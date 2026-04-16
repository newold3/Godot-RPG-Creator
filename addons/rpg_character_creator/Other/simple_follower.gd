class_name SimpleFollower
extends CharacterBody2D


## How many "distance steps" this follower lags behind.
@export var spacing_steps: int = 16

## Constant speed of the walk animation (frames per second).
@export var animation_fps: float = 19.0

## Time the walk animation persists after movement stops.
@export var walk_persist_time: float = 0.07

## Maximum time (in seconds) the follower should take to catch up after waiting.
@export var max_catch_up_time: float = 2.5

## The rate at which the game registers snapshots (usually 60 per second).
@export var snapshots_per_second: float = 60.0

var speed: float = 14

var _is_fading: bool = false
var is_invalid_event: bool = false
var target_node: Node2D
var follower_id: int = 0

var current_direction: int = CharacterBase.DIRECTIONS.DOWN
var fixed_direction: int = -1
var current_animation: String = "idle"
var current_frame: int = 0
var current_weapon_data: Dictionary = {}
var current_weapon_images: Dictionary = {}

var _frame_timer: float = 0.0
var _idle_timer: float = 0.0
var _last_pos: Vector2 = Vector2.ZERO

var is_manual_animation: bool = false
var is_sync_active: bool = true
var is_jumping_locally: bool = false
var is_force_walking: bool = false
var target_position: Vector2
var jump_snapshot: Dictionary
var local_tween: Tween

var _is_waiting: bool = false
var _extra_history_offset_f: float = 0.0
var _last_valid_snapshot: Dictionary = {}
var _last_player_head_pos: Vector2 = Vector2.ZERO

var is_fading_transition: bool = false

@onready var animations = {
	"player": RPGSYSTEM.player_animations_data.animations,
	"weapon": RPGSYSTEM.weapon_animations_data.animations
}
@onready var wings: Sprite2D = %WingsBack
@onready var offhand_back: Sprite2D = %OffhandBack
@onready var mainhand_back: Sprite2D = %MainHandBack
@onready var body: Sprite2D = %Body
@onready var offhand_front: Sprite2D = %OffhandFront
@onready var mainhand_front: Sprite2D = %MainHandFront


func _ready() -> void:
	for sprite in [wings, mainhand_back, body, offhand_front]:
		sprite.region_enabled = true
	
	_last_pos = global_position

	if target_node:
		global_position = target_node.global_position


func get_direction() -> CharacterBase.DIRECTIONS:
	return current_direction


func get_current_tile() -> Vector2i:
	if GameManager.current_map:
		return GameManager.current_map.get_tile_from_position(global_position)
	
	return Vector2i()


func get_current_virtual_tile() -> Vector2i:
	return get_current_tile()


func _process_next_frame(delta: float) -> void:
	_frame_timer += delta
	if _frame_timer >= (1.0 / animation_fps):
		current_frame += 1
		_frame_timer = 0.0

	run_animation()


func _get_index_at_distance(target_distance_px: float) -> int:
	var player = GameManager.current_player
	if not player or not "movement_history" in player:
		return 0
		
	var history = player.movement_history
	if history.is_empty():
		return 0
		
	var accumulated_dist: float = 0.0
	var current_idx = history.size() - 1
	
	while current_idx > 0:
		var pos_curr = history[current_idx].pos
		var pos_prev = history[current_idx - 1].pos
		
		accumulated_dist += pos_curr.distance_to(pos_prev)
		
		if accumulated_dist >= target_distance_px:
			return (history.size() - 1) - current_idx
			
		current_idx -= 1
	
	return history.size() - 1


func _process(delta: float) -> void:
	if is_manual_animation:
		return
	
	if GameManager.current_player and GameManager.current_player.is_on_vehicle:
		modulate.a -= (5 + follower_id) * delta
		
	if not is_sync_active:
		current_animation = "idle"
		_process_next_frame(delta)
		return

	if not target_node or is_invalid_event or is_jumping_locally:
		if is_jumping_locally:
			_process_next_frame(delta)
		return
	
	if is_force_walking:
		_approach_launch_pad(target_position, delta)
		var dist_to_launch = global_position.distance_to(target_position)
		if dist_to_launch < 4:
			is_force_walking = false
			target_position = Vector2.ZERO
			current_direction = jump_snapshot.direction
			var rect = jump_snapshot.region_rect
			var flip = jump_snapshot.flip_h
			body.region_rect = rect
			body.flip_h = flip
			wings.region_rect = rect
			wings.flip_h = flip
			_trigger_local_jump(jump_snapshot)
		return
	
	if GameManager.current_player:
		var player_moved: bool = false
		var head_snapshot = GameManager.current_player.get_history_step(0)
		
		if not head_snapshot.is_empty():
			if _last_player_head_pos != head_snapshot.pos:
				player_moved = true
			_last_player_head_pos = head_snapshot.pos

		var map_tile_size = GameManager.get_map_tile_size().x if GameManager.current_map else 64.0
		var dist_per_follower = float(map_tile_size)
		var total_needed_dist = follower_id * dist_per_follower

		var dynamic_spacing_steps = _get_index_at_distance(total_needed_dist)

		var base_offset = dynamic_spacing_steps

		if _is_waiting:
			if player_moved:
				_extra_history_offset_f += 1.0
			
			current_animation = "idle"
			_process_next_frame(delta)
			return
		else:
			if _extra_history_offset_f > 0.0:
				var catch_up_rate = _extra_history_offset_f / max_catch_up_time
				catch_up_rate = max(catch_up_rate, 15.0) 
				
				if not player_moved:
					catch_up_rate += snapshots_per_second
					
				_extra_history_offset_f = max(0.0, _extra_history_offset_f - (catch_up_rate * delta))

		var my_step_offset = base_offset + int(_extra_history_offset_f)

		var snapshot = GameManager.current_player.get_history_step(my_step_offset)
		
		if not snapshot.is_empty():
			_last_valid_snapshot = snapshot
			if snapshot.get("event") == "start_jump":
				var launch_pad = snapshot.get("jump_start_pos", global_position)
				var orig = snapshot.get("followers_position")[follower_id]
				var dist_to_launch = orig.distance_to(launch_pad)
				if dist_to_launch > 4:
					global_position = orig
					_approach_launch_pad(launch_pad, delta)
					is_force_walking = true
					target_position = launch_pad
					jump_snapshot = snapshot
				else:
					_trigger_local_jump(snapshot)
					
			elif snapshot.get("event") == "end_jump":
				is_jumping_locally = false
			else:
				_process_follower_logic(snapshot, delta)


## Pauses or resumes the follower's progression through the player's movement queue.
func set_wait(waiting: bool) -> void:
	_is_waiting = waiting


func _approach_launch_pad(target_pos: Vector2, delta: float) -> void:
	global_position = global_position.lerp(target_pos, speed * delta)
	
	current_animation = "walk"
	_idle_timer = walk_persist_time
	
	var dir_vector = target_pos - global_position
	if abs(dir_vector.x) > abs(dir_vector.y):
		current_direction = CharacterBase.DIRECTIONS.RIGHT if dir_vector.x > 0 else CharacterBase.DIRECTIONS.LEFT
	else:
		current_direction = CharacterBase.DIRECTIONS.DOWN if dir_vector.y > 0 else CharacterBase.DIRECTIONS.UP
		
	run_animation()


func _trigger_local_jump(snap: Dictionary) -> void:
	if is_jumping_locally: return
	
	is_jumping_locally = true
	
	var start_pos = global_position
	var end_pos = snap.get("jump_target", start_pos)
	var jump_height = snap.get("jump_height", 30.0)
	var jump_duration = snap.get("jump_duration", 0.35)
	
	current_animation = "start_jump"
	current_frame = 0
	run_animation()
	
	var initial_delay = 0.05
	
	if local_tween: local_tween.kill()
	
	local_tween = create_tween()
	local_tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	
	if initial_delay > 0:
		local_tween.tween_interval(initial_delay * follower_id)
	
	local_tween.tween_property(self, "scale", Vector2(0.94, 0.55), 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	local_tween.tween_interval(0.02)
	
	local_tween.set_parallel(true)
	
	local_tween.tween_property(self, "scale", Vector2(1.02, 1.04), 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	local_tween.tween_method(func(t):
		global_position = start_pos.lerp(end_pos, t) - Vector2(0, sin(t * PI) * jump_height)
	, 0.0, 1.0, jump_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	
	local_tween.tween_callback(func():
		current_animation = "end_jump"
		current_frame = 0
		run_animation()
	).set_delay(jump_duration * 0.65)
	
	local_tween.set_parallel(false)
	local_tween.tween_interval(0.01)
	
	local_tween.tween_property(self, "scale", Vector2(1.1, 0.90), 0.1).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CIRC)
	local_tween.tween_property(self, "scale", Vector2.ONE, 0.15).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)
	
	local_tween.tween_callback(func():
		is_jumping_locally = false
	)


func _process_follower_logic(snap: Dictionary, delta: float) -> void:
	_apply_snapshot_transform(snap)
	
	var dist_moved = global_position.distance_squared_to(_last_pos)
	_last_pos = global_position
	
	if dist_moved > 0.001:
		_idle_timer = walk_persist_time
		current_animation = "walk"
		_apply_snapshot_visuals(snap)
		
	else:
		_idle_timer = max(0.0, _idle_timer - delta)
		
		if _idle_timer <= 0.0:
			current_animation = "idle"
			
			_frame_timer += delta
			if _frame_timer >= (1.0 / animation_fps):
				current_frame += 1
				_frame_timer = 0.0
			
			run_animation()
		else:
			_apply_snapshot_visuals(snap)


func _apply_snapshot_transform(snap: Dictionary) -> void:
	global_position = snap.pos
	scale = snap.scale
	rotation = snap.rotation
	
	var snap_modulate: Color = snap.get("modulate", Color.WHITE)
	
	if is_fading_transition:
		var current_alpha: float = modulate.a
		modulate = snap_modulate
		modulate.a = min(current_alpha, snap_modulate.a)
	else:
		modulate = snap_modulate
		
	z_index = snap.z_index
	current_direction = snap.direction


func _apply_snapshot_visuals(snap: Dictionary) -> void:
	var rect = snap.region_rect
	var flip = snap.flip_h
	
	body.region_rect = rect
	body.flip_h = flip
	wings.region_rect = rect
	wings.flip_h = flip
	
	_update_weapon_textures()
	
	if (mainhand_back.texture and mainhand_back.texture.get_size() == body.texture.get_size()):
		mainhand_back.region_rect = rect
		mainhand_back.flip_h = flip
		
	if (offhand_front.texture and offhand_front.texture.get_size() == body.texture.get_size()):
		offhand_front.region_rect = rect
		offhand_front.flip_h = flip


func _update_weapon_textures() -> void:
	if current_animation == "idle" and "idle" in current_weapon_images:
		mainhand_back.texture = current_weapon_images.idle.back
		offhand_front.texture = current_weapon_images.idle.front
	elif current_animation == "walk" and "walk" in current_weapon_images:
		mainhand_back.texture = current_weapon_images.walk.back
		offhand_front.texture = current_weapon_images.walk.front


func run_animation() -> void:
	if not is_inside_tree():
		return
	
	if fixed_direction != -1:
		current_direction = fixed_direction
	
	_update_weapon_textures()
	
	var anim_data = get_current_animation()
	var weapon_anim_data = get_current_weapon_animation()

	if anim_data.is_empty() and weapon_anim_data.is_empty():
		return
	
	if anim_data.is_empty(): anim_data = weapon_anim_data
	if weapon_anim_data.is_empty(): weapon_anim_data = anim_data
	
	if current_frame >= anim_data.frames.size():
		if anim_data.get("loop"):
			current_frame = 0
		else:
			current_frame = anim_data.frames.size() - 1

	var weapon_current_frame = min(current_frame, weapon_anim_data.frames.size() - 1)
	var normal_animation_current_frame = min(current_frame, anim_data.frames.size() - 1)
	
	var player_frame: Array = anim_data.frames[normal_animation_current_frame]
	var weapon_frame: Array = weapon_anim_data.frames[weapon_current_frame]
	var player_size = anim_data.frame_size
	
	var rect = Rect2(player_frame[0], player_frame[1], player_size[0], player_size[1])
	
	body.region_rect = rect
	wings.region_rect = rect
	
	if (
		(mainhand_back.texture and mainhand_back.texture.get_size() == body.texture.get_size()) or
		(offhand_front.texture and offhand_front.texture.get_size() == body.texture.get_size())
	):
		mainhand_back.region_rect = body.region_rect
	else:
		mainhand_back.region_rect = Rect2(weapon_frame[0], weapon_frame[1], 192, 192)
		
	offhand_front.region_rect = mainhand_back.region_rect


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


func get_character_sprite() -> Sprite2D:
	return body


func get_icon() -> Variant:
	var tex: Variant
	
	#if has_meta("actor_id"):
		#var actor_id = get_meta("actor_id")
		#if typeof(actor_id) == TYPE_INT and RPGSYSTEM.database.actors.size() > actor_id and actor_id > 0:
			#var actor = RPGSYSTEM.database.actors[actor_id]
			#tex = actor.icon
	
	return tex


func get_shadow_data() -> Dictionary:
	if is_queued_for_deletion() or has_meta("_disable_shadow"):
		return {}
		
	var tile_size = GameManager.get_map_tile_size()
	var base_pos = body.global_position
	#base_pos.y += tile_size.y * 0.5
	
	var shadow_dict = {
		"position": base_pos,
		"textures": [],
		"positions": [],
		"regions": [],
		"feet_offsets": [[4, 4, 0]],
		"mask_offsets": [],
		"alpha": body.modulate.a,
		"scale": body.scale,
		"rotation": body.rotation,
		"flip_h": false
	}
	
	var sprites_to_check = [wings, mainhand_back, body, offhand_front]
	
	for s in sprites_to_check:
		if is_instance_valid(s) and s.visible and s.modulate.a > 0.0 and s.texture:
			shadow_dict.textures.append(s.texture)
			shadow_dict.positions.append(base_pos)
			if s.region_enabled:
				shadow_dict.regions.append(s.region_rect)
			else:
				shadow_dict.regions.append(Rect2(Vector2.ZERO, s.texture.get_size()))
			shadow_dict.feet_offsets.append(16.0)
			shadow_dict.mask_offsets.append(Vector2.ZERO)
			if s.flip_h:
				shadow_dict.flip_h = true
				
	if shadow_dict.textures.is_empty():
		return {}
		
	return shadow_dict


func update_appearance_cascade(actor_id: int, instant: bool = false) -> void:
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
		baker.request_bake_character(
			bake_id, char_data, "walk", wings,
			offhand_back,
			mainhand_back,
			body,
			offhand_front,
			offhand_front,
			get_meta("actor_id") if has_meta("actor_id") else -1
		)
		await baker.character_baked
	
	if not instant:
		var tween_in = create_tween()
		tween_in.tween_property(self, "modulate:a", 1.0, 0.4)
		await tween_in.finished


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


func get_body_region_rect() -> Rect2:
	var node = get_node_or_null("%Body")
	if node:
		return node.region_rect

	return Rect2()


func reset_movement_queue() -> void:
	pass


func set_manual_animation_active(active: bool) -> void:
	is_manual_animation = active


func update_manual_state(data: Dictionary) -> void:
	if not is_manual_animation:
		return
		
	if "modulate" in data:
		modulate = data.modulate
	
	if "scale" in data:
		scale = data.scale
		
	if "position" in data:
		global_position = data.position
		
	if "z_index" in data:
		z_index = data.z_index
		
	if "rotation" in data:
		rotation = data.rotation
		
	if "region_rect" in data:
		var rect = data.region_rect
		var flip = data.get("flip_h", false)
		
		body.region_rect = rect
		body.flip_h = flip
		wings.region_rect = rect
		wings.flip_h = flip
		
		if (mainhand_back.texture and mainhand_back.texture.get_size() == body.texture.get_size()):
			mainhand_back.region_rect = rect
			mainhand_back.flip_h = flip
		if (offhand_front.texture and offhand_front.texture.get_size() == body.texture.get_size()):
			offhand_front.region_rect = rect
			offhand_front.flip_h = flip


func disappear(fade_time: float = 0.5) -> void:
	is_manual_animation = true
	is_sync_active = false
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, fade_time)
	tween.tween_callback(set.bind("is_manual_animation", false))


func appear(fade_time: float = 0.5) -> void:
	if is_instance_valid(target_node):
		global_position = target_node.global_position
		_last_pos = global_position
		
	is_sync_active = true
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, fade_time)


func get_global_mouth_position() -> Vector2:
	var mouth = get_node_or_null("%Mouth")
	if mouth:
		return mouth.global_position
	
	return Vector2.ZERO


func destroy(move_time: float = 0.5) -> void:
	is_sync_active = false
	var tween = create_tween().set_parallel(true)
	
	if is_instance_valid(target_node):
		tween.tween_property(self, "global_position", target_node.global_position, move_time).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		
	tween.tween_property(self, "modulate:a", 0.0, move_time)
	
	await tween.finished
	queue_free()
