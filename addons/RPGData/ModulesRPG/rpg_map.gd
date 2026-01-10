@tool
@icon("res://addons/rpg_scene_manager/Assets/Images/map.png")
class_name RPGMap
extends Node2D


func get_class(): return "RPGMap"


class IngameEvent:
	var map_id: int
	var event_id: int
	var relationship: GameRelationship
	var event: RPGEvent
	var character_data: RPGLPCCharacter
	var page_id: int
	var lpc_event: Variant
	
	func _init(p_event: RPGEvent, p_character_data: RPGLPCCharacter, p_lpc_event: Variant, p_map_id: int, p_relationship: GameRelationship = null, p_page_id: int = 1) -> void:
		event = p_event
		character_data = p_character_data
		lpc_event = p_lpc_event
		if event:
			event_id = event.id
		map_id = p_map_id
		relationship = p_relationship
		page_id = p_page_id
	
	func update_page(new_page: RPGEventPage, new_character_data: RPGLPCCharacter) -> void:
		page_id = new_page.page_id
		character_data = new_character_data

class IngameExtractionEvent:
	var event: RPGExtractionItem
	var scene: Variant
	var extraction_event: GameExtractionItem
	
	func _init(p_event: RPGExtractionItem, p_scene: Variant, p_extraction_event: GameExtractionItem = null) -> void:
		event = p_event
		scene = p_scene
		
		if p_extraction_event:
			extraction_event = p_extraction_event
		else:
			extraction_event = GameExtractionItem.new(event.id)


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
		_set_child_opacity(self, false)


## Change the opacity of the canvases for better visibility of the children
@export_range(0.0, 1.0, 0.01) var canvas_opacity: float = 1.0:
	set(value):
		canvas_opacity = value
		if event_canvas:
			event_canvas.modulate = Color(1.0, 1.0, 1.0, canvas_opacity)
		if extraction_event_canvas:
			extraction_event_canvas.modulate = Color(1.0, 1.0, 1.0, canvas_opacity)
		if enemy_spawn_canvas:
			enemy_spawn_canvas.modulate = Color(1.0, 1.0, 1.0, canvas_opacity)
		if event_region_canvas:
			event_region_canvas.modulate = Color(1.0, 1.0, 1.0, canvas_opacity)

## Copy the map ID to the clipboard
@export var copy_map_id_into_clipboard: bool = false:
	set(value):
		if value:
			DisplayServer.clipboard_set(str(internal_id))
			print("Map id %s copy into clipboard" % internal_id)


@export_category("Map Fields")
## Music that will be played when playing this map
@export var map_bgm: AudioStream


## Changes the current color modulation for this map (Default will be White = No Change)
@export var map_modulate: Color = Color.WHITE:
	set(color):
		map_modulate = color
		update_modulate_color()


## Makes the map infinitely scrollable horizontally (useful for world maps)
@export var infinite_horizontal_scroll: bool = false

## Makes the map infinitely scrollable vertically (useful for world maps)
@export var infinite_vertical_scroll: bool = false


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
		_update_shadows()
		notify_property_list_changed()


## Enable integrated Day/Night usage (configurable in [System] within the database). Disabling this
## option will turn off the Day/Night cycle and instead use the fixed shadow component integrated
## into the map. In Day/Night mode, you can set the starting time for this map, 
## or leave it at -1 to use the current time recorded by the Day/Night system.
@export var use_dynamic_day_night: bool = true:
	set(value):
		use_dynamic_day_night = value
		if DayNightManager:
			if use_dynamic_day_night:
				DayNightManager.set_enabled()
			else:
				DayNightManager.set_disabled()
		_update_shadows()
		notify_property_list_changed()


## In Day/Night mode, you can set the starting time for this map, 
## or leave it at -1 to use the current time recorded by the Day/Night system.
@export_range(-1, 24, 1) var dynamic_day_night_hour: int = 13:
	set(value):
		dynamic_day_night_hour = value
		if DayNightManager:
			DayNightManager.set_time(dynamic_day_night_hour)
		_update_shadows()


## Set the shadow parameters.
@export var shadow_parameters: ShadowComponent:
	set(value):
		shadow_parameters = value
		_update_shadows()

## Preview Shadow in editor
@export var preview_shadows_in_editor: bool = false:
	set(value):
		preview_shadows_in_editor = value
		_update_shadows()
#endregion


#region Initial variables and exports using in the editor
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
var event_canvas: Node2D
var extraction_event_canvas: Node2D
var keot_canvas: Node2D
var enemy_spawn_canvas: Node2D
var event_region_canvas: Node2D
var cursor_canvas: Node2D
var can_add_events: bool = false
var resize_controls = []
var max_tiles: Vector2i
var shadow_need_refresh: bool = false
var map_need_refresh: bool = false
var force_update_shadow: float = 0.0
var force_update_shadow_timer: float = 15
var _keots_timer: float = 0.0
const _KAOT_MAX_TIMER = 0.25

var force_show_regions: bool = false

var preview_map_only_enabled: bool = false

var particle_container: Node2D

var editor_icons = {}
var editor_canvas_modulate: CanvasModulate
var current_parent: MainScene
var editor_shadow_canvas: Node2D

var event_preview_textures: Dictionary = {}
var extraction_event_preview_textures: Dictionary = {}

var need_refresh: bool = false # Used to refresh events in map

var current_in_game_enemy_spawn_region: EnemySpawnRegion # used in game mode to define wich region is active

var hexagon_cache = {}

@export var _baked_keot_data: Dictionary = {}
@export var events := RPGEvents.new()
@export var extraction_events: Array[RPGExtractionItem] = []
@export var regions: Array[EnemySpawnRegion] = []
@export var event_regions: Array[EventRegion] = []
@export var internal_id: int
@export var current_edit_button_pressed: int = -1
var ingame_event_regions: Array[CollisionShape2D] = []

@onready var MAP_LAYERS: Dictionary = {}
#endregion


#region Other Variables
var pathfinder: AStarPathfinder
var event_offset: Vector2
var shadow_layer: Sprite2D
var shadow_viewport: SubViewport
var mask_shadow_viewport: SubViewport
var shadow_compose: SubViewport
var shadow_container: CanvasGroup
var cached_environment_textures: Dictionary = {}
var shadows: Dictionary = {
	"tiles": {},
	"vehicles": {},
	"events": {},
	"players": {}
}
var current_ingame_events: Dictionary[int, IngameEvent] = {}
var current_ingame_extraction_events: Dictionary[int, IngameExtractionEvent] = {}
var current_ingame_vehicles: Array[RPGVehicle] = []
var current_ingame_weather_scenes: Dictionary = {}
var moving_event: bool = false
var rect_size_cache: Dictionary = {}
var last_extraction_event_pasted_id: int

var map_layout: MapLayout
#endregion


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

	_set_child_opacity(self, true)
	
	if Engine.is_editor_hint():
		if !preview_map_only_enabled:
			_start_editor_mode()
		else:
			_start_preview_mode()
	else:
		if !preview_map_only_enabled:
			_start_game_mode()
			pass
		else:
			_start_preview_mode()
	
	update_modulate_color()
	update_bgm()


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


func _start_editor_mode() -> void:
	editor_icons.player_start_position = preload("res://addons/RPGMap/Assets/Images/player_start_position.png")
	editor_icons.land_transport_start_position = preload("res://addons/RPGMap/Assets/Images/land_transport_start_position.png")
	editor_icons.sea_transport_start_position = preload("res://addons/RPGMap/Assets/Images/sea_transport_start_position.png")
	editor_icons.air_transport_start_position = preload("res://addons/RPGMap/Assets/Images/air_transport_start_position.png")
	editor_icons.other = [] # Store textures for event previews so they can be rendered smoothly.
	editor_icons.keot_tile = preload("uid://cjfab1wyp2rf0")
	call_deferred("create_canvas")
	
	editor_canvas_modulate = CanvasModulate.new()
	add_child(editor_canvas_modulate)
	
	if !internal_id:
		internal_id = generate_16_digit_id()
		notify_property_list_changed()
	
	var edited_scene_root = get_tree().get_edited_scene_root()
	
	child_entered_tree.connect(_on_child_entered_tree)
	
	if preview_shadows_in_editor and draw_shadows:
		_update_shadows()
	
	var timer = Timer.new()
	timer.wait_time = 0.1
	timer.timeout.connect(func():
		if shadow_need_refresh:
			shadow_need_refresh = false
			_create_shadows()
		elif force_update_shadow > 0:
			force_update_shadow -= 1
			if force_update_shadow <= 0:
				force_update_shadow = force_update_shadow_timer
				_create_shadows()
			
	)
	add_child(timer)
	timer.start()
	
	for child in get_children():
		if not child is TileMapLayer: continue
		
		if not child.changed.is_connected(_keots_need_refresh):
			child.changed.connect(_keots_need_refresh)


func _keots_need_refresh() -> void:
	_keots_timer = _KAOT_MAX_TIMER


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


func _start_preview_mode() -> void:
	map_layout = MapLayout.new()
	GameManager.current_map = self
	editor_icons.player_start_position = preload("res://addons/RPGMap/Assets/Images/player_start_position.png")
	editor_icons.land_transport_start_position = preload("res://addons/RPGMap/Assets/Images/land_transport_start_position.png")
	editor_icons.sea_transport_start_position = preload("res://addons/RPGMap/Assets/Images/sea_transport_start_position.png")
	editor_icons.air_transport_start_position = preload("res://addons/RPGMap/Assets/Images/air_transport_start_position.png")
	editor_icons.other = []
	call_deferred("create_canvas", true)


func _start_game_mode() -> void:
	map_layout = MapLayout.new()
	GameManager.current_map = self
	visible = false
	pathfinder = AStarPathfinder.new(self)
	event_offset = Vector2(tile_size.x * 0.5, tile_size.y - 4)
	# Check if scene_main needs to be set up.
	var parent = get_tree().get_first_node_in_group("start_scene_main")
	if not parent or parent is not MainScene:
		await get_tree().process_frame
		var main_scene = "res://Scenes/main_scene.tscn"
		var scn = load(main_scene).instantiate()
		scn.is_test_map = true
		scn.current_map = self
		get_parent().add_child(scn)
		#parent = scn
		# add map to parent
		#parent.set_map(self)
		queue_free()
		return

	# add vehicles
	_setup_vehicles()
	# add events
	_setup_events()
	# add extraction events
	_setup_extraction_events()
	# add commond evests
	_setup_common_events()
	# add player:
	parent.setup_player()
	# set shadows
	if draw_shadows:
		_create_shadows()
	
	# Set camera limits
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
	
	# Set Invisible Exterior Walls
	var body := StaticBody2D.new()
	body.collision_layer = int(pow(2, 3))
	#body.collision_mask = int(pow(2, 0)) | int(pow(2, 2))
	body.name = "Walls"
	add_child(body)
	if !infinite_vertical_scroll:
		# Top Wall
		var top_wall: CollisionShape2D = CollisionShape2D.new()
		top_wall.shape = RectangleShape2D.new()
		top_wall.shape.size = Vector2(rect.size.x * 2, 32)
		var p = Vector2i(Vector2(rect.position.x, rect.position.y) / Vector2(tile_size)) * tile_size - Vector2i(0, 16)
		top_wall.position = p
		top_wall.name = "TopWall"
		body.add_child(top_wall)
		# Bottom Wall
		var bottom_wall: CollisionShape2D = CollisionShape2D.new()
		bottom_wall.shape = RectangleShape2D.new()
		bottom_wall.shape.size = Vector2(rect.size.x * 2, 32)
		p = Vector2i(Vector2(rect.position.x, rect.position.y + rect.size.y) / Vector2(tile_size)) * tile_size + Vector2i(0, 16)
		bottom_wall.position = p
		bottom_wall.name = "BotomWall"
		body.add_child(bottom_wall)
		
	if !infinite_horizontal_scroll:
		# Left Wall
		var left_wall: CollisionShape2D = CollisionShape2D.new()
		left_wall.shape = RectangleShape2D.new()
		left_wall.shape.size = Vector2(32, rect.size.y * 2)
		var p = Vector2i(Vector2(rect.position.x, rect.position.y) / Vector2(tile_size)) * tile_size - Vector2i(16, 0)
		left_wall.position = p
		left_wall.name = "LeftWall"
		body.add_child(left_wall)
		# Right Wall
		var right_wall: CollisionShape2D = CollisionShape2D.new()
		right_wall.shape = RectangleShape2D.new()
		right_wall.shape.size = Vector2(32, rect.size.y * 2)
		p = Vector2i(Vector2(rect.position.x + rect.size.x, rect.position.y) / Vector2(tile_size)) * tile_size + Vector2i(16, 0)
		right_wall.position = p
		right_wall.name = "RightWall"
		body.add_child(right_wall)
	
	var area: Area2D = Area2D.new()
	area.name = "EventMonitor"
	area.collision_layer = int(pow(2, 5))
	area.collision_mask = int(pow(2, 0)) | int(pow(2, 2))
	area.body_shape_entered.connect(_on_event_monitor_body_entered.bind(area))
	area.body_shape_exited.connect(_on_event_monitor_body_exited.bind(area))
	add_child(area)
	
	# Create region events
	_create_region_events(body, area)
	
	# Create enemy spawn areas
	_create_enemy_spawn_areas(area)
	
	# create particle container
	_create_particle_container()
	
	# update map_visited stat
	var game_state = GameManager.game_state
	if game_state:
		var stats = game_state.stats.map_visited
		if not internal_id in stats:
			stats[internal_id] = true
	
	# Set day hour if using day / night system
	if use_dynamic_day_night:
		DayNightManager.continue_from_time(dynamic_day_night_hour)
	
	
	# Clear repeat if map is small
	var screen_size = Vector2i(
		ProjectSettings.get_setting("display/window/size/viewport_width"),
		ProjectSettings.get_setting("display/window/size/viewport_height")
	)
	if get_used_rect(false).size < screen_size or not (infinite_vertical_scroll or infinite_horizontal_scroll):
		GameManager.clear_map_repeating()
	else:
		GameManager.enable_map_repeating()
	
	# If test mode,  load command list into the interpreter as automatic event
	if OS.is_debug_build():
		var _test_commands_file_path = "res://addons/RPGMap/Temp/_temp_event_commands.res"
		if ResourceLoader.exists(_test_commands_file_path) and not GameManager._test_commands_processed:
			var res: TestCommandEvent = load(_test_commands_file_path)
			if not res.commands.is_empty():
				var automatic_event: Array[Dictionary] = [ {"obj": null, "commands": res.commands, "id": "_test_commands"}]
				GameInterpreter.start_event(GameManager.current_player, res.commands)
			GameManager._test_commands_processed = true
	
	var keots_area = KeotSystem.new()
	add_child(keots_area)
	keots_area.build_from_cache(self, _baked_keot_data)
	
	visible = true


