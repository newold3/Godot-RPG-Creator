class_name CommandsGroup7
extends CommandHandlerBase


# Command Fade Out (Code 63), button_id = 46
# Code 63 parameters { duration }
func _command_0063() -> void:
	debug_print("Processing command: Fade Out (code 63)")

	var duration = current_command.parameters.get("duration", 0)

	if duration != 0:
		var modulate_node = GameManager.get_secondary_transition_node()
		if modulate_node:
			modulate_node.color = Color(0, 0, 0, 0)
			var t = GameManager.create_tween()
			t.tween_property(modulate_node, "color", Color.BLACK, duration)
	
	await GameManager.get_tree().create_timer(duration).timeout


# Command Fade In (Code 64), button_id = 47
# Code 64 parameters { duration }
func _command_0064() -> void:
	debug_print("Processing command: Fade In (code 64)")

	var duration = current_command.parameters.get("duration", 0)

	if duration != 0:
		var modulate_node = GameManager.get_secondary_transition_node()
		if modulate_node:
			modulate_node.color = Color.BLACK
			var t = GameManager.create_tween()
			t.tween_property(modulate_node, "color", Color(0, 0, 0, 0), duration)
	
	await GameManager.get_tree().create_timer(duration).timeout


# Command Perform Transition (Code 55), button_id = 124
# Code 55 parameters { type }
func _command_0055() -> void:
	debug_print("Processing command: Perform Transition (code 55)")

	var type = current_command.parameters.get("type", 0)

	var transition_manager = GameManager.get_transition_manager()

	if transition_manager:
		if type == 0: # Transition Out
			var img = GameManager.get_viewport().get_texture().get_image()
			var tex = ImageTexture.create_from_image(img)
			await transition_manager.start(tex)
		elif type == 1: # Transition In
			await transition_manager.end()


# Command Tint Screen (Code 65), button_id = 48
# Code 65 parameters { color, duration, wait }
func _command_0065() -> void:
	debug_print("Processing command: Tint Screen (code 65)")

	var color = current_command.parameters.get("color", Color.WHITE)
	var duration = current_command.parameters.get("duration", 0)
	var wait = current_command.parameters.get("wait", false)
	var remove = current_command.parameters.get("remove", false)
	
	if remove:
		GameManager.remove_tint_color(duration)
	else:
		GameManager.set_tint_color(color, duration)

	if wait:
		await GameManager.get_tree().create_timer(duration).timeout


# Command Flash Screen (Code 66), button_id = 49
# Code 66 parameters { color, duration, wait }
func _command_0066() -> void:
	debug_print("Processing command: Flash Screen (code 66)")

	var color = current_command.parameters.get("color", Color.WHITE)
	var duration = (current_command.parameters.get("duration", 0) + 0.01) / 2.0
	var wait = current_command.parameters.get("wait", false)

	var modulate_node = GameManager.get_secondary_transition_node()
	
	if modulate_node:
		var current_modulate_color = modulate_node.color

		var t = GameManager.create_tween()
		t.tween_method(
			func(step):
				modulate_node.color = current_modulate_color.lerp(color, step)
		, 0.0, 1.0, duration)
		t.tween_method(
			func(step):
				modulate_node.color = color.lerp(current_modulate_color, step)
		, 0.0, 1.0, duration)
		t.tween_callback(modulate_node.set_color.bind(current_modulate_color))

		if wait:
			await GameManager.get_tree().create_timer(duration * 2).timeout


# Command Shake Screen (Code 67), button_id = 50
# Code 67 parameters { duration, power }
func _command_0067() -> void:
	debug_print("Processing command: Shake Screen (code 67)")

	var duration = current_command.parameters.get("duration", 0)
	var power = current_command.parameters.get("power", 0)

	var camera = GameManager.get_camera()
	if camera:
		camera.add_trauma(power, duration)


# Command Add or Remove Weather Scene (Code 68), button_id = 51
# Code 68 parameters { type, id, scene }
func _command_0068() -> void:
	debug_print("Processing command: Add or Remove Weather Scene (code 68)")
	
	if not GameManager.current_map:
		return

	var type = current_command.parameters.get("type", 0)
	var id = current_command.parameters.get("id", 0)
	var scene = current_command.parameters.get("scene", "")

	if type == 0: # Add Wheather Scene
		if not ResourceLoader.exists(scene):
			debug_print("Weather scene does not exist: " + scene)
			return

		var weather_scene = load(scene).instantiate()
		weather_scene.set_meta("creation_properties", current_command.parameters)
		weather_scene.add_to_group("_map_weather_scene")
		GameManager.current_map.add_weather_scene(id, weather_scene)
		GameManager.interpreter_last_scene_created = weather_scene

	elif type == 1: # Remove Weather Scene
		GameManager.current_map.remove_weather_scene(id)
