class_name CommandsGroup12
extends CommandHandlerBase

# Command Erase Event (Code 94), button_ids = 107
# Code 94 parameters {  }
func _command_0094() -> void:
	debug_print("Processing command: Erase Event (code 94)")
	
	if current_interpreter.obj and GameManager.current_map:
		for key in GameManager.current_map.current_ingame_events.keys():
			var obj = GameManager.current_map.current_ingame_events[key]
			if obj.lpc_event == current_interpreter.obj:
				# Delete the event and wait 3 frames to prevent screen flickering caused by the shadow system.
				if GameManager.game_state:
					GameManager.game_state.erased_events.append(obj.event.id)
				current_interpreter.obj.visible = false
				current_interpreter.obj.position = Vector2.INF
				await RenderingServer.frame_post_draw
				await RenderingServer.frame_post_draw
				await RenderingServer.frame_post_draw
				current_interpreter.obj.queue_free()
				obj.lpc_event = null
				obj.character_data = null
				obj.event = null
	
	current_interpreter.end()
	current_interpreter.force_stop.emit(current_interpreter)
