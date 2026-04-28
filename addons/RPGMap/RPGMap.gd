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


var events_dock: EditorDock
var extraction_events_dock: EditorDock
var enemy_spawn_regions_dock: EditorDock
var event_regions_dock: EditorDock
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

var floating_panel: PanelContainer
var floating_buttons: Array[Button] = []
var is_in_2d_screen: bool = false
var _current_floating_state: bool = false
var is_dragging_floating_panel: bool = false
var floating_panel_drag_offset: Vector2 = Vector2.ZERO

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

var hot_reload_udp := PacketPeerUDP.new()
var target_port := 4242
var target_ip := "127.0.0.1"

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
		"show_regions": true
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
		"show_regions": true
	}
}

var initialize_state: int = 0


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


func _create_editor_dock(title: String, content: Control) -> EditorDock:
	var dock = EditorDock.new()
	
	dock.name = title
	dock.title = title
	dock.default_slot = EditorDock.DOCK_SLOT_BOTTOM
	dock.available_layouts = EditorDock.DOCK_LAYOUT_HORIZONTAL
	dock.focus_entered.connect(func(): print("selected ", title))
	dock.focus_exited.connect(func(): print("unselected ", title))
	dock.add_child(content)
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	return dock


func _init_project_settings() -> void:
	if not ProjectSettings.has_setting("godot_rpg_creator/interface/use_floating_ui"):
		ProjectSettings.set_setting("godot_rpg_creator/interface/use_floating_ui", false)
		ProjectSettings.set_initial_value("godot_rpg_creator/interface/use_floating_ui", false)
		
	ProjectSettings.add_property_info({
		"name": "godot_rpg_creator/interface/use_floating_ui",
		"type": TYPE_BOOL,
		"hint": PROPERTY_HINT_NONE,
		"hint_string": ""
	})
	
	if not ProjectSettings.has_setting("godot_rpg_creator/interface/floating_ui_layout"):
		ProjectSettings.set_setting("godot_rpg_creator/interface/floating_ui_layout", {"corner": 0, "offset": Vector2(25, 80)})
		ProjectSettings.set_initial_value("godot_rpg_creator/interface/floating_ui_layout", {"corner": 0, "offset": Vector2(25, 80)})
		
	ProjectSettings.add_property_info({
		"name": "godot_rpg_creator/interface/floating_ui_layout",
		"type": TYPE_DICTIONARY,
		"hint": PROPERTY_HINT_NONE,
		"hint_string": ""
	})


func _on_settings_changed() -> void:
	var new_state = ProjectSettings.get_setting("godot_rpg_creator/interface/use_floating_ui", false)
	
	if new_state != _current_floating_state:
		var previous_mode = current_edit_mode
		
		_current_floating_state = new_state
		_apply_ui_mode()
		
		if previous_mode != MODE.NONE:
			_force_mode_switch(previous_mode)


func _apply_ui_mode() -> void:
	_ensure_containers_exist()
	
	if _current_floating_state:
		_destroy_docks()
	else:
		_create_docks()
		
	_update_floating_toolbar_visibility()


func _ensure_containers_exist() -> void:
	if not is_instance_valid(event_container_control):
		event_container_control = preload("res://addons/RPGMap/Scenes/event_container.tscn").instantiate()
		event_container_control.requested_edit_event.connect(_on_event_container_requested_edit)
		event_container_control.requested_remove_event.connect(_on_event_container_requested_remove)
		event_container_control.item_selected.connect(_on_event_container_item_selected)
		event_container_control.detach_panel.connect(_on_detach_event_container_control)
		event_container_control.enable_plugin()
		event_container_control.visibility_changed.connect(_set_custom_tooltip.bind(event_container_control))
		
	if not is_instance_valid(extraction_event_container_control):
		extraction_event_container_control = preload("res://addons/RPGMap/Scenes/extraction_event_container.tscn").instantiate()
		extraction_event_container_control.requested_edit_event.connect(_on_extraction_event_container_requested_edit)
		extraction_event_container_control.requested_remove_event.connect(_on_extraction_event_container_requested_remove)
		extraction_event_container_control.item_selected.connect(_on_extraction_event_container_item_selected)
		extraction_event_container_control.detach_panel.connect(_on_detach_extraction_event_container_control)
		extraction_event_container_control.enable_plugin()
		extraction_event_container_control.visibility_changed.connect(_set_custom_tooltip.bind(extraction_event_container_control))
		
	if not is_instance_valid(enemy_spawn_container_control):
		enemy_spawn_container_control = preload("res://addons/RPGMap/Scenes/enemy_spawn_region_container.tscn").instantiate()
		enemy_spawn_container_control.requested_edit_region.connect(_on_enemy_spawn_region_container_requested_edit)
		enemy_spawn_container_control.requested_remove_region.connect(_on_enemy_spawn_region_container_requested_remove)
		enemy_spawn_container_control.item_selected.connect(_on_enemy_spawn_region_container_item_selected)
		enemy_spawn_container_control.detach_panel.connect(_on_detach_enemy_spawn_container_control)
		enemy_spawn_container_control.enable_plugin()
		enemy_spawn_container_control.visibility_changed.connect(_set_custom_tooltip.bind(enemy_spawn_container_control))
		
	if not is_instance_valid(event_region_container_control):
		event_region_container_control = preload("res://addons/RPGMap/Scenes/event_region_container.tscn").instantiate()
		event_region_container_control.requested_edit_region.connect(_on_region_event_container_requested_edit)
		event_region_container_control.requested_remove_region.connect(_on_region_event_container_requested_remove)
		event_region_container_control.item_selected.connect(_on_region_event_container_item_selected)
		event_region_container_control.detach_panel.connect(_on_detach_region_event_container_control)
		event_region_container_control.enable_plugin()
		event_region_container_control.visibility_changed.connect(_set_custom_tooltip.bind(event_region_container_control))


func _destroy_docks() -> void:
	if events_dock:
		if events_dock.get_parent():
			remove_dock(events_dock)
			
		if is_instance_valid(event_container_control) and event_container_control.get_parent() == events_dock:
			events_dock.remove_child(event_container_control)
			
		events_dock.queue_free()
		events_dock = null
		
	if extraction_events_dock:
		if extraction_events_dock.get_parent():
			remove_dock(extraction_events_dock)
			
		if is_instance_valid(extraction_event_container_control) and extraction_event_container_control.get_parent() == extraction_events_dock:
			extraction_events_dock.remove_child(extraction_event_container_control)
			
		extraction_events_dock.queue_free()
		extraction_events_dock = null
		
	if enemy_spawn_regions_dock:
		if enemy_spawn_regions_dock.get_parent():
			remove_dock(enemy_spawn_regions_dock)
			
		if is_instance_valid(enemy_spawn_container_control) and enemy_spawn_container_control.get_parent() == enemy_spawn_regions_dock:
			enemy_spawn_regions_dock.remove_child(enemy_spawn_container_control)
			
		enemy_spawn_regions_dock.queue_free()
		enemy_spawn_regions_dock = null
		
	if event_regions_dock:
		if event_regions_dock.get_parent():
			remove_dock(event_regions_dock)
			
		if is_instance_valid(event_region_container_control) and event_region_container_control.get_parent() == event_regions_dock:
			event_regions_dock.remove_child(event_region_container_control)
			
		event_regions_dock.queue_free()
		event_regions_dock = null


func _create_docks() -> void:
	if not is_instance_valid(events_dock):
		events_dock = _create_editor_dock("Events", event_container_control)
		add_dock(events_dock)
		events_dock.visibility_changed.connect(_on_events_dock_visibility_changed)
		
	if not is_instance_valid(extraction_events_dock):
		extraction_events_dock = _create_editor_dock("Extraction Events", extraction_event_container_control)
		add_dock(extraction_events_dock)
		extraction_events_dock.visibility_changed.connect(_on_extraction_events_dock_visibility_changed)
		
	if not is_instance_valid(enemy_spawn_regions_dock):
		enemy_spawn_regions_dock = _create_editor_dock("Enemy Spawn Regions", enemy_spawn_container_control)
		add_dock(enemy_spawn_regions_dock)
		enemy_spawn_regions_dock.visibility_changed.connect(_on_enemy_spawn_regions_dock_visibility_changed)
		
	if not is_instance_valid(event_regions_dock):
		event_regions_dock = _create_editor_dock("Event Regions", event_region_container_control)
		add_dock(event_regions_dock)
		event_regions_dock.visibility_changed.connect(_on_event_regions_dock_visibility_changed)


func _setup_floating_toolbar() -> void:
	if floating_panel:
		return
		
	var vbox = VBoxContainer.new()
	var style = StyleBoxFlat.new()
	
	style.bg_color = Color(0.15, 0.15, 0.15, 0.8)
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_left = 5
	style.corner_radius_bottom_right = 5
	style.content_margin_left = 5
	style.content_margin_right = 5
	style.content_margin_top = 5
	style.content_margin_bottom = 5
	
	floating_panel = PanelContainer.new()
	
	floating_panel.add_theme_stylebox_override("panel", style)
	floating_panel.add_child(vbox)
	floating_panel.z_index = 100
	floating_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	floating_panel.visible = false
	
	var drag_handle = HSeparator.new()
	
	drag_handle.mouse_filter = Control.MOUSE_FILTER_STOP
	drag_handle.mouse_default_cursor_shape = Control.CURSOR_DRAG
	
	var handle_style = StyleBoxLine.new()
	
	handle_style.color = Color(0.5, 0.5, 0.5, 0.8)
	handle_style.thickness = 4
	drag_handle.add_theme_stylebox_override("separator", handle_style)
	vbox.add_child(drag_handle)
	
	floating_panel.set_meta("drag_handle", drag_handle)
	
	var btn_events = Button.new()
	
	btn_events.text = "Events"
	btn_events.toggle_mode = true
	btn_events.mouse_filter = Control.MOUSE_FILTER_STOP
	btn_events.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn_events.toggled.connect(_on_event_button_toggled)
	vbox.add_child(btn_events)
	floating_buttons.append(btn_events)
	
	var btn_extraction = Button.new()
	
	btn_extraction.text = "Extraction"
	btn_extraction.toggle_mode = true
	btn_extraction.mouse_filter = Control.MOUSE_FILTER_STOP
	btn_extraction.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn_extraction.toggled.connect(_on_extraction_event_button_toggled)
	vbox.add_child(btn_extraction)
	floating_buttons.append(btn_extraction)
	
	var btn_enemy = Button.new()
	
	btn_enemy.text = "Enemy Spawns"
	btn_enemy.toggle_mode = true
	btn_enemy.mouse_filter = Control.MOUSE_FILTER_STOP
	btn_enemy.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn_enemy.toggled.connect(_on_enemy_spawn_region_button_toggled)
	vbox.add_child(btn_enemy)
	floating_buttons.append(btn_enemy)
	
	var btn_region = Button.new()
	
	btn_region.text = "Event Regions"
	btn_region.toggle_mode = true
	btn_region.mouse_filter = Control.MOUSE_FILTER_STOP
	btn_region.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn_region.toggled.connect(_on_event_region_button_toggled)
	vbox.add_child(btn_region)
	floating_buttons.append(btn_region)
	
	var viewport = EditorInterface.get_editor_viewport_2d()
	
	if viewport:
		var parent = viewport.get_parent()
		parent.add_child(floating_panel)
		if not parent.resized.is_connected(_on_viewport_parent_resized):
			parent.resized.connect(_on_viewport_parent_resized)


func _on_viewport_parent_resized() -> void:
	_apply_corner_position()


