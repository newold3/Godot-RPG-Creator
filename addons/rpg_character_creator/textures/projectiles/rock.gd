@tool
extends DefaultProyectileAnimation


var initial_impulse = -200.0

func _ready() -> void:
	speed = 450
	super()
	$AnimationPlayer.play("rock_animation")


func set_direction(_direction: String) -> void:
	super(_direction)
	if direction == "Up" or direction == "Down":
		var t = create_tween()
		t.tween_property(self, "position:x", position.x - 15, 2.3).set_delay(0.2)
		


func _process(delta: float) -> void:
	if direction == "Left" or direction == "Right":
		position.y += 20 * delta + initial_impulse * delta
		initial_impulse += 80 * delta * 12
	elif direction == "Up":
		var v = remap(initial_impulse, 0.0, -200.0, 0.0, 1.0)
		var mov = 400 * delta * v
		position.y -= mov - speed * delta
		initial_impulse = clamp(initial_impulse + 200 * delta, -200, -0.55)
	elif direction == "Down":
		var v = remap(initial_impulse, 0.0, -200.0, 0.0, 1.0)
		var mov = 400 * delta * v
		position.y += mov - speed * delta
		initial_impulse = clamp(initial_impulse + 200 * delta, -200, -0.55)

	super(delta)
