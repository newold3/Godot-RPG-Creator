class_name MainScene
extends Node2D

@export var transition_manager: Control

var initialize_title_scene: bool = false
var game_state: GameUserData
var current_map: RPGMap
var current_player: LPCCharacter
var followers: Array[SimpleFollower]
var busy: bool = false
var fx_busy: bool = false
var battle_in_progress: bool = false

# Audio player management
var audio_players: Dictionary = {}
var current_canvas_modulation = Color.WHITE
var current_scene: Node
var is_test_map: bool = false

var _day_color: Color = Color.WHITE
var _use_day_night: bool = true
var _map_color: Color = Color.WHITE
var _weather_color: Color = Color.WHITE
var _weather_ratio: float = 0.0
var _tint_color: Color = Color.WHITE
var _tint_ratio: float = 0.0
var transition_speed: float = 5.0
var flash_tween: Tween
var _weather_tween: Tween
var _tint_tween: Tween

var last_fx_ids: Dictionary

var _load_data_map: Dictionary = {}
var interpreter_id = "_load_interpreter"

var _current_scene_loaded: Node


@onready var interpreter = %Interpreter
@onready var main_camera: Camera2D = %MainCamera
@onready var map_container: Parallax2D = %MapContainer
@onready var animate_items: ItemAnimationControl = %AnimateItems
@onready var main_game_viewport: SubViewport = %MainGameViewport


signal scene_changed()


func _ready() -> void:
	get_viewport().transparent_bg = false
	preload_system_scenes()
	GameManager.main_scene = self
	GameManager.hand_cursor.reparent(self)
	_initialize_audio_players()
	
	if not is_test_map:
		if not initialize_title_scene:
			setup_new_game()
		else:
			var main_menu_path = RPGSYSTEM.database.system.game_scenes["Scene Title"]
			change_scene(main_menu_path)
	else:
		setup_test_game()


func _process(delta: float) -> void:
	if not last_fx_ids.is_empty():
		for key in last_fx_ids.keys():
			last_fx_ids[key] -= delta
			if last_fx_ids[key] <= 0:
				last_fx_ids.erase(key)
	
	var target_color: Color = _calculate_final_color()
	var color = %MainModulate.color
	if not color.is_equal_approx(target_color):
		color = color.lerp(target_color, delta * transition_speed)
	else:
		color = target_color
	%MainModulate.color = color


func set_day_color(new_color: Color) -> void:
	_day_color = new_color


func set_use_day_night(enabled: bool) -> void:
	_use_day_night = enabled


func set_map_color(new_color: Color) -> void:
	_map_color = new_color


func set_weather_color(new_color: Color, duration: float) -> void:
	if _weather_tween: _weather_tween.kill()
	
	if duration > 0.0:
		_weather_tween = create_tween().set_parallel(true)
		
		if _weather_ratio > 0.0:
			_weather_tween.tween_property(self, "_weather_color", new_color, duration)
		else:
			_weather_color = new_color
			
		_weather_tween.tween_property(self, "_weather_ratio", 1.0, duration)
		
	else:
		_weather_color = new_color
		_weather_ratio = 1.0
		%MainModulate.color = _calculate_final_color()


func remove_weather_color(duration: float) -> void:
	if _weather_tween: _weather_tween.kill()
	
	if duration > 0.0:
		_weather_tween = create_tween()
		_weather_tween.tween_property(self, "_weather_ratio", 0.0, duration)
	else:
		_weather_ratio = 0.0
		%MainModulate.color = _calculate_final_color()


func set_weather_flash(color: Color, duration: float) -> void:
	var node = %WeatherModulate
	var mat: ShaderMaterial = node.get_material()
	if flash_tween: flash_tween.kill()
	flash_tween = create_tween()
	flash_tween.tween_method(
		func(value: float):
			var final_color = Color.WHITE.lerp(color, value)
			mat.set_shader_parameter("modulate", final_color)
	, 0.0, 1.0, duration)
	flash_tween.tween_method(
		func(value: float):
			var final_color = color.lerp(Color.TRANSPARENT, value)
			mat.set_shader_parameter("modulate", final_color)
	, 0.0, 1.0, duration * 5.0)


func set_tint_color(new_color: Color, duration: float) -> void:
	if _tint_tween: _tint_tween.kill()

	if duration > 0.0:
		_tint_tween = create_tween().set_parallel(true)
		
		if _tint_ratio > 0.0:
			_tint_tween.tween_property(self, "_tint_color", new_color, duration)
		else:
			_tint_color = new_color

		_tint_tween.tween_property(self, "_tint_ratio", 1.0, duration)
		
	else:
		_tint_color = new_color
		_tint_ratio = 1.0
		%MainModulate.color = _calculate_final_color()


func remove_tint_color(duration: float) -> void:
	if _tint_tween: _tint_tween.kill()
	
	if duration > 0.0:
		_tint_tween = create_tween()
		_tint_tween.tween_property(self, "_tint_ratio", 0.0, duration)
	else:
		_tint_ratio = 0.0
		%MainModulate.color = _calculate_final_color()