func _on_event_monitor_body_entered(body_rid: RID, body: Node2D, body_shape_index: int, local_shape_index: int, main_area: Area2D) -> void:
	if body.is_in_group("vehicle") and not body.is_enabled:
		return
		
	var shape_owner_id = main_area.shape_find_owner(local_shape_index)
	var shape_node = main_area.shape_owner_get_owner(shape_owner_id)
	
	if "force_locked" in body and typeof(body.force_locked) == TYPE_BOOL:
		body.force_locked = true
	
	if body.has_method("is_processin_moving"):
		while body.is_processin_moving():
			await get_tree().process_frame
	
	if shape_node and shape_node.has_meta("type") and shape_node.has_meta("region_data"):
		var action_type = shape_node.get_meta("type")
		var region_data = shape_node.get_meta("region_data")
		
		if action_type == "event_region": # Process Event Region on entry
			var reg := (region_data as EventRegion)
			var triggers = reg.triggers
			
			# Chack Valid Target
			var is_in_player_group = body.is_in_group("player")
			var is_in_event_group = body.is_in_group("event")
			var is_valid: bool = false

			if is_in_player_group and -1 in triggers:
				is_valid = true
			
			if not is_valid and body and body is LPCBase or body is EmptyLPCEvent or body is GenericLPCEvent:
				if (
					"current_event_page" in body and
					body.current_event_page and
					body.current_event_page is RPGEventPage
				):
					is_valid = body.current_event_page.id in triggers
			
			if not is_valid:
				if "force_locked" in body and typeof(body.force_locked) == TYPE_BOOL:
					body.force_locked = false
				return
			
			var commands: Array[RPGEventCommand]
			
			# Call a Common Event
			if reg.event_mode == reg.EventMode.COMMON_EVENTS:
				var event_id = reg.entry_common_event
				if RPGSYSTEM.database.common_events.size() > event_id and event_id > 0:
					var ev = RPGSYSTEM.database.common_events[event_id]
					commands = ev.list
			
			# Call a Caller Event
			elif reg.event_mode == reg.EventMode.CALLER_EVENTS:
				var event_id = reg.trigger_caller_event_on_entry
				if event_id > 0:
					var ev = get_in_game_event_by_pos(event_id)
					if ev and "current_event_page" in ev and ev.current_event_page is RPGEventPage:
						var event_page: RPGEventPage = ev.current_event_page
						if event_page.launcher == event_page.LAUNCHER_MODE.CALLER:
							commands = event_page.list
				
			if commands:
				if body.has_method("_reset"):
					body._reset(true)
				GameInterpreter.start_event(body, commands, true)
				
		elif action_type == "enemy_spawn_area" and (body.is_in_group("player") or body.is_in_group("vehicle")): # Process Enemy Spawn Region
			current_in_game_enemy_spawn_region = region_data
	
	if "force_locked" in body and typeof(body.force_locked) == TYPE_BOOL:
		body.force_locked = false


func _on_event_monitor_body_exited(body_rid: RID, body: Node2D, body_shape_index: int, local_shape_index: int, main_area: Area2D) -> void:
	if body.is_in_group("vehicle") and not body.is_enabled:
		return
		
	var shape_owner_id = main_area.shape_find_owner(local_shape_index)
	var shape_node = main_area.shape_owner_get_owner(shape_owner_id)
	
	if shape_node and shape_node.has_meta("type") and shape_node.has_meta("region_data"):
		var action_type = shape_node.get_meta("type")
		var region_data = shape_node.get_meta("region_data")
		
		if action_type == "event_region": # Process Event Region on exit
			var reg := (region_data as EventRegion)
			#var ev = RPGSYSTEM.database.common_events[reg.entry_common_event]
			var commands: Array[RPGEventCommand]
			
			# Call a Common Event
			if reg.event_mode == reg.EventMode.COMMON_EVENTS:
				var event_id = reg.exit_common_event
				if RPGSYSTEM.database.common_events.size() > event_id and event_id > 0:
					var ev = RPGSYSTEM.database.common_events[event_id]
					commands = ev.list
			
			# Call a Caller Event
			elif reg.event_mode == reg.EventMode.CALLER_EVENTS:
				var event_id = reg.trigger_caller_event_on_exit
				if event_id > 0:
					var ev = get_in_game_event_by_pos(event_id)
					if ev and "current_event_page" in ev and ev.current_event_page is RPGEventPage:
						var event_page: RPGEventPage = ev.current_event_page
						if event_page.launcher == event_page.LAUNCHER_MODE.CALLER:
							commands = event_page.list
				
			if commands:
				GameInterpreter.start_event(body, commands, true)
				
		elif action_type == "enemy_spawn_area" and (body.is_in_group("player") or body.is_in_group("vehicle")): # Process Enemy Spawn Region
			if current_in_game_enemy_spawn_region and current_in_game_enemy_spawn_region == region_data:
				current_in_game_enemy_spawn_region = null


func _create_region_events(collision_body: StaticBody2D, collision_area: Area2D) -> void:
	for region: EventRegion in event_regions:
		var obj: CollisionShape2D = CollisionShape2D.new()
		obj.shape = RectangleShape2D.new()
		obj.shape.size = region.rect.size * tile_size
		var p = region.rect.position * tile_size + Vector2i(obj.shape.size / 2)
		obj.position = p
		obj.name = "EventRegion#%s" % region.id
		obj.z_index = 1
		obj.set_meta("region_data", region)
		var region_is_disabled = region.activation_mode == EventRegion.ActivationMode.SWITCH and not GameManager.get_switch(region.activation_switch_id)
		obj.set_disabled(region_is_disabled)
		if not region.can_entry:
			obj.set_meta("type", "collision_region")
			collision_body.add_child(obj)
		else:
			obj.set_meta("type", "event_region")
			collision_area.add_child(obj)
		ingame_event_regions.append(obj)


func _create_enemy_spawn_areas(collision_area: Area2D) -> void:
	for region: EnemySpawnRegion in regions:
		var obj: CollisionShape2D = CollisionShape2D.new()
		obj.shape = RectangleShape2D.new()
		obj.shape.size = region.rect.size * tile_size
		var p = region.rect.position * tile_size + Vector2i(obj.shape.size / 2)
		obj.position = p
		obj.name = "EnemyEventRegion#%s" % region.id
		obj.z_index = 1
		
		obj.set_meta("type", "enemy_spawn_area")
		obj.set_meta("region_data", region)
		collision_area.add_child(obj)


func _update_spawn_region(index: int, region: EnemySpawnRegion) -> void:
	if index >= 0 and index < regions.size():
		regions[index] = region
		refresh_canvas()


func _create_particle_container() -> void:
	particle_container = Node2D.new()
	particle_container.name = "ParticleContainer"
	particle_container.z_index = 1
	add_child(particle_container)


func get_particle_container() -> Node2D:
	return particle_container

func set_force_update_shadow(enable_force_update_timer: bool) -> void:
	force_update_shadow = force_update_shadow_timer if enable_force_update_timer else 0
	shadow_need_refresh = !enable_force_update_timer


func _update_shadows() -> void:
	if draw_shadows:
		if Engine.is_editor_hint() and is_node_ready() and preview_shadows_in_editor and draw_shadows:
			shadow_need_refresh = true
		elif !Engine.is_editor_hint() and is_node_ready():
			_create_shadows()
		elif editor_shadow_canvas:
			editor_shadow_canvas.queue_free()
			editor_shadow_canvas = null
	else:
		if editor_shadow_canvas:
			editor_shadow_canvas.queue_free()
			editor_shadow_canvas = null


func _perform_shadow_update() -> void:
	if has_meta("_disable_shadow"):
		return
	
	if Engine.is_editor_hint():
		DayNightManager.day_night_config = RPGSYSTEM.database.system.day_night_config.clone(true)
		
	var all_shadows = []
	for item in shadows.values():
		for shadow_data in item.values():
			if "main_node" in shadow_data and "visible" in shadow_data.main_node:
				if not shadow_data.main_node.visible:
					continue
			all_shadows.append(shadow_data)
	var used_rect = get_used_rect(false)
	
	var shadow_canvas = GameManager.get_dynamic_shadows_from_main_scene()
	if not shadow_canvas:
		if not editor_shadow_canvas:
			var scn = preload("res://Scenes/ShadowCompose/shadow_compose.tscn")
			var ins = scn.instantiate()
			editor_shadow_canvas = ins
			editor_shadow_canvas.z_as_relative = false
			editor_shadow_canvas.z_index = 4000
			editor_shadow_canvas.in_editor_map = self
			add_child(editor_shadow_canvas)
		
		shadow_canvas = editor_shadow_canvas
	
	if shadow_canvas:
		shadow_canvas.call_deferred("set_current_map_rect", used_rect)
		shadow_canvas.set_deferred("shadow_data", all_shadows)
		if shadow_parameters:
			shadow_canvas.set_deferred("shadow_component", shadow_parameters)


func _create_shadows() -> void:
	if Engine.is_editor_hint() and (not preview_shadows_in_editor or not draw_shadows):
		if editor_shadow_canvas:
			editor_shadow_canvas.queue_free()
			editor_shadow_canvas = null
		return
	_create_cell_shadows()
	_create_dynamic_shadows()
	_perform_shadow_update()


func _create_cell_shadows() -> void:
	var original_layer: TileMapLayer = MAP_LAYERS.environment
	var used_cells = original_layer.get_used_cells()
	shadows.tiles.clear()
	for cell in used_cells:
		var tile_coord = map_to_local(cell)
		var source_id = original_layer.get_cell_source_id(cell)
		if source_id != -1:
			var atlas_coord = original_layer.get_cell_atlas_coords(cell)
			var source: TileSetSource = original_layer.tile_set.get_source(source_id)
			if source:
				var tile_data: TileData = source.get_tile_data(atlas_coord, 0)
				if tile_data and tile_data.has_custom_data("Cast Shadow"):
					var cast_shadow: RPGMapCastShadow = tile_data.get_custom_data("Cast Shadow")
					if cast_shadow:
						var shadow_data = _draw_shadow(original_layer, cell, cast_shadow, tile_data.texture_origin)
						shadows.tiles[cell] = shadow_data


func _create_dynamic_shadows() -> void:
	# vehicle shadows
	shadows.vehicles.clear()
	for vehicle in current_ingame_vehicles:
		var vehicle_shadow_data = vehicle.get_shadow_data()
		if vehicle_shadow_data:
			shadows.vehicles[vehicle.get_rid().get_id()] = vehicle_shadow_data
	
	# Player/s shadows:
	shadows.players.clear()
	var nodes = get_tree().get_nodes_in_group("player")
	for node in nodes:
		if node.has_method("get_shadow_data"):
			var node_shadow_data = node.get_shadow_data()
			var rid = node.get_rid().get_id()
			if node_shadow_data and node.visible and node.modulate.a > 0:
				shadows.players[rid] = node_shadow_data
	
	# Event/s shadows:
	shadows.events.clear()
	for ev: IngameEvent in current_ingame_events.values():
		if not ev: continue
		if ev.lpc_event:
			if ev.lpc_event.is_queued_for_deletion() or ev.lpc_event.has_meta("_disable_shadow"):
				continue
			var node = ev.lpc_event
			if node.has_method("get_shadow_data"):
				var node_shadow_data = node.get_shadow_data()
				var rid = node.get_rid()
				if node_shadow_data and node.visible and node.modulate.a > 0:
					shadows.events[rid] = node_shadow_data
	
	# Extraction Event/s shadows:
	for ev: IngameExtractionEvent in current_ingame_extraction_events.values():
		if ev.scene:
			if ev.scene.is_queued_for_deletion() or ev.scene.has_meta("_disable_shadow"):
				continue
			var node = ev.scene
			if node.has_method("get_shadow_data"):
				var node_shadow_data = node.get_shadow_data()
				var rid = node.get_rid()
				if node_shadow_data and node.visible and node.modulate.a > 0:
					shadows.events[rid] = node_shadow_data


