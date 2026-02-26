class_name TimerManager
extends Node



func _get_timer(timer_id: int) -> TimerScene:
	if timer_id in GameManager.game_state.active_timers:
		if GameManager.main_scene and GameManager.main_scene.get_screen_effect_canvas():
			for child in GameManager.main_scene.get_screen_effect_canvas().get_children():
				if child is TimerScene and child.id == timer_id:
					return child
	return null


func manage_timer(config: Dictionary) -> void:
	var operation_type = config.get("operation_type", 0)
	var timer_id = config.get("timer_id", 0)
	var minutes = config.get("minutes", 0)
	var seconds = config.get("seconds", 0)
	var total_time_in_seconds = minutes * 60 + seconds
	
	if operation_type == 0:
		var timer: TimerScene = _get_timer(timer_id)
		if timer:
			timer.stop()
			
		var timer_scene = config.get("timer_scene", "")
		var timer_name = config.get("timer_title", "")
		var extra_config = config.get("extra_config", {})
		
		if timer_scene.is_empty() or not AssetManager.exists(timer_scene):
			return
			
		var scene = load(timer_scene).instantiate()
		if GameManager.main_scene and GameManager.main_scene.get_screen_effect_canvas():
			GameManager.main_scene.get_screen_effect_canvas().add_child(scene)
			scene.set_config(timer_id, timer_name, extra_config)
			scene.tree_exited.connect(func(): GameManager.game_state.active_timers.erase(timer_id))
			GameManager.game_state.active_timers[timer_id] = {
				"config": config,
				"current_time": seconds
			}
			scene.start(total_time_in_seconds)
		
	else:
		var timer: TimerScene = _get_timer(timer_id)
		if timer:
			match operation_type:
				1: timer.stop()
				2: timer.pause()
				3: timer.resume()
				4: timer.add_time(total_time_in_seconds)
				5: timer.subtract_time(total_time_in_seconds)


func update_timer_time(timer_id: int, value: float) -> void:
	if not Engine.is_editor_hint():
		if GameManager.game_state.active_timers.has(timer_id):
			GameManager.game_state.active_timers[timer_id].current_time = value
