@tool
class_name RPGSavedGameData
extends Resource

# The complete game state (inventory, variables, switches, player pos/vehicles, stats)
@export var game_state: GameUserData

# Dictionary[int (Event ID), RPGEventSaveData]
# Stores the runtime state (direction, page) of all loaded events on the map.
@export var current_map_events: Dictionary = {}

# current map bgm playing
@export var current_map_bgm: Dictionary = {}

# current map bgs playing
@export var current_map_bgs: Dictionary = {}

# type of vehicle driven by the player before saving
@export var player_on_vehicle: int = -1

# saves the status of the main scene (camera, modulation, scenes)
@export var main_scene_config: Dictionary = {}

@export var engine_version: String



# Internal ID mainly for runtime reference, the file name dictates the actual slot on disk.
var save_slot_id: int = 0
static var show_debug_prints: bool = false

const AUTO_SAVE_SLOT_ID = 0


#region Initialization and Population (Instance Methods)

## Initializes the data object. call this on a new instance before passing it to the static save function.
func initialize(slot_id: int, current_game_state: GameUserData) -> void:
	save_slot_id = slot_id
	game_state = current_game_state # Deep clone or reference depending on your GameUserData implementation
	current_map_events.clear()
	engine_version = ProjectSettings.get_setting("application/config/version")


## Sets the event save data by iterating over currently loaded map events.
## Assumes the game is currently running on a map.
func set_map_events(current_map: RPGMap) -> void:
	current_map_events.clear()
	
	if not current_map: return
	
	# Iterate over the dictionary of currently loaded runtime events
	for event_id in current_map.current_ingame_events.keys():
		var ingame_event: RPGMap.IngameEvent = current_map.current_ingame_events[event_id]
		
		# Ensure the runtime object is valid and has directional state
		if ingame_event and ingame_event.lpc_event and "current_direction" in ingame_event.lpc_event:
			
			var save_data = RPGEventSaveData.new()
			
			# The page ID is retrieved from the IngameEvent wrapper
			save_data.position = ingame_event.lpc_event.position
			save_data.event_id = ingame_event.event.id
			save_data.direction = ingame_event.lpc_event.current_direction
			save_data.active_page_id = ingame_event.page_id
			
			current_map_events[event_id] = save_data

#endregion


#region Static I/O Operations (Save, Load, Delete)

## Checks if there is at least one save file (auto-save or manual) in the save directory.
## Returns true if any valid save file is found. Useful for enabling "Continue" buttons.
static func has_any_save_file() -> bool:
	var paths = _get_paths_for_slot(AUTO_SAVE_SLOT_ID)
	var base_dir = paths["dir"] 

	var dir = DirAccess.open(base_dir)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		
		while file_name != "":
			if not dir.current_is_dir():
				if file_name.begins_with("_save_data") and file_name.ends_with(".sav"):
					dir.list_dir_end()
					return true
			
			file_name = dir.get_next()
			
		dir.list_dir_end()
	
	return false


## Checks if an auto-save file exists.
static func has_autosave() -> bool:
	var paths = _get_paths_for_slot(AUTO_SAVE_SLOT_ID)
	return FileAccess.file_exists(paths["preview"])


## Retrieves the last modification timestamp (Unix time) of the save file for the given slot.
## Returns -1 if the file is missing.
static func get_save_date(slot_id: int) -> int:
	var paths = _get_paths_for_slot(slot_id)
	var data_path = paths["data"]
	
	if not FileAccess.file_exists(data_path):
		return -1
		
	return FileAccess.get_modified_time(data_path)


static func set_properties_in_obj(obj: Dictionary, scn: Node) -> void:
	if not "properties" in obj:
		return
	
	var properties = obj.properties
	for key in properties.keys():
		if key in scn:
			scn.set(key, properties[key])

	if scn is CanvasItem and scn.material is CanvasItemMaterial:
		properties.blend_mode = scn.material.blend_mode
	else:
		properties.blend_mode = null


static func set_tween_info_into(obj: Dictionary, tweens_data: Dictionary) -> void:
	var active_tweens = {}
	for key in ["position", "rotation", "scale", "modulate"]:
		if key in tweens_data:
			var info = tweens_data[key]
			# Calcular tiempo restante
			var elapsed = (Time.get_ticks_msec() - info.start_time) / 1000.0
			var remaining = info.duration - elapsed
			
			if remaining > 0:
				info.duration = remaining
				active_tweens[key] = info
	
	obj.merge(active_tweens)