func _draw_shadow(layer: TileMapLayer, cell: Vector2i, shadow_info: RPGMapCastShadow, offset: Vector2) -> Dictionary:
	var atlas_source = layer.tile_set.get_source(layer.get_cell_source_id(cell))
	var atlas_coords = layer.get_cell_atlas_coords(cell)
	var texture_region = atlas_source.get_tile_texture_region(atlas_coords)
	if shadow_info:
		texture_region.size *= Vector2i(shadow_info.width, shadow_info.height)

	# Calculate the correct tile position
	var tile_position = layer.map_to_local(cell) - tile_size * 0.5 - offset + Vector2(0, 2)

	# Create Shadow Sprite
	var key = "%s_%s" % [atlas_source.texture.get_rid().get_id(), texture_region]
	var shadow
	if !cached_environment_textures.has(key):
		var tex = ImageTexture.create_from_image(atlas_source.texture.get_image().get_region(texture_region))
		shadow = {
			"texture": tex,
			"position": tile_position,
			"cell": cell,
			"feet_offset": shadow_info.feet_offset
		}
		cached_environment_textures[key] = tex
	else:
		shadow = {
			"texture": cached_environment_textures[key],
			"position": tile_position,
			"cell": cell,
			"feet_offset": shadow_info.feet_offset
		}

	return shadow
	
	#var sprite_name = "ShadowSprite%s" % cell
	#var shadow_sprite = Sprite2D.new()
	#shadow_sprite.name = sprite_name
	#shadow_sprite.centered = true
	#shadow_sprite.offset = Vector2(texture_region.size.x * 0.5, -texture_region.size.y * 0.5)
	#shadow_sprite.texture = atlas_source.texture
	#shadow_sprite.region_enabled = true
	#shadow_sprite.region_rect = texture_region
#
	#shadow_sprite.position = tile_position - shadow_sprite.offset
	#
	#return shadow_sprite


func _process(delta: float) -> void:
	if draw_shadows:
		if Engine.is_editor_hint():
			if preview_shadows_in_editor:
				if force_update_shadow <= 0:
					force_update_shadow = 2
	
	if need_refresh:
		refresh_events()
		need_refresh = false
	
	_update_depleted_items(delta)
	
	if _keots_timer > 0.0:
		_keots_timer -= delta
		if _keots_timer <= 0.0:
			_bake_keot_data_fast()
			keot_canvas.queue_redraw()
	
	if cursor_canvas:
		if _is_selected_in_editor():
			cursor_canvas.visible = true
			cursor_canvas.queue_redraw()
		else:
			cursor_canvas.visible = false
	

func _is_selected_in_editor() -> bool:
	if Engine.is_editor_hint():
		var selection = EditorInterface.get_selection()
		if not selection:
			return false
		
		var selected_nodes = selection.get_selected_nodes()
		return self in selected_nodes and selected_nodes.size() == 1
	
	return false


func _is_mouse_inside_viewport() -> bool:
	if not Engine.is_editor_hint():
		return false
	
	var viewport_control = EditorInterface.get_editor_viewport_2d()
	if not viewport_control:
		return false
	
	var local_mouse = viewport_control.get_mouse_position()
	
	var viewport_rect = Rect2(Vector2.ZERO, viewport_control.size)
	
	return viewport_rect.has_point(local_mouse)


func _update_depleted_items(delta: float):
	for event: IngameExtractionEvent in current_ingame_extraction_events.values():
		if event.extraction_event.is_depleted():
			event.extraction_event.current_respawn_time -= delta

			if event.extraction_event.current_respawn_time <= 0:
				event.extraction_event.current_respawn_time = 0
				event.extraction_event.current_uses = event.event.max_uses
				event.scene.start(false) # start with animations


func _physics_process(delta: float) -> void:
	if draw_shadows and not Engine.is_editor_hint():
		_create_dynamic_shadows()
		_perform_shadow_update()


func _setup_vehicles() -> void:
	var ids = [
		"land_transport_start_position",
		"sea_transport_start_position",
		"air_transport_start_position"
	]
	for vehicle in current_ingame_vehicles:
		if vehicle and is_instance_valid(vehicle):
			vehicle.queue_free()
			
	GameManager.current_map_vehicles = current_ingame_vehicles
	current_ingame_vehicles.clear()
	for id in ids:
		var data: RPGMapPosition
		if Engine.is_editor_hint():
			data = RPGSYSTEM.database.system.get(id)
		else:
			data = GameManager.game_state.get(id)
		if data:
			if data.map_id == internal_id:
				var vehicle_id = id.replace("_start_position", "")
				var vehicle_path: String = RPGSYSTEM.database.system.get(vehicle_id)
				if ResourceLoader.exists(vehicle_path):
					var start_position = data.position
					var real_pos = Vector2i(map_to_local(start_position))
					var scn = ResourceLoader.load(vehicle_path).instantiate()
					#var target_position = map_to_local(start_position)
					#target_position = target_position.snapped(tile_size)
					#scn.position = Vector2(target_position) + tile_size * 0.5
					add_child(scn)
					set_event_position(scn, Vector2i(start_position.x, start_position.y), LPCCharacter.DIRECTIONS.DOWN)
					current_ingame_vehicles.append(scn)
					if not scn.is_in_group("vehicle"):
						scn.add_to_group("vehicle")
					#scn.fix_offsets(false)


func _clear_all_ingame_events() -> void:
	for ev: IngameEvent in current_ingame_events.values():
		if not ev: continue
		if ev.lpc_event:
			ev.lpc_event.queue_free()
	current_ingame_events.clear()


func _clear_all_ingame_extraction_events() -> void:
	for ev: IngameExtractionEvent in current_ingame_extraction_events.values():
		if ev.scene:
			ev.scene.queue_free()
	current_ingame_extraction_events.clear()


func _setup_events() -> void:
	_clear_all_ingame_events()
	GameManager.current_map_events = current_ingame_events
	var automatic_events: Array[Dictionary] = []
	
	for ev: RPGEvent in events.get_events():
		ev.initialize_page_ids()
		var interpreter_id = "event_" + str(ev.id)
		var page: RPGEventPage = ev.get_active_page()
		if page:
			page.id = ev.id
			var ingame_event = _create_ingame_event(ev, page)
			if ingame_event:
				current_ingame_events[ev.id] = ingame_event
				
				# Recopilar eventos automáticos
				if page.launcher == RPGEventPage.LAUNCHER_MODE.AUTOMATIC:
					automatic_events.append({"obj": ingame_event.lpc_event, "commands": page.list, "id": interpreter_id})
				elif page.launcher == RPGEventPage.LAUNCHER_MODE.PARALLEL:
					GameInterpreter.register_interpreter(ingame_event.lpc_event, page.list, true, interpreter_id)
	
	if not automatic_events.is_empty():
		GameInterpreter.auto_start_automatic_events(automatic_events)


func _setup_extraction_events() -> void:
	_clear_all_ingame_extraction_events()
	GameManager.current_map_extraction_events = current_ingame_extraction_events
	
	for ev: RPGExtractionItem in extraction_events:
		var ingame_extraction_event = _create_ingame_extraction_event(ev)
		if ingame_extraction_event:
			current_ingame_extraction_events[ev.id] = ingame_extraction_event


func refresh_events() -> void:
	for ev: IngameEvent in current_ingame_events.values():
		if not ev: continue
		if ev.lpc_event:
			var page = ev.lpc_event.current_event.get_active_page()
			if page and page != ev.lpc_event.current_event_page:
				if not ev.event.legacy_mode:
					_handle_legacy_refresh(ev, page)
				else:
					_handle_modern_refresh(ev, page)
	
	#for obj: Dictionary in refresh_event_list:
		#GameInterpreter.remove_interpreter(obj.event)
		#var ev: IngameEvent = obj.event
		#if ev:
			#var page: RPGEventPage = obj.new_page
			#page.id = ev.event.id
			#current_ingame_events.erase(ev.lpc_event.current_event.id)
			#var entity_id = str(ev.lpc_event.get_rid()) + "-Page#" + str(obj.page_id)
			#GameInterpreter.remove_interpreter_by_id(entity_id)
			#ev.page_id = page.page_id
			#_load_event(ev, page)
	#
	#  refresh ingame_event_regions
	for obj: CollisionShape2D in ingame_event_regions:
		var region = obj.get_meta("region_data")
		var region_is_disabled = region.activation_mode == EventRegion.ActivationMode.SWITCH and not GameManager.get_switch(region.activation_switch_id)
		if obj.disabled != region_is_disabled:
			obj.set_deferred("disabled", region_is_disabled)
	
	if has_meta("_disable_shadow"):
		#shadows.events.clear()
		#_create_shadows()
		#_perform_shadow_update()
		if not is_inside_tree(): return
		get_tree().create_timer(0.03).timeout.connect(remove_meta.bind("_disable_shadow"))


func _handle_legacy_refresh(ev: IngameEvent, page: RPGEventPage) -> void:
	page.id = ev.event.id
	if page.launcher != page.LAUNCHER_MODE.CALLER:
		var new_character_data
		if ResourceLoader.exists(page.character_path):
			new_character_data = load(page.character_path)
			if new_character_data and ResourceLoader.exists(new_character_data.scene_path):
				var new_scene_path = new_character_data.scene_path
		ev.update_page(page, new_character_data)
		_update_event_visuals(ev, page)


func _handle_modern_refresh(ev: IngameEvent, page: RPGEventPage) -> void:
	page.id = ev.event.id
	current_ingame_events.erase(ev.lpc_event.current_event.id)
	var entity_id = str(ev.lpc_event.get_rid()) + "-Page#" + str(ev.page_id)
	GameInterpreter.remove_interpreter_by_id(entity_id)
	ev.page_id = page.page_id
	_load_event(ev, page)


func refresh_extraction_events() -> void:
	for ev: IngameExtractionEvent in current_ingame_extraction_events.values():
		if ev.scene: ev.scene.refresh()


func _load_event(ev: IngameEvent, current_page: RPGEventPage) -> void:
	var old_scene = ev.lpc_event
	var old_character_data = ev.character_data
	var old_scene_path = ""
	
	# Obtener el path de la escena anterior
	if old_character_data and ResourceLoader.exists(old_character_data.scene_path):
		old_scene_path = old_character_data.scene_path
	
	# Determinar nueva escena y datos del personaje
	var new_character_data: RPGLPCCharacter = null
	var new_scene_path = ""
	
	if current_page.launcher != current_page.LAUNCHER_MODE.CALLER:
		if ResourceLoader.exists(current_page.character_path):
			new_character_data = load(current_page.character_path)
			if new_character_data and ResourceLoader.exists(new_character_data.scene_path):
				new_scene_path = new_character_data.scene_path
	
	# Verificar si podemos reutilizar la escena existente
	var can_reuse_scene = (old_scene_path == new_scene_path and
						  old_scene_path != "" and
						  current_page.launcher != current_page.LAUNCHER_MODE.CALLER)
	
	var scene: Variant
	
	var animation1: Variant
	var animation2: Variant
	
	if can_reuse_scene:
		# Reutilizar la escena existente
		scene = old_scene
		scene.event_data = new_character_data
	else:
		# Crear nueva escena
		#old_scene.visible = false
		old_scene.set_meta("_disable_shadow", true)
		
		if current_page.launcher == current_page.LAUNCHER_MODE.CALLER:
			scene = EmptyLPCEvent.new()
		elif new_scene_path != "":
			scene = load(new_scene_path).instantiate()
			scene.event_data = new_character_data
		else:
			scene = EmptyLPCEvent.new()
		
		scene.set_meta("_disable_shadow", true)
		set_meta("_disable_shadow", true)

		
		add_child(scene)
		set_event_position(scene, Vector2i(ev.lpc_event.current_event.x, ev.lpc_event.current_event.y), current_page.direction)
		
		if not is_inside_tree(): return
		get_tree().create_timer(0.06).timeout.connect(
			func():
				if is_instance_valid(scene):
					scene.remove_meta("_disable_shadow")
		)
		
		animation1 = scene
		animation2 = old_scene
	
	# Actualizar propiedades de la escena
	_update_scene_properties(scene, ev.lpc_event.current_event, current_page)
	
	# Crear nuevo IngameEvent
	var new_ingame_event = IngameEvent.new(ev.lpc_event.current_event, new_character_data, scene, internal_id)
	current_ingame_events[ev.lpc_event.current_event.id] = new_ingame_event
	
	# Manejar eventos especiales
	#_handle_special_event_modes(scene, current_page)
	
	# Change event graphics, use tween to fade in/out
	var use_animation_in_out: bool = true # Disable this variable to instant appear/disappear
	
	if animation1 and animation2 and use_animation_in_out:
		var node1 = animation1.get_node_or_null("%FinalCharacter")
		var node2 = animation2.get_node_or_null("%FinalCharacter")
		var current_scene_modulate = animation1.modulate
		var t1 = 0.5
		var t2 = 0.15
		
		var t = create_tween()
		t.set_parallel(true)
		if node1:
			animation1.modulate = Color.TRANSPARENT
			t.tween_property(animation1, "modulate", current_scene_modulate, t1)
			if node1.get_material() is ShaderMaterial:
				var m = node1.get_material().get_shader_parameter("blend_color")
				node1.get_material().set_shader_parameter("blend_color", Color.TRANSPARENT)
				t.tween_method(
					func(c: Color): node1.get_material().set_shader_parameter("blend_color", c)
					, Color.TRANSPARENT, m, t1
				)
		if node2:
			t.tween_property(animation2, "modulate", Color.TRANSPARENT, t2)
			if node2.get_material() is ShaderMaterial:
				var m = node2.get_material().get_shader_parameter("blend_color")
				t.tween_method(
					func(c: Color): node2.get_material().set_shader_parameter("blend_color", c)
					, m, Color.TRANSPARENT, t2
				)
		t.tween_callback(animation2.queue_free).set_delay(t2 + 0.01)
		
	elif animation2:
		var t = create_tween().tween_callback(animation2.queue_free).set_delay(0.06)
	
	var interpreter_id = "event_" + str(ev.event.id)
	
	if old_scene != scene:
		old_scene.queue_free()
	
	if current_page.launcher == RPGEventPage.LAUNCHER_MODE.AUTOMATIC:
		GameInterpreter.auto_start_automatic_events([ {"obj": scene, "commands": current_page.list, "id": interpreter_id}])
	elif current_page.launcher == RPGEventPage.LAUNCHER_MODE.PARALLEL:
		GameInterpreter.register_interpreter(scene, current_page.list, true, interpreter_id)


