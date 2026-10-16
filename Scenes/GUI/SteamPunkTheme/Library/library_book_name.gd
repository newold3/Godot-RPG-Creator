extends GuiCoreLibraryBookTooltip

func _play_start_animation() -> void:
	modulate = Color.TRANSPARENT
	pivot_offset = size * 0.5
	scale = Vector2(0.8, 0.8)
	
	var t = create_tween().set_parallel(true)
	t.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(self, "modulate", Color.WHITE, 0.35)
	t.tween_property(self, "scale", Vector2(1.0, 1.0), 0.35)


func _play_end_animation() -> void:
	var t = create_tween().set_parallel(true)
	t.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	t.tween_property(self, "modulate", Color.TRANSPARENT, 0.2)
	t.tween_property(self, "scale", Vector2(0.8, 0.8), 0.2)
	t.set_parallel(false)
	t.tween_callback(queue_free)