func _calculate_final_color() -> Color:
	# 1. Base Layer: Map * Day/Night
	var final_color: Color = _map_color
	
	if _use_day_night:
		final_color = final_color * _day_color
	
	# 2. Weather Layer
	# We interpret ratio 1.0 as "Full Override".
	if _weather_ratio > 0.0:
		final_color = final_color.lerp(_weather_color, _weather_ratio)
	
	# 3. Tint Layer
	# Tint is on top. If ratio is 1.0, it completely covers Weather and Base.
	# If ratio is 0.5 (fading out), it lets the updated Weather/Base show through.
	if _tint_ratio > 0.0:
		final_color = final_color.lerp(_tint_color, _tint_ratio)
	
	return final_color


func preload_system_scenes() -> void:
	for scene in RPGSYSTEM.database.system.preload_scenes:
		if ResourceLoader.exists(scene):
			ResourceLoader.load_threaded_request(scene)


func _initialize_audio_players() -> void:
	"""Initialize audio player management system"""
	audio_players = {
		"se": {
			"players": [%SEPlayer1, %SEPlayer2, %SEPlayer3, %SEPlayer4, %SEPlayer5],
			"current_index": 0
		},
		"bgm": {
			"players": [%BGMPlayer1, %BGMPlayer2],
			"current_index": 0,
			"current_player": null
		},
		"bgs": {
			"players": [%BGSPlayer1, %BGSPlayer2],
			"current_index": 0,
			"current_player": null
		},
		"me": {
			"players": [%MEPlayer]
		}
	}
	audio_players.bgm.current_player = audio_players.bgm.players[0]


func get_modulate_scenes() -> Dictionary:
	var modulates = {
		"main_modulate": %MainModulate.color,
		"weather_modulate": %WeatherModulate.color
	}
	
	return modulates


func setup_new_game() -> void:
	GameInterpreter.clear()
	stop_bgm(0.25)
	stop_bgs(0.25)
	GameManager.set_cursor_manipulator("")
	_initialize_game_state()
	_setup_initial_party()
	_setup_game_managers()
	_setup_debug_scene()
	_setup_day_night_config()
	_initialize_transition_system()
	_load_starting_map()
	set_deferred("fx_busy", false)
	GameManager.set_deferred("game_started", true)
	GameManager.set_deferred("loading_game", false)


#region LOAD RESTORATION LOGIC
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
	# Camera
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
	
	# Global Modulate
	if "modulates" in config:
		var mods = config.modulates
		if "main_modulate" in mods:
			set_canvas_modulate_color(mods.main_modulate)
		if "weather_modulate" in mods:
			set_weather_modulate_color(mods.weather_modulate)


func _restore_audio_state(data: RPGSavedGameData) -> void:
	# Restore BGM
	if not data.current_map_bgm.is_empty():
		var bgm = data.current_map_bgm
		play_bgm(bgm.path, bgm.volume, bgm.pitch)
		if audio_players.bgm.current_player:
			audio_players.bgm.current_player.seek(bgm.playback_position)
	else:
		# Fallback if no precise data exists
		restore_bgm()
	
	# Restore BGS
	if not data.current_map_bgs.is_empty():
		var bgs = data.current_map_bgs
		play_bgs(bgs.path, bgs.volume, bgs.pitch)
		if audio_players.bgs.current_player:
			audio_players.bgs.current_player.seek(bgs.playback_position)


## Helper to instantiate a node from saved data and apply properties/tweens.
func _restore_generic_scene(data: Dictionary, command_key: int) -> void:
	if data.creation_properties:
		_load_data_map[data.creation_properties] = data
		GameInterpreter.add_load_command(interpreter_id, command_key, data.creation_properties)
#endregion


func _restore_tweens(node: Node, tweens_data: Dictionary) -> void:
	for prop in tweens_data:
		var info = tweens_data[prop]
		var duration = abs(info.get("duration", 0.0))
		var final_val = info.get("final_value")
		
		var t = create_tween()
		t.tween_property(node, prop, final_val, duration)
		
		info.start_time = Time.get_ticks_msec()

		node.set_meta("active_tweens", tweens_data)
		
		# Clean up meta on finish
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
	
	# Restore standard properties
	var properties = data.get("properties", {})
	if not properties.is_empty():
		for key in data.properties:
			if key in scene:
				scene.set(key, data.properties[key])
	
		# Restore Blend Mode (Material handling)
		if scene is CanvasItem and "blend_mode" in properties and properties.blend_mode != null:
			if not scene.material:
				scene.material = CanvasItemMaterial.new()
			if scene.material is CanvasItemMaterial:
				scene.material.blend_mode = properties.blend_mode

	# Restore Custom Script Data (Hooks)
	if "extra_config" in data and scene.has_method("on_load_custom_data"):
		scene.on_load_custom_data(data.extra_config)

	# Restore Active Tweens
	if "tweens" in data:
		_restore_tweens(scene, data.tweens)
	
	_load_data_map.erase(command.parameters)


