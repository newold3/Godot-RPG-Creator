@tool
extends ScrollText


var main_tween: Tween


func reset() -> void:
	if main_tween:
		main_tween.kill()
	super()


func start() -> void:
	reset()
	modulate.a = 0.0
	if main_tween:
		main_tween.kill()
	
	await get_tree().process_frame
	main_tween = create_tween()
	main_tween.tween_property(self, "modulate:a", 1.0, 0.5)


func end() -> void:
	if main_tween:
		main_tween.kill()
		
	main_tween = create_tween()
	main_tween.tween_property(self, "modulate:a", 0.0, 0.5)
	main_tween.tween_callback(queue_free)
