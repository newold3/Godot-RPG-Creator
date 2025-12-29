class_name CommandsGroup9
extends CommandHandlerBase


# Command Show Image (Code 75), button_id = 58
# Code 75 parameters { index, path, image_type, origin, position_type, position, scale, rotation, modulate, blend_type, start_animation, end_animation, start_animation_duration, end_animation_duration, z_index, enable_sort }
func _command_0075() -> void:
	debug_print("Processing command: Show Image (code 75)")

	var path = current_command.parameters.get("path", "")
	var index = current_command.parameters.get("index", 0)
	var image_type = current_command.parameters.get("image_type", 0)

	var image = GameManager.create_image(image_type, index, path)
	if not image:
		return
	
	image.set_meta("creation_properties", current_command.parameters)

	var origin = current_command.parameters.get("origin", 0)
	var position_type = current_command.parameters.get("position_type", 0)
	var position = current_command.parameters.get("position", Vector2.ZERO)
	var scale = current_command.parameters.get("scale", Vector2.ONE)
	var rotation = current_command.parameters.get("rotation", 0.0)
	var modulate = current_command.parameters.get("modulate", Color.WHITE)
	var blend_type = current_command.parameters.get("blend_type", 0)
	var start_animation = current_command.parameters.get("start_animation", 0)
	var start_animation_duration = current_command.parameters.get("start_animation_duration", 0.0)
	var end_animation = current_command.parameters.get("end_animation", 0)
	var end_animation_duration = current_command.parameters.get("end_animation_duration", 0.0)
	var z_index = current_command.parameters.get("z_index", 0)
	var enable_sort = current_command.parameters.get("enable_sort", false)
	image.centered = (origin == 0) # Centered
	image.scale = scale
	image.rotation = rad_to_deg(rotation)
	image.modulate = modulate
	image.material.blend_mode = (
		CanvasItemMaterial.BLEND_MODE_MIX if blend_type == 0 else
		CanvasItemMaterial.BLEND_MODE_ADD if blend_type == 1 else
		CanvasItemMaterial.BLEND_MODE_SUB if blend_type == 2 else
		CanvasItemMaterial.BLEND_MODE_MUL if blend_type == 3 else
		CanvasItemMaterial.BLEND_MODE_PREMULT_ALPHA
	)
	var image_position: Vector2
	if position_type == 1: # use variables
		var real_x = GameManager.get_variable(position.x)
		var real_y = GameManager.get_variable(position.y)
		image_position = Vector2(real_x, real_y)
	else:
		image_position = position
	
	if image.centered and image.texture:
		image_position.y += image.texture.get_height() / 2.0
	#
	#if image_type == 0 and GameManager.current_map:
		#image_position += Vector2(GameManager.current_map.tile_size) / 2

	if image_type == 0:
		image.z_index = z_index
		image.y_sort_enabled = enable_sort
		if not image.centered:
			var offset = Vector2(image.texture.get_width() * 0.5, image.texture.get_height())
			image.offset = -offset
		else:
			var offset = Vector2(0, image.texture.get_height() * 0.5)
			image.offset = -offset
	
	image.position = image_position

	image.start(start_animation, start_animation_duration, end_animation, end_animation_duration)
	GameManager.interpreter_last_scene_created = image


func _register_tween_on_image(image: Node, property: String, final_val: Variant, duration: float) -> void:
	
	var active_tweens = image.get_meta("active_tweens", {})
	
	var tween_info = {
		"property": property,
		"final_value": final_val,
		"duration": duration,
		"start_time": Time.get_ticks_msec()
	}
	active_tweens[property] = tween_info
	image.set_meta("active_tweens", active_tweens)
	
	var tween = GameManager.create_tween()
	tween.tween_property(image, property, final_val, duration)
	
	tween.finished.connect(func():
		if is_instance_valid(image):
			if image.has_meta("active_tweens"):
				active_tweens = image.get_meta("active_tweens", {})
				active_tweens.erase(property)
				if not active_tweens.is_empty():
					image.set_meta("active_tweens", active_tweens)
				else:
					image.remove_meta("active_tweens")
	)


# Command Move Image (Code 76), button_id = 59
# Code 76 parameters { index, relative_movement, position_type, position, duration, wait }
func _command_0076() -> void:
	debug_print("Processing command: Move Image (code 76)")

	var index = current_command.parameters.get("index", 0)
	var relative_movement = current_command.parameters.get("relative_movement", false)
	var position_type = current_command.parameters.get("position_type", 0)
	var position = current_command.parameters.get("position", Vector2.ZERO)
	var duration = current_command.parameters.get("duration", 0.0)
	var wait = current_command.parameters.get("wait", false)

	var image = GameManager.get_image(index)

	if not image:
		return

	if position_type == 1: # use variables
		var real_x = GameManager.get_variable(position.x)
		var real_y = GameManager.get_variable(position.y)
		position = Vector2(real_x, real_y)
	
	if relative_movement:
		position += image.position

	if duration > 0:
		_register_tween_on_image(image, "position", position, duration)
	else:
		image.position = position

	if wait and current_interpreter.obj:
		await current_interpreter.obj.get_tree().create_timer(duration).timeout


