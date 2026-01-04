@tool
class_name RPGMapPlugin
extends EditorPlugin

enum MODE {NONE, EVENT, EXTRACTION_EVENT, ENEMY_SPAWN, EVENT_REGION}
const RESIZE_HANDLE_SIZE = 8
const RESIZE_CURSORS = {
	"arrow": Control.CURSOR_ARROW,
	"top_left": Control.CURSOR_FDIAGSIZE,
	"top_right": Control.CURSOR_BDIAGSIZE,
	"bottom_left": Control.CURSOR_BDIAGSIZE,
	"bottom_right": Control.CURSOR_FDIAGSIZE,
	"left": Control.CURSOR_HSIZE,
	"right": Control.CURSOR_HSIZE,
	"top": Control.CURSOR_VSIZE,
	"bottom": Control.CURSOR_VSIZE,
	"move": Control.CURSOR_POINTING_HAND
}

const GRID_MOVEMENT_MODE = 1
const FREE_MOVEMENT_NODE = 2
const EVENT_MOVEMENT_MODE = 3

var is_resizing = false
var resize_handle = ""
var resize_start_pos = Vector2.ZERO
var resize_start_rect: Rect2
var current_cursor: Control.CursorShape = RESIZE_CURSORS.arrow


var event_button: Button
var extraction_event_button: Button
var enemy_spawn_region_button: Button
var event_region_button: Button
var event_container_control: MarginContainer
var extraction_event_container_control: MarginContainer
var enemy_spawn_container_control: MarginContainer
var event_region_container_control: MarginContainer
var event_container_control_window: Window
var extraction_event_container_control_window: Window
var enemy_spawn_container_control_window: Window
var event_region_container_control_window: Window
var current_object: RPGMap
var current_edit_mode: MODE = MODE.NONE
var current_tile_pos: Vector2i
var dragging_event: RPGEvent
var event_drag_start_pos: Vector2i
var start_pos_drag_start_pos: Vector2i
var dragging_extraction_event: RPGExtractionItem
var extraction_drag_start_pos: Vector2i
var dragging_enemy_spawn_region: EnemySpawnRegion
var dragging_event_region: EventRegion
var moving_enemy_spawn_region: EnemySpawnRegion
var moving_event_region: EventRegion
var dragging_start_position: RPGMapPosition
var current_event: RPGEvent
var current_extraction_event: RPGExtractionItem
var current_enemy_spawn_region: EnemySpawnRegion
var current_event_region: EventRegion
var drawing_region_start_position: Vector2
var current_region_position: Vector2i
var current_start_position: RPGMapPosition
var cursor: NinePatchRect
var selected_cursor: NinePatchRect

var toggled_regions_button: Button

var scene_preview: Variant

var tile_popup_menu: PopupMenu
var extraction_tile_popup_menu: PopupMenu
var region_popup_menu: PopupMenu
var start_position_popup_menu: PopupMenu
const POPUP_MENU_OFFSET: Vector2 = Vector2(5, 5)

var dialog_sizes: Dictionary

var busy: bool = false

var focus_tile_is_enabled: bool = true

var preset_manager: EventPresetList = EventPresetList.new()
var extraction_preset_manager: ExtractionEventPresetList = ExtractionEventPresetList.new()

var DETACHABLE_WINDOW: PackedScene

var edit_configs = {
	MODE.EVENT: {
		"mode": MODE.EVENT,
		"edit_method": "set_editing_events",
		"button_index": 0,
		"container": "event_container_control",
		"window": "event_container_control_window",
		"events_property": "events",
		"container_property": "events",
		"dialog_option": "event_dialog",
		"detach_method": "_on_detach_event_container_control",
		"window_title": "Event List",
		"show_regions": true
	},
	MODE.EXTRACTION_EVENT: {
		"mode": MODE.EXTRACTION_EVENT,
		"edit_method": "set_editing_extraction_events",
		"button_index": 1,
		"container": "extraction_event_container_control",
		"window": "extraction_event_container_control_window",
		"events_property": "extraction_events",
		"container_property": "extraction_events",
		"dialog_option": "extraction_event_dialog",
		"detach_method": "_on_detach_extraction_event_container_control",
		"window_title": "Extraction Event List",
		"show_regions": true
	},
	MODE.ENEMY_SPAWN: {
		"mode": MODE.ENEMY_SPAWN,
		"edit_method": "set_editing_enemy_spawn_regions",
		"button_index": 2,
		"container": "enemy_spawn_container_control",
		"window": "enemy_spawn_container_control_window",
		"events_property": "regions",
		"container_property": "regions",
		"dialog_option": "enemy_spawn_region_dialog",
		"detach_method": "_on_detach_enemy_spawn_container_control",
		"window_title": "Enemy Spawn Region List",
		"show_regions": false
	},
	MODE.EVENT_REGION: {
		"mode": MODE.EVENT_REGION,
		"edit_method": "set_editing_event_regions",
		"button_index": 3,
		"container": "event_region_container_control",
		"window": "event_region_container_control_window",
		"events_property": "event_regions",
		"container_property": "regions",
		"dialog_option": "event_region_dialog",
		"detach_method": "_on_detach_region_event_container_control",
		"window_title": "Event Region List",
		"show_regions": false
	}
}


static func reload_inputs_safely():
	var editor_actions_backup = {}
	
	for action_name in InputMap.get_actions():
		var action_data = {
			"events": InputMap.action_get_events(action_name),
			"deadzone": InputMap.action_get_deadzone(action_name)
		}
		editor_actions_backup[action_name] = action_data

	InputMap.load_from_project_settings()

	for action_name in editor_actions_backup.keys():
		if not InputMap.has_action(action_name):
			var data = editor_actions_backup[action_name]
			
			InputMap.add_action(action_name, data["deadzone"])
			
			for event in data["events"]:
				InputMap.action_add_event(action_name, event)


func _enter_tree() -> void:
	tree_exiting.connect(_tree_exiting)
	
	#add_autoload_singleton("RPGMapsInfo", "res://addons/RPGMap/Scripts/maps_info.gd")
	#add_autoload_singleton("RPGSYSTEM", "res://addons/RPGMap/Scripts/system.gd")

	event_container_control = preload("res://addons/RPGMap/Scenes/event_container.tscn").instantiate()
	event_container_control.requested_edit_event.connect(_on_event_container_requested_edit)
	event_container_control.requested_remove_event.connect(_on_event_container_requested_remove)
	event_container_control.item_selected.connect(_on_event_container_item_selected)
	event_container_control.detach_panel.connect(_on_detach_event_container_control)

	event_button = add_control_to_bottom_panel(event_container_control, "Events")
	event_button.toggled.connect(_on_event_button_toggled)

	event_container_control.enable_plugin()
	
	CustomTooltipManager.plugin_replace_all_tooltips_with_custom.call_deferred(event_container_control)
	
	extraction_event_container_control = preload("res://addons/RPGMap/Scenes/extraction_event_container.tscn").instantiate()
	extraction_event_container_control.requested_edit_event.connect(_on_extraction_event_container_requested_edit)
	extraction_event_container_control.requested_remove_event.connect(_on_extraction_event_container_requested_remove)
	extraction_event_container_control.item_selected.connect(_on_extraction_event_container_item_selected)
	extraction_event_container_control.detach_panel.connect(_on_detach_extraction_event_container_control)

	extraction_event_button = add_control_to_bottom_panel(extraction_event_container_control, "Extraction Events")
	extraction_event_button.toggled.connect(_on_extraction_event_button_toggled)

	extraction_event_container_control.enable_plugin()
	
	CustomTooltipManager.plugin_replace_all_tooltips_with_custom.call_deferred(extraction_event_container_control)

	enemy_spawn_container_control = preload("res://addons/RPGMap/Scenes/enemy_spawn_region_container.tscn").instantiate()
	enemy_spawn_container_control.requested_edit_region.connect(_on_enemy_spawn_region_container_requested_edit)
	enemy_spawn_container_control.requested_remove_region.connect(_on_enemy_spawn_region_container_requested_remove)
	enemy_spawn_container_control.item_selected.connect(_on_enemy_spawn_region_container_item_selected)
	enemy_spawn_container_control.detach_panel.connect(_on_detach_enemy_spawn_container_control)

	enemy_spawn_region_button = add_control_to_bottom_panel(enemy_spawn_container_control, "Enemy Spawn Regions")
	enemy_spawn_region_button.toggled.connect(_on_enemy_spawn_region_button_toggled)

	enemy_spawn_container_control.enable_plugin()
	
	CustomTooltipManager.plugin_replace_all_tooltips_with_custom.call_deferred(enemy_spawn_container_control)

	event_region_container_control = preload("res://addons/RPGMap/Scenes/event_region_container.tscn").instantiate()
	event_region_container_control.requested_edit_region.connect(_on_region_event_container_requested_edit)
	event_region_container_control.requested_remove_region.connect(_on_region_event_container_requested_remove)
	event_region_container_control.item_selected.connect(_on_region_event_container_item_selected)
	event_region_container_control.detach_panel.connect(_on_detach_region_event_container_control)

	event_region_button = add_control_to_bottom_panel(event_region_container_control, "Region Events")
	event_region_button.toggled.connect(_on_event_region_button_toggled)

	event_region_container_control.enable_plugin()
	
	CustomTooltipManager.plugin_replace_all_tooltips_with_custom.call_deferred(event_region_container_control)

	var selected_nodes = get_editor_interface().get_selection().get_selected_nodes()
	if selected_nodes.size() > 0:
		var buttons_visibility: bool = selected_nodes[0] is RPGMap and selected_nodes[0].can_add_events
		event_button.visible = buttons_visibility
		extraction_event_button.visible = buttons_visibility
		enemy_spawn_region_button.visible = buttons_visibility
		event_region_button.visible = buttons_visibility
	else:
		event_button.visible = false
		extraction_event_button.visible = false
		enemy_spawn_region_button.visible = false
		event_region_button.visible = false

	set_force_draw_over_forwarding_enabled()
	scene_preview = get_editor_interface().get_resource_previewer()
	
	var ins = preload("res://addons/RPGMap/Scenes/rpg_tile_menu.tscn")
	tile_popup_menu = ins.instantiate()
	tile_popup_menu.visible = false
	tile_popup_menu.index_pressed.connect(_on_tile_popup_menu_index_pressed)
	tile_popup_menu.visibility_changed.connect(_on_tile_popup_menu_visibility_changed)
	call_deferred("add_child", tile_popup_menu)
	var sub_popup1 = tile_popup_menu.get_child(0)
	sub_popup1.index_pressed.connect(_on_tile_subpopup_menu1_index_pressed)
	var sub_popup2 = tile_popup_menu.get_child(1)
	sub_popup2.index_pressed.connect(_on_preset_pressed)
	tile_popup_menu.call_deferred("add_submenu_node_item", "Set start position for...", sub_popup1)
	tile_popup_menu.call_deferred("add_separator")
	tile_popup_menu.call_deferred("add_submenu_node_item", "Presets...", sub_popup2)
	tile_popup_menu.call_deferred("add_separator")
	
	extraction_tile_popup_menu = ins.instantiate(PackedScene.GEN_EDIT_STATE_MAIN_INHERITED)
	extraction_tile_popup_menu.visible = false
	extraction_tile_popup_menu.index_pressed.connect(_on_extraction_tile_popup_menu_index_pressed)
	extraction_tile_popup_menu.visibility_changed.connect(_on_extraction_tile_popup_menu_visibility_changed)
	call_deferred("add_child", extraction_tile_popup_menu)
	sub_popup2 = extraction_tile_popup_menu.get_child(1)
	sub_popup2.index_pressed.connect(_on_extraction_preset_pressed)
	extraction_tile_popup_menu.call_deferred("add_submenu_node_item", "Presets...", sub_popup2)
	extraction_tile_popup_menu.call_deferred("add_separator")

	ins = preload("res://addons/RPGMap/Scenes/rpg_enemy_spawn_region_menu.tscn")
	region_popup_menu = ins.instantiate()
	region_popup_menu.visible = false
	region_popup_menu.index_pressed.connect(_on_region_popup_menu_index_pressed)
	region_popup_menu.visibility_changed.connect(_on_region_popup_menu_visibility_changed)
	call_deferred("add_child", region_popup_menu)

	ins = preload("res://addons/RPGMap/Scenes/rpg_start_position_menu.tscn")
	start_position_popup_menu = ins.instantiate()
	start_position_popup_menu.visible = false
	start_position_popup_menu.index_pressed.connect(_on_start_position_popup_menu_index_pressed)
	start_position_popup_menu.visibility_changed.connect(_on_start_position_popup_menu_visibility_changed)
	call_deferred("add_child", start_position_popup_menu)
	
	var path = "res://addons/RPGMap/Scenes/toggled_regions_draw_button.tscn"
	toggled_regions_button = load(path).instantiate()
	toggled_regions_button.toggled.connect(_on_toggled_regions_draw_butto_pressed)
	toggled_regions_button.tooltip_text = "[title]Toggled Regions Visibility[/title]\nView regions added to map in the event editor"
	
	add_control_to_container(EditorPlugin.CONTAINER_CANVAS_EDITOR_MENU, toggled_regions_button)
	CustomTooltipManager.plugin_replace_all_tooltips_with_custom.call_deferred(toggled_regions_button)
	toggled_regions_button.visible = false

	add_custom_type("RPGMap", "TileMap", preload("res://addons/RPGData/ModulesRPG/rpg_map.gd"), null)

	get_tree().node_added.connect(_on_node_added)

	var nodes_selected = EditorInterface.get_selection().get_selected_nodes()
	if nodes_selected.size() > 0:
		EditorInterface.edit_node(nodes_selected[0])
	
	DETACHABLE_WINDOW = load("res://addons/CustomControls/detachable_window.tscn")


func _populate_event_presets_menu() -> void:
	var sub_popup_presets = tile_popup_menu.get_child(1)
	sub_popup_presets.clear()
	
	sub_popup_presets.add_item("Loading presets...")
	sub_popup_presets.set_item_disabled(0, true)
	
	if preset_manager.presets_loaded.is_connected(_on_presets_loaded_callback):
		preset_manager.presets_loaded.disconnect(_on_presets_loaded_callback)
	
	preset_manager.presets_loaded.connect(_on_presets_loaded_callback, CONNECT_ONE_SHOT)
	
	preset_manager.refresh_async("EventPresets", "_event_list.res")


func _on_presets_loaded_callback(loaded_presets: Dictionary) -> void:
	var sub_popup_presets = tile_popup_menu.get_child(1)
	if not is_instance_valid(sub_popup_presets):
		return
		
	sub_popup_presets.clear()
	
	if loaded_presets.is_empty():
		sub_popup_presets.add_item("(None)")
		sub_popup_presets.set_item_disabled(0, true)
	else:
		var index = 0
		var name_counts = {}
		for key in loaded_presets:
			var preset_name = loaded_presets[key].name
			if not name_counts.has(preset_name):
				name_counts[preset_name] = 0
			name_counts[preset_name] += 1
		var keys = loaded_presets.keys()
		keys.sort_custom(func(a, b): return a.naturalnocasecmp_to(b) < 0)
		for key in keys:
			var data = loaded_presets[key]
			var display_name = data.name
			if name_counts[display_name] > 1:
				display_name = "%s (%s)" % [data.name, key]
			sub_popup_presets.add_item(display_name)
			sub_popup_presets.set_item_metadata(index, data.path)
			index += 1


func get_presets_folder() -> String:
	var documents_path = OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS)
	return documents_path.path_join("GodotRPGCreatorPresets/EventPresets/")


func _populate_extraction_event_presets_menu() -> void:
	var sub_popup_presets = extraction_tile_popup_menu.get_child(1)
	sub_popup_presets.clear()
	
	sub_popup_presets.add_item("Loading presets...")
	sub_popup_presets.set_item_disabled(0, true)
	
	if extraction_preset_manager.presets_loaded.is_connected(_on_extraction_event_presets_loaded_callback):
		extraction_preset_manager.presets_loaded.disconnect(_on_extraction_event_presets_loaded_callback)
	
	extraction_preset_manager.presets_loaded.connect(_on_extraction_event_presets_loaded_callback, CONNECT_ONE_SHOT)
	
	extraction_preset_manager.refresh_async("ExtractionEventPresets", "_extraction_list.res")


func _on_extraction_event_presets_loaded_callback(loaded_presets: Dictionary) -> void:
	var sub_popup_presets = extraction_tile_popup_menu.get_child(1)
	if not is_instance_valid(sub_popup_presets):
		return
		
	sub_popup_presets.clear()
	
	if loaded_presets.is_empty():
		sub_popup_presets.add_item("(None)")
		sub_popup_presets.set_item_disabled(0, true)
	else:
		var index = 0
		var name_counts = {}
		for key in loaded_presets:
			var preset_name = loaded_presets[key].name
			if not name_counts.has(preset_name):
				name_counts[preset_name] = 0
			name_counts[preset_name] += 1
		var keys = loaded_presets.keys()
		keys.sort_custom(func(a, b): return a.naturalnocasecmp_to(b) < 0)
		for key in keys:
			var data = loaded_presets[key]
			var display_name = data.name
			if name_counts[display_name] > 1:
				display_name = "%s (%s)" % [data.name, key]
			sub_popup_presets.add_item(display_name)
			sub_popup_presets.set_item_metadata(index, data.path)
			index += 1