## Updates an existing IngameEvent's visual scene and data.
func _update_event_visuals(ev: IngameEvent, current_page: RPGEventPage) -> void:
	var old_scene = ev.lpc_event
	var old_character_data = ev.character_data
	var old_scene_path = ""
	
	if old_character_data and ResourceLoader.exists(old_character_data.scene_path):
		old_scene_path = old_character_data.scene_path
		
	var new_character_data: RPGLPCCharacter = null
	var new_scene_path = ""
	
	if current_page.launcher != current_page.LAUNCHER_MODE.CALLER:
		if ResourceLoader.exists(current_page.character_path):
			new_character_data = load(current_page.character_path)
			if new_character_data and ResourceLoader.exists(new_character_data.scene_path):
				new_scene_path = new_character_data.scene_path
				
	var can_reuse_scene = (old_scene_path == new_scene_path and old_scene_path != "" and current_page.launcher != current_page.LAUNCHER_MODE.CALLER)
	var scene: Variant
	
	if can_reuse_scene:
		scene = old_scene
		
		## Check if the scene actually uses event_data before assignment.
		if "event_data" in scene:
			scene.event_data = new_character_data
			
		_update_scene_properties(scene, ev.lpc_event.current_event, current_page)
	else:
		old_scene.set_meta("_disable_shadow", true)
		
		if current_page.launcher == current_page.LAUNCHER_MODE.CALLER:
			scene = EmptyLPCEvent.new()
		elif new_scene_path != "":
			scene = load(new_scene_path).instantiate()
			
			## Check if the instantiated scene actually uses event_data.
			if "event_data" in scene:
				scene.event_data = new_character_data
		else:
			scene = EmptyLPCEvent.new()
			
		scene.set_meta("_disable_shadow", true)
		add_child(scene)
		set_event_position(scene, Vector2i(ev.lpc_event.current_event.x, ev.lpc_event.current_event.y), current_page.direction)
		
		#_handle_scene_transition_animation(old_scene, scene)
		
	ev.character_data = new_character_data
	ev.lpc_event = scene
	ev.page_id = current_page.page_id
	
	#_update_interpreter_context(ev, scene, current_page)


func _create_ingame_event(ev: RPGEvent, page: RPGEventPage) -> IngameEvent:
	var scene: Variant
	var character_data: RPGLPCCharacter = null
	
	# Determinar qué escena crear
	if page.launcher == page.LAUNCHER_MODE.CALLER:
		scene = EmptyLPCEvent.new()
	elif ResourceLoader.exists(page.character_path):
		character_data = load(page.character_path)
		if character_data and ResourceLoader.exists(character_data.scene_path):
			scene = load(character_data.scene_path).instantiate()
			scene.event_data = character_data
		else:
			scene = EmptyLPCEvent.new()
	else:
		scene = EmptyLPCEvent.new()
	
	add_child(scene)
	if GameManager.game_state and ev.id in GameManager.game_state.current_events:
		var event_data: RPGEventSaveData = GameManager.game_state.current_events[ev.id]
		set_event_position(scene, event_data.position, event_data.direction, false, true)
	else:
		set_event_position(scene, Vector2i(ev.x, ev.y), page.direction)
	
	# Actualizar propiedades de la escena
	_update_scene_properties(scene, ev, page)
	
	# Manejar eventos especiales
	#_handle_special_event_modes(scene, page)
	
	return IngameEvent.new(ev, character_data, scene, internal_id, null, page.page_id)


func _create_ingame_extraction_event(ev: RPGExtractionItem) -> IngameExtractionEvent:
	var scene: Variant
	
	if ev.drop_table.is_empty():
		return null
	
	if ResourceLoader.exists(ev.scene_path):
		scene = load(ev.scene_path).instantiate()
		scene.data = ev
	
	if scene:
		add_child(scene)
		scene.position = get_tile_position(Vector2i(ev.x, ev.y))
		if not internal_id in GameManager.game_state.extraction_items:
			GameManager.game_state.extraction_items[internal_id] = {}
		if not ev.id in GameManager.game_state.extraction_items[internal_id]:
			GameManager.game_state.extraction_items[internal_id][ev.id] = GameExtractionItem.new(ev.id)
		var extraction_data: GameExtractionItem = GameManager.game_state.extraction_items[internal_id][ev.id]
		if extraction_data.is_depleted(): # item is depleted, recalculate respawn time
			var time_elapsed = GameManager.game_state.stats.play_time - extraction_data.depleted_date
			extraction_data.current_respawn_time = max(0, extraction_data.current_respawn_time - time_elapsed)
		
		scene.extraction_data = extraction_data
		
		if extraction_data.is_depleted():
			scene.end(true) # ignore animations, set final state
		else:
			scene.start(true) # ignore animations, set final state
			
		return IngameExtractionEvent.new(ev, scene, extraction_data)
	
	return null


func _update_scene_properties(scene: Variant, ev: RPGEvent, page: RPGEventPage) -> void:
	scene.name = "Event %s - %s" % [ev.name, generate_16_digit_id()]
	scene.current_event = ev
	scene.movement_current_mode = CharacterBase.MOVEMENTMODE.EVENT
	scene.current_event_page = page
	scene.event_movement_type = page.movement_type
	scene.event_movement_frequency = page.frequency
	scene.movement_speed = page.speed
	
	if page.movement_type == 4: # route
		scene.route_commands = page.movement_route
	else:
		scene.route_commands = null
	
	scene.current_map_tile_size = tile_size
	scene.calculate_grid_move_duration()
	
	# Configurar opciones del personaje si existen
	if "character_options" in scene:
		scene.character_options.fixed_direction = page.options.fixed_direction
		scene.character_options.walking_animation = page.options.walking_animation
		scene.character_options.idle_animation = page.options.idle_animation
		scene.character_options.passable = page.options.passable
		scene.character_options.movement_type = page.movement_type
		scene.character_options.movement_speed = page.speed
		scene.character_options.movement_frequency = page.frequency

		if page.options.passable:
			scene.call_deferred("_disable_collision_shape", true)
	
	# Configurar passable para CALLER
	if page.launcher == page.LAUNCHER_MODE.CALLER:
		scene.character_options.passable = true
	
	# Asegurar que esté en el grupo event
	if not scene.is_in_group("event"):
		scene.add_to_group("event")


func set_event_position(target: Node, tile: Vector2i, direction: LPCCharacter.DIRECTIONS, center_camera: bool = false, is_global_position: bool = false) -> void:
	if not target or not "position" in target:
		return
	
	target.position = get_tile_position(tile) if not is_global_position else tile
	update_event_position_in_layout(target)
	
	set_event_direction(target, direction)
	if center_camera:
		GameManager.camera_fast_reposition()


func get_tile_position(tile: Vector2i) -> Vector2:
	var start_position = Vector2(tile)
	var target_position = map_to_local(start_position)
	target_position = target_position.snapped(tile_size)
	
	return (Vector2(target_position) + event_offset)


func get_tile_from_position(pos: Vector2) -> Vector2i:
	var tile_coords = local_to_map(pos)
	return Vector2i(tile_coords)


func set_event_direction(target: Variant, direction: LPCCharacter.DIRECTIONS) -> void:
	if "current_direction" in target:
		target.current_direction = direction
	if "last_direction" in target:
		target.last_direction = direction


func _setup_common_events() -> void:
	pass


#region Functions used in the editor
func _notification(what: int) -> void:
	if what == NOTIFICATION_EDITOR_PRE_SAVE:
		var rpg_map_info = get_node_or_null("/root/RPGMapsInfo")
		if rpg_map_info:
			rpg_map_info.fix_maps([self])
		
		_bake_keot_data_fast()


func _bake_keot_data_fast() -> void:
	var time = Time.get_ticks_msec()
	_baked_keot_data.clear()
	var layar_data = "Keep Events On Top"
	
	for layer in get_children():
		if not layer is TileMapLayer: continue
	
		var tile_set: TileSet = layer.tile_set
		
		if not tile_set: continue
		
		if not tile_set.has_custom_data_layer_by_name(layar_data): continue
		
		# ---------------------------------------------------------
		# FASE 1: CACHE DEL TILESET (La "Libreta de notas")
		# ---------------------------------------------------------
		# Queremos saber: ¿El tile del Atlas (2,1) es KEOT?
		# Guardaremos: cache[source_id][atlas_coords] = target_z
		var cache: Dictionary = {}
		
		var source_count = tile_set.get_source_count()
		
		# Recorremos los "Source" (las imágenes/atlas que componen tu tileset)
		for i in range(source_count):
			var source_id = tile_set.get_source_id(i)
			var source = tile_set.get_source(source_id)
			
			# Aseguramos que es un Atlas (donde pintas tiles normales)
			if source is TileSetAtlasSource:
				var tiles_count = source.get_tiles_count()
				
				# Recorremos cada tile definido en ese Atlas
				for j in range(tiles_count):
					var atlas_coords = source.get_tile_id(j)
					
					# ESTA ES LA CLAVE:
					# Pedimos la data al SOURCE, no al MAPA.
					# 0 es el alternative_tile_id (0 = original sin rotar)
					var tile_data = source.get_tile_data(atlas_coords, 0)
					
					if tile_data and tile_data.get_custom_data(layar_data):
						var z = tile_data.z_index + layer.z_index + 1
						# Guardamos en nuestra libreta
						if not cache.has(source_id): cache[source_id] = {}
						cache[source_id][atlas_coords] = z

		# ---------------------------------------------------------
		# FASE 2: LECTURA DEL MAPA (Usando IDs, no Data)
		# ---------------------------------------------------------
		var cells = layer.get_used_cells()
		
		for coords in cells:
			# Aquí usamos las funciones rápidas que pusiste en tu mensaje.
			# Solo devuelven números (int y Vector2i), no objetos pesados.
			var id = layer.get_cell_source_id(coords)
			
			# 1. ¿Está este ID en nuestra libreta de "Tiles Mágicos"?
			if cache.has(id):
				var atlas_coords = layer.get_cell_atlas_coords(coords)
				
				# 2. ¿Está esa coordenada concreta en la libreta?
				if cache[id].has(atlas_coords):
					var z_val = cache[id][atlas_coords]
					
					# Guardamos el resultado final
					if _baked_keot_data.has(coords):
						_baked_keot_data[coords] = max(_baked_keot_data[coords], z_val)
					else:
						_baked_keot_data[coords] = z_val


func _get_extraction_item_shape_polygon(p_margin: float = 0.0) -> Dictionary:
	var center = Vector2(tile_size.x / 2.0, tile_size.y / 2.0)
	
	var max_radius_x = (tile_size.x - p_margin * 2) / 2.0
	var max_radius_y = (tile_size.y - p_margin * 2) / 2.0
	var radius = min(max_radius_x, max_radius_y / sin(PI / 3.0))
	
	var result: Dictionary = {}
	result.fill_polygon = _get_hexagon_vertices(center, radius)
	result.outer_border = result.fill_polygon.duplicate()
	result.outer_border.append(result.outer_border[0])
	result.inner_border = _get_hexagon_vertices(center, radius - 1)
	result.inner_border.append(result.inner_border[0])
	
	return result


