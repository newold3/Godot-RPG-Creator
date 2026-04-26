@tool
class_name CharacterBase
extends CharacterBody2D

#region Export and Variables
## Terrains over which this player can move
@export var can_move_on_terrains: PackedStringArray = ["^lava", "^water"]

## Visual indicator scene instantiated when the player clicks on a map tile
@export var click_indicator_scene: PackedScene = preload("res://Scenes/OtherScenes/click_on_map.tscn")

@export_category("Carry & Throw Indicators")
## Indicates if the player should show a visual marker where the carried object will land
@export var show_throw_indicator: bool = true

## Color used for the throw indicator when the target is valid
@export var valid_throw_color: Color = Color.BLACK

## Color used for the throw indicator when the target is invalid or blocked
@export var invalid_throw_color: Color = Color.RED

## Texture used for the throw indicator, defaults to a simple rect if empty
@export var throw_indicator_texture: Texture2D = preload("uid://denhhg8ng2ipw")

enum DIRECTIONS {
	LEFT = RPGMapPassability.DIR_LEFT,
	RIGHT = RPGMapPassability.DIR_RIGHT,
	UP = RPGMapPassability.DIR_UP,
	DOWN = RPGMapPassability.DIR_DOWN
}

enum MOVEMENTMODE {GRID = 1, FREE = 2, EVENT = 3}

enum LiftTriggers {
	NONE = 0,
	PRE_LIFT = 1,
	POST_LIFT = 2,
	PRE_THROW = 4,
	POST_THROW = 8
}

class TextureData:
	var part_id: String
	var back_texture: String
	var front_texture: String
	var is_large_texture: bool
	var palette1: RPGLPCPalette
	var palette2: RPGLPCPalette
	var palette3: RPGLPCPalette

var movement_current_mode = MOVEMENTMODE.GRID :
	set(value):
		movement_current_mode = value
		if is_node_ready():
			adjust_bounds()
var movement_speed: float = 100
var running_speed: float = 130
var is_moving = false
var is_jumping = false
var can_move: bool = true
var is_running = false
var target_position = Vector2.ZERO
var grid_move_duration: Vector2
var movement_vector = Vector2.ZERO
var current_map_tile_size: Vector2i = Vector2i.ZERO
var map_offset: Vector2i
var cumulative_steps: float = 0
var is_invalid_event: bool = false
var current_direction: DIRECTIONS = DIRECTIONS.DOWN
var last_direction: DIRECTIONS = DIRECTIONS.DOWN
var event_movement_type: int = 0
var event_movement_frequency: int = 10
var event_movement_frame_count: int = 0
var route_commands: RPGMovementRoute
var route_command_index: int = 0
var _processing_command_route: bool = false
var update_texture_timer: float = 0.0
var current_frame: int = -1
var current_animation: String = "idle"
var frame_delay: float = 0.0
var frame_delay_max: float = 0.1
var frame_delay_max_running: float = 0.05
var frame_delay_max_attacking: float = 0.05
var previous_tile: Vector2i
var is_attacking: bool = false
var can_attack: bool = true
var is_on_vehicle = false
var current_vehicle: RPGVehicle = null
var current_weapon_data: Dictionary
var current_virtual_tile: Vector2
var collision_disabled: bool = false
var force_locked: bool = false
var activated_this_frame: bool = false
var _last_route_movement: Vector2i
var _contact_activation_delay: float = 0.0
var _contact_activation_cooldown: float = 1.0
var _ignore_events_contact: Array = []
var _squared_tile_size: int

@onready var character_options: CharacterOptions