static func populate_scene_data(scenes: Array, scene_data: Array) -> void:
	for scn in scenes:
		if is_instance_valid(scn) and not scn.is_queued_for_deletion():
			var obj = {"path": scn.get_scene_file_path(), "properties": {}, "creation_properties": {}, "extra_config": {}}
			if scn.has_meta("creation_properties"):
				obj.creation_properties = scn.get_meta("creation_properties")
			if scn.has_method("get_custom_save_data"):
				obj.extra_config = scn.get_custom_save_data()
			set_properties_in_obj(obj, scn)
			scene_data.append(obj)


static func _serialize_camera_target(obj: Variant) -> Dictionary:
	var node = null
	var priority = 10
	if obj is Dictionary:
		node = obj.get("target", null)
		priority = obj.get("priority", 10)
	else:
		node = obj
	
	if not is_instance_valid(node):
		return {"type": "none"}
	
	if node == GameManager.current_player:
		return {"type": "player", "priority": priority}
	
	if node is LPCEvent:
		return {"type": "event", "id": node.current_event.id, "priority": priority}
	
	if node is RPGVehicle:
		return {"type": "vehicle", "id": node.vehicle_type, "priority": priority} # O un ID único si hay varios
		
	return {"type": "none"}


static func _serialize_camera_targets(data: Array[Dictionary]) -> Array:
	var serialize_data: Array[Dictionary] = []
	for obj: Dictionary in data:
		serialize_data.append(_serialize_camera_target(obj))
	return serialize_data


## Static function to save a game data object to a specific slot.
## Automatically handles compression, preview generation, and screenshot resizing.
static func save_to_slot(slot_id: int, game_data: GameUserData, current_map: RPGMap, preview_texture: Texture2D = null) -> bool:
	if slot_id < 0:
		if show_debug_prints: printerr("Save failed: Invalid slot_id or data object is null.")
		return false
	
	game_data.current_day_time = DayNightManager.get_current_hour()
	
	# create save data
	var data_to_save = RPGSavedGameData.new()
	data_to_save.initialize(slot_id, game_data)
	
	# Set map events
	data_to_save.set_map_events(current_map)
	var main_scene = GameManager.get_main_scene()
	if main_scene:
		# Set camera
		var camera = main_scene.get_main_camera()
		data_to_save.main_scene_config.camera = {
			"target": _serialize_camera_target(camera.target),
			"targets": _serialize_camera_targets(camera.targets),
			"zoom": camera.zoom,
			"target_zoom": camera.target_zoom,
			"traumas": camera.traumas,
			"global_position": camera.global_position
		}
		# Set modulate
		data_to_save.main_scene_config.modulates = main_scene.get_modulate_scenes()
		# set BGM
		var current_bgm_player = main_scene.audio_players.bgm.current_player
		if current_bgm_player and current_bgm_player.is_playing() and current_bgm_player.stream:
			var obj = {
				"volume": current_bgm_player.volume_db,
				"pitch": current_bgm_player.pitch_scale,
				"path": current_bgm_player.stream.get_path(),
				"playback_position": current_bgm_player.get_playback_position()
			}
			data_to_save.current_map_bgm = obj
		# set BGS
		var current_bgs_player = main_scene.audio_players.bgs.current_player
		if current_bgs_player and current_bgs_player.is_playing() and current_bgs_player.stream:
			var obj = {
				"volume": current_bgs_player.volume_db,
				"pitch": current_bgs_player.pitch_scale,
				"path": current_bgs_player.stream.get_path(),
				"playback_position": current_bgs_player.get_playback_position()
			}
			data_to_save.current_map_bgs = obj
		# set player on vehicle
		if GameManager.current_player and GameManager.current_player.is_on_vehicle:
			var vehicle: RPGVehicle = GameManager.current_player.current_vehicle
			if vehicle:
				data_to_save.player_on_vehicle = vehicle.vehicle_type
				if GameManager.current_map:
					var vehicles = ["land_transport_start_position", "sea_transport_start_position", "air_transport_start_position"]
					var vehicle_id = clamp(int(vehicle.vehicle_type), 0, 2)
					var map_id = GameManager.current_map.internal_id
					var vehicle_position: RPGMapPosition = RPGMapPosition.new(map_id, vehicle.get_current_tile())
					GameManager.game_state.set(vehicles[vehicle_id], vehicle_position)
		# Set Screen Scenes (extra config if scene has method get_custom_save_data)
		var scenes = GameManager.current_ingame_scenes.values()
		data_to_save.main_scene_config.ingame_scenes = []
		populate_scene_data(scenes, data_to_save.main_scene_config.ingame_scenes)
		# Set image Scenes (extra config if scene has method get_custom_save_data)
		var images = GameManager.current_ingame_images.values()
		data_to_save.main_scene_config.ingame_images = []
		for img in images:
			if is_instance_valid(img) and not img.is_queued_for_deletion():
				var obj = {"path": img.get_scene_file_path(), "creation_properties": {}, "extra_config": {}, "tweens": {}}
				if img.has_meta("creation_properties"):
					obj.creation_properties = img.get_meta("creation_properties")
				if img.has_meta("active_tweens"):
					var active_tweens = img.get_meta("active_tweens")
					if not active_tweens.is_empty():
						set_tween_info_into(obj.tweens, active_tweens)
						obj.extra_config = img.get_custom_save_data()
				set_properties_in_obj(obj, img)
				data_to_save.main_scene_config.ingame_images.append(obj)
		# Set Weather Scenes (extra config if scene has method get_custom_save_data)
		var weather_scenes = main_scene.get_tree().get_nodes_in_group("_map_weather_scene")
		data_to_save.main_scene_config.weather_scenes = []
		populate_scene_data(weather_scenes, data_to_save.main_scene_config.weather_scenes)
		# Set video Scenes (extra config if scene has method get_custom_save_data)
		var video_scenes = main_scene.get_tree().get_nodes_in_group("_map_video_scene")
		data_to_save.main_scene_config.video_scenes = []
		populate_scene_data(video_scenes, data_to_save.main_scene_config.video_scenes)
	
	# 1. Determine Paths
	var paths = _get_paths_for_slot(slot_id)
	var data_path = paths["data"]
	var preview_path = paths["preview"]
	var image_path = paths["image"]
	var dir_path = paths["dir"]
	
	# Ensure directory exists
	if not DirAccess.dir_exists_absolute(dir_path):
		DirAccess.make_dir_recursive_absolute(dir_path)

	# 2. Create and Populate Preview Resource
	# We extract summary info from the main game_state for the lightweight preview file.
	var preview_data = RPGSavedGamePreview.new()
	if data_to_save.game_state:
		preview_data.current_party_ids = data_to_save.game_state.current_party
		preview_data.current_gold = data_to_save.game_state.current_gold
		preview_data.play_time = data_to_save.game_state.stats.play_time
		preview_data.current_chapter_name = data_to_save.game_state.game_chapter_name

	# 3. Save Files
	
	# --- COMPRESSED SAVE (Main Data) ---
	var data_file = FileAccess.open_compressed(data_path, FileAccess.WRITE, FileAccess.COMPRESSION_ZSTD)
	if data_file:
		data_file.store_var(data_to_save, true)
		data_file.close()
	else:
		if show_debug_prints: printerr("Failed to open compressed file for writing: %s" % data_path)
		return false
		
	# --- COMPRESSED SAVE (Preview Data) ---
	var preview_file = FileAccess.open_compressed(preview_path, FileAccess.WRITE, FileAccess.COMPRESSION_ZSTD)
	if preview_file:
		preview_file.store_var(preview_data, true)
		preview_file.close()
	else:
		if show_debug_prints: printerr("Failed to open preview file for writing: %s" % preview_path)
	
	# --- RESIZED SCREENSHOT (30%) ---
	if preview_texture:
		var img: Image = preview_texture.get_image()
		if img:
			# Resize to 30% of original size using Cubic interpolation
			var new_width: int = int(img.get_width() * 0.3)
			var new_height: int = int(img.get_height() * 0.3)
			img.resize(new_width, new_height, Image.INTERPOLATE_CUBIC)
			
			var result_image = img.save_png(image_path)
			if result_image != OK:
				if show_debug_prints: printerr("Failed to save resized screenshot to: %s" % image_path)
				# We don't return false here because the main save succeeded.
		
	return true