func _apply_corner_position() -> void:
	if not is_instance_valid(floating_panel) or not floating_panel.get_parent():
		return
		
	var parent_size = floating_panel.get_parent().size
	if parent_size.x == 0 or parent_size.y == 0:
		return
		
	var layout = ProjectSettings.get_setting("godot_rpg_creator/interface/floating_ui_layout", {"corner": 0, "offset": Vector2(25, 80)})
	
	if typeof(layout) != TYPE_DICTIONARY:
		layout = {"corner": 0, "offset": Vector2(25, 80)}
		
	var corner: int = layout.get("corner", 0)
	var offset: Vector2 = layout.get("offset", Vector2(25, 80))
	var target_pos = Vector2.ZERO
	var panel_size = floating_panel.size
	
	match corner:
		0:
			target_pos = offset
		1:
			target_pos = Vector2(parent_size.x - panel_size.x - offset.x, offset.y)
		2:
			target_pos = Vector2(offset.x, parent_size.y - panel_size.y - offset.y)
		3:
			target_pos = Vector2(parent_size.x - panel_size.x - offset.x, parent_size.y - panel_size.y - offset.y)
			
	floating_panel.position = target_pos
	_clamp_floating_panel_position(false)


func _process_floating_ui_input(event: InputEvent, local_pos: Vector2) -> bool:
	if is_dragging_floating_panel:
		if event is InputEventMouseMotion:
			floating_panel.position += event.relative
			_clamp_floating_panel_position(false)
			return true
		elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.is_pressed():
			is_dragging_floating_panel = false
			_clamp_floating_panel_position(true)
			ProjectSettings.save()
			return true
			
	var drag_handle = floating_panel.get_meta("drag_handle")
	var handle_pos = drag_handle.get_parent().position + drag_handle.position
	var handle_rect = Rect2(handle_pos, drag_handle.size)
	
	if event is InputEventMouseMotion:
		var over_button: bool = false
		var hovered_btn = null
		
		for btn in floating_buttons:
			var btn_local = btn.get_local_mouse_position()
			
			if Rect2(Vector2.ZERO, btn.size).has_point(btn_local):
				over_button = true
				hovered_btn = btn
				break
				
		for btn in floating_buttons:
			if btn == hovered_btn:
				btn.modulate = Color(1.3, 1.3, 1.3, 1.0)
			else:
				btn.modulate = Color(1.0, 1.0, 1.0, 1.0)
				
		if over_button:
			current_cursor = Control.CURSOR_POINTING_HAND
		elif handle_rect.has_point(local_pos):
			current_cursor = Control.CURSOR_DRAG
		else:
			current_cursor = Control.CURSOR_ARROW
			
		update_cursor_shape()
		
		return true
		
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
		if handle_rect.has_point(local_pos):
			is_dragging_floating_panel = true
			return true
			
		for i in range(floating_buttons.size()):
			var btn = floating_buttons[i]
			var btn_local = btn.get_local_mouse_position()
			
			if Rect2(Vector2.ZERO, btn.size).has_point(btn_local):
				if not btn.button_pressed:
					for j in range(floating_buttons.size()):
						if i != j:
							floating_buttons[j].set_pressed_no_signal(false)
							floating_buttons[j].modulate = Color(1.0, 1.0, 1.0, 1.0)
							
					EditorInterface.inspect_object(null)
					btn.set_pressed(true)
				break
				
		return true
		
	return false


func _on_floating_panel_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.is_pressed():
			is_dragging_floating_panel = true
		else:
			is_dragging_floating_panel = false
			_clamp_floating_panel_position(true)
			ProjectSettings.save()
	elif event is InputEventMouseMotion and is_dragging_floating_panel:
		floating_panel.position += event.relative
		_clamp_floating_panel_position(false)


func _clamp_floating_panel_position(save_layout: bool = false) -> void:
	if not is_instance_valid(floating_panel) or not floating_panel.get_parent():
		return
		
	var parent_size = floating_panel.get_parent().size
	if parent_size.x == 0 or parent_size.y == 0:
		return
		
	var panel_size = floating_panel.size
	var margin = 20.0
	
	var new_pos = floating_panel.position
	new_pos.x = clamp(new_pos.x, margin, max(margin, parent_size.x - panel_size.x - margin))
	new_pos.y = clamp(new_pos.y, margin, max(margin, parent_size.y - panel_size.y - margin))
	
	floating_panel.position = new_pos
	
	if save_layout:
		var dist_tl = new_pos.length_squared()
		var dist_tr = Vector2(parent_size.x - (new_pos.x + panel_size.x), new_pos.y).length_squared()
		var dist_bl = Vector2(new_pos.x, parent_size.y - (new_pos.y + panel_size.y)).length_squared()
		var dist_br = Vector2(parent_size.x - (new_pos.x + panel_size.x), parent_size.y - (new_pos.y + panel_size.y)).length_squared()
		
		var min_dist = min(min(dist_tl, dist_tr), min(dist_bl, dist_br))
		var corner = 0
		var offset = new_pos
		
		if min_dist == dist_tr:
			corner = 1
			offset = Vector2(parent_size.x - (new_pos.x + panel_size.x), new_pos.y)
		elif min_dist == dist_bl:
			corner = 2
			offset = Vector2(new_pos.x, parent_size.y - (new_pos.y + panel_size.y))
		elif min_dist == dist_br:
			corner = 3
			offset = Vector2(parent_size.x - (new_pos.x + panel_size.x), parent_size.y - (new_pos.y + panel_size.y))
			
		ProjectSettings.set_setting("godot_rpg_creator/interface/floating_ui_layout", {"corner": corner, "offset": offset})


func _on_editor_selection_changed() -> void:
	if busy:
		return
		
	var selected_nodes = get_editor_interface().get_selection().get_selected_nodes()
	
	if selected_nodes.size() > 0 and selected_nodes[0] == current_object:
		var inspector = EditorInterface.get_inspector()
		
		if inspector and inspector.get_edited_object() != current_object:
			busy = true
			#EditorInterface.edit_node(current_object)
			busy = false


func _enter_tree() -> void:
	tree_exiting.connect(_tree_exiting)
	main_screen_changed.connect(_on_main_screen_changed)
	ProjectSettings.settings_changed.connect(_on_settings_changed)
	
	var selection = get_editor_interface().get_selection()
	
	if not selection.selection_changed.is_connected(_on_editor_selection_changed):
		selection.selection_changed.connect(_on_editor_selection_changed)
		
	_init_project_settings()
	_current_floating_state = ProjectSettings.get_setting("godot_rpg_creator/interface/use_floating_ui", false)
	
	is_in_2d_screen = false
	
	_setup_floating_toolbar()
	
	_apply_ui_mode()
	
	var selected_nodes = get_editor_interface().get_selection().get_selected_nodes()
	
	if selected_nodes.size() > 0:
		var first_node = selected_nodes[0]
		var buttons_visibility: bool = first_node is RPGMap and first_node.get("can_add_events") == true
		
		if not _current_floating_state:
			if is_instance_valid(events_dock): events_dock.visible = buttons_visibility
			if is_instance_valid(extraction_events_dock): extraction_events_dock.visible = buttons_visibility
			if is_instance_valid(enemy_spawn_regions_dock): enemy_spawn_regions_dock.visible = buttons_visibility
			if is_instance_valid(event_regions_dock): event_regions_dock.visible = buttons_visibility
	else:
		if not _current_floating_state:
			if is_instance_valid(events_dock): events_dock.visible = false
			if is_instance_valid(extraction_events_dock): extraction_events_dock.visible = false
			if is_instance_valid(enemy_spawn_regions_dock): enemy_spawn_regions_dock.visible = false
			if is_instance_valid(event_regions_dock): event_regions_dock.visible = false
			
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
	
	DETACHABLE_WINDOW = load("res://addons/CustomControls/detachable_window.tscn")
	
	if selected_nodes.size() > 0:
		var first_node = selected_nodes[0]
		
		if first_node is RPGMap:
			get_editor_interface().call_deferred("edit_node", first_node)


func _disable_plugin() -> void:
	var selection = get_editor_interface().get_selection().get_selected_nodes()
	
	if selection.size() > 0:
		get_editor_interface().edit_node(selection[0])
	else:
		get_editor_interface().inspect_object(null)


func _on_main_screen_changed(screen_name: String) -> void:
	is_in_2d_screen = (screen_name == "2D")
	_update_floating_toolbar_visibility()


func _update_floating_toolbar_visibility() -> void:
	if floating_panel:
		var viewport = EditorInterface.get_editor_viewport_2d()
		
		if viewport and not floating_panel.is_inside_tree():
			var parent = viewport.get_parent()
			parent.add_child(floating_panel)
			if not parent.resized.is_connected(_on_viewport_parent_resized):
				parent.resized.connect(_on_viewport_parent_resized)
				
		floating_panel.visible = _current_floating_state and is_in_2d_screen and current_object != null
		
		if floating_panel.visible:
			_apply_corner_position.call_deferred()


func _set_custom_tooltip(container: Control) -> void:
	if container.visible:
		CustomTooltipManager.plugin_replace_all_tooltips_with_custom(container)


func _on_events_dock_visibility_changed() -> void:
	if initialize_state < 2:
		return
		
	if not _current_floating_state and is_instance_valid(events_dock):
		if events_dock.visible and current_edit_mode != MODE.EVENT:
			_on_event_button_toggled(true)
		elif not events_dock.visible and current_edit_mode == MODE.EVENT:
			_on_event_button_toggled(false)


func _on_extraction_events_dock_visibility_changed() -> void:
	if initialize_state < 2:
		return
		
	if not _current_floating_state and is_instance_valid(extraction_events_dock):
		if extraction_events_dock.visible and current_edit_mode != MODE.EXTRACTION_EVENT:
			_on_extraction_event_button_toggled(true)
		elif not extraction_events_dock.visible and current_edit_mode == MODE.EXTRACTION_EVENT:
			_on_extraction_event_button_toggled(false)


func _on_enemy_spawn_regions_dock_visibility_changed() -> void:
	if initialize_state < 2:
		return
		
	if not _current_floating_state and is_instance_valid(enemy_spawn_regions_dock):
		if enemy_spawn_regions_dock.visible and current_edit_mode != MODE.ENEMY_SPAWN:
			_on_enemy_spawn_region_button_toggled(true)
		elif not enemy_spawn_regions_dock.visible and current_edit_mode == MODE.ENEMY_SPAWN:
			_on_enemy_spawn_region_button_toggled(false)


func _on_event_regions_dock_visibility_changed() -> void:
	if initialize_state < 2:
		return
		
	if not _current_floating_state and is_instance_valid(event_regions_dock):
		if event_regions_dock.visible and current_edit_mode != MODE.EVENT_REGION:
			_on_event_region_button_toggled(true)
		elif not event_regions_dock.visible and current_edit_mode == MODE.EVENT_REGION:
			_on_event_region_button_toggled(false)


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
	
	FileCache.options.show_regions_toggled = value


func _tree_exiting() -> void:
	set_process(false)
	set_process_input(false)


func _exit_tree() -> void:
	get_tree().node_added.disconnect(_on_node_added)
	ProjectSettings.settings_changed.disconnect(_on_settings_changed)
	
	var selection = get_editor_interface().get_selection()
	
	if selection.selection_changed.is_connected(_on_editor_selection_changed):
		selection.selection_changed.disconnect(_on_editor_selection_changed)
	
	if floating_panel:
		var parent = floating_panel.get_parent()
		if parent and parent.resized.is_connected(_on_viewport_parent_resized):
			parent.resized.disconnect(_on_viewport_parent_resized)
		floating_panel.queue_free()
		floating_panel = null
		floating_buttons.clear()
		
	_destroy_docks()
	
	if is_instance_valid(event_container_control): event_container_control.queue_free()
	if is_instance_valid(extraction_event_container_control): extraction_event_container_control.queue_free()
	if is_instance_valid(enemy_spawn_container_control): enemy_spawn_container_control.queue_free()
	if is_instance_valid(event_region_container_control): event_region_container_control.queue_free()
	
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
	if initialize_state < 2:
		return
		
	var config = edit_configs[edit_type]
	
	if toggled_on:
		current_edit_mode = config.mode
		if current_object and "_last_edit_button_pressed" in current_object:
			current_object._last_edit_button_pressed = config.button_index
	elif current_edit_mode == config.mode:
		current_edit_mode = MODE.NONE
		if current_object:
			current_object.current_edit_button_pressed = -1
			if "_last_edit_button_pressed" in current_object:
				current_object._last_edit_button_pressed = -1
				
	if _current_floating_state:
		if toggled_on:
			for i in range(floating_buttons.size()):
				var btn = floating_buttons[i]
				
				if i == edit_type - 1:
					if not btn.button_pressed:
						btn.set_pressed_no_signal(true)
						btn.modulate = Color(1.0, 1.0, 1.0, 1.0)
				else:
					btn.set_pressed_no_signal(false)
					btn.modulate = Color(1.0, 1.0, 1.0, 1.0)
					
	if current_object:
		current_object.call(config.edit_method, toggled_on)
		
	if toggled_on:
		_setup_editing_mode(config)
		_hide_other_windows(edit_type)
		_handle_regions_button(config, toggled_on)
		
	_handle_regions_button_update(config, toggled_on)


