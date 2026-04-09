@tool
@icon("res://addons/rpg_scene_manager/Assets/Images/map.png")
class_name RPGMap
extends Node2D

#region Exports
@export_category("Editor Fields")
## Changes the size for tiles to all TileMapLayers added to this control.
## You can only paint events on the part of the grid that is drawn.
@export var tile_size: Vector2i = Vector2i(32, 32):
	set(value):
		tile_size = value.max(Vector2i.ONE)
		for child in get_children():
			if child is TileMapLayer and child.tile_set:
				child.tile_set.tile_size = tile_size
		queue_redraw()

## Color with which the grid will be drawn in this control.
@export var grid_gradient: Gradient:
	set(gradient):
		grid_gradient = gradient
		queue_redraw()

## Color used for the grid lines.
@export var grid_color: Color = Color(0.969, 0.718, 0.639, 0.514):
	set(color):
		grid_color = color
		queue_redraw()

## Radius of the area to draw around the mouse cursor (in tiles).
@export var cursor_radius: int = 5

## Change the opacity of the children for better visibility of the canvases.
@export_range(0.0, 1.0, 0.01) var children_opacity: float = 0.21:
	set(value):
		children_opacity = value
		if editor_canvas: editor_canvas.set_child_opacity(self, false)

## Change the opacity of the canvases for better visibility of the children
@export_range(0.0, 1.0, 0.01) var canvas_opacity: float = 1.0:
	set(value):
		canvas_opacity = value
		if editor_canvas:
			if editor_canvas.event_canvas:
				editor_canvas.event_canvas.modulate = Color(1.0, 1.0, 1.0, canvas_opacity)
			if editor_canvas.extraction_event_canvas:
				editor_canvas.extraction_event_canvas.modulate = Color(1.0, 1.0, 1.0, canvas_opacity)
			if editor_canvas.enemy_spawn_canvas:
				editor_canvas.enemy_spawn_canvas.modulate = Color(1.0, 1.0, 1.0, canvas_opacity)
			if editor_canvas.event_region_canvas:
				editor_canvas.event_region_canvas.modulate = Color(1.0, 1.0, 1.0, canvas_opacity)

## Copy the map ID to the clipboard
@export var copy_map_id_into_clipboard: bool = false:
	set(value):
		if value:
			DisplayServer.clipboard_set(str(internal_id))
			print("Map id %s copy into clipboard" % internal_id)

@export_category("Map Fields")
## Allows you to configure how the map name is displayed when you open it.
@export_enum("ALWAYS", "ONCE", "NEVER") var show_map_name: int = 0
## Specify a custom name for the map, or leave it blank to use the map node's name as the "map name"
@export var custom_map_name: String = ""
## Music that will be played when playing this map
@export var map_bgm: AudioStream

## Changes the current color modulation for this map (Default will be White = No Change)
@export var map_modulate: Color = Color.WHITE:
	set(color):
		map_modulate = color
		update_modulate_color()

## Makes the map infinitely scrollable horizontally (useful for world maps)
@export var infinite_horizontal_scroll: bool = false :
	set(value):
		infinite_horizontal_scroll = value
		notify_property_list_changed()
		update_configuration_warnings()

## Makes the map infinitely scrollable vertically (useful for world maps)
@export var infinite_vertical_scroll: bool = false :
	set(value):
		infinite_vertical_scroll = value
		notify_property_list_changed()
		update_configuration_warnings()

## Limits camera panning to map width on maps that do not have infinite horizontal scroll
@export var auto_set_horizontal_camera_limits: bool = true

## Limits camera panning to map height on maps that do not have infinite vertical scroll
@export var auto_set_vertical_camera_limits: bool = true

@export_subgroup("Shadows")
## Draw shadows to the environment layer, events, player and vehicles.
## (This will create shadow sprites for each object / character that has shadow,
## if you prefer to use godot light and occlusion, disable this option
## and set your lights and occlusion manually).
@export var draw_shadows: bool = true:
	set(value):
		draw_shadows = value
		if shadow_manager: shadow_manager.update_shadows()
		notify_property_list_changed()
		update_configuration_warnings()

## Enable integrated Day/Night usage (configurable in [System] within the database).
@export var use_dynamic_day_night: bool = false:
	set(value):
		use_dynamic_day_night = value
		if DayNightManager:
			if use_dynamic_day_night:
				DayNightManager.set_enabled()
			else:
				DayNightManager.set_disabled()
		if shadow_manager: shadow_manager.update_shadows()
		notify_property_list_changed()

## You can set the starting time for this map, 
## or leave it at -1 to use the current time recorded by the Day/Night system.
@export_range(-1, 24, 1) var map_starting_hour: int = 13:
	set(value):
		map_starting_hour = value
		if DayNightManager:
			DayNightManager.set_time(map_starting_hour)
		if shadow_manager: shadow_manager.update_shadows()
#endregion

