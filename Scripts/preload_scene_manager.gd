extends Node

signal preloading_finished

var scenes_load_status: Dictionary = {}
var preload_thread: Thread = null
var scenes_to_preload: Array[String] = []
var viewport: SubViewport

func _ready() -> void:
	if not Engine.is_editor_hint():
		viewport = SubViewport.new()
		add_child(viewport)
		if not is_in_group("preloader"):
			add_to_group("preloader")
		preloading_finished.connect(_cleanup_thread, ConnectFlags.CONNECT_DEFERRED)


func start(scenes: Array[String]) -> void:
	scenes_to_preload = scenes
	for scene_path in scenes_to_preload:
		scenes_load_status[scene_path] = false
	_start_preloading_thread()


func _start_preloading_thread() -> void:
	preload_thread = Thread.new()
	preload_thread.start(_preload_scenes_thread)


func _preload_scenes_thread() -> void:
	for scene_path in scenes_to_preload:
		if not ResourceLoader.exists(scene_path):
			scenes_load_status.erase(scene_path)
			continue
		ResourceLoader.load_threaded_request(scene_path)
		
		var status = ResourceLoader.THREAD_LOAD_IN_PROGRESS
		while status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			status = ResourceLoader.load_threaded_get_status(scene_path)
			OS.delay_msec(1)
		
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			call_deferred("_add_and_remove_instance", scene_path)
	
	preloading_finished.emit()


func _add_and_remove_instance(scene_path: String) -> void:
	var instance = ResourceLoader.load(scene_path).instantiate()
	viewport.add_child(instance)
	await get_tree().process_frame
	instance.queue_free()
	scenes_load_status[scene_path] = true


func _update_load_status(scene_path: String, loaded: bool) -> void:
	scenes_load_status[scene_path] = loaded


func _cleanup_thread() -> void:
	if preload_thread and preload_thread.is_alive():
		preload_thread.wait_to_finish()
	preload_thread = null


func get_scene(scene_path: String) -> Node:
	if scene_path in scenes_load_status:
		while not scenes_load_status[scene_path]:
			await get_tree().process_frame
		return ResourceLoader.load(scene_path).instantiate()
	elif ResourceLoader.exists(scene_path):
		return ResourceLoader.load(scene_path).instantiate()
	
	printerr("Error: %s no exists!" % scene_path)
	return null