func _setup_editing_mode(config: Dictionary) -> void:
	EditorInterface.set_main_screen_editor("2D")
	
	if current_object:
		var inspector = EditorInterface.get_inspector()
		
		if inspector and inspector.get_edited_object() != current_object:
			busy = true
			#EditorInterface.edit_node(current_object)
			busy = false
			
		current_object.current_edit_button_pressed = config.button_index
		
		var selection = get_editor_interface().get_selection()
		
		if not selection.get_selected_nodes().has(current_object):
			busy = true
			selection.add_node(current_object)
			busy = false
			
		if "refresh_canvas" in current_object:
			current_object.refresh_canvas()
		
		var container = get(config.container)
		if container:
			container.set(config.container_property, current_object.get(config.events_property))
			container.refresh(true)
			
			if FileCache.options.get(config.dialog_option).detached:
				call(config.detach_method, container)


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
			var last_state = FileCache.options.get("show_regions_toggled", false)
			toggled_regions_button.set_pressed_no_signal(last_state)
			toggled_regions_button.toggled.emit(last_state)
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
	
	EditorInterface.inspect_object(null)
	match edit_type:
		MODE.EVENT:
			var event = current_object.events.get_event(index)
			if event:
				current_object.current_event = event
				current_object.refresh_canvas()
				EditorInterface.inspect_object(event)
				if focus_tile_is_enabled:
					var pos = Vector2i(event.x, event.y) * current_object.tile_size
					_focus_any_item(pos, current_object.tile_size / 2)
		
		MODE.EXTRACTION_EVENT:
			var event = current_object.extraction_events[index]
			if event:
				current_object.current_extraction_event = event
				current_object.refresh_canvas()
				EditorInterface.inspect_object(event)
				if focus_tile_is_enabled:
					var pos = Vector2i(event.x, event.y) * current_object.tile_size
					_focus_any_item(pos, current_object.tile_size / 2)
		
		MODE.ENEMY_SPAWN:
			var region = current_object.get_region(index)
			if region:
				current_object.region_selected = region
				current_object.refresh_canvas()
				EditorInterface.inspect_object(region)
				if focus_tile_is_enabled:
					var pos = region.rect.position * current_object.tile_size
					_focus_any_item(pos, region.rect.size / 2)
		
		MODE.EVENT_REGION:
			var region = current_object.get_event_region(index)
			if region:
				current_object.event_region_selected = region
				current_object.refresh_canvas()
				EditorInterface.inspect_object(region)
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


#func _process(delta: float) -> void:
	#if _current_floating_state:
		#if floating_panel and floating_panel.visible:
			#var local_pos = floating_panel.get_local_mouse_position()
			#var rect = Rect2(Vector2.ZERO, floating_panel.size)
			#
			#if not rect.has_point(local_pos):
				#for btn in floating_buttons:
					#btn.modulate = Color(1.0, 1.0, 1.0, 1.0)
					#
		#var any_active = false
		#
		#for btn in floating_buttons:
			#if btn.button_pressed:
				#any_active = true
				#break
				#
		#if not any_active and current_object and "current_edit_button_pressed" in current_object:
			#current_object.current_edit_button_pressed = -1
			#
		#return
		#
	#if current_edit_mode == MODE.EVENT and is_instance_valid(events_dock) and !events_dock.visible:
		#_on_event_button_toggled(false)
	#elif current_edit_mode == MODE.EXTRACTION_EVENT and is_instance_valid(extraction_events_dock) and !extraction_events_dock.visible:
		#_on_extraction_event_button_toggled(false)
	#elif current_edit_mode == MODE.ENEMY_SPAWN and is_instance_valid(enemy_spawn_regions_dock) and !enemy_spawn_regions_dock.visible:
		#_on_enemy_spawn_region_button_toggled(false)
	#elif current_edit_mode == MODE.EVENT_REGION and is_instance_valid(event_regions_dock) and !event_regions_dock.visible:
		#_on_event_region_button_toggled(false)
		#
	#if (
		#is_instance_valid(events_dock) and not events_dock.visible and
		#is_instance_valid(extraction_events_dock) and not extraction_events_dock.visible and
		#is_instance_valid(enemy_spawn_regions_dock) and not enemy_spawn_regions_dock.visible and
		#is_instance_valid(event_regions_dock) and not event_regions_dock.visible and
		#current_object and
		#"current_edit_button_pressed" in current_object
	#):
		#current_object.current_edit_button_pressed = -1


func _process(delta: float) -> void:
	if current_object and initialize_state == 0:
		_delayed_initialization()
		
	if _current_floating_state and is_instance_valid(floating_panel) and floating_panel.visible:
		var local_pos = floating_panel.get_local_mouse_position()
		var rect = Rect2(Vector2.ZERO, floating_panel.size)
		
		if not rect.has_point(local_pos):
			for btn in floating_buttons:
				if is_instance_valid(btn):
					btn.modulate = Color(1.0, 1.0, 1.0, 1.0)
					
		var parent = floating_panel.get_parent()
		
		if parent:
			var p_size = parent.size
			var f_size = floating_panel.size
			var f_pos = floating_panel.position
			var margin = 20.0
			
			if f_pos.x < margin or f_pos.y < margin or f_pos.x > p_size.x - f_size.x - margin or f_pos.y > p_size.y - f_size.y - margin:
				if not is_dragging_floating_panel:
					_clamp_floating_panel_position(false)


func _delayed_initialization() -> void:
	if not current_object:
		return
		
	initialize_state = 1
	
	while is_instance_valid(current_object) and not current_object.is_node_ready():
		await get_tree().process_frame
		
	initialize_state = 2
	
	if current_object and is_instance_valid(current_object):
		_sync_initial_edit_mode()


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
	is_in_2d_screen = visible
	_update_floating_toolbar_visibility()


func deactivate_edit_mode_and_show_output() -> void:
	current_edit_mode = MODE.NONE
	
	if current_object:
		current_object.current_edit_button_pressed = -1
		
		if "set_editing_events" in current_object:
			current_object.set_editing_events(false)
			current_object.set_editing_extraction_events(false)
			current_object.set_editing_enemy_spawn_regions(false)
			current_object.set_editing_event_regions(false)
			
		if "refresh_canvas" in current_object:
			current_object.refresh_canvas()
			
	if _current_floating_state:
		for btn in floating_buttons:
			btn.set_pressed_no_signal(false)
			btn.modulate = Color(1.0, 1.0, 1.0, 1.0)
			
	var target_tab_container: TabContainer = null
	
	if not _current_floating_state and is_instance_valid(events_dock) and events_dock.get_parent() is TabContainer:
		target_tab_container = events_dock.get_parent() as TabContainer
	elif not _current_floating_state and is_instance_valid(extraction_events_dock) and extraction_events_dock.get_parent() is TabContainer:
		target_tab_container = extraction_events_dock.get_parent() as TabContainer
	else:
		var base_control = EditorInterface.get_base_control()
		var all_tabs = base_control.find_children("*", "TabContainer", true, false)
		
		for tab in all_tabs:
			if tab.get_tab_count() > 0:
				var tab_title = tab.get_tab_title(0).to_lower()
				
				if tab_title == "output" or tab_title == "salida":
					target_tab_container = tab as TabContainer
					break
					
	if target_tab_container:
		target_tab_container.current_tab = 0
		
	update_overlays()


## Se llama al seleccionar un nodo nuevo en la jerarquia
func _edit(object: Object) -> void:
	var is_remote = false
	
	if object:
		if "EditorDebuggerRemoteObject" in str(object):
			is_remote = true
		elif object is Node:
			var edited_scene = EditorInterface.get_edited_scene_root()
			if edited_scene and object != edited_scene and not edited_scene.is_ancestor_of(object):
				is_remote = true
				
	if is_remote:
		return
		
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
		
	if !object:
		if is_instance_valid(events_dock) and events_dock.get_parent() != null:
			event_regions_dock.close()
			enemy_spawn_regions_dock.close()
			extraction_events_dock.close()
			events_dock.close()
		current_object = null
		return
		
	var is_same_map = (current_object == object)
	
	if is_same_map:
		_update_floating_toolbar_visibility()
		return
		
	if current_object and is_instance_valid(current_object):
		if current_object.has_method("set_editing_events"):
			current_object.set_editing_events(false)
			current_object.set_editing_extraction_events(false)
			current_object.set_editing_enemy_spawn_regions(false)
			current_object.set_editing_event_regions(false)
		deactivate_edit_mode_and_show_output()
		
	current_object = object as RPGMap
	
	if current_object and not current_object.has_method("set_editing_events"):
		current_object = null
		
	if current_object:
		initialize_state = 0
		
	if is_instance_valid(events_dock):
		if current_object:
			if not _current_floating_state:
				events_dock.open()
				extraction_events_dock.open()
				enemy_spawn_regions_dock.open()
				event_regions_dock.open()
				
				if "current_edit_button_pressed" in current_object and current_object.current_edit_button_pressed != -1:
					if current_object.current_edit_button_pressed == 0:
						events_dock.make_visible()
					elif current_object.current_edit_button_pressed == 1:
						extraction_events_dock.make_visible()
					elif current_object.current_edit_button_pressed == 2:
						enemy_spawn_regions_dock.make_visible()
					else:
						event_regions_dock.make_visible()
						
					if current_object.has_method("refresh_canvas"):
						current_object.refresh_canvas()
				elif current_object.get("can_add_events"):
					get_viewport().set_input_as_handled()
					events_dock.make_visible()
		else:
			if not _current_floating_state:
				event_regions_dock.close()
				enemy_spawn_regions_dock.close()
				extraction_events_dock.close()
				events_dock.close()
				
	if current_object:
		if Engine.is_editor_hint():
			if current_object.property_list_changed.is_connected(_on_map_property_changed):
				current_object.property_list_changed.disconnect(_on_map_property_changed)
			current_object.property_list_changed.connect(_on_map_property_changed.bind(current_object))
			
		if not _current_floating_state and is_instance_valid(events_dock):
			var bottom_panel = events_dock.get_parent()
			
			if bottom_panel:
				for child in bottom_panel.get_children():
					if child is Button and child.text == "TileSet":
						child.visible = false
						
	_update_floating_toolbar_visibility()


