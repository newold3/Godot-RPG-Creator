extends RichTextLabel


func set_data(contents: String, initial_position: Vector2) -> void:
	text = contents
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	global_position = initial_position - Vector2(size.x / 2, size.y)
	_start()


func _start() -> void:
	var t = create_tween()
	t.set_parallel(true)
	t.tween_property(self, "modulate", Color.WHITE, 0.15)
	t.tween_property(self, "position:y", position.y - 30, 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_property(self, "position:y", position.y - 35, 0.4).set_delay(1)
	t.tween_property(self, "modulate", Color.TRANSPARENT, 0.4).set_delay(1)
	t.tween_interval(0.01)
	t.set_parallel(false)
	t.tween_callback(queue_free)
