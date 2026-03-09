extends TextureButton

@export_enum("Left Movement", "Right Movement") var animation_mode: int = 0

func _ready() -> void:
	if animation_mode == 0:
		pivot_offset = Vector2(size.x, size.y * 0.5)
	else:
		pivot_offset = Vector2(0, size.y * 0.5)
	mouse_entered.connect(func(): scale = Vector2(1.1, 1.1))
	mouse_exited.connect(
		func():
			if not is_pressed():
				scale = Vector2(1.0, 1.0)
			else:
				scale = Vector2(1.1, 1.1)
	)
	pressed.connect(
		func():
			scale = Vector2(1.1, 1.1)
			GameManager.play_se(preload("uid://b1yrhtaulew27"))
			var t = create_tween()
			t.tween_property(self, "scale", Vector2(0.9, 0.9) , 0.1)
			t.tween_property(self, "scale", Vector2(1.0, 1.0), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	)
