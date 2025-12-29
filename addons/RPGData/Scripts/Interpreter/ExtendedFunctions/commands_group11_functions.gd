class_name CommandsGroup11
extends CommandHandlerBase


# Command Play Video (Code 92), button_id = 74
# Code 92 parameters { path, wait, loop, fadein, fadeout, color }
func _command_0092() -> void:
	debug_print("Processing command: Play Video (code 92)")

	var path = current_command.parameters.get("path", "")
	var wait = current_command.parameters.get("wait", false)
	var loop = current_command.parameters.get("loop", false)
	var fade_in_time = current_command.parameters.get("fadein", 0.0)
	var fade_out_time = current_command.parameters.get("fadeout", 0.0)
	var color = current_command.parameters.get("color", Color(1, 1, 1, 1))

	if not path:
		return

	var video = GameManager.play_video(path, loop, fade_out_time)
	if not video:
		return
	
	video.set_meta("creation_properties", current_command.parameters)
	video.add_to_group("_map_video_scene")

	if fade_in_time > 0:
		video.modulate = Color.TRANSPARENT
		var tween = GameManager.create_tween()
		tween.tween_property(video, "modulate", color, fade_in_time)
	else:
		video.modulate = color
	
	GameManager.interpreter_last_scene_created = video

	if wait and not loop:
		await video.tree_exited
	


# Command Stop Video (Code 93), button_ids = 75
# Code 93 parameters {  }
func _command_0093() -> void:
	debug_print("Processing command: Stop Video (code 93)")

	GameManager.stop_video()
