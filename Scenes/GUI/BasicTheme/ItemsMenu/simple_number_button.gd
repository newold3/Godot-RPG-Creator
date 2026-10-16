extends Button

var selected: bool = false


func _ready() -> void:
	pivot_offset = size * 0.5
	mouse_entered.connect(func(): scale = Vector2(1.3, 1.3))
	mouse_exited.connect(
		func():
			if not is_pressed():
				scale = Vector2(1.0, 1.0)
			else:
				scale = Vector2(1.3, 1.3)
	)
	pressed.connect(
		func():
			scale = Vector2(1.3, 1.3)
			GameManager.play_se(preload("uid://b1yrhtaulew27"))
	)