#region Initial Variables
var preview_shadows_in_editor = false
var editing_events: bool = false
var current_event: RPGEvent
var editing_extraction_events: bool = false
var current_extraction_event: RPGExtractionItem
var editing_enemy_spawn_region: bool = false
var current_enemy_spawn_region: EnemySpawnRegion
var editing_event_region: bool = false
var region_selected: EnemySpawnRegion
var current_event_region: EventRegion
var event_region_selected: EventRegion
var current_start_position: RPGMapPosition = RPGMapPosition.new()

var can_add_events: bool = false

var _keots_timer: float = 0.0
const _KAOT_MAX_TIMER = 0.25

var force_show_regions: bool = false
var preview_map_only_enabled: bool = false
var particle_container: Node2D
var editor_icons = {}
var editor_canvas_modulate: CanvasModulate
var current_parent: MainScene
var show_passability_debug: bool = false

var need_refresh: bool = false
var current_in_game_enemy_spawn_region: EnemySpawnRegion

@export var _baked_keot_data: Dictionary = {}
@export var events := RPGEvents.new()
@export var extraction_events: Array[RPGExtractionItem] = []
@export var regions: Array[EnemySpawnRegion] = []
@export var event_regions: Array[EventRegion] = []
@export var internal_id: int
@export var current_edit_button_pressed: int = -1
@export var _last_edit_button_pressed: int = -1
var ingame_event_regions: Array[CollisionShape2D] = []

@onready var MAP_LAYERS: Dictionary = {}

var pathfinder: AStarPathfinder
var event_offset: Vector2
var moving_event: bool = false
var rect_size_cache: Dictionary = {}
var last_extraction_event_pasted_id: int

var events_page_hp: Dictionary = {}

var map_layout: MapLayout
var shadow_manager: IngameMapShadowManager
var editor_canvas: IneditorMapEditorCanvas
var entity_manager: IngameMapEntityManager
var editor_data_manager: IneditorMapDataManager
var layout_helper: IngameMapLayoutHelper
var passability_helper: IngameMapPassabilityHelper
var region_manager: IngameMapRegionManager

const GENERIC_EVENT_SCENE_PATH = "res://addons/rpg_character_creator/Other/generic_lpc_base_scene.tscn"
const GENERIC_EVENT_SCRIPT_PATH = "res://addons/rpg_character_creator/Other/generic_lpc_base.gd"
#endregion

signal map_started()


#region Built-in Engine Methods
func _init() -> void:
	if Engine.is_editor_hint():
		pass



func _enter_tree() -> void:
	if Engine.is_editor_hint():
		var layers = ["GroundBase", "GroundDetail", "Environment", "Overlay"]
		for i in layers.size():
			var layer_name = layers[i]
			var layer_exists = has_node(layer_name)
			if not layer_exists:
				var layer = TileMapLayer.new()
				layer.name = layer_name
				layer.z_index = 0 if i < 2 else 1
				add_child(layer)
				layer.unique_name_in_owner = true
				layer.owner = get_tree().edited_scene_root



func _ready() -> void:
	MAP_LAYERS = {
		"ground": find_child("GroundBase"),
		"ground_detail": find_child("GroundDetail"),
		"environment": find_child("Environment"),
		"overlay": find_child("Overlay")
	}
	
	shadow_manager = IngameMapShadowManager.new(self)
	entity_manager = IngameMapEntityManager.new(self)
	editor_data_manager = IneditorMapDataManager.new(self)
	layout_helper = IngameMapLayoutHelper.new(self)
	passability_helper = IngameMapPassabilityHelper.new(self)
	region_manager = IngameMapRegionManager.new(self)
	
	if Engine.is_editor_hint():
		if !preview_map_only_enabled:
			_start_editor_mode()
		else:
			_start_preview_mode()
	else:
		if !preview_map_only_enabled:
			_start_game_mode()
		else:
			_start_preview_mode()
			
	if editor_canvas:
		editor_canvas.set_child_opacity(self, true)
	else:
		_restore_original_opacity(self)
	
	update_modulate_color()
	update_bgm()



func _process(delta: float) -> void:
	if shadow_manager: shadow_manager.process_editor_physics()
	
	if need_refresh:
		refresh_events()
		need_refresh = false
	
	_update_depleted_items(delta)
	
	if _keots_timer > 0.0:
		_keots_timer -= delta
		if _keots_timer <= 0.0:
			_bake_keot_data_fast()
			if editor_canvas and editor_canvas.keot_canvas: editor_canvas.keot_canvas.queue_redraw()
	
	if editor_canvas and editor_canvas.cursor_canvas:
		if _is_selected_in_editor():
			editor_canvas.cursor_canvas.visible = true
			editor_canvas.cursor_canvas.queue_redraw()
		else:
			editor_canvas.cursor_canvas.visible = false



func _physics_process(delta: float) -> void:
	if shadow_manager: shadow_manager.process_ingame_physics()
	if entity_manager:
		entity_manager.update_pressable_events()