var movement_tween: Tween
var contact_area_tween: Tween
var busy: bool = false
var busy2: bool = false
var force_animation_enabled: bool = false
var targets_over_me: Array = []
var movement_history: Array[Dictionary] = []
var _last_recorded_pos: Vector2 = Vector2.ZERO
var _last_recorded_scale: Vector2 = Vector2.ONE
var _auto_target_tile: Vector2i = Vector2i(-1, -1)
var _auto_target_event: Node = null
var _click_indicator_cooldown: float = 0.0
var _last_auto_path_tile: Vector2i = Vector2i(-1, -1)
var _auto_path_stuck_frames: int = 0
var interactive_event: Node
var is_dual_animation: bool = false
var dual_top_animation: String = "lift"
var dual_top_frame: int = 0
var dual_crop_offset_y: float = 54.0
var original_body_texture: Texture2D
var dual_frame_cache: Dictionary = {}
var carried_event: Node2D = null
var throw_indicator_node: Node2D
var is_lifting: bool = false
var is_pushing: bool = false
var _cached_collision_layer: int = 1
var _cached_collision_mask: int = 1

const MAX_HISTORY_SIZE: int = 300
const MIN_RECORD_DIST_SQ: float = 2.0
const MAX_FLEE_DISTANCE_SQUARED: int = 25
const MAX_JUMP_HEIGHT: int = 48
const JUMP_PARTICLES = preload("res://Scenes/ParticleScenes/jump_particles.tscn")

var _movement_module: CharacterBaseMovement
var _interaction_module: CharacterBaseInteraction
var _manipulation_module: CharacterBaseManipulation
var _navigation_module: CharacterBaseNavigation
var _history_module: CharacterBaseHistory

signal animation_finished()
signal attack(animation: String)
signal start_motion(motion: Vector2)
signal end_movement()
signal event_start_movement()
signal idle_setted()
#endregion


#region Base functions
func _init() -> void:
	_movement_module = CharacterBaseMovement.new()
	_movement_module.current_entity = self
	
	_interaction_module = CharacterBaseInteraction.new()
	_interaction_module.current_entity = self
	
	_manipulation_module = CharacterBaseManipulation.new()
	_manipulation_module.current_entity = self
	
	_navigation_module = CharacterBaseNavigation.new()
	_navigation_module.current_entity = self
	
	_history_module = CharacterBaseHistory.new()
	_history_module.current_entity = self



func get_class() -> String: 
	return "CharacterBase"



func get_custom_class() -> String: 
	return "CharacterBase"



func _ready() -> void:
	previous_tile = get_current_tile()
	set_character_options(CharacterOptions.new())
	end_movement.connect(_on_end_movement)
	initialize_virtual_tile()
	
	if GameManager.current_map:
		var tile_size: Vector2i = GameManager.get_map_tile_size()
		_squared_tile_size = tile_size.length_squared()
		GameManager.current_map.update_event_position_in_layout(self)
	
	throw_indicator_node = Node2D.new()
	throw_indicator_node.name = "ThrowIndicator"
	throw_indicator_node.top_level = true
	throw_indicator_node.z_index = 100
	add_child(throw_indicator_node)
	throw_indicator_node.draw.connect(_on_throw_indicator_draw)



func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.is_pressed() and event.keycode == KEY_T:
		if is_dual_animation:
			disable_dual_animation()
		else:
			enable_dual_animation("start_lift", "lift")



func _process(_delta: float) -> void:
	if GameManager.loading_game or is_invalid_event or busy2 or Engine.is_editor_hint():
		return
		
	if is_in_group("player") and not is_on_vehicle:
		_smart_record_history()



