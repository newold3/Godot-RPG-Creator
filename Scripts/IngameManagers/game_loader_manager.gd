class_name GameLoaderManager
extends Node


var _load_data_map: Dictionary = {}
var interpreter_id = "_load_interpreter"


func preload_system_scenes() -> void:
	for scene in RPGSYSTEM.database.system.preload_scenes:
		if AssetManager.exists(scene):
			ResourceLoader.load_threaded_request(scene)


func setup_new_game() -> void:
	var main_scene = GameManager.main_scene
	GameInterpreter.clear()
	main_scene.stop_bgm(0.25)
	main_scene.stop_bgs(0.25)
	GameManager.set_cursor_manipulator("")
	
	_initialize_game_state()
	_setup_initial_party()
	_setup_game_managers()
	_setup_debug_scene()
	_setup_day_night_config()
	_initialize_transition_system()
	_load_starting_map()
	
	GameManager.set_deferred("game_started", true)
	GameManager.set_deferred("loading_game", false)


func setup_test_game() -> void:
	GameManager.set_cursor_manipulator("")
	_initialize_game_state()
	_setup_initial_party()
	_setup_game_managers()
	_setup_debug_scene()
	_setup_day_night_config()
	_initialize_transition_system()
	_start_test_map()


func _initialize_game_state() -> void:
	var game_state = GameUserData.new()
	GameManager.game_state = game_state
	var system = RPGSYSTEM.database.system
	
	game_state.game_variables.resize(RPGSYSTEM.system.variables.size() + 1)
	game_state.game_text_variables.resize(RPGSYSTEM.system.text_variables.size() + 1)
	game_state.game_switches.resize(RPGSYSTEM.system.switches.size() + 1)
	
	game_state.current_map_id = system.player_start_position.map_id
	game_state.current_map_position = system.player_start_position.position
	game_state.current_direction = LPCCharacter.DIRECTIONS.DOWN
	game_state.land_transport_start_position = system.land_transport_start_position.clone(true)
	game_state.sea_transport_start_position = system.sea_transport_start_position.clone(true)
	game_state.air_transport_start_position = system.air_transport_start_position.clone(true)
	game_state.current_message_config = system.default_message_config.duplicate(true)
	game_state.experience_mode = 1 if system.options.experience_in_reserve else 0
	game_state.game_chapter_name = system.initial_chapter_name
	game_state.followers_enabled = system.followers_enabled


func _setup_initial_party() -> void:
	var party_manager = GameManager.main_scene.get_node_or_null("%PartyManager")
	if party_manager:
		for actor_id in RPGSYSTEM.database.system.start_party:
			party_manager.add_actor_to_party(actor_id)


func _setup_game_managers() -> void:
	var main_scene = GameManager.main_scene
	var dialog = main_scene.get_node_or_null("%Dialog")
	
	GameManager.message = dialog
	GameManager.message_container = main_scene.get_node_or_null("%MessageCanvas")
	
	if dialog:
		dialog.setup()
		dialog.set_message_config(GameManager.game_state.current_message_config)
		
	GameManager.options_layer = main_scene.get_node_or_null("%OptionsCanvas")
	GameManager.gui_canvas_layer = main_scene.get_node_or_null("%GUICanvas")
	GameManager.over_message_layer = main_scene.get_node_or_null("%OverMessageCanvas")


func _setup_debug_scene() -> void:
	if OS.is_debug_build():
		var debug_scene = preload("res://Scenes/Debug/debug_scene.tscn").instantiate()
		GameManager.main_scene.add_child(debug_scene)


func _setup_day_night_config() -> void:
	var system = RPGSYSTEM.database.system
	var config = system.day_night_config
	DayNightManager.set_config(config)


func _initialize_transition_system() -> void:
	RPGSYSTEM.request_ready()
	var current_transition = RPGSYSTEM.database.system.default_map_transition.parameters
	GameManager.game_state.current_transition = current_transition
	GameManager.main_scene.transition_manager.set_config(current_transition)


func _start_test_map() -> void:
	var map: RPGMap = GameManager.main_scene.current_map
	var start_map_path = map.scene_file_path
	var game_state = GameManager.game_state
	
	if start_map_path and AssetManager.exists(start_map_path):
		if game_state.current_map_id != map.internal_id:
			game_state.current_map_id = map.internal_id
			var rect = map.get_used_rect(false)
			game_state.current_map_position = Vector2i(
				(rect.position.x + rect.size.x / 2) / map.tile_size.x,
				(rect.position.y + rect.size.y / 2) / map.tile_size.y
			)
		GameManager.main_scene.change_scene(start_map_path)
	else:
		get_tree().quit()


