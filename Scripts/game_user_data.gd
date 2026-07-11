class_name GameUserData
extends Resource


#region Exports regions
## Dictionary containing game actors data by their ID.
@export var actors: Dictionary = {}

## Array of actor IDs currently in the active party.
@export var current_party: PackedInt64Array = []

## Array of actor IDs that are locked in the party and cannot be removed.
@export var party_member_locked: PackedInt64Array = []

## Dictionary of inventory items sorted by item ID.
@export var items: Dictionary = {}

## Dictionary of inventory weapons sorted by item ID.
@export var weapons: Dictionary = {}

## Dictionary of inventory armors sorted by item ID.
@export var armors: Dictionary = {}

## Dictionary of gear sets or costumes sorted by item ID.
@export var sets: Dictionary = {}

## Dictionary mapping actor IDs to their skill evolution usage data.
@export var skill_evolves: Dictionary = {}

## Current state and progression of the player's active and unlocked quests.
@export var quest_progress: GameQuestProgress = GameQuestProgress.new()

## Array of dictionaries representing NPCs currently escorting the player.
@export var escorted_npcs: Array[Dictionary] = []

## Dictionary of extraction items sorted by map ID and item ID.
@export var extraction_items: Dictionary = {}

## Dictionary mapping profession IDs to their current levels and experience.
@export var profession_levels: Dictionary = {}

## Current amount of gold the player has.
@export var current_gold: int = 0

## Array of float variables used for custom game logic.
@export var game_variables: PackedFloat32Array = []

## Array of string variables used for custom game text.
@export var game_text_variables: PackedStringArray = []

## Array of byte flags used as game switches.
@export var game_switches: PackedByteArray = []

## Dictionary of self switches for specific map events.
@export var game_self_switches: Dictionary = {}

## Array of float parameters defined by the user.
@export var game_user_parameters: PackedFloat32Array = []

## Name of the current chapter of the game.
@export var game_chapter_name: String = ""

## Dictionary of active game timers.
@export var active_timers: Dictionary = {}

## Dictionary of active shop timers sorted by shop ID.
@export var active_shop_timers: Dictionary = {}

## ID of the map the player is currently exploring.
@export var current_map_id: int = -1

## Current grid coordinates of the player on the map.
@export var current_map_position: Vector2i

## Current facing direction of the player character.
@export var current_direction: LPCCharacter.DIRECTIONS = LPCCharacter.DIRECTIONS.DOWN

## Starting position coordinates for the land transport vehicle.
@export var land_transport_start_position: RPGMapPosition = RPGMapPosition.new()

## Starting position coordinates for the sea transport vehicle.
@export var sea_transport_start_position: RPGMapPosition = RPGMapPosition.new()

## Starting position coordinates for the air transport vehicle.
@export var air_transport_start_position: RPGMapPosition = RPGMapPosition.new()

## General statistics and history of the current playthrough.
@export var stats: GameStatistics = GameStatistics.new()

## Configuration settings for the current message window UI.
@export var current_message_config: Dictionary = {}

## Flag to determine if accessing the main menu scene is prohibited.
@export var menu_scene_prohibited: bool = false

## Flag to determine if saving the game is currently prohibited.
@export var save_scene_prohibited: bool = false

## Flag to determine if changing party formation is prohibited.
@export var formation_scene_prohibited: bool = false

## Flag to enable or disable automatic saving functionality.
@export var auto_save: bool = false

## Flag to determine if the post-battle summary screen should be shown.
@export var post_battle_summary: bool = true

## Flag to enable active time battle system mechanics.
@export var active_time_battle: bool = false

## Dictionary containing data for the current screen transition effect.
@export var current_transition: Dictionary

## Current mode of experience point distribution among party members.
@export var experience_mode: int = 0

## Flag to enable or disable party followers visible on the map.
@export var followers_enabled: bool = false

## Flag to determine if followers track the player's movements strictly.
@export var followers_tracking_enabled: bool = true

## Component handling the day and night cycle visual effects.
@export var current_day_night_component: RPGDayNightComponent

## Dictionary storing the currently playing background music data.
@export var bgm_saved: Dictionary

## Dictionary for user plugins to store custom persistent data.
@export var plugin_data: Dictionary = {}