## Loads a saved game from disk given a slot ID.
static func load_from_slot(slot_id: int) -> RPGSavedGameData:
	var paths = _get_paths_for_slot(slot_id)
	var data_path = paths["data"]
	
	if not FileAccess.file_exists(data_path):
		if show_debug_prints: printerr("Save file not found at: %s" % data_path)
		return null

	# Open Compressed File (Must match the compression mode used in save)
	var data_file = FileAccess.open_compressed(data_path, FileAccess.READ, FileAccess.COMPRESSION_ZSTD)
	if not data_file:
		if show_debug_prints: printerr("Failed to open compressed save file: %s" % data_path)
		return null
	
	var loaded_data = data_file.get_var(true)
	data_file.close()
	
	if loaded_data is RPGSavedGameData:
		loaded_data.save_slot_id = slot_id
		_validate_data(loaded_data.game_state)
		return loaded_data
	else:
		if show_debug_prints: printerr("Failed to cast loaded data to RPGSavedGameData. File might be corrupted.")
		return null


## Loads ONLY the lightweight preview resource from a slot. Returns null if not found.
static func get_preview_data(slot_id: int) -> RPGSavedGamePreview:
	var paths = _get_paths_for_slot(slot_id)

	var preview_path = paths["preview"]
	if not FileAccess.file_exists(preview_path):
		return null
		
	# Open Compressed File (ZSTD)
	var file = FileAccess.open_compressed(preview_path, FileAccess.READ, FileAccess.COMPRESSION_ZSTD)
	if not file:
		if show_debug_prints: printerr("Failed to open compressed preview file: %s" % preview_path)
		return null
		
	var data = file.get_var(true)
	file.close()
	
	if data is RPGSavedGamePreview:
		return data
	
	return null