func _notification(what: int) -> void:
	if what == NOTIFICATION_EDITOR_PRE_SAVE:
		var rpg_map_info = get_node_or_null("/root/RPGMapsInfo")
		if rpg_map_info:
			rpg_map_info.fix_maps([self])
		
		_bake_keot_data_fast()



func _validate_property(property):
	if not Engine.is_editor_hint():
		if property.name == "_rt":
			property.usage = PROPERTY_USAGE_NO_EDITOR
			return
			
	var properties = ["internal_id", "events", "extraction_events", "regions", "event_regions", "current_edit_button_pressed", "_baked_keot_data", "_last_edit_button_pressed"]
	if property.name in properties:
		property.usage &= ~PROPERTY_USAGE_EDITOR
	
	properties = ["use_dynamic_day_night"]
	if property.name in properties:
		if not draw_shadows:
			property.usage = PROPERTY_USAGE_NO_EDITOR
		else:
			property.usage = PROPERTY_USAGE_EDITOR | PROPERTY_USAGE_STORAGE



func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	if get_tree().get_edited_scene_root() != self:
		warnings.append("This node must be the parent of the scene for it to function correctly.")
	if get_tree().get_edited_scene_root().get_scene_file_path().length() == 0:
		warnings.append("The current scene must be saved in order to add events to the map.")
	var layers = 0
	for child in get_children():
		if child is TileMapLayer:
			layers += 1
			if Vector2i(child.position) != Vector2i.ZERO:
				warnings.append("The layer \"%s\" should be at position 0x,0y (current position = %sx,%sy" % [child.name, int(child.position.x), int(child.position.y)])
				break
	if layers == 0:
		warnings.append("The map must have at least one TileMapLayer.")
		
	if draw_shadows:
		if infinite_horizontal_scroll and infinite_vertical_scroll:
			warnings.append("Warning: Enabling dynamic shadows on fully infinite maps (X and Y) may affect performance.")
		elif infinite_horizontal_scroll:
			warnings.append("Warning: Enabling dynamic shadows on horizontal infinite maps may affect performance.")
		elif infinite_vertical_scroll:
			warnings.append("Warning: Enabling dynamic shadows on vertical infinite maps may affect performance.")
			
	can_add_events = warnings.size() == 0
	
	return warnings



func get_class():
	return "RPGMap"
#endregion



#region Initialization & Modes
func _start_editor_mode() -> void:
	editor_icons.player_start_position = preload("res://addons/RPGMap/Assets/Images/player_start_position.png")
	editor_icons.land_transport_start_position = preload("res://addons/RPGMap/Assets/Images/land_transport_start_position.png")
	editor_icons.sea_transport_start_position = preload("res://addons/RPGMap/Assets/Images/sea_transport_start_position.png")
	editor_icons.air_transport_start_position = preload("res://addons/RPGMap/Assets/Images/air_transport_start_position.png")
	editor_icons.other = []
	editor_icons.keot_tile = preload("uid://cjfab1wyp2rf0")
	editor_canvas = IneditorMapEditorCanvas.new(self)
	editor_canvas.call_deferred("build_canvases", false)
	
	editor_canvas_modulate = CanvasModulate.new()
	add_child(editor_canvas_modulate)
	
	if !internal_id:
		internal_id = generate_16_digit_id()
		notify_property_list_changed()
	
	var edited_scene_root = get_tree().get_edited_scene_root()
	
	child_entered_tree.connect(_on_child_entered_tree)
	
	if preview_shadows_in_editor and draw_shadows:
		if shadow_manager: shadow_manager.update_shadows()
	
	for child in get_children():
		if not child is TileMapLayer: continue
		
		if not child.changed.is_connected(_keots_need_refresh):
			child.changed.connect(_keots_need_refresh)



func _start_preview_mode() -> void:
	map_layout = MapLayout.new()
	GameManager.current_map = self
	editor_icons.player_start_position = preload("res://addons/RPGMap/Assets/Images/player_start_position.png")
	editor_icons.land_transport_start_position = preload("res://addons/RPGMap/Assets/Images/land_transport_start_position.png")
	editor_icons.sea_transport_start_position = preload("res://addons/RPGMap/Assets/Images/sea_transport_start_position.png")
	editor_icons.air_transport_start_position = preload("res://addons/RPGMap/Assets/Images/air_transport_start_position.png")
	editor_icons.other = []
	editor_canvas = IneditorMapEditorCanvas.new(self)
	editor_canvas.call_deferred("build_canvases", true)