func _get_hexagon_vertices(center: Vector2, radius: float) -> PackedVector2Array:
	var vertices = PackedVector2Array()
	
	for i in range(6):
		var angle = i * PI / 3.0 # + PI / 6.0 -> Star tip on top
		var x = center.x + radius * cos(angle)
		var y = center.y + radius * sin(angle)
		vertices.append(Vector2(x, y))
	
	return vertices


func _get_extraction_item_shape(p_tile_position: Vector2i, p_margin: float = 2.0) -> Dictionary:
	var offset = Vector2(p_tile_position.x * tile_size.x, p_tile_position.y * tile_size.y)
	var cache_key = str(tile_size) + "_" + str(p_margin)
	hexagon_cache.clear()
	
	if not hexagon_cache.has(cache_key):
		var polygon_data = _get_extraction_item_shape_polygon(p_margin)
		hexagon_cache[cache_key] = polygon_data
	
	var polygon = hexagon_cache[cache_key].duplicate(true)
	
	# Apply offset
	for i: int in polygon.fill_polygon.size():
		polygon.fill_polygon[i] += offset
	for i: int in polygon.outer_border.size():
		polygon.outer_border[i] += offset
	for i: int in polygon.inner_border.size():
		polygon.inner_border[i] += offset
		
	return polygon


func _draw() -> void:
	var rect: Rect2 = get_used_rect()
	if !rect.has_area():
		return

	# Logic to check if we should draw the grid based on editor state
	if !Engine.is_editor_hint() or (!editing_events and !editing_extraction_events and !editing_enemy_spawn_region and !editing_event_region):
		return


	var start_x: float = rect.position.x * tile_size.x
	var start_y: float = rect.position.y * tile_size.y
	var end_x: float = (rect.position.x + rect.size.x) * tile_size.x
	var end_y: float = (rect.position.y + rect.size.y) * tile_size.y

	# Draw vertical lines
	for x in range(rect.size.x + 1):
		var x_pos: float = start_x + (x * tile_size.x)
		draw_line(Vector2(x_pos, start_y), Vector2(x_pos, end_y), grid_color)


	# Draw horizontal lines
	for y in range(rect.size.y + 1):
		var y_pos: float = start_y + (y * tile_size.y)
		draw_line(Vector2(start_x, y_pos), Vector2(end_x, y_pos), grid_color)


func _draw_cursor_highlight() -> void:
	# Only draw if we have a gradient and we are in the correct editor modes
	if not grid_gradient or not Engine.is_editor_hint() or not cursor_canvas:
		return
	
	if (!editing_events and !editing_extraction_events and !editing_enemy_spawn_region and !editing_event_region):
		return

	var local_mouse: Vector2 = get_local_mouse_position()
	var mouse_grid_x: int = int(local_mouse.x / tile_size.x)
	var mouse_grid_y: int = int(local_mouse.y / tile_size.y)
	
	# Determine the bounds to iterate, clamped to the map size if necessary
	var start_x: int = mouse_grid_x - cursor_radius
	var end_x: int = mouse_grid_x + cursor_radius
	var start_y: int = mouse_grid_y - cursor_radius
	var end_y: int = mouse_grid_y + cursor_radius

	for x in range(start_x, end_x + 1):
		for y in range(start_y, end_y + 1):
			# Calculate Chebyshev distance (concentric square rings)
			var dist_x: int = abs(x - mouse_grid_x)
			var dist_y: int = abs(y - mouse_grid_y)
			var distance: int = max(dist_x, dist_y)
			
			# Normalize distance to 0.0 - 1.0 for gradient sampling
			var sample_pos: float = float(distance) / float(cursor_radius)
			var color: Color = grid_gradient.sample(sample_pos)
			
			# Calculate drawing position
			var draw_pos: Vector2 = Vector2(x * tile_size.x, y * tile_size.y)
			var rect: Rect2 = Rect2(draw_pos, tile_size)
			
			# Draw the filled rect (or outline if preferred)
			cursor_canvas.draw_rect(rect, color, false) # 'false' means filled, change to 'true' for outline only


func _on_keot_canvas_draw() -> void:
	if Engine.is_editor_hint() and not _baked_keot_data.is_empty():
		for tile: Vector2i in _baked_keot_data.keys():
			var keot_rect = Rect2i(
				(Vector2i(tile.x, tile.y) * tile_size),
				tile_size
			)
			if "keot_tile" in editor_icons:
				keot_canvas.draw_texture_rect(editor_icons.keot_tile, keot_rect, false)


func get_region(index: int) -> EnemySpawnRegion:
	if regions.size() > index and index >= 0:
		return regions[index]
	else:
		return null


func get_event_region(index: int) -> EventRegion:
	if event_regions.size() > index and index >= 0:
		return event_regions[index]
	else:
		return null


func _set_child_opacity(node: Node = self, original_modulate: bool = false) -> void:
	for child in node.get_children():
		if editor_shadow_canvas and child == editor_shadow_canvas:
			continue
		if "modulate" in child and child != event_canvas and child != extraction_event_canvas and child != enemy_spawn_canvas and child != event_region_canvas and child != keot_canvas and child != cursor_canvas:
			if original_modulate:
				if child.has_meta("original_opacity"):
					child.modulate.a = child.get_meta("original_opacity")
					if remove_meta:
						child.remove_meta("original_opacity")
				else:
					child.modulate.a = 1.0
					pass
			else:
				if !child.has_meta("original_opacity"):
					child.set_meta("original_opacity", child.modulate.a)
				child.modulate.a = children_opacity
		
		for other_node in child.get_children():
			_set_child_opacity(other_node, original_modulate)


func set_editing_events(value: bool) -> void:
	editing_extraction_events = false
	current_extraction_event = null
	editing_enemy_spawn_region = false
	current_enemy_spawn_region = null
	editing_event_region = false
	current_event_region = null
	if enemy_spawn_canvas:
		enemy_spawn_canvas.queue_redraw()
	if event_region_canvas:
		event_region_canvas.queue_redraw()
	
	if Engine.is_editor_hint():
		editing_events = value
		current_event = null
		if !value:
			_set_child_opacity(self, true)
		else:
			_set_child_opacity(self, false)
			
	queue_redraw()


func set_editing_extraction_events(value: bool) -> void:
	editing_events = false
	current_event = null
	editing_enemy_spawn_region = false
	current_enemy_spawn_region = null
	editing_event_region = false
	current_event_region = null
	if enemy_spawn_canvas:
		enemy_spawn_canvas.queue_redraw()
	if event_region_canvas:
		event_region_canvas.queue_redraw()
	if event_canvas:
		event_region_canvas.queue_redraw()
	
	if Engine.is_editor_hint():
		editing_extraction_events = value
		current_extraction_event = null
		if !value:
			_set_child_opacity(self, true)
		else:
			_set_child_opacity(self, false)
			
	queue_redraw()


func set_editing_enemy_spawn_regions(value: bool) -> void:
	editing_events = false
	current_event = null
	editing_extraction_events = false
	current_extraction_event = null
	editing_event_region = false
	current_event_region = null
	if event_canvas:
		event_canvas.queue_redraw()
	if event_region_canvas:
		event_region_canvas.queue_redraw()
	
	if Engine.is_editor_hint():
		editing_enemy_spawn_region = value
		current_enemy_spawn_region = null
		if !value:
			_set_child_opacity(self, true)
		else:
			_set_child_opacity(self, false)
			
	queue_redraw()


func set_editing_event_regions(value: bool) -> void:
	editing_events = false
	current_event = null
	editing_extraction_events = false
	current_extraction_event = null
	editing_enemy_spawn_region = false
	current_enemy_spawn_region = null
	if event_canvas:
		event_canvas.queue_redraw()
	if enemy_spawn_canvas:
		enemy_spawn_canvas.queue_redraw()
	
	if Engine.is_editor_hint():
		editing_event_region = value
		current_event_region = null
		if !value:
			_set_child_opacity(self, true)
		else:
			_set_child_opacity(self, false)
			
	queue_redraw()


func generate_16_digit_id() -> int:
	var id = str(randi_range(1, 9))
	var characters = "0123456789"
	for i in range(15):
		var random_index = randi() % characters.length()
		id += characters.substr(random_index, 1)
	
	return int(id)


func create_canvas(refresh_events: bool = false) -> void:
	# Add events canvas
	event_canvas = Node2D.new()
	event_canvas.z_index = 100
	event_canvas.draw.connect(_on_event_canvas_draw)
	draw.connect(event_canvas.queue_redraw)
	add_child(event_canvas)
	
	# Add extraction event canvas
	extraction_event_canvas = Node2D.new()
	extraction_event_canvas.z_index = 100
	extraction_event_canvas.draw.connect(_on_extraction_event_canvas_draw)
	draw.connect(extraction_event_canvas.queue_redraw)
	add_child(extraction_event_canvas)
	
	# Add keots canvas
	keot_canvas = Node2D.new()
	keot_canvas.z_index = 100
	keot_canvas.modulate.a = 0.4
	keot_canvas.draw.connect(_on_keot_canvas_draw)
	draw.connect(keot_canvas.queue_redraw)
	add_child(keot_canvas)

	if refresh_events:
		queue_redraw()
	else:
		# Add enemy spawn canvas
		enemy_spawn_canvas = Node2D.new()
		enemy_spawn_canvas.z_index = 100
		enemy_spawn_canvas.draw.connect(_on_enemy_spawn_canvas_draw)
		draw.connect(enemy_spawn_canvas.queue_redraw)
		add_child(enemy_spawn_canvas)
		# Add event region canvas
		event_region_canvas = Node2D.new()
		event_region_canvas.z_index = 100
		event_region_canvas.draw.connect(_on_event_region_canvas_draw)
		draw.connect(event_region_canvas.queue_redraw)
		add_child(event_region_canvas)
	
	# Add Cursor Canvas
	cursor_canvas = Node2D.new()
	cursor_canvas.z_index = 200
	cursor_canvas.draw.connect(_draw_cursor_highlight)
	add_child(cursor_canvas)


func perform_full_update() -> void:
	if Engine.is_editor_hint():
		if editing_events:
			if event_canvas:
				event_canvas.queue_redraw()
		elif editing_extraction_events:
			if extraction_event_canvas:
				extraction_event_canvas.queue_redraw()
		elif editing_enemy_spawn_region:
			if enemy_spawn_canvas:
				enemy_spawn_canvas.queue_redraw()
		elif editing_event_region:
			if event_region_canvas:
				event_region_canvas.queue_redraw()


func select_event(pos: Vector2i) -> void:
	if Engine.is_editor_hint():
		var old_event = current_event
		current_event = get_event_in(pos)
		if old_event != current_event:
			if event_canvas:
				event_canvas.queue_redraw()


func select_extraction_event(pos: Vector2i) -> void:
	if Engine.is_editor_hint():
		var old_event = current_extraction_event
		current_extraction_event = get_extraction_event_in(pos)
		if old_event != current_extraction_event:
			if extraction_event_canvas:
				extraction_event_canvas.queue_redraw()


func is_mouse_over_event() -> bool:
	if events:
		var pos = get_global_mouse_position()
		for event: RPGEvent in events.get_events():
			var rect = Rect2i(Vector2i(event.x, event.y) * tile_size, tile_size)
			if rect.has_point(Vector2i(pos)):
				return true
	return false


func is_mouse_over_extraction_event() -> bool:
	if extraction_events:
		var pos = get_global_mouse_position()
		for event: RPGExtractionItem in extraction_events:
			var rect = Rect2i(Vector2i(event.x, event.y) * tile_size, tile_size)
			if rect.has_point(Vector2i(pos)):
				return true
	return false


func _is_place_free(pos: Vector2i) -> bool:
	var is_place_free: bool = events.is_place_free_in(pos)
	
	if is_place_free:
		for event in extraction_events:
			if event.x == pos.x and event.y == pos.y:
				is_place_free = false
				break
	
	return is_place_free


func add_event_in(pos: Vector2i) -> bool:
	if !Engine.is_editor_hint():
		return false
		
	var is_place_free: bool = _is_place_free(pos)
	if is_place_free:
		var event_id: int = events.get_next_id()
		var event := RPGEvent.new(event_id, pos.x, pos.y)
		events.add_event(event)
		current_event = event
		notify_property_list_changed()
		if event_canvas:
			event_canvas.queue_redraw()
		return true
	else:
		select_event(pos)
		return false


func _get_next_extraction_event_id() -> int:
	var existing_ids = extraction_events.map(func(obj): return obj.id)
	
	for i in range(1, existing_ids.size() + 2):
		if not i in existing_ids:
			return i
	
	return 1


func _get_next_event_id() -> int:
	var existing_ids = events.events.map(func(obj): return obj.id)
	
	for i in range(1, existing_ids.size() + 2):
		if not i in existing_ids:
			return i
	
	return 1


func add_extraction_event_in(pos: Vector2i) -> bool:
	if !Engine.is_editor_hint():
		return false
		
	var is_place_free: bool = _is_place_free(pos)
	if is_place_free:
		var event_id: int = _get_next_extraction_event_id()
		var event := RPGExtractionItem.new(event_id, pos.x, pos.y)
		event.name = "EV" + str(event.id).pad_zeros(4)
		extraction_events.append(event)
		current_extraction_event = event
		notify_property_list_changed()
		if extraction_event_canvas:
			extraction_event_canvas.queue_redraw()
		return true
	else:
		select_extraction_event(pos)
		return false


