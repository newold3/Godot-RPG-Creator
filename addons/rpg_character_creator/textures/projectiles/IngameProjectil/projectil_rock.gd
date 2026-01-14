extends ProjectileBase

@export var throw_distance: float = 250.0
@export var arc_height: float = 60.0
@export var flight_time: float = 0.55
@export var max_scale: float = 1.5

var _start_pos: Vector2
var _target_pos: Vector2

func setup_projectile(tex: Texture2D, dir_str: String, start_pos: Vector2, p_id: String) -> void:
	super.setup_projectile(tex, dir_str, start_pos, p_id)
	
	set_process(false)
	
	monitoring = false
	monitorable = false
	
	_start_pos = start_pos
	_target_pos = start_pos + (direction_vector * throw_distance)
	
	_start_parabola_tween()

func _start_parabola_tween() -> void:
	var t = create_tween()
	t.set_parallel(true)
	
	t.tween_property(self, "position", _target_pos, flight_time).set_trans(Tween.TRANS_LINEAR)
	
	var arc_tween = create_tween()
	arc_tween.tween_method(_update_height_and_scale, 0.0, 1.0, flight_time).set_trans(Tween.TRANS_LINEAR)
	
	var rot_tween = create_tween()
	rot_tween.tween_property(sprite, "rotation_degrees", 720.0, flight_time).as_relative()
	
	arc_tween.tween_callback(_on_land)

func _update_height_and_scale(progress: float) -> void:
	var height_factor = sin(progress * PI)
	
	sprite.position.y = -height_factor * arc_height
	
	var current_scale = 1.0 + (height_factor * (max_scale - 1.0))
	sprite.scale = Vector2(current_scale, current_scale)

func _on_land() -> void:
	sprite.position.y = 0
	sprite.scale = Vector2(1, 1)
	
	monitoring = true
	monitorable = true
	
	await get_tree().physics_frame
	await get_tree().physics_frame
	
	destroy()
