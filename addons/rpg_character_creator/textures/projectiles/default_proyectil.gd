@tool
class_name DefaultProyectileAnimation
extends AnimatedSprite2D

var blend_color: Color
var direction: String = "up"
var movement_vector: Vector2 = Vector2.UP
var speed: int = 900


func _ready() -> void:
	position = Vector2.ZERO
	get_material().set_shader_parameter("alpha", 1.0)
	get_material().set_shader_parameter("use_custom_alpha", true)
	set_process(false)


func set_blend_color(blend_color: int) -> void:
	self.blend_color = Color(blend_color)


func set_direction(_direction: String) -> void:
	direction = _direction.capitalize()
	movement_vector = 	Vector2.UP if direction == "Up" else \
						Vector2.LEFT if direction == "Left" else \
						Vector2.DOWN if direction == "Down" else \
						Vector2.RIGHT
	
	get_material().set_shader_parameter("alpha", 1.0)
	get_material().set_shader_parameter("use_custom_alpha", true)
	
	play(direction)

	var t = create_tween()
	t.tween_interval(2.5)
	t.tween_interval(0.001)
	t.set_parallel(true)
	t.tween_property(get_material(), "shader_parameter/alpha", 0.0, 1.5).set_trans(Tween.TRANS_CIRC).set_ease(Tween.EASE_IN)
	t.set_parallel(false)
	t.tween_interval(0.1)
	t.tween_callback(queue_free)
	
	set_process(true)


func _process(delta: float) -> void:
	var displacement = movement_vector * speed * delta
	position += displacement
	if direction == "Left" or direction == "Right":
		position.y += 25 * delta
