@tool
extends Node

var map_infos: Node
var system: System

var active_editor_database: RPGDATA

var database: RPGDATA: get = _get_database

var player_animations_data: Dictionary
var weapon_animations_data: Dictionary

var is_playing: bool = false

const VALID_DATABASE_KEYS: Array = ["actors", "classes", "professions", "skills", "items", "weapons", "armors", "costumes", "enemies", "troops", "states", "animations", "common_events", "speakers", "quests"]

static var editor_interface


func _ready() -> void:
	load_data()
	load_variables_and_switches()
	load_animations()
	load_map_infos()
	set_deferred("is_loaded", true)


func _get_database() -> RPGDATA:
	if is_instance_valid(active_editor_database):
		return active_editor_database

	return database


func load_data() -> void:
	database = DatabaseLoader.load_database()
	
	if database == null:
		print("No Database found. Initializing new RPGDATA.")
		database = RPGDATA.new()
		if database.has_method("initialize"):
			database.initialize()
	
	if not DatabaseLoader.is_develop_build:
		_inject_extra_data()


func _inject_extra_data() -> void:
	if not database: return
	database.migrate_to_version(DatabaseLoader.get_master_version())
	
	
	#var database_path = DatabaseLoader.get_database_path()
	#if ResourceLoader.exists(database_path):
		#database = ResourceLoader.load(database_path, "", ResourceLoader.CACHE_MODE_REPLACE)
		##database.system.game_fxs.insert(6, {"path": "", "pitch": 1.0, "pitch2": 1.0, "volume": 0.0})
		## TO ERASE
		## ==========================================================================================
		##database.system.game_fxs.append({"path": "res://Assets/Sounds/SE/switch_hero_panels.ogg", "pitch": 1.0, "pitch2": 1.0, "volume": 0.0})
		#
		#database.terms.messages.clear()
		#var default_terms = []
		#var f = FileAccess.open("res://addons/RPGData/default_terms_list.txt", FileAccess.READ)
		#default_terms = f.get_as_text().split("\n")
		#f.close()
		#
		#for i: int in default_terms.size():
			#var term: String = default_terms[i]
			#var id := ""
			#var message := ""
			#if "," in term:
				#id = term.get_slice(",", 0).strip_edges()
				#message = term.get_slice(",", 1).strip_edges()
			#else:
				#id = term.strip_edges()
				#message = ""
#
			#if not id.is_empty() and not database.terms.messages.any(func(t: RPGTerm): t.id == id):
				#var new_term = RPGTerm.new(id, message, message == "")
				#if database.terms.messages.size() > i:
					#database.terms.messages.insert(i, new_term)
				#else:
					#database.terms.messages.append(new_term)
		#
		##database.system.player_start_position = RPGMapPosition.new()
		##database.system.air_transport_start_position = RPGMapPosition.new()
		##database.system.sea_transport_start_position = RPGMapPosition.new()
		##database.system.land_transport_start_position = RPGMapPosition.new()
		##database.quests = [null, RPGQuest.new()]
		##var p = RPGProfession.new()
		##p.name = tr("Collector")
		##database.professions = [null, p]
		#database.system.game_scenes = {}
		#var list = [
			#"Scene Title", "Scene Load Game", "Scene Options", "Scene Credits",
			#"Scene Main Menu", "Scene Equipment"
		#]
		#var paths = [
			#"res://Scenes/GUI/SteamPunkTheme/Title/scene_title.tscn",
			#"res://Scenes/GUI/SteamPunkTheme/SaveLoad/main_scene.tscn",
			#"res://Scenes/GUI/SteamPunkTheme/Options/main_scene.tscn",
			#"res://Scenes/GUI/SteamPunkTheme/Credits/main_scene.tscn",
			#"res://Scenes/GUI/SteamPunkTheme/MainMenu/main_scene.tscn",
			#"res://Scenes/GUI/SteamPunkTheme/Equip/main_scene.tscn"
			#
		#]
		#for i in list.size():
			#database.system.game_scenes[list[i]] = paths[i]
		## ==========================================================================================
	#else:
		#database = RPGDATA.new()
		#database.initialize()