func _physics_process(delta: float):
	if GameManager.loading_game or is_invalid_event or busy2 or Engine.is_editor_hint() or GameManager.busy or GameInterpreter.is_busy():
		return
		
	if show_throw_indicator and is_instance_valid(throw_indicator_node):
		throw_indicator_node.queue_redraw()
		
	if is_in_group("player"):
		_save_player_position_into_game_state()
		
	if _click_indicator_cooldown > 0.0:
		_click_indicator_cooldown -= delta
		
	if ControllerManager.is_action_just_released("Mouse Left"):
		_click_indicator_cooldown = 0.0
		
	if not Engine.is_editor_hint() and is_in_group("player"):
		if ControllerManager.is_action_just_pressed("Button L2"):
			if not carried_event and not is_lifting:
				if GameManager.current_player: GameManager.current_player.busy2 = true
				await GameManager.shift_up_follower()
				if GameManager.current_player: GameManager.current_player.busy2 = false
		elif ControllerManager.is_action_just_pressed("Button R2"):
			if not carried_event and not is_lifting:
				if GameManager.current_player: GameManager.current_player.busy2 = true
				await GameManager.shift_down_follower()
				if GameManager.current_player: GameManager.current_player.busy2 = false
		elif GameManager.current_map and ControllerManager.is_action_pressed("Mouse Left"):
			if not GameInterpreter.is_busy() and not GameManager.busy and not busy2:
				var is_new_click = ControllerManager.is_action_just_pressed("Mouse Left")
				var mouse_pos = GameManager.current_map.get_local_mouse_position()
				var tile: Vector2i = GameManager.current_map.local_to_map(mouse_pos)
				if is_new_click or (tile != _auto_target_tile and _click_indicator_cooldown <= 0.0):
					_set_target_destination(tile, is_new_click)
					
	activated_this_frame = false
	
	if not busy and _contact_activation_delay > 0:
		_contact_activation_delay -= delta
		
	if not _ignore_events_contact.is_empty():
		for i in range(_ignore_events_contact.size() - 1, -1, -1):
			var obj = _ignore_events_contact[i]
			if not is_instance_valid(obj) or obj == self:
				_ignore_events_contact.remove_at(i)
				continue
			if position.distance_squared_to(obj.position) > _squared_tile_size:
				_ignore_events_contact.remove_at(i)
				
	if not targets_over_me.is_empty():
		var current_tile = get_current_tile()
		for i in range(targets_over_me.size() - 1, -1, -1):
			if targets_over_me[i] is Node and targets_over_me[i].has_method("get_current_tile"):
				if targets_over_me[i].get_current_tile() != current_tile:
					targets_over_me.remove_at(i)
			else:
				targets_over_me.remove_at(i)
				
	if is_on_vehicle:
		if route_commands:
			update_process_route()
		return
		
	if is_inside_tree():
		queue_redraw()
		
	if busy or is_attacking or is_jumping or is_moving or force_locked:
		return
		
	if is_in_group("player") and _auto_target_tile != Vector2i(-1, -1):
		_process_auto_movement()
		
	if movement_current_mode == MOVEMENTMODE.EVENT and GameManager.current_map:
		GameManager.current_map.moving_event = true
		
	match movement_current_mode:
		MOVEMENTMODE.GRID:
			if route_commands:
				update_process_route()
			else:
				grid_movement()
		MOVEMENTMODE.FREE:
			if route_commands:
				update_process_route()
			else:
				free_movement(delta)
		MOVEMENTMODE.EVENT:
			event_movement_frame_count += 1
			if event_movement_frame_count >= event_movement_frequency:
				event_movement()
				event_movement_frame_count = 0
				
	if movement_current_mode == MOVEMENTMODE.EVENT and GameManager.current_map:
		GameManager.current_map.moving_event = false



func _on_end_movement() -> void:
	if GameManager.current_map:
		GameManager.current_map.update_event_position_in_layout(self)
		
	call_deferred("_check_contact_after_move")
	previous_tile = get_current_tile()
	_check_nearby_events_for_activation()



func set_character_options(new_options: CharacterOptions) -> void:
	character_options = new_options
	if character_options.changed.is_connected(_on_character_options_changed):
		character_options.changed.disconnect(_on_character_options_changed)
	character_options.changed.connect(_on_character_options_changed)



func _on_character_options_changed() -> void:
	calculate_grid_move_duration()



