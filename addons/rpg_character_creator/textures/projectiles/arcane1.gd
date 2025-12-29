@tool
extends DefaultProyectileAnimation

var timer: float = 0.0

func _ready() -> void:
	speed = 400
	super()
	$AnimationPlayer.play("rock_animation")
	$GPUParticles2D.get_process_material().color = blend_color


func _process(delta: float) -> void:
	timer += delta * 8
	
	var movement_vector: Vector2 = Vector2.ZERO
	var vertical_oscillation: float = sin(timer) * 2.5
	
	match direction:
		"Left":
			movement_vector = Vector2(-1, 0)
			position.y += 25 * delta
			position.x += vertical_oscillation
		"Right":
			movement_vector = Vector2(1, 0)
			position.y += 25 * delta
			position.x -= vertical_oscillation
		"Up":
			movement_vector = Vector2(0, -1)
			position.x += 25 * delta
			position.y += vertical_oscillation
		"Down":
			movement_vector = Vector2(0, 1)
			position.x += 25 * delta
			position.y -= vertical_oscillation
	
	position += movement_vector * speed * delta
		