func get_extraction_presets_folder() -> String:
	var documents_path = OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS)
	return documents_path.path_join("GodotRPGCreatorPresets/ExtractionEventPresets/")


func _on_toggled_regions_draw_butto_pressed(value: bool) -> void:
	if current_object:
		current_object.force_show_regions = value
		current_object.queue_redraw()


func _tree_exiting() -> void:
	set_process(false)
	set_process_input(false)


func _exit_tree() -> void:
	#remove_autoload_singleton("RPGMapsInfo")
	#remove_autoload_singleton("RPGSYSTEM")
	get_tree().node_added.disconnect(_on_node_added)

	if event_container_control:
		if event_button:
			remove_control_from_bottom_panel(event_container_control)
		CustomTooltipManager.restore_all_tooltips_for(event_container_control)
		if FileCache.options.event_dialog.detached:
			event_container_control.get_parent().queue_free()
		else:
			event_container_control.queue_free()
	
	if extraction_event_container_control:
		if extraction_event_button:
			remove_control_from_bottom_panel(extraction_event_container_control)
		CustomTooltipManager.restore_all_tooltips_for(extraction_event_container_control)
		if FileCache.options.extraction_event_dialog.detached:
			extraction_event_container_control.get_parent().queue_free()
		else:
			extraction_event_container_control.queue_free()
	
	if enemy_spawn_container_control:
		if enemy_spawn_region_button:
			remove_control_from_bottom_panel(enemy_spawn_container_control)
		CustomTooltipManager.restore_all_tooltips_for(enemy_spawn_container_control)
		if FileCache.options.enemy_spawn_region_dialog.detached:
			enemy_spawn_container_control.get_parent().queue_free()
		else:
			enemy_spawn_container_control.queue_free()
	
	if event_button:
		remove_control_from_bottom_panel(event_button)
		event_button.queue_free()
	
	if extraction_event_button:
		remove_control_from_bottom_panel(extraction_event_button)
		extraction_event_button.queue_free()
	
	if enemy_spawn_region_button:
		remove_control_from_bottom_panel(enemy_spawn_region_button)
		enemy_spawn_region_button.queue_free()
	
	if event_region_button:
		remove_control_from_bottom_panel(event_region_button)
		event_region_button.queue_free()
	
	if current_object and current_object is RPGMap:
		current_object.editing_events = false
		current_object.editing_extraction_events = false
		current_object.editing_enemy_spawn_region = false
		current_object.editing_event_region = false
		current_object.queue_redraw()
	
	if toggled_regions_button:
		remove_control_from_container(EditorPlugin.CONTAINER_CANVAS_EDITOR_MENU, toggled_regions_button)
		toggled_regions_button.queue_free()
	
	if tile_popup_menu: tile_popup_menu.queue_free()
	if extraction_tile_popup_menu: extraction_tile_popup_menu.queue_free()
	if region_popup_menu: region_popup_menu.queue_free()
	if start_position_popup_menu: start_position_popup_menu.queue_free()


func _handle_button_toggle(edit_type: int, toggled_on: bool) -> void:
	var config = edit_configs[edit_type]
	
	current_edit_mode = config.mode if toggled_on else MODE.NONE
	
	if current_object:
		current_object.call(config.edit_method, toggled_on)
	
	if toggled_on:
		_setup_editing_mode(config)
		_hide_other_windows(edit_type)
		_handle_regions_button(config, toggled_on)
	
	_handle_regions_button_update(config, toggled_on)

# Configura el modo de edición
func _setup_editing_mode(config: Dictionary) -> void:
	EditorInterface.set_main_screen_editor("2D")
	
	if current_object:
		current_object.current_edit_button_pressed = config.button_index
		get_editor_interface().get_selection().add_node(current_object)
		
		if "refresh_canvas" in current_object:
			current_object.refresh_canvas()
		
		var container = get(config.container)
		if container:
			container.set(config.container_property, current_object.get(config.events_property))
			container.refresh(true)
			
			if FileCache.options.get(config.dialog_option).detached:
				call(config.detach_method, container)

# Oculta las otras ventanas cuando se activa un modo
func _hide_other_windows(current_edit_type: int) -> void:
	for edit_type in edit_configs:
		if edit_type != current_edit_type:
			var config = edit_configs[edit_type]
			var window = get(config.window)
			if window:
				var dialog_option = FileCache.options.get(config.dialog_option)
				dialog_option.position = window.position
				dialog_option.size = window.size
				window.hide()

# Maneja la visibilidad del botón de regiones
func _handle_regions_button(config: Dictionary, toggled_on: bool) -> void:
	if not toggled_regions_button or not config.show_regions:
		if toggled_regions_button:
			toggled_regions_button.visible = false
			toggled_regions_button.toggled.emit(false)
		return
	
	toggled_regions_button.visible = current_object != null and current_object.current_edit_button_pressed == config.button_index and toggled_on
	
	if toggled_regions_button.visible:
		_force_toggled_regions_button_position()
	
	toggled_regions_button.toggled.emit(toggled_regions_button.is_pressed())

# Actualiza el estado del botón de regiones
func _handle_regions_button_update(config: Dictionary, toggled_on: bool) -> void:
	if not config.show_regions:
		return
		
	if (current_object and "current_edit_button_pressed" in current_object and
		current_object.current_edit_button_pressed == config.button_index and
		not toggled_regions_button.visible and
		current_object.has_method("perform_full_update")):
		
		var p = toggled_regions_button.is_pressed()
		toggled_regions_button.set_pressed(true)
		toggled_regions_button.set_pressed(false)
		current_object.perform_full_update()
		await get_tree().process_frame
		await get_tree().process_frame
		toggled_regions_button.set_pressed_no_signal(p)

# Funciones específicas simplificadas
func _on_event_button_toggled(toggled_on: bool) -> void:
	_handle_button_toggle(MODE.EVENT, toggled_on)

func _on_extraction_event_button_toggled(toggled_on: bool) -> void:
	_handle_button_toggle(MODE.EXTRACTION_EVENT, toggled_on)

func _on_enemy_spawn_region_button_toggled(toggled_on: bool) -> void:
	_handle_button_toggle(MODE.ENEMY_SPAWN, toggled_on)

func _on_event_region_button_toggled(toggled_on: bool) -> void:
	_handle_button_toggle(MODE.EVENT_REGION, toggled_on)

# Función genérica para crear ventanas desprendibles
func _create_detachable_window(panel: MarginContainer, config: Dictionary) -> void:
	var window_property = config.window
	var existing_window = get(window_property)
	
	if existing_window:
		existing_window.show()
		existing_window.grab_focus()
		return
	
	var dialog_option = FileCache.options.get(config.dialog_option)
	dialog_option.detached = true
	
	var old_parent = panel.get_parent()
	panel.hide_detach_button(true)
	
	if not DETACHABLE_WINDOW:
		DETACHABLE_WINDOW = load("res://addons/CustomControls/detachable_window.tscn")
	
	var w = DETACHABLE_WINDOW.instantiate()
	w.title = config.window_title
	
	if dialog_option.position != Vector2i.ZERO:
		w.position = dialog_option.position
	if dialog_option.size != Vector2i.ZERO:
		w.size = dialog_option.size
	
	get_parent().add_child(w)
	panel.get_parent().remove_child(panel)
	w.get_node("%MainContainer").add_child(panel)
	
	w.close_requested.connect(
		func():
			dialog_option.detached = false
			dialog_option.position = w.position
			dialog_option.size = w.size
			panel.reparent(old_parent)
			old_parent.move_child(panel, 0)
			panel.hide_detach_button(false)
			w.queue_free()
			set(window_property, null)
			CustomTooltipManager.replace_all_tooltips_with_custom(panel)
	)
	
	old_parent.size.y = 0
	set(window_property, w)
	CustomTooltipManager.replace_all_tooltips_with_custom(panel)

# Funciones de detach simplificadas
func _on_detach_event_container_control(panel: MarginContainer) -> void:
	_create_detachable_window(panel, edit_configs[MODE.EVENT])

func _on_detach_extraction_event_container_control(panel: MarginContainer) -> void:
	_create_detachable_window(panel, edit_configs[MODE.EXTRACTION_EVENT])

func _on_detach_enemy_spawn_container_control(panel: MarginContainer) -> void:
	_create_detachable_window(panel, edit_configs[MODE.ENEMY_SPAWN])

func _on_detach_region_event_container_control(panel: MarginContainer) -> void:
	_create_detachable_window(panel, edit_configs[MODE.EVENT_REGION])

# Funciones genéricas para manejar edición y eliminación
func _handle_container_edit_request(edit_type: int, index: int) -> void:
	if not current_object:
		return
	
	var config = edit_configs[edit_type]
	var events = current_object.get(config.events_property)
	
	match edit_type:
		MODE.EVENT:
			var event = events.get_event(index)
			if event:
				current_event = event
				current_tile_pos = Vector2i(event.x, event.y)
				show_edit_event_dialog()
		
		MODE.EXTRACTION_EVENT:
			var event = events[index]
			if event:
				current_extraction_event = event
				current_tile_pos = Vector2i(event.x, event.y)
				show_edit_extraction_event_dialog()
		
		MODE.ENEMY_SPAWN:
			show_edit_region_dialog()
		
		MODE.EVENT_REGION:
			show_edit_event_region_dialog()

func _handle_container_remove_request(edit_type: int, index: int) -> void:
	if not current_object:
		return
	
	match edit_type:
		MODE.EVENT:
			var event = current_object.events.get_event(index)
			if event:
				current_event = event
				current_tile_pos = Vector2i(event.x, event.y)
				remove_tile()
		
		MODE.EXTRACTION_EVENT:
			var event = current_object.extraction_events[index]
			if event:
				current_extraction_event = event
				current_tile_pos = Vector2i(event.x, event.y)
				remove_extraction_tile()
		
		MODE.ENEMY_SPAWN:
			var region = current_object.get_region(index)
			if region:
				current_enemy_spawn_region = region
				remove_region()
		
		MODE.EVENT_REGION:
			var region = current_object.get_event_region(index)
			if region:
				current_event_region = region
				remove_event_region()

func _handle_container_item_selection(edit_type: int, index: int) -> void:
	if not current_object:
		return
	
	match edit_type:
		MODE.EVENT:
			var event = current_object.events.get_event(index)
			if event:
				current_object.current_event = event
				current_object.refresh_canvas()
				if focus_tile_is_enabled:
					var pos = Vector2i(event.x, event.y) * current_object.tile_size
					_focus_any_item(pos, current_object.tile_size / 2)
		
		MODE.EXTRACTION_EVENT:
			var event = current_object.extraction_events[index]
			if event:
				current_object.current_extraction_event = event
				current_object.refresh_canvas()
				if focus_tile_is_enabled:
					var pos = Vector2i(event.x, event.y) * current_object.tile_size
					_focus_any_item(pos, current_object.tile_size / 2)
		
		MODE.ENEMY_SPAWN:
			var region = current_object.get_region(index)
			if region:
				current_object.region_selected = region
				current_object.refresh_canvas()
				if focus_tile_is_enabled:
					var pos = region.rect.position * current_object.tile_size
					_focus_any_item(pos, region.rect.size / 2)
		
		MODE.EVENT_REGION:
			var region = current_object.get_event_region(index)
			if region:
				current_object.event_region_selected = region
				current_object.refresh_canvas()
				if focus_tile_is_enabled:
					var pos = region.rect.position * current_object.tile_size
					_focus_any_item(pos, region.rect.size / 2)

# Funciones de callback simplificadas
func _on_event_container_requested_edit(index: int) -> void:
	_handle_container_edit_request(MODE.EVENT, index)

func _on_extraction_event_container_requested_edit(index: int) -> void:
	_handle_container_edit_request(MODE.EXTRACTION_EVENT, index)

func _on_enemy_spawn_region_container_requested_edit(index: int) -> void:
	_handle_container_edit_request(MODE.ENEMY_SPAWN, index)

func _on_region_event_container_requested_edit(index: int) -> void:
	_handle_container_edit_request(MODE.EVENT_REGION, index)

func _on_event_container_requested_remove(index: int) -> void:
	_handle_container_remove_request(MODE.EVENT, index)

func _on_extraction_event_container_requested_remove(index: int) -> void:
	_handle_container_remove_request(MODE.EXTRACTION_EVENT, index)

func _on_enemy_spawn_region_container_requested_remove(index: int) -> void:
	_handle_container_remove_request(MODE.ENEMY_SPAWN, index)

func _on_region_event_container_requested_remove(index: int) -> void:
	_handle_container_remove_request(MODE.EVENT_REGION, index)

func _on_event_container_item_selected(index: int) -> void:
	_handle_container_item_selection(MODE.EVENT, index)

func _on_extraction_event_container_item_selected(index: int) -> void:
	_handle_container_item_selection(MODE.EXTRACTION_EVENT, index)

func _on_enemy_spawn_region_container_item_selected(index: int) -> void:
	_handle_container_item_selection(MODE.ENEMY_SPAWN, index)

func _on_region_event_container_item_selected(index: int) -> void:
	_handle_container_item_selection(MODE.EVENT_REGION, index)


func _focus_any_item(pos: Vector2, item_size: Vector2) -> void:
	if !current_object:
		return
	
	var editor = EditorInterface.get_base_control().find_child("@CanvasItemEditorViewport*", true, false)
	if !editor:
		return
	
	var editor_viewport_2d = EditorInterface.get_editor_viewport_2d()
	var s: Vector2 = editor_viewport_2d.get_final_transform().get_scale()
	var viewport_size: Vector2 = editor_viewport_2d.get_visible_rect().size
	
	var h_scroll = editor.find_child("@HScrollBar*", true, false)
	var v_scroll = editor.find_child("@VScrollBar*", true, false)
	if !h_scroll or !v_scroll:
		return
	
	# Calculate the centered position of the object
	var centered_pos = pos + item_size / 2
	
	# Check if the object is already visible on the screen
	var current_view_rect = Rect2(Vector2(h_scroll.value, v_scroll.value), viewport_size / s)
	if current_view_rect.has_point(centered_pos):
		return # The object is already visible, we do nothing
	
	# Calculate the new offset position
	var new_scroll_pos = centered_pos - viewport_size / (2 * s)
	
	# Adjust scrollbar limits if necessary
	_adjust_scroll_limits(h_scroll, new_scroll_pos.x, viewport_size.x / s.x)
	_adjust_scroll_limits(v_scroll, new_scroll_pos.y, viewport_size.y / s.y)
	
	# Apply the displacement
	h_scroll.value = new_scroll_pos.x
	v_scroll.value = new_scroll_pos.y


func _adjust_scroll_limits(scroll_bar: ScrollBar, new_value: float, viewport_size: float) -> void:
	var half_viewport = viewport_size / 2
	
	# Adjust the minimum if necessary
	if new_value < scroll_bar.min_value + half_viewport:
		scroll_bar.min_value = new_value - half_viewport
	
	# Adjust the maximun if necessary
	if new_value > scroll_bar.max_value - half_viewport:
		scroll_bar.max_value = new_value + half_viewport
	
	# Make sure that the range is at least the size of the viewport.
	if scroll_bar.max_value - scroll_bar.min_value < viewport_size:
		scroll_bar.max_value = scroll_bar.min_value + viewport_size


func _on_node_added(node) -> void:
	if node is LineEdit or node is TextEdit:
		if !node.focus_entered.is_connected(_on_node_type1_focus_entered):
			node.focus_entered.connect(_on_node_type1_focus_entered.bind(node))


func _ready() -> void:
	get_tree().node_added.connect(_on_new_node_added)


func _process(delta: float) -> void:
	if current_edit_mode == MODE.EVENT and !event_button.is_pressed():
		_on_event_button_toggled(false)
	
	if current_edit_mode == MODE.EXTRACTION_EVENT and !extraction_event_button.is_pressed():
		_on_extraction_event_button_toggled(false)
	
	elif current_edit_mode == MODE.ENEMY_SPAWN and !enemy_spawn_region_button.is_pressed():
		_on_enemy_spawn_region_button_toggled(false)
	
	elif current_edit_mode == MODE.EVENT_REGION and !event_region_button.is_pressed():
		_on_event_region_button_toggled(false)
	
	if (
		not event_button.is_pressed() and
		not extraction_event_button.is_pressed() and
		not enemy_spawn_region_button.is_pressed() and
		not event_region_button.is_pressed() and
		current_object and
		"current_edit_button_pressed" in current_object
	):
		current_object.current_edit_button_pressed = -1


func _on_node_type1_focus_entered(node: Node) -> void:
	if !node.is_editable():
		node.release_focus()
		node.deselect()
		node.set_process_internal(false)
	else:
		node.set_process_internal(true)


func _on_new_node_added(node: Node) -> void:
	await get_tree().process_frame
	if !node or !is_instance_valid(node):
		return
	if node is RPGMap:
		if !node.tree_exited.is_connected(_on_rpgmap_exited):
			node.tree_exited.connect(_on_rpgmap_exited.bind(node))


