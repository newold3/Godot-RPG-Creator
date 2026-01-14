class_name SimpleFollower
extends CharacterBody2D


## How many "distance steps" this follower lags behind.
@export var spacing_steps: int = 24
## Constant speed of the walk animation (frames per second).
@export var animation_fps: float = 19.0
## Time the walk animation persists after movement stops.
@export var walk_persist_time: float = 0.07

var speed: float = 14


var _is_fading: bool = false
var is_invalid_event: bool = false
var target_node: Node2D
var follower_id: int = 0

var current_direction: int = CharacterBase.DIRECTIONS.DOWN
var current_animation: String = "idle"
var current_frame: int = 0
var current_weapon_data: Dictionary = {}
var current_weapon_images: Dictionary = {}

var _frame_timer: float = 0.0
var _idle_timer: float = 0.0
var _last_pos: Vector2 = Vector2.ZERO

## Flag to control animation and transform manually, bypassing follower logic.
var is_manual_animation: bool = false

var is_jumping_locally: bool = false
var is_force_walking: bool = false
var target_position: Vector2
var jump_snapshot: Dictionary
var local_tween: Tween


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


func _process_next_frame(delta: float) -> void:
	_frame_timer += delta
	if _frame_timer >= (1.0 / animation_fps):
		current_frame += 1
		_frame_timer = 0.0

	run_animation()


func _process(delta: float) -> void:
	if is_manual_animation:
		return

	if not target_node or is_invalid_event or _is_fading or is_jumping_locally:
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
		var my_step_offset = follower_id * spacing_steps
		var snapshot = GameManager.current_player.get_history_step(my_step_offset)
		
		if not snapshot.is_empty():
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
	
	# Configuración inicial
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
	modulate = snap.modulate
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
	if not is_inside_tree() or _is_fading:
		return
	
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


func get_shadow_data() -> Dictionary:
	if is_queued_for_deletion() or has_meta("_disable_shadow"):
		return {}
	
	var shadow = {
		"main_node": body,
		"sprites": [wings, mainhand_back, body, offhand_front],
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


func get_body_region_rect() -> Rect2:
	var node = get_node_or_null("%Body")
	if node:
		return node.region_rect

	return Rect2()


func reset_movement_queue() -> void:
	pass


## Enables or disables manual animation control.
## When enabled, follower logic (movement and auto-animation) is bypassed.
func set_manual_animation_active(active: bool) -> void:
	is_manual_animation = active


## Manually updates the follower's transform and visual properties.
## Dictionary keys: modulate, scale, position, z_index, rotation, region_rect.
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