func get_region_in(pos: Vector2i) -> EnemySpawnRegion:
	for region in regions:
		if region.rect.has_point(pos):
			return region
	
	return null


func get_event_region_in(pos: Vector2i) -> EventRegion:
	for region in event_regions:
		if region.rect.has_point(pos):
			return region
	
	return null


func random_color_in_range(hue_min: float, hue_max: float):
	return Color.from_hsv(randf_range(hue_min, hue_max), randf_range(0.5, 1.0), randf_range(0.5, 1.0))


func add_region(new_region: EnemySpawnRegion) -> EnemySpawnRegion:
	var id: int
	if regions.size() > 0:
		while true:
			id = generate_16_digit_id()
			var exit_loop = true
			for region in regions:
				if region.id == id:
					exit_loop = false
					break
			if exit_loop:
				break
	else:
		id = generate_16_digit_id()
			
	new_region.id = id
	new_region.name = ""
	new_region.color = random_color_in_range(0.0, 1.0)
	new_region.color.a = 0.4
	regions.append(new_region)
	
	refresh_canvas()
	
	return new_region


func add_event_region(new_region: EventRegion) -> EventRegion:
	var id: int
	if regions.size() > 0:
		while true:
			id = _get_next_event_region_id()
			var exit_loop = true
			for region in regions:
				if region.id == id:
					exit_loop = false
					break
			if exit_loop:
				break
	else:
		id = _get_next_event_region_id()
			
	new_region.id = id
	new_region.name = ""
	new_region.color = random_color_in_range(0.0, 1.0)
	new_region.color.a = 0.4
	event_regions.append(new_region)
	
	refresh_canvas()
	
	return new_region


func _update_event_region(index: int, region: EventRegion) -> void:
	if index >= 0 and index < event_regions.size():
		event_regions[index] = region
		refresh_canvas()


func update_region(region_updated: EnemySpawnRegion) -> void:
	var rect = Rect2i(region_updated.rect.position * tile_size, region_updated.rect.size * tile_size)
	if get_used_rect().intersects(rect):
		for region in regions:
			if region.id == region_updated.id:
				region.rect = region_updated.rect
				break
	
	refresh_canvas()


func update_event_region(region_updated: EventRegion) -> void:
	var rect = Rect2i(region_updated.rect.position * tile_size, region_updated.rect.size * tile_size)
	if get_used_rect().intersects(rect):
		for region in event_regions:
			if region.id == region_updated.id:
				region.rect = region_updated.rect
				break
	
	refresh_canvas()


func paste_event_in(pos: Vector2i, event: RPGEvent) -> bool:
	if !Engine.is_editor_hint():
		return false
		
	var result = events.paste_event_in(pos, event)
	notify_property_list_changed()
	if event_canvas:
		event_canvas.queue_redraw()
	
	if result:
		event.id = _get_next_event_id()

	return result


func _add_extraction_event(event: RPGExtractionItem, rename: bool = true) -> void:
	if rename:
		event.name = "EV" + str(event.id).pad_zeros(4)
	extraction_events.append(event)
	if extraction_events.size() > 0:
		extraction_events.sort_custom(sort_events_by_id)


func _update_extraction_event(index: int, event: RPGExtractionItem) -> void:
	if index >= 0 and index < extraction_events.size():
		extraction_events[index] = event


func sort_events_by_id(a: RPGExtractionItem, b: RPGExtractionItem) -> bool:
	return a.id < b.id


func paste_extraction_event_in(pos: Vector2i, new_event: RPGExtractionItem) -> bool:
	if !Engine.is_editor_hint():
		return false
	
	for ev in extraction_events:
		if ev.x == pos.x and ev.y == pos.y:
			var properties = ["name", "scene_path", "required_profession", "required_level", "max_uses", "respawn_time", "drop_table", "extraction_fx"]
			for p in properties:
				ev.set(p, new_event.get(p))
			return true
	
	new_event.id = _get_next_extraction_event_id()
	new_event.x = pos.x
	new_event.y = pos.y
	last_extraction_event_pasted_id = new_event.id
	_add_extraction_event(new_event, false)
		
	notify_property_list_changed()
	if extraction_event_canvas:
		extraction_event_canvas.queue_redraw()

	return true


func paste_region_in(pos: Vector2i, region: EnemySpawnRegion) -> bool:
	if !Engine.is_editor_hint():
		return false
		
	region.id = generate_16_digit_id()
	region.rect.position = pos
	region.color = random_color_in_range(0.0, 1.0)
	region.color.a = 0.4
	regions.append(region)
	notify_property_list_changed()
	if enemy_spawn_canvas:
		enemy_spawn_canvas.queue_redraw()

	return true


func _get_next_event_region_id() -> int:
	var used_ids := {}
	for region in event_regions:
		used_ids[region.id] = true

	var next_id := 1
	while used_ids.has(next_id):
		next_id += 1

	return next_id
		

func paste_event_region_in(pos: Vector2i, region: EventRegion) -> bool:
	if !Engine.is_editor_hint():
		return false
		
	region.id = _get_next_event_region_id()
	region.rect.position = pos
	region.color = random_color_in_range(0.0, 1.0)
	region.color.a = 0.4
	event_regions.append(region)
	notify_property_list_changed()
	if event_region_canvas:
		event_region_canvas.queue_redraw()

	return true


func get_last_event_added() -> int:
	return events.get_last_event_added()


func get_last_extraction_event_added() -> int:
	return last_extraction_event_pasted_id


func get_event_in(pos: Vector2i) -> RPGEvent:
	var event = events.get_event_in(pos)
	return event


func get_extraction_event_in(pos: Vector2i) -> RPGExtractionItem:
	for ev: RPGExtractionItem in extraction_events:
		var p = Vector2i(ev.x, ev.y)
		if p == pos:
			return ev

	return null


func get_events_in_place(pos: Vector2i) -> int:
	var event_count = 0
	
	if GameManager.current_player.get_current_tile() == pos:
		event_count += 1
	
	event_count += get_overlapped_events_number(pos)
	event_count += get_overlapped_vehicle_number(pos)
		
	return event_count


func get_events_objects_in(pos: Vector2i) -> Array:
	var objects: Array = []
	
	if GameManager.current_player.get_current_tile() == pos:
		objects.append(GameManager.current_player)
	
	for ev: IngameEvent in current_ingame_events.values():
		if ev.lpc_event.get_current_tile() == pos:
			objects.append(ev.lpc_event)
	
	for vehicle: RPGVehicle in current_ingame_vehicles:
		var vehicle_tile_position = local_to_map(vehicle.global_position)
		if pos == vehicle_tile_position:
			objects.append(vehicle)
		elif vehicle.extra_dimensions:
			var extra_dimensions: RPGDimension = vehicle.extra_dimensions
			var vehicle_left = vehicle_tile_position.x - extra_dimensions.grow_left
			var vehicle_right = vehicle_tile_position.x + extra_dimensions.grow_right + 1
			var vehicle_up = vehicle_tile_position.y - extra_dimensions.grow_up
			var vehicle_down = vehicle_tile_position.y + extra_dimensions.grow_down + 1
			if pos.x >= vehicle_left and pos.x < vehicle_right and \
			   pos.y >= vehicle_up and pos.y < vehicle_down:
				objects.append(vehicle)
	
	return objects


func get_in_game_event_in(pos: Vector2i) -> Variant:
	# check events/npcs
	for ev: IngameEvent in current_ingame_events.values():
		if not ev: continue
		if ev.lpc_event:
			if ev.lpc_event.get_current_tile() == pos:
				return ev.lpc_event
	
	# check extraction events in this map
	for ev: IngameExtractionEvent in current_ingame_extraction_events.values():
		if ev.scene:
			var scene = ev.scene
			if scene.get_current_tile() == pos:
				return scene
	
	return null


func get_in_game_events_in(pos: Vector2i, include_previous_tile: bool = false) -> Array:
	var in_game_events: Array = []
	var real_pos = map_to_local(pos)
	var evs = map_layout.get_events_near_position(real_pos)
	for ev: Variant in evs:
		if not ev: continue
		if ev.get_current_tile() == pos or (include_previous_tile and ev.get_previous_tile() == pos):
			in_game_events.append(ev)
	
	return in_game_events


func get_overlapped_events_number(pos: Vector2i) -> int:
	var n = 0
	
	for ev: IngameEvent in current_ingame_events.values():
		if not ev: continue
		if ev.lpc_event:
			if ev.lpc_event.get_current_tile() == pos:
				n += 1
	
	return n


func get_in_game_events() -> Array[IngameEvent]:
	return current_ingame_events.values().filter(func(obj: Variant): return not obj == null)


func get_in_game_event(event_id: int) -> Variant:
	for ev: IngameEvent in current_ingame_events.values():
		if not ev: continue
		if ev.event and ev.event.id == event_id and ev.lpc_event:
			return ev.lpc_event
	
	return null

# Search event by pos in array current_ingame_events.values()
func get_in_game_event_by_pos(event_id: int) -> Variant:
	var current_events = current_ingame_events.values()
	if current_events.size() > event_id:
		return current_events[event_id].lpc_event
	
	return null

# Search event by event real id
func get_in_game_event_by_id(event_id: int) -> Variant:
	if event_id in current_ingame_events:
		return current_ingame_events[event_id].lpc_event
	
	return null


func get_in_game_vehicle_in(pos: Vector2i) -> RPGVehicle:
	var current_vehicle: RPGVehicle = null
	for vehicle: RPGVehicle in current_ingame_vehicles:
		var vehicle_tile_position = local_to_map(vehicle.global_position)
		if pos == vehicle_tile_position:
			current_vehicle = vehicle
		elif vehicle.extra_dimensions:
			var extra_dimensions: RPGDimension = vehicle.extra_dimensions
			var vehicle_left = vehicle_tile_position.x - extra_dimensions.grow_left
			var vehicle_right = vehicle_tile_position.x + extra_dimensions.grow_right + 1
			var vehicle_up = vehicle_tile_position.y - extra_dimensions.grow_up
			var vehicle_down = vehicle_tile_position.y + extra_dimensions.grow_down + 1
			if pos.x >= vehicle_left and pos.x < vehicle_right and \
			   pos.y >= vehicle_up and pos.y < vehicle_down:
				current_vehicle = vehicle
		
		if current_vehicle: break
	
	return current_vehicle


func get_in_game_vehicles() -> Array[RPGVehicle]:
	return current_ingame_vehicles


func get_overlapped_vehicle_number(pos: Vector2i) -> int:
	var n = 0
	
	for vehicle: RPGVehicle in current_ingame_vehicles:
		var vehicle_tile_position = local_to_map(vehicle.global_position)
		if pos == vehicle_tile_position:
			n += 1
		elif vehicle.extra_dimensions:
			var extra_dimensions: RPGDimension = vehicle.extra_dimensions
			var vehicle_left = vehicle_tile_position.x - extra_dimensions.grow_left
			var vehicle_right = vehicle_tile_position.x + extra_dimensions.grow_right + 1
			var vehicle_up = vehicle_tile_position.y - extra_dimensions.grow_up
			var vehicle_down = vehicle_tile_position.y + extra_dimensions.grow_down + 1
			if pos.x >= vehicle_left and pos.x < vehicle_right and \
			   pos.y >= vehicle_up and pos.y < vehicle_down:
				n += 1
	
	return n


func add_weather_scene(id: int, weather_scene: Node) -> void:
	remove_weather_scene(id)
	current_ingame_weather_scenes[id] = weather_scene
	
	weather_scene.visible = false
	add_child(weather_scene)
	
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	
	if is_instance_valid(weather_scene):
		weather_scene.visible = true


func remove_weather_scene(id: int) -> void:
	if id in current_ingame_weather_scenes:
		if is_instance_valid(current_ingame_weather_scenes[id]):
			current_ingame_weather_scenes[id].queue_free()
			current_ingame_weather_scenes.erase(id)


func get_event_by_id(id: int) -> RPGEvent:
	return events.get_event_by_id(id)


func remove_event_in(pos: Vector2i) -> bool:
	if !Engine.is_editor_hint():
		return false
		
	var result = events.remove_event_in(pos)
	if result:
		notify_property_list_changed()
		if event_canvas:
			event_canvas.queue_redraw()
	
	return result


func remove_extraction_event_in(pos: Vector2i) -> bool:
	if !Engine.is_editor_hint():
		return false
	
	var result: bool = false
	for event in extraction_events:
		if event.x == pos.x and event.y == pos.y:
			extraction_events.erase(event)
			result = true
			break
		
	if result:
		notify_property_list_changed()
		if extraction_event_canvas:
			extraction_event_canvas.queue_redraw()
	
	return result


func remove_region_in(pos: Vector2i) -> bool:
	if !Engine.is_editor_hint():
		return false
	
	var region: EnemySpawnRegion = get_region_in(pos)
 
	if region:
		remove_region(region)
	
	return region != null


func remove_event_region_in(pos: Vector2i) -> bool:
	if !Engine.is_editor_hint():
		return false
	
	var region: EventRegion = get_event_region_in(pos)

	if region:
		remove_event_region(region)
	
	return region != null


