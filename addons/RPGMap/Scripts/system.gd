@tool
extends Node

var map_infos: RPGMapsInfo
var system: System
var database: RPGDATA
var player_animations_data: Dictionary
var weapon_animations_data: Dictionary

var is_playing: bool = false

static var editor_interface


func _ready() -> void:
	load_data()
	load_variables_and_switches()
	load_animations()
	load_map_infos()


func load_data() -> void:
	database = DatabaseLoader.load_database()
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


func load_variables_and_switches() -> void:
	system = DatabaseLoader.load_system()
	#DatabaseLoader.setup()
	#var dir = DatabaseLoader.get_data_folder_path()
	#var file = "system.res"
	#var path = "%s/%s" % [dir, file]
	#if ResourceLoader.exists(path):
		#system = ResourceLoader.load(path)
	#else:
		#DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
		#system = System.new()
		#system.build()
		#ResourceSaver.save(system, path, ResourceSaver.FLAG_COMPRESS)


func load_animations() -> void:
	var data_folder = "res://addons/rpg_character_creator/Data/"
	player_animations_data = load_animation_data(data_folder, "character.anim")
	weapon_animations_data = load_animation_data(data_folder, "weapon.anim")


func load_animation_data(data_folder: String, file: String) -> Dictionary:
	var path = data_folder.path_join(file)
	var animation_data: Dictionary = {}
	var f = FileAccess.open(path, FileAccess.READ)
	if f:
		var json = f.get_as_text()
		var parse_result = JSON.parse_string(json)
		if parse_result:
			animation_data = parse_result
		else:
			printerr("Error parsing JSON from file: %s" % path)
		f.close()
	else:
		printerr("Failed to open file: %s" % path)
	return animation_data


func load_map_infos() -> void:
	map_infos = RPGMapsInfo


func save(save_system: bool = true, save_database: bool = true) -> void:
	if save_system:
		DatabaseLoader.save_system()
	if save_database:
		DatabaseLoader.save_database()
	#var data_folder_path = DatabaseLoader.get_data_folder_path()
	#var absolute_data_folder_path = ProjectSettings.globalize_path(data_folder_path)
	#if !DirAccess.dir_exists_absolute(absolute_data_folder_path):
		#DirAccess.make_dir_recursive_absolute(absolute_data_folder_path)
	## Save system
	#if save_system:
		#var file = "system.res"
		#var system_path = data_folder_path.path_join(file)
		#ResourceSaver.save(system, system_path, ResourceSaver.FLAG_COMPRESS)
	## Save data
	#if save_database:
		#var file = "database.res"
		#var database_path = data_folder_path.path_join(file)
		#database.take_over_path(database_path)
		#ResourceSaver.save(database, database_path, ResourceSaver.FLAG_COMPRESS)
		#DirAccess.remove_absolute(MainDatabasePanel.BACKUP_PATH)


func _exit_tree() -> void:
	save()
