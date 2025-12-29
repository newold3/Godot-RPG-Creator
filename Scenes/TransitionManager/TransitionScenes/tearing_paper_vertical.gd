@tool
extends GameTransition



const TEARING_PAPER = preload("res://Assets/Sounds/SE/tearing_paper.ogg")

@onready var audio_stream_player: AudioStreamPlayer = $AudioStreamPlayer


func start() -> void:
	%BrokenPageLeftMask.texture = background_image
	%BrokenPageRightMask.texture = background_image
	%FinalTexture.texture = %Pass1.get_texture()
	
	if main_tween:
		main_tween.kill()
	
	audio_stream_player.stream = TEARING_PAPER
	audio_stream_player.play()
	
	var left_part = %BrokenPageLeftMask
	var right_part = %BrokenPageRightMask
	
	left_part.visible = true
	right_part.visible = true
	
	main_tween = create_tween()
	main_tween.set_parallel(true)
	var t = transition_time * 0.15
	main_tween.tween_property(left_part, "rotation", -0.4, t)
	main_tween.tween_property(right_part, "rotation", 0.4, t)
	main_tween.set_parallel(false)
	main_tween.tween_interval(0.01)
	main_tween.set_parallel(true)
	t = transition_time * 0.85
	main_tween.tween_property(left_part, "position:x", 26, t)
	main_tween.tween_property(right_part, "position:x", 1110, t)
	t = transition_time * 0.65
	var t2 = transition_time * 0.25
	main_tween.tween_property(left_part, "modulate:a", 0.0, t2).set_delay(t)
	main_tween.tween_property(right_part, "modulate:a", 0.0, t2).set_delay(t)
	
	main_tween.set_parallel(false)
	main_tween.tween_interval(0.01)
	
	main_tween.tween_callback(left_part.set.bind("visible", false))
	main_tween.tween_callback(right_part.set.bind("visible", false))

	main_tween.tween_callback(end_animation)


func end() -> void:
	if main_tween:
		main_tween.kill()
	
	main_tween = create_tween()
	main_tween.tween_property(self, "modulate:a", 0.0, transition_time)
	main_tween.tween_callback(end_animation)
	
	await main_tween.finished # Wait to finish animation before remove scene
	
	super() # queue free
