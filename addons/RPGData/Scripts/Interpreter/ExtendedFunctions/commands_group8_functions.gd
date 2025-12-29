class_name CommandsGroup8
extends CommandHandlerBase


const ANIMATION_PROCESS = preload("res://Scenes/AnimationProcess/animation_process.tscn")

# Command Change Transparency (Code 69), button_id = 52
# Code 69 parameters { value }
func _command_0069() -> void:
	debug_print("Processing command: Change Transparency (code 69)")

	var value = current_command.parameters.get("value", 1.0)


# Command Change Player Followers (Code 70), button_id = 53
# Code 70 parameters { value }
func _command_0070() -> void:
	debug_print("Processing command: Change Player Followers (code 70)")

	var value = current_command.parameters.get("value", false)
	GameManager.game_state.followers_enabled = value

	GameManager.show_followers(value)


# Command Followers Leader Tracking (Code 71), button_id = 54
# Code 70 parameters { value }
func _command_0071() -> void:
	debug_print("Processing command: Followers Leader Tracking (code 71)")

	var value = current_command.parameters.get("value", true)
	GameManager.game_state.followers_tracking_enabled = false


# Command Show Animation (Code 72), button_id = 55
# Code 72 parameters { target_id, animation_id, wait }
func _command_0072() -> void:
	debug_print("Processing command: Show Animation (code 72)")

	var target_id = current_command.parameters.get("target_id", 0)
	var animation_id = current_command.parameters.get("animation_id", 0)
	var wait = current_command.parameters.get("wait", false)

	var target: Variant

	if GameManager.current_map: # Show animation on map
		match target_id:
			0: # Current player
				if GameManager.current_player:
					target = GameManager.current_player
			1: # This event:
				target = current_interpreter.obj
			_: # event with id target_id - 1
				target = GameManager.current_map.get_in_game_event_by_pos(target_id - 2)

	elif GameManager.current_battle_scene: # Show animation on battle scene
		return # TODO
	
	if target and RPGSYSTEM.database.animations.size() > animation_id and animation_id > 0:
		var animation: RPGAnimation = RPGSYSTEM.database.animations[animation_id]
		if ResourceLoader.exists(animation.filename):
			var effect: Variant
			if animation.filename.get_extension().to_lower() == "tscn":
				var ins = load(animation.filename).instantiate()
				ins.propagate_call("set_speed_scale", [animation.animation_speed])
				var ins_scale = Vector2(animation.animation_scale, animation.animation_scale)
				ins.propagate_call("set_scale", [ins_scale])
				ins.rotation = animation.rotation.z
				ins.modulate = animation.animation_color
				effect = ins
			else:
				var ins = load(animation.filename)
				var effek: EffekseerEmitter2D = EffekseerEmitter2D.new()
				effek.autoplay = false
				effek.speed = animation.animation_speed
				effek.scale = Vector2(animation.animation_scale, animation.animation_scale)
				effek.orientation = animation.rotation
				effek.autofree = true
				effek.color = animation.animation_color
				effek.set_effect(ins)
				effect = effek
			
			if effect:
				effect.modulate = animation.animation_color
				var animation_process = ANIMATION_PROCESS.instantiate()
				animation_process.z_as_relative = true
				animation_process.z_index = 50
				var animation_position: Vector2 = animation.offset

				if animation.vertical_align == 0: # Top
					var node = target.get_node_or_null("%Up")
					if node:
						animation_position += node.position
				elif animation.vertical_align == 1: # Center
					var node1 = target.get_node_or_null("%Up")
					var node2 = target.get_node_or_null("%Down")
					if node1 and node2:
						var mid_y = (node2.position.y + node1.position.y) / 2
						animation_position.y += mid_y
				elif animation.vertical_align == 2: # Down
					var node = target.get_node_or_null("%Down")
					if node:
						animation_position += node.position
				
				#var target_position = target.get_viewport_transform() * target.global_position
				animation_position *= GameManager.get_camera_zoom()
				animation_position -= Vector2(GameManager.current_map.event_offset.x * 0.5, 0)
				var target_position = target.global_position + animation_position
				animation_process.position = target_position
				var layer = GameManager.get_screen_effect_canvas()
				if layer:
					layer.add_child(animation_process)
					effect.tree_exited.connect(animation_process.end)
					animation_process.add_effect(effect, target, animation_position)
					animation_process.add_animation_data(animation, target)
				else:
					animation_process.queue_free()
					
				if effect is EffekseerEmitter2D:
					effect.target_position = target_position
					effect.play()

				if wait:
					await animation_process.tree_exited


# Command Show Balloon Icon (Code 73), button_id = 56
# Code 73 parameters { target_id, path, wait }
func _command_0073() -> void:
	debug_print("Processing command: Show Balloon Icon (code 73)")

	var target_id = current_command.parameters.get("target_id", 0)
	var scene_path = current_command.parameters.get("path", 0)
	var wait = current_command.parameters.get("wait", false)
	
	if ResourceLoader.exists(scene_path):
		var target: Variant
		match target_id:
			0: # Current player
				if GameManager.current_player:
					target = GameManager.current_player
			1: # This event:
				target = current_interpreter.obj
			_: # event with id target_id - 1
				target = GameManager.current_map.get_in_game_event_by_pos(target_id - 2)
		if target:
			var scene = load(scene_path).instantiate()
			scene.z_as_relative = false
			scene.z_index = 50
			var node = target.get_node_or_null("%Up")
			if node:
				scene.position = node.position
			target.add_child(scene)
		
			if wait:
				await scene.tree_exited


# Command Show Player Action (Code 74), button_id = 57
# Code 74 parameters { index }
func _command_0074() -> void:
	debug_print("Processing command: Show Player Action (code 74)")
	
	var action_index = current_command.parameters.get("index", 0)