func generate_16_digit_id() -> int:
	var id = str(randi_range(1, 9))
	var characters = "0123456789"
	for i in range(15):
		var random_index = randi() % 10
		id += characters.substr(random_index, 1)
		
	return int(id)


func get_data(key: Variant, id: int) -> Variant:
	if id < 0:
		return null
		
	if key is String and not key in VALID_DATABASE_KEYS:
		return null
		
	var data: Array = database[key] if key is String else key
	
	if not data: 
		return null
		
	if id >= 1_000_000_000_000_000:
		for d: Variant in data:
			if d and d.get("_uniq_id") == id:
				return d
		return null
	
	if id > 0 and data.size() > id and data[id] and data[id].id == id:
		return data[id]
		
	for d: Variant in data:
		if d and d.id == id:
			return d
			
	return null


func get_type_data(_type: String, id: int) -> Dictionary:
	var obj = {"name": "", "color": Color.WHITE, "icon": null}
	
	if not database or not database.types:
		return obj
		
	var types: RPGTypes = database.types
	var type_icons: RPGTypeIcons = types.icons
	
	var type_key = _type.to_lower()
	
	match type_key:
		"enemy", "enemies", "enemy_rarity":
			if id >= 0 and id < types.enemy_rarity_types.size():
				obj.name = types.enemy_rarity_types[id]
			if id >= 0 and id < types.enemy_rarity_color_types.size():
				obj.color = types.enemy_rarity_color_types[id]
			if type_icons and id >= 0 and id < type_icons.enemy_rarity_icons.size():
				var icon_res = type_icons.enemy_rarity_icons[id]
				if icon_res:
					obj.icon = icon_res.get_texture()
					
		"item", "items":
			if id >= 0 and id < types.item_types.size():
				obj.name = types.item_types[id]
			if type_icons and id >= 0 and id < type_icons.item_icons.size():
				var icon_res = type_icons.item_icons[id]
				if icon_res:
					obj.icon = icon_res.get_texture()
					
		"item_rarity":
			if id >= 0 and id < types.item_rarity_types.size():
				obj.name = types.item_rarity_types[id]
			if id >= 0 and id < types.item_rarity_color_types.size():
				obj.color = types.item_rarity_color_types[id]
			
		"weapon", "weapons":
			if id >= 0 and id < types.weapon_types.size():
				obj.name = types.weapon_types[id]
			if type_icons and id >= 0 and id < type_icons.weapon_icons.size():
				var icon_res = type_icons.weapon_icons[id]
				if icon_res:
					obj.icon = icon_res.get_texture()
					
		"weapon_rarity":
			if id >= 0 and id < types.weapon_rarity_types.size():
				obj.name = types.weapon_rarity_types[id]
			if id >= 0 and id < types.weapon_rarity_color_types.size():
				obj.color = types.weapon_rarity_color_types[id]
				
		"armor", "armors":
			if id >= 0 and id < types.armor_types.size():
				obj.name = types.armor_types[id]
			if type_icons and id >= 0 and id < type_icons.armor_icons.size():
				var icon_res = type_icons.armor_icons[id]
				if icon_res:
					obj.icon = icon_res.get_texture()
					
		"armor_rarity":
			if id >= 0 and id < types.armor_rarity_types.size():
				obj.name = types.armor_rarity_types[id]
			if id >= 0 and id < types.armor_rarity_color_types.size():
				obj.color = types.armor_rarity_color_types[id]
				
		"element", "elements":
			if id >= 0 and id < types.element_types.size():
				obj.name = types.element_types[id]
			if id >= 0 and id < types.element_colors.size():
				obj.color = types.element_colors[id]
			if type_icons and id >= 0 and id < type_icons.element_icons.size():
				var icon_res = type_icons.element_icons[id]
				if icon_res:
					obj.icon = icon_res.get_texture()
					
		"skill", "skills":
			if id >= 0 and id < types.skill_types.size():
				obj.name = types.skill_types[id]
			if type_icons and id >= 0 and id < type_icons.skill_icons.size():
				var icon_res = type_icons.skill_icons[id]
				if icon_res:
					obj.icon = icon_res.get_texture()
					
		"tool", "tools":
			if id >= 0 and id < types.tool_types.size():
				obj.name = types.tool_types[id]
			if type_icons and id >= 0 and id < type_icons.tool_icons.size():
				var icon_res = type_icons.tool_icons[id]
				if icon_res:
					obj.icon = icon_res.get_texture()
					
		"equipment", "equipments":
			if id >= 0 and id < types.equipment_types.size():
				obj.name = types.equipment_types[id]
			if type_icons and id >= 0 and id < type_icons.equipment_icons.size():
				var icon_res = type_icons.equipment_icons[id]
				if icon_res:
					obj.icon = icon_res.get_texture()
					
		"main_parameter", "main_parameters":
			if id >= 0 and id < types.main_parameters.size():
				obj.name = types.main_parameters[id]
			if type_icons and id >= 0 and id < type_icons.main_parameters_icons.size():
				var icon_res = type_icons.main_parameters_icons[id]
				if icon_res:
					obj.icon = icon_res.get_texture()
					
		"user_parameter", "user_parameters":
			if id >= 0 and id < types.user_parameters.size():
				var param = types.user_parameters[id]
				if param:
					obj.name = param.name
			if type_icons and id >= 0 and id < type_icons.user_parameters_icons.size():
				var icon_res = type_icons.user_parameters_icons[id]
				if icon_res:
					obj.icon = icon_res.get_texture()

	return obj