func _on_rpgmap_exited(node: RPGMap) -> void:
	if current_object == node:
		current_object = null


func _make_visible(visible: bool) -> void:
	pass


func _edit(object: Object) -> void:
	if event_container_control_window:
		FileCache.options.event_dialog.position = event_container_control_window.position
		FileCache.options.event_dialog.size = event_container_control_window.size
		event_container_control_window.hide()
	
	if extraction_event_container_control_window:
		FileCache.options.extraction_event_dialog.position = extraction_event_container_control_window.position
		FileCache.options.extraction_event_dialog.size = extraction_event_container_control_window.size
		extraction_event_container_control_window.hide()
	
	if enemy_spawn_container_control_window:
		FileCache.options.enemy_spawn_region_dialog.position = enemy_spawn_container_control_window.position
		FileCache.options.enemy_spawn_region_dialog.size = enemy_spawn_container_control_window.size
		enemy_spawn_container_control_window.hide()
	
	if event_region_container_control_window:
		FileCache.options.event_region_dialog.position = event_region_container_control_window.position
		FileCache.options.event_region_dialog.size = event_region_container_control_window.size
		event_region_container_control_window.hide()
		
	if !object or object.get_class() == "EditorDebuggerRemoteObject":
		if event_button:
			event_button.visible = false
			event_button.toggled.emit(false)
			extraction_event_button.visible = false
			extraction_event_button.toggled.emit(false)
			enemy_spawn_region_button.visible = false
			enemy_spawn_region_button.toggled.emit(false)
			event_region_button.visible = false
			event_region_button.toggled.emit(false)
			toggled_regions_button.visible = false
			var output_button: Button = event_button.get_parent().get_child(0)
			if output_button:
				output_button.toggled.emit(true)
		return

	if current_object and is_instance_valid(current_object) and "set_editing_events" in current_object:
		current_object.set_editing_events(false)
		current_object.set_editing_extraction_events(false)
		current_object.set_editing_enemy_spawn_regions(false)
		current_object.set_editing_event_regions(false)

	current_object = object as RPGMap
	
	if current_object and !"set_editing_events" in current_object:
		current_object = null
		#return
	if event_button:
		if current_object:
			event_button.visible = true
			extraction_event_button.visible = true
			enemy_spawn_region_button.visible = true
			event_region_button.visible = true
			if "current_edit_button_pressed" in current_object and current_object.current_edit_button_pressed != -1:
				if current_object.current_edit_button_pressed == 0:
					event_button.set_pressed(false)
					event_button.set_pressed(true)
					event_button.toggled.emit(true)
				elif current_object.current_edit_button_pressed == 1:
					extraction_event_button.set_pressed(false)
					extraction_event_button.set_pressed(true)
					extraction_event_button.toggled.emit(true)
				elif current_object.current_edit_button_pressed == 2:
					enemy_spawn_region_button.set_pressed(false)
					enemy_spawn_region_button.set_pressed(true)
					enemy_spawn_region_button.toggled.emit(true)
				else:
					event_region_button.set_pressed(false)
					event_region_button.set_pressed(true)
					event_region_button.toggled.emit(true)
				current_object.refresh_canvas()
			elif current_object.can_add_events:
				get_viewport().set_input_as_handled()
				event_button.visible = true
				extraction_event_button.visible = true
				enemy_spawn_region_button.visible = true
				event_region_button.visible = true
				event_button.set_pressed(false)
				event_button.set_pressed(true)
				event_button.toggled.emit(true)
		else:
			event_button.visible = false
			event_button.toggled.emit(false)
			extraction_event_button.visible = false
			extraction_event_button.toggled.emit(false)
			enemy_spawn_region_button.visible = false
			enemy_spawn_region_button.toggled.emit(false)
			event_region_button.visible = true
			event_region_button.toggled.emit(false)
	
	if current_object:
		if Engine.is_editor_hint():
			if current_object.property_list_changed.is_connected(_on_map_property_changed):
				current_object.property_list_changed.disconnect(_on_map_property_changed)
			current_object.property_list_changed.connect(_on_map_property_changed.bind(current_object))
		var bottom_panel = event_button.get_parent()
		if bottom_panel:
			for child in bottom_panel.get_children():
				if child is Button and child.text == "TileSet":
					child.visible = false
	
	if (
		not event_button.is_pressed() and
		not extraction_event_button.is_pressed() and
		not enemy_spawn_region_button.is_pressed() and
		not event_region_button.is_pressed() and
		current_object and
		"current_edit_button_pressed" in current_object
	):
		current_object.current_edit_button_pressed = -1
	
	if toggled_regions_button:
		toggled_regions_button.visible = current_object != null and current_object.current_edit_button_pressed == 0
		if toggled_regions_button.visible:
			_force_toggled_regions_button_position()
		toggled_regions_button.toggled.emit(toggled_regions_button.is_pressed())


func _force_toggled_regions_button_position() -> void:
	if toggled_regions_button.get_index() != toggled_regions_button.get_parent().get_child_count() - 1:
		var index = toggled_regions_button.get_index() - 1
		if index >= 0:
			var vseparator = toggled_regions_button.get_parent().get_child(index)
			if vseparator is VSeparator:
				toggled_regions_button.get_parent().move_child(vseparator, -1)
		toggled_regions_button.get_parent().move_child(toggled_regions_button, -1)


func _on_map_property_changed(map: RPGMap) -> void:
	var rpg_map_info = get_node_or_null("/root/RPGMapsInfo")
	if rpg_map_info:
		rpg_map_info.fix_maps([map])


func _handles(object: Object) -> bool:
	if object is TileMapLayer:
		return true
		
	if object is Resource:
		return false
		
	var result = object is RPGMap
	
	if "EditorDebuggerRemoteObject" in str(object):
		return false
	
	if object is Node and not object.is_inside_tree():
		return false
	
	if result:
		if object.has_method("set_force_update_shadow"):
			object.set_force_update_shadow(false)
			return true
		return false
	else:
		if event_button:
			event_button.visible = false
			event_button.toggled.emit(false)
		if extraction_event_button:
			extraction_event_button.visible = false
			extraction_event_button.toggled.emit(false)
		if enemy_spawn_region_button:
			enemy_spawn_region_button.visible = false
			enemy_spawn_region_button.toggled.emit(false)
		if event_region_button:
			event_region_button.visible = false
			event_region_button.toggled.emit(false)
		if current_object:
			current_object.set_force_update_shadow(true)
			current_object.set_editing_events(false)
			current_object.current_event = null
			current_object = null
		return false



func update_cursor_shape() -> void:
	var base_control: Control = EditorInterface.get_editor_viewport_2d().get_parent().get_parent()
	base_control.set_default_cursor_shape(current_cursor)


func _forward_canvas_force_draw_over_viewport(overlay: Control) -> void:
	var viewport_2d_size = get_editor_interface().get_editor_viewport_2d().size
	var font = overlay.get_theme_default_font()
	var font_size = overlay.get_theme_default_font_size()
	var align = HORIZONTAL_ALIGNMENT_LEFT
	var text: String
	
	# Draw Map ID
	
	if current_object:
		text = "Map ID: %s" % current_object.internal_id
		var s = font.get_string_size(text, align, -1, font_size)
		var p = Vector2(viewport_2d_size.x - s.x - 20, font.get_ascent() + s.y)
		overlay.draw_string_outline(font, p, text, align, -1, font_size, 2, Color.BLACK)
		overlay.draw_string(font, p, text, align, -1, font_size, Color.WHITE)
	
	if current_edit_mode != MODE.NONE and current_object:
		# draw current tile coords
		text = str(current_tile_pos)
		if current_edit_mode == MODE.EVENT:
			var event_under_mouse = current_object.get_event_in(current_tile_pos)
			if event_under_mouse != null:
				var event_name = " | Event " + str(event_under_mouse.id).pad_zeros(4) + ":" + event_under_mouse.name
				text += event_name
			else:
				var system = get_node_or_null("/root/RPGSYSTEM")
				if system:
					var map_id = current_object.internal_id
					var ids = [
						"player_start_position",
						"land_transport_start_position",
						"sea_transport_start_position",
						"air_transport_start_position",
					]
					for id: String in ids:
						var data: RPGMapPosition = system.database.system.get(id)
						if data and data.map_id == map_id and data.position == current_tile_pos:
							text += " | " + id.replace("_", " ").capitalize()
							break
		elif current_edit_mode == MODE.EXTRACTION_EVENT:
			var event_under_mouse = current_object.get_extraction_event_in(current_tile_pos)
			if event_under_mouse != null:
				var profession_id = event_under_mouse.required_profession
				var profession_name: String
				if profession_id >= 1 and RPGSYSTEM.database.professions.size() > profession_id:
					profession_name = RPGSYSTEM.database.professions[profession_id].name
				else:
					profession_name = "⚠ Invalid Data"
				var event_name = " | Extraction Event " + str(event_under_mouse.id).pad_zeros(4) + ":" + event_under_mouse.name + " (Level %s in %s)" % [event_under_mouse.current_level, profession_name]
				text += event_name
		elif current_edit_mode == MODE.ENEMY_SPAWN:
			var region = current_object.get_region_in(current_tile_pos)
			if region:
				text += " | " + region.to_string()
		elif current_edit_mode == MODE.EVENT_REGION:
			var region = current_object.get_event_region_in(current_tile_pos)
			if region:
				text += " | " + region.to_string()
		var p = Vector2(20, viewport_2d_size.y - font.get_ascent())
		overlay.draw_string_outline(font, p, text, align, -1, font_size, 2, Color.BLACK)
		overlay.draw_string(font, p, text, align, -1, font_size, Color.WHITE)


func find_viewport_2d(node: Node, recursive_level):
	if node.get_class() == "CanvasItemEditor":
		return node.get_child(1).get_child(0).get_child(0).get_child(0).get_child(0)
	else:
		recursive_level += 1
		if recursive_level > 15:
			return null
		for child in node.get_children():
			var result = find_viewport_2d(child, recursive_level)
			if result != null:
				return result


func _input(event: InputEvent) -> void:
	if !current_object or EditorInterface.get_script_editor().is_visible_in_tree():
		return
	
	match current_edit_mode:
		MODE.ENEMY_SPAWN:
			_input_enemy_spawn_mode(event)
		MODE.EVENT_REGION:
			_input_event_region_mode(event)


func _forward_canvas_gui_input(event: InputEvent) -> bool:
	if tile_popup_menu.visible or region_popup_menu.visible or is_resizing:
		return false

	if current_edit_mode == MODE.NONE or not current_object:
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or Input.is_key_pressed(KEY_DELETE):
			var editing_object = EditorInterface.get_edited_scene_root()
			if editing_object is RPGMap:
				editing_object._keots_need_refresh()
		return false

	var input_handled: bool = false
	
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		current_object._keots_need_refresh()
	
	match current_edit_mode:
		MODE.EVENT:
			input_handled = _forward_canvas_gui_input_event_mode(event)
		MODE.EXTRACTION_EVENT:
			input_handled = _forward_canvas_gui_input_extraction_event_mode(event)
		MODE.ENEMY_SPAWN:
			input_handled = _forward_canvas_gui_input_enemy_spawn_mode(event)
		MODE.EVENT_REGION:
			input_handled = _forward_canvas_gui_input_event_region_mode(event)

	if input_handled:
		get_viewport().set_input_as_handled()
		update_overlays()
		return true
	
	return false


func _handle_region_resize_input(event: InputEvent, mode: MODE, current_data: Array, region_property: String, selected_property: String, container_control: Control, update_method: StringName) -> void:
	var region_instance = get(region_property)

	if event is InputEventMouseMotion and !is_resizing:
		var mouse_pos = current_object.get_local_mouse_position()
		current_cursor = RESIZE_CURSORS.arrow
		
		for region in current_data:
			var handle = get_resize_handle(region, mouse_pos)
			if handle != "" and handle != "inside":
				current_cursor = RESIZE_CURSORS[handle]
				get_viewport().set_input_as_handled()
				break
			elif handle == "inside":
				current_cursor = RESIZE_CURSORS.move
		
		update_cursor_shape()
	
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				var mouse_pos = current_object.get_local_mouse_position()
				
				var found_handle = false
				
				for region in current_data:
					resize_handle = get_resize_handle(region, mouse_pos)
					if resize_handle != "" and resize_handle != "inside":
						is_resizing = true
						resize_start_pos = mouse_pos
						resize_start_rect = region.rect # This is the "before" state
						set(region_property, region)
						current_object.set(selected_property, region)
						current_object.refresh_canvas()
						found_handle = true
						break
				
				if !found_handle:
					is_resizing = false
					
			else: # Mouse release
				if is_resizing and region_instance:
					var old_rect = resize_start_rect
					var new_rect = region_instance.rect
					
					# BUG FIX: Cast old_rect (Rect2) to Rect2i for comparison
					if Rect2i(old_rect) != new_rect:
						var undo_redo = get_undo_redo()
						undo_redo.create_action("Resize Region", UndoRedo.MERGE_DISABLE, current_object)
						
						# DO
						undo_redo.add_do_method(self, "_force_mode_switch", mode)
						undo_redo.add_do_property(region_instance, "rect", new_rect)
						undo_redo.add_do_method(current_object, update_method, region_instance)
						undo_redo.add_do_method(get_editor_interface(), "mark_scene_as_unsaved")
						undo_redo.add_do_method(container_control, "select", region_instance.id, false, true)
						
						# UNDO
						undo_redo.add_undo_method(self, "_force_mode_switch", mode)
						undo_redo.add_undo_property(region_instance, "rect", Rect2i(old_rect)) # Cast here too for safety
						undo_redo.add_undo_method(current_object, update_method, region_instance)
						undo_redo.add_undo_method(get_editor_interface(), "mark_scene_as_unsaved")
						undo_redo.add_undo_method(container_control, "select", region_instance.id, false, true)
						
						undo_redo.commit_action()
					
				is_resizing = false
				resize_handle = ""
				if region_instance:
					set(region_property, null)
	
	elif is_resizing and event is InputEventMouseMotion:
		var mouse_pos = current_object.get_local_mouse_position()
		var delta = Vector2i((mouse_pos - resize_start_pos) / Vector2(current_object.tile_size))
		var new_rect: Rect2i = resize_start_rect # This correctly truncates the float Rect2 to Rect2i
		
		match resize_handle:
			"top_left":
				new_rect.position += delta
				new_rect.size -= delta
			"top_right":
				new_rect.position.y += delta.y
				new_rect.size.x += delta.x
				new_rect.size.y -= delta.y
			"bottom_left":
				new_rect.position.x += delta.x
				new_rect.size.x -= delta.x
				new_rect.size.y += delta.y
			"bottom_right":
				new_rect.size += delta
			"left":
				new_rect.position.x += delta.x
				new_rect.size.x -= delta.x
			"right":
				new_rect.size.x += delta.x
			"top":
				new_rect.position.y += delta.y
				new_rect.size.y -= delta.y
			"bottom":
				new_rect.size.y += delta.y
		
		new_rect = new_rect.abs()
		new_rect.size = new_rect.size.max(Vector2i.ONE)
		
		if is_instance_valid(region_instance):
			region_instance.rect = new_rect.abs()
			current_object.call(update_method, region_instance)
			if container_control:
				container_control.select(region_instance.id, false, true)
				
		update_cursor_shape()
	
	if is_resizing:
		get_viewport().set_input_as_handled()


func get_resize_handle(region: Variant, mouse_pos: Vector2) -> String:
	var tile_size = current_object.tile_size
	var rect = Rect2(region.rect.position * tile_size, region.rect.size * tile_size)
	var handle_size = Vector2(RESIZE_HANDLE_SIZE, RESIZE_HANDLE_SIZE)
	
	if Rect2(rect.position, handle_size).has_point(mouse_pos):
		return "top_left"
	elif Rect2(rect.position + Vector2(rect.size.x - RESIZE_HANDLE_SIZE, 0), handle_size).has_point(mouse_pos):
		return "top_right"
	elif Rect2(rect.position + Vector2(0, rect.size.y - RESIZE_HANDLE_SIZE), handle_size).has_point(mouse_pos):
		return "bottom_left"
	elif Rect2(rect.end - handle_size, handle_size).has_point(mouse_pos):
		return "bottom_right"
	elif Rect2(rect.position, Vector2(RESIZE_HANDLE_SIZE, rect.size.y)).has_point(mouse_pos):
		return "left"
	elif Rect2(rect.position + Vector2(rect.size.x - RESIZE_HANDLE_SIZE, 0), Vector2(RESIZE_HANDLE_SIZE, rect.size.y)).has_point(mouse_pos):
		return "right"
	elif Rect2(rect.position, Vector2(rect.size.x, RESIZE_HANDLE_SIZE)).has_point(mouse_pos):
		return "top"
	elif Rect2(rect.position + Vector2(0, rect.size.y - RESIZE_HANDLE_SIZE), Vector2(rect.size.x, RESIZE_HANDLE_SIZE)).has_point(mouse_pos):
		return "bottom"
	elif rect.has_point(mouse_pos):
		return "inside"
	
	return ""