func _restore_game_scene_states(data: RPGSavedGameData) -> void:
	if not data: return
	
	_load_data_map.clear()
	GameInterpreter.create_load_interpreter(interpreter_id)
	if not GameInterpreter.processed_command.is_connected(_on_load_command_processed):
		GameInterpreter.processed_command.connect(_on_load_command_processed)
	
	# 1. Restore Main Scene Configuration (Camera, Modulate)
	if not data.main_scene_config.is_empty():
		var config = data.main_scene_config
		_restore_main_scene_visuals(config)
		# Restore Dynamic Assets (Images, Scenes, Weather, Video)
		if "ingame_images" in config: # interpreter command = 75
			for img_data in config.ingame_images:
				_restore_generic_scene(img_data, 75)
		
		if "ingame_scenes" in config: # interpreter command = 81
			for scene_data in config.ingame_scenes:
				_restore_generic_scene(scene_data, 81)
				
		if "weather_scenes" in config: # interpreter command = 68
			# Assuming specific container or map child
			for weather_data in config.weather_scenes:
				_restore_generic_scene(weather_data, 68)

		if "video_scenes" in config: # interpreter command = 92
			for video_data in config.video_scenes:
				_restore_generic_scene(video_data,92)

	# 2. Restore Vehicle State
	if data.player_on_vehicle != -1 and GameManager.current_map and GameManager.current_player:
		var vehicles = GameManager.current_map.get_in_game_vehicles()
		for vehicle in vehicles:
			if vehicle.vehicle_type == data.player_on_vehicle:
				var tile = GameManager.current_player.get_current_tile()
				GameManager.current_map.set_event_position(vehicle, tile, GameManager.current_player.current_direction)
				vehicle.start(GameManager.current_player)

	# 3. Restore Audio (Precise Playback)
	_restore_audio_state(data)
	
	# 4. # Process load interpreter
	await GameInterpreter.execute_load_interpreter(interpreter_id)
	
	_load_data_map.clear()
	if GameInterpreter.processed_command.is_connected(_on_load_command_processed):
		GameInterpreter.processed_command.disconnect(_on_load_command_processed)

	# 5. Final UI updates
	GameManager.set_cursor_manipulator.call_deferred("")


func load_game(data: RPGSavedGameData) -> void:
	if not data or not data.game_state:
		printerr("Invalid save data")
		return

	GameInterpreter.clear()
	busy = true
	fx_busy = true
	GameManager.loading_game = true

	# 1. Stop audio
	stop_bgm(0.25)
	stop_bgs(0.25)

	# 2. Apply loaded state
	game_state = data.game_state
	GameManager.game_started = false
	GameManager.game_state = game_state
	GameManager.current_save_slot = data.save_slot_id
	game_state.current_events = data.current_map_events

	# 3. Setup managers
	_setup_game_managers()
	_setup_day_night_config()
	DayNightManager.current_time = game_state.current_day_time
	_initialize_transition_system()

	# 4. Load map
	var map_path = RPGSYSTEM.map_infos.get_map_by_id(game_state.current_map_id)
	if not map_path or not ResourceLoader.exists(map_path):
		printerr("Map not found: ", game_state.current_map_id)
		return

	# 4.1 Restore game state after load map
	scene_changed.connect(_restore_game_scene_states.bind(data), CONNECT_ONE_SHOT)
	
	await change_scene(map_path, true)

	# 5. Update cursor_manipulator
	GameManager.set_cursor_manipulator.call_deferred("")

	# 6. clean loading status
	busy = false
	fx_busy = false
	GameManager.loading_game = false
	GameManager.set_deferred("game_started", true)
	GameManager.set_deferred("busy", false)
	game_state.current_events.clear()



func setup_test_game() -> void:
	GameManager.set_cursor_manipulator("")
	_initialize_game_state()
	_setup_initial_party()
	_setup_game_managers()
	_setup_debug_scene()
	_setup_day_night_config()
	_initialize_transition_system()
	_start_test_map()
	set_deferred("fx_busy", false)


func _initialize_game_state() -> void:
	"""Initialize the game state with default values"""
	game_state = GameUserData.new()
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
	"""Setup the initial party members"""
	for actor_id in RPGSYSTEM.database.system.start_party:
		add_actor_to_party(actor_id)


func _setup_game_managers() -> void:
	"""Setup game manager references"""
	GameManager.message = %Dialog
	GameManager.message_container = %MessageCanvas
	GameManager.message.setup()
	GameManager.options_layer = %OptionsCanvas
	GameManager.message.set_message_config(game_state.current_message_config)
	GameManager.gui_canvas_layer = %GUICanvas
	GameManager.over_message_layer = %OverMessageCanvas


func _setup_debug_scene() -> void:
	"""Add debug scene if in debug mode"""
	if OS.is_debug_build():
		var debug_scene = preload("res://Scenes/Debug/debug_scene.tscn").instantiate()
		add_child(debug_scene)


