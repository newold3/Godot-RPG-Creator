class_name ExtractionManager
extends Node


const ANIMATE_POPUP = preload("res://Scenes/OtherScenes/animate_popup.tscn")

var last_animated_popup: Dictionary = {}


func get_profession_level(profession: RPGProfession) -> int:
	if GameManager.game_state:
		var profession_level = 0
		var actor_profession_level = GameManager.game_state.profession_levels.get(profession.id, {})
		var profession_is_available = actor_profession_level.get("available", false)
		var level = actor_profession_level.get("level", -1)
		
		for i in level - 1:
			profession_level += profession.levels[i].max_levels
			
		var sub_level = actor_profession_level.get("sub_level", 1)
		profession_level += sub_level
		
		return -1 if not profession_is_available else profession_level
		
	return 0


func manage_extraction_scene(node: Node) -> void:
	var data: RPGExtractionItem = node.data
	var extraction_data: GameExtractionItem = node.extraction_data
	var profession = data.get_profession()
	var alert_message: String
	
	if profession:
		if not has_profession(profession.id):
			alert_message = tr("Profession required") + "\n< [color=red]%s[/color] >" % profession.name
			var top_node = GameManager.get_node_or_null("%Top")
			_show_alert_message(alert_message, node.global_position if not top_node else top_node.global_position)
			return
			
		var player_level = get_profession_level(profession)
		if not data.no_level_restrictions and (player_level < data.min_required_profession_level or player_level > data.max_required_profession_level):
			if player_level < data.min_required_profession_level:
				alert_message = tr("You need a higher\nlevel to extract") + "\n< [color=red]%s[/color]  >" % data.name
			else:
				alert_message = tr("Your level is too\nhigh to extract") + "\n< [color=red]%s[/color]  >" % data.name
			var top_node = GameManager.get_node_or_null("%Top")
			_show_alert_message(alert_message, node.global_position if not top_node else top_node.global_position)
			return
		
		var level_difference = data.current_level - player_level
		if level_difference >= 10:
			alert_message = tr("Cannot extract") + "\n< [color=red]%s[/color] >\n" % data.name + tr("Item level too high")
			var top_node = GameManager.get_node_or_null("%Top")
			_show_alert_message(alert_message, node.global_position if not top_node else top_node.global_position)
			return
			
		if GameManager.gui_canvas_layer:
			GameManager.busy = true
			if node.has_method("start_extraction"):
				node.start_extraction()
				
			var scene = preload("res://Scenes/ExtractionScenes/default_manager_extraction_scene.tscn").instantiate()
			GameManager.gui_canvas_layer.add_child(scene)
			scene.start(data, extraction_data)

			var _result = await scene.finished
			
			extraction_data.current_uses -= 1
			if extraction_data.current_uses == 0:
				if node.has_method("end"):
					extraction_data.depleted_date = GameManager.game_state.stats.play_time
					extraction_data.current_respawn_time = data.respawn_time
					node.end()
			
			if node.has_method("end_extraction"):
				node.end_extraction()
			GameManager.busy = false


func has_profession(profession_id: int) -> bool:
	if not GameManager.game_state or not profession_id in GameManager.game_state.profession_levels or not GameManager.game_state.profession_levels[profession_id].available:
		return false

	return true


func add_profession_experience(event_data: RPGExtractionItem, experience: float) -> void:
	var profession_id = event_data.required_profession
	if not GameManager.game_state or not profession_id in GameManager.game_state.profession_levels or not GameManager.game_state.profession_levels[profession_id].available:
		return
	
	var level: Dictionary = GameManager.game_state.profession_levels[profession_id]
	
	if "current_level_completed" in level:
		return
	
	var profession = event_data.get_profession()
	if not profession:
		return
		
	var current_profession_level = get_profession_level(profession)
	var leveled_up_major: bool = false
	
	while experience > 0:
		if profession.levels.size() <= level.level - 1:
			break
		
		var last_level = profession.levels.size()
		var is_last_level = level.level == last_level
		
		if is_last_level:
			level.level = last_level
			level.sub_level = 1
			level.experience = 0
			experience = 0
		else:
			var profession_level_component: RPGExtractionLevelComponent = profession.levels[level.level - 1]
			var current_experience_base_needed: int = int(profession_level_component.experience_to_complete * pow(1.1, level.sub_level - 1))
			var max_sub_levels = profession_level_component.max_levels
			
			if level.experience + experience >= current_experience_base_needed:
				experience = level.experience + experience - current_experience_base_needed
				level.experience = 0
				level.sub_level += 1
				
				if level.sub_level > max_sub_levels:
					if level.level + 1 <= profession.levels.size():
						if profession.auto_upgrade_level:
							level.sub_level = 1
							level.level += 1
							leveled_up_major = true
						else:
							level.experience = 0
							level.sub_level -= 1
							level["current_level_completed"] = true
							experience = 0
					else:
						level.experience = 0
						level.sub_level = max_sub_levels
						level.level = profession.levels.size()
						level["current_level_completed"] = true
						experience = 0
			else:
				level.experience += experience
				experience = 0
	
	var final_profession_level = get_profession_level(profession)
	if current_profession_level != final_profession_level and GameManager.current_map:
		GameManager.current_map.refresh_extraction_events()
		
	if leveled_up_major and profession.call_global_event_on_level_up:
		if profession.target_global_event > 0 and RPGSYSTEM.database.common_events.size() > profession.target_global_event:
			var global_event: RPGCommonEvent = RPGSYSTEM.database.common_events[profession.target_global_event]
			var caller_node = GameManager.current_player
			GameInterpreter.start_common_event.call_deferred(caller_node, global_event.list)


func _show_alert_message(text: String, initial_position: Vector2) -> void:
	var alert_id = str(text) + "_" + str(initial_position)
	if alert_id in last_animated_popup or not GameManager.current_map:
		return
		
	var label: RichTextLabel = ANIMATE_POPUP.instantiate()
	GameManager.current_map.add_child(label)
	label.z_index = 500
	label.set_data(text, initial_position)
	last_animated_popup[alert_id] = true
	label.tree_exited.connect(_on_alert_tree_exited.bind(alert_id))


func _on_alert_tree_exited(alert_id: String) -> void:
	if alert_id in last_animated_popup:
		last_animated_popup.erase(alert_id)