func _sync_initial_edit_mode() -> void:
	if not is_instance_valid(current_object):
		return
		
	var last_state = FileCache.options.get("show_regions_toggled", false)
	var target_btn = -1
	
	if "_last_edit_button_pressed" in current_object and current_object._last_edit_button_pressed != -1:
		target_btn = current_object._last_edit_button_pressed
	elif "current_edit_button_pressed" in current_object and current_object.current_edit_button_pressed != -1:
		target_btn = current_object.current_edit_button_pressed
		
	if target_btn != -1:
		var mode_found = -1
		
		for key in edit_configs:
			if edit_configs[key].button_index == target_btn:
				mode_found = key
				break
				
		if mode_found != -1:
			_handle_button_toggle(mode_found, true)
			
		if not _current_floating_state:
			if target_btn == 0 and is_instance_valid(events_dock):
				if not events_dock.visible: events_dock.make_visible()
			elif target_btn == 1 and is_instance_valid(extraction_events_dock):
				if not extraction_events_dock.visible: extraction_events_dock.make_visible()
			elif target_btn == 2 and is_instance_valid(enemy_spawn_regions_dock):
				if not enemy_spawn_regions_dock.visible: enemy_spawn_regions_dock.make_visible()
			elif target_btn == 3 and is_instance_valid(event_regions_dock):
				if not event_regions_dock.visible: event_regions_dock.make_visible()
				
		if current_object.has_method("refresh_canvas"):
			current_object.refresh_canvas()
			
		update_overlays()
	else:
		deactivate_edit_mode_and_show_output()
		
	if is_instance_valid(toggled_regions_button) and toggled_regions_button.visible:
		_force_toggled_regions_button_position()
		toggled_regions_button.set_pressed_no_signal(last_state)
		
		if current_object:
			current_object.force_show_regions = last_state
			if current_object.has_method("queue_redraw"):
				current_object.queue_redraw()
				
		toggled_regions_button.toggled.emit(last_state)


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
	if !object:
		return false
		
	var is_remote = false
	
	if "EditorDebuggerRemoteObject" in str(object):
		is_remote = true
	elif object is Node:
		if not object.is_inside_tree():
			is_remote = true
		else:
			var edited_scene = EditorInterface.get_edited_scene_root()
			if edited_scene and object != edited_scene and not edited_scene.is_ancestor_of(object):
				is_remote = true
				
	if is_remote:
		return current_object != null
		
	if object is TileMapLayer:
		return true
		
	if object is Resource:
		return false
		
	var result = object is RPGMap
	
	if result:
		if "shadow_manager" in object and object.shadow_manager:
			object.shadow_manager.set_force_update_shadow(false)
		return true
	else:
		if events_dock:
			events_dock.visible = false
		if extraction_events_dock:
			extraction_events_dock.visible = false
		if enemy_spawn_regions_dock:
			enemy_spawn_regions_dock.visible = false
		if event_regions_dock:
			event_regions_dock.visible = false
			
		if current_object:
			if "shadow_manager" in current_object and current_object.shadow_manager:
				current_object.shadow_manager.set_force_update_shadow(true)
			if current_object.has_method("set_editing_events"):
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
		
	if _current_floating_state and floating_panel and floating_panel.visible:
		var local_pos = floating_panel.get_local_mouse_position()
		var rect = Rect2(Vector2.ZERO, floating_panel.size)
		
		if is_dragging_floating_panel or rect.has_point(local_pos):
			return
			
	match current_edit_mode:
		MODE.ENEMY_SPAWN:
			_input_enemy_spawn_mode(event)
		MODE.EVENT_REGION:
			_input_event_region_mode(event)


func _forward_canvas_gui_input(event: InputEvent) -> bool:
	if _current_floating_state and floating_panel and floating_panel.visible:
		var local_pos = floating_panel.get_local_mouse_position()
		var rect = Rect2(Vector2.ZERO, floating_panel.size)
		
		if is_dragging_floating_panel or rect.has_point(local_pos):
			return _process_floating_ui_input(event, local_pos)
		else:
			for btn in floating_buttons:
				btn.modulate = Color(1.0, 1.0, 1.0, 1.0)
				
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
						resize_start_rect = region.rect
						set(region_property, region)
						current_object.set(selected_property, region)
						current_object.refresh_canvas()
						found_handle = true
						break
				
				if !found_handle:
					is_resizing = false
					
			else:
				if is_resizing and region_instance:
					var old_rect = resize_start_rect
					var new_rect = region_instance.rect
					
					if Rect2i(old_rect) != new_rect:
						var undo_redo = get_undo_redo()
						undo_redo.create_action("Resize Region", UndoRedo.MERGE_DISABLE, current_object)
						undo_redo.add_do_method(self, "_force_mode_switch", mode)
						undo_redo.add_do_property(region_instance, "rect", new_rect)
						undo_redo.add_do_method(current_object, update_method, region_instance)
						undo_redo.add_do_method(get_editor_interface(), "mark_scene_as_unsaved")
						undo_redo.add_do_method(container_control, "select", region_instance.id, false, true)
						undo_redo.add_undo_method(self, "_force_mode_switch", mode)
						undo_redo.add_undo_property(region_instance, "rect", Rect2i(old_rect))
						undo_redo.add_undo_method(current_object, update_method, region_instance)
						undo_redo.add_undo_method(get_editor_interface(), "mark_scene_as_unsaved")
						undo_redo.add_undo_method(container_control, "select", region_instance.id, false, true)
						undo_redo.commit_action()
						
						var type = "update_enemy_spawn" if mode == MODE.ENEMY_SPAWN else "update_event_region"
						send_hot_reload_update(type, region_instance.id, region_instance)
					
				is_resizing = false
				resize_handle = ""
				if region_instance:
					set(region_property, null)
	
	elif is_resizing and event is InputEventMouseMotion:
		var mouse_pos = current_object.get_local_mouse_position()
		var delta = Vector2i((mouse_pos - resize_start_pos) / Vector2(current_object.tile_size))
		var new_rect: Rect2i = resize_start_rect
		
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
		if event.is_pressed():
			var _current_event = current_object.get_event_in(current_tile_pos)
			
			if can_place_event_in(current_tile_pos) or _current_event:
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
					EditorInterface.inspect_object(_current_event)
					
					if event.is_double_click():
						show_edit_event_dialog()
					else:
						current_object.select_event(Vector2i(_current_event.x, _current_event.y))
						dragging_event = _current_event
						event_drag_start_pos = Vector2i(_current_event.x, _current_event.y)
						create_cursor()
						set_cursor_position()
						
						if event_container_control:
							event_container_control.select(dragging_event.id, false, true)
							
					current_cursor = RESIZE_CURSORS.move
					
			else:
				var start_position = get_start_position_under_mouse()
				
				if start_position:
					EditorInterface.inspect_object(start_position)
					current_object.current_start_position = start_position
					
					if event_container_control:
						event_container_control.refresh(true)
						
					dragging_start_position = start_position
					start_pos_drag_start_pos = start_position.position
					create_cursor()
					set_cursor_position()
					current_cursor = RESIZE_CURSORS.move
					
			update_cursor_shape()
		
		elif dragging_event:
			var new_pos = current_tile_pos
			var old_pos = event_drag_start_pos
			var can_place = current_object.events.is_place_free_in(new_pos) and can_place_event_in(new_pos)
			
			if new_pos != old_pos and can_place:
				var undo_redo = get_undo_redo()
				
				undo_redo.create_action("Move Event", UndoRedo.MERGE_DISABLE, current_object)
				undo_redo.add_do_method(self, "_force_mode_switch", MODE.EVENT)
				undo_redo.add_do_property(dragging_event, "x", new_pos.x)
				undo_redo.add_do_property(dragging_event, "y", new_pos.y)
				undo_redo.add_do_method(current_object, "queue_redraw")
				undo_redo.add_do_method(get_editor_interface(), "mark_scene_as_unsaved")
				undo_redo.add_do_method(event_container_control, "refresh", true)
				undo_redo.add_undo_method(self, "_force_mode_switch", MODE.EVENT)
				undo_redo.add_undo_property(dragging_event, "x", old_pos.x)
				undo_redo.add_undo_property(dragging_event, "y", old_pos.y)
				undo_redo.add_undo_method(current_object, "queue_redraw")
				undo_redo.add_undo_method(get_editor_interface(), "mark_scene_as_unsaved")
				undo_redo.add_undo_method(event_container_control, "refresh", true)
				undo_redo.commit_action()
			
			send_hot_reload_update("update_event", dragging_event.id, dragging_event)
			dragging_event = null
			destroy_cursor()
		
		elif dragging_start_position:
			var new_pos = current_tile_pos
			var old_pos = start_pos_drag_start_pos
			var can_place = current_object.events.is_place_free_in(new_pos) and can_place_event_in(new_pos)
			
			if new_pos != old_pos and can_place:
				var undo_redo = get_undo_redo()
				var target_id = _get_start_position_id(dragging_start_position)
				
				undo_redo.create_action("Move Start Position", UndoRedo.MERGE_DISABLE, current_object)
				
				undo_redo.add_do_method(self, "_force_mode_switch", MODE.EVENT)
				undo_redo.add_do_property(dragging_start_position, "position", new_pos)
				undo_redo.add_do_method(current_object, "queue_redraw")
				undo_redo.add_do_method(get_editor_interface(), "mark_scene_as_unsaved")
				undo_redo.add_do_method(event_container_control, "refresh", true)
				undo_redo.add_do_method(self, "send_hot_reload_start_position", target_id, current_object.internal_id, new_pos)
				
				undo_redo.add_undo_method(self, "_force_mode_switch", MODE.EVENT)
				undo_redo.add_undo_property(dragging_start_position, "position", old_pos)
				undo_redo.add_undo_method(current_object, "queue_redraw")
				undo_redo.add_undo_method(get_editor_interface(), "mark_scene_as_unsaved")
				undo_redo.add_undo_method(event_container_control, "refresh", true)
				undo_redo.add_undo_method(self, "send_hot_reload_start_position", target_id, current_object.internal_id, old_pos)
				
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
		
		current_tile_pos = map_pos
		
		if can_place_event_in(map_pos):
			var ev = current_object.get_event_in(map_pos)
			
			if ev and event_container_control:
				event_container_control.select(ev.id, true, true)
				
			show_tile_popup_menu(event.global_position)
		elif get_start_position_under_mouse():
			show_start_position_popup_menu(event.global_position)
			
		input_handled = true
		
	elif event is InputEventKey and event.is_pressed():
		if event.keycode == KEY_ENTER:
			show_edit_event_dialog()
			input_handled = true
		elif event.keycode == KEY_DELETE or event.keycode == KEY_BACKSPACE:
			var event_to_remove = current_object.current_event
			
			if !event_to_remove:
				event_to_remove = current_object.get_event_in(current_tile_pos)
			
			if event_to_remove:
				current_object.current_event = event_to_remove
				current_tile_pos = Vector2i(event_to_remove.x, event_to_remove.y)
				remove_tile()
			elif current_object.current_start_position:
				_on_start_position_popup_menu_index_pressed(2)
				
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
					_on_tile_popup_menu_index_pressed(2)
				elif current_object.current_start_position:
					_on_start_position_popup_menu_index_pressed(0)
					
				input_handled = true
			elif event.keycode == KEY_V:
				paste_tile()
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
					EditorInterface.inspect_object(_current_event)
					
					if event.is_double_click():
						show_edit_extraction_event_dialog()
					else:
						current_object.select_extraction_event(Vector2i(_current_event.x, _current_event.y))
						dragging_extraction_event = _current_event
						extraction_drag_start_pos = Vector2i(_current_event.x, _current_event.y)
						create_cursor()
						set_cursor_position()
						
						if extraction_event_container_control:
							extraction_event_container_control.select(dragging_extraction_event.id, false, true)
							
					current_cursor = RESIZE_CURSORS.move
					
			update_cursor_shape()
		
		elif dragging_extraction_event:
			var new_pos = current_tile_pos
			var old_pos = extraction_drag_start_pos
			var can_place = current_object._is_place_free(new_pos) and can_place_event_in(new_pos)
			
			if new_pos != old_pos and can_place:
				var undo_redo = get_undo_redo()
				
				undo_redo.create_action("Move Extraction Event", UndoRedo.MERGE_DISABLE, current_object)
				undo_redo.add_do_method(self, "_force_mode_switch", MODE.EXTRACTION_EVENT)
				undo_redo.add_do_property(dragging_extraction_event, "x", new_pos.x)
				undo_redo.add_do_property(dragging_extraction_event, "y", new_pos.y)
				undo_redo.add_do_method(current_object, "queue_redraw")
				undo_redo.add_do_method(get_editor_interface(), "mark_scene_as_unsaved")
				undo_redo.add_do_method(extraction_event_container_control, "refresh", true)
				undo_redo.add_undo_method(self, "_force_mode_switch", MODE.EXTRACTION_EVENT)
				undo_redo.add_undo_property(dragging_extraction_event, "x", old_pos.x)
				undo_redo.add_undo_property(dragging_extraction_event, "y", old_pos.y)
				undo_redo.add_undo_method(current_object, "queue_redraw")
				undo_redo.add_undo_method(get_editor_interface(), "mark_scene_as_unsaved")
				undo_redo.add_undo_method(extraction_event_container_control, "refresh", true)
				undo_redo.commit_action()
					
			send_hot_reload_update("update_extraction_event", dragging_extraction_event.id, dragging_extraction_event)
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
		elif event.keycode == KEY_DELETE or event.keycode == KEY_BACKSPACE:
			var event_to_remove = current_object.current_extraction_event
			
			if !event_to_remove:
				event_to_remove = current_object.get_extraction_event_in(current_tile_pos)
			
			if event_to_remove:
				current_object.current_extraction_event = event_to_remove
				current_tile_pos = Vector2i(event_to_remove.x, event_to_remove.y)
				remove_extraction_tile()
				
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
					_on_extraction_tile_popup_menu_index_pressed(2)
					
				input_handled = true
			elif event.keycode == KEY_V:
				paste_extraction_tile()
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
			current_object.refresh_canvas()
		elif moving_enemy_spawn_region != null:
			update_moving_region(event.position)
			current_object.refresh_canvas()
			
		input_handled = true
		
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.is_pressed():
			var region: EnemySpawnRegion = get_region_in(current_tile_pos)
			
			if can_place_event_in(current_tile_pos) or region:
				if region:
					EditorInterface.inspect_object(region)
					moving_enemy_spawn_region = region.duplicate()
					current_object.current_enemy_spawn_region = moving_enemy_spawn_region
					current_object.region_selected = region
					current_object.refresh_canvas()
					drawing_region_start_position = event.position
					current_region_position = moving_enemy_spawn_region.rect.position
					
					if enemy_spawn_container_control:
						enemy_spawn_container_control.select(moving_enemy_spawn_region.id, false, true)
						
					if event.is_double_click():
						show_edit_region_dialog()
				else:
					dragging_enemy_spawn_region = EnemySpawnRegion.new()
					current_object.current_enemy_spawn_region = dragging_enemy_spawn_region
					drawing_region_start_position = current_tile_pos
					update_drawing_region()
					current_object.refresh_canvas()
					
		elif dragging_enemy_spawn_region:
			var region_to_add = dragging_enemy_spawn_region.duplicate(true)
			var region_id = region_to_add.id
			
			if region_to_add.rect.size.x > 0 and region_to_add.rect.size.y > 0:
				var undo_redo = get_undo_redo()
				
				undo_redo.create_action("Create Region", UndoRedo.MERGE_DISABLE, current_object)
				undo_redo.add_do_method(self, "_force_mode_switch", MODE.ENEMY_SPAWN)
				undo_redo.add_do_method(current_object, "add_region", region_to_add)
				undo_redo.add_do_method(get_editor_interface(), "mark_scene_as_unsaved")
				undo_redo.add_do_method(enemy_spawn_container_control, "refresh", true)
				call_deferred("_select_region_after_creation", region_to_add)
				undo_redo.add_undo_method(self, "_force_mode_switch", MODE.ENEMY_SPAWN)
				undo_redo.add_undo_method(current_object, "remove_region", region_to_add)
				undo_redo.add_undo_method(get_editor_interface(), "mark_scene_as_unsaved")
				undo_redo.add_undo_method(enemy_spawn_container_control, "refresh", true)
				undo_redo.add_undo_method(enemy_spawn_container_control, "select", -1, true, true)
				undo_redo.commit_action()
				
			send_hot_reload_update("update_enemy_spawn", region_to_add.id, region_to_add)
			current_object.current_enemy_spawn_region = null
			dragging_enemy_spawn_region = null
			current_object.refresh_canvas()
			
		elif moving_enemy_spawn_region:
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
					undo_redo.add_do_method(self, "_force_mode_switch", MODE.ENEMY_SPAWN)
					undo_redo.add_do_property(region_to_move, "rect", new_rect)
					undo_redo.add_do_method(current_object, "update_region", region_to_move)
					undo_redo.add_do_method(get_editor_interface(), "mark_scene_as_unsaved")
					undo_redo.add_do_method(enemy_spawn_container_control, "select", region_id, true, true)
					undo_redo.add_undo_method(self, "_force_mode_switch", MODE.ENEMY_SPAWN)
					undo_redo.add_undo_property(region_to_move, "rect", old_rect)
					undo_redo.add_undo_method(current_object, "update_region", region_to_move)
					undo_redo.add_undo_method(get_editor_interface(), "mark_scene_as_unsaved")
					undo_redo.add_undo_method(enemy_spawn_container_control, "select", region_id, true, true)
					undo_redo.commit_action()
					
					send_hot_reload_update("update_enemy_spawn", region_to_move.id, region_to_move)
					
			current_object.current_enemy_spawn_region = null
			moving_enemy_spawn_region = null
			current_object.refresh_canvas()
			
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
		elif event.keycode == KEY_DELETE or event.keycode == KEY_BACKSPACE:
			var region_to_remove = current_object.region_selected
			
			if !region_to_remove:
				region_to_remove = current_object.get_region_in(current_tile_pos)
				
			if region_to_remove:
				remove_region(region_to_remove)
				
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
				
	return input_handled