func id_to_uid(key: Variant, id: int) -> int:
	if id < 0:
		return -1
		
	if id >= 1_000_000_000_000_000:
		return id
		
	if key is String and not key in VALID_DATABASE_KEYS:
		return -1
		
	var data: Array = database[key] if key is String else key
	
	if not data: 
		return -1
	
	if id > 0 and data.size() > id and data[id] and data[id].id == id:
		return data[id]._uniq_id
	
	for d: Variant in data:
		if d and d.id == id:
			return d.get("_uniq_id", -1)
		
	return -1



func uid_to_id(key: Variant, id: int) -> int:
	if id < 0:
		return -1
		
	if id < 1_000_000_000_000_000:
		return id
		
	if key is String and not key in VALID_DATABASE_KEYS:
		return -1
		
	var data: Array = database[key] if key is String else key
	
	if not data: 
		return -1
	
	for i: int in data.size():
		var d: Variant = data[i]
		
		if d and d.get("_uniq_id") == id:
			return i
			
	return -1


func load_variables_and_switches() -> void:
	system = DatabaseLoader.load_system()
	
	if system == null:
		print("No System found. Initializing new System.")
		system = System.new()
		if system.has_method("build"):
			system.build()


func load_animations() -> void:
	var data_folder = "res://addons/rpg_character_creator/Data/"
	player_animations_data = load_animation_data(data_folder, "character.lcc")
	weapon_animations_data = load_animation_data(data_folder, "weapon.lcc")


func load_animation_data(data_folder: String, file_name: String) -> Dictionary:
	var path = data_folder.path_join(file_name)
	var animation_data: Dictionary = {}
	
	var json = ZipMediaLoader.get_text_content(path)
	
	if not json.is_empty():
		var parse_result = JSON.parse_string(json)
		if parse_result:
			animation_data = parse_result
		else:
			printerr("❌ Error parsing JSON from file: %s" % path)
	else:
		# This will only happen if the file is missing in both Disk and ZIP
		printerr("⚠️ Failed to find or read animation file: %s" % path)
		
	return animation_data


func load_map_infos() -> void:
	map_infos = RPGMapsInfo


func save(save_system: bool = true, save_database: bool = true) -> void:
	if save_system:
		DatabaseLoader.save_system()
	if save_database:
		DatabaseLoader.save_database()