func enable_dual_animation(start_animation: String, end_animation: String) -> void:
	busy = true
	current_animation = "idle"
	current_frame = 0
	
	if not start_animation.is_empty():
		force_animation_enabled = true
		current_animation = start_animation
		dual_top_frame = 0
		await animation_finished
		
	dual_top_frame = 0
	force_animation_enabled = false
	is_dual_animation = true
	dual_top_animation = end_animation
	busy = false



func disable_dual_animation() -> void:
	is_dual_animation = false
	dual_top_animation = ""
	dual_top_frame = 0
	current_animation = "idle"
	current_frame = 0
	animation_finished.emit()



func attack_with_weapon() -> void:
	pass



func attack_without_weapon() -> void:
	pass



func run_animation() -> void:
	pass



func adjust_bounds() -> void:
	pass



func _reset(force_reset: bool = false) -> void:
	pass



func _animation_to_idle() -> void:
	if not is_moving and not force_animation_enabled:
		current_animation = "idle"
	idle_setted.emit()



func _disable_collision_shape(value: bool) -> void:
	var node = get_node_or_null("%CollisionShape")
	if node and node is CollisionShape2D:
		node.set_deferred("disabled", value)



func update_virtual_tile(motion: Vector2 = Vector2.ZERO) -> void:
	var map = GameManager.current_map
	if not map:
		return
	
	if motion != Vector2.ZERO:
		var motion_in_tiles = Vector2(
			(motion.x / current_map_tile_size.x),
			(motion.y / current_map_tile_size.y)
		)
		current_virtual_tile += motion_in_tiles
	else:
		current_virtual_tile = map.get_tile_from_position(global_position)



func get_current_virtual_tile() -> Vector2i:
	return current_virtual_tile.round()



func get_current_virtual_tile_position() -> Vector2:
	var tile = current_virtual_tile
	return tile * Vector2(current_map_tile_size)



func initialize_virtual_tile() -> void:
	var map = GameManager.current_map
	if map:
		current_virtual_tile = map.get_tile_from_position(global_position)



func get_current_tile() -> Vector2i:
	if is_on_vehicle and current_vehicle:
		return current_vehicle.get_current_tile()
	else:
		var map = GameManager.current_map
		if map:
			if is_moving:
				return map.get_tile_from_position(target_position)
			else:
				return map.get_tile_from_position(global_position)
	return Vector2i(0, 0)



func get_previous_tile() -> Vector2i:
	return previous_tile



func get_current_position() -> Vector2:
	if is_on_vehicle and current_vehicle:
		var real_position = current_vehicle.get_player_position()
		return real_position
	else:
		var map = GameManager.current_map
		if map:
			if is_moving:
				return target_position
			else:
				return global_position
	return Vector2i(0, 0)



func get_mouth_position() -> Vector2:
	var mouth = get_node_or_null("%Mouth")
	if mouth:
		return mouth.position
	return Vector2.ZERO



func get_global_mouth_position() -> Vector2:
	var mouth = get_node_or_null("%Mouth")
	if mouth:
		return mouth.global_position
	return Vector2.ZERO



func get_body_region_rect() -> Rect2:
	var node = get_node_or_null("%Body")
	if node:
		return node.region_rect
	return Rect2()



func _save_player_position_into_game_state() -> void:
	if GameManager.loading_game:
		return
	if GameManager.game_state:
		GameManager.game_state.current_map_position = get_current_tile()
		GameManager.game_state.current_direction = current_direction



func _execute_real_event_page(event_node: Node2D) -> void:
	if "current_event" in event_node and event_node.current_event is RPGEvent:
		var real_page = event_node.current_event.get_active_page()
		if real_page and real_page.list.size() > 0:
			var objs: Array[Dictionary] = []
			objs.append({"obj": event_node, "commands": real_page.list, "id": str(event_node.get_rid())})
			await GameInterpreter.auto_start_automatic_events(objs)