## Dictionary tracking which map names have been already shown to the player.
@export var map_names_shown: Dictionary = {}

## Current time of day in the game world.
@export var current_day_time: float = 0.0

## Array of event IDs that were temporarily erased via commands on the current map.
@export var erased_events: Array[int] = []

## Dictionary containing user configured in-game options.
@export var in_game_options: Dictionary = {}

## Dictionary storing data about the last item used by the player.
@export var last_item_used: Dictionary = {}

## Dictionary mapping actor IDs to the last skill they used.
@export var last_skill_used: Dictionary = {}

## Dictionary tracking events that have migrated between different maps.
@export var migrated_events: Dictionary = {}

## Path to a custom UI scene used for displaying the map name.
@export var custom_map_name_scene_path: String = ""

## Collection of crafting recipes the player has learned and can use to craft items or equipment [b]([itemtipe_itemid] = [recipes ids])[/b].
@export var crafting_recipes: Dictionary = {}

## Dictionary of active weather effects currently applied to the map.
@export var active_weathers: Dictionary = {}

## variable used to re-trigger events when a game is loaded
var current_events: Dictionary = {}
#endregion


#region Smart function for searching for a stat
var _stat_path_cache: Dictionary = {}

## Finds a game statistic by its name or path dynamically and returns its value.
## The lookup is case-insensitive and supports full/partial paths (e.g. "won", "battles.won", "user_stats:my_stat").
## Uses a cache to make repeated calls extremely fast (O(1)).
func find_stat(stat_path: String, _cache_result: bool = true) -> Variant:
	if stat_path.is_empty() or stats == null:
		return null
		
	# 0. Check cache first for instant O(1) retrieval
	if _stat_path_cache.has(stat_path):
		var steps = _stat_path_cache[stat_path]
		if steps != null:
			var val = _execute_cached_steps(stats, steps)
			if val != null:
				return val
				
	# Clean and trim user_stats: prefix if it exists
	var trimmed_path = stat_path
	if trimmed_path.begins_with("user_stats:"):
		trimmed_path = trimmed_path.trim_prefix("user_stats:")
		if stats and stats.user_stats:
			for key in stats.user_stats.keys():
				if str(key).to_lower() == trimmed_path.to_lower():
					# Cache it
					var steps = [
						[0, "user_stats"],
						[1, key, false]
					]
					if _cache_result:
						_stat_path_cache[stat_path] = steps
					return stats.user_stats[key]
	
	# Parse segments (split by . or /)
	var segments: Array[String] = []
	var parts = trimmed_path.replace(".", "/").split("/")
	for p in parts:
		var clean = p.strip_edges()
		if not clean.is_empty():
			segments.append(clean)
			
	if segments.is_empty():
		return null
		
	var steps: Array = []
	
	# 1. Try to resolve starting from the root 'stats' resource
	var walk_res = _walk_segments_case_insensitive(stats, segments, steps)
	if walk_res.found:
		if _cache_result:
			_stat_path_cache[stat_path] = steps
		return walk_res.value
		
	# 2. If not found, do a recursive search to locate the path
	steps.clear()
	var search_res = _search_recursively_case_insensitive(stats, segments, steps)
	if search_res.found:
		if _cache_result:
			_stat_path_cache[stat_path] = steps
		return search_res.value
		
	# 3. Last fallback: Check if the user specified a custom stat from user_stats directly
	if segments.size() == 1 and stats.user_stats:
		var target_key = segments[0].to_lower()
		for key in stats.user_stats.keys():
			if str(key).to_lower() == target_key:
				steps = [
					[0, "user_stats"],
					[1, key, false]
				]
				if _cache_result:
					_stat_path_cache[stat_path] = steps
				return stats.user_stats[key]
				
	return null