func _select_region_after_creation(region: EnemySpawnRegion):
	if !current_object or !enemy_spawn_container_control:
		return
		
	enemy_spawn_container_control.select(region.id, true, true)
	send_hot_reload_update("update_enemy_spawn", region.id, region)


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
			current_object.refresh_canvas()
		elif moving_event_region != null:
			update_moving_event_region(event.position)
			current_object.refresh_canvas()
			
		input_handled = true
		
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.is_pressed():
			var region: EventRegion = get_event_region_in(current_tile_pos)
			
			if can_place_event_in(current_tile_pos) or region:
				if region:
					EditorInterface.inspect_object(region)
					moving_event_region = region.duplicate()
					current_object.current_event_region = moving_event_region
					current_object.event_region_selected = region
					current_object.refresh_canvas()
					drawing_region_start_position = event.position
					current_region_position = moving_event_region.rect.position
					
					if event_region_container_control:
						event_region_container_control.select(moving_event_region.id, false, true)
						
					if event.is_double_click():
						show_edit_event_region_dialog()
				else:
					dragging_event_region = EventRegion.new()
					current_object.current_event_region = dragging_event_region
					drawing_region_start_position = current_tile_pos
					update_drawing_event_region()
					current_object.refresh_canvas()
					
		elif dragging_event_region:
			var region_to_add = dragging_event_region.duplicate(true)
			var region_id = region_to_add.id
			
			if region_to_add.rect.size.x > 0 and region_to_add.rect.size.y > 0:
				var undo_redo = get_undo_redo()
				
				undo_redo.create_action("Create Event Region", UndoRedo.MERGE_DISABLE, current_object)
				undo_redo.add_do_method(self, "_force_mode_switch", MODE.EVENT_REGION)
				undo_redo.add_do_method(current_object, "add_event_region", region_to_add)
				undo_redo.add_do_method(get_editor_interface(), "mark_scene_as_unsaved")
				undo_redo.add_do_method(event_region_container_control, "refresh", true)
				call_deferred("_select_event_region_after_creation", region_to_add)
				undo_redo.add_undo_method(self, "_force_mode_switch", MODE.EVENT_REGION)
				undo_redo.add_undo_method(current_object, "remove_event_region", region_to_add)
				undo_redo.add_undo_method(get_editor_interface(), "mark_scene_as_unsaved")
				undo_redo.add_undo_method(event_region_container_control, "refresh", true)
				undo_redo.add_undo_method(event_region_container_control, "select", -1, true, true)
				undo_redo.commit_action()
				
			send_hot_reload_update("update_event_region", region_to_add.id, region_to_add)
			current_object.current_event_region = null
			dragging_event_region = null
			current_object.refresh_canvas()
			
		elif moving_event_region:
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
					undo_redo.add_do_method(self, "_force_mode_switch", MODE.EVENT_REGION)
					undo_redo.add_do_property(region_to_move, "rect", new_rect)
					undo_redo.add_do_method(current_object, "update_event_region", region_to_move)
					undo_redo.add_do_method(get_editor_interface(), "mark_scene_as_unsaved")
					undo_redo.add_do_method(event_region_container_control, "select", region_id, true, true)
					undo_redo.add_undo_method(self, "_force_mode_switch", MODE.EVENT_REGION)
					undo_redo.add_undo_property(region_to_move, "rect", old_rect)
					undo_redo.add_undo_method(current_object, "update_event_region", region_to_move)
					undo_redo.add_undo_method(get_editor_interface(), "mark_scene_as_unsaved")
					undo_redo.add_undo_method(event_region_container_control, "select", region_id, true, true)
					undo_redo.commit_action()
					
					send_hot_reload_update("update_event_region", region_to_move.id, region_to_move)
					
			current_object.current_event_region = null
			moving_event_region = null
			current_object.refresh_canvas()
			
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
		elif event.keycode == KEY_DELETE or event.keycode == KEY_BACKSPACE:
			var region_to_remove = current_object.event_region_selected
			
			if !region_to_remove:
				region_to_remove = current_object.get_event_region_in(current_tile_pos)
				
			if region_to_remove:
				remove_event_region(region_to_remove)
				
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
				
	return input_handled


func _select_event_region_after_creation(region: EventRegion):
	if !current_object or !event_region_container_control:
		return
		
	event_region_container_control.select(region.id, true, true)
	send_hot_reload_update("update_event_region", region.id, region)


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
	
	current_object.queue_redraw()
	update_overlays()


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
	
	current_object.queue_redraw()
	update_overlays()


func update_moving_region(pos: Vector2i) -> void:
	var viewport = EditorInterface.get_editor_viewport_2d()
	var scale = viewport.get_final_transform().y.y
	var target: Vector2i = (pos - Vector2i(drawing_region_start_position)) / scale
	var dest: Vector2i = target / current_object.tile_size
	
	moving_enemy_spawn_region.rect.position = current_region_position + dest
	
	current_object.queue_redraw()
	update_overlays()


func update_moving_event_region(pos: Vector2i) -> void:
	var viewport = EditorInterface.get_editor_viewport_2d()
	var scale = viewport.get_final_transform().y.y
	var target: Vector2i = (pos - Vector2i(drawing_region_start_position)) / scale
	var dest: Vector2i = target / current_object.tile_size
	
	moving_event_region.rect.position = current_region_position + dest
	
	current_object.queue_redraw()
	update_overlays()


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

	if index == 0:
		if !current_event:
			create_new_tile()
		else:
			show_edit_event_dialog()
			
	elif index == 2:
		var event_to_cut = current_object.get_event_in(current_tile_pos)
		
		if !event_to_cut:
			return
			
		var event_copy = event_to_cut.duplicate(true)
		var event_id = event_copy.id
		var event_pos = Vector2i(event_copy.x, event_copy.y)
		
		event_copy._uniq_id = event_to_cut._uniq_id
		event_copy.set_meta("is_original_event", true)
		
		undo_redo.create_action("Cut Event", UndoRedo.MERGE_DISABLE, current_object)
		
		undo_redo.add_do_method(self, "_force_mode_switch", MODE.EVENT)
		undo_redo.add_do_method(self, "copy_tile_into_clipboard", event_copy, true)
		undo_redo.add_do_method(current_object, "remove_event_in", event_pos)
		undo_redo.add_do_method(get_editor_interface(), "mark_scene_as_unsaved")
		undo_redo.add_do_method(event_container_control, "refresh", true)
		undo_redo.add_do_method(event_container_control, "select", -1, true, true)
		undo_redo.add_do_method(self, "send_hot_reload_delete", "delete_event", event_copy._uniq_id)
		
		undo_redo.add_undo_method(self, "_force_mode_switch", MODE.EVENT)
		undo_redo.add_undo_method(current_object, "paste_event_in", event_pos, event_copy)
		undo_redo.add_undo_method(get_editor_interface(), "mark_scene_as_unsaved")
		undo_redo.add_undo_method(event_container_control, "refresh", true)
		undo_redo.add_undo_method(event_container_control, "select", event_id, true, true)
		undo_redo.add_undo_method(self, "send_hot_reload_update", "update_event", event_id, event_copy)
		
		undo_redo.commit_action()
		
	elif index == 3:
		copy_tile_into_clipboard()
		
	elif index == 4:
		paste_tile()
		
	elif index == 5:
		remove_tile()