func _load_starting_map() -> void:
	var start_map_path = RPGSYSTEM.map_infos.get_map_by_id(GameManager.game_state.current_map_id)
	if start_map_path and AssetManager.exists(start_map_path):
		GameManager.main_scene.change_scene(start_map_path)
	else:
		printerr("Starting map not found. Exiting...")
		GameManager.main_scene.change_scene("res://Scenes/EndScene/scene_end.tscn")


func load_game(data: RPGSavedGameData) -> void:
	if not data or not data.game_state:
		printerr("Invalid save data")
		return

	var main_scene = GameManager.main_scene
	GameInterpreter.clear()
	main_scene.busy = true
	GameManager.loading_game = true

	main_scene.stop_bgm(0.25)
	main_scene.stop_bgs(0.25)

	var game_state = data.game_state
	GameManager.game_started = false
	GameManager.game_state = game_state
	GameManager.current_save_slot = data.save_slot_id
	game_state.current_events = data.current_map_events

	_setup_game_managers()
	_setup_day_night_config()
	DayNightManager.current_time = game_state.current_day_time
	_initialize_transition_system()

	var map_path = RPGSYSTEM.map_infos.get_map_by_id(game_state.current_map_id)
	if not map_path or not AssetManager.exists(map_path):
		printerr("Map not found: ", game_state.current_map_id)
		return

	main_scene.scene_changed.connect(_restore_game_scene_states.bind(data), CONNECT_ONE_SHOT)
	await main_scene.change_scene(map_path, true)

	GameManager.set_cursor_manipulator.call_deferred("")

	main_scene.busy = false
	GameManager.loading_game = false
	GameManager.set_deferred("game_started", true)
	GameManager.set_deferred("busy", false)
	game_state.current_events.clear()


func _restore_game_scene_states(data: RPGSavedGameData) -> void:
	if not data: return
	
	_load_data_map.clear()
	GameInterpreter.create_load_interpreter(interpreter_id)
	if not GameInterpreter.processed_command.is_connected(_on_load_command_processed):
		GameInterpreter.processed_command.connect(_on_load_command_processed)
	
	if not data.main_scene_config.is_empty():
		var config = data.main_scene_config
		_restore_main_scene_visuals(config)
		if "ingame_images" in config:
			for img_data in config.ingame_images:
				_restore_generic_scene(img_data, 75)
		
		if "ingame_scenes" in config:
			for scene_data in config.ingame_scenes:
				_restore_generic_scene(scene_data, 81)
				
		if "weather_scenes" in config:
			for weather_data in config.weather_scenes:
				_restore_generic_scene(weather_data, 68)

		if "video_scenes" in config:
			for video_data in config.video_scenes:
				_restore_generic_scene(video_data, 92)

	if data.player_on_vehicle != -1 and GameManager.current_map and GameManager.current_player:
		var vehicles = GameManager.current_map.get_in_game_vehicles()
		for vehicle in vehicles:
			if vehicle.vehicle_type == data.player_on_vehicle:
				var tile = GameManager.current_player.get_current_tile()
				GameManager.current_map.set_event_position(vehicle, tile, GameManager.current_player.current_direction)
				vehicle.start(GameManager.current_player)

	_restore_audio_state(data)
	
	await GameInterpreter.execute_load_interpreter(interpreter_id)
	
	_load_data_map.clear()
	if GameInterpreter.processed_command.is_connected(_on_load_command_processed):
		GameInterpreter.processed_command.disconnect(_on_load_command_processed)

	GameManager.set_cursor_manipulator.call_deferred("")


func _deserialize_camera_target(obj: Dictionary) -> Dictionary:
	var type = obj.get("type", "none")
	var priority = obj.get("priority", 10)
	
	if type == "player" and GameManager.current_player:
		return {"target": GameManager.current_player, "priority": priority}
	elif type == "event" and GameManager.current_map:
		var event_id = obj.get("id", 0)
		var event = GameManager.current_map.get_in_game_event_by_id(event_id)
		if event:
			return {"target": event, "priority": priority}
	elif type == "vehicle" and GameManager.current_map:
		var vehicles = GameManager.current_map.get_in_game_vehicles()
		var vehicle_id = obj.get("id", 0)
		for vehicle in vehicles:
			if vehicle.vehicle_type == vehicle_id:
				return {"target": vehicle, "priority": priority}
	return {}