func _execute_cached_steps(start_val: Variant, steps: Array) -> Variant:
	var current = start_val
	for step in steps:
		if current == null:
			return null
		match step[0]:
			0: # Object property
				current = current.get(step[1])
			1: # Collection index/key lookup (step[1] = key_or_id, step[2] = is_array)
				if step[2]: # Array
					var found = false
					for item in current:
						if item is Object:
							for test_prop in ["id", "uid", "name", "key"]:
								if test_prop in item:
									if item.get(test_prop) == step[1]:
										current = item
										found = true
										break
						elif item is Dictionary:
							for test_key in ["id", "uid", "name", "key"]:
								if item.has(test_key):
									if item[test_key] == step[1]:
										current = item
										found = true
										break
						if found:
							break
					if not found:
						if typeof(step[1]) == TYPE_INT and step[1] >= 0 and step[1] < current.size():
							current = current[step[1]]
						else:
							return null
				else: # Dictionary
					current = current.get(step[1])
			2: # Auto-navigation inside member collection (step[1] = prop_name, step[2] = key_or_id, step[3] = is_array)
				current = current.get(step[1])
				if current == null:
					return null
				if step[3]: # Array
					var found = false
					for item in current:
						if item is Object:
							for test_prop in ["id", "uid", "name", "key"]:
								if test_prop in item:
									if item.get(test_prop) == step[2]:
										current = item
										found = true
										break
						elif item is Dictionary:
							for test_key in ["id", "uid", "name", "key"]:
								if item.has(test_key):
									if item[test_key] == step[2]:
										current = item
										found = true
										break
						if found:
							break
					if not found:
						if typeof(step[2]) == TYPE_INT and step[2] >= 0 and step[2] < current.size():
							current = current[step[2]]
						else:
							return null
				else: # Dictionary
					current = current.get(step[2])
	return current


func _walk_segments_case_insensitive(start_val: Variant, segments: Array[String], out_steps: Array) -> Dictionary:
	var current = start_val
	for i in range(segments.size()):
		var seg = segments[i].to_lower()
		if current == null:
			return {"found": false, "value": null}
		elif current is Object:
			var found_prop = false
			# 1. Exact case-insensitive match
			for prop in current.get_property_list():
				if prop.name.to_lower() == seg:
					current = current.get(prop.name)
					out_steps.append([0, prop.name])
					found_prop = true
					break
			# 2. Smart match (word splits and singular/plural normalization)
			if not found_prop:
				for prop in current.get_property_list():
					if _is_smart_match(prop.name, seg):
						current = current.get(prop.name)
						out_steps.append([0, prop.name])
						found_prop = true
						break
			# 3. Auto-navigation inside member collections
			if not found_prop:
				for prop in current.get_property_list():
					if prop.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
						var prop_val = current.get(prop.name)
						if prop_val is Array or prop_val is Dictionary:
							var col_res = _resolve_in_collection(prop_val, seg)
							if col_res.found:
								current = col_res.value
								out_steps.append([2, prop.name, col_res.key_or_id, col_res.is_array])
								found_prop = true
								break
			if not found_prop:
				return {"found": false, "value": null}
		elif current is Array or current is Dictionary:
			var col_res = _resolve_in_collection(current, seg)
			if col_res.found:
				current = col_res.value
				out_steps.append([1, col_res.key_or_id, col_res.is_array])
			else:
				return {"found": false, "value": null}
		else:
			return {"found": false, "value": null}
			
	return {"found": true, "value": current}


func _resolve_in_collection(collection: Variant, seg: String) -> Dictionary:
	if collection is Array:
		# 1. Search by id, uid, name, key
		for item in collection:
			if item is Object:
				for test_prop in ["id", "uid", "name", "key"]:
					if test_prop in item:
						var val = item.get(test_prop)
						if str(val).to_lower() == seg:
							return {"found": true, "value": item, "key_or_id": val, "is_array": true}
			elif item is Dictionary:
				for test_key in ["id", "uid", "name", "key"]:
					if item.has(test_key):
						var val = item[test_key]
						if str(val).to_lower() == seg:
							return {"found": true, "value": item, "key_or_id": val, "is_array": true}
		# 2. Fallback to index access
		if seg.is_valid_int():
			var idx = seg.to_int()
			if idx >= 0 and idx < collection.size():
				return {"found": true, "value": collection[idx], "key_or_id": idx, "is_array": true}
				
	elif collection is Dictionary:
		if collection.has(seg):
			return {"found": true, "value": collection[seg], "key_or_id": seg, "is_array": false}
		for key in collection.keys():
			if str(key).to_lower() == seg:
				return {"found": true, "value": collection[key], "key_or_id": key, "is_array": false}
		if seg.is_valid_int():
			var int_key = seg.to_int()
			if collection.has(int_key):
				return {"found": true, "value": collection[int_key], "key_or_id": int_key, "is_array": false}
		elif seg.is_valid_float():
			var float_key = seg.to_float()
			if collection.has(float_key):
				return {"found": true, "value": collection[float_key], "key_or_id": float_key, "is_array": false}
				
	return {"found": false, "value": null, "key_or_id": null, "is_array": false}