func _on_throw_indicator_draw() -> void:
	var map = GameManager.current_map
	
	if not show_throw_indicator or not carried_event or not map:
		return
		
	var throw_info = _manipulation_module._get_throw_target_info()
	var target_tile = throw_info.tile
	var is_valid = throw_info.distance > 0
	
	if not is_valid:
		var dir_vec = Vector2i.ZERO
		match current_direction:
			DIRECTIONS.UP: dir_vec = Vector2i(0, -1)
			DIRECTIONS.DOWN: dir_vec = Vector2i(0, 1)
			DIRECTIONS.LEFT: dir_vec = Vector2i(-1, 0)
			DIRECTIONS.RIGHT: dir_vec = Vector2i(1, 0)
		target_tile = get_current_tile() + dir_vec
		
	var target_global_pos = map.get_tile_position(target_tile)
	var tile_size = Vector2(map.tile_size)
	var rect = Rect2(target_global_pos - Vector2(tile_size.x / 2.0, tile_size.y), tile_size)
	var color = valid_throw_color if is_valid else invalid_throw_color
	
	if throw_indicator_texture:
		throw_indicator_node.draw_texture_rect(throw_indicator_texture, rect, false, color)
	else:
		throw_indicator_node.draw_rect(rect, color, true)
		color.a = min(color.a + 0.4, 1.0)
		throw_indicator_node.draw_rect(rect, color, false, 2.0)



func _draw() -> void:
	var map = GameManager.current_map
	
	if map and get_tree().debug_collisions_hint:
		var p = map.get_tile_position(get_current_tile())
		var l_pos = to_local(p) - map.event_offset
		draw_rect(
			Rect2(l_pos.x, l_pos.y, map.tile_size.x, map.tile_size.y),
			Color(1, 0, 0, 0.55), true
		)
#endregion


#region WRAPPER FUNCTIONS - CharacterBaseMovement
func calculate_grid_move_duration() -> void:
	_movement_module.calculate_grid_move_duration()



func get_motion(target_pos: Vector2) -> Dictionary:
	return _movement_module.get_motion(target_pos)



func get_possible_movements(motion: Vector2, is_jump_action: bool = false) -> Vector2i:
	return _movement_module.get_possible_movements(motion, is_jump_action)



func get_tile_passability(target_tile: Vector2i, motion: Vector2) -> Vector2i:
	return _movement_module.get_tile_passability(target_tile, motion)



func _try_move_with_free_mode(current_tile: Vector2i, motion: Vector2) -> Vector2i:
	return _movement_module._try_move_with_free_mode(current_tile, motion)



func set_vertical_look(motion: Vector2) -> void:
	_movement_module.set_vertical_look(motion)



func set_horizontal_look(motion: Vector2) -> void:
	_movement_module.set_horizontal_look(motion)



func set_current_look(motion: Vector2) -> void:
	_movement_module.set_current_look(motion)



func grid_movement() -> void:
	_movement_module.grid_movement()



func free_movement(delta: float) -> void:
	_movement_module.free_movement(delta)



func start_movement(motion_data: Dictionary) -> void:
	_movement_module.start_movement(motion_data)



func _update_position(new_position: Vector2, old_position_cache: Array) -> void:
	_movement_module._update_position(new_position, old_position_cache)



func _animate_contact_area(final_motion: Vector2) -> void:
	_movement_module._animate_contact_area(final_motion)



func _set_contact_area_size(width: float, collision_shape: CollisionShape2D, motion: Vector2) -> void:
	_movement_module._set_contact_area_size(width, collision_shape, motion)



func _on_grid_movement_finished(target_pos: Vector2) -> void:
	_movement_module._on_grid_movement_finished(target_pos)



func move_event(new_pos: Vector2, route: RPGMovementRoute = null, keep_direction: bool = false) -> void:
	await _movement_module.move_event(new_pos, route, keep_direction)



