class_name SceneManager
extends Node


var _current_scene_loaded: Node



func clear_current_map() -> void:
	var map_container = GameManager.main_scene.get_node_or_null("%MapContainer")
	var options_canvas = GameManager.main_scene.get_node_or_null("%OptionsCanvas")
	
	if map_container:
		map_container.repeat_size = Vector2.ZERO
		for map in map_container.get_children():
			if map is RPGMap:
				map.queue_free()
				
	if options_canvas:
		for child in options_canvas.get_children():
			child.queue_free()
			
	GameInterpreter.clear()


func set_map(map: RPGMap) -> void:
	if not map:
		return
	
	clear_current_map()
	GameManager.main_scene.current_map = map
	GameManager.current_map = map
	
	_add_map_to_container(map)
	_configure_map_scrolling(map)


func _add_map_to_container(map: RPGMap) -> void:
	var map_container = GameManager.main_scene.get_node_or_null("%MapContainer")
	if map_container:
		if map.is_inside_tree():
			map.reparent(map_container)
		else:
			map_container.add_child(map)


func clear_map_repeating() -> void:
	var map_container = GameManager.main_scene.get_node_or_null("%MapContainer")
	var shadows = GameManager.main_scene.get_node_or_null("%DynamicShadows")
	
	if map_container:
		map_container.repeat_times = 1
		map_container.repeat_size = Vector2.ZERO
		
	if shadows:
		shadows.clear_map_repeating()


func enable_map_repeating() -> void:
	var map_container = GameManager.main_scene.get_node_or_null("%MapContainer")
	var shadows = GameManager.main_scene.get_node_or_null("%DynamicShadows")
	
	if map_container:
		map_container.repeat_times = 4
		
	if shadows:
		shadows.enable_map_repeating()


func _configure_map_scrolling(map: RPGMap) -> void:
	var map_container = GameManager.main_scene.get_node_or_null("%MapContainer")
	if not map_container or map_container.repeat_times == 1: return
	
	var used_rect = map.get_used_rect(false)
	map_container.repeat_size = used_rect.size
	
	var viewport_size = get_viewport().size
	var max_repeats_x = max(2, ceil(used_rect.size.x / viewport_size.x))
	var max_repeats_y = max(2, ceil(used_rect.size.y / viewport_size.y))
	var max_repeats = max(max_repeats_x, max_repeats_y)
	
	map_container.repeat_times = max_repeats if (map.infinite_horizontal_scroll or map.infinite_vertical_scroll) else 1


func _destroy_gui_scenes() -> void:
	var canvas = GameManager.main_scene.get_node_or_null("%GUICanvas")
	if canvas:
		for child in canvas.get_children():
			child.queue_free()


func change_scene(path: String, destroy_gui: bool = false) -> void:
	var main_scene = GameManager.main_scene
	var interpreter = main_scene.get_node_or_null("%Interpreter")
	var transition_canvas = main_scene.get_node_or_null("%TransitionCanvas")
	var transition_manager = main_scene.transition_manager
	
	main_scene.busy = true
	if interpreter: interpreter.transfer_in_progress = true
	
	await _wait_frames(3)
	
	if transition_canvas: transition_canvas.layer = 128
	var transition_texture = _create_transition_texture()
	
	await _load_scene_async(path, transition_texture)
	
	if _current_scene_loaded and _current_scene_loaded is RPGMap:
		await _current_scene_loaded.map_started
		
	if GameManager.game_state:
		GameManager.game_state.erased_events.clear()
		
	if destroy_gui:
		_destroy_gui_scenes()
		
	main_scene.scene_changed.emit()
	
	if transition_manager: await transition_manager.end()
	if transition_canvas: transition_canvas.layer = 115
	if interpreter: interpreter.transfer_in_progress = false
	if transition_manager: transition_manager.visible = false


func _wait_frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame


func _create_transition_texture() -> ImageTexture:
	var img = get_viewport().get_texture().get_image()
	return ImageTexture.create_from_image(img)


func _load_scene_async(path: String, transition_texture: ImageTexture) -> void:
	if not AssetManager.exists(path):
		printerr("Invalid Path: ", path)
		return
	
	var transition_manager = GameManager.main_scene.transition_manager
	ResourceLoader.load_threaded_request(path)
	
	if transition_manager: await transition_manager.start(transition_texture)
	
	var res = await _wait_for_resource_load(path)
	if res:
		_instantiate_and_setup_scene(res, path)
	else:
		_current_scene_loaded = null


func _wait_for_resource_load(path: String) -> Resource:
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
	if not res is PackedScene:
		printerr("The current path is not a scene: ", path)
		_current_scene_loaded = null
		return
	
	var next_scene = res.instantiate()
	_current_scene_loaded = next_scene
	_setup_scene_based_on_type(next_scene)
	GameManager.main_scene.current_scene = next_scene


func _setup_scene_based_on_type(next_scene: Node) -> void:
	if next_scene is SCENE_TITTLE or next_scene is SCENE_END:
		_setup_gui_scene(next_scene)
	elif next_scene is RPGMap:
		_setup_map_scene(next_scene)


func _setup_gui_scene(scene: Node) -> void:
	var canvas = GameManager.main_scene.get_node_or_null("%GUICanvas")
	if canvas:
		for child in canvas.get_children():
			child.queue_free()
		canvas.add_child(scene)


func _setup_map_scene(map_scene: RPGMap) -> void:
	var main_scene = GameManager.main_scene
	if main_scene.current_scene is SCENE_TITTLE:
		main_scene.current_scene.queue_free()
	
	var canvas = main_scene.get_node_or_null("%MapContainer")
	var shadows = main_scene.get_node_or_null("%ShadowContainer")
	
	if canvas:
		for child in canvas.get_children():
			if child != shadows:
				child.queue_free()
	
	set_map(map_scene)