func _start_game_mode() -> void:
	map_layout = MapLayout.new()
	GameManager.current_map = self
	visible = false
	pathfinder = AStarPathfinder.new()
	pathfinder.initialize(self)
	event_offset = Vector2(tile_size.x * 0.5, tile_size.y - 4)
	
	events_page_hp = {}
	
	var parent = get_tree().get_first_node_in_group("start_scene_main")
	if not parent or parent is not MainScene:
		await get_tree().process_frame
		var main_scene = "res://Scenes/main_scene.tscn"
		var scn = load(main_scene).instantiate()
		scn.is_test_map = true
		scn.current_map = self
		get_parent().add_child(scn)
		queue_free()
		return

	if entity_manager:
		entity_manager.setup_vehicles()
		entity_manager.setup_events()
		entity_manager.setup_extraction_events()
		
	_setup_common_events()
	
	parent.setup_player()
	GameManager.show_followers(GameManager.game_state.followers_enabled, true)
	
	if draw_shadows and shadow_manager:
		shadow_manager.create_shadows()
	
	var rect = get_used_rect(false)
	var camera: Camera2D = get_viewport().get_camera_2d()
	var default_limit_amount = 10000000
	camera.limit_left = - default_limit_amount
	camera.limit_top = - default_limit_amount
	camera.limit_right = default_limit_amount
	camera.limit_bottom = default_limit_amount
	if camera:
		camera.set_meta("screen_limits", {
			"left": rect.position.x,
			"right": rect.position.x + rect.size.x,
			"up": rect.position.y,
			"down": rect.position.y + rect.size.y
		})
		if !infinite_horizontal_scroll and auto_set_horizontal_camera_limits:
			camera.limit_left = rect.position.x
			camera.limit_right = rect.position.x + rect.size.x
		if !infinite_vertical_scroll and auto_set_vertical_camera_limits:
			camera.limit_bottom = rect.position.y + rect.size.y
			camera.limit_top = rect.position.y
	
	var body: StaticBody2D = region_manager.build_world_walls()
	var area: Area2D = region_manager.setup_event_monitor()
	region_manager.create_region_events(body, area)
	region_manager.create_enemy_spawn_areas(area)
	
	if entity_manager: entity_manager.create_particle_container()
	
	var game_state = GameManager.game_state
	if game_state:
		var stats = game_state.stats.map_visited
		if not internal_id in stats:
			stats[internal_id] = true
	
	if use_dynamic_day_night:
		DayNightManager.continue_from_time(map_starting_hour)
	
	var screen_size = Vector2i(
		ProjectSettings.get_setting("display/window/size/viewport_width"),
		ProjectSettings.get_setting("display/window/size/viewport_height")
	)
	if get_used_rect(false).size < screen_size or not (infinite_vertical_scroll or infinite_horizontal_scroll):
		GameManager.clear_map_repeating()
	else:
		GameManager.enable_map_repeating()
	
	if OS.is_debug_build():
		var _test_commands_file_path = "res://addons/RPGMap/Temp/_temp_event_commands.res"
		if ResourceLoader.exists(_test_commands_file_path) and not GameManager._test_commands_processed:
			var res: TestCommandEvent = load(_test_commands_file_path)
			if not res.commands.is_empty():
				GameInterpreter.start_event(GameManager.current_player, res.commands)
			GameManager._test_commands_processed = true
	
	var keots_area = KeotSystem.new()
	add_child(keots_area)
	keots_area.build_from_cache(self, _baked_keot_data)
	
	visible = true
	await get_tree().create_timer(0.04).timeout
	GameManager.set_fx_busy(false)
	GameManager.set_cursor_manipulator(GameManager.MANIPULATOR_MODES.NONE)
	map_started.emit()
	
	if show_map_name == 0 or (show_map_name == 1 and not GameManager.game_state.map_names_shown.get(internal_id, false)):
		var map_name = custom_map_name if not custom_map_name.is_empty() else name
		GameManager.show_map_name(map_name, 1.0)
		if show_map_name == 1:
			GameManager.game_state.map_names_shown[internal_id] = true


func register_hp_page(event_id: int, page_id: int, hp_value: int) -> void:
	if not event_id in events_page_hp:
		events_page_hp[event_id] = {}
	
	if not page_id in events_page_hp[event_id]:
		events_page_hp[event_id][page_id] = hp_value


func _on_child_entered_tree(node: Node) -> void:
	if node is TileMapLayer:
		if !node.tile_set:
			node.tile_set = TileSet.new()
		node.tile_set.tile_size = tile_size
		var passability_layer_name = "Passability"
		if node.tile_set.get_custom_data_layer_by_name(passability_layer_name) == -1:
			node.tile_set.add_custom_data_layer(-1)
			var index = node.tile_set.get_custom_data_layers_count() - 1
			node.tile_set.set_custom_data_layer_name(index, passability_layer_name)
			node.tile_set.set_custom_data_layer_type(index, typeof(RPGMapPassability))
		
		if node.changed.is_connected(_keots_need_refresh):
			node.changed.disconnect(_keots_need_refresh)
		node.changed.connect(_keots_need_refresh)



func _setup_common_events() -> void:
	pass