func vehicle_movement(motion: Vector2, route: RPGMovementRoute = null, keep_direction: bool = false) -> void:
	await _movement_module.vehicle_movement(motion, route, keep_direction)



func jump_to(new_pos: Vector2, route: RPGMovementRoute = null, start_fx: Dictionary = {}, end_fx: Dictionary = {}) -> void:
	await _movement_module.jump_to(new_pos, route, start_fx, end_fx)



func vehicle_jump_to(new_pos: Vector2, route: RPGMovementRoute = null, start_fx: Dictionary = {}, end_fx: Dictionary = {}) -> void:
	await _movement_module.vehicle_jump_to(new_pos, route, start_fx, end_fx)



func is_processin_moving() -> bool:
	return _movement_module.is_processin_moving()



func kill_movement() -> void:
	_movement_module.kill_movement()
#endregion


#region WRAPPER FUNCTIONS - CharacterBaseInteraction
func _set_target_destination(tile: Vector2i, is_new_click: bool = true) -> void:
	_interaction_module._set_target_destination(tile, is_new_click)



func _process_auto_movement() -> void:
	_interaction_module._process_auto_movement()



func _look_at_tile_direction(diff: Vector2i) -> void:
	_interaction_module._look_at_tile_direction(diff)



func _interact_with_click_target() -> void:
	_interaction_module._interact_with_click_target()



func _process_event_contact(contacting_entities: Array, stop_movement_on_activate: bool) -> bool:
	return _interaction_module._process_event_contact(contacting_entities, stop_movement_on_activate)



func _check_contact(tile: Vector2i, check_passable: bool = false) -> bool:
	return _interaction_module._check_contact(tile, check_passable)



func _check_nearby_events_for_activation() -> void:
	_interaction_module._check_nearby_events_for_activation()



func look_at_event(event: Variant) -> void:
	_interaction_module.look_at_event(event)



func _check_contact_before_move(tile: Vector2i, is_after_move: bool = false) -> bool:
	return _interaction_module._check_contact_before_move(tile, is_after_move)



func _check_contact_after_move() -> void:
	_interaction_module._check_contact_after_move()



func _is_solid(entity: Node) -> bool:
	return _interaction_module._is_solid(entity)



func _can_activate_event(my_entity, other_entity) -> bool:
	return _interaction_module._can_activate_event(my_entity, other_entity)



func _handle_player_contact(player, entity, entity_is_player: bool) -> Dictionary:
	return _interaction_module._handle_player_contact(player, entity, entity_is_player)



func _handle_event_vs_player(event, player, my_is_solid: bool, my_is_moving: bool) -> Dictionary:
	return _interaction_module._handle_event_vs_player(event, player, my_is_solid, my_is_moving)



func _handle_solid_vs_solid(my_event, other_event, my_is_moving: bool, other_is_moving: bool) -> Dictionary:
	return _interaction_module._handle_solid_vs_solid(my_event, other_event, my_is_moving, other_is_moving)



func _handle_solid_vs_passable(my_event, other_event, my_is_moving: bool, other_is_moving: bool) -> Dictionary:
	return _interaction_module._handle_solid_vs_passable(my_event, other_event, my_is_moving, other_is_moving)



func _handle_passable_vs_solid(my_event, other_event, other_is_moving: bool) -> Dictionary:
	return _interaction_module._handle_passable_vs_solid(my_event, other_event, other_is_moving)



func _handle_passable_vs_passable(my_event, other_event) -> Dictionary:
	return _interaction_module._handle_passable_vs_passable(my_event, other_event)



func _add_mutual_ignore(entity_a: Node, entity_b: Node) -> void:
	_interaction_module._add_mutual_ignore(entity_a, entity_b)



func _add_to_ignore(entity: Node) -> void:
	_interaction_module._add_to_ignore(entity)



func _has_ignore_entity(entity: Node) -> bool:
	return _interaction_module._has_ignore_entity(entity)