# --- Event Mode ---

func _forward_canvas_gui_input_event_mode(event: InputEvent) -> bool:
	var input_handled: bool = false
	
	if event is InputEventMouseMotion:
		# ... (keep existing motion logic) ...
		current_cursor = RESIZE_CURSORS.arrow
		if current_object.is_mouse_over_event() or is_mouse_over_start_positions():
			current_cursor = RESIZE_CURSORS.move
		
		var pos = current_object.get_local_mouse_position()
		update_cursor_shape()
		current_tile_pos = current_object.local_to_map(pos)
		
		if dragging_event or dragging_start_position:
			set_cursor_position()
			if cursor and is_instance_valid(cursor):
				if can_place_event_in(current_tile_pos):
					cursor.modulate = Color.WHITE
				else:
					cursor.modulate = Color("#66000044")
		
		input_handled = true
	
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		# ... (keep existing left click logic) ...
		if event.is_pressed():
			var _current_event = current_object.get_event_in(current_tile_pos)
			
			if can_place_event_in(current_tile_pos) or _current_event:
				# Double-click to create new event
				var result = add_event_in(current_tile_pos) if !_current_event and event.is_double_click() else false
				if result:
					var undo_redo = get_undo_redo()
					undo_redo.create_action("Create New Event", UndoRedo.MERGE_DISABLE, current_object)
					undo_redo.add_do_method(self, "_force_mode_switch", MODE.EVENT)
					undo_redo.add_do_method(current_object, "add_event_in", current_tile_pos)
					undo_redo.add_do_method(get_editor_interface(), "mark_scene_as_unsaved")
					undo_redo.add_do_method(event_container_control, "refresh", true)
					
					undo_redo.add_undo_method(self, "_force_mode_switch", MODE.EVENT)
					undo_redo.add_undo_method(current_object, "remove_event_in", current_tile_pos)
					undo_redo.add_undo_method(get_editor_interface(), "mark_scene_as_unsaved")
					undo_redo.add_undo_method(event_container_control, "refresh", true)
					undo_redo.add_undo_method(event_container_control, "select", -1, true, true)
					undo_redo.commit_action()
					
					call_deferred("_select_event_after_creation", current_tile_pos)
					
				elif _current_event:
					if event.is_double_click():
						show_edit_event_dialog()
					else:
						# Start dragging an existing event
						current_object.select_event(Vector2i(_current_event.x, _current_event.y))
						dragging_event = _current_event
						event_drag_start_pos = Vector2i(_current_event.x, _current_event.y) # Store original pos
						create_cursor()
						set_cursor_position()
						if event_container_control:
							event_container_control.select(dragging_event.id, false, true)
					current_cursor = RESIZE_CURSORS.move
			else:
				var start_position = get_start_position_under_mouse()
				if start_position:
					# Start dragging a start position
					current_object.current_start_position = start_position
					if event_container_control:
						event_container_control.refresh(true)
					dragging_start_position = start_position
					start_pos_drag_start_pos = start_position.position # Store original pos
					create_cursor()
					set_cursor_position()
					current_cursor = RESIZE_CURSORS.move
			update_cursor_shape()
		
		elif dragging_event:
			# Finished dragging an event
			var new_pos = current_tile_pos
			var old_pos = event_drag_start_pos
			
			var can_place = current_object.events.is_place_free_in(new_pos) and can_place_event_in(new_pos)
			
			if new_pos != old_pos and can_place:
				var undo_redo = get_undo_redo()
				undo_redo.create_action("Move Event", UndoRedo.MERGE_DISABLE, current_object)
				
				# DO
				undo_redo.add_do_method(self, "_force_mode_switch", MODE.EVENT)
				undo_redo.add_do_property(dragging_event, "x", new_pos.x)
				undo_redo.add_do_property(dragging_event, "y", new_pos.y)
				undo_redo.add_do_method(current_object, "queue_redraw")
				undo_redo.add_do_method(get_editor_interface(), "mark_scene_as_unsaved")
				undo_redo.add_do_method(event_container_control, "refresh", true)
				
				# UNDO
				undo_redo.add_undo_method(self, "_force_mode_switch", MODE.EVENT)
				undo_redo.add_undo_property(dragging_event, "x", old_pos.x)
				undo_redo.add_undo_property(dragging_event, "y", old_pos.y)
				undo_redo.add_undo_method(current_object, "queue_redraw")
				undo_redo.add_undo_method(get_editor_interface(), "mark_scene_as_unsaved")
				undo_redo.add_undo_method(event_container_control, "refresh", true)
				
				undo_redo.commit_action()
			
			dragging_event = null
			destroy_cursor()
		
		elif dragging_start_position:
			# Finished dragging a start position
			var new_pos = current_tile_pos
			var old_pos = start_pos_drag_start_pos
			
			var can_place = current_object.events.is_place_free_in(new_pos) and can_place_event_in(new_pos)
			
			if new_pos != old_pos and can_place:
				var undo_redo = get_undo_redo()
				undo_redo.create_action("Move Start Position", UndoRedo.MERGE_DISABLE, current_object)
				
				# DO
				undo_redo.add_do_method(self, "_force_mode_switch", MODE.EVENT)
				undo_redo.add_do_property(dragging_start_position, "position", new_pos)
				undo_redo.add_do_method(current_object, "queue_redraw")
				undo_redo.add_do_method(get_editor_interface(), "mark_scene_as_unsaved")
				undo_redo.add_do_method(event_container_control, "refresh", true)
				
				# UNDO
				undo_redo.add_undo_method(self, "_force_mode_switch", MODE.EVENT)
				undo_redo.add_undo_property(dragging_start_position, "position", old_pos)
				undo_redo.add_undo_method(current_object, "queue_redraw")
				undo_redo.add_undo_method(get_editor_interface(), "mark_scene_as_unsaved")
				undo_redo.add_undo_method(event_container_control, "refresh", true)
				
				undo_redo.commit_action()
					
			dragging_start_position = RPGMapPosition.new()
			current_object.current_start_position = RPGMapPosition.new()
			if event_container_control:
				event_container_control.refresh(true)
			destroy_cursor()

		input_handled = true
		
			
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.is_pressed():
		var pos = current_object.get_local_mouse_position()
		var map_pos = current_object.local_to_map(pos)
		
		# FIX: Ensure global current_tile_pos is updated exactly where we clicked
		current_tile_pos = map_pos
		
		if can_place_event_in(map_pos):
			var ev = current_object.get_event_in(map_pos)
			if ev and event_container_control:
				event_container_control.select(ev.id, true, true)
			show_tile_popup_menu(event.global_position)
		elif get_start_position_under_mouse():
			show_start_position_popup_menu(event.global_position)
		input_handled = true

	# ... (keep existing key input logic) ...
	elif event is InputEventKey and event.is_pressed():
		if event.keycode == KEY_ENTER:
			show_edit_event_dialog()
			input_handled = true
		elif event.is_ctrl_pressed():
			if event.keycode == KEY_C:
				copy_tile_into_clipboard()
				input_handled = true
			elif event.keycode == KEY_X:
				var event_to_cut = current_object.current_event
				if !event_to_cut:
					event_to_cut = current_object.get_event_in(current_tile_pos)
				
				if event_to_cut:
					current_tile_pos = Vector2i(event_to_cut.x, event_to_cut.y)
					_on_tile_popup_menu_index_pressed(2) # Call "Cut"
				input_handled = true
			elif event.keycode == KEY_V:
				paste_tile()
				input_handled = true
			elif event.keycode == KEY_DELETE:
				var event_to_remove = current_object.current_event
				if !event_to_remove:
					event_to_remove = current_object.get_event_in(current_tile_pos)
				
				if event_to_remove:
					current_object.current_event = event_to_remove
					current_tile_pos = Vector2i(event_to_remove.x, event_to_remove.y)
					remove_tile()
				input_handled = true
	
	return input_handled

# --- Extraction Event Mode ---

func _forward_canvas_gui_input_extraction_event_mode(event: InputEvent) -> bool:
	var input_handled: bool = false
	
	if event is InputEventMouseMotion:
		current_cursor = RESIZE_CURSORS.arrow
		if current_object.is_mouse_over_extraction_event():
			current_cursor = RESIZE_CURSORS.move
		
		var pos = current_object.get_local_mouse_position()
		update_cursor_shape()
		current_tile_pos = current_object.local_to_map(pos)
		
		if dragging_extraction_event:
			set_cursor_position()
			if cursor and is_instance_valid(cursor):
				if can_place_event_in(current_tile_pos):
					cursor.modulate = Color.WHITE
				else:
					cursor.modulate = Color("#66000044")
		
		input_handled = true
	
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.is_pressed():
			var _current_event = current_object.get_extraction_event_in(current_tile_pos)
			
			if can_place_event_in(current_tile_pos) or _current_event:
				# Double-click to create new event
				var result = add_extraction_event_in(current_tile_pos) if !_current_event and event.is_double_click() else false
				if result:
					var undo_redo = get_undo_redo()
					undo_redo.create_action("Create New Extraction Event", UndoRedo.MERGE_DISABLE, current_object)
					undo_redo.add_do_method(self, "_force_mode_switch", MODE.EXTRACTION_EVENT)
					undo_redo.add_do_method(current_object, "add_extraction_event_in", current_tile_pos)
					undo_redo.add_do_method(get_editor_interface(), "mark_scene_as_unsaved")
					undo_redo.add_do_method(extraction_event_container_control, "refresh", true)
					
					undo_redo.add_undo_method(self, "_force_mode_switch", MODE.EXTRACTION_EVENT)
					undo_redo.add_undo_method(current_object, "remove_extraction_event_in", current_tile_pos)
					undo_redo.add_undo_method(get_editor_interface(), "mark_scene_as_unsaved")
					undo_redo.add_undo_method(extraction_event_container_control, "refresh", true)
					undo_redo.add_undo_method(extraction_event_container_control, "select", -1, true, true)
					undo_redo.commit_action()
					
					call_deferred("_select_extraction_event_after_creation", current_tile_pos)
						
				elif _current_event:
					if event.is_double_click():
						show_edit_extraction_event_dialog()
					else:
						# Start dragging
						current_object.select_extraction_event(Vector2i(_current_event.x, _current_event.y))
						dragging_extraction_event = _current_event
						extraction_drag_start_pos = Vector2i(_current_event.x, _current_event.y) # Store original pos
						create_cursor()
						set_cursor_position()
						if extraction_event_container_control:
							extraction_event_container_control.select(dragging_extraction_event.id, false, true)
					current_cursor = RESIZE_CURSORS.move

			update_cursor_shape()
		
		elif dragging_extraction_event:
			# Finished dragging
			var new_pos = current_tile_pos
			var old_pos = extraction_drag_start_pos
			
			var can_place = current_object._is_place_free(new_pos) and can_place_event_in(new_pos)

			if new_pos != old_pos and can_place:
				var undo_redo = get_undo_redo()
				undo_redo.create_action("Move Extraction Event", UndoRedo.MERGE_DISABLE, current_object)
				
				# DO
				undo_redo.add_do_method(self, "_force_mode_switch", MODE.EXTRACTION_EVENT)
				undo_redo.add_do_property(dragging_extraction_event, "x", new_pos.x)
				undo_redo.add_do_property(dragging_extraction_event, "y", new_pos.y)
				undo_redo.add_do_method(current_object, "queue_redraw")
				undo_redo.add_do_method(get_editor_interface(), "mark_scene_as_unsaved")
				undo_redo.add_do_method(extraction_event_container_control, "refresh", true)
				
				# UNDO
				undo_redo.add_undo_method(self, "_force_mode_switch", MODE.EXTRACTION_EVENT)
				undo_redo.add_undo_property(dragging_extraction_event, "x", old_pos.x)
				undo_redo.add_undo_property(dragging_extraction_event, "y", old_pos.y)
				undo_redo.add_undo_method(current_object, "queue_redraw")
				undo_redo.add_undo_method(get_editor_interface(), "mark_scene_as_unsaved")
				undo_redo.add_undo_method(extraction_event_container_control, "refresh", true)
				
				undo_redo.commit_action()
					
			dragging_extraction_event = null
			destroy_cursor()
		
		input_handled = true
		
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.is_pressed():
		var pos = current_object.get_local_mouse_position()
		pos = current_object.local_to_map(pos)
		if can_place_event_in(pos):
			var ev = current_object.get_extraction_event_in(pos)
			if ev and extraction_event_container_control:
				extraction_event_container_control.select(ev.id, true, true)
			show_extraction_tile_popup_menu(event.global_position)
		input_handled = true
	elif event is InputEventKey and event.is_pressed():
		if event.keycode == KEY_ENTER:
			show_edit_extraction_event_dialog()
			input_handled = true
		elif event.is_ctrl_pressed():
			if event.keycode == KEY_C:
				copy_extraction_tile_into_clipboard()
				input_handled = true
			elif event.keycode == KEY_X:
				var event_to_cut = current_object.current_extraction_event
				if !event_to_cut:
					event_to_cut = current_object.get_extraction_event_in(current_tile_pos)
				
				if event_to_cut:
					current_tile_pos = Vector2i(event_to_cut.x, event_to_cut.y)
					_on_extraction_tile_popup_menu_index_pressed(2) # Call "Cut"
				input_handled = true
			elif event.keycode == KEY_V:
				paste_extraction_tile()
				input_handled = true
			elif event.keycode == KEY_DELETE:
				var event_to_remove = current_object.current_extraction_event
				if !event_to_remove:
					event_to_remove = current_object.get_extraction_event_in(current_tile_pos)
				
				if event_to_remove:
					current_object.current_extraction_event = event_to_remove
					current_tile_pos = Vector2i(event_to_remove.x, event_to_remove.y)
					remove_extraction_tile()
				input_handled = true
	
	return input_handled

# --- Enemy Spawn Mode ---

func _input_enemy_spawn_mode(event: InputEvent) -> void:
	if not current_object.editing_enemy_spawn_region:
		return
	_handle_region_resize_input(
		event,
		MODE.ENEMY_SPAWN, # Pass current mode
		current_object.regions,
		"current_enemy_spawn_region",
		"region_selected",
		enemy_spawn_container_control,
		"update_region"
	)


func _forward_canvas_gui_input_enemy_spawn_mode(event: InputEvent) -> bool:
	var input_handled: bool = false
	
	if event is InputEventMouseMotion:
		var pos = current_object.get_local_mouse_position()
		update_cursor_shape()
		current_tile_pos = current_object.local_to_map(pos)
		
		if dragging_enemy_spawn_region != null:
			update_drawing_region()
		elif moving_enemy_spawn_region != null:
			update_moving_region(event.position)
		
		input_handled = true
	
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.is_pressed():
			var region: EnemySpawnRegion = get_region_in(current_tile_pos)
			if can_place_event_in(current_tile_pos) or region:
				if region:
					# Start Moving
					moving_enemy_spawn_region = region.duplicate()
					current_object.current_enemy_spawn_region = moving_enemy_spawn_region
					current_object.region_selected = region
					current_object.refresh_canvas() # Shows "dim" state
					drawing_region_start_position = event.position
					current_region_position = moving_enemy_spawn_region.rect.position
					if enemy_spawn_container_control:
						enemy_spawn_container_control.select(moving_enemy_spawn_region.id, false, true)
					if event.is_double_click():
						show_edit_region_dialog()
				else:
					# Start Creating
					dragging_enemy_spawn_region = EnemySpawnRegion.new()
					current_object.current_enemy_spawn_region = dragging_enemy_spawn_region
					drawing_region_start_position = current_tile_pos
					update_drawing_region()
		
		elif dragging_enemy_spawn_region:
			# Finished Creating
			var region_to_add = dragging_enemy_spawn_region.duplicate(true)
			var region_id = region_to_add.id
			
			if region_to_add.rect.size.x > 0 and region_to_add.rect.size.y > 0:
				var undo_redo = get_undo_redo()
				undo_redo.create_action("Create Region", UndoRedo.MERGE_DISABLE, current_object)
				
				# DO
				undo_redo.add_do_method(self, "_force_mode_switch", MODE.ENEMY_SPAWN)
				undo_redo.add_do_method(current_object, "add_region", region_to_add)
				undo_redo.add_do_method(get_editor_interface(), "mark_scene_as_unsaved")
				undo_redo.add_do_method(enemy_spawn_container_control, "refresh", true)
				call_deferred("_select_region_after_creation", region_to_add)

				# UNDO
				undo_redo.add_undo_method(self, "_force_mode_switch", MODE.ENEMY_SPAWN)
				undo_redo.add_undo_method(current_object, "remove_region", region_to_add)
				undo_redo.add_undo_method(get_editor_interface(), "mark_scene_as_unsaved")
				undo_redo.add_undo_method(enemy_spawn_container_control, "refresh", true)
				undo_redo.add_undo_method(enemy_spawn_container_control, "select", -1, true, true)
				
				undo_redo.commit_action()
			
			current_object.current_enemy_spawn_region = null
			dragging_enemy_spawn_region = null
		
		elif moving_enemy_spawn_region:
			# Finished Moving
			var new_rect = moving_enemy_spawn_region.rect
			var old_rect = Rect2i(current_region_position, new_rect.size)
			
			if new_rect != old_rect:
				var region_to_move = current_object.region_selected
				
				if !region_to_move:
					push_error("RPGMapPlugin: Cannot move region, region_selected is null.")
				else:
					var region_id = region_to_move.id
					
					var undo_redo = get_undo_redo()
					undo_redo.create_action("Move Region", UndoRedo.MERGE_DISABLE, current_object)
					
					# DO
					undo_redo.add_do_method(self, "_force_mode_switch", MODE.ENEMY_SPAWN)
					undo_redo.add_do_property(region_to_move, "rect", new_rect)
					undo_redo.add_do_method(current_object, "update_region", region_to_move)
					undo_redo.add_do_method(get_editor_interface(), "mark_scene_as_unsaved")
					undo_redo.add_do_method(enemy_spawn_container_control, "select", region_id, true, true)
					
					# UNDO
					undo_redo.add_undo_method(self, "_force_mode_switch", MODE.ENEMY_SPAWN)
					undo_redo.add_undo_property(region_to_move, "rect", old_rect)
					undo_redo.add_undo_method(current_object, "update_region", region_to_move)
					undo_redo.add_undo_method(get_editor_interface(), "mark_scene_as_unsaved")
					undo_redo.add_undo_method(enemy_spawn_container_control, "select", region_id, true, true)
					
					undo_redo.commit_action()
			
			current_object.current_enemy_spawn_region = null
			moving_enemy_spawn_region = null
			current_object.refresh_canvas() # <<< BUG FIX

		input_handled = true
		
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.is_pressed():
		var pos = current_object.get_local_mouse_position()
		pos = current_object.local_to_map(pos)
		var region = current_object.get_region_in(pos)
		if region and enemy_spawn_container_control:
			enemy_spawn_container_control.select(region.id, true, true)
		show_region_popup_menu(event.global_position)
		input_handled = true
	elif event is InputEventKey and event.is_pressed():
		if event.keycode == KEY_ENTER and current_object.region_selected:
			show_edit_region_dialog()
			input_handled = true
		elif event.is_ctrl_pressed():
			if event.keycode == KEY_C:
				copy_region_into_clipboard()
				input_handled = true
			elif event.keycode == KEY_X:
				var region_to_cut = current_object.region_selected
				if !region_to_cut:
					region_to_cut = current_object.get_region_in(current_tile_pos)
				if region_to_cut:
					current_object.region_selected = region_to_cut
					_on_region_popup_menu_index_pressed(4) 
				input_handled = true
			elif event.keycode == KEY_V:
				paste_region()
				input_handled = true
			elif event.keycode == KEY_DELETE:
				var region_to_remove = current_object.region_selected
				if !region_to_remove:
					region_to_remove = current_object.get_region_in(current_tile_pos)
				if region_to_remove:
					remove_region(region_to_remove)
				input_handled = true
	
	return input_handled