func debug_fill_stats_randomly() -> void:
	if not is_instance_valid(GameManager) or not GameManager.game_state:
		printerr("debug_fill_stats_randomly: GameManager or game_state is not valid.")
		return
		
	var stats: GameStatistics = GameManager.game_state.stats
	if not stats:
		stats = GameStatistics.new()
		GameManager.game_state.stats = stats
		
	# 1. Simple numeric fields
	stats.steps = randi_range(100, 100000)
	stats.play_time = randf_range(60.0, 36000.0)
	stats.save_count = randi_range(1, 50)
	stats.game_progress = randf_range(0.0, 1.0)
	stats.total_money_earned = randi_range(500, 1000000)
	stats.total_money_spent = randi_range(100, stats.total_money_earned)
	stats.player_deaths = randi_range(0, 30)
	stats.chests_opened = randi_range(0, 150)
	stats.secrets_found = randi_range(0, 20)
	stats.max_level_reached = randi_range(1, 99)
	stats.dialogues_completed = randi_range(5, 500)
	stats.rare_items_found = randi_range(0, 10)
	
	# 2. Dictionaries mapping unique IDs to random counts
	stats.enemy_kills = {}
	stats.skills = {}
	stats.items_sold = {}
	stats.items_purchased = {}
	stats.items_found = {}
	stats.map_visited = {}
	stats.interactive_events_found = {}
	stats.achievements = {}
	stats.relationships = {}
	stats.user_stats = {}
	
	if database:
		# Random enemy kills
		for enemy in database.enemies:
			if enemy and enemy.id > 0:
				var uid = enemy._uniq_id
				if uid > 0 and randf() > 0.3:
					stats.enemy_kills[uid] = randi_range(1, 99)
					
		# Random skills used
		for skill in database.skills:
			if skill and skill.id > 0:
				var uid = skill._uniq_id
				if uid > 0 and randf() > 0.4:
					stats.skills[uid] = randi_range(1, 150)
					
		# Random items found/sold/purchased
		# item types: 0 (item), 1 (weapon), 2 (armor)
		for item in database.items:
			if item and item.id > 0:
				var uid = item._uniq_id
				if uid > 0:
					var key = "0_%s" % uid
					if randf() > 0.5: stats.items_found[key] = randi_range(1, 20)
					if randf() > 0.7: stats.items_sold[key] = randi_range(1, 10)
					if randf() > 0.6: stats.items_purchased[key] = randi_range(1, 15)
					
		for weapon in database.weapons:
			if weapon and weapon.id > 0:
				var uid = weapon._uniq_id
				if uid > 0:
					var key = "1_%s" % uid
					if randf() > 0.6: stats.items_found[key] = randi_range(1, 5)
					if randf() > 0.8: stats.items_sold[key] = randi_range(1, 3)
					if randf() > 0.7: stats.items_purchased[key] = randi_range(1, 5)
					
		for armor in database.armors:
			if armor and armor.id > 0:
				var uid = armor._uniq_id
				if uid > 0:
					var key = "2_%s" % uid
					if randf() > 0.6: stats.items_found[key] = randi_range(1, 5)
					if randf() > 0.8: stats.items_sold[key] = randi_range(1, 3)
					if randf() > 0.7: stats.items_purchased[key] = randi_range(1, 5)
					
		# Custom user stats
		if database.types and database.types.user_stats:
			for custom_stat in database.types.user_stats:
				if not custom_stat.is_empty():
					stats.user_stats[custom_stat] = randi_range(1, 500)
					
	# 3. Sub-resources (Battles, Extractions, Missions)
	if not stats.battles:
		stats.battles = GameBattleStats.new()
	stats.battles.won = randi_range(5, 200)
	stats.battles.lost = randi_range(0, 50)
	stats.battles.drawn = randi_range(0, 10)
	stats.battles.escaped = randi_range(0, 30)
	stats.battles.total_played = stats.battles.won + stats.battles.lost + stats.battles.drawn + stats.battles.escaped
	stats.battles.current_win_streak = randi_range(0, 10)
	stats.battles.longest_win_streak = randi_range(stats.battles.current_win_streak, stats.battles.current_win_streak + 15)
	stats.battles.current_lose_streak = randi_range(0, 5)
	stats.battles.longest_lose_streak = randi_range(stats.battles.current_lose_streak, stats.battles.current_lose_streak + 8)
	stats.battles.longest_battle_time = randf_range(120.0, 900.0)
	stats.battles.shortest_battle_time = randf_range(5.0, 60.0)
	stats.battles.total_combat_turns = randi_range(50, 2000)
	stats.battles.total_time_in_battle = randf_range(300.0, 18000.0)
	stats.battles.total_experience_earned = randi_range(1000, 500000)
	stats.battles.total_damage_received = randi_range(2000, 1000000)
	stats.battles.total_damage_done = randi_range(5000, 2000000)
	stats.battles.total_used_skills = randi_range(10, 1500)
	stats.battles.total_critiques_performed = randi_range(5, 300)
	
	if not stats.extractions:
		stats.extractions = GameExtractionStats.new()
	stats.extractions.total_success = randi_range(0, 100)
	stats.extractions.total_failure = randi_range(0, 50)
	stats.extractions.total_finished = stats.extractions.total_success + stats.extractions.total_failure
	stats.extractions.total_unfinished = randi_range(0, 20)
	stats.extractions.critical_performs = randi_range(0, stats.extractions.total_success)
	stats.extractions.super_critical_performs = randi_range(0, stats.extractions.critical_performs)
	
	if not stats.missions:
		stats.missions = GameMissionStats.new()
	stats.missions.completed = randi_range(0, 30)
	stats.missions.in_progress = randi_range(0, 10)
	stats.missions.failed = randi_range(0, 5)
	stats.missions.total_found = stats.missions.completed + stats.missions.in_progress + stats.missions.failed
	
	# Fill random missions from database
	stats.missions.missions.clear()
	stats.missions.historical_dictionary.clear()
	if database and database.quests:
		for quest in database.quests:
			if quest and quest.id > 0:
				var uid = quest._uniq_id
				if uid > 0 and randf() > 0.4:
					var result = GameQuestResult.new()
					result.id = quest.id
					result.owner_map_uniq_id = generate_16_digit_id()
					result.owner_event_uniq_id = generate_16_digit_id()
					result.status = randi() % 3
					result.count = randi_range(1, 3)
					result.quest_completed_at = Time.get_unix_time_from_system() - randf_range(0.0, 604800.0)
					stats.missions.missions.append(result)
					stats.missions.historical_dictionary[quest.id] = result.status

	# Random achievements
	for i in range(1, 4):
		var ach = GameAchievement.new()
		ach.id = i
		ach.name = "Achievement %d" % i
		ach.description = "Randomly generated achievement %d" % i
		if randf() > 0.5:
			ach.state = GameAchievement.STATE.COMPLETE
			ach.progress = 1.0
			ach.first_time_achieved = Time.get_unix_time_from_system() - randf_range(0.0, 86400.0)
		else:
			ach.state = GameAchievement.STATE.UNFINISHED
			ach.progress = randf_range(0.0, 0.99)
		stats.achievements[i] = ach

	# Random relationships
	for i in range(1, 3):
		var rel = GameRelationship.new()
		rel.map_id = randi_range(1, 5)
		rel.character_id = i
		rel.max_level = 5
		rel.level_names = PackedStringArray(["Stranger", "Acquaintance", "Friend", "Close Friend", "Best Friend"])
		rel.current_level = randi_range(0, 4)
		rel.exp_next_level = randf_range(0.0, 100.0)
		var key = "%d_%d" % [rel.map_id, rel.character_id]
		stats.relationships[key] = rel
	
	# Visited maps
	for i in range(1, randi_range(3, 10)):
		stats.map_visited[i] = true
		
	print("Game statistics filled randomly for debug.")


func _exit_tree() -> void:
	save()