func _on_extraction_tile_popup_menu_index_pressed(index: int) -> void:
	if !current_object:
		return
	
	var undo_redo = get_undo_redo()
	
	if index == 0:
		if !current_extraction_event:
			create_new_extraction_tile()
		else:
			show_edit_extraction_event_dialog()
			
	elif index == 2:
		var event_to_cut = current_object.get_extraction_event_in(current_tile_pos)
		
		if !event_to_cut:
			return
		
		var event_copy = event_to_cut.duplicate(true)
		var event_id = event_copy.id
		var event_pos = Vector2i(event_copy.x, event_copy.y)

		undo_redo.create_action("Cut Extraction Event", UndoRedo.MERGE_DISABLE, current_object)
		
		undo_redo.add_do_method(self, "_force_mode_switch", MODE.EXTRACTION_EVENT)
		undo_redo.add_do_method(self, "copy_extraction_tile_into_clipboard", event_copy)
		undo_redo.add_do_method(current_object, "remove_extraction_event_in", event_pos)
		undo_redo.add_do_method(get_editor_interface(), "mark_scene_as_unsaved")
		undo_redo.add_do_method(extraction_event_container_control, "refresh", true)
		undo_redo.add_do_method(extraction_event_container_control, "select", -1, true, true)
		undo_redo.add_do_method(self, "send_hot_reload_delete", "delete_extraction_event", event_id)
		
		undo_redo.add_undo_method(self, "_force_mode_switch", MODE.EXTRACTION_EVENT)
		undo_redo.add_undo_method(current_object, "paste_extraction_event_in", event_pos, event_copy)
		undo_redo.add_undo_method(get_editor_interface(), "mark_scene_as_unsaved")
		undo_redo.add_undo_method(extraction_event_container_control, "refresh", true)
		undo_redo.add_undo_method(extraction_event_container_control, "select", event_id, true, true)
		undo_redo.add_undo_method(self, "send_hot_reload_update", "update_extraction_event", event_id, event_copy)
		
		undo_redo.commit_action()

	elif index == 3:
		copy_extraction_tile_into_clipboard()
		
	elif index == 4:
		paste_extraction_tile()
		
	elif index == 5:
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
		0:
			start_pos_key = "player_start_position"
			action_name = "Set Player Start"
		1:
			start_pos_key = "land_transport_start_position"
			action_name = "Set Land Transport Start"
		2:
			start_pos_key = "sea_transport_start_position"
			action_name = "Set Sea Transport Start"
		3:
			start_pos_key = "air_transport_start_position"
			action_name = "Set Air Transport Start"
		5:
			paste_start_position()
			return
		_:
			return
			
	var data_object: RPGMapPosition = system.database.system.get(start_pos_key)
	
	if !data_object:
		return

	var old_map_id = data_object.map_id
	var old_pos = data_object.position
	var target_id = _get_start_position_id(data_object)

	if old_map_id == new_map_id and old_pos == new_pos:
		return

	undo_redo.create_action(action_name, UndoRedo.MERGE_DISABLE, current_object)

	undo_redo.add_do_method(self, "_force_mode_switch", MODE.EVENT)
	undo_redo.add_do_property(data_object, "map_id", new_map_id)
	undo_redo.add_do_property(data_object, "position", new_pos)
	undo_redo.add_do_method(get_editor_interface(), "mark_scene_as_unsaved")
	undo_redo.add_do_method(event_container_control, "refresh", true)
	undo_redo.add_do_method(current_object, "queue_redraw")
	undo_redo.add_do_method(self, "send_hot_reload_start_position", target_id, new_map_id, new_pos)
	
	undo_redo.add_undo_method(self, "_force_mode_switch", MODE.EVENT)
	undo_redo.add_undo_property(data_object, "map_id", old_map_id)
	undo_redo.add_undo_property(data_object, "position", old_pos)
	undo_redo.add_undo_method(get_editor_interface(), "mark_scene_as_unsaved")
	undo_redo.add_undo_method(event_container_control, "refresh", true)
	undo_redo.add_undo_method(current_object, "queue_redraw")
	undo_redo.add_undo_method(self, "send_hot_reload_start_position", target_id, old_map_id, old_pos)
	
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
	
	if !FileAccess.file_exists(preset_path):
		push_error("Preset file not found: ", preset_path)
		return
	
	var preset: EventPreset = FileAccess.open(preset_path, FileAccess.READ).get_var(true)
	
	if !preset or !preset.preset:
		push_error("Invalid preset file: ", preset_path)
		return
	
	var event_copy = preset.preset.duplicate(true)
	
	if "_uniq_id" in event_copy:
		event_copy._uniq_id = RPGSYSTEM.generate_16_digit_id()
	
	var undo_redo = get_undo_redo()
	
	undo_redo.create_action("Create Event from Preset", UndoRedo.MERGE_DISABLE, current_object)
	
	undo_redo.add_do_method(self, "_force_mode_switch", MODE.EVENT)
	undo_redo.add_do_method(current_object, "paste_event_in", current_tile_pos, event_copy)
	undo_redo.add_do_method(get_editor_interface(), "mark_scene_as_unsaved")
	undo_redo.add_do_method(event_container_control, "refresh", true)
	undo_redo.add_do_method(event_container_control, "select_object", event_copy, true, true)
	undo_redo.add_do_method(self, "send_hot_reload_update", "update_event", event_copy.id, event_copy)
	
	undo_redo.add_undo_method(self, "_force_mode_switch", MODE.EVENT)
	undo_redo.add_undo_method(current_object, "remove_event_in", current_tile_pos)
	undo_redo.add_undo_method(get_editor_interface(), "mark_scene_as_unsaved")
	undo_redo.add_undo_method(event_container_control, "refresh", true)
	undo_redo.add_undo_method(event_container_control, "select", -1, true, true)
	undo_redo.add_undo_method(self, "send_hot_reload_delete", "delete_event", event_copy._uniq_id)
	
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
	
	undo_redo.add_do_method(self, "_force_mode_switch", MODE.EXTRACTION_EVENT)
	undo_redo.add_do_method(current_object, "paste_extraction_event_in", current_tile_pos, event_copy)
	undo_redo.add_do_method(get_editor_interface(), "mark_scene_as_unsaved")
	undo_redo.add_do_method(extraction_event_container_control, "refresh", true)
	undo_redo.add_do_method(extraction_event_container_control, "select", event_copy.id, true, true)
	undo_redo.add_do_method(self, "send_hot_reload_update", "update_extraction_event", event_copy.id, event_copy)
	
	undo_redo.add_undo_method(self, "_force_mode_switch", MODE.EXTRACTION_EVENT)
	undo_redo.add_undo_method(current_object, "remove_extraction_event_in", current_tile_pos)
	undo_redo.add_undo_method(get_editor_interface(), "mark_scene_as_unsaved")
	undo_redo.add_undo_method(extraction_event_container_control, "refresh", true)
	undo_redo.add_undo_method(extraction_event_container_control, "select", -1, true, true)
	undo_redo.add_undo_method(self, "send_hot_reload_delete", "delete_extraction_event", event_copy.id)
	
	undo_redo.commit_action()


func _on_region_popup_menu_index_pressed(index: int) -> void:
	if !current_object:
		return
		
	if current_edit_mode == MODE.ENEMY_SPAWN:
		if index == 0:
			show_edit_region_dialog()
		elif index == 2:
			remove_region(current_object.region_selected)
		elif index == 4:
			var region_to_cut = current_object.region_selected
			
			if !region_to_cut:
				region_to_cut = current_object.get_region_in(current_tile_pos)
				
			if !region_to_cut:
				return

			var region_copy = region_to_cut.duplicate(true)
			var region_id = region_copy.id
			var undo_redo = get_undo_redo()
			
			undo_redo.create_action("Cut Region", UndoRedo.MERGE_DISABLE, current_object)
			
			undo_redo.add_do_method(self, "_force_mode_switch", MODE.ENEMY_SPAWN)
			undo_redo.add_do_method(self, "copy_region_into_clipboard", region_copy)
			undo_redo.add_do_method(current_object, "remove_region", region_to_cut)
			undo_redo.add_do_method(get_editor_interface(), "mark_scene_as_unsaved")
			undo_redo.add_do_method(enemy_spawn_container_control, "refresh", true)
			undo_redo.add_do_method(enemy_spawn_container_control, "select", -1, true, true)
			undo_redo.add_do_method(self, "send_hot_reload_delete", "delete_enemy_spawn", region_id)
			
			undo_redo.add_undo_method(self, "_force_mode_switch", MODE.ENEMY_SPAWN)
			undo_redo.add_undo_method(current_object, "paste_region_in", region_copy.rect.position, region_copy)
			undo_redo.add_undo_method(get_editor_interface(), "mark_scene_as_unsaved")
			undo_redo.add_undo_method(enemy_spawn_container_control, "refresh", true)
			undo_redo.add_undo_method(enemy_spawn_container_control, "select", region_id, true, true)
			undo_redo.add_undo_method(self, "send_hot_reload_update", "update_enemy_spawn", region_id, region_copy)
			
			undo_redo.commit_action()
			
		elif index == 5:
			copy_region_into_clipboard()
		elif index == 6:
			paste_region()
	else:
		if index == 0:
			show_edit_event_region_dialog()
		elif index == 2:
			remove_event_region(current_object.event_region_selected)
		elif index == 4:
			var region_to_cut = current_object.event_region_selected
			
			if !region_to_cut:
				region_to_cut = current_object.get_event_region_in(current_tile_pos)
				
			if !region_to_cut:
				return

			var region_copy = region_to_cut.duplicate(true)
			var region_id = region_copy.id
			var undo_redo = get_undo_redo()
			
			undo_redo.create_action("Cut Event Region", UndoRedo.MERGE_DISABLE, current_object)

			undo_redo.add_do_method(self, "_force_mode_switch", MODE.EVENT_REGION)
			undo_redo.add_do_method(self, "copy_event_region_into_clipboard", region_copy)
			undo_redo.add_do_method(current_object, "remove_event_region", region_to_cut)
			undo_redo.add_do_method(get_editor_interface(), "mark_scene_as_unsaved")
			undo_redo.add_do_method(event_region_container_control, "refresh", true)
			undo_redo.add_do_method(event_region_container_control, "select", -1, true, true)
			undo_redo.add_do_method(self, "send_hot_reload_delete", "delete_event_region", region_id)
			
			undo_redo.add_undo_method(self, "_force_mode_switch", MODE.EVENT_REGION)
			undo_redo.add_undo_method(current_object, "paste_event_region_in", region_copy.rect.position, region_copy)
			undo_redo.add_undo_method(get_editor_interface(), "mark_scene_as_unsaved")
			undo_redo.add_undo_method(event_region_container_control, "refresh", true)
			undo_redo.add_undo_method(event_region_container_control, "select", region_id, true, true)
			undo_redo.add_undo_method(self, "send_hot_reload_update", "update_event_region", region_id, region_copy)
			
			undo_redo.commit_action()
			
		elif index == 5:
			copy_event_region_into_clipboard()
		elif index == 6:
			paste_event_region()