func _select_region_after_creation(region: EnemySpawnRegion):
	if !current_object or !enemy_spawn_container_control:
		return
	# 'add_region' might have assigned a new ID, so we select using the object's ID
	enemy_spawn_container_control.select(region.id, true, true)


# --- Event Region Mode ---

func _input_event_region_mode(event: InputEvent) -> void:
	if not current_object.editing_event_region:
		return
	_handle_region_resize_input(
		event,
		MODE.EVENT_REGION, # Pass current mode
		current_object.event_regions,
		"current_event_region",
		"event_region_selected",
		event_region_container_control,
		"update_event_region"
	)


func _forward_canvas_gui_input_event_region_mode(event: InputEvent) -> bool:
	var input_handled: bool = false

	if event is InputEventMouseMotion:
		var pos = current_object.get_local_mouse_position()
		update_cursor_shape()
		current_tile_pos = current_object.local_to_map(pos)

		if dragging_event_region != null:
			update_drawing_event_region()
		elif moving_event_region != null:
			update_moving_event_region(event.position)
		
		input_handled = true
	
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.is_pressed():
			var region: EventRegion = get_event_region_in(current_tile_pos)
			if can_place_event_in(current_tile_pos) or region:
				if region:
					# Start Moving
					moving_event_region = region.duplicate()
					current_object.current_event_region = moving_event_region
					current_object.event_region_selected = region
					current_object.refresh_canvas() # Shows "dim" state
					drawing_region_start_position = event.position
					current_region_position = moving_event_region.rect.position
					if event_region_container_control:
						event_region_container_control.select(moving_event_region.id, false, true)
					if event.is_double_click():
						show_edit_event_region_dialog()
				else:
					# Start Creating
					dragging_event_region = EventRegion.new()
					current_object.current_event_region = dragging_event_region
					drawing_region_start_position = current_tile_pos
					update_drawing_event_region()
		
		elif dragging_event_region:
			# Finished Creating
			var region_to_add = dragging_event_region.duplicate(true)
			var region_id = region_to_add.id
			
			if region_to_add.rect.size.x > 0 and region_to_add.rect.size.y > 0:
				var undo_redo = get_undo_redo()
				undo_redo.create_action("Create Event Region", UndoRedo.MERGE_DISABLE, current_object)
				
				# DO
				undo_redo.add_do_method(self, "_force_mode_switch", MODE.EVENT_REGION)
				undo_redo.add_do_method(current_object, "add_event_region", region_to_add)
				undo_redo.add_do_method(get_editor_interface(), "mark_scene_as_unsaved")
				undo_redo.add_do_method(event_region_container_control, "refresh", true)
				call_deferred("_select_event_region_after_creation", region_to_add)

				# UNDO
				undo_redo.add_undo_method(self, "_force_mode_switch", MODE.EVENT_REGION)
				undo_redo.add_undo_method(current_object, "remove_event_region", region_to_add)
				undo_redo.add_undo_method(get_editor_interface(), "mark_scene_as_unsaved")
				undo_redo.add_undo_method(event_region_container_control, "refresh", true)
				undo_redo.add_undo_method(event_region_container_control, "select", -1, true, true)
				
				undo_redo.commit_action()

			current_object.current_event_region = null
			dragging_event_region = null
		
		elif moving_event_region:
			# Finished Moving
			var new_rect = moving_event_region.rect
			var old_rect = Rect2i(current_region_position, new_rect.size)
			
			if new_rect != old_rect:
				var region_to_move = current_object.event_region_selected
				
				if !region_to_move:
					push_error("RPGMapPlugin: Cannot move event region, event_region_selected is null.")
				else:
					var region_id = region_to_move.id
					
					var undo_redo = get_undo_redo()
					undo_redo.create_action("Move Event Region", UndoRedo.MERGE_DISABLE, current_object)
					
					# DO
					undo_redo.add_do_method(self, "_force_mode_switch", MODE.EVENT_REGION)
					undo_redo.add_do_property(region_to_move, "rect", new_rect)
					undo_redo.add_do_method(current_object, "update_event_region", region_to_move)
					undo_redo.add_do_method(get_editor_interface(), "mark_scene_as_unsaved")
					undo_redo.add_do_method(event_region_container_control, "select", region_id, true, true)
					
					# UNDO
					undo_redo.add_undo_method(self, "_force_mode_switch", MODE.EVENT_REGION)
					undo_redo.add_undo_property(region_to_move, "rect", old_rect)
					undo_redo.add_undo_method(current_object, "update_event_region", region_to_move)
					undo_redo.add_undo_method(get_editor_interface(), "mark_scene_as_unsaved")
					undo_redo.add_undo_method(event_region_container_control, "select", region_id, true, true)
					
					undo_redo.commit_action()
			
			current_object.current_event_region = null
			moving_event_region = null
			current_object.refresh_canvas() # <<< BUG FIX
		
		input_handled = true
	
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.is_pressed():
		var pos = current_object.get_local_mouse_position()
		pos = current_object.local_to_map(pos)
		var region = current_object.get_event_region_in(pos)
		if region and event_region_container_control:
			event_region_container_control.select(region.id, true, true)
		show_region_popup_menu(event.global_position)
		input_handled = true
	elif event is InputEventKey and event.is_pressed():
		if event.keycode == KEY_ENTER and current_object.event_region_selected:
			show_edit_event_region_dialog()
			input_handled = true
		elif event.is_ctrl_pressed():
			if event.keycode == KEY_C:
				copy_event_region_into_clipboard()
				input_handled = true
			elif event.keycode == KEY_X:
				var region_to_cut = current_object.event_region_selected
				if !region_to_cut:
					region_to_cut = current_object.get_event_region_in(current_tile_pos)
				if region_to_cut:
					current_object.event_region_selected = region_to_cut
					_on_region_popup_menu_index_pressed(4) 
				input_handled = true
			elif event.keycode == KEY_V:
				paste_event_region()
				input_handled = true
			elif event.keycode == KEY_DELETE:
				var region_to_remove = current_object.event_region_selected
				if !region_to_remove:
					region_to_remove = current_object.get_event_region_in(current_tile_pos)
				if region_to_remove:
					remove_event_region(region_to_remove)
				input_handled = true
	
	return input_handled


func _select_event_region_after_creation(region: EventRegion):
	if !current_object or !event_region_container_control:
		return
	event_region_container_control.select(region.id, true, true)


func is_mouse_over_start_positions() -> bool:
	var system = get_node_or_null("/root/RPGSYSTEM")
	if !system:
		return false
	var map_id = current_object.internal_id
	var ids = [
		"player_start_position",
		"land_transport_start_position",
		"sea_transport_start_position",
		"air_transport_start_position",
	]
	for id: String in ids:
		var data: RPGMapPosition = system.database.system.get(id)
		if data and data.map_id == map_id and data.position == current_tile_pos:
			return true
	
	return false


func get_start_position_under_mouse() -> RPGMapPosition:
	var system = get_node_or_null("/root/RPGSYSTEM")
	if !system:
		return null
	var map_id = current_object.internal_id
	var ids = [
		"player_start_position",
		"land_transport_start_position",
		"sea_transport_start_position",
		"air_transport_start_position",
	]
	for id: String in ids:
		var data: RPGMapPosition = system.database.system.get(id)
		if data and data.map_id == map_id and data.position == current_tile_pos:
			return data
	
	return null


func update_drawing_region() -> void:
	var top_left = Vector2i(
		min(drawing_region_start_position.x, current_tile_pos.x),
		min(drawing_region_start_position.y, current_tile_pos.y)
	)
	var bottom_right = Vector2i(
		max(drawing_region_start_position.x, current_tile_pos.x) + 1,
		max(drawing_region_start_position.y, current_tile_pos.y) + 1
	)
	
	dragging_enemy_spawn_region.rect = Rect2i(top_left, bottom_right - top_left)
	dragging_enemy_spawn_region.rect.size = dragging_enemy_spawn_region.rect.size.max(Vector2i.ONE)
	
	current_object.refresh_canvas()


func update_drawing_event_region() -> void:
	var top_left = Vector2i(
		min(drawing_region_start_position.x, current_tile_pos.x),
		min(drawing_region_start_position.y, current_tile_pos.y)
	)
	var bottom_right = Vector2i(
		max(drawing_region_start_position.x, current_tile_pos.x) + 1,
		max(drawing_region_start_position.y, current_tile_pos.y) + 1
	)
	
	dragging_event_region.rect = Rect2i(top_left, bottom_right - top_left)
	dragging_event_region.rect.size = dragging_event_region.rect.size.max(Vector2i.ONE)
	
	current_object.refresh_canvas()


func update_moving_region(pos: Vector2i) -> void:
	var viewport = EditorInterface.get_editor_viewport_2d()
	var scale = viewport.get_final_transform().y.y
	var target: Vector2i = (pos - Vector2i(drawing_region_start_position)) / scale
	var dest: Vector2i = target / current_object.tile_size
	
	moving_enemy_spawn_region.rect.position = current_region_position + dest
	
	current_object.refresh_canvas()


func update_moving_event_region(pos: Vector2i) -> void:
	var viewport = EditorInterface.get_editor_viewport_2d()
	var scale = viewport.get_final_transform().y.y
	var target: Vector2i = (pos - Vector2i(drawing_region_start_position)) / scale
	var dest: Vector2i = target / current_object.tile_size
	
	moving_event_region.rect.position = current_region_position + dest
	
	current_object.refresh_canvas()


func show_tile_popup_menu(pos: Vector2) -> void:
	if current_object:
		create_selected_cursor()
		await get_tree().process_frame
		
		current_event = current_object.get_event_in(current_tile_pos)

		if !current_event:
			tile_popup_menu.set_item_text(0, "Create New Item")
		else:
			tile_popup_menu.set_item_text(0, "Edit Item")
		
		tile_popup_menu.set_item_disabled(2, !current_event)
		tile_popup_menu.set_item_disabled(3, !current_event)
		tile_popup_menu.set_item_disabled(4, current_event != null or !StaticEditorVars.CLIPBOARD.has("event"))
		tile_popup_menu.set_item_disabled(5, !current_event)
		tile_popup_menu.set_item_disabled(7, current_event != null)
		
		var start_position_in_clipboard = StaticEditorVars.CLIPBOARD.get("start_position", {})
		var submenu: PopupMenu = tile_popup_menu.get_child(0)
		if !start_position_in_clipboard.is_empty():
			submenu.set_item_disabled(5, false)
			var start_position_name = "Paste From Clipboard (%s)" % (
				"Player" if start_position_in_clipboard == "player_start_position" else
				"land Transport" if start_position_in_clipboard == "land_transport_start_position" else
				"Sea Transport" if start_position_in_clipboard == "sea_transport_start_position" else
				"Air Transport" if start_position_in_clipboard == "air_transport_start_position" else
				""
			)
			submenu.set_item_text(5, start_position_name)
		else:
			submenu.set_item_disabled(5, true)
			
		
		if current_event:
			current_object.select_event(Vector2i(current_event.x, current_event.y))
		
		var real_pos = pos + POPUP_MENU_OFFSET
		if real_pos.x < 20:
			real_pos.x = 20
		elif real_pos.x > get_viewport().size.x - tile_popup_menu.size.x - 20:
			real_pos.x = get_viewport().size.x - tile_popup_menu.size.x - 20
		if real_pos.y < 20:
			real_pos.y = 20
		elif real_pos.y > get_viewport().size.y - tile_popup_menu.size.y - 20:
			real_pos.y = get_viewport().size.y - tile_popup_menu.size.y - 20
		tile_popup_menu.position = real_pos
		
		tile_popup_menu.show()


func show_extraction_tile_popup_menu(pos: Vector2) -> void:
	if current_object:
		create_selected_cursor()
		await get_tree().process_frame
		
		current_extraction_event = current_object.get_extraction_event_in(current_tile_pos)

		if !current_extraction_event:
			extraction_tile_popup_menu.set_item_text(0, "Create New Item")
		else:
			extraction_tile_popup_menu.set_item_text(0, "Edit Item")
		
		extraction_tile_popup_menu.set_item_disabled(2, !current_extraction_event)
		extraction_tile_popup_menu.set_item_disabled(3, !current_extraction_event)
		extraction_tile_popup_menu.set_item_disabled(4, current_extraction_event != null or !StaticEditorVars.CLIPBOARD.has("extraction_event"))
		extraction_tile_popup_menu.set_item_disabled(5, !current_extraction_event)
		extraction_tile_popup_menu.set_item_disabled(7, current_extraction_event != null)
		
		if current_extraction_event:
			current_object.select_extraction_event(Vector2i(current_extraction_event.x, current_extraction_event.y))
		
		var real_pos = pos + POPUP_MENU_OFFSET
		if real_pos.x < 20:
			real_pos.x = 20
		elif real_pos.x > get_viewport().size.x - extraction_tile_popup_menu.size.x - 20:
			real_pos.x = get_viewport().size.x - extraction_tile_popup_menu.size.x - 20
		if real_pos.y < 20:
			real_pos.y = 20
		elif real_pos.y > get_viewport().size.y - extraction_tile_popup_menu.size.y - 20:
			real_pos.y = get_viewport().size.y - extraction_tile_popup_menu.size.y - 20
		extraction_tile_popup_menu.position = real_pos
		
		extraction_tile_popup_menu.show()


func show_region_popup_menu(pos: Vector2) -> void:
	
	var region = get_region_in(current_tile_pos) if current_edit_mode == MODE.ENEMY_SPAWN else get_event_region_in(current_tile_pos)
	
	if !region:
		create_selected_cursor()
		await get_tree().process_frame
	
	var clipboard_id = "enemy_spawn_region" if current_edit_mode == MODE.ENEMY_SPAWN else "event_region"
	
	region_popup_menu.set_item_disabled(0, region == null)
	region_popup_menu.set_item_disabled(1, false)
	region_popup_menu.set_item_disabled(2, region == null)
	region_popup_menu.set_item_disabled(4, region == null)
	region_popup_menu.set_item_disabled(5, region == null)
	region_popup_menu.set_item_disabled(6, !StaticEditorVars.CLIPBOARD.has(clipboard_id) or region)
	
	var real_pos = pos + POPUP_MENU_OFFSET
	if real_pos.x < 20:
		real_pos.x = 20
	elif real_pos.x > get_viewport().size.x - region_popup_menu.size.x - 20:
		real_pos.x = get_viewport().size.x - region_popup_menu.size.x - 20
	if real_pos.y < 20:
		real_pos.y = 20
	elif real_pos.y > get_viewport().size.y - region_popup_menu.size.y - 20:
		real_pos.y = get_viewport().size.y - region_popup_menu.size.y - 20
	region_popup_menu.position = real_pos
	
	region_popup_menu.show()


