class_name DynamicAssetManager
extends Node


var current_ingame_images: Dictionary[int, GameImage] = {}
var current_ingame_scenes: Dictionary[int, Node] = {}

var scene_cache: Dictionary = {
	"messages": {},
	"shops": {},
	"main_menus": {},
	"items": {},
	"skills": {},
	"equipment": {},
	"status": {},
	"formation": {},
	"quests": {},
	"save_loads": {},
	"options": {},
	"game_ends": {},
}


func create_image(type: int, index: int, image_path: String) -> GameImage:
	if AssetManager.exists(image_path):
		var target: Node = GameManager.current_map if type == 0 else null if not GameManager.main_scene else GameManager.main_scene.get_image_container()
		if target:
			var img = GameImage.new(index, image_path)
			target.add_child(img)
			if index in current_ingame_images:
				current_ingame_images[index].queue_free()
			current_ingame_images[index] = img
			return img
	
	return null


func get_image(index: int) -> GameImage:
	return current_ingame_images.get(index, null)


func remove_image(index: int) -> void:
	if index in current_ingame_images:
		if is_instance_valid(current_ingame_images[index]):
			current_ingame_images[index].end()
		current_ingame_images.erase(index)


func create_scene(index: int, scene_path: String, is_map_scene: bool = false) -> Node:
	if AssetManager.exists(scene_path) and GameManager.main_scene:
		var target: Node
		if GameManager.current_map and is_map_scene:
			target = GameManager.current_map
		else:
			target = GameManager.main_scene.get_scene_container()
			
		if target:
			if index in current_ingame_scenes:
				current_ingame_scenes[index].queue_free()
				current_ingame_scenes.erase(index)
				await get_tree().process_frame
			await get_tree().process_frame
			var scn = load(scene_path).instantiate()
			target.add_child(scn)
			current_ingame_scenes[index] = scn
			return scn
	
	return null


func get_scene(index: int) -> Node:
	return current_ingame_scenes.get(index, null)


func remove_scene(index: int) -> void:
	if index in current_ingame_scenes:
		if is_instance_valid(current_ingame_scenes[index]):
			current_ingame_scenes[index].queue_free()
		current_ingame_scenes.erase(index)


func get_scene_from_cache(cache_path: String, scene_path: String, type_required: String = "", cache_instance: bool = false) -> Node:
	var ins
	var current_cache_files
	
	if cache_path.is_empty():
		if not "other_scenes" in scene_cache:
			scene_cache["other_scenes"] = {}
		current_cache_files = scene_cache["other_scenes"]
	else:
		if not cache_path in scene_cache:
			scene_cache[cache_path] = {}
		current_cache_files = scene_cache[cache_path]

	if AssetManager.exists(scene_path):
		if scene_path in current_cache_files:
			if is_instance_valid(current_cache_files[scene_path]):
				if current_cache_files[scene_path] is PackedScene:
					ins = current_cache_files[scene_path].instantiate()
				else:
					ins = current_cache_files[scene_path]
			elif AssetManager.exists(scene_path):
				var scn = ResourceLoader.load(scene_path)
				ins = scn.instantiate()
			
		else:
			var scn
			if scene_path in RPGSYSTEM.database.system.preload_scenes:
				while ResourceLoader.load_threaded_get_status(scene_path) != ResourceLoader.THREAD_LOAD_LOADED:
					if is_inside_tree():
						await get_tree().process_frame
					break
				if ResourceLoader.load_threaded_get_status(scene_path) == ResourceLoader.THREAD_LOAD_LOADED:
					scn = ResourceLoader.load_threaded_get(scene_path)
						
			if not scn:
				scn = load(scene_path)
			ins = scn.instantiate()
			if type_required.is_empty() or ins.get_class() == type_required:
				if not cache_instance:
					current_cache_files[scene_path] = scn
				else:
					current_cache_files[scene_path] = ins
			else:
				ins.queue_free()
				ins = null
	
	return ins