# Command Rotate Image (Code 77), button_id = 60
# Code 77 parameters { index, rotation, duration, wait }
func _command_0077() -> void:
	debug_print("Processing command: Rotate Image (code 77)")

	var index = current_command.parameters.get("index", 0)
	var rotation = current_command.parameters.get("rotation", 0.0)
	var duration = current_command.parameters.get("duration", 0.0)
	var wait = current_command.parameters.get("wait", false)

	var image = GameManager.get_image(index)

	if not image:
		return

	if duration > 0:
		_register_tween_on_image(image, "rotation", deg_to_rad(rotation), duration)
	else:
		image.rotation = deg_to_rad(rotation)

	if wait and current_interpreter.obj:
		await current_interpreter.obj.get_tree().create_timer(duration).timeout


# Command Scale Image (Code 78), button_id = 116
# Code 78 parameters { index, scale, duration, wait }
func _command_0078() -> void:
	debug_print("Processing command: Scale Image (code 78)")

	var index = current_command.parameters.get("index", 0)
	var scale = current_command.parameters.get("scale", Vector2.ONE)
	var duration = current_command.parameters.get("duration", 0.0)
	var wait = current_command.parameters.get("wait", false)

	var image = GameManager.get_image(index)

	if not image:
		return

	if duration > 0:
		_register_tween_on_image(image, "scale", scale, duration)
	else:
		image.scale = scale

	if wait and current_interpreter.obj:
		await current_interpreter.obj.get_tree().create_timer(duration).timeout


# Command Tint Image (Code 79), button_id = 61
# Code 79 parameters { index, duration, modulate, wait }
func _command_0079() -> void:
	debug_print("Processing command: Tint Image (code 79)")

	var index = current_command.parameters.get("index", 0)
	var duration = current_command.parameters.get("duration", 0.0)
	var modulate = current_command.parameters.get("modulate", Color.WHITE)
	var wait = current_command.parameters.get("wait", false)

	var image = GameManager.get_image(index)

	if not image:
		return

	if duration > 0:
		_register_tween_on_image(image, "modulate", modulate, duration)
	else:
		image.modulate = modulate

	if wait and current_interpreter.obj:
		await current_interpreter.obj.get_tree().create_timer(duration).timeout


# Command Erase Image (Code 80), button_id = 62
# Code 80 parameters { index }
func _command_0080() -> void:
	debug_print("Processing command: Erase Image (code 80)")

	var index = current_command.parameters.get("index", 0)
	GameManager.remove_image(index)


# Command Add Scene (Code 81), button_id = 63
# Code 81 parameters { index, path, wait }
func _command_0081() -> void:
	debug_print("Processing command: Add Scene (code 81)")

	var index = current_command.parameters.get("index", 0)
	var path = current_command.parameters.get("path", "")
	var wait = current_command.parameters.get("wait", false)
	var is_map_scene = current_command.parameters.get("is_map_scene", false)

	if not path:
		return

	var scene = await GameManager.create_scene(index, path, is_map_scene)

	if not scene:
		return
	
	scene.set_meta("creation_properties", current_command.parameters)
	
	scene.tree_exited.connect(GameManager.remove_scene.bind(index))
	
	GameManager.interpreter_last_scene_created = scene

	if wait:
		await scene.tree_exited


# Command Manipulate Scene (Code 124), button_id = 127
# Code 124 parameters { index, func_name, wait, params }
func _command_0124() -> void:
	debug_print("Processing command: Manipulate Scene (code 124)")

	var index = current_command.parameters.get("index", 0)
	var func_name = current_command.parameters.get("func_name", "")
	var wait = current_command.parameters.get("wait", false)
	var params = current_command.parameters.get("params", {})

	var scene = GameManager.get_scene(index)
	if not scene:
		return
	
	var func_params = []
	for param: Dictionary in params:
		match param.type:
			0, 1, 2:
				func_params.append(param.get("value", null))
			3:
				var value = GameManager.get_switch(param.get("value", 1))
				func_params.append(value)
			4:
				var value = GameManager.get_variable(param.get("value", 1))
				func_params.append(value)
			5:
				var value = GameManager.get_text_variable(param.get("value", 1))
				func_params.append(value)

	var scene_has_method = interpreter.safe_call_methods.validate_method_call(scene, func_name, func_params)

	if not scene_has_method:
		return

	if wait:
		await scene.callv(func_name, func_params)
	else:
		scene.callv(func_name, func_params)


# Command Remove Scene (Code 82), button_id = 64
# Code 82 parameters { index }
func _command_0082() -> void:
	debug_print("Processing command: Remove Scene (code 82)")

	var index = current_command.parameters.get("index", 0)

	GameManager.remove_scene(index)