func _remove_duplicates(array: Array) -> Array:
	return _interaction_module._remove_duplicates(array)



func _trigger_events(valid_contacts: Array) -> void:
	_interaction_module._trigger_events(valid_contacts)



func get_events_at_adjacent_tile() -> Array:
	return _interaction_module.get_events_at_adjacent_tile()
#endregion


#region WRAPPER FUNCTIONS - CharacterBaseManipulation
func _get_shoulders() -> Marker2D:
	return _manipulation_module._get_shoulders()



func pick_up_event(event_node: Node2D) -> void:
	await _manipulation_module.pick_up_event(event_node)



func _get_throw_target_info() -> Dictionary:
	return _manipulation_module._get_throw_target_info()



func throw_event() -> void:
	await _manipulation_module.throw_event()



func enable_push_mode() -> void:
	_manipulation_module.enable_push_mode()



func disable_push_mode() -> void:
	_manipulation_module.disable_push_mode()



func _get_pushable_event_in_direction(dir: Vector2) -> Node2D:
	return _manipulation_module._get_pushable_event_in_direction(dir)



func try_push_event(event: Node2D, dir: Vector2) -> void:
	await _manipulation_module.try_push_event(event, dir)



func _execute_push_loop(event: Node2D, dir: Vector2) -> void:
	await _manipulation_module._execute_push_loop(event, dir)



func _is_push_input_active(dir: Vector2) -> bool:
	return _manipulation_module._is_push_input_active(dir)



func _cancel_push() -> void:
	_manipulation_module._cancel_push()
#endregion


#region WRAPPER FUNCTIONS - CharacterBaseNavigation
func get_opposite_direction(direction: int) -> int:
	return _navigation_module.get_opposite_direction(direction)



func set_direction(direction: int) -> void:
	_navigation_module.set_direction(direction)



func event_movement() -> void:
	await _navigation_module.event_movement()



func update_process_route() -> void:
	await _navigation_module.update_process_route()



func _get_next_move_toward_target(target: Vector2i, target_screen_position: Vector2) -> Vector2i:
	return _navigation_module._get_next_move_toward_target(target, target_screen_position)



func _get_next_move_toward_player() -> Vector2i:
	return _navigation_module._get_next_move_toward_player()



func _get_next_move_toward_event() -> Vector2i:
	return _navigation_module._get_next_move_toward_event()



func _get_next_move_away_from_player() -> Vector2i:
	return _navigation_module._get_next_move_away_from_player()



func _get_wrapped_distance_sq(from_pos: Vector2i, to_pos: Vector2i, size: Vector2i, inf_x: bool, inf_y: bool) -> float:
	return _navigation_module._get_wrapped_distance_sq(from_pos, to_pos, size, inf_x, inf_y)



func _is_movement_route_command(command: RPGMovementCommand) -> bool:
	return _navigation_module._is_movement_route_command(command)



func _rotate_left(direction: int) -> int:
	return _navigation_module._rotate_left(direction)



func _rotate_right(direction: int) -> int:
	return _navigation_module._rotate_right(direction)



func process_route_command() -> Dictionary:
	return _navigation_module.process_route_command()
#endregion


#region WRAPPER FUNCTIONS - CharacterBaseHistory
func _smart_record_history() -> void:
	_history_module._smart_record_history()



func _add_snapshot(snapshot: Dictionary = {}) -> void:
	_history_module._add_snapshot(snapshot)



func clear_movement_history() -> void:
	_history_module.clear_movement_history()



func get_history_step(step_offset: int) -> Dictionary:
	return _history_module.get_history_step(step_offset)



func shift_history_and_followers(offset: Vector2) -> void:
	_history_module.shift_history_and_followers(offset)



func apply_map_wrap_offset(offset: Vector2) -> void:
	_history_module.apply_map_wrap_offset(offset)
#endregion
