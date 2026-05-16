## map_generator_plugin.gd
@tool
extends EditorPlugin


#region VARIABLES
var inspector_plugin: EditorInspectorPlugin
var current_object: MapGenerator
var floating_panel: MapGeneratorFloatingPanel
var blocker_overlay: ColorRect
var active_canvas: MapEventCanvasGenerator
var _auto_check_timer: float = 0.0
var map_button: Button
#endregion



## Initializes the plugin, registers the custom modular inspector and sets up the floating UI
func _enter_tree() -> void:
	var inspector_script = load("res://addons/RPGMapGenerator/UI/map_generator_inspector.gd")
	inspector_plugin = inspector_script.new()
	add_inspector_plugin(inspector_plugin)
	
	var scene = load("res://addons/RPGMapGenerator/UI/floating_panel.tscn")
	if scene:
		floating_panel = scene.instantiate()
		floating_panel.visible = false
		floating_panel.top_level = true
		
	_setup_blocker_overlay()
	
	var selection = get_editor_interface().get_selection()
	if not selection.selection_changed.is_connected(_on_editor_selection_changed):
		selection.selection_changed.connect(_on_editor_selection_changed)
	
	_create_button()
		
	_on_editor_selection_changed()


func _ready() -> void:
	_repos_floating_panel()
	var saved_pos: Vector2 = FileCache.options.get("map_generator_panel_pos", Vector2(40, 40))
	print(saved_pos)
	floating_panel.set_deferred("global_position", saved_pos)


func _repos_floating_panel() -> void:
	while not floating_panel or not FileCache.cache_setted:
		await RenderingServer.frame_post_draw
		
	var saved_pos: Vector2 = FileCache.options.get("map_generator_panel_pos", Vector2(40, 40))
	print(saved_pos, " from plugin")
	floating_panel.set_deferred("global_position", saved_pos)


func _create_button() -> void:
	map_button = Button.new()
	map_button.icon = preload("uid://daohf8pvmdk62")
	map_button.name = "MapGeneratorButton"
	map_button.toggle_mode = true
	map_button.text = "Open Map Generator (ALT+M)"
	map_button.pressed.connect(_on_map_button_pressed, CONNECT_DEFERRED)
	map_button.theme = load("res://addons/CustomControls/Resources/Themes/editor_buitton_themes.tres")
	map_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	map_button.tooltip_text = "[title]Open Map Generator[/title]\nOpen the map generator scene"
	
	RPGMenuAPI.add_menu_item(map_button)
	
	CustomTooltipManager.plugin_replace_all_tooltips_with_custom(map_button)


func _shortcut_input(event: InputEvent) -> void:
	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		if event.keycode == KEY_M and not event.is_ctrl_pressed() and event.is_alt_pressed():
			_on_map_button_pressed()


func _on_map_button_pressed() -> void:
	var map_path: String = "res://addons/RPGMapGenerator/main_map_generator.tscn"
	if map_path and ResourceLoader.exists(map_path):
		EditorInterface.open_scene_from_path(map_path)



## Cleans up the custom inspector and UI overlays to leave the editor state clean
func _exit_tree() -> void:
	if inspector_plugin:
		remove_inspector_plugin(inspector_plugin)
		inspector_plugin = null
		
	var selection = get_editor_interface().get_selection()
	if selection.selection_changed.is_connected(_on_editor_selection_changed):
		selection.selection_changed.disconnect(_on_editor_selection_changed)
		
	if floating_panel:
		var viewport = EditorInterface.get_editor_viewport_2d()
		if viewport:
			var vp_container = viewport.get_parent()
			if vp_container and vp_container.resized.is_connected(floating_panel._clamp_panel_position):
				vp_container.resized.disconnect(floating_panel._clamp_panel_position)
		floating_panel.queue_free()
		
	if blocker_overlay:
		blocker_overlay.queue_free()
	
	if map_button:
		RPGMenuAPI.remove_menu_item(map_button)
		map_button.queue_free()



## Periodically checks for auto-selection when the editor focus is empty
func _process(delta: float) -> void:
	_auto_check_timer -= delta
	if _auto_check_timer <= 0.0:
		_auto_check_timer = 0.5
		_check_auto_selection()