func remove_region(region: EnemySpawnRegion) -> void:
	regions.erase(region)
	if enemy_spawn_canvas:
		enemy_spawn_canvas.queue_redraw()


func remove_event_region(region: EventRegion) -> void:
	event_regions.erase(region)
	if event_region_canvas:
		event_region_canvas.queue_redraw()


func set_events(values: RPGEvents) -> void:
	events = values


func refresh_canvas():
	queue_redraw()


func _on_enemy_spawn_canvas_draw() -> void:
	if !editing_enemy_spawn_region and not force_show_regions:
		return
	
	for i in regions.size():
		var region = regions[i]
		if region == current_enemy_spawn_region:
			continue
		if region.rect.has_area():
			var c1 = region.color
			if current_enemy_spawn_region and current_enemy_spawn_region.id == region.id:
				c1 = Color(0.09, 0.047, 0.047, 0.267)
			var c2 = c1.darkened(0.4)
			if region_selected and region_selected.id == region.id:
				c2 = Color.ORANGE
			if force_show_regions:
				c1.a *= 0.45
				c2.a *= 0.45
			var real_rect = region.rect
			real_rect.position *= tile_size
			real_rect.size *= tile_size
			enemy_spawn_canvas.draw_rect(real_rect, c1, true)
			enemy_spawn_canvas.draw_rect(real_rect, c2, false, 2)
			var font = ThemeDB.fallback_font
			var text_size = ThemeDB.fallback_font_size
			var text_position = Vector2(real_rect.position) + Vector2(22, 22)
			var align = HORIZONTAL_ALIGNMENT_LEFT
			var text = region.name
			if text.is_empty():
				text = "Spawn Region #%s" % (i + 1)
			while text_size > 8 and font.get_string_size(text, align, -1, text_size).x > real_rect.size.x - 22:
				text_size -= 1
			var c = Color.WHITE if not force_show_regions else Color(0.80, 0.80, 0.80, 0.45)
			enemy_spawn_canvas.draw_string(font, text_position, text, align, real_rect.size.x - 22, text_size, c)
	
	
	if not force_show_regions and current_enemy_spawn_region and current_enemy_spawn_region.rect.has_area():
		var c1 = current_enemy_spawn_region.color
		var c2 = c1.darkened(0.4)
		var real_rect = current_enemy_spawn_region.rect
		real_rect.position *= tile_size
		real_rect.size *= tile_size
		enemy_spawn_canvas.draw_rect(real_rect, c1, true)
		enemy_spawn_canvas.draw_rect(real_rect, c2, false, 2)


func _on_event_region_canvas_draw() -> void:
	if !editing_event_region and not force_show_regions:
		return

	for i in event_regions.size():
		var region = event_regions[i]
		if region == current_event_region:
			continue
		if region.rect.has_area():
			var c1 = region.color
			if current_event_region and current_event_region.id == region.id:
				c1 = Color(0.09, 0.047, 0.047, 0.267)
			var c2 = c1.darkened(0.4)
			if event_region_selected and event_region_selected.id == region.id:
				c2 = Color.ORANGE
			if force_show_regions:
				c1.a *= 0.45
				c2.a *= 0.45
			var real_rect = region.rect
			real_rect.position *= tile_size
			real_rect.size *= tile_size
			event_region_canvas.draw_rect(real_rect, c1, true)
			event_region_canvas.draw_rect(real_rect, c2, false, 2)
			var font = ThemeDB.fallback_font
			var text_size = ThemeDB.fallback_font_size
			var text_position = Vector2(real_rect.position) + Vector2(22, 22)
			var align = HORIZONTAL_ALIGNMENT_LEFT
			var text = region.name
			if text.is_empty():
				text = "Event Region #%s" % (i + 1)
			while text_size > 8 and font.get_string_size(text, align, -1, text_size).x > real_rect.size.x - 22:
				text_size -= 1
			var c = Color.WHITE if not force_show_regions else Color(0.80, 0.80, 0.80, 0.45)
			event_region_canvas.draw_string(font, text_position, text, align, real_rect.size.x - 22, text_size, c)
	
	
	if not force_show_regions and current_event_region and current_event_region.rect.has_area():
		var c1 = current_event_region.color
		var c2 = c1.darkened(0.4)
		var real_rect = current_event_region.rect
		real_rect.position *= tile_size
		real_rect.size *= tile_size
		event_region_canvas.draw_rect(real_rect, c1, true)
		event_region_canvas.draw_rect(real_rect, c2, false, 2)


func _on_event_canvas_draw() -> void:
	event_preview_textures.clear()
	# Draw start positions:
	var ids = [
		"player_start_position",
		"land_transport_start_position",
		"sea_transport_start_position",
		"air_transport_start_position",
	]
	var color = Color(1, 1, 1, 0.90) if editing_events else Color(1, 1, 1, 0.30)
	for id in ids:
		var data: RPGMapPosition = RPGSYSTEM.database.system.get(id)
		if data:
			if data.map_id == internal_id:
				var pos = data.position
				var icon = editor_icons.get(id)
				var real_pos = Vector2i(map_to_local(Vector2i(pos.x, pos.y)))
				event_canvas.draw_texture(icon, real_pos, color)
				if current_start_position == data:
					var rect = Rect2i(real_pos + Vector2i.ONE, tile_size - Vector2i(2, 2))
					event_canvas.draw_rect(rect, Color.DARK_ORANGE, false, 2)

	# Draw Events
	if (Engine.is_editor_hint() and events) or preview_map_only_enabled:
		var obj = events.get_events()
		if !obj:
			return
		
		var used_rect = get_used_rect()
			
		var color1: Color = Color.WHITE
		var color2: Color = Color.BLACK
		var color3: Color = Color.DARK_ORANGE
		var color4: Color = Color(0.839, 0.208, 0.063, 0.098)
		
		if editing_events:
			color1.a = 0.90
			color2.a = 0.65
		else:
			color1.a = 0.30
			color2.a = 0.20
		
		for event: RPGEvent in obj:
			if !event:
				continue
			
			var real_pos = Vector2i(map_to_local(Vector2i(event.x, event.y)))
			var rect = Rect2i(real_pos + Vector2i.ONE, tile_size - Vector2i(2, 2))
			
			if used_rect.intersects(rect):
				event_canvas.draw_rect(rect, color1, false, 2)
				event_canvas.draw_rect(rect, color2, true)
			
				if event == current_event and editing_events:
					event_canvas.draw_rect(rect, color3, false, 2)
			else:
				event_canvas.draw_rect(rect, color1, false, 2)
				event_canvas.draw_rect(rect, color4, true)
			
			if event.pages.size() > 0:
				var page: RPGEventPage = event.pages[0]
				var path = page.character_path
				if ResourceLoader.exists(path):
					var res: RPGLPCCharacter = ResourceLoader.load(path)
					var character_preview_path = res.event_preview
					if ResourceLoader.exists(character_preview_path):
						rect.position += Vector2i.ONE
						rect.size -= Vector2i(2, 2)
						var tex: Texture
						if character_preview_path in event_preview_textures:
							tex = event_preview_textures[character_preview_path]
						else:
							tex = ResourceLoader.load(character_preview_path)
							event_preview_textures[character_preview_path] = tex
						event_canvas.draw_texture_rect(tex, rect, false, Color(1, 1, 1, color1.a))


func _on_extraction_event_canvas_draw() -> void:
	extraction_event_preview_textures.clear()
	
	var used_rect = get_used_rect()
	var color1: Color = Color.WHITE
	var color2: Color = Color.BLACK
	var color3: Color = Color.DARK_ORANGE
	var color4: Color = Color(0.839, 0.208, 0.063, 0.098)
	var color5: Color = Color.WHITE
	var fill_polygon_color: Color = Color.BLACK
	var inner_border_polygon: Color = Color.GRAY
	var outer_border_polygon: Color = Color.WHITE
	
	
	if editing_extraction_events:
		color1.a = 0.90
		color2.a = 0.65
		color5.a = 1.0
		fill_polygon_color.a = 0.65
		inner_border_polygon.a = 0.90
		outer_border_polygon.a = 0.90
	else:
		color1.a = 0.30
		color2.a = 0.20
		color5.a = 0.20
		fill_polygon_color.a = 0.20
		inner_border_polygon.a = 0.30
		outer_border_polygon.a = 0.30
	
	var font = ThemeDB.fallback_font
	var text_size = 22
	var align = HORIZONTAL_ALIGNMENT_LEFT
	var profession_icon_size = Vector2i(18, 18)

	for event in extraction_events:
		var real_pos = Vector2i(map_to_local(Vector2i(event.x, event.y)))
		var rect = Rect2i(real_pos + Vector2i.ONE, tile_size - Vector2i(2, 2))
		
		if used_rect.intersects(rect):
			if event == current_extraction_event and editing_extraction_events:
				extraction_event_canvas.draw_rect(rect, color3, false, 2)
			
		# Draw node
		var p = _get_extraction_item_shape(Vector2i(event.x, event.y), 1.0)
		extraction_event_canvas.draw_colored_polygon(p.fill_polygon, fill_polygon_color)
		extraction_event_canvas.draw_polyline(p.inner_border, inner_border_polygon, 1.0)
		extraction_event_canvas.draw_polyline(p.outer_border, outer_border_polygon, 1.0)
		
		# Draw Contents
		var scene_path = event.scene_path.get_basename() + "_preview" + ".png"
		if ResourceLoader.exists(scene_path):
			var contents: Texture
			if scene_path in extraction_event_preview_textures:
				contents = extraction_event_preview_textures[scene_path]
			else:
				contents = ResourceLoader.load(scene_path)
				extraction_event_preview_textures[scene_path] = contents
			var contents_rect = Rect2i(
				(Vector2i(event.x, event.y) * tile_size) + Vector2i(8, 8),
				tile_size - Vector2i(16, 16)
			)
			
			extraction_event_canvas.draw_texture_rect(contents, contents_rect, false, color5)
		
		# Draw profession icon
		var profession_id = event.required_profession
		if profession_id >= 1 and RPGSYSTEM.database.professions.size() > profession_id:
			var profession = RPGSYSTEM.database.professions[profession_id]
			if ResourceLoader.exists(profession.icon.path):
				var contents: Texture
				var texture_id = profession.icon.path + "_" + str(profession.icon.region)
				if texture_id in extraction_event_preview_textures:
					contents = extraction_event_preview_textures[texture_id]
				else:
					contents = profession.icon.get_texture()
					extraction_event_preview_textures[texture_id] = contents
				if contents:
					var icon_rect = Rect2i(
						(Vector2i(event.x, event.y) * tile_size) - profession_icon_size / 2,
						profession_icon_size
					)
					extraction_event_canvas.draw_texture_rect(contents, icon_rect, false, color5)
		
		# Draw Level
		var text = str(str(event.current_level))
		var level_str_size: Vector2i = font.get_string_size(text, align, -1, text_size)
		var text_offset: Vector2i = tile_size + Vector2i(0, font.get_ascent())
		var text_position = Vector2i(event.x, event.y) * tile_size + text_offset - level_str_size / 2
		extraction_event_canvas.draw_string_outline(font, text_position, text, align, -1, text_size, 8, color2)
		extraction_event_canvas.draw_string(font, text_position, text, align, -1, text_size, color1)


func map_to_local(grid_position: Vector2i) -> Vector2i:
	return grid_position * tile_size


func local_to_map(local_position: Vector2i) -> Vector2i:
	var pos = Vector2(local_position.x / float(tile_size.x), local_position.y / float(tile_size.y)) - Vector2.ONE
	var real_pos = Vector2i(pos.ceil())
	return real_pos


func get_map_size_info() -> Dictionary:
	var rect = get_used_rect(false)
	var tiles = {}

	tiles.min_tile = rect.position / tile_size
	tiles.max_tile = tiles.min_tile + rect.size / tile_size
	tiles.min_position = rect.position
	tiles.max_position = rect.end
	
	
	return tiles


func get_used_rect(add_margin: bool = true) -> Rect2i:
	if not Engine.is_editor_hint():
		var r = rect_size_cache.get("map_used_rect")
		if r: return r
		
	var margin = 5
	var rect: Rect2i = Rect2i()
	var tile = Vector2(tile_size)
	for child in get_children():
		if child is TileMapLayer:
			var child_rect = Rect2(child.get_used_rect())
			var child_global_position = child.global_position
			var top_left = child_global_position + child_rect.position * tile * child.scale
			var bottom_right = child_global_position + (child_rect.position + child_rect.size) * tile * child.scale
			var screen_rect = Rect2i(Vector2i(top_left), Vector2i(bottom_right - top_left))
			if screen_rect.has_area():
				if rect:
					rect = rect.merge(screen_rect)
				else:
					rect = screen_rect

	if add_margin and rect.has_area():
		rect.position -= tile_size * margin
		rect.size += Vector2i(tile_size * margin) * 2
	
	if not Engine.is_editor_hint():
		rect_size_cache.map_used_rect = rect

	return rect


