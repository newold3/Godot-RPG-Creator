class_name ProjectileBase
extends Area2D

@export var sprite: Sprite2D
@export var collision_shape: CollisionShape2D

@export var speed: float = 400.0
@export var damage: int = 10
@export var max_distance: float = 1000.0

var direction_vector: Vector2 = Vector2.UP
var direction_string: String = "up"
var travelled_distance: float = 0.0
var projectile_id: String = "arrow"

var _anim_rects: Array = []
var _current_frame_index: int = 0
var _anim_timer: float = 0.0
var _anim_fps: float = 0.0
var _is_animating: bool = false


func _ready() -> void:
	set_process(false)


func setup_projectile(tex: Texture2D, dir_str: String, start_pos: Vector2, p_id: String) -> void:
	position = start_pos
	projectile_id = p_id
	direction_string = dir_str.to_lower()
	
	match direction_string:
		"up": direction_vector = Vector2.UP
		"left": direction_vector = Vector2.LEFT
		"down": direction_vector = Vector2.DOWN
		"right": direction_vector = Vector2.RIGHT
		_: direction_vector = Vector2.UP
	
	if sprite:
		if tex:
			sprite.texture = tex
		sprite.region_enabled = true
		
		_configure_animation_and_shape()
	
	if not is_queued_for_deletion():
		set_process(true)


func _process(delta: float) -> void:
	var displacement = direction_vector * speed * delta
	position += displacement
	
	travelled_distance += displacement.length()
	if travelled_distance >= max_distance:
		destroy()
		
	if _is_animating:
		_process_animation(delta)


func _configure_animation_and_shape() -> void:
	var data = ProjectileConfig.DATA.get(projectile_id)
	
	if not data:
		queue_free()
		return
	
	var dir_data = data.get(direction_string, {})
	
	if dir_data.is_empty():
		dir_data = data.get("up", {})
	
	_anim_rects = dir_data.get("frames", [])
	_anim_fps = data.get("fps", 0)
	
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
	if _anim_timer >= (1.0 / _anim_fps):
		_anim_timer = 0.0
		_current_frame_index = (_current_frame_index + 1) % _anim_rects.size()
		sprite.region_rect = _anim_rects[_current_frame_index]


func destroy() -> void:
	queue_free()


func _on_body_entered(body: Node2D) -> void:
	destroy()