func _is_smart_match(prop_name: String, seg: String) -> bool:
	var clean_seg = seg.to_lower().trim_suffix("s")
	var words = prop_name.to_lower().split("_")
	for word in words:
		var clean_word = word.trim_suffix("s")
		# 1. Exact match
		if clean_word == clean_seg:
			return true
		# 2. Prefix match (with minimum length of 3 to avoid short ambiguous strings)
		if clean_seg.length() >= 3 and clean_word.begins_with(clean_seg):
			return true
	return false


func _search_recursively_case_insensitive(current_val: Variant, segments: Array[String], out_steps: Array) -> Dictionary:
	if current_val == null:
		return {"found": false, "value": null}
		
	if current_val is Object:
		for prop in current_val.get_property_list():
			if prop.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
				var prop_val = current_val.get(prop.name)
				if prop_val == null:
					continue
				
				# Try walking case-insensitively starting from this property
				var sub_steps = []
				var walk_res = _walk_segments_case_insensitive(prop_val, segments, sub_steps)
				if walk_res.found:
					out_steps.append([0, prop.name])
					out_steps.append_array(sub_steps)
					return walk_res
					
				# Recurse
				if prop_val is Object or prop_val is Dictionary or prop_val is Array:
					sub_steps = []
					var recurse_res = _search_recursively_case_insensitive(prop_val, segments, sub_steps)
					if recurse_res.found:
						out_steps.append([0, prop.name])
						out_steps.append_array(sub_steps)
						return recurse_res
						
	elif current_val is Dictionary:
		for key in current_val:
			var dict_val = current_val[key]
			if dict_val == null:
				continue
			
			# Try walking case-insensitively starting from this dictionary value
			var sub_steps = []
			var walk_res = _walk_segments_case_insensitive(dict_val, segments, sub_steps)
			if walk_res.found:
				out_steps.append([1, key, false])
				out_steps.append_array(sub_steps)
				return walk_res
				
			# Recurse
			if dict_val is Object or dict_val is Dictionary or dict_val is Array:
				sub_steps = []
				var recurse_res = _search_recursively_case_insensitive(dict_val, segments, sub_steps)
				if recurse_res.found:
					out_steps.append([1, key, false])
					out_steps.append_array(sub_steps)
					return recurse_res
					
	elif current_val is Array:
		for idx in range(current_val.size()):
			var item = current_val[idx]
			if item == null:
				continue
				
			# Try walking case-insensitively starting from this array item
			var sub_steps = []
			var walk_res = _walk_segments_case_insensitive(item, segments, sub_steps)
			if walk_res.found:
				var matched_identity = null
				if item is Object:
					for test_prop in ["id", "uid", "name", "key"]:
						if test_prop in item:
							matched_identity = item.get(test_prop)
							break
				elif item is Dictionary:
					for test_key in ["id", "uid", "name", "key"]:
						if item.has(test_key):
							matched_identity = item[test_key]
							break
							
				if matched_identity != null:
					out_steps.append([1, matched_identity, true])
				else:
					out_steps.append([1, idx, true])
					
				out_steps.append_array(sub_steps)
				return walk_res
				
			# Recurse
			if item is Object or item is Dictionary or item is Array:
				sub_steps = []
				var recurse_res = _search_recursively_case_insensitive(item, segments, sub_steps)
				if recurse_res.found:
					var matched_identity = null
					if item is Object:
						for test_prop in ["id", "uid", "name", "key"]:
							if test_prop in item:
								matched_identity = item.get(test_prop)
								break
					elif item is Dictionary:
						for test_key in ["id", "uid", "name", "key"]:
							if item.has(test_key):
								matched_identity = item[test_key]
								break
								
					if matched_identity != null:
						out_steps.append([1, matched_identity, true])
					else:
						out_steps.append([1, idx, true])
						
					out_steps.append_array(sub_steps)
					return recurse_res
					
	return {"found": false, "value": null}
#endregion