func _on_start_position_popup_menu_index_pressed(index: int) -> void:
	if !current_object or !current_start_position:
		return

	var undo_redo = get_undo_redo()
	var old_map_id = current_start_position.map_id
	var old_pos = current_start_position.position
	var target_id = _get_start_position_id(current_start_position)
	
	if index == 0:
		undo_redo.create_action("Cut Start Position", UndoRedo.MERGE_DISABLE, current_object)
		undo_redo.add_do_method(self, "_force_mode_switch", MODE.EVENT)
		undo_redo.add_do_method(self, "copy_start_position_into_clipboard")
		undo_redo.add_do_method(current_start_position, "clear")
		undo_redo.add_do_method(get_editor_interface(), "mark_scene_as_unsaved")
		undo_redo.add_do_method(event_container_control, "refresh", true)
		undo_redo.add_do_method(current_object, "queue_redraw")
		undo_redo.add_do_method(self, "send_hot_reload_start_position", target_id, -1, Vector2i.ZERO)
		
		undo_redo.add_undo_method(self, "_force_mode_switch", MODE.EVENT)
		undo_redo.add_undo_property(current_start_position, "map_id", old_map_id)
		undo_redo.add_undo_property(current_start_position, "position", old_pos)
		undo_redo.add_undo_method(get_editor_interface(), "mark_scene_as_unsaved")
		undo_redo.add_undo_method(event_container_control, "refresh", true)
		undo_redo.add_undo_method(current_object, "queue_redraw")
		undo_redo.add_undo_method(self, "send_hot_reload_start_position", target_id, old_map_id, old_pos)
		
		undo_redo.commit_action()

	elif index == 1:
		copy_start_position_into_clipboard()
	
	elif index == 2:
		undo_redo.create_action("Remove Start Position", UndoRedo.MERGE_DISABLE, current_object)
		undo_redo.add_do_method(self, "_force_mode_switch", MODE.EVENT)
		undo_redo.add_do_method(current_start_position, "clear")
		undo_redo.add_do_method(get_editor_interface(), "mark_scene_as_unsaved")
		undo_redo.add_do_method(event_container_control, "refresh", true)
		undo_redo.add_do_method(current_object, "queue_redraw")
		undo_redo.add_do_method(self, "send_hot_reload_start_position", target_id, -1, Vector2i.ZERO)
		
		undo_redo.add_undo_method(self, "_force_mode_switch", MODE.EVENT)
		undo_redo.add_undo_property(current_start_position, "map_id", old_map_id)
		undo_redo.add_undo_property(current_start_position, "position", old_pos)
		undo_redo.add_undo_method(get_editor_interface(), "mark_scene_as_unsaved")
		undo_redo.add_undo_method(event_container_control, "refresh", true)
		undo_redo.add_undo_method(current_object, "queue_redraw")
		undo_redo.add_undo_method(self, "send_hot_reload_start_position", target_id, old_map_id, old_pos)
		
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
	var target_id = _get_start_position_id(data_object)
	
	if old_map_id == new_map_id and old_pos == new_pos:
		return
		
	var undo_redo = get_undo_redo()
	
	undo_redo.create_action("Paste Start Position", UndoRedo.MERGE_DISABLE, current_object)
	
	undo_redo.add_do_method(self, "_force_mode_switch", MODE.EVENT)
	undo_redo.add_do_property(data_object, "map_id", new_map_id)
	undo_redo.add_do_property(data_object, "position", new_pos)
	undo_redo.add_do_method(get_editor_interface(), "mark_scene_as_unsaved")
	undo_redo.add_do_method(event_container_control, "refresh", true)
	undo_redo.add_do_method(current_object, "queue_redraw")
	undo_redo.add_do_method(self, "send_hot_reload_start_position", target_id, new_map_id, new_pos)
	
	undo_redo.add_undo_method(self, "_force_mode_switch", MODE.EVENT)
	undo_redo.add_undo_property(data_object, "map_id", old_map_id)
	undo_redo.add_undo_property(data_object, "position", old_pos)
	undo_redo.add_undo_method(get_editor_interface(), "mark_scene_as_unsaved")
	undo_redo.add_undo_method(event_container_control, "refresh", true)
	undo_redo.add_undo_method(current_object, "queue_redraw")
	undo_redo.add_undo_method(self, "send_hot_reload_start_position", target_id, old_map_id, old_pos)
	
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
	if event:
		if event_container_control:
			event_container_control.select(event.id, true, true)
		send_hot_reload_update("update_event", event.id, event)
	
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
	if event:
		if extraction_event_container_control:
			extraction_event_container_control.select(event.id, true, true)
		send_hot_reload_update("update_extraction_event", event.id, event)
	
	current_object.select_extraction_event(pos)


func copy_tile_into_clipboard(default_event: RPGEvent = null, preserve_id: bool = false) -> void:
	var event = current_object.get_event_in(current_tile_pos) if !default_event else default_event
	if event:
		var preserve_id_cache = -1
		if preserve_id:
			preserve_id_cache = event._uniq_id 
		StaticEditorVars.CLIPBOARD["event"] = event.clone(true)
		if preserve_id_cache != -1:
			StaticEditorVars.CLIPBOARD["event"]._uniq_id = preserve_id_cache


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
		
	var event_copy: RPGEvent = event_to_paste.duplicate(true)
	event_copy.id = current_object.events.get_next_id()
	
	var is_original = event_copy.has_meta("is_original_event")
	
	if not is_original:
		event_copy._uniq_id = RPGSYSTEM.generate_16_digit_id()
	elif event_copy.has_meta("is_original_event"):
		event_copy.remove_meta("is_original_event")
	
	var undo_redo = get_undo_redo()
	
	undo_redo.create_action("Paste Event", UndoRedo.MERGE_DISABLE, current_object)
	
	undo_redo.add_do_method(self, "_force_mode_switch", MODE.EVENT)
	undo_redo.add_do_method(current_object, "paste_event_in", current_tile_pos, event_copy)
	undo_redo.add_do_method(get_editor_interface(), "mark_scene_as_unsaved")
	undo_redo.add_do_method(event_container_control, "refresh", true)
	undo_redo.add_do_method(event_container_control, "select", event_copy.id, true, true)
	undo_redo.add_do_method(self, "send_hot_reload_update", "update_event", event_copy.id, event_copy)
	
	if is_original:
		undo_redo.add_do_method(self, "_set_cache_original_event", false)
		
	undo_redo.add_undo_method(self, "_force_mode_switch", MODE.EVENT)
	undo_redo.add_undo_method(current_object, "remove_event_in", current_tile_pos)
	undo_redo.add_undo_method(get_editor_interface(), "mark_scene_as_unsaved")
	undo_redo.add_undo_method(event_container_control, "refresh", true)
	undo_redo.add_undo_method(event_container_control, "select", -1, true, true)
	undo_redo.add_undo_method(self, "send_hot_reload_delete", "delete_event", event_copy._uniq_id)
	
	if is_original:
		undo_redo.add_undo_method(self, "_set_cache_original_event", true)

	undo_redo.commit_action()


func _set_cache_original_event(value: bool) -> void:
	var event_into_clipboard = StaticEditorVars.CLIPBOARD.get("event")
	if event_into_clipboard:
		if value and !event_into_clipboard.has_meta("is_original_event"):
			event_into_clipboard.set_meta("is_original_event", true)
		elif !value and event_into_clipboard.has_meta("is_original_event"):
			event_into_clipboard.remove_meta("is_original_event")


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
	
	undo_redo.add_do_method(self, "_force_mode_switch", MODE.EXTRACTION_EVENT)
	undo_redo.add_do_method(current_object, "paste_extraction_event_in", current_tile_pos, event_copy)
	undo_redo.add_do_method(get_editor_interface(), "mark_scene_as_unsaved")
	undo_redo.add_do_method(extraction_event_container_control, "refresh", true)
	undo_redo.add_do_method(extraction_event_container_control, "select", event_copy.id, true, true)
	undo_redo.add_do_method(self, "send_hot_reload_update", "update_extraction_event", event_copy.id, event_copy)
	
	undo_redo.add_undo_method(self, "_force_mode_switch", MODE.EXTRACTION_EVENT)
	undo_redo.add_undo_method(current_object, "remove_extraction_event_in", current_tile_pos)
	undo_redo.add_undo_method(get_editor_interface(), "mark_scene_as_unsaved")
	undo_redo.add_undo_method(extraction_event_container_control, "refresh", true)
	undo_redo.add_undo_method(extraction_event_container_control, "select", -1, true, true)
	undo_redo.add_undo_method(self, "send_hot_reload_delete", "delete_extraction_event", event_copy.id)

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
	
	undo_redo.add_do_method(self, "_force_mode_switch", MODE.ENEMY_SPAWN)
	undo_redo.add_do_method(current_object, "paste_region_in", current_tile_pos, region_copy)
	undo_redo.add_do_method(get_editor_interface(), "mark_scene_as_unsaved")
	undo_redo.add_do_method(enemy_spawn_container_control, "refresh", true)
	undo_redo.add_do_method(enemy_spawn_container_control, "select", region_copy.id, true, true)
	undo_redo.add_do_method(self, "send_hot_reload_update", "update_enemy_spawn", region_copy.id, region_copy)
	
	undo_redo.add_undo_method(self, "_force_mode_switch", MODE.ENEMY_SPAWN)
	undo_redo.add_undo_method(current_object, "remove_region", region_copy) 
	undo_redo.add_undo_method(get_editor_interface(), "mark_scene_as_unsaved")
	undo_redo.add_undo_method(enemy_spawn_container_control, "refresh", true)
	undo_redo.add_undo_method(enemy_spawn_container_control, "select", -1, true, true)
	undo_redo.add_undo_method(self, "send_hot_reload_delete", "delete_enemy_spawn", region_copy.id)

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
	
	undo_redo.add_do_method(self, "_force_mode_switch", MODE.EVENT_REGION)
	undo_redo.add_do_method(current_object, "paste_event_region_in", current_tile_pos, region_copy)
	undo_redo.add_do_method(get_editor_interface(), "mark_scene_as_unsaved")
	undo_redo.add_do_method(event_region_container_control, "refresh", true)
	undo_redo.add_do_method(event_region_container_control, "select", region_copy.id, true, true)
	undo_redo.add_do_method(self, "send_hot_reload_update", "update_event_region", region_copy.id, region_copy)
	
	undo_redo.add_undo_method(self, "_force_mode_switch", MODE.EVENT_REGION)
	undo_redo.add_undo_method(current_object, "remove_event_region", region_copy)
	undo_redo.add_undo_method(get_editor_interface(), "mark_scene_as_unsaved")
	undo_redo.add_undo_method(event_region_container_control, "refresh", true)
	undo_redo.add_undo_method(event_region_container_control, "select", -1, true, true)
	undo_redo.add_undo_method(self, "send_hot_reload_delete", "delete_event_region", region_copy.id)

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
	
	undo_redo.add_do_method(self, "_force_mode_switch", MODE.EVENT)
	undo_redo.add_do_method(current_object, "remove_event_in", event_pos)
	undo_redo.add_do_method(get_editor_interface(), "mark_scene_as_unsaved")
	undo_redo.add_do_method(event_container_control, "refresh", true)
	undo_redo.add_do_method(event_container_control, "select", -1, true, true)
	undo_redo.add_do_method(EditorInterface, "inspect_object", null)
	undo_redo.add_do_method(current_object, "queue_redraw")
	undo_redo.add_do_method(self, "send_hot_reload_delete", "delete_event", event_copy._uniq_id)
	
	undo_redo.add_undo_method(self, "_force_mode_switch", MODE.EVENT)
	undo_redo.add_undo_method(current_object, "paste_event_in", event_pos, event_copy)
	undo_redo.add_undo_method(get_editor_interface(), "mark_scene_as_unsaved")
	undo_redo.add_undo_method(event_container_control, "refresh", true)
	undo_redo.add_undo_method(event_container_control, "select", event_id, true, true)
	undo_redo.add_undo_method(current_object, "queue_redraw")
	undo_redo.add_undo_method(self, "send_hot_reload_update", "update_event", event_id, event_copy)
	
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
	
	undo_redo.add_do_method(self, "_force_mode_switch", MODE.EXTRACTION_EVENT)
	undo_redo.add_do_method(current_object, "remove_extraction_event_in", event_pos)
	undo_redo.add_do_method(get_editor_interface(), "mark_scene_as_unsaved")
	undo_redo.add_do_method(extraction_event_container_control, "refresh", true)
	undo_redo.add_do_method(extraction_event_container_control, "select", -1, true, true)
	undo_redo.add_do_method(EditorInterface, "inspect_object", null)
	undo_redo.add_do_method(current_object, "queue_redraw")
	undo_redo.add_do_method(self, "send_hot_reload_delete", "delete_extraction_event", event_id)
	
	undo_redo.add_undo_method(self, "_force_mode_switch", MODE.EXTRACTION_EVENT)
	undo_redo.add_undo_method(current_object, "paste_extraction_event_in", event_pos, event_copy)
	undo_redo.add_undo_method(get_editor_interface(), "mark_scene_as_unsaved")
	undo_redo.add_undo_method(extraction_event_container_control, "refresh", true)
	undo_redo.add_undo_method(extraction_event_container_control, "select", event_id, true, true)
	undo_redo.add_undo_method(current_object, "queue_redraw")
	undo_redo.add_undo_method(self, "send_hot_reload_update", "update_extraction_event", event_id, event_copy)
	
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
		return 
	
	var region_copy = region_to_remove.duplicate(true)
	var region_id = region_copy.id
	var undo_redo = get_undo_redo()
	
	undo_redo.create_action("Remove Region", UndoRedo.MERGE_DISABLE, current_object)
	
	undo_redo.add_do_method(self, "_force_mode_switch", MODE.ENEMY_SPAWN)
	undo_redo.add_do_method(current_object, "remove_region", region_to_remove)
	undo_redo.add_do_method(get_editor_interface(), "mark_scene_as_unsaved")
	undo_redo.add_do_method(enemy_spawn_container_control, "refresh", true)
	undo_redo.add_do_method(enemy_spawn_container_control, "select", -1, true, true)
	undo_redo.add_do_method(EditorInterface, "inspect_object", null)
	undo_redo.add_do_method(current_object, "queue_redraw")
	undo_redo.add_do_method(self, "send_hot_reload_delete", "delete_enemy_spawn", region_id)
	
	undo_redo.add_undo_method(self, "_force_mode_switch", MODE.ENEMY_SPAWN)
	undo_redo.add_undo_method(current_object, "paste_region_in", region_copy.rect.position, region_copy)
	undo_redo.add_undo_method(get_editor_interface(), "mark_scene_as_unsaved")
	undo_redo.add_undo_method(enemy_spawn_container_control, "refresh", true)
	undo_redo.add_undo_method(enemy_spawn_container_control, "select", region_id, true, true)
	undo_redo.add_undo_method(current_object, "queue_redraw")
	undo_redo.add_undo_method(self, "send_hot_reload_update", "update_enemy_spawn", region_id, region_copy)
	
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
		return
	
	var region_copy = region_to_remove.duplicate(true)
	var region_id = region_copy.id
	var undo_redo = get_undo_redo()
	
	undo_redo.create_action("Remove Event Region", UndoRedo.MERGE_DISABLE, current_object)
	
	undo_redo.add_do_method(self, "_force_mode_switch", MODE.EVENT_REGION)
	undo_redo.add_do_method(current_object, "remove_event_region", region_to_remove)
	undo_redo.add_do_method(get_editor_interface(), "mark_scene_as_unsaved")
	undo_redo.add_do_method(event_region_container_control, "refresh", true)
	undo_redo.add_do_method(event_region_container_control, "select", -1, true, true)
	undo_redo.add_do_method(EditorInterface, "inspect_object", null)
	undo_redo.add_do_method(current_object, "queue_redraw")
	undo_redo.add_do_method(self, "send_hot_reload_delete", "delete_event_region", region_id)
	
	undo_redo.add_undo_method(self, "_force_mode_switch", MODE.EVENT_REGION)
	undo_redo.add_undo_method(current_object, "paste_event_region_in", region_copy.rect.position, region_copy)
	undo_redo.add_undo_method(get_editor_interface(), "mark_scene_as_unsaved")
	undo_redo.add_undo_method(event_region_container_control, "refresh", true)
	undo_redo.add_undo_method(event_region_container_control, "select", region_id, true, true)
	undo_redo.add_undo_method(current_object, "queue_redraw")
	undo_redo.add_undo_method(self, "send_hot_reload_update", "update_event_region", region_id, region_copy)
	
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
	dialog.event_updated.connect(_on_edit_event_dialog_changed.bind(current_object))
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