func show_start_position_popup_menu(pos: Vector2) -> void:
	if current_object:
		create_selected_cursor()
		await get_tree().process_frame
		
		current_start_position = get_start_position_under_mouse()
		
		if current_event:
			current_object.select_event(Vector2i(current_event.x, current_event.y))
		
		var real_pos = pos + POPUP_MENU_OFFSET
		if real_pos.x < 20:
			real_pos.x = 20
		elif real_pos.x > get_viewport().size.x - start_position_popup_menu.size.x - 20:
			real_pos.x = get_viewport().size.x - start_position_popup_menu.size.x - 20
		if real_pos.y < 20:
			real_pos.y = 20
		elif real_pos.y > get_viewport().size.y - start_position_popup_menu.size.y - 20:
			real_pos.y = get_viewport().size.y - start_position_popup_menu.size.y - 20
		start_position_popup_menu.position = real_pos
		
		start_position_popup_menu.show()


func _on_tile_popup_menu_index_pressed(index: int) -> void:
	if !current_object:
		return
	
	var undo_redo = get_undo_redo()

	if index == 0: # Create\Edit tile
		if !current_event:
			create_new_tile()
		else:
			show_edit_event_dialog()
	
	elif index == 2: # Cut tile
		var event_to_cut = current_object.get_event_in(current_tile_pos)
		if !event_to_cut:
			return
			
		var event_copy = event_to_cut.duplicate(true)
		var event_id = event_copy.id
		var event_pos = Vector2i(event_copy.x, event_copy.y)
		
		undo_redo.create_action("Cut Event", UndoRedo.MERGE_DISABLE, current_object)
		
		# DO
		undo_redo.add_do_method(self, "_force_mode_switch", MODE.EVENT)
		undo_redo.add_do_method(self, "copy_tile_into_clipboard", event_copy)
		undo_redo.add_do_method(current_object, "remove_event_in", event_pos)
		undo_redo.add_do_method(get_editor_interface(), "mark_scene_as_unsaved")
		undo_redo.add_do_method(event_container_control, "refresh", true)
		undo_redo.add_do_method(event_container_control, "select", -1, true, true)
		
		# UNDO
		undo_redo.add_undo_method(self, "_force_mode_switch", MODE.EVENT)
		undo_redo.add_undo_method(current_object, "paste_event_in", event_pos, event_copy)
		undo_redo.add_undo_method(get_editor_interface(), "mark_scene_as_unsaved")
		undo_redo.add_undo_method(event_container_control, "refresh", true)
		undo_redo.add_undo_method(event_container_control, "select", event_id, true, true)
		
		undo_redo.commit_action()
		
	elif index == 3: # Copy tile
		copy_tile_into_clipboard()
	
	elif index == 4: # Paste tile
		paste_tile()
	
	elif index == 5: # Remove tile
		remove_tile()


func _on_extraction_tile_popup_menu_index_pressed(index: int) -> void:
	if !current_object:
		return
	
	var undo_redo = get_undo_redo()
	
	if index == 0: # Create\Edit tile
		if !current_extraction_event:
			create_new_extraction_tile()
		else:
			show_edit_extraction_event_dialog()
	
	elif index == 2: # Cut tile
		var event_to_cut = current_object.get_extraction_event_in(current_tile_pos)
		if !event_to_cut:
			return
		
		var event_copy = event_to_cut.duplicate(true)
		var event_id = event_copy.id
		var event_pos = Vector2i(event_copy.x, event_copy.y)

		undo_redo.create_action("Cut Extraction Event", UndoRedo.MERGE_DISABLE, current_object)
		
		# DO
		undo_redo.add_do_method(self, "_force_mode_switch", MODE.EXTRACTION_EVENT)
		undo_redo.add_do_method(self, "copy_extraction_tile_into_clipboard", event_copy)
		undo_redo.add_do_method(current_object, "remove_extraction_event_in", event_pos)
		undo_redo.add_do_method(get_editor_interface(), "mark_scene_as_unsaved")
		undo_redo.add_do_method(extraction_event_container_control, "refresh", true)
		undo_redo.add_do_method(extraction_event_container_control, "select", -1, true, true)
		
		# UNDO
		undo_redo.add_undo_method(self, "_force_mode_switch", MODE.EXTRACTION_EVENT)
		undo_redo.add_undo_method(current_object, "paste_extraction_event_in", event_pos, event_copy)
		undo_redo.add_undo_method(get_editor_interface(), "mark_scene_as_unsaved")
		undo_redo.add_undo_method(extraction_event_container_control, "refresh", true)
		undo_redo.add_undo_method(extraction_event_container_control, "select", event_id, true, true)
		
		undo_redo.commit_action()

	elif index == 3: # Copy tile
		copy_extraction_tile_into_clipboard()
	
	elif index == 4: # Paste tile
		paste_extraction_tile()
	
	elif index == 5: # Remove tile
		remove_extraction_tile()


func _on_tile_subpopup_menu1_index_pressed(index: int) -> void:
	if !current_object:
		return
	
	var system = get_node_or_null("/root/RPGSYSTEM")
	if !system:
		return

	var undo_redo = get_undo_redo()
	var new_map_id = current_object.internal_id
	var new_pos = current_tile_pos

	var start_pos_key: String
	var action_name: String
	
	match index:
		0: # Start Player Position
			start_pos_key = "player_start_position"
			action_name = "Set Player Start"
		1: # Start Land Transport Position
			start_pos_key = "land_transport_start_position"
			action_name = "Set Land Transport Start"
		2: # Start Sea Transport Position
			start_pos_key = "sea_transport_start_position"
			action_name = "Set Sea Transport Start"
		3: # Start Air Transport Position
			start_pos_key = "air_transport_start_position"
			action_name = "Set Air Transport Start"
		5: # Paste Start Position
			paste_start_position() # Refactored to its own function
			return
		_:
			return # Other indices don't need undo
	var data_object: RPGMapPosition = system.database.system.get(start_pos_key)
	if !data_object:
		return

	# Store old data
	var old_map_id = data_object.map_id
	var old_pos = data_object.position

	if old_map_id == new_map_id and old_pos == new_pos:
		return # No change

	undo_redo.create_action(action_name, UndoRedo.MERGE_DISABLE, current_object)

	# DO
	undo_redo.add_do_method(self, "_force_mode_switch", MODE.EVENT)
	undo_redo.add_do_property(data_object, "map_id", new_map_id)
	undo_redo.add_do_property(data_object, "position", new_pos)
	undo_redo.add_do_method(get_editor_interface(), "mark_scene_as_unsaved")
	undo_redo.add_do_method(event_container_control, "refresh", true)
	undo_redo.add_do_method(current_object, "queue_redraw")
	
	# UNDO
	undo_redo.add_undo_method(self, "_force_mode_switch", MODE.EVENT)
	undo_redo.add_undo_property(data_object, "map_id", old_map_id)
	undo_redo.add_undo_property(data_object, "position", old_pos)
	undo_redo.add_undo_method(get_editor_interface(), "mark_scene_as_unsaved")
	undo_redo.add_undo_method(event_container_control, "refresh", true)
	undo_redo.add_undo_method(current_object, "queue_redraw")
	
	undo_redo.commit_action()


func _on_preset_pressed(index: int) -> void:
	if tile_popup_menu.has_meta("_remove_index"):
		_remove_event_preset(index, tile_popup_menu.get_meta("_remove_index"))
		tile_popup_menu.remove_meta("_remove_index")
		return
	elif tile_popup_menu.has_meta("_edit_index"):
		_edit_event_preset_name(index, tile_popup_menu.get_meta("_edit_index"))
		tile_popup_menu.remove_meta("_edit_index")
		return
		
	# Get the preset path from metadata
	var sub_popup_presets = tile_popup_menu.get_child(1)
	var preset_path: String = sub_popup_presets.get_item_metadata(index)
	
	# Create event from preset
	create_tile_from_preset(preset_path)


func _remove_event_preset(index: int, preset_name: String) -> void:
	var sub_popup_presets = tile_popup_menu.get_child(1)
	var preset_path: String = sub_popup_presets.get_item_metadata(index)
	var path = "res://addons/CustomControls/Dialogs/confirm_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	
	var text = tr("Do you want to permanently delete the preset?")
	text += "\n\n[b]%s[/b]" % preset_name
	text += "\n\n[color=red][i]%s[/i][/color]" % preset_path
	
	dialog.set_text(text)
	dialog.title = TranslationManager.tr("Remove File")
	
	await dialog.tree_exiting
	
	if dialog.result:
		DirAccess.remove_absolute(preset_path)


func _edit_event_preset_name(index: int, preset_name: String) -> void:
	var sub_popup_presets = tile_popup_menu.get_child(1)
	var preset_path: String = sub_popup_presets.get_item_metadata(index)
	var preset = FileAccess.open(preset_path, FileAccess.READ).get_var(true)
	var path = "res://addons/CustomControls/Dialogs/select_text_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	dialog.title = TranslationManager.tr("Set Preset Name")
	dialog.set_text(preset.name)
	dialog.text_selected.connect(
		func(new_name: String):
			preset.name = new_name
			FileAccess.open(preset_path, FileAccess.WRITE).store_var(preset, true)
	)


func create_tile_from_preset(preset_path: String) -> void:
	if !current_object:
		return
	
	# Load the preset
	if !FileAccess.file_exists(preset_path):
		push_error("Preset file not found: ", preset_path)
		return
	
	var preset: EventPreset = FileAccess.open(preset_path, FileAccess.READ).get_var(true)
	if !preset or !preset.preset:
		push_error("Invalid preset file: ", preset_path)
		return
	
	var event_copy = preset.preset.duplicate(true)
	
	var undo_redo = get_undo_redo()
	undo_redo.create_action("Create Event from Preset", UndoRedo.MERGE_DISABLE, current_object)
	
	# DO
	undo_redo.add_do_method(self, "_force_mode_switch", MODE.EVENT)
	undo_redo.add_do_method(current_object, "paste_event_in", current_tile_pos, event_copy)
	undo_redo.add_do_method(get_editor_interface(), "mark_scene_as_unsaved")
	undo_redo.add_do_method(event_container_control, "refresh", true)
	undo_redo.add_do_method(event_container_control, "select_object", event_copy, true, true)
	
	# UNDO
	undo_redo.add_undo_method(self, "_force_mode_switch", MODE.EVENT)
	undo_redo.add_undo_method(current_object, "remove_event_in", current_tile_pos)
	undo_redo.add_undo_method(get_editor_interface(), "mark_scene_as_unsaved")
	undo_redo.add_undo_method(event_container_control, "refresh", true)
	undo_redo.add_undo_method(event_container_control, "select", -1, true, true)
	
	undo_redo.commit_action()


func _on_extraction_preset_pressed(index: int) -> void:
	if extraction_tile_popup_menu.has_meta("_remove_index"):
		_remove_extraction_event_preset(index, extraction_tile_popup_menu.get_meta("_remove_index"))
		extraction_tile_popup_menu.remove_meta("_remove_index")
		return
	elif extraction_tile_popup_menu.has_meta("_edit_index"):
		_edit_extraction_event_preset_name(index, extraction_tile_popup_menu.get_meta("_edit_index"))
		extraction_tile_popup_menu.remove_meta("_edit_index")
		return
		
	# Get the preset path from metadata
	var sub_popup_presets = extraction_tile_popup_menu.get_child(1)
	var preset_path: String = sub_popup_presets.get_item_metadata(index)
	# Create extraction event from preset
	create_extraction_tile_from_preset(preset_path)


func _remove_extraction_event_preset(index: int, preset_name: String) -> void:
	var sub_popup_presets = extraction_tile_popup_menu.get_child(1)
	var preset_path: String = sub_popup_presets.get_item_metadata(index)
	var path = "res://addons/CustomControls/Dialogs/confirm_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	
	var text = tr("Do you want to permanently delete the preset?")
	text += "\n\n[b]%s[/b]" % preset_name
	text += "\n\n[color=red][i]%s[/i][/color]" % preset_path
	
	dialog.set_text(text)
	dialog.title = TranslationManager.tr("Remove File")
	
	await dialog.tree_exiting
	
	if dialog.result:
		DirAccess.remove_absolute(preset_path)


func _edit_extraction_event_preset_name(index: int, preset_name: String) -> void:
	var sub_popup_presets = extraction_tile_popup_menu.get_child(1)
	var preset_path: String = sub_popup_presets.get_item_metadata(index)
	var preset = FileAccess.open(preset_path, FileAccess.READ).get_var(true)
	var path = "res://addons/CustomControls/Dialogs/select_text_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	dialog.title = TranslationManager.tr("Set Preset Name")
	dialog.set_text(preset.name)
	dialog.text_selected.connect(
		func(new_name: String):
			preset.name = new_name
			FileAccess.open(preset_path, FileAccess.WRITE).store_var(preset, true)
	)


func create_extraction_tile_from_preset(preset_path: String) -> void:
	if !current_object:
		return
	
	# Load the preset
	if !FileAccess.file_exists(preset_path):
		push_error("Extraction preset file not found: ", preset_path)
		return
	
	var preset: ExtractionEventPreset = FileAccess.open(preset_path, FileAccess.READ).get_var(true)
	if !preset or !preset.preset:
		push_error("Invalid extraction preset file: ", preset_path)
		return
	
	var event_copy = preset.preset.duplicate(true)
	event_copy.id = current_object._get_next_extraction_event_id()
	
	var undo_redo = get_undo_redo()
	undo_redo.create_action("Create Extraction Event from Preset", UndoRedo.MERGE_DISABLE, current_object)
	
	# DO
	undo_redo.add_do_method(self, "_force_mode_switch", MODE.EXTRACTION_EVENT)
	undo_redo.add_do_method(current_object, "paste_extraction_event_in", current_tile_pos, event_copy)
	undo_redo.add_do_method(get_editor_interface(), "mark_scene_as_unsaved")
	undo_redo.add_do_method(extraction_event_container_control, "refresh", true)
	undo_redo.add_do_method(extraction_event_container_control, "select", event_copy.id, true, true)
	
	# UNDO
	undo_redo.add_undo_method(self, "_force_mode_switch", MODE.EXTRACTION_EVENT)
	undo_redo.add_undo_method(current_object, "remove_extraction_event_in", current_tile_pos)
	undo_redo.add_undo_method(get_editor_interface(), "mark_scene_as_unsaved")
	undo_redo.add_undo_method(extraction_event_container_control, "refresh", true)
	undo_redo.add_undo_method(extraction_event_container_control, "select", -1, true, true)
	
	undo_redo.commit_action()


func _on_region_popup_menu_index_pressed(index: int) -> void:
	if !current_object:
		return

	# This function handles BOTH ENEMY_SPAWN and EVENT_REGION
	
	if current_edit_mode == MODE.ENEMY_SPAWN:
		# --- ENEMY_SPAWN (Refactored in Phase 4) ---
		if index == 0: # Edit region
			show_edit_region_dialog()
		elif index == 2: # Remove region
			remove_region(current_object.region_selected)
		elif index == 4: # Cut region
			var region_to_cut = current_object.region_selected
			if !region_to_cut:
				region_to_cut = current_object.get_region_in(current_tile_pos)
			if !region_to_cut:
				return

			var region_copy = region_to_cut.duplicate(true)
			var region_id = region_copy.id
			
			var undo_redo = get_undo_redo()
			undo_redo.create_action("Cut Region", UndoRedo.MERGE_DISABLE, current_object)
			
			# DO
			undo_redo.add_do_method(self, "_force_mode_switch", MODE.ENEMY_SPAWN)
			undo_redo.add_do_method(self, "copy_region_into_clipboard", region_copy)
			undo_redo.add_do_method(current_object, "remove_region", region_to_cut)
			undo_redo.add_do_method(get_editor_interface(), "mark_scene_as_unsaved")
			undo_redo.add_do_method(enemy_spawn_container_control, "refresh", true)
			undo_redo.add_do_method(enemy_spawn_container_control, "select", -1, true, true)
			
			# UNDO
			undo_redo.add_undo_method(self, "_force_mode_switch", MODE.ENEMY_SPAWN)
			undo_redo.add_undo_method(current_object, "paste_region_in", region_copy.rect.position, region_copy)
			undo_redo.add_undo_method(get_editor_interface(), "mark_scene_as_unsaved")
			undo_redo.add_undo_method(enemy_spawn_container_control, "refresh", true)
			undo_redo.add_undo_method(enemy_spawn_container_control, "select", region_id, true, true)
			
			undo_redo.commit_action()
			
		elif index == 5: # Copy region
			copy_region_into_clipboard()
		elif index == 6: # Paste region
			paste_region()
	else:
		# --- EVENT_REGION (Refactored now) ---
		if index == 0: # Edit region
			show_edit_event_region_dialog()
		elif index == 2: # Remove region
			remove_event_region(current_object.event_region_selected)
		elif index == 4: # Cut region
			var region_to_cut = current_object.event_region_selected
			if !region_to_cut:
				region_to_cut = current_object.get_event_region_in(current_tile_pos)
			if !region_to_cut:
				return

			var region_copy = region_to_cut.duplicate(true)
			var region_id = region_copy.id
			
			var undo_redo = get_undo_redo()
			undo_redo.create_action("Cut Event Region", UndoRedo.MERGE_DISABLE, current_object)

			# DO
			undo_redo.add_do_method(self, "_force_mode_switch", MODE.EVENT_REGION)
			undo_redo.add_do_method(self, "copy_event_region_into_clipboard", region_copy)
			undo_redo.add_do_method(current_object, "remove_event_region", region_to_cut)
			undo_redo.add_do_method(get_editor_interface(), "mark_scene_as_unsaved")
			undo_redo.add_do_method(event_region_container_control, "refresh", true)
			undo_redo.add_do_method(event_region_container_control, "select", -1, true, true)
			
			# UNDO
			undo_redo.add_undo_method(self, "_force_mode_switch", MODE.EVENT_REGION)
			undo_redo.add_undo_method(current_object, "paste_event_region_in", region_copy.rect.position, region_copy)
			undo_redo.add_undo_method(get_editor_interface(), "mark_scene_as_unsaved")
			undo_redo.add_undo_method(event_region_container_control, "refresh", true)
			undo_redo.add_undo_method(event_region_container_control, "select", region_id, true, true)
			
			undo_redo.commit_action()
			
		elif index == 5: # Copy region
			copy_event_region_into_clipboard()
		elif index == 6: # Paste region
			paste_event_region()


