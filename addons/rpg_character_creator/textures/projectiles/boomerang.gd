@tool
extends DefaultProyectileAnimation


func _ready() -> void:
	super()
	%CustomAudioPlayer2D.set_listener_position(Vector2(593, 342))


func set_direction(_direction: String) -> void:
	if direction != "down":
		show_behind_parent = true
	direction = _direction.capitalize()
	movement_vector = 	Vector2.UP if direction == "Up" else \
						Vector2.LEFT if direction == "Left" else \
						Vector2.DOWN if direction == "Down" else \
						Vector2.RIGHT
	
	get_material().set_shader_parameter("alpha", 1.0)
	get_material().set_shader_parameter("use_custom_alpha", true)
	
	play(direction)
	
	var t = create_tween()
	t.tween_method(_move_character, 0, 700, 1.2).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	t.tween_method(_move_character, -700, 0, 1.2).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	t.tween_callback(queue_free)


func _move_character(value: float) -> void:
	value *= get_process_delta_time()
	if direction == "Left":
		position.x -= value
	elif direction == "Right":
		position.x += value
	elif direction == "Up":
		position.y -= value
	elif direction == "Down":
		position.y += value
	
	rotation += 8 * get_process_delta_time()