func _on_edit_event_dialog_changed(event: RPGEvent, obj: RPGMap) -> void:
	if is_instance_valid(obj) and is_instance_valid(event):
		var rpg_map_info = get_node_or_null("/root/RPGMapsInfo")
		if rpg_map_info:
			rpg_map_info.update_single_event(obj.internal_id, event)
		send_hot_reload_update("update_event", event.id, event)


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
	dialog.changed.connect(_on_extraction_event_changed.bind(current_extraction_event))
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


func _on_extraction_event_changed(event = null, _extra = null) -> void:
	var target = event if event is RPGExtractionItem else current_extraction_event
	
	if target:
		get_editor_interface().mark_scene_as_unsaved()
		send_hot_reload_update("update_extraction_event", target.id, target)


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
	send_hot_reload_update("update_enemy_spawn", _region.id, _region)


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
	send_hot_reload_update("update_event_region", _region.id, _region)


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
			var ids = ["player_start_position", "land_transport_start_position", "sea_transport_start_position", "air_transport_start_position"]
			
			for id in ids:
				var data: RPGMapPosition = system.database.system.get(id)
				
				if data and data.map_id == map_id and data.position == pos:
					return false
					
		var extra_margin = 5
		var used_rect = current_object.get_used_rect()
		used_rect.position -= Vector2i(extra_margin, extra_margin)
		used_rect.size += Vector2i(extra_margin * 2, extra_margin * 2)
		
		return used_rect.has_point(pos)
		
	return false


func get_preview(scene: String, receiver: Object, function: StringName, userdata: Variant = null) -> void:
	scene_preview.queue_resource_preview(scene, receiver, function, userdata)


func _force_mode_switch(mode_to_force: MODE) -> void:
	if _current_floating_state:
		for i in range(floating_buttons.size()):
			var btn = floating_buttons[i]
			var should_be_pressed = false
			
			if mode_to_force == MODE.EVENT and i == 0: should_be_pressed = true
			elif mode_to_force == MODE.EXTRACTION_EVENT and i == 1: should_be_pressed = true
			elif mode_to_force == MODE.ENEMY_SPAWN and i == 2: should_be_pressed = true
			elif mode_to_force == MODE.EVENT_REGION and i == 3: should_be_pressed = true
			
			if should_be_pressed:
				btn.set_pressed(true)
			else:
				btn.set_pressed_no_signal(false)
				btn.modulate = Color(1.0, 1.0, 1.0, 1.0)
	else:
		if mode_to_force != MODE.EVENT and is_instance_valid(events_dock): events_dock.visible = false
		if mode_to_force != MODE.EXTRACTION_EVENT and is_instance_valid(extraction_events_dock): extraction_events_dock.visible = false
		if mode_to_force != MODE.ENEMY_SPAWN and is_instance_valid(enemy_spawn_regions_dock): enemy_spawn_regions_dock.visible = false
		if mode_to_force != MODE.EVENT_REGION and is_instance_valid(event_regions_dock): event_regions_dock.visible = false
		
		match mode_to_force:
			MODE.EVENT: 
				if is_instance_valid(events_dock): events_dock.make_visible()
			MODE.EXTRACTION_EVENT: 
				if is_instance_valid(extraction_events_dock): extraction_events_dock.make_visible()
			MODE.ENEMY_SPAWN: 
				if is_instance_valid(enemy_spawn_regions_dock): enemy_spawn_regions_dock.make_visible()
			MODE.EVENT_REGION: 
				if is_instance_valid(event_regions_dock): event_regions_dock.make_visible()


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

#region Hot Reloaded
func _get_start_position_id(pos_obj: RPGMapPosition) -> String:
	var system = get_node_or_null("/root/RPGSYSTEM")
	
	if not system or not system.database or not system.database.system:
		return ""
		
	var db = system.database.system
	
	if pos_obj == db.get("land_transport_start_position"): return "land_transport_start_position"
	if pos_obj == db.get("sea_transport_start_position"): return "sea_transport_start_position"
	if pos_obj == db.get("air_transport_start_position"): return "air_transport_start_position"
	if pos_obj == db.get("player_start_position"): return "player_start_position"
	
	return ""


func send_hot_reload_delete(type: String, id: int) -> void:
	if not hot_reload_udp.is_bound():
		hot_reload_udp.set_dest_address(target_ip, target_port)
		
	var data := {
		"type": type,
		"id": id,
		"map_id": current_object.internal_id
	}
	
	var packet := JSON.stringify(data).to_utf8_buffer()
	
	hot_reload_udp.put_packet(packet)
	
	cleanup_old_temp_files()


func send_hot_reload_update(type: String, id: int, resource: Resource) -> void:
	if not hot_reload_udp.is_bound():
		hot_reload_udp.set_dest_address(target_ip, target_port)
		
	var temp_dir := "res://addons/RPGMap/Temp/"
	
	if not DirAccess.dir_exists_absolute(temp_dir):
		DirAccess.make_dir_recursive_absolute(temp_dir)
		
	var temp_path := temp_dir + "hot_reload_" + type + "_" + str(id) + ".tres"
	
	ResourceSaver.save(resource, temp_path)
	
	var data := {
		"type": type,
		"id": id,
		"path": temp_path,
		"map_id": current_object.internal_id
	}
	
	var packet := JSON.stringify(data).to_utf8_buffer()
	
	hot_reload_udp.put_packet(packet)
	
	cleanup_old_temp_files()


func send_hot_reload_move(type: String, id: int, new_pos: Vector2i) -> void:
	if not hot_reload_udp.is_bound():
		hot_reload_udp.set_dest_address(target_ip, target_port)
		
	var data := {
		"type": type,
		"id": id,
		"x": new_pos.x,
		"y": new_pos.y,
		"map_id": current_object.internal_id
	}
	
	var packet := JSON.stringify(data).to_utf8_buffer()
	
	hot_reload_udp.put_packet(packet)
	
	cleanup_old_temp_files()


## Sends the updated start position data for vehicles or the player to the game instance
func send_hot_reload_start_position(target_id: String, map_id: int, pos: Vector2i) -> void:
	if not hot_reload_udp.is_bound():
		hot_reload_udp.set_dest_address(target_ip, target_port)
		
	var data := {
		"type": "update_start_position",
		"target_id": target_id,
		"map_id": map_id,
		"x": pos.x,
		"y": pos.y
	}
	
	var packet := JSON.stringify(data).to_utf8_buffer()
	
	hot_reload_udp.put_packet(packet)
	
	cleanup_old_temp_files()


## Sends a hot-reload network packet to update, create, or delete a vehicle in the game instance
func send_hot_reload_vehicle(target_id: String, map_id: int, pos: Vector2i) -> void:
	if target_id == "player_start_position" or target_id.is_empty():
		return
		
	if not hot_reload_udp.is_bound():
		hot_reload_udp.set_dest_address(target_ip, target_port)
		
	var data := {
		"type": "update_start_position",
		"target_id": target_id,
		"map_id": map_id,
		"x": pos.x,
		"y": pos.y
	}
	
	var packet := JSON.stringify(data).to_utf8_buffer()
	
	hot_reload_udp.put_packet(packet)
	
	cleanup_old_temp_files()


## Cleans up temporary hot reload files older than a specific threshold
func cleanup_old_temp_files(max_age_seconds: int = 60) -> void:
	var temp_dir = "res://addons/RPGMap/Temp/"
	var dir = DirAccess.open(temp_dir)
	
	if not dir:
		return
		
	var current_time = Time.get_unix_time_from_system()
	var files = dir.get_files()
	
	for file_name in files:
		var file_path = temp_dir + file_name
		var file_time = FileAccess.get_modified_time(file_path)
			
		if current_time - file_time > max_age_seconds:
			DirAccess.remove_absolute(file_path)
#endregion
