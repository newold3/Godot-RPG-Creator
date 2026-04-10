class_name SceneManager
extends Node


var _current_scene_loaded: Node



## Clears the current map and its components
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


## Sets the new active map
func set_map(map: RPGMap) -> void:
	if not map:
		return
	
	clear_current_map()
	GameManager.main_scene.current_map = map
	GameManager.current_map = map
	
	_add_map_to_container(map)
	_configure_map_scrolling(map)


## Adds the map node to the container hierarchy
func _add_map_to_container(map: RPGMap) -> void:
	var map_container = GameManager.main_scene.get_node_or_null("%MapContainer")
	if map_container:
		if map.is_inside_tree():
			map.reparent(map_container)
		else:
			map_container.add_child(map)


## Disables map repeating visuals
func clear_map_repeating() -> void:
	var map_container = GameManager.main_scene.get_node_or_null("%MapContainer")
	var shadows = GameManager.main_scene.get_node_or_null("%DynamicShadows")
	
	if map_container:
		map_container.repeat_times = 1
		map_container.repeat_size = Vector2.ZERO
		
	if shadows:
		shadows.clear_map_repeating()


## Enables map repeating visually
func enable_map_repeating() -> void:
	var map_container = GameManager.main_scene.get_node_or_null("%MapContainer")
	var shadows = GameManager.main_scene.get_node_or_null("%DynamicShadows")
	
	var repeat_times = get_map_repeat_times()
	if map_container:
		map_container.repeat_times = repeat_times
		
	if shadows:
		shadows.enable_map_repeating(repeat_times)


## Calculates how many times the map needs to repeat to fill the screen
func get_map_repeat_times() -> int:
	var map = GameManager.current_map
	if map:
		var viewport_size = map.get_viewport_rect().size / GameManager.get_camera_zoom()
		var map_pixel_size = Vector2(map.get_map_size_in_tiles() * map.tile_size)
		var repeat_x = ceil(viewport_size.x / map_pixel_size.x) + 1
		var repeat_y = ceil(viewport_size.y / map_pixel_size.y) + 1
		var optimal_repeat = max(repeat_x, repeat_y)
		optimal_repeat = clamp(optimal_repeat, 2, 8)
		
		return optimal_repeat
	
	return 2


## Adjusts repeating rules depending on map scroll flags
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


## Removes all generic GUI nodes from the canvas
func _destroy_gui_scenes() -> void:
	var canvas = GameManager.main_scene.get_node_or_null("%GUICanvas")
	if canvas:
		for child in canvas.get_children():
			child.queue_free()


## Changes to the specified scene path handling graphical transitions
func change_scene(path: String, destroy_gui: bool = false, is_instant: bool = false) -> void:
	var main_scene = GameManager.main_scene
	var interpreter = main_scene.get_node_or_null("%Interpreter")
	var transition_canvas = main_scene.get_node_or_null("%TransitionCanvas")
	var transition_manager = main_scene.transition_manager
	
	main_scene.busy = true
	if interpreter: interpreter.transfer_in_progress = true
	
	var transition_texture: ImageTexture = null
	
	if not is_instant:
		await _wait_frames(3)
		if transition_canvas: transition_canvas.layer = 128
		transition_texture = _create_transition_texture()
	
	await _load_scene_async(path, transition_texture, is_instant)
	
	if _current_scene_loaded and _current_scene_loaded is RPGMap:
		await _current_scene_loaded.map_started
		main_scene.get_main_camera().fast_reposition.call_deferred()
		
	if GameManager.game_state:
		GameManager.game_state.erased_events.clear()
		
	if destroy_gui:
		_destroy_gui_scenes()
		
	main_scene.scene_changed.emit()
	
	if transition_manager and not is_instant:
		await transition_manager.end()
		
	if transition_canvas: transition_canvas.layer = 115
	if interpreter: interpreter.transfer_in_progress = false
	if transition_manager: transition_manager.visible = false


## Pauses execution for a set amount of process frames
func _wait_frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame


## Generates a texture from the current viewport state
func _create_transition_texture() -> ImageTexture:
	var img = get_viewport().get_texture().get_image()
	return ImageTexture.create_from_image(img)


## Handles threaded resource loading and transition start
func _load_scene_async(path: String, transition_texture: ImageTexture, is_instant: bool = false) -> void:
	if not AssetManager.exists(path):
		printerr("Invalid Path: ", path)
		return
	
	var transition_manager = GameManager.main_scene.transition_manager
	ResourceLoader.load_threaded_request(path)
	
	if transition_manager and not is_instant:
		await transition_manager.start(transition_texture)
	
	var res = await _wait_for_resource_load(path)
	if res:
		_instantiate_and_setup_scene(res, path)
	else:
		_current_scene_loaded = null


## Polls the threaded load request until completion
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


## Creates the node and determines correct setup
func _instantiate_and_setup_scene(res: Resource, path: String) -> void:
	if not res is PackedScene:
		printerr("The current path is not a scene: ", path)
		_current_scene_loaded = null
		return
	
	var next_scene = res.instantiate()
	_current_scene_loaded = next_scene
	_setup_scene_based_on_type(next_scene)
	GameManager.main_scene.current_scene = next_scene


## Routes scene setup logic depending on inheritance
func _setup_scene_based_on_type(next_scene: Node) -> void:
	if next_scene is SCENE_TITTLE or next_scene is SCENE_END:
		_setup_gui_scene(next_scene)
	elif next_scene is RPGMap:
		_setup_map_scene(next_scene)


## Prepares Title or End scenes
func _setup_gui_scene(scene: Node) -> void:
	var canvas = GameManager.main_scene.get_node_or_null("%GUICanvas")
	if canvas:
		for child in canvas.get_children():
			child.queue_free()
		canvas.add_child(scene)


## Cleans up previous maps and inserts the new one
func _setup_map_scene(map_scene: RPGMap) -> void:
	var main_scene = GameManager.main_scene
	if main_scene.current_scene is SCENE_TITTLE:
		main_scene.current_scene.queue_free()
	
	var canvas = main_scene.get_node_or_null("%MapContainer")
	
	if canvas:
		for child in canvas.get_children():
			if child is RPGMap:
				child.queue_free()
	
	set_map(map_scene)