func get_ingame_rect() -> Rect2i:
	if not Engine.is_editor_hint():
		var r = rect_size_cache.get("map_ingame_rect")
		if r: return r
	
	var rect: Rect2i = Rect2i()
	for child in get_children():
		if child is TileMapLayer:
			var child_rect = Rect2(child.get_used_rect())
			rect = rect.merge(child_rect)
			#rect.position.x = min(rect.position.x, child_rect.position.x)
			#rect.position.y = min(rect.position.y, child_rect.position.y)
			#rect.size.x = max(rect.size.x, child_rect.size.x - 1)
			#rect.size.y = max(rect.size.y, child_rect.size.y - 1)
	
	if not Engine.is_editor_hint():
		rect_size_cache.map_ingame_rect = rect
	
	return rect


func get_map_size() -> Vector2i:
	if not Engine.is_editor_hint():
		var r = rect_size_cache.get("map_size")
		if r: return r
		
	var rect = get_used_rect(false)
	var size = rect.size - rect.position
	
	if not Engine.is_editor_hint():
		rect_size_cache.map_size = size
		
	return size


func get_map_size_in_tiles() -> Vector2i:
	if not Engine.is_editor_hint():
		var r = rect_size_cache.get("map_size_in_tiles")
		if r: return r
		
	var rect = get_ingame_rect()
	var size = rect.size - rect.position
	
	if not Engine.is_editor_hint():
		rect_size_cache.map_size_in_tiles = size
		
	return size


func get_wrapped_tile(tile: Vector2i) -> Vector2i:
	var rect = get_ingame_rect()

	if rect.has_point(Vector2(tile)):
		return tile
		
	var min = rect.position
	var size = rect.size

	var map_width: int = int(size.x)
	var map_height: int = int(size.y)
	
	var wrapped_x: int
	var wrapped_y: int

	if infinite_horizontal_scroll:
		wrapped_x = min.x + (int(tile.x - min.x) % map_width + map_width) % map_width
	else:
		wrapped_x = tile.x
	if infinite_vertical_scroll:
		wrapped_y = min.y + (int(tile.y - min.y) % map_height + map_height) % map_height
	else:
		wrapped_y = tile.y

	return Vector2i(wrapped_x, wrapped_y)


func get_wrapped_position(position: Vector2) -> Vector2:
	var rect = get_ingame_rect()
	var min = rect.position * tile_size.x
	var size = rect.size * tile_size.y

	var wrapped_x = position.x
	var wrapped_y = position.y

	if infinite_horizontal_scroll:
		wrapped_x = min.x + fposmod(position.x - min.x, size.x)
	if infinite_vertical_scroll:
		wrapped_y = min.y + fposmod(position.y - min.y, size.y)

	return Vector2(wrapped_x, wrapped_y)


#func _get_property_list() -> void:
	#if use_dynamic_day_night:
		#pass


func _validate_property(property):
	var properties = ["internal_id", "events", "extraction_events", "regions", "event_regions", "current_edit_button_pressed", "_baked_keot_data"]
	if property.name in properties:
		property.usage &= ~PROPERTY_USAGE_EDITOR
	
	properties = ["dynamic_day_night_hour", "shadow_parameters"]
	if property.name in properties:
		if use_dynamic_day_night:
			if property.name == "shadow_parameters":
				property.usage = PROPERTY_USAGE_NO_EDITOR
			if property.name == "dynamic_day_night_hour":
				property.usage = PROPERTY_USAGE_EDITOR
		else:
			if property.name == "shadow_parameters":
				property.usage = PROPERTY_USAGE_EDITOR
			if property.name == "dynamic_day_night_hour":
				property.usage = PROPERTY_USAGE_NO_EDITOR
	
	properties = ["use_dynamic_day_night", "dynamic_day_night_hour", "shadow_parameters", "preview_shadows_in_editor"]
	if property.name in properties:
		if not draw_shadows:
			property.usage = PROPERTY_USAGE_NO_EDITOR
		else:
			if property.name == "use_dynamic_day_night" or property.name == "preview_shadows_in_editor":
				property.usage = PROPERTY_USAGE_EDITOR
			elif property.name == "dynamic_day_night_hour":
				property.usage = PROPERTY_USAGE_EDITOR if use_dynamic_day_night else PROPERTY_USAGE_NO_EDITOR
			elif property.name == "shadow_parameters":
				property.usage = PROPERTY_USAGE_NO_EDITOR if use_dynamic_day_night else PROPERTY_USAGE_EDITOR


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
	
	can_add_events = warnings.size() == 0
	
	return warnings


func get_custom_data_layer_names() -> PackedStringArray:
	var layers: PackedStringArray = []
	
	var tile_map_layer: TileMapLayer = MAP_LAYERS.ground
	var tileset = tile_map_layer.tile_set
	var layer_count = tileset.get_custom_data_layers_count()
	
	for i in layer_count:
		layers.append(tileset.get_custom_data_layer_name(i))
	
	return layers

func get_tile_terrain_name(tile: Vector2i) -> PackedStringArray:
	var terrain_name: PackedStringArray = []
	var tile_map_layer: TileMapLayer = MAP_LAYERS.ground
	var tile_data: TileData = tile_map_layer.get_cell_tile_data(tile)
	if tile_data:
		var terrain_set = tile_data.terrain_set
		var terrain = tile_data.terrain
		if terrain_set != -1 and terrain != -1:
			terrain_name.append(tile_map_layer.tile_set.get_terrain_name(terrain_set, terrain).to_lower())
		
		var other_terrains: PackedStringArray = tile_data.get_custom_data("TerrainName")
		if other_terrains:
			terrain_name.append_array(other_terrains)
	
	return terrain_name
	
#endregion


#region Functions used in game
func get_events_near_position(pos: Vector2) -> Array:
	return map_layout.get_events_near_position(pos)


func update_event_position_in_layout(event: Node) -> void:
	map_layout.update_event_position(event)


func is_passable(tile_position: Vector2i, player_direction: int, ignore_node: Node = null, ignore_debug: bool = false) -> bool:
	if Input.is_key_pressed(KEY_CTRL) and OS.is_debug_build() and not moving_event and not ignore_debug:
		return true
	
	# check player:
	if tile_position == GameManager.current_player.get_current_tile():
		return false
	
	# check vehicles
	for vehicle: RPGVehicle in current_ingame_vehicles:
		if ignore_node and vehicle == ignore_node:
			continue
		var vehicle_tile_position = local_to_map(vehicle.global_position)
		if tile_position == vehicle_tile_position:
			return false
		elif vehicle.extra_dimensions:
			var extra_dimensions: RPGDimension = vehicle.extra_dimensions
			var vehicle_left = vehicle_tile_position.x - extra_dimensions.grow_left
			var vehicle_right = vehicle_tile_position.x + extra_dimensions.grow_right + 1
			var vehicle_up = vehicle_tile_position.y - extra_dimensions.grow_up
			var vehicle_down = vehicle_tile_position.y + extra_dimensions.grow_down + 1
			if tile_position.x >= vehicle_left and tile_position.x < vehicle_right and \
			   tile_position.y >= vehicle_up and tile_position.y < vehicle_down:
				return false
		
	# Check map
	var result = is_tile_passable_from_direction(tile_position, player_direction)
	
	if not result:
		return false
	
	# check events:
	for ev: IngameEvent in current_ingame_events.values():
		if not ev: continue
		if ev.lpc_event:
			if !ev.lpc_event.is_passable() and ev.lpc_event.get_current_tile() == tile_position:
				return false

	return true


func is_tile_passable_from_direction(tile_position: Vector2i, player_direction: int, invert: bool = false) -> bool:
	var result = true
	for map in get_children():
		if map is TileMapLayer and map.tile_set:
			var source_id = map.get_cell_source_id(tile_position)
			if source_id != -1:
				var atlas_coord = map.get_cell_atlas_coords(tile_position)
				var source: TileSetSource = map.tile_set.get_source(source_id)
				if source:
					var tile_data: TileData = source.get_tile_data(atlas_coord, 0)
					if tile_data and tile_data.has_custom_data("Passability"):
						var passability: RPGMapPassability = tile_data.get_custom_data("Passability")
						if passability:
							if passability.disabled: continue
							var passable = passability.is_passable(player_direction)
							if passability.is_high_priority:
								match player_direction:
									CharacterBase.DIRECTIONS.LEFT:
										result = passability.right if not invert else passability.left
									CharacterBase.DIRECTIONS.RIGHT:
										result = passability.left if not invert else passability.right
									CharacterBase.DIRECTIONS.UP:
										result = passability.down if not invert else passability.up
									CharacterBase.DIRECTIONS.DOWN:
										result = passability.up if not invert else passability.down
								if result:
									break
							elif not passable:
								result = false

	return result


func get_cell_data(tile_position: Vector2i) -> Dictionary:
	var result = {"keep_events_on_top": false, "layer_z_index": - 1}
	for map in get_children():
		if map is TileMapLayer and map.tile_set:
			var source_id = map.get_cell_source_id(tile_position)
			if source_id != -1:
				var atlas_coord = map.get_cell_atlas_coords(tile_position)
				var source: TileSetSource = map.tile_set.get_source(source_id)
				if source:
					var tile_data: TileData = source.get_tile_data(atlas_coord, 0)
					if tile_data and tile_data.has_custom_data("Keep Events On Top"):
						if tile_data.has_custom_data("Passability"):
							var passability: RPGMapPassability = tile_data.get_custom_data("Passability")
							if passability:
								if passability.disabled: continue
						var keep_events_on_top = tile_data.get_custom_data("Keep Events On Top")
						if keep_events_on_top != null and keep_events_on_top:
							result.keep_events_on_top = true
							result.layer_z_index = max(result.layer_z_index, map.z_index)
	
	return result


# The parameter ignore_is_blocked_tile is used as a failsafe to prevent the player from getting
# stuck on a fully blocked tile (i.e. a tile that doesn't allow movement in any direction).
func can_move_to_direction(tile_position: Vector2i, player_direction: int, ignore_is_blocked_tile: bool = false) -> bool:
	var passable: bool = true
	
	# Check map
	var source_id = MAP_LAYERS.environment.get_cell_source_id(tile_position)
	if source_id != -1:
		var atlas_coord = MAP_LAYERS.environment.get_cell_atlas_coords(tile_position)
		var source: TileSetSource = MAP_LAYERS.environment.tile_set.get_source(source_id)
		if source:
			var tile_data: TileData = source.get_tile_data(atlas_coord, 0)
			if tile_data:
				var passability: RPGMapPassability = tile_data.get_custom_data("Passability")
				if passability:
					if ignore_is_blocked_tile:
						if not passability.is_blocked():
							passable = passability.is_passable(player_direction)
					else:
						passable = passability.is_passable(player_direction)
	
	return passable


func is_tile_block(tile_position: Vector2i) -> bool:
	var block: bool = true
	
	# Check map
	var source_id = MAP_LAYERS.environment.get_cell_source_id(tile_position)
	if source_id != -1:
		var atlas_coord = MAP_LAYERS.environment.get_cell_atlas_coords(tile_position)
		var source: TileSetSource = MAP_LAYERS.environment.tile_set.get_source(source_id)
		if source:
			var tile_data: TileData = source.get_tile_data(atlas_coord, 0)
			if tile_data:
				var passability: RPGMapPassability = tile_data.get_custom_data("Passability")
				if passability:
					block = passability.is_blocked()
	
	return block


func can_move_over_terrain(tile: Vector2i, terrains: PackedStringArray) -> bool:
	if Input.is_key_pressed(KEY_CTRL) and OS.is_debug_build() and not moving_event:
		return true

	var tile_map_layer: TileMapLayer = MAP_LAYERS.ground
	var tile_data: TileData = tile_map_layer.get_cell_tile_data(tile)
	var all_tags = Array(terrains).map(
		func(obj: String): return obj.to_lower())
	var forbidden_tags = all_tags.filter(
		func(obj: String): return obj.begins_with("^")).map(func(obj: String): return obj.substr(1))
	var partial_tags = all_tags.filter(
		func(obj: String): return obj.begins_with("*")).map(func(obj: String): return obj.substr(1))
	var exact_tags = all_tags.filter(
		func(obj: String): return obj[0] != "*" and obj[0] != "^").map(func(obj: String): return obj)
	
	if exact_tags.has("all"):
		return true
	
	if tile_data:
		var terrain_set = tile_data.terrain_set
		var terrain = tile_data.terrain
		var current_terrains: PackedStringArray = []
		if terrain_set != -1 and terrain != -1:
			current_terrains.append(tile_map_layer.tile_set.get_terrain_name(terrain_set, terrain).to_lower())
		var other_terrains: PackedStringArray = tile_data.get_custom_data("TerrainName")
		if not other_terrains.is_empty():
			current_terrains.append_array(other_terrains)

		if not current_terrains.is_empty():
			for terrain_name in current_terrains:
				for t in forbidden_tags:
					if terrain_name.find(t) != -1:
						return false
					
				for t in partial_tags:
					if terrain_name.find(t) != -1:
						return true
			
				for t in exact_tags:
					if terrain_name == t:
						return true
	else:
		return false
	
	if forbidden_tags.size() > 0 and partial_tags.is_empty() and exact_tags.is_empty():
		return true
		
	return false

#endregion