func _restore_original_opacity(node: Node) -> void:
	for child in node.get_children():
		if child.has_meta("original_opacity"):
			child.modulate.a = child.get_meta("original_opacity")
		_restore_original_opacity(child)
#endregion



#region Update & Refresh
func update_modulate_color() -> void:
	if !is_inside_tree():
		return
		
	if Engine.is_editor_hint() and editor_canvas_modulate:
		editor_canvas_modulate.color = map_modulate
	else:
		GameManager.set_map_color(map_modulate)



func update_bgm() -> void:
	if !is_inside_tree():
		return
	
	GameManager.play_bgm(map_bgm, 0.0, 1.0, 1.5)



func refresh_canvas():
	queue_redraw()



func _keots_need_refresh() -> void:
	_keots_timer = _KAOT_MAX_TIMER


func _bake_keot_data_fast() -> void:
	if editor_data_manager: 
		editor_data_manager.bake_keot_data_fast()
#endregion



#region Editor Canvas & UI Wrappers
func set_editing_events(value: bool) -> void:
	editing_extraction_events = false
	current_extraction_event = null
	editing_enemy_spawn_region = false
	current_enemy_spawn_region = null
	editing_event_region = false
	current_event_region = null
	
	if editor_canvas:
		if editor_canvas.event_canvas: editor_canvas.event_canvas.queue_redraw()
		if editor_canvas.extraction_event_canvas: editor_canvas.extraction_event_canvas.queue_redraw()
		if editor_canvas.enemy_spawn_canvas: editor_canvas.enemy_spawn_canvas.queue_redraw()
		if editor_canvas.event_region_canvas: editor_canvas.event_region_canvas.queue_redraw()
	
	if Engine.is_editor_hint():
		editing_events = value
		current_event = null
		if editor_canvas: editor_canvas.set_child_opacity(self, !value)
	
	show_passability_debug = value
	if editor_canvas and editor_canvas.passability_canvas:
		editor_canvas.passability_canvas.queue_redraw()
			
	queue_redraw()



func set_editing_extraction_events(value: bool) -> void:
	editing_events = false
	current_event = null
	editing_enemy_spawn_region = false
	current_enemy_spawn_region = null
	editing_event_region = false
	current_event_region = null
	
	if editor_canvas:
		if editor_canvas.event_canvas: editor_canvas.event_canvas.queue_redraw()
		if editor_canvas.extraction_event_canvas: editor_canvas.extraction_event_canvas.queue_redraw()
		if editor_canvas.enemy_spawn_canvas: editor_canvas.enemy_spawn_canvas.queue_redraw()
		if editor_canvas.event_region_canvas: editor_canvas.event_region_canvas.queue_redraw()
	
	if Engine.is_editor_hint():
		editing_extraction_events = value
		current_extraction_event = null
		if editor_canvas: editor_canvas.set_child_opacity(self, !value)
			
	show_passability_debug = value
	if editor_canvas and editor_canvas.passability_canvas:
		editor_canvas.passability_canvas.queue_redraw()
			
	queue_redraw()



func set_editing_enemy_spawn_regions(value: bool) -> void:
	editing_events = false
	current_event = null
	editing_extraction_events = false
	current_extraction_event = null
	editing_event_region = false
	current_event_region = null
	
	if editor_canvas:
		if editor_canvas.event_canvas: editor_canvas.event_canvas.queue_redraw()
		if editor_canvas.extraction_event_canvas: editor_canvas.extraction_event_canvas.queue_redraw()
		if editor_canvas.enemy_spawn_canvas: editor_canvas.enemy_spawn_canvas.queue_redraw()
		if editor_canvas.event_region_canvas: editor_canvas.event_region_canvas.queue_redraw()
	
	if Engine.is_editor_hint():
		editing_enemy_spawn_region = value
		current_enemy_spawn_region = null
		if editor_canvas: editor_canvas.set_child_opacity(self, !value)
			
	show_passability_debug = false
	if editor_canvas and editor_canvas.passability_canvas:
		editor_canvas.passability_canvas.queue_redraw()
			
	queue_redraw()



func set_editing_event_regions(value: bool) -> void:
	editing_events = false
	current_event = null
	editing_extraction_events = false
	current_extraction_event = null
	editing_enemy_spawn_region = false
	current_enemy_spawn_region = null
	
	if editor_canvas:
		if editor_canvas.event_canvas: editor_canvas.event_canvas.queue_redraw()
		if editor_canvas.extraction_event_canvas: editor_canvas.extraction_event_canvas.queue_redraw()
		if editor_canvas.enemy_spawn_canvas: editor_canvas.enemy_spawn_canvas.queue_redraw()
		if editor_canvas.event_region_canvas: editor_canvas.event_region_canvas.queue_redraw()
	
	if Engine.is_editor_hint():
		editing_event_region = value
		current_event_region = null
		if editor_canvas: editor_canvas.set_child_opacity(self, !value)
			
	show_passability_debug = false
	if editor_canvas and editor_canvas.passability_canvas:
		editor_canvas.passability_canvas.queue_redraw()
			
	queue_redraw()