func _on_start_position_popup_menu_index_pressed(index: int) -> void:
	if !current_object or !current_start_position:
		return

	var undo_redo = get_undo_redo()
	
	# Store old data
	var old_map_id = current_start_position.map_id
	var old_pos = current_start_position.position
	
	if index == 0: # Cut start position
		undo_redo.create_action("Cut Start Position", UndoRedo.MERGE_DISABLE, current_object)

		# DO
		undo_redo.add_do_method(self, "_force_mode_switch", MODE.EVENT)
		undo_redo.add_do_method(self, "copy_start_position_into_clipboard")
		undo_redo.add_do_method(current_start_position, "clear")
		undo_redo.add_do_method(get_editor_interface(), "mark_scene_as_unsaved")
		undo_redo.add_do_method(event_container_control, "refresh", true)
		undo_redo.add_do_method(current_object, "queue_redraw")
		
		# UNDO
		undo_redo.add_undo_method(self, "_force_mode_switch", MODE.EVENT)
		undo_redo.add_undo_property(current_start_position, "map_id", old_map_id)
		undo_redo.add_undo_property(current_start_position, "position", old_pos)
		undo_redo.add_undo_method(get_editor_interface(), "mark_scene_as_unsaved")
		undo_redo.add_undo_method(event_container_control, "refresh", true)
		undo_redo.add_undo_method(current_object, "queue_redraw")
		
		undo_redo.commit_action()

	elif index == 1: # Copy start position
		copy_start_position_into_clipboard() # No undo/redo needed
	
	elif index == 2: # Remove start position
		undo_redo.create_action("Remove Start Position", UndoRedo.MERGE_DISABLE, current_object)

		# DO
		undo_redo.add_do_method(self, "_force_mode_switch", MODE.EVENT)
		undo_redo.add_do_method(current_start_position, "clear")
		undo_redo.add_do_method(get_editor_interface(), "mark_scene_as_unsaved")
		undo_redo.add_do_method(event_container_control, "refresh", true)
		undo_redo.add_do_method(current_object, "queue_redraw")
		
		# UNDO
		undo_redo.add_undo_method(self, "_force_mode_switch", MODE.EVENT)
		undo_redo.add_undo_property(current_start_position, "map_id", old_map_id)
		undo_redo.add_undo_property(current_start_position, "position", old_pos)
		undo_redo.add_undo_method(get_editor_interface(), "mark_scene_as_unsaved")
		undo_redo.add_undo_method(event_container_control, "refresh", true)
		undo_redo.add_undo_method(current_object, "queue_redraw")
		
		undo_redo.commit_action()
	


func copy_start_position_into_clipboard() -> void:
	if current_start_position:
		var node = get_node_or_null("/root/RPGSYSTEM")
		if node:
			var system = node.database.system
			var data: Dictionary
			var key: String
			if system.player_start_position == current_start_position:
				key = "player_start_position"
			elif system.land_transport_start_position == current_start_position:
				key = "land_transport_start_position"
			elif system.sea_transport_start_position == current_start_position:
				key = "sea_transport_start_position"
			elif system.air_transport_start_position == current_start_position:
				key = "air_transport_start_position"
			StaticEditorVars.CLIPBOARD.start_position = key
	
	destroy_selected_cursor()


func paste_start_position() -> void:
	if !current_object:
		return
		
	var start_position_key = StaticEditorVars.CLIPBOARD.get("start_position")
	if !start_position_key:
		return
	
	var system = get_node_or_null("/root/RPGSYSTEM")
	if !system:
		return
	
	var data_object: RPGMapPosition = system.database.system.get(start_position_key)
	if !data_object:
		return
		
	var new_map_id = current_object.internal_id
	var new_pos = current_tile_pos
	
	var old_map_id = data_object.map_id
	var old_pos = data_object.position
	
	if old_map_id == new_map_id and old_pos == new_pos:
		return # No change

	var undo_redo = get_undo_redo()
	undo_redo.create_action("Paste Start Position", UndoRedo.MERGE_DISABLE, current_object)
	
	# DO
	undo_redo.add_do_method(self, "_force_mode_switch", MODE.EVENT)
	undo_redo.add_do_property(data_object, "map_id", new_map_id)
	undo_redo.add_do_property(data_object, "position", new_pos)
	undo_redo.add_do_method(get_editor_interface(), "mark_scene_as_unsaved")
	undo_redo.add_do_method(event_container_control, "refresh", true)
	undo_redo.add_do_method(current_object, "queue_redraw")
	
	# UNDO
	undo_redo.add_undo_method(self, "_force_mode_switch", MODE.EVENT)
	undo_redo.add_undo_property(data_object, "map_id", old_map_id)
	undo_redo.add_undo_property(data_object, "position", old_pos)
	undo_redo.add_undo_method(get_editor_interface(), "mark_scene_as_unsaved")
	undo_redo.add_undo_method(event_container_control, "refresh", true)
	undo_redo.add_undo_method(current_object, "queue_redraw")
	
	undo_redo.commit_action()


func remove_start_position() -> void:
	# This logic is now handled in _on_start_position_popup_menu_index_pressed
	# to support UndoRedo.
	pass


func create_new_tile() -> void:
	if !current_object:
		return

	var undo_redo = get_undo_redo()
	
	undo_redo.create_action("Create New Event", UndoRedo.MERGE_DISABLE, current_object)
	
	# DO
	undo_redo.add_do_method(self, "_force_mode_switch", MODE.EVENT)
	undo_redo.add_do_method(current_object, "add_event_in", current_tile_pos)
	undo_redo.add_do_method(get_editor_interface(), "mark_scene_as_unsaved")
	undo_redo.add_do_method(event_container_control, "refresh", true)
	
	# UNDO
	undo_redo.add_undo_method(self, "_force_mode_switch", MODE.EVENT)
	undo_redo.add_undo_method(current_object, "remove_event_in", current_tile_pos)
	undo_redo.add_undo_method(get_editor_interface(), "mark_scene_as_unsaved")
	undo_redo.add_undo_method(event_container_control, "refresh", true)
	undo_redo.add_undo_method(event_container_control, "select", -1, true, true)

	undo_redo.commit_action()
	
	call_deferred("_select_event_after_creation", current_tile_pos)


func _select_event_after_creation(pos: Vector2i):
	if !current_object:
		return
	
	var event = current_object.get_event_in(pos)
	if event and event_container_control:
		event_container_control.select(event.id, true, true)
	
	current_object.select_event(pos)


func create_new_extraction_tile() -> void:
	if !current_object:
		return

	var undo_redo = get_undo_redo()
	undo_redo.create_action("Create New Extraction Event", UndoRedo.MERGE_DISABLE, current_object)
	
	# DO
	undo_redo.add_do_method(self, "_force_mode_switch", MODE.EXTRACTION_EVENT)
	undo_redo.add_do_method(current_object, "add_extraction_event_in", current_tile_pos)
	undo_redo.add_do_method(get_editor_interface(), "mark_scene_as_unsaved")
	undo_redo.add_do_method(extraction_event_container_control, "refresh", true)
	
	# UNDO
	undo_redo.add_undo_method(self, "_force_mode_switch", MODE.EXTRACTION_EVENT)
	undo_redo.add_undo_method(current_object, "remove_extraction_event_in", current_tile_pos)
	undo_redo.add_undo_method(get_editor_interface(), "mark_scene_as_unsaved")
	undo_redo.add_undo_method(extraction_event_container_control, "refresh", true)
	undo_redo.add_undo_method(extraction_event_container_control, "select", -1, true, true)

	undo_redo.commit_action()
	
	call_deferred("_select_extraction_event_after_creation", current_tile_pos)


func _select_extraction_event_after_creation(pos: Vector2i):
	if !current_object:
		return
	
	var event = current_object.get_extraction_event_in(pos)
	if event and extraction_event_container_control:
		extraction_event_container_control.select(event.id, true, true)
	
	current_object.select_extraction_event(pos)


func copy_tile_into_clipboard(default_event: RPGEvent = null) -> void:
	var event = current_object.get_event_in(current_tile_pos) if !default_event else default_event
	if event:
		StaticEditorVars.CLIPBOARD["event"] = event.clone(true)


func copy_extraction_tile_into_clipboard(default_event: RPGExtractionItem = null) -> void:
	var event = current_object.get_extraction_event_in(current_tile_pos) if !default_event else default_event
	if event:
		StaticEditorVars.CLIPBOARD["extraction_event"] = event.clone(true)


func copy_region_into_clipboard(default_region: EnemySpawnRegion = null) -> void:
	var region = current_object.region_selected if !default_region else default_region
	if region:
		StaticEditorVars.CLIPBOARD["enemy_spawn_region"] = region.clone(true)


func copy_event_region_into_clipboard(default_region: EventRegion = null) -> void:
	var region = current_object.event_region_selected if !default_region else default_region
	if region:
		StaticEditorVars.CLIPBOARD["event_region"] = region.clone(true)


func paste_tile() -> void:
	if !current_object:
		return

	var event_to_paste = StaticEditorVars.CLIPBOARD.get("event")
	if !event_to_paste:
		return
		
	var event_copy = event_to_paste.duplicate(true)
	event_copy.id = current_object.events.get_next_id()
	
	var undo_redo = get_undo_redo()

	undo_redo.create_action("Paste Event", UndoRedo.MERGE_DISABLE, current_object)

	# DO
	undo_redo.add_do_method(self, "_force_mode_switch", MODE.EVENT)
	undo_redo.add_do_method(current_object, "paste_event_in", current_tile_pos, event_copy)
	undo_redo.add_do_method(get_editor_interface(), "mark_scene_as_unsaved")
	undo_redo.add_do_method(event_container_control, "refresh", true)
	undo_redo.add_do_method(event_container_control, "select", event_copy.id, true, true)
	
	# UNDO
	undo_redo.add_undo_method(self, "_force_mode_switch", MODE.EVENT)
	undo_redo.add_undo_method(current_object, "remove_event_in", current_tile_pos)
	undo_redo.add_undo_method(get_editor_interface(), "mark_scene_as_unsaved")
	undo_redo.add_undo_method(event_container_control, "refresh", true)
	undo_redo.add_undo_method(event_container_control, "select", -1, true, true)

	undo_redo.commit_action()


func paste_extraction_tile() -> void:
	if !current_object:
		return

	var event_to_paste = StaticEditorVars.CLIPBOARD.get("extraction_event")
	if !event_to_paste:
		return
		
	var event_copy = event_to_paste.duplicate(true)
	event_copy.id = current_object._get_next_extraction_event_id()
	
	var undo_redo = get_undo_redo()
	undo_redo.create_action("Paste Extraction Event", UndoRedo.MERGE_DISABLE, current_object)

	# DO
	undo_redo.add_do_method(self, "_force_mode_switch", MODE.EXTRACTION_EVENT)
	undo_redo.add_do_method(current_object, "paste_extraction_event_in", current_tile_pos, event_copy)
	undo_redo.add_do_method(get_editor_interface(), "mark_scene_as_unsaved")
	undo_redo.add_do_method(extraction_event_container_control, "refresh", true)
	undo_redo.add_do_method(extraction_event_container_control, "select", event_copy.id, true, true)
	
	# UNDO
	undo_redo.add_undo_method(self, "_force_mode_switch", MODE.EXTRACTION_EVENT)
	undo_redo.add_undo_method(current_object, "remove_extraction_event_in", current_tile_pos)
	undo_redo.add_undo_method(get_editor_interface(), "mark_scene_as_unsaved")
	undo_redo.add_undo_method(extraction_event_container_control, "refresh", true)
	undo_redo.add_undo_method(extraction_event_container_control, "select", -1, true, true)

	undo_redo.commit_action()


func paste_region() -> void:
	if !current_object:
		return
		
	var region_to_paste = StaticEditorVars.CLIPBOARD.get("enemy_spawn_region")
	if !region_to_paste:
		return
		
	var region_copy = region_to_paste.duplicate(true)
	
	var undo_redo = get_undo_redo()
	undo_redo.create_action("Paste Region", UndoRedo.MERGE_DISABLE, current_object)
	
	# DO
	undo_redo.add_do_method(self, "_force_mode_switch", MODE.ENEMY_SPAWN)
	undo_redo.add_do_method(current_object, "paste_region_in", current_tile_pos, region_copy)
	undo_redo.add_do_method(get_editor_interface(), "mark_scene_as_unsaved")
	undo_redo.add_do_method(enemy_spawn_container_control, "refresh", true)
	undo_redo.add_do_method(enemy_spawn_container_control, "select", region_copy.id, true, true)
	
	# UNDO
	undo_redo.add_undo_method(self, "_force_mode_switch", MODE.ENEMY_SPAWN)
	# Assuming 'remove_region' can take a region object
	undo_redo.add_undo_method(current_object, "remove_region", region_copy) 
	undo_redo.add_undo_method(get_editor_interface(), "mark_scene_as_unsaved")
	undo_redo.add_undo_method(enemy_spawn_container_control, "refresh", true)
	undo_redo.add_undo_method(enemy_spawn_container_control, "select", -1, true, true)

	undo_redo.commit_action()


func paste_event_region() -> void:
	if !current_object:
		return

	var region_to_paste = StaticEditorVars.CLIPBOARD.get("event_region")
	if !region_to_paste:
		return
		
	var region_copy = region_to_paste.duplicate(true)
	
	var undo_redo = get_undo_redo()
	undo_redo.create_action("Paste Event Region", UndoRedo.MERGE_DISABLE, current_object)
	
	# DO
	undo_redo.add_do_method(self, "_force_mode_switch", MODE.EVENT_REGION)
	undo_redo.add_do_method(current_object, "paste_event_region_in", current_tile_pos, region_copy)
	undo_redo.add_do_method(get_editor_interface(), "mark_scene_as_unsaved")
	undo_redo.add_do_method(event_region_container_control, "refresh", true)
	undo_redo.add_do_method(event_region_container_control, "select", region_copy.id, true, true)
	
	# UNDO
	undo_redo.add_undo_method(self, "_force_mode_switch", MODE.EVENT_REGION)
	undo_redo.add_undo_method(current_object, "remove_event_region", region_copy)
	undo_redo.add_undo_method(get_editor_interface(), "mark_scene_as_unsaved")
	undo_redo.add_undo_method(event_region_container_control, "refresh", true)
	undo_redo.add_undo_method(event_region_container_control, "select", -1, true, true)

	undo_redo.commit_action()


func remove_tile():
	if !current_object:
		return

	var event_to_remove = current_object.current_event
	if !event_to_remove:
		event_to_remove = current_object.get_event_in(current_tile_pos)
		if !event_to_remove:
			return
	
	var event_copy = event_to_remove.duplicate(true)
	var event_id = event_copy.id
	var event_pos = Vector2i(event_copy.x, event_copy.y)

	var undo_redo = get_undo_redo()
	
	undo_redo.create_action("Remove Event", UndoRedo.MERGE_DISABLE, current_object)

	# DO
	undo_redo.add_do_method(self, "_force_mode_switch", MODE.EVENT)
	undo_redo.add_do_method(current_object, "remove_event_in", event_pos)
	undo_redo.add_do_method(get_editor_interface(), "mark_scene_as_unsaved")
	undo_redo.add_do_method(event_container_control, "refresh", true)
	undo_redo.add_do_method(event_container_control, "select", -1, true, true)
	undo_redo.add_do_method(current_object, "queue_redraw")

	# UNDO
	undo_redo.add_undo_method(self, "_force_mode_switch", MODE.EVENT)
	undo_redo.add_undo_method(current_object, "paste_event_in", event_pos, event_copy)
	undo_redo.add_undo_method(get_editor_interface(), "mark_scene_as_unsaved")
	undo_redo.add_undo_method(event_container_control, "refresh", true)
	undo_redo.add_undo_method(event_container_control, "select", event_id, true, true)
	undo_redo.add_undo_method(current_object, "queue_redraw")
	
	undo_redo.commit_action()


