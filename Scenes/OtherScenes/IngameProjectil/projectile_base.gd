class_name ProjectileBase
extends CombatActionBase

## Handles generic movement, animation, and logic for flying projectiles.


## Main Sprite node representing the projectile visually.
@export var sprite: Sprite2D

## The movement speed of the projectile in pixels per second.
@export var speed: float = 400.0

## The maximum distance in pixels this projectile can travel before automatically expiring.
@export var max_distance: float = 1000.0

## The rate at which the projectile's properties degrade over time or distance.
@export var decay: float = 8.0

var direction_vector: Vector2 = Vector2.RIGHT
var direction_string: String = "up"
var travelled_distance: float = 0.0
var projectile_id: String = "arrow"

var _anim_rects: Array = []
var _current_frame_index: int = 0
var _anim_timer: float = 0.0
var _anim_fps: float = 0.0
var _anim_loop: bool = false
var _is_animating: bool = false



func _enter_tree() -> void:
	sprite = get_node_or_null("%Sprite2D")
	super()



## Initializes the projectile state, stats, and visual representation based on direction and ID.
func setup(action_id: String, direction: String, start_pos: Vector2, custom_stats: Dictionary = {}) -> void:
	projectile_id = action_id
	direction_string = direction.to_lower()
	position = start_pos
	
	speed = custom_stats.get("speed", speed)
	damage = custom_stats.get("damage", damage)
	max_distance = custom_stats.get("max_distance", max_distance)
	decay = custom_stats.get("decay", decay)
	
	match direction_string:
		"up": direction_vector = Vector2.UP
		"left": direction_vector = Vector2.LEFT
		"down": direction_vector = Vector2.DOWN
		"right": direction_vector = Vector2.RIGHT
		_: direction_vector = Vector2.UP
	
	if sprite:
		if custom_stats.has("texture"):
			sprite.texture = custom_stats.texture
		sprite.region_enabled = true
		_configure_animation_and_shape()



## Triggers the physics process and plays the initialization effects.
func shoot() -> void:
	super.shoot()
	_play_initial_sound()



## Overridable method to play specific sounds when the projectile is shot.
func _play_initial_sound() -> void:
	pass



## Utility to play a sound effect dynamically from the ZipMediaLoader.
func _play_audio_from_path(path: String) -> void:
	var fx = ZipMediaLoader.get_audio_stream(path)
	if fx:
		var audio_player = AudioStreamPlayer.new()
		audio_player.stream = fx
		audio_player.bus = "SE"
		get_parent().add_child(audio_player)
		audio_player.play()
		audio_player.finished.connect(audio_player.queue_free)



func _physics_process(delta: float) -> void:
	var displacement = direction_vector * speed * delta
	position += displacement
	
	travelled_distance += displacement.length()
	if travelled_distance >= max_distance:
		hit(null)
		
	if _is_animating:
		_process_animation(delta)



## Processes the impact logic and clears the projectile from the scene.
func hit(target: Node2D = null) -> void:
	if _is_destroyed or is_queued_for_deletion():
		return
		
	if target and target.is_in_group("event"):
		pass
	
	_play_audio_from_path("uid://did4aih30hyu7")
	
	destroy()



func _on_body_entered(body: Node2D) -> void:
	if is_instance_valid(player) and body == player:
		return
	hit(body)



func _on_area_entered(area: Area2D) -> void:
	var body = area.get_parent()
	if body and is_instance_valid(player) and body == player:
		return
	hit(body)



func _configure_animation_and_shape() -> void:
	var data = ProjectileConfig.DATA.get(projectile_id)
	
	if not data:
		return
	
	var dir_data = data.get(direction_string, {})
	if dir_data.is_empty():
		dir_data = data.get("up", {})
	
	_anim_rects = dir_data.get("frames", [])
	_anim_fps = data.get("fps", 0)
	_anim_loop = data.get("loop", false)
	
	_is_animating = _anim_fps > 0 and _anim_rects.size() > 1
	_current_frame_index = 0
	
	if not _anim_rects.is_empty():
		sprite.region_rect = _anim_rects[0]

	var shape_data = dir_data.get("shape", {})
	_update_collision_shape(shape_data)



func _update_collision_shape(shape_data: Dictionary) -> void:
	if shape_data.is_empty() or not collision_shape:
		return
		
	var type = shape_data.get("type", "circle")
	var new_pos = shape_data.get("pos", Vector2.ZERO)
	
	collision_shape.position = new_pos
	
	match type:
		"circle":
			if not (collision_shape.shape is CircleShape2D):
				collision_shape.shape = CircleShape2D.new()
			collision_shape.shape.radius = shape_data.get("radius", 5.0)
			
		"rectangle":
			if not (collision_shape.shape is RectangleShape2D):
				collision_shape.shape = RectangleShape2D.new()
			collision_shape.shape.size = shape_data.get("size", Vector2(10, 10))
			
		"capsule":
			if not (collision_shape.shape is CapsuleShape2D):
				collision_shape.shape = CapsuleShape2D.new()
			collision_shape.shape.radius = shape_data.get("radius", 5.0)
			collision_shape.shape.height = shape_data.get("height", 20.0)



func _process_animation(delta: float) -> void:
	_anim_timer += delta
	var frame_time = 1.0 / _anim_fps
	
	if _anim_timer >= frame_time:
		_anim_timer -= frame_time 
		_current_frame_index += 1
		
		if _current_frame_index >= _anim_rects.size():
			if _anim_loop:
				_current_frame_index = 0
			else:
				_current_frame_index = _anim_rects.size() - 1
				_is_animating = false
				
		sprite.region_rect = _anim_rects[_current_frame_index]