func perform_full_update() -> void:
	if Engine.is_editor_hint() and editor_canvas:
		if editing_events and editor_canvas.event_canvas:
			editor_canvas.event_canvas.queue_redraw()
		elif editing_extraction_events and editor_canvas.extraction_event_canvas:
			editor_canvas.extraction_event_canvas.queue_redraw()
		elif editing_enemy_spawn_region and editor_canvas.enemy_spawn_canvas:
			editor_canvas.enemy_spawn_canvas.queue_redraw()
		elif editing_event_region and editor_canvas.event_region_canvas:
			editor_canvas.event_region_canvas.queue_redraw()
#endregion



#region Editor Data Manager Wrappers
func get_region(index: int) -> EnemySpawnRegion:
	return editor_data_manager.get_region(index) if editor_data_manager else null



func get_event_region(index: int) -> EventRegion:
	return editor_data_manager.get_event_region(index) if editor_data_manager else null



func generate_16_digit_id() -> int:
	return editor_data_manager.generate_16_digit_id() if editor_data_manager else 0



func _is_place_free(pos: Vector2i) -> bool:
	return editor_data_manager._is_place_free(pos) if editor_data_manager else false



func add_event_in(pos: Vector2i) -> bool:
	return editor_data_manager.add_event_in(pos) if editor_data_manager else false



func _get_next_extraction_event_id() -> int:
	return editor_data_manager._get_next_extraction_event_id() if editor_data_manager else 1



func _get_next_event_id() -> int:
	return editor_data_manager._get_next_event_id() if editor_data_manager else 1



func add_extraction_event_in(pos: Vector2i) -> bool:
	return editor_data_manager.add_extraction_event_in(pos) if editor_data_manager else false



func get_region_in(pos: Vector2i) -> EnemySpawnRegion:
	return editor_data_manager.get_region_in(pos) if editor_data_manager else null



func get_event_region_in(pos: Vector2i) -> EventRegion:
	return editor_data_manager.get_event_region_in(pos) if editor_data_manager else null



func random_color_in_range(hue_min: float, hue_max: float) -> Color:
	return editor_data_manager.random_color_in_range(hue_min, hue_max) if editor_data_manager else Color.WHITE



func add_region(new_region: EnemySpawnRegion) -> EnemySpawnRegion:
	return editor_data_manager.add_region(new_region) if editor_data_manager else null



func add_event_region(new_region: EventRegion) -> EventRegion:
	return editor_data_manager.add_event_region(new_region) if editor_data_manager else null



func _update_spawn_region(index: int, region: EnemySpawnRegion) -> void:
	if editor_data_manager: editor_data_manager._update_spawn_region(index, region)



func _update_event_region(index: int, region: EventRegion) -> void:
	if editor_data_manager: editor_data_manager._update_event_region(index, region)



func update_region(region_updated: EnemySpawnRegion) -> void:
	if editor_data_manager: editor_data_manager.update_region(region_updated)



func update_event_region(region_updated: EventRegion) -> void:
	if editor_data_manager: editor_data_manager.update_event_region(region_updated)



func paste_event_in(pos: Vector2i, event: RPGEvent) -> bool:
	return editor_data_manager.paste_event_in(pos, event) if editor_data_manager else false



func _add_extraction_event(event: RPGExtractionItem, rename: bool = true) -> void:
	if editor_data_manager: editor_data_manager._add_extraction_event(event, rename)



func _update_extraction_event(index: int, event: RPGExtractionItem) -> void:
	if editor_data_manager: editor_data_manager._update_extraction_event(index, event)



func sort_events_by_id(a: RPGExtractionItem, b: RPGExtractionItem) -> bool:
	return editor_data_manager.sort_events_by_id(a, b) if editor_data_manager else false



func paste_extraction_event_in(pos: Vector2i, new_event: RPGExtractionItem) -> bool:
	return editor_data_manager.paste_extraction_event_in(pos, new_event) if editor_data_manager else false



func paste_region_in(pos: Vector2i, region: EnemySpawnRegion) -> bool:
	return editor_data_manager.paste_region_in(pos, region) if editor_data_manager else false



func _get_next_event_region_id() -> int:
	return editor_data_manager._get_next_event_region_id() if editor_data_manager else 1



func paste_event_region_in(pos: Vector2i, region: EventRegion) -> bool:
	return editor_data_manager.paste_event_region_in(pos, region) if editor_data_manager else false



func get_last_event_added() -> int:
	return editor_data_manager.get_last_event_added() if editor_data_manager else 0



func get_last_extraction_event_added() -> int:
	return editor_data_manager.get_last_extraction_event_added() if editor_data_manager else 0



func get_event_in(pos: Vector2i) -> RPGEvent:
	return editor_data_manager.get_event_in(pos) if editor_data_manager else null



