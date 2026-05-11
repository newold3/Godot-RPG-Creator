@tool
class_name MapSceneExporter
extends RefCounted

#region VARIABLES
var _generator: Node
#endregion


## Initializes the exporter with a reference to the main generator
func _init(generator: Node) -> void:
	_generator = generator


## Opens a file dialog to select the destination for the exported RPGMap
func export_to_rpgmap() -> void:
	if not Engine.is_editor_hint():
		return
	var dir: DirAccess = DirAccess.open("res://")
	if not dir.dir_exists("Scenes/Maps"):
		dir.make_dir_recursive("Scenes/Maps")
	var dialog: EditorFileDialog = EditorFileDialog.new()
	dialog.file_mode = EditorFileDialog.FILE_MODE_SAVE_FILE
	dialog.access = EditorFileDialog.ACCESS_RESOURCES
	dialog.current_dir = "res://Scenes/Maps/"
	dialog.clear_filters()
	dialog.add_filter("*.tscn", "Godot Scene")
	dialog.title = "Save RPGMap Scene"
	dialog.file_selected.connect(_on_export_file_selected.bind(dialog))
	dialog.close_requested.connect(dialog.queue_free)
	EditorInterface.get_base_control().add_child(dialog)
	dialog.popup_centered_ratio(0.5)


## Generates the internal ID and checks for file conflicts before proceeding
func _on_export_file_selected(path: String, dialog: EditorFileDialog) -> void:
	dialog.queue_free()
	var base_dir: String = path.get_base_dir()
	var raw_name: String = path.get_file().get_basename()
	var snake_name: String = raw_name.to_snake_case()
	var display_name: String = raw_name.capitalize()
	var map_id_int: int = RPGSYSTEM.generate_16_digit_id()
	var final_scene_path: String = base_dir + "/" + snake_name + ".tscn"
	var events_path: String = "res://data/MapEvents/Map_" + str(map_id_int) + "_events.tres"
	var conflicts: Array[String] = []
	if FileAccess.file_exists(final_scene_path):
		conflicts.append("Scene: " + snake_name + ".tscn")
	if FileAccess.file_exists(events_path):
		conflicts.append("Events: Map_" + str(map_id_int) + "_events.tres")
	if conflicts.size() > 0:
		var confirm: ConfirmationDialog = ConfirmationDialog.new()
		confirm.title = "Overwrite Files?"
		confirm.dialog_text = "The following files already exist:\n\n" + "\n".join(conflicts) + "\n\nDo you want to proceed?"
		confirm.confirmed.connect(_perform_export_save.bind(base_dir, snake_name, display_name, map_id_int, confirm))
		confirm.canceled.connect(confirm.queue_free)
		EditorInterface.get_base_control().add_child(confirm)
		confirm.popup_centered()
	else:
		_perform_export_save(base_dir, snake_name, display_name, map_id_int, null)


## Retrieves the latest event template from the library using its original UID
func _get_latest_template_event(template_uid: int) -> RPGEvent:
	for ev_data in _generator.events_library.events:
		if ev_data and ev_data.event and ev_data.event._uniq_id == template_uid:
			return ev_data.event
			
	return null


## Executes the export saving the scene and the external events resource using the internal ID
func _perform_export_save(base_dir: String, snake_name: String, display_name: String, map_id: int, confirm_dialog: ConfirmationDialog) -> void:
	if confirm_dialog:
		confirm_dialog.queue_free()
		
	var final_scene_path: String = base_dir + "/" + snake_name + ".tscn"
	var script_path: String = base_dir + "/" + snake_name + ".gd"
	var events_dir: String = "res://data/MapEvents/"
	var events_path: String = events_dir + "Map_" + str(map_id) + "_events.tres"
	
	if not DirAccess.dir_exists_absolute(events_dir):
		DirAccess.make_dir_recursive_absolute(events_dir)
		
	var script_content: String = "@tool\nextends RPGMap\n"
	var file: FileAccess = FileAccess.open(script_path, FileAccess.WRITE)
	
	if file:
		file.store_string(script_content)
		file.close()
	else:
		push_error("MapGenerator: Could not create script at " + script_path)
		return
		
	EditorInterface.get_resource_filesystem().update_file(script_path)
	var map_script: Script = load(script_path)
	var new_events_res: RPGEvents = RPGEvents.new()
	var event_counter: int = 1
	
	for placed_ev in _generator.current_map_events:
		var template: RPGEvent = _generator.event_placer.get_template_from_uid(placed_ev.template_uid)
		
		if template:
			var final_event: RPGEvent = template.clone(true)
			final_event.x = placed_ev.tile.x
			final_event.y = placed_ev.tile.y
			final_event.id = event_counter
			final_event._uniq_id = RPGSYSTEM.generate_16_digit_id()
			
			new_events_res.events.append(final_event)
			event_counter += 1
			
	ResourceSaver.save(new_events_res, events_path)
	var map_node: Node2D = Node2D.new()
	map_node.set_script(map_script)
	map_node.name = snake_name
	map_node.y_sort_enabled = true
	map_node.set("internal_id", map_id)
	map_node.set("custom_map_name", display_name)
	
	var base_tile_size: Vector2i = Vector2i(32, 32)
	var layers_to_check: Array[TileMapLayer] = [_generator.layer_ground_base, _generator.layer_ground_detail, _generator.layer_shadows, _generator.layer_walls, _generator.layer_environment]
	
	for l in layers_to_check:
		if l and l.tile_set:
			base_tile_size = l.tile_set.tile_size
			break
			
	map_node.set("tile_size", base_tile_size)
	
	var grad_res = load("res://addons/RPGMap/Assets/GridGradient/orange_gradient.tres")
	if grad_res:
		map_node.set("grid_gradient", grad_res)
		
	for l in layers_to_check:
		if l:
			var dup: TileMapLayer = l.duplicate()
			var debug_path = dup.get_node_or_null("DebugPath")
			if debug_path:
				dup.remove_child(debug_path)
				debug_path.queue_free()
			map_node.add_child(dup)
			_set_owner_recursive(dup, map_node)
			
	var packed_scene: PackedScene = PackedScene.new()
	var err: Error = packed_scene.pack(map_node)
	
	if err == OK:
		ResourceSaver.save(packed_scene, final_scene_path)
		map_node.scene_file_path = final_scene_path
		map_node.set("events", new_events_res)
		if RPGSYSTEM.map_infos:
			RPGSYSTEM.map_infos.fix_maps([map_node])
		print("MapGenerator: Exported successfully. ID: " + str(map_id))
	else:
		push_error("MapGenerator: Failed to pack the scene.")
		
	map_node.queue_free()
	EditorInterface.get_resource_filesystem().scan()


## Recursively assigns node owners to ensure correct scene serialization
func _set_owner_recursive(node: Node, new_owner: Node) -> void:
	node.owner = new_owner
	for child in node.get_children():
		_set_owner_recursive(child, new_owner)