#region UI MANAGEMENT (BLOCKER)
## Builds the blocker overlay that prevents input during heavy background generation
func _setup_blocker_overlay() -> void:
	blocker_overlay = ColorRect.new()
	blocker_overlay.color = Color(0, 0, 0, 0.6)
	blocker_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	blocker_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	blocker_overlay.top_level = true
	blocker_overlay.visible = false
	
	var lbl = Label.new()
	lbl.text = "Generating Map...\nPlease Wait"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 28)
	lbl.set_anchors_preset(Control.PRESET_CENTER)
	blocker_overlay.add_child(lbl)
	
	EditorInterface.get_base_control().add_child(blocker_overlay)



func _show_blocker() -> void:
	if blocker_overlay:
		EditorInterface.get_base_control().move_child(blocker_overlay, -1)
		blocker_overlay.visible = true



func _hide_blocker() -> void:
	if blocker_overlay:
		blocker_overlay.visible = false
#endregion



#region EDITOR INTEGRATION
## Tells the editor that this plugin handles MapGenerators and EventCanvases
func _handles(object: Object) -> bool:
	return object is MapGenerator or object is MapEventCanvasGenerator



## Intercepts mouse events in the 2D editor viewport and passes them to the canvas
func _forward_canvas_gui_input(event: InputEvent) -> bool:
	if floating_panel and floating_panel.get_global_rect().has_point(floating_panel.get_global_mouse_position()):
		return false
		
	if active_canvas and active_canvas.is_visible_in_tree():
		return active_canvas.process_editor_input(event)
		
	return false



## Updates the editor state when the selected node changes
func _on_editor_selection_changed() -> void:
	var selected_nodes = get_editor_interface().get_selection().get_selected_nodes()
	var ur = get_undo_redo()
	
	if current_object:
		if current_object.generation_started.is_connected(_show_blocker):
			current_object.generation_started.disconnect(_show_blocker)
		if current_object.generation_finished.is_connected(_hide_blocker):
			current_object.generation_finished.disconnect(_hide_blocker)
			
	if active_canvas:
		active_canvas.set_grid_visible(false)
		active_canvas = null
		
	if selected_nodes.size() > 0:
		var node = selected_nodes[0]
		
		if node is MapGenerator:
			current_object = node
			if "editor_undo_redo" in current_object:
				current_object.editor_undo_redo = ur
			
			if not current_object.generation_started.is_connected(_show_blocker):
				current_object.generation_started.connect(_show_blocker)
			if not current_object.generation_finished.is_connected(_hide_blocker):
				current_object.generation_finished.connect(_hide_blocker)
				
			var viewport = EditorInterface.get_editor_viewport_2d()
			if viewport and floating_panel:
				var vp_container = viewport.get_parent()
				
				if not floating_panel.is_inside_tree():
					vp_container.add_child(floating_panel)
					if not vp_container.resized.is_connected(floating_panel._clamp_panel_position):
						vp_container.resized.connect(floating_panel._clamp_panel_position)
						
				vp_container.move_child(floating_panel, -1)
				floating_panel.sync_with_generator(current_object)
				floating_panel.visible = true
				floating_panel.call_deferred("set_global_position", FileCache.options.get("map_generator_panel_pos", Vector2(40, 40)))
				floating_panel.call_deferred("_clamp_panel_position")
				
			var canvas = current_object.get_node_or_null("%EventCanvas")
			if canvas and canvas is MapEventCanvasGenerator:
				active_canvas = canvas
				active_canvas.set_grid_visible(true)
				update_overlays()
				
		elif node is MapEventCanvasGenerator:
			active_canvas = node
			if "editor_undo_redo" in active_canvas:
				active_canvas.editor_undo_redo = ur
			active_canvas.set_grid_visible(true)
			update_overlays()
			
			current_object = null 
			if floating_panel:
				floating_panel.visible = false
		else:
			current_object = null
			if floating_panel:
				floating_panel.visible = false
	else:
		current_object = null
		if floating_panel:
			floating_panel.visible = false



func _check_auto_selection() -> void:
	var editor_selection: EditorSelection = get_editor_interface().get_selection()
	
	if editor_selection.get_selected_nodes().is_empty():
		var root: Node = EditorInterface.get_edited_scene_root()
		if root and root is MapGenerator:
			editor_selection.add_node(root)
#endregion