func get_extraction_event_in(pos: Vector2i) -> RPGExtractionItem:
	return editor_data_manager.get_extraction_event_in(pos) if editor_data_manager else null



func get_event_by_id(id: int) -> RPGEvent:
	return editor_data_manager.get_event_by_id(id) if editor_data_manager else null



func get_event_by_uniq_id(id: int) -> RPGEvent:
	return editor_data_manager.get_event_by_uniq_id(id) if editor_data_manager else null



func remove_event_in(pos: Vector2i) -> bool:
	return editor_data_manager.remove_event_in(pos) if editor_data_manager else false



func remove_extraction_event_in(pos: Vector2i) -> bool:
	return editor_data_manager.remove_extraction_event_in(pos) if editor_data_manager else false



func remove_region_in(pos: Vector2i) -> bool:
	return editor_data_manager.remove_region_in(pos) if editor_data_manager else false



func remove_event_region_in(pos: Vector2i) -> bool:
	return editor_data_manager.remove_event_region_in(pos) if editor_data_manager else false



func remove_region(region: EnemySpawnRegion) -> void:
	if editor_data_manager: editor_data_manager.remove_region(region)



func remove_event_region(region: EventRegion) -> void:
	if editor_data_manager: editor_data_manager.remove_event_region(region)



func set_events(values: RPGEvents) -> void:
	if editor_data_manager: editor_data_manager.set_events(values)



func select_event(pos: Vector2i) -> void:
	if editor_data_manager: editor_data_manager.select_event(pos)



func select_extraction_event(pos: Vector2i) -> void:
	if editor_data_manager: editor_data_manager.select_extraction_event(pos)



func is_mouse_over_event() -> bool:
	return editor_data_manager.is_mouse_over_event() if editor_data_manager else false



func is_mouse_over_extraction_event() -> bool:
	return editor_data_manager.is_mouse_over_extraction_event() if editor_data_manager else false



func _is_selected_in_editor() -> bool:
	return editor_data_manager.is_selected_in_editor() if editor_data_manager else false



func _is_mouse_inside_viewport() -> bool:
	return editor_data_manager.is_mouse_inside_viewport() if editor_data_manager else false
#endregion



#region In-Game Entity Manager Wrappers
func refresh_events() -> void:
	if entity_manager: entity_manager.refresh_events()



func refresh_extraction_events() -> void:
	if entity_manager: entity_manager.refresh_extraction_events()



func _update_depleted_items(delta: float) -> void:
	if entity_manager: entity_manager.process_extraction_events(delta)


func _update_pressed_events() -> void:
	if entity_manager: entity_manager._update_pressed_events()

func get_events_in_place(pos: Vector2i) -> int:
	return entity_manager.get_events_in_place(pos) if entity_manager else 0



func get_events_objects_in(pos: Vector2i) -> Array:
	return entity_manager.get_events_objects_in(pos) if entity_manager else []



func get_in_game_event_in(pos: Vector2i) -> Variant:
	return entity_manager.get_in_game_event_in(pos) if entity_manager else null



func get_in_game_events_in(pos: Vector2i, include_previous_tile: bool = false) -> Array:
	return entity_manager.get_in_game_events_in(pos, include_previous_tile) if entity_manager else []



func get_overlapped_events_number(pos: Vector2i) -> int:
	return entity_manager.get_overlapped_events_number(pos) if entity_manager else 0



func get_in_game_events() -> Array[IngameEvent]:
	return entity_manager.get_in_game_events() if entity_manager else []



func get_in_game_event(event_id: int) -> Variant:
	return entity_manager.get_in_game_event(event_id) if entity_manager else null



func get_in_game_event_by_pos(event_id: int) -> Variant:
	return entity_manager.get_in_game_event_by_pos(event_id) if entity_manager else null



func get_in_game_event_by_id(event_id: int) -> Variant:
	return entity_manager.get_in_game_event_by_id(event_id) if entity_manager else null



func get_in_game_event_by_uniq_id(uniq_id: int, return_ingame_event: bool = false) -> Variant:
	return entity_manager.get_in_game_event_by_uniq_id(uniq_id, return_ingame_event) if entity_manager else null



func get_in_game_vehicle_in(pos: Vector2i) -> RPGVehicle:
	return entity_manager.get_in_game_vehicle_in(pos) if entity_manager else null



func get_in_game_vehicles() -> Array[RPGVehicle]:
	return entity_manager.get_in_game_vehicles() if entity_manager else []



func get_overlapped_vehicle_number(pos: Vector2i) -> int:
	return entity_manager.get_overlapped_vehicle_number(pos) if entity_manager else 0



func add_weather_scene(id: int, weather_scene: Node) -> void:
	if entity_manager: entity_manager.add_weather_scene(id, weather_scene)



func remove_weather_scene(id: int) -> void:
	if entity_manager: entity_manager.remove_weather_scene(id)