func remove_extraction_tile():
	if !current_object:
		return

	var event_to_remove = current_object.current_extraction_event
	if !event_to_remove:
		event_to_remove = current_object.get_extraction_event_in(current_tile_pos)
		if !event_to_remove:
			return
	
	var event_copy = event_to_remove.duplicate(true)
	var event_id = event_copy.id
	var event_pos = Vector2i(event_copy.x, event_copy.y)

	var undo_redo = get_undo_redo()
	undo_redo.create_action("Remove Extraction Event", UndoRedo.MERGE_DISABLE, current_object)

	# DO
	undo_redo.add_do_method(self, "_force_mode_switch", MODE.EXTRACTION_EVENT)
	undo_redo.add_do_method(current_object, "remove_extraction_event_in", event_pos)
	undo_redo.add_do_method(get_editor_interface(), "mark_scene_as_unsaved")
	undo_redo.add_do_method(extraction_event_container_control, "refresh", true)
	undo_redo.add_do_method(extraction_event_container_control, "select", -1, true, true)
	undo_redo.add_do_method(current_object, "queue_redraw")

	# UNDO
	undo_redo.add_undo_method(self, "_force_mode_switch", MODE.EXTRACTION_EVENT)
	undo_redo.add_undo_method(current_object, "paste_extraction_event_in", event_pos, event_copy)
	undo_redo.add_undo_method(get_editor_interface(), "mark_scene_as_unsaved")
	undo_redo.add_undo_method(extraction_event_container_control, "refresh", true)
	undo_redo.add_undo_method(extraction_event_container_control, "select", event_id, true, true)
	undo_redo.add_undo_method(current_object, "queue_redraw")
	
	undo_redo.commit_action()


func remove_region(default_region: EnemySpawnRegion = null):
	if !current_object:
		return

	var region_to_remove = default_region
	if !region_to_remove:
		region_to_remove = current_object.region_selected
	if !region_to_remove:
		region_to_remove = current_object.get_region_in(current_tile_pos)
	if !region_to_remove:
		return # Nothing to remove
	
	var region_copy = region_to_remove.duplicate(true)
	var region_id = region_copy.id
	
	var undo_redo = get_undo_redo()
	undo_redo.create_action("Remove Region", UndoRedo.MERGE_DISABLE, current_object)
	
	# DO
	undo_redo.add_do_method(self, "_force_mode_switch", MODE.ENEMY_SPAWN)
	undo_redo.add_do_method(current_object, "remove_region", region_to_remove)
	undo_redo.add_do_method(get_editor_interface(), "mark_scene_as_unsaved")
	undo_redo.add_do_method(enemy_spawn_container_control, "refresh", true)
	undo_redo.add_do_method(enemy_spawn_container_control, "select", -1, true, true)
	undo_redo.add_do_method(current_object, "queue_redraw")

	# UNDO
	undo_redo.add_undo_method(self, "_force_mode_switch", MODE.ENEMY_SPAWN)
	undo_redo.add_undo_method(current_object, "paste_region_in", region_copy.rect.position, region_copy)
	undo_redo.add_undo_method(get_editor_interface(), "mark_scene_as_unsaved")
	undo_redo.add_undo_method(enemy_spawn_container_control, "refresh", true)
	undo_redo.add_undo_method(enemy_spawn_container_control, "select", region_id, true, true)
	undo_redo.add_undo_method(current_object, "queue_redraw")
	
	undo_redo.commit_action()


func remove_event_region(default_region: EventRegion = null):
	if !current_object:
		return

	var region_to_remove = default_region
	if !region_to_remove:
		region_to_remove = current_object.event_region_selected
	if !region_to_remove:
		region_to_remove = current_object.get_event_region_in(current_tile_pos)
	if !region_to_remove:
		return # Nothing to remove
	
	var region_copy = region_to_remove.duplicate(true)
	var region_id = region_copy.id
	
	var undo_redo = get_undo_redo()
	undo_redo.create_action("Remove Event Region", UndoRedo.MERGE_DISABLE, current_object)
	
	# DO
	undo_redo.add_do_method(self, "_force_mode_switch", MODE.EVENT_REGION)
	undo_redo.add_do_method(current_object, "remove_event_region", region_to_remove)
	undo_redo.add_do_method(get_editor_interface(), "mark_scene_as_unsaved")
	undo_redo.add_do_method(event_region_container_control, "refresh", true)
	undo_redo.add_do_method(event_region_container_control, "select", -1, true, true)
	undo_redo.add_do_method(current_object, "queue_redraw")

	# UNDO
	undo_redo.add_undo_method(self, "_force_mode_switch", MODE.EVENT_REGION)
	undo_redo.add_undo_method(current_object, "paste_event_region_in", region_copy.rect.position, region_copy)
	undo_redo.add_undo_method(get_editor_interface(), "mark_scene_as_unsaved")
	undo_redo.add_undo_method(event_region_container_control, "refresh", true)
	undo_redo.add_undo_method(event_region_container_control, "select", region_id, true, true)
	undo_redo.add_undo_method(current_object, "queue_redraw")
	
	undo_redo.commit_action()


func _on_tile_popup_menu_visibility_changed() -> void:
	if !tile_popup_menu.visible:
		tile_popup_menu.set_item_disabled(8, true)
		destroy_selected_cursor()
	else:
		if tile_popup_menu.has_meta("_remove_index"): tile_popup_menu.remove_meta("_remove_index")
		if tile_popup_menu.has_meta("_edit_index"): tile_popup_menu.remove_meta("_edit_index")
		if not current_event:
			tile_popup_menu.set_item_disabled(9, false)
			_populate_event_presets_menu()
		else:
			tile_popup_menu.set_item_disabled(9, true)


func _on_extraction_tile_popup_menu_visibility_changed() -> void:
	if !extraction_tile_popup_menu.visible:
		extraction_tile_popup_menu.set_item_disabled(8, true)
		destroy_selected_cursor()
	else:
		if extraction_tile_popup_menu.has_meta("_remove_index"): extraction_tile_popup_menu.remove_meta("_remove_index")
		if extraction_tile_popup_menu.has_meta("_edit_index"): extraction_tile_popup_menu.remove_meta("_edit_index")
		if not current_extraction_event:
			extraction_tile_popup_menu.set_item_disabled(8, false)
			_populate_extraction_event_presets_menu()
		else:
			extraction_tile_popup_menu.set_item_disabled(8, true)


func _on_region_popup_menu_visibility_changed() -> void:
	if !region_popup_menu.visible:
		destroy_selected_cursor()


func show_edit_event_dialog() -> void:
	current_event = current_object.get_event_in(current_tile_pos)
	if !current_event or !current_object:
		return
	var path = "res://addons/CustomControls/Dialogs/edit_event_dialog.tscn"
	
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	dialog.resource_previewer = EditorInterface.get_resource_previewer()
	dialog.undo_redo = get_undo_redo()
	dialog.current_object = current_object
	dialog.plugin = self
	dialog.set_event(current_event)
	dialog.set_events(current_object.events)
	dialog.changed.connect(get_editor_interface().mark_scene_as_unsaved)
	dialog.size_changed.connect(_on_dialog_size_changed.bind(path, dialog))
	dialog.tree_exited.connect(_on_dialog_tree_exited)
	dialog.tree_exiting.connect(
		func():
			FileCache.options.edit_event_dialog = {"position": dialog.position, "size": dialog.size}
	)
	
	dialog.setup()

	var state = FileCache.options.get("edit_event_dialog", null)
	if !state:
		var s = Vector2i(DisplayServer.screen_get_size() * 0.85)
		dialog.size = s
		dialog.position = DisplayServer.screen_get_size() / 2 - dialog.size / 2
	else:
		dialog.size = state.size
		dialog.position = state.position


func _on_dialog_tree_exited() -> void:
	if event_container_control:
		event_container_control.refresh(true)


func _on_dialog_size_changed(path: String, dialog: Window) -> void:
	dialog_sizes[path] = dialog.size


func show_edit_extraction_event_dialog() -> void:
	current_extraction_event = current_object.get_extraction_event_in(current_tile_pos)
	if !current_extraction_event or !current_object:
		return
	var path = "res://addons/CustomControls/Dialogs/edit_extraction_event_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	dialog.resource_previewer = EditorInterface.get_resource_previewer()
	dialog.undo_redo = get_undo_redo()
	dialog.current_object = current_object
	dialog.plugin = self
	dialog.set_event(current_extraction_event)
	dialog.set_events(current_object.extraction_events)
	dialog.changed.connect(get_editor_interface().mark_scene_as_unsaved)
	dialog.size_changed.connect(_on_extraction_event_dialog_size_changed.bind(path, dialog))
	dialog.tree_exited.connect(_on_extraction_event_dialog_tree_exited)
	dialog.tree_exiting.connect(
		func():
			FileCache.options.edit_event_dialog = {"position": dialog.position, "size": dialog.size}
	)
	
	dialog.setup()


	var state = FileCache.options.get("edit_extraction_event_dialog", null)
	if !state:
		var s = Vector2i(DisplayServer.screen_get_size() * 0.85)
		dialog.position = DisplayServer.screen_get_size() / 2 - dialog.size / 2
	else:
		dialog.position = state.position


func _on_extraction_event_dialog_tree_exited() -> void:
	if extraction_event_container_control:
		extraction_event_container_control.refresh(true)


func _on_extraction_event_dialog_size_changed(path: String, dialog: Window) -> void:
	dialog_sizes[path] = dialog.size


func show_edit_region_dialog() -> void:
	current_enemy_spawn_region = current_object.region_selected
	if !current_enemy_spawn_region or !current_object:
		return
	var path = "res://addons/CustomControls/Dialogs/edit_enemy_spawn_region_dialog.tscn"
	
	var dialog_size = null
	if dialog_sizes.has(path):
		dialog_size = dialog_sizes[path]
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE, dialog_size)
	dialog.undo_redo = get_undo_redo()
	dialog.current_object = current_object
	dialog.plugin = self
	dialog.region_changed.connect(_on_region_changed_in_dialog)
	dialog.size_changed.connect(_on_region_dialog_size_changed.bind(path, dialog))
	dialog.tree_exited.connect(_on_region_dialog_tree_exited)

	dialog.set_region(current_enemy_spawn_region)


func _on_region_changed_in_dialog(_region: EnemySpawnRegion) -> void:
	get_editor_interface().mark_scene_as_unsaved()
	current_object.refresh_canvas()
	current_object.property_list_changed.emit()


func _on_region_dialog_tree_exited() -> void:
	moving_enemy_spawn_region = null
	current_object.current_enemy_spawn_region = null
	if enemy_spawn_container_control:
		enemy_spawn_container_control.refresh(true)


func _on_region_dialog_size_changed(path: String, dialog: Window) -> void:
	dialog_sizes[path] = dialog.size


func show_edit_event_region_dialog() -> void:
	current_event_region = current_object.event_region_selected
	if !current_event_region or !current_object:
		return
	var path = "res://addons/CustomControls/Dialogs/edit_event_region_dialog.tscn"
	
	var dialog_size = null
	if dialog_sizes.has(path):
		dialog_size = dialog_sizes[path]
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE, dialog_size)
	dialog.undo_redo = get_undo_redo()
	dialog.current_object = current_object
	dialog.plugin = self
	dialog.region_changed.connect(_on_event_region_changed_in_dialog)
	dialog.size_changed.connect(_on_event_region_dialog_size_changed.bind(path, dialog))
	dialog.tree_exited.connect(_on_event_region_dialog_tree_exited)

	dialog.set_events(current_object.events.get_events())
	dialog.set_region(current_event_region)


func _on_event_region_changed_in_dialog(_region: EventRegion) -> void:
	get_editor_interface().mark_scene_as_unsaved()
	current_object.refresh_canvas()
	current_object.property_list_changed.emit()


func _on_event_region_dialog_tree_exited() -> void:
	moving_event_region = null
	current_object.current_event_region = null
	if event_region_container_control and event_region_container_control.visible:
		event_region_container_control.refresh(true)


func _on_event_region_dialog_size_changed(path: String, dialog: Window) -> void:
	dialog_sizes[path] = dialog.size


func re_focus_dialog(dialog: Window) -> void:
	dialog.request_attention()
	await get_tree().process_frame
	dialog.grab_focus()


func create_cursor() -> void:
	cursor = preload("res://addons/RPGMap/Scenes/tilemap_cursor.tscn").instantiate()
	cursor.size = current_object.tile_size + Vector2i(2, 2)
	current_object.add_child(cursor)


func _on_start_position_popup_menu_visibility_changed() -> void:
	if !start_position_popup_menu.visible:
		destroy_selected_cursor()


func create_selected_cursor() -> void:
	if selected_cursor and is_instance_valid(selected_cursor):
		selected_cursor.queue_free()
	
	selected_cursor = preload("res://addons/RPGMap/Scenes/tilemap_cursor_selected.tscn").instantiate()
	selected_cursor.size = current_object.tile_size + Vector2i(2, 2)
	current_object.add_child(selected_cursor)
	var pos = Vector2i(current_object.map_to_local(current_tile_pos)) - Vector2i.ONE
	selected_cursor.position = pos


func set_cursor_position() -> void:
	if cursor and is_instance_valid(cursor):
		var pos = Vector2i(current_object.map_to_local(current_tile_pos)) - Vector2i.ONE
		cursor.position = pos


func destroy_cursor() -> void:
	if cursor and is_instance_valid(cursor):
		cursor.queue_free()


func destroy_selected_cursor() -> void:
	if selected_cursor and is_instance_valid(selected_cursor):
		selected_cursor.queue_free()
		selected_cursor = null


func add_event_in(pos: Vector2i) -> bool:
	var result = current_object.add_event_in(pos)
	return result


func add_extraction_event_in(pos: Vector2i) -> bool:
	var result = current_object.add_extraction_event_in(pos)
	return result


func get_region_in(pos: Vector2i) -> EnemySpawnRegion:
	var region = current_object.get_region_in(pos)
	return region


func get_event_region_in(pos: Vector2i) -> EventRegion:
	var region = current_object.get_event_region_in(pos)
	return region


func can_place_event_in(pos: Vector2i) -> bool:
	if current_object:
		var system = get_node_or_null("/root/RPGSYSTEM")
		if system:
			var map_id = current_object.internal_id
			var ids = [
				"player_start_position",
				"land_transport_start_position",
				"sea_transport_start_position",
				"air_transport_start_position",
			]
			for id in ids:
				var data: RPGMapPosition = system.database.system.get(id)
				if data and data.map_id == map_id and data.position == current_tile_pos:
					return false
		
		var extra_margin = 5
		var used_rect = current_object.get_used_rect()

		var real_position = current_object.map_to_local(pos)
		
		return used_rect.has_point(real_position)
	
	return false


func get_preview(scene: String, receiver: Object, function: StringName, userdata: Variant = null) -> void:
	scene_preview.queue_resource_preview(scene, receiver, function, userdata)


func _force_mode_switch(mode_to_force: MODE) -> void:
	# This function forces the UI to switch to a specific mode.
	# We set other buttons to false first to avoid multiple signals.
	if mode_to_force != MODE.EVENT:
		event_button.set_pressed(false)
	if mode_to_force != MODE.EXTRACTION_EVENT:
		extraction_event_button.set_pressed(false)
	if mode_to_force != MODE.ENEMY_SPAWN:
		enemy_spawn_region_button.set_pressed(false)
	if mode_to_force != MODE.EVENT_REGION:
		event_region_button.set_pressed(false)
	
	# Now press the correct one. Its 'toggled' signal will fire.
	match mode_to_force:
		MODE.EVENT:
			if !event_button.is_pressed():
				event_button.set_pressed(true)
		MODE.EXTRACTION_EVENT:
			if !extraction_event_button.is_pressed():
				extraction_event_button.set_pressed(true)
		MODE.ENEMY_SPAWN:
			if !enemy_spawn_region_button.is_pressed():
				enemy_spawn_region_button.set_pressed(true)
		MODE.EVENT_REGION:
			if !event_region_button.is_pressed():
				event_region_button.set_pressed(true)


func _save_external_data() -> void:
	#var rpg_map_info = get_node_or_null("/root/RPGMapsInfo")
	#if rpg_map_info:
		#var opened_maps: Array = []
		#var interface = get_editor_interface()
		#var current_opened_scenes = interface.get_open_scenes()
		#var resource_filesystem = interface.get_resource_filesystem()
		#for path in current_opened_scenes:
			#opened_maps.append(path)
		#
		#rpg_map_info.fix_maps(opened_maps)
		
	var system = get_node_or_null("/root/RPGSYSTEM")
	if system:
		system.save()
