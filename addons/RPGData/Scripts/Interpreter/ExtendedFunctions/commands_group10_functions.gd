class_name CommandsGroup10
extends CommandHandlerBase


# Command Play BGM (Code 83), button_id = 65
# Code 83 parameters { path, volume, pitch, fadein }
func _command_0083() -> void:
	debug_print("Processing command: Play BGM (code 83)")
	var path = current_command.parameters.get("path", "")
	var volume = current_command.parameters.get("volume", 0.0)
	var pitch = current_command.parameters.get("pitch", 1.0)
	var fade_in_time = current_command.parameters.get("fadein", 0.25)

	GameManager.play_bgm(path, volume, pitch, fade_in_time)


# Command Stop BGM (Code 84), button_id = 66
# Code 84 parameters { duration }
func _command_0084() -> void:
	debug_print("Processing command: Stop BGM (code 84)")
	var duration = current_command.parameters.get("duration", 0.0)

	GameManager.stop_bgm(duration)


# Command Save BGM (Code 85), button_id = 67
# Code 85 parameters { }
func _command_0085() -> void:
	debug_print("Processing command: Save BGM (code 85)")

	GameManager.save_bgm()


# Command Resume BGM (Code 86), button_id = 68
# Code 86 parameters { }
func _command_0086() -> void:
	debug_print("Processing command: Resume BGM (code 86)")

	GameManager.restore_bgm()


# Command Play BGS (Code 87), button_id = 69
# Code 87 parameters { path, volume, pitch, fadein }
func _command_0087() -> void:
	debug_print("Processing command: Play BGS (code 87)")

	var path = current_command.parameters.get("path", "")
	var volume = current_command.parameters.get("volume", 0.0)
	var pitch = current_command.parameters.get("pitch", 1.0)
	var fade_in_time = current_command.parameters.get("fadein", 0.25)

	GameManager.play_bgs(path, volume, pitch, fade_in_time)


# Command Stop BGS (Code 88), button_id = 70
# Code 88 parameters { duration }
func _command_0088() -> void:
	debug_print("Processing command: Stop BGS (code 88)")

	var duration = current_command.parameters.get("duration", 0.0)

	GameManager.stop_bgs(duration)

	
# Command Play ME (Code 89), button_id = 71
# Code 89 parameters { path, volume, pitch }
func _command_0089() -> void:
	debug_print("Processing command: Play ME (code 89)")

	var path = current_command.parameters.get("path", "")
	var volume = current_command.parameters.get("volume", 0.0)
	var pitch = current_command.parameters.get("pitch", 1.0)

	GameManager.play_me(path, volume, pitch)


# Command Play SE (Code 90), button_id = 72
# Code 90 parameters { path, volume, pitch, pitch2 }
func _command_0090() -> void:
	debug_print("Processing command: Play SE (code 90)")

	var path = current_command.parameters.get("path", "")
	var volume = current_command.parameters.get("volume", 0.0)
	var pitch1 = current_command.parameters.get("pitch", 1.0)
	var pitch2 = current_command.parameters.get("pitch2", 1.0)

	var pitch = pitch1 if pitch1 == pitch2 else  randf_range(pitch1, pitch2)

	GameManager.play_se(path, volume, pitch)


# Command Stop SE (Code 91), button_id = 73
# Code 91 parameters {  }
func _command_0091() -> void:
	debug_print("Processing command: Stop SE (code 91)")

	GameManager.stop_se()