func get_particle_container() -> Node2D:
	return entity_manager.get_particle_container() if entity_manager else null



func get_tile_position(tile: Vector2i) -> Vector2:
	return layout_helper.get_tile_position(tile) if layout_helper else Vector2.ZERO



func set_event_position(target: Node, tile: Vector2i, direction: LPCCharacter.DIRECTIONS, center_camera: bool = false, is_global_position: bool = false) -> void:
	if entity_manager: entity_manager.set_event_position(target, tile, direction, center_camera, is_global_position)



func set_event_direction(target: Variant, direction: LPCCharacter.DIRECTIONS) -> void:
	if entity_manager: entity_manager.set_event_direction(target, direction)
#endregion



#region Math & Passability Wrappers
func map_to_local(grid_position: Vector2i) -> Vector2i:
	return layout_helper.map_to_local(grid_position) if layout_helper else Vector2i.ZERO



func local_to_map(local_position: Vector2i) -> Vector2i:
	return layout_helper.local_to_map(local_position) if layout_helper else Vector2i.ZERO



func get_map_size_info() -> Dictionary:
	return layout_helper.get_map_size_info() if layout_helper else {}



func get_used_rect(add_margin: bool = true) -> Rect2i:
	return layout_helper.get_used_rect(add_margin) if layout_helper else Rect2i()



func get_ingame_rect() -> Rect2i:
	return layout_helper.get_ingame_rect() if layout_helper else Rect2i()



func get_map_size() -> Vector2i:
	return layout_helper.get_map_size() if layout_helper else Vector2i.ZERO



func get_map_size_in_tiles() -> Vector2i:
	return layout_helper.get_map_size_in_tiles() if layout_helper else Vector2i.ZERO



func get_wrapped_tile(tile: Vector2i) -> Vector2i:
	return layout_helper.get_wrapped_tile(tile) if layout_helper else Vector2i.ZERO



func get_wrapped_position(pos: Vector2) -> Vector2:
	return layout_helper.get_wrapped_position(pos) if layout_helper else Vector2.ZERO



func get_tile_from_position(pos: Vector2) -> Vector2i:
	return layout_helper.get_tile_from_position(pos) if layout_helper else Vector2i.ZERO



func update_event_position_in_layout(event: Node) -> void:
	if map_layout: map_layout.update_event_position(event)



func get_events_near_position(pos: Vector2) -> Array:
	return map_layout.get_events_near_position(pos) if map_layout else []



func is_passable(tile_position: Vector2i, player_direction: int, ignore_node: Node = null, ignore_debug: bool = false) -> bool:
	return passability_helper.is_passable(tile_position, player_direction, ignore_node, ignore_debug) if passability_helper else false



func has_any_region_passable_in(tile: Vector2i) -> bool:
	var global_p = map_to_local(tile)
	for shape: CollisionShape2D in ingame_event_regions:
		if shape.has_meta("region_data") and shape.shape and not shape.is_disabled():
			var region_data: EventRegion = shape.get_meta("region_data")
			if region_data.always_passable:
				var shape_local_p = shape.to_local(global_p)
				if shape.shape.get_rect().has_point(shape_local_p):
					return true
	return false


func has_any_region_impassable_in(tile: Vector2i) -> bool:
	var global_p = map_to_local(tile)
	for shape: CollisionShape2D in ingame_event_regions:
		if shape.has_meta("type") and shape.get_meta("type") == "collision_region" and shape.shape and not shape.is_disabled():
			var shape_local_p = shape.to_local(global_p)
			if shape.shape.get_rect().has_point(shape_local_p):
				return true
	return false


func is_tile_passable_from_direction(tile_position: Vector2i, player_direction: int, invert: bool = false) -> bool:
	return passability_helper.is_tile_passable_from_direction(tile_position, player_direction, invert) if passability_helper else true



func get_cell_data(tile_position: Vector2i) -> Dictionary:
	return passability_helper.get_cell_data(tile_position) if passability_helper else {}



func can_move_to_direction(tile_position: Vector2i, player_direction: int, ignore_is_blocked_tile: bool = false) -> bool:
	return passability_helper.can_move_to_direction(tile_position, player_direction, ignore_is_blocked_tile) if passability_helper else false



func is_tile_block(tile_position: Vector2i, default_value: bool = true) -> bool:
	return passability_helper.is_tile_block(tile_position, default_value) if passability_helper else default_value



func can_move_over_terrain(tile: Vector2i, terrains: PackedStringArray) -> bool:
	return passability_helper.can_move_over_terrain(tile, terrains) if passability_helper else false



func get_custom_data_layer_names() -> PackedStringArray:
	return passability_helper.get_custom_data_layer_names() if passability_helper else PackedStringArray()



func get_tile_terrain_name(tile: Vector2i) -> PackedStringArray:
	return passability_helper.get_tile_terrain_name(tile) if passability_helper else PackedStringArray()
#endregion