func _setup_day_night_config() -> void:
	var system = RPGSYSTEM.database.system
	var config = system.day_night_config
	DayNightManager.set_config(config)


func _initialize_transition_system() -> void:
	"""Initialize transition system"""
	RPGSYSTEM.request_ready()
	var current_transition = RPGSYSTEM.database.system.default_map_transition.parameters
	game_state.current_transition = current_transition
	transition_manager.set_config(current_transition)


func _start_test_map() -> void:
	var map: RPGMap = current_map
	var start_map_path = map.scene_file_path
	if start_map_path and ResourceLoader.exists(start_map_path):
		if game_state.current_map_id != map.internal_id:
			game_state.current_map_id = map.internal_id
			var rect = map.get_used_rect(false)
			game_state.current_map_position = Vector2i(
				(rect.position.x + rect.size.x / 2) / map.tile_size.x,
				(rect.position.y + rect.size.y / 2) / map.tile_size.y
			)
		change_scene(start_map_path)
	else:
		get_tree().quit()


func _load_starting_map() -> void:
	"""Load the starting map"""
	var start_map_path = RPGSYSTEM.map_infos.get_map_by_id(game_state.current_map_id)
	if start_map_path and ResourceLoader.exists(start_map_path):
		change_scene(start_map_path)
	else:
		printerr("Starting map not found (Map with id %s). Exiting..." % game_state.current_map_id)
		change_scene("res://Scenes/EndScene/scene_end.tscn")


# Party Management
func add_actor_to_party(actor_id: int) -> void:
	if RPGSYSTEM.database.actors.size() > actor_id:
		if !game_state.actors.has(actor_id):
			var actor = GameActor.new(actor_id)
			game_state.actors[actor_id] = actor
	
	if !game_state.current_party.has(actor_id):
		game_state.current_party.append(actor_id)


func remove_actor_from_party(remove_actor_id: int) -> void:
	var index = game_state.current_party.find(remove_actor_id)
	if index != -1:
		game_state.current_party.remove_at(index)


# Player Management
func clear_current_player() -> void:
	for player in %PlayerContainer.get_children():
		player.queue_free()


func setup_player() -> void:
	if not current_map or current_map.internal_id != game_state.current_map_id:
		return
	
	_create_or_reuse_player()
	_position_player()
	_setup_player_properties()
	if GameManager._transfer_direction != -1:
		current_map.set_event_direction(current_player, GameManager._transfer_direction)
		GameManager._transfer_direction = -1


func _refresh_follower_nodes(instant: bool = false) -> void:
	if not current_map or not current_player: return
	
	var needed = game_state.current_party.size() - 1 if game_state.followers_enabled else 0
	var base_delay = 18
	var insert_idx = current_player.get_index()
	
	var start_spots = _get_procedural_party_positions(needed)
	
	while followers.size() < needed:
		var f = preload("uid://pbm7vnwv6qll").instantiate()
		current_map.add_child(f)
		current_map.move_child(f, insert_idx)
		
		f.global_position = start_spots[followers.size()]
		f.modulate.a = 1.0 if instant else 0.0
		
		followers.append(f)
		
	while followers.size() > needed:
		var f = followers.pop_back()
		f.queue_free()
		
	for i in range(followers.size()):
		followers[i].follower_id = i + 1
		@warning_ignore("incompatible_ternary")
		followers[i].target_node = current_player if i == 0 else followers[i-1]
		followers[i].frame_delay = base_delay
		
		if followers[i].has_method("_initialize_queue"):
			followers[i]._initialize_queue()
			
		if followers[i].has_method("_update_facing_direction"):
			followers[i]._update_facing_direction()


func update_party_visuals(instant: bool = false) -> void:
	if not game_state or game_state.current_party.is_empty():
		return
		
	var party = game_state.current_party
	
	if current_player:
		var leader_actor = RPGSYSTEM.database.actors[party[0]]
		current_player.set_data(load(leader_actor.character_data_file))
		current_player.name = "Player_" + leader_actor.name
		
	_refresh_follower_nodes(instant)
	
	for i in range(1, party.size()):
		if (i - 1) < followers.size():
			var follower = followers[i - 1]
			follower.update_appearance_cascade(party[i], instant)


func _get_procedural_party_positions(count: int) -> Array[Vector2]:
	var spots: Array[Vector2] = []
	var map = GameManager.current_map
	if not map or not current_player:
		for i in range(count): spots.append(Vector2.ZERO)
		return spots
	
	var visited_tiles: Array[Vector2i] = []
	var current_center_tile = map.get_tile_from_position(current_player.global_position)
	visited_tiles.append(current_center_tile)

	for i in range(count):
		var adjacent_directions = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
		adjacent_directions.shuffle()
		
		var found_spot = false
		for dir in adjacent_directions:
			var target_tile = Vector2i(current_center_tile + dir)
			
			if not target_tile in visited_tiles and map.is_passable(target_tile, 0, current_player):
				var world_pos = map.get_tile_position(target_tile)
				spots.append(world_pos)
				visited_tiles.append(target_tile)
				current_center_tile = target_tile
				found_spot = true
				break
		
		if not found_spot:
			var fallback_pos = spots[-1] if not spots.is_empty() else current_player.global_position
			spots.append(fallback_pos)
			
	return spots