## Helper to get the expected image path for a slot, so the UI doesn't need to know file naming rules.
static func get_image_path(slot_id: int) -> String:
	var paths = _get_paths_for_slot(slot_id)
	return paths["image"]


## Validates and updates the GameUserData to match the current Database state.
## This handles cases where the Database was updated (new variables, new traits, new actor params)
## after the save file was created.
static func _validate_data(state: GameUserData) -> void:
	if not state: return
	
	if RPGMapsInfo.get_map_by_id(state.current_map_id).is_empty():
		if show_debug_prints: printerr("🚫 The target map does not exist.")
		GameManager.exit()

	# 1. Update Variables and Switches
	# If the database now has more switches/variables than the save file, resize the arrays.
	# PackedArrays in Godot fill new slots with default values (0, false, empty string).
	if RPGSYSTEM.system.variables.size() > state.game_variables.size():
		state.game_variables.resize(RPGSYSTEM.system.variables.size())
		
	if RPGSYSTEM.system.switches.size() > state.game_switches.size():
		state.game_switches.resize(RPGSYSTEM.system.switches.size())
		
	if RPGSYSTEM.system.text_variables.size() > state.game_text_variables.size():
		state.game_text_variables.resize(RPGSYSTEM.system.text_variables.size())

	# 2. Update Global User Parameters
	if RPGSYSTEM.database.types.user_parameters.size() > state.game_user_parameters.size():
		state.game_user_parameters.resize(RPGSYSTEM.database.types.user_parameters.size())

	# 3. Refresh Actors
	# Iterates through all actors stored in the save file and updates their structure.
	for actor_id in state.actors:
		var actor = state.actors[actor_id]
		if actor and actor.has_method("refresh_actor_data"):
			actor.refresh_actor_data()
			if not actor.is_valid:
				state.actors.erase(actor_id)
	
	# 4. Sanitize Inventory
	# Remove items, weapons, or armors that no longer exist in the database to prevent crashes.
	
	# Items
	var items_to_remove = []
	for item_id in state.items:
		if item_id >= RPGSYSTEM.database.items.size() or item_id <= 0:
			items_to_remove.append(item_id)
	for id in items_to_remove:
		state.items.erase(id)
		
	# Weapons
	var weapons_to_remove = []
	for item_id in state.weapons:
		if item_id >= RPGSYSTEM.database.weapons.size() or item_id <= 0:
			weapons_to_remove.append(item_id)
	for id in weapons_to_remove:
		state.weapons.erase(id)

	# Armors
	var armors_to_remove = []
	for item_id in state.armors:
		if item_id >= RPGSYSTEM.database.armors.size() or item_id <= 0:
			armors_to_remove.append(item_id)
	for id in armors_to_remove:
		state.armors.erase(id)


## Deletes all files (Data, Preview, Image) associated with a specific slot.
static func delete_slot(slot_id: int) -> void:
	var paths = _get_paths_for_slot(slot_id)
	var dir = DirAccess.open(paths["dir"])
	
	if not dir:
		if show_debug_prints: printerr("Cannot access save directory.")
		return

	# Try to remove each file if it exists
	if dir.file_exists(paths["data"].get_file()):
		dir.remove(paths["data"].get_file())
		
	if dir.file_exists(paths["preview"].get_file()):
		dir.remove(paths["preview"].get_file())
		
	if dir.file_exists(paths["image"].get_file()):
		dir.remove(paths["image"].get_file())


# Helper function to generate paths, ensuring consistency across Save/Load/Delete.
static func _get_paths_for_slot(slot_id: int) -> Dictionary:
	var game_name = ProjectSettings.get_setting("application/config/name", "DefaultGame")
	var save_dir = "user://" + game_name + "/"
	var global_dir = ProjectSettings.globalize_path(save_dir)
	
	var file_suffix = ""
	
	if slot_id == AUTO_SAVE_SLOT_ID:
		file_suffix = "_autosave"
	else:
		file_suffix = "_slot" + str(slot_id)
	
	return {
		"dir": global_dir,
		"data": save_dir + "_save_data" + file_suffix + ".sav",
		"preview": save_dir + "_save_data_preview" + file_suffix + ".sav",
		"image": save_dir + "_save_data_preview_image" + file_suffix + ".png"
	}

#endregion