func _deserialize_camera_targets(objs: Array[Dictionary]) -> Array[Dictionary]:
	var new_targets: Array[Dictionary] = []
	for obj in objs:
		var target = _deserialize_camera_target(obj)
		if target:
			new_targets.append(target)
	return new_targets


func _restore_main_scene_visuals(config: Dictionary) -> void:
	var main_camera = GameManager.main_scene.get_main_camera()
	
	if "camera" in config:
		main_camera.clear_targets()
		var cam_data = config.camera
		var camera_target = cam_data.get("target", null)
		var camera_targets = cam_data.get("targets", null)
		if camera_targets or camera_target:
			if camera_targets and not camera_targets.is_empty():
				var new_camera_targets = _deserialize_camera_targets(camera_targets)
				main_camera.set_targets_array(new_camera_targets)
			elif camera_target:
				var new_camera_target = _deserialize_camera_target(camera_target)
				if new_camera_target:
					main_camera.set_target(new_camera_target.target)

		main_camera.zoom = cam_data.get("zoom", main_camera.zoom)
		main_camera.target_zoom = cam_data.get("target_zoom", main_camera.target_zoom)
		main_camera.traumas = cam_data.get("traumas", {})
		main_camera.global_position = cam_data.get("global_position", main_camera.global_position)
	
	if "modulates" in config:
		var mods = config.modulates
		if "main_modulate" in mods:
			GameManager.main_scene.set_canvas_modulate_color(mods.main_modulate)
		if "weather_modulate" in mods:
			GameManager.main_scene.set_weather_modulate_color(mods.weather_modulate)


func _restore_audio_state(data: RPGSavedGameData) -> void:
	var main_scene = GameManager.main_scene
	if not data.current_map_bgm.is_empty():
		var bgm = data.current_map_bgm
		main_scene.play_bgm(bgm.path, bgm.volume, bgm.pitch)
	else:
		main_scene.restore_bgm()
	
	if not data.current_map_bgs.is_empty():
		var bgs = data.current_map_bgs
		main_scene.play_bgs(bgs.path, bgs.volume, bgs.pitch)


func _restore_generic_scene(data: Dictionary, command_key: int) -> void:
	if data.creation_properties:
		_load_data_map[data.creation_properties] = data
		GameInterpreter.add_load_command(interpreter_id, command_key, data.creation_properties)


func _restore_tweens(node: Node, tweens_data: Dictionary) -> void:
	for prop in tweens_data:
		var info = tweens_data[prop]
		var duration = abs(info.get("duration", 0.0))
		var final_val = info.get("final_value")
		
		var t = create_tween()
		t.tween_property(node, prop, final_val, duration)
		
		info.start_time = Time.get_ticks_msec()
		node.set_meta("active_tweens", tweens_data)
		
		t.finished.connect(
			func():
				if is_instance_valid(node):
					if node.has_meta("active_tweens"):
						var current_tweens_data = node.get_meta("active_tweens", {})
						current_tweens_data.erase(info.property)
						if not current_tweens_data.is_empty():
							node.set_meta("active_tweens", current_tweens_data)
						else:
							node.remove_meta("active_tweens")
		)


func _on_load_command_processed(command: RPGEventCommand, scene: Node) -> void:
	if not scene or not command: return
	
	if not command.parameters in _load_data_map: return
	
	var data = _load_data_map[command.parameters]
	var properties = data.get("properties", {})
	
	if not properties.is_empty():
		for key in data.properties:
			if key in scene:
				scene.set(key, data.properties[key])
	
		if scene is CanvasItem and "blend_mode" in properties and properties.blend_mode != null:
			if not scene.material:
				scene.material = CanvasItemMaterial.new()
			if scene.material is CanvasItemMaterial:
				scene.material.blend_mode = properties.blend_mode

	if "extra_config" in data and scene.has_method("on_load_custom_data"):
		scene.on_load_custom_data(data.extra_config)

	if "tweens" in data:
		_restore_tweens(scene, data.tweens)
	
	_load_data_map.erase(command.parameters)