func regroup() -> void:
	game_state.followers_enabled = false
	if followers.is_empty(): return
	
	var tween = create_tween().set_parallel(true)
	var target_pos = current_player.global_position if current_player else Vector2.ZERO
	
	for f in followers:
		f.is_invalid_event = true
		tween.tween_property(f, "global_position", target_pos, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(f, "modulate:a", 0.0, 0.5)
		
	await tween.finished
	for f in followers:
		if is_instance_valid(f): f.queue_free()
	followers.clear()


func _create_or_reuse_player() -> void:
	"""Create new player or reuse existing one"""
	if GameManager.loading_game and current_player and is_instance_valid(current_player):
		current_player.queue_free()
		current_player = null
	if (not current_player or not is_instance_valid(current_player)) and GameManager.game_state:
		var player_id = GameManager.game_state.current_party[0] if not  GameManager.game_state.current_party.is_empty() else 0
		if player_id > 0 and RPGSYSTEM.database.actors.size() > player_id:
			var actor = RPGSYSTEM.database.actors[player_id]
			var scene_path = actor.character_scene
			if ResourceLoader.exists(scene_path):
				current_player = load(scene_path).instantiate()
				current_player.name = "Player_" + actor.name
				
		if not current_player:
			current_player = preload("uid://bfh5umy1vx2y3").instantiate()
			current_player.name = "Player_Empty"
	elif current_player and current_player.is_inside_tree():
		current_player.get_parent().remove_child(current_player)
	
	if GameManager.current_map:
		if current_player: current_player.current_map_tile_size = GameManager.current_map.tile_size


func _position_player() -> void:
	"""Position the player on the map"""
	var start_position = Vector2(game_state.current_map_position.x, game_state.current_map_position.y)
	var target_position = current_map.map_to_local(start_position)
	target_position = target_position.snapped(current_map.tile_size)
	current_player.position = Vector2(target_position) + current_map.event_offset
	current_player.current_direction = game_state.current_direction
	current_player.last_direction = game_state.current_direction
	current_map.add_child(current_player)
	current_player.initialize_virtual_tile()
	main_camera.set_target(current_player)
	await get_tree().process_frame
	main_camera.fast_reposition.call_deferred()


func _setup_player_properties() -> void:
	"""Setup player camera and movement properties"""
	main_camera.add_target_to_array(current_player, 10)
	main_camera.fast_reposition.call_deferred()
	
	if "movement_current_mode" in current_player:
		match RPGSYSTEM.database.system.movement_mode:
			0: current_player.movement_current_mode = CharacterBase.MOVEMENTMODE.GRID
			1: current_player.movement_current_mode = CharacterBase.MOVEMENTMODE.FREE
		
	if is_test_map and current_map:
		current_player.current_map_tile_size = current_map.tile_size
		current_player.calculate_grid_move_duration()
	GameManager.current_player = current_player


# Visual Effects
func set_canvas_modulate_color(color: Color) -> void:
	current_canvas_modulation = color
	var brightness_factor = GameManager.current_game_options.brightness if GameManager.current_game_options else 1.0
	
	var final_color = color * brightness_factor
	final_color.a = current_canvas_modulation.a
	
	%MainModulate.color = final_color


func set_weather_modulate_color(color: Color) -> void:
	%WeatherModulate.get_material().set_shader_parameter("modulate", color)


func get_canvas_modulate_color() -> Color:
	return current_canvas_modulation


func get_secondary_transition_node() -> ColorRect:
	return %SecondaryTransition


func set_flash_color(color: Color, blend: CanvasItemMaterial.BlendMode) -> void:
	%Flash.color = color
	%Flash.get_material().blend_mode = blend

 
func show_popup_message(obj: Dictionary) -> void:
	animate_items.add_single_item(obj)


# Audio System
func _load_audio_stream(audio: Variant) -> AudioStream:
	"""Convert various audio input types to AudioStream"""
	if audio is AudioStream:
		return audio
	elif audio is String and ResourceLoader.exists(audio):
		return load(audio)
	return null


func _play_audio_on_player(player: AudioStreamPlayer, audio_stream: AudioStream, volume: float = 0.0, pitch: float = 1.0) -> void:
	"""Play audio on a specific player"""
	player.stop()
	player.stream = audio_stream
	player.volume_db = volume
	player.pitch_scale = pitch
	player.play()


func _stop_audio_players_with_fade(players: Array, fade_duration: float = 0.0) -> void:
	"""Stop audio players with optional fade"""
	if fade_duration == 0:
		for player in players:
			player.stop()
	else:
		var any_playing = false
		for player in players:
			if player.is_playing():
				any_playing = true
				break
		
		if any_playing:
			var tween = create_tween()
			tween.set_parallel(true)
			for player in players:
				tween.tween_property(player, "volume_db", -80, fade_duration)
			tween.set_parallel(false)
			for player in players:
				tween.tween_callback(player.stop)


func _play_audio_with_crossfade(audio_type: String, audio: Variant, volume: float = 0.0, pitch: float = 1.0, fade_duration: float = 0.0) -> void:
	"""Generic audio playback with crossfade support"""
	var audio_stream = _load_audio_stream(audio)
	if not audio_stream:
		return
	
	var audio_data = audio_players[audio_type]
	var old_player = audio_data.players[audio_data.current_index]
	
	# Switch to next player
	audio_data.current_index = (audio_data.current_index + 1) % audio_data.players.size()
	var new_player = audio_data.players[audio_data.current_index]
	
	# Update current player reference for BGM
	if audio_type == "bgm" or audio_type == "bgs":
		audio_data.current_player = new_player
	
	# Check if same audio is already playing
	if old_player.is_playing() and old_player.stream and old_player.stream.resource_path == audio_stream.resource_path:
		return
	
	# Setup new player
	new_player.stream = audio_stream
	new_player.pitch_scale = pitch
	new_player.play()
	
	# Handle crossfade or immediate switch
	if fade_duration > 0:
		new_player.volume_db = -80
		var tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(old_player, "volume_db", -80, fade_duration)
		tween.tween_property(new_player, "volume_db", volume, fade_duration)
		tween.set_parallel(false)
		tween.tween_callback(old_player.stop)
	else:
		new_player.volume_db = volume
		old_player.stop()


func get_dynamic_shadows_node() -> Node2D:
	return %DynamicShadows


# Public Audio Interface
func play_bgm(bgm: Variant, volume: float = 0.0, pitch: float = 1.0, fade_duration: float = 0.0) -> void:
	_play_audio_with_crossfade("bgm", bgm, volume, pitch, fade_duration)


func play_bgs(bgs: Variant, volume: float = 0.0, pitch: float = 1.0, fade_duration: float = 0.0) -> void:
	_play_audio_with_crossfade("bgs", bgs, volume, pitch, fade_duration)


func play_se(fx: Variant, volume: float = 0.0, pitch: float = 1.0) -> void:
	var audio_stream = _load_audio_stream(fx)
	if not audio_stream:
		return
	
	var se_data = audio_players.se
	se_data.current_index = (se_data.current_index + 1) % se_data.players.size()
	var player = se_data.players[se_data.current_index]
	
	_play_audio_on_player(player, audio_stream, volume, pitch)


func play_video(path: String, loop: bool = false, fade_out_time: float = 0.0) -> VideoStreamPlayer:
	stop_video()
		
	if ResourceLoader.exists(path):
		var video = load(path)
		if video is VideoStream:
			var scn = VideoStreamPlayer.new()
			scn.stream = video
			scn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			scn.size_flags_vertical = Control.SIZE_EXPAND_FILL
			scn.expand = true
			scn.loop = loop
			%VideoContainer.add_child(scn)
			
			scn.play()
			var video_length = scn.get_stream_length()
			# Caution. The get_stream_length function will always return 0 for
			# videos supported by the default video player,
			# because it has not yet been implemented.
			if not loop:
				if fade_out_time > 0 and video_length > fade_out_time:
					var t = create_tween()
					t.tween_interval(fade_out_time - fade_out_time)
					t.tween_property(scn, "modulate", Color.TRANSPARENT, fade_out_time)
					t.tween_callback(scn.queue_free)
				else:
					scn.finished.connect(scn.queue_free)

			
			return scn
	
	return null


func stop_video() -> void:
	for child in %VideoContainer.get_children():
		child.queue_free()


func play_me(me: Variant, volume: float = 0.0, pitch: float = 1.0) -> void:
	var audio_stream = _load_audio_stream(me)
	if not audio_stream:
		return
	
	stop_bgm()
	_play_audio_on_player(audio_players.me.players[0], audio_stream, volume, pitch)


func stop_bgm(fade_duration: float = 0) -> void:
	_stop_audio_players_with_fade(audio_players.bgm.players, fade_duration)


func stop_bgs(fade_duration: float = 0) -> void:
	_stop_audio_players_with_fade(audio_players.bgs.players, fade_duration)


func stop_se() -> void:
	_stop_audio_players_with_fade(audio_players.se.players)


# BGM Save/Restore
func save_bgm() -> void:
	var current_bgm_player = audio_players.bgm.current_player
	if current_bgm_player and current_bgm_player.is_playing() and current_bgm_player.stream and GameManager.game_state:
		GameManager.game_state.bgm_saved = {
			"volume": current_bgm_player.volume_db,
			"pitch": current_bgm_player.pitch_scale,
			"path": current_bgm_player.stream.get_path(),
			"playback_position": current_bgm_player.get_playback_position()
		}


func restore_bgm() -> void:
	if not GameManager.game_state or not GameManager.game_state.bgm_saved:
		return
	
	stop_bgm()
	var saved_data = GameManager.game_state.bgm_saved
	var volume = saved_data.get("volume", 0.0)
	var pitch = saved_data.get("pitch", 1.0)
	var path = saved_data.get("path", "")
	var playback_position = saved_data.get("playback_position", 0.0)
	
	if ResourceLoader.exists(path):
		var player = audio_players.bgm.players[0]
		player.stream = load(path)
		player.volume_db = volume
		player.pitch_scale = pitch
		player.play()
		player.seek(playback_position)


# System Audio (FX and Music) 
func play_fx(id: Variant) -> void:
	if fx_busy or id in last_fx_ids: return 
	last_fx_ids[id] = 0.05
	var sound_data = _get_system_sound_data("game_fxs", id, _get_fx_sound_id(id))
	if sound_data:
		var pitch = _calculate_pitch(sound_data)
		play_se(sound_data.get("path", ""), sound_data.get("volume", 0.0), pitch)


func play_music(id: Variant) -> void:
	var sound_data = _get_system_sound_data("game_musics", id, _get_music_sound_id(id))
	if sound_data:
		var pitch = _calculate_pitch(sound_data)
		play_bgm(sound_data.get("path", ""), sound_data.get("volume", 0.0), pitch, 1.5)


func get_fx_path(id: Variant) -> String:
	var fxs = RPGSYSTEM.database.system.game_fxs
	var fx_id = _get_fx_sound_id(id)
	
	if fx_id > -1 and fxs.size() > fx_id:
		return RPGSYSTEM.database.system.game_fxs[fx_id].path
	
	return ""


func _get_fx_sound_id(id: Variant) -> int:
	"""Map FX IDs to sound indices"""
	
	var sound_list = [
		["cursor", "hover"],
		["select", "accept", "ok"],
		["cancel", "back"],
		["error"],
		["equip"],
		["save"],
		["load"],
		["erase_save"],
		["battle_start"],
		["battle_end"],
		["escape"],
		["lost_battle", "lost"],
		["win_battle", "win"],
		["failure"],
		["evasion"],
		["reflex", "magic_reflex"],
		["buy", "buy_item"],
		["sell", "sell_item"],
		["transaction", "complete_transaction"],
		["no_money_error"],
		["restock"],
		["use_item"],
		["use_skill"],
		["start_extraction"],
		["extraction_success"],
		["extraction_cancel"],
		["extraction_critical"],
		["switch_hero_panels"]
	]
	
	if typeof(id) == TYPE_INT:
		if id < 0 or id >= sound_list.size():
			return -1
		else:
			return id
	
	id = str(id).to_lower().replace(" ", "_")
	for i in sound_list.size():
		if id in sound_list[i]:
			return i
	
	return -1


func _get_music_sound_id(id: Variant) -> int:
	"""Map music IDs to sound indices"""
	match id:
		"title", 0: return 0
		"battle", 1: return 1
		"victory", 2: return 2
		"defeat", 3: return 3
		"game_end", 4: return 4
		"land_transport", 5: return 5
		"sea_transport", 6: return 6
		"air_transport", 7: return 7
	return -1


func _get_system_sound_data(array_name: String, _id: Variant, sound_id: int) -> Dictionary:
	"""Get sound data from system arrays"""
	if sound_id > -1 and RPGSYSTEM.database.system.get(array_name).size() > sound_id:
		return RPGSYSTEM.database.system.get(array_name)[sound_id]
	return {}


func _calculate_pitch(sound_data: Dictionary) -> float:
	"""Calculate pitch with random variation if specified"""
	var pitch1 = sound_data.get("pitch", 1.0)
	var pitch2 = sound_data.get("pitch2", -1)
	return pitch1 if pitch2 == -1 else randf_range(pitch1, pitch2)


# Map Management
func clear_current_map() -> void:
	%MapContainer.repeat_size = Vector2.ZERO
	for map in %MapContainer.get_children():
		if map is RPGMap:
			map.queue_free()
	for child in %OptionsCanvas.get_children():
		child.queue_free()
	GameInterpreter.clear()


func set_map(map: RPGMap) -> void:
	if not map:
		return
	
	clear_current_map()
	current_map = map
	GameManager.current_map = current_map
	
	_add_map_to_container(map)
	_configure_map_scrolling(map)


func _add_map_to_container(map: RPGMap) -> void:
	"""Add map to container, handling reparenting if necessary"""
	if map.is_inside_tree():
		map.reparent(%MapContainer)
	else:
		%MapContainer.add_child(map)


func clear_map_repeating() -> void:
	%MapContainer.repeat_times = 1
	%MapContainer.repeat_size = Vector2.ZERO
	%DynamicShadows.clear_map_repeating()


func enable_map_repeating() -> void:
	%MapContainer.repeat_times = 4
	%DynamicShadows.enable_map_repeating()


func _configure_map_scrolling(map: RPGMap) -> void:
	"""Configure map scrolling based on map properties"""
	if %MapContainer.repeat_times == 1: return
	
	var used_rect = map.get_used_rect(false)
	%MapContainer.repeat_size = used_rect.size
	
	var viewport_size = get_viewport().size
	var max_repeats_x = max(2, ceil(used_rect.size.x / viewport_size.x))
	var max_repeats_y = max(2, ceil(used_rect.size.y / viewport_size.y))
	var max_repeats = max(max_repeats_x, max_repeats_y)
	
	%MapContainer.repeat_times = max_repeats if (map.infinite_horizontal_scroll or map.infinite_vertical_scroll) else 1


# Getters
func get_main_scene_texture() -> Texture:
	if main_game_viewport:
		return main_game_viewport.get_texture()
	else:
		return null


func get_main_sub_viewport_container() -> SubViewportContainer:
	return %MainSubViewportContainer


func get_screen_effect_canvas() -> CanvasLayer:
	return %ScreenEffectCanvas


func get_image_container() -> Node:
	return %ImageContainer


func get_scene_container() -> Node:
	return %SceneContainer


func get_main_camera() -> Camera2D:
	return %MainCamera


func get_main_interpreter() -> MainInterpreter:
	return interpreter


func get_character_baker() -> CharacterBaker:
	return %CharacterBaker


func _destroy_gui_scenes() -> void:
	var canvas = %GUICanvas
	for child in canvas.get_children():
		child.queue_free()


# Scene Management
func change_scene(path: String, destroy_gui: bool = false) -> void:
	busy = true
	interpreter.transfer_in_progress = true
	await _wait_frames(3)
	%TransitionCanvas.layer = 128
	var transition_texture = _create_transition_texture()
	await _load_scene_async(path, transition_texture)
	if _current_scene_loaded and _current_scene_loaded is RPGMap:
		await _current_scene_loaded.map_started
	if GameManager.game_state:
		GameManager.game_state.erased_events.clear()
	if destroy_gui:
		_destroy_gui_scenes()
	scene_changed.emit()
	await transition_manager.end()
	%TransitionCanvas.layer = 115
	
	interpreter.transfer_in_progress = false
	transition_manager.visible = false


func _wait_frames(count: int) -> void:
	"""Wait for specified number of frames"""
	for i in count:
		await get_tree().process_frame


func _create_transition_texture() -> ImageTexture:
	"""Create texture for transition effect"""
	var img = get_viewport().get_texture().get_image()
	return ImageTexture.create_from_image(img)


func _load_scene_async(path: String, transition_texture: ImageTexture) -> void:
	"""Load scene asynchronously with error handling"""
	if not ResourceLoader.exists(path):
		printerr("Invalid Path: ", path)
		return
	
	ResourceLoader.load_threaded_request(path)
	await transition_manager.start(transition_texture)
	
	var res = await _wait_for_resource_load(path)
	if res:
		_instantiate_and_setup_scene(res, path)
	else:
		_current_scene_loaded = null


func _wait_for_resource_load(path: String) -> Resource:
	"""Wait for threaded resource loading to complete"""
	var file_status = ResourceLoader.load_threaded_get_status(path)
	
	while file_status != ResourceLoader.ThreadLoadStatus.THREAD_LOAD_LOADED:
		if file_status in [ResourceLoader.ThreadLoadStatus.THREAD_LOAD_FAILED, ResourceLoader.ThreadLoadStatus.THREAD_LOAD_INVALID_RESOURCE]:
			printerr("Error loading file: ", path)
			get_tree().quit()
			return null
			
		await get_tree().process_frame
		file_status = ResourceLoader.load_threaded_get_status(path)
	
	return ResourceLoader.load_threaded_get(path)


func _instantiate_and_setup_scene(res: Resource, path: String) -> void:
	"""Instantiate and setup the loaded scene"""
	if not res is PackedScene:
		printerr("The current path is not a scene: ", path)
		_current_scene_loaded = null
		return
	
	var next_scene = res.instantiate()
	_current_scene_loaded = next_scene
	_setup_scene_based_on_type(next_scene)
	current_scene = next_scene


func _setup_scene_based_on_type(next_scene: Node) -> void:
	"""Setup scene based on its type"""
	if next_scene is SCENE_TITTLE or next_scene is SCENE_END:
		_setup_gui_scene(next_scene)
	elif next_scene is RPGMap:
		_setup_map_scene(next_scene)


func _setup_gui_scene(scene: Node) -> void:
	"""Setup GUI-based scenes (title, end)"""
	var canvas = %GUICanvas
	for child in canvas.get_children():
		child.queue_free()
	canvas.add_child(scene)


func _setup_map_scene(map_scene: RPGMap) -> void:
	"""Setup map-based scenes"""
	if current_scene is SCENE_TITTLE:
		current_scene.queue_free()
	
	var canvas = %MapContainer
	var shadows = %ShadowContainer
	for child in canvas.get_children():
		if child != shadows:
			child.queue_free()
	
	set_map(map_scene)
