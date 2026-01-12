@tool
class_name CharacterBase
extends CharacterBody2D

func get_class() -> String: return "CharacterBase"
func get_custom_class() -> String: return "CharacterBase"


## Terrains over which this player can move
## (Use a "*" at the beginning to include any terrain whose name contains the specified terrain name, or use a “” at the beginning to exclude any terrain whose name contains the specified terrain name. or "all" to include any terrain.)
@export var can_move_on_terrains: PackedStringArray = ["^lava", "^water"]


enum DIRECTIONS {
	LEFT = RPGMapPassability.DIR_LEFT,
	RIGHT = RPGMapPassability.DIR_RIGHT,
	UP = RPGMapPassability.DIR_UP,
	DOWN = RPGMapPassability.DIR_DOWN
}

enum MOVEMENTMODE {GRID = 1, FREE = 2, EVENT = 3}

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
var running_speed: float = 150
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

var update_texture_timer: float = 0.0
var current_frame: int = -1
var current_animation: String = "idle"
var frame_delay: float = 0.0
var frame_delay_max: float = 0.1
var frame_delay_max_running: float = 0.05
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


# Must be serialized and deserialized in save file
@onready var character_options: CharacterOptions

var movement_tween: Tween
var contact_area_tween: Tween

var busy: bool = false
var force_animation_enabled: bool = false

var targets_over_me: Array = []

const MAX_FLEE_DISTANCE_SQUARED: int = 25
const MAX_JUMP_HEIGHT: int = 48

const JUMP_PARTICLES = preload("res://Scenes/ParticleScenes/jump_particles.tscn")


signal animation_finished()
signal attack(animation: String)
signal start_motion(motion: Vector2)
signal end_movement()
signal event_start_movement()


func _ready() -> void:
	previous_tile = get_current_tile()
	set_character_options(CharacterOptions.new())
	end_movement.connect(_on_end_movement)
	initialize_virtual_tile()
	if GameManager.current_map:
		_squared_tile_size = GameManager.current_map.tile_size.length_squared()
		GameManager.current_map.update_event_position_in_layout(self)


func _on_end_movement() -> void:
	if GameManager.current_map:
		GameManager.current_map.update_event_position_in_layout(self)

	call_deferred("_check_contact_after_move")
	previous_tile = get_current_tile()
	#_check_nearby_events_for_activation()


func set_character_options(new_options: CharacterOptions) -> void:
	character_options = new_options
	if character_options.changed.is_connected(_on_character_options_changed):
		character_options.changed.disconnect(_on_character_options_changed)
	character_options.changed.connect(_on_character_options_changed)


func _on_character_options_changed() -> void:
	calculate_grid_move_duration()


func _physics_process(delta: float):
	if GameManager.loading_game or is_invalid_event:
		return 
	
	if is_in_group("player"):
		_save_player_position_into_game_state()
	
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
	
	if is_on_vehicle: return
				
	if is_inside_tree():
		queue_redraw()
		
	if busy or is_attacking or is_jumping or is_moving or force_locked:
		return
	
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
			event_movement_frame_count +=  1
			if event_movement_frame_count >= event_movement_frequency:
				event_movement()
				event_movement_frame_count = 0
	
	if movement_current_mode == MOVEMENTMODE.EVENT and GameManager.current_map:
		GameManager.current_map.moving_event = false


func _should_check_nearby_events() -> bool:
	var page = get("current_event_page")
	if not page:
		return false
	
	return page.launcher == RPGEventPage.LAUNCHER_MODE.ANY_CONTACT or \
		   page.launcher == RPGEventPage.LAUNCHER_MODE.EVENT_COLLISION or \
		   page.launcher == RPGEventPage.LAUNCHER_MODE.PLAYER_COLLISION


func _draw() -> void:
	var map = GameManager.current_map
	if map and get_tree().debug_collisions_hint:
		var tile = get_current_tile()
		var p = map.get_tile_position(tile)
		var local_pos = to_local(p) - map.event_offset
		draw_rect(
			Rect2(local_pos.x, local_pos.y, map.tile_size.x, map.tile_size.y),
			Color(1, 0, 0, 0.55), true
		)


func calculate_grid_move_duration():
	var sp = 0.0000000000001 + (movement_speed if !is_running else running_speed)
	grid_move_duration = Vector2(
		current_map_tile_size.x / sp,
		current_map_tile_size.y / sp
	)


func get_opposite_direction(direction: int) -> int:
	match direction:
		RPGMapPassability.DIR_LEFT:
			return RPGMapPassability.DIR_RIGHT
		RPGMapPassability.DIR_RIGHT:
			return RPGMapPassability.DIR_LEFT
		RPGMapPassability.DIR_UP:
			return RPGMapPassability.DIR_DOWN
		RPGMapPassability.DIR_DOWN:
			return RPGMapPassability.DIR_UP
	return 0


func set_direction(direction: int) -> void:
	last_direction = direction
	current_direction = direction


func event_movement() -> void:
	if is_jumping or GameManager.loading_game: return
	
	var has_route = route_commands and not route_commands.list.is_empty()
	
	previous_tile = get_current_tile()
	
	if is_moving or busy or GameInterpreter.busy:
		if has_route and route_commands.is_route_from_interpreter:
			update_process_route() # update route if called from interpreter
		return
	
	var type = 4 if has_route else event_movement_type
	var movement_result: Vector2i
	match type:
		0: # Immobile
			pass
		1: # Random
			movement_result =  Vector2i(randi_range(0, 2) - 1, randi_range(0, 2) - 1)
		2: # Approach To Player
			movement_result = _get_next_move_toward_player()
		3: # Move Away From Player
			movement_result = _get_next_move_away_from_player()
		4: # Route
			update_process_route()
		5: # Approach To Other Event
			movement_result = _get_next_move_toward_event()
			
			if movement_result:
				var motion_data = get_motion(movement_result)
				#movement_result = Vector2i.ONE
	
	if movement_result:
		await move_event(movement_result, null)
		end_movement.emit()
		
	if type == 2: # Fix Direction
		if not character_options.fixed_direction:
			var player = GameManager.current_player if not GameManager.current_player.is_on_vehicle else GameManager.current_player.current_vehicle
			var player_tile = player.get_current_tile()
			var self_tile = get_current_tile()
			var delta_tile = player_tile - self_tile
			var map_size = GameManager.current_map.get_map_size_in_tiles()
			if abs(delta_tile.x) > map_size.x / 2:
				delta_tile.x -= sign(delta_tile.x) * map_size.x
			if abs(delta_tile.y) > map_size.y / 2:
				delta_tile.y -= sign(delta_tile.y) * map_size.y
			var motion = delta_tile
			var diagonal_movement_direction_mode = RPGSYSTEM.database.system.options.get("movement_mode", 0)
			match diagonal_movement_direction_mode:
				0: set_vertical_look(motion)
				1: set_horizontal_look(motion)
				2: set_current_look(motion)
			current_direction = last_direction
	
	update_virtual_tile()


func get_motion(target_position: Vector2) -> Dictionary:
	var map = GameManager.current_map
	var motion = Vector2.ZERO
	var result = {"final_motion": motion, "current_motion": motion}
	var disable_motion: bool = false
	# Verify if the movement is possible
	var possible_movements = get_possible_movements(target_position)
	if !possible_movements:
		disable_motion = true

	result.current_motion =  target_position * Vector2(current_map_tile_size)
	
	# Calculate the target position
	target_position.x = floor(target_position.x) if target_position.x < 0 else ceil(target_position.x)
	target_position.y = floor(target_position.y) if target_position.y < 0 else ceil(target_position.y)
	target_position *= Vector2(possible_movements)

	motion = target_position * Vector2(current_map_tile_size)

	var backup_motion = motion
	
	var collision: KinematicCollision2D = move_and_collide(motion, true)

	if collision:
		motion = Vector2i.ZERO

	if !motion and backup_motion and !collision_disabled: # possible collision?
		if map:
			var event_count = map.get_events_in_place(get_current_tile())
			if event_count > 1:
				motion = backup_motion
				collision_disabled = true
				call_deferred("_disable_collision_shape", true)

	if collision_disabled:
		var event_count = map.get_events_in_place(get_current_tile())
		if event_count <= 1:
			collision_disabled = false
			call_deferred("_disable_collision_shape", false)
		elif randi() % 10 > 2: # lucky shot to delay the movement if condition is met
			motion = Vector2.ZERO
	if map and motion:
		var current_tile = get_current_tile()
		if (
			not map.is_tile_block(current_tile) and
			not map.can_move_to_direction(current_tile, current_direction) and
			not ((Input.is_key_pressed(KEY_CTRL) and OS.is_debug_build() and movement_current_mode != MOVEMENTMODE.EVENT) or character_options.passable)
		):
			motion = Vector2.ZERO
	
	result.final_motion = motion if not disable_motion else Vector2.ZERO

	return result


func _disable_collision_shape(value: bool) -> void:
	var node = get_node_or_null("%CollisionShape")
	if node and node is CollisionShape2D:
		node.set_deferred("disabled", value)


func set_vertical_look(motion: Vector2) -> void:
	# Preferred vertical direction when moving diagonally
	if motion.y < 0:
		last_direction = DIRECTIONS.UP
	elif motion.y > 0:
		last_direction = DIRECTIONS.DOWN
	elif motion.x < 0:
		last_direction = DIRECTIONS.LEFT
	elif motion.x > 0:
		last_direction = DIRECTIONS.RIGHT


func set_horizontal_look(motion: Vector2) -> void:
	# Preferred horizontal direction when moving diagonally
	if motion.x < 0:
		last_direction = DIRECTIONS.LEFT
	elif motion.x > 0:
		last_direction = DIRECTIONS.RIGHT
	elif motion.y < 0:
		last_direction = DIRECTIONS.UP
	elif motion.y > 0:
		last_direction = DIRECTIONS.DOWN


func set_current_look(motion: Vector2) -> void:
	# Preferred current direction used when moving diagonally
	var dir_pressed_count = 0
	if motion.x < 0: dir_pressed_count += 1
	if motion.x > 0: dir_pressed_count += 1
	if motion.y < 0: dir_pressed_count += 1
	if motion.y > 0: dir_pressed_count += 1
	if dir_pressed_count == 1:
		set_vertical_look(motion)


func update_process_route() -> void:
	if is_moving or busy or is_jumping:
		return
		
	var result = await process_route_command()

	if result.action:
		match result.action:
			"move":
				var backup_direction = current_direction
				if is_on_vehicle and current_vehicle:
					await vehicle_movement(result.value, result.route, result.keep_direction)
				else:
					await move_event(result.value, result.route, result.keep_direction)
				if result.keep_direction:
					current_direction = backup_direction
					run_animation()
					
				GameManager.game_state.stats.steps += 1
			"jump":
				if is_on_vehicle and current_vehicle:
					await vehicle_jump_to(result.value, result.route, result.start_fx, result.end_fx)
				else:
					await jump_to(result.value, result.route, result.start_fx, result.end_fx)
				var steps = max(abs(result.value.x), abs(result.value.y))
				GameManager.game_state.stats.steps += steps
				
	route_command_index += 1
	if route_commands:
		if route_command_index >= route_commands.list.size():
			if route_commands.repeat:
				route_command_index = 0
			else:
				var wrapped_position = GameManager.current_map.get_wrapped_position(position)
				if wrapped_position != position:
					if is_in_group("player"):
						var camera = GameManager.get_camera()
						if camera:
							camera.global_position += (wrapped_position - position)
					position = wrapped_position
				route_commands.finished.emit()
				route_commands = null
				if is_on_vehicle and current_vehicle:
					current_vehicle.reset_force_movement()
		elif is_on_vehicle and current_vehicle:
			if not _is_movement_route_command(route_commands.list[route_command_index]):
				current_vehicle.reset_force_movement()
	elif is_on_vehicle and current_vehicle:
		current_vehicle.reset_force_movement()


func _get_next_move_toward_target(target: Vector2i, target_screen_position: Vector2) -> Vector2i:
	var map = GameManager.current_map
	
	if map:
		var current = get_current_tile()
		var next = map.pathfinder.get_next_tile(self, current, target)
		if next != null:
			return next - current
	
	return Vector2i.ZERO


func _get_next_move_toward_player() -> Vector2i:
	var goal = GameManager.current_player.get_current_tile() if not GameManager.current_player.is_on_vehicle else GameManager.current_player.current_vehicle.get_current_tile()
	
	var target_screen_position: Vector2 = GameManager.current_player.get_global_transform_with_canvas().origin
	
	return _get_next_move_toward_target(goal, target_screen_position)


# Need override
func _get_next_move_toward_event() -> Vector2i:
	var goal = Vector2i.ZERO
	var target_screen_position: Vector2 = Vector2.ZERO
	var page = get("current_event_page")
	if page and GameManager.current_map:
		var event = GameManager.current_map.get_in_game_event_by_pos(page.movement_to_target - 1)
		if event and event.has_method("get_current_tile"):
			goal = event.get_current_tile()
			target_screen_position = event.get_global_transform_with_canvas().origin
	else:
		return goal
	
	return _get_next_move_toward_target(goal, target_screen_position)


func _get_next_move_away_from_player() -> Vector2i:
	var directions = [
		Vector2i(0, -1), Vector2i(1, 0),
		Vector2i(0, 1), Vector2i(-1, 0),
		Vector2i(1, -1), Vector2i(1, 1),
		Vector2i(-1, -1), Vector2i(-1, 1),
	]
	
	var my_tile: Vector2i = get_current_tile()
	var player_tile = GameManager.current_player.get_current_tile() if not GameManager.current_player.is_on_vehicle else GameManager.current_player.current_vehicle.get_current_tile()

	var furthest_tile := my_tile
	var max_distance := my_tile.distance_squared_to(player_tile)
	
	if max_distance >= MAX_FLEE_DISTANCE_SQUARED:
		return Vector2i(0, 0)

	for dir in directions:
		var neighbor = my_tile + dir
		if GameManager.current_map.is_passable(neighbor, GameManager.current_map.pathfinder.vector2_to_direction(dir), self):
			var dist = neighbor.distance_squared_to(player_tile)
			if dist > max_distance:
				max_distance = dist
				furthest_tile = neighbor
	
	var motion = furthest_tile - my_tile
	if motion:
		if motion.x == 0:
			current_direction = DIRECTIONS.UP if motion.y < 0 else DIRECTIONS.DOWN
		elif motion.y == 0:
			current_direction = DIRECTIONS.LEFT if motion.x < 0 else DIRECTIONS.RIGHT
		last_direction = current_direction

	return motion


func _is_movement_route_command(command: RPGMovementCommand) -> bool:
	return command.code in [1,4,7,10,13,16,19,22,25,28,31,34,37,40]


func _rotate_left(direction: int) -> int:
	match direction:
		DIRECTIONS.UP: return DIRECTIONS.LEFT
		DIRECTIONS.LEFT: return DIRECTIONS.DOWN
		DIRECTIONS.DOWN: return DIRECTIONS.RIGHT
		DIRECTIONS.RIGHT: return DIRECTIONS.UP
	return direction

func _rotate_right(direction: int) -> int:
	match direction:
		DIRECTIONS.UP: return DIRECTIONS.RIGHT
		DIRECTIONS.RIGHT: return DIRECTIONS.DOWN
		DIRECTIONS.DOWN: return DIRECTIONS.LEFT
		DIRECTIONS.LEFT: return DIRECTIONS.UP
	return direction


func process_route_command() -> Dictionary:
	var result: Dictionary = {"action": null, "value": Vector2i(), "target": self, "keep_direction": false}
	var command: RPGMovementCommand
	var backup_direction = current_direction
	if route_commands:
		result.route = route_commands
		if route_command_index < route_commands.list.size():
			command = route_commands.list[route_command_index]
		else:
			return result
	else:
		return result
	
	if is_in_group("player") and is_on_vehicle and current_vehicle:
		result.target = current_vehicle

	if command:
		var params: Array = command.parameters
		match command.code:
			# Column 1
			1: # Move Down
				result.action = "move"
				result.value = Vector2i(0, 1)
			4: # Move Left
				result.action = "move"
				result.value = Vector2i(-1, 0)
			7: # Move Right
				result.action = "move"
				result.value = Vector2i(1, 0)
			10: # Move Up
				result.action = "move"
				result.value = Vector2i(0, -1)
			13: # Move Bottom Left
				result.action = "move"
				result.value = Vector2i(-1, 1)
			16: # Move Bottom Right
				result.action = "move"
				result.value = Vector2i(1, 1)
			19: # Move Top Left
				result.action = "move"
				result.value = Vector2i(-1, -1)
			22: # Move Top Right
				result.action = "move"
				result.value = Vector2i(1, -1)
			25: # Random Movement
				result.action = "move"
				result.value = Vector2i(randi_range(0, 2) - 1, randi_range(0, 2) - 1)
			28, 31: # Move To/Away From The Player
				if not is_in_group("player"):
					var player = GameManager.current_player if not GameManager.current_player.is_on_vehicle else GameManager.current_player.current_vehicle
					if player and player != self:
						result.action = "move"
						# Move To Player = Code 28, Move Away From Player = Code 31
						if command.code == 28:
							result.value = _get_next_move_toward_player()
						else:
							result.value = _get_next_move_away_from_player()
			34: # Step Forward
				result.action = "move"
				match result.target.current_direction:
					DIRECTIONS.LEFT: result.value = Vector2i(-1, 0)
					DIRECTIONS.DOWN: result.value = Vector2i(0, 1)
					DIRECTIONS.RIGHT: result.value = Vector2i(1, 0)
					DIRECTIONS.UP: result.value = Vector2i(0, -1)
				result.keep_direction = true
			37: # Take A Step Back
				result.action = "move"
				match result.target.current_direction:
					DIRECTIONS.LEFT: result.value = Vector2i(1, 0)
					DIRECTIONS.DOWN: result.value = Vector2i(0, -1)
					DIRECTIONS.RIGHT: result.value = Vector2i(-1, 0)
					DIRECTIONS.UP: result.value = Vector2i(0, 1)
				result.keep_direction = true
			40: # Jump
				var jump_amount: Vector2i = command.parameters[0]
				result.action = "jump"
				result.value = jump_amount
				result.start_fx = command.parameters[1]
				result.end_fx = command.parameters[2]
			43: # Wait
				var wait_time: float = command.parameters[0]
				result.target.busy = true
				busy = true
				var timer = get_tree().create_timer(wait_time)
				timer.timeout.connect(
					func():
						result.target.busy = false
						busy = false
				)
			46: # Change Z-Index
				var z: int = command.parameters[0]
				result.target.z_index = z
				character_options.z_index = z
			# Column 2
			2: # Look Down
				if not character_options.fixed_direction: result.target.current_direction = DIRECTIONS.DOWN
			5: # Look Left
				if not character_options.fixed_direction: result.target.current_direction = DIRECTIONS.LEFT
			8: # Look Right
				if not character_options.fixed_direction: result.target.current_direction = DIRECTIONS.RIGHT
			11: # Look Up
				if not character_options.fixed_direction: result.target.current_direction = DIRECTIONS.UP
			14: # Turn 90º Left
				if not character_options.fixed_direction:
					result.target.current_direction = _rotate_left(result.target.current_direction)
			17: # Turn 90º Right
				if not character_options.fixed_direction:
					result.target.current_direction = _rotate_right(result.target.current_direction)
			20: # Turn 180º
				if not character_options.fixed_direction:
					match result.target.current_direction:
						DIRECTIONS.LEFT: result.target.current_direction = DIRECTIONS.RIGHT
						DIRECTIONS.DOWN: result.target.current_direction = DIRECTIONS.UP
						DIRECTIONS.RIGHT: result.target.current_direction = DIRECTIONS.LEFT
						DIRECTIONS.UP: result.target.current_direction = DIRECTIONS.DOWN
			23: # Turn 90º Random
				if not character_options.fixed_direction:
					var turn_left = randi() % 2 == 0
		
					if turn_left:
						result.target.current_direction = _rotate_left(result.target.current_direction)
					else:
						result.target.current_direction = _rotate_right(result.target.current_direction)
			26: # Look Random
				if not character_options.fixed_direction:
					var random_dir = randi() % 4
					match random_dir:
						0: result.target.current_direction = DIRECTIONS.LEFT
						1: result.target.current_direction = DIRECTIONS.DOWN
						2: result.target.current_direction = DIRECTIONS.RIGHT
						3: result.target.current_direction = DIRECTIONS.UP
			29, 32: # Look Player / Look Opposite Player
				if not character_options.fixed_direction and not is_in_group("player"):
					var player = GameManager.current_player if not GameManager.current_player.is_on_vehicle else GameManager.current_player.current_vehicle
					if player:
						var direction
						
						if command.code == 29:  # Look Player
							direction = (player.global_position - global_position).normalized()
						else:  # Look Opposite Player (32)
							direction = (global_position - player.global_position).normalized()
						
						if abs(direction.x) > abs(direction.y):
							current_direction = DIRECTIONS.RIGHT if direction.x > 0 else DIRECTIONS.LEFT
						else:
							current_direction = DIRECTIONS.DOWN if direction.y > 0 else DIRECTIONS.UP
			35, 38: # Switch ON/OFF
				var game_state = GameManager.game_state
				if game_state:
					var switch_id: int = command.parameters[0]
					if game_state.game_switches.size() > switch_id and switch_id > 0:
						var is_enabled = (command.code == 35) 
						if game_state.game_switches[switch_id] != is_enabled:
							game_state.game_switches[switch_id] = is_enabled
							GameManager.current_map.map_need_refresh = true
			41: # Change Speed
				var new_speed: int = command.parameters[0]
				if result.target == self:
					movement_speed = new_speed
				else:
					result.target.vehicle_speed = new_speed
				character_options.movement_speed = new_speed
			44: # Change Frequency
				if result.target == self and not is_in_group("player"):
					var new_movement_frequency: float = command.parameters[0]
					event_movement_frequency = new_movement_frequency
					character_options.movenet_frequency = new_movement_frequency
			# Column 3
			3: # Walking Animation ON
				character_options.walking_animation = true
			6: # Walking Animation OFF
				character_options.walking_animation = false
			9: # Idle Animation ON
				character_options.idle_animation = true
			12: # Idle Animation OFF
				character_options.idle_animation = false
			15: # Fix Direction ON
				character_options.fixed_direction = true
			18: # Fix Direction OFF
				character_options.fixed_direction = false
			21: # Walk Trought ON
				character_options.passable = true
			24: # Walk Trought
				character_options.passable = false
			27: # Invisible ON
				result.target.visible = false
				character_options.visible = false
			30: # Invisible OFF
				result.target.visible = true
				character_options.visible = true
			33: # Change Graphic
				result.target.propagate_call("change_actor_graphics", [command.parameters[0]])
				character_options.current_graphics = command.parameters[0]
			36: # Change Opacity
				result.target.modulate.a = command.parameters[0]
				character_options.current_opacity = command.parameters[0]
			39: # Change Blend Mode
				result.target.propagate_call("change_blend_mode", [command.parameters[0]])
				character_options.blend_mode = command.parameters[0]
			42: # Play SE
				var parameters = command.parameters
				var path = parameters[0]
				var volume = parameters[1]
				var pitch1 = parameters[2]
				var pitch2 = parameters[3]
				var pitch = randf_range(pitch1, pitch2)
				GameManager.play_se(path, volume, pitch)
			45: # Script
				GameInterpreter.code_eval.execute(command.parameters[0])
	
	if backup_direction != result.target.current_direction:
		result.target.last_direction = result.target.current_direction
		if result.target != self:
			current_direction = result.target.current_direction
			last_direction = result.target.current_direction
			run_animation()
	
	_last_route_movement = result.value
	
	return result


func update_virtual_tile(motion: Vector2 = Vector2.ZERO) -> void:
	var map = GameManager.current_map
	if not map:
		return
	
	# Si hay movimiento, actualizar basándose en el motion
	if motion != Vector2.ZERO:
		var motion_in_tiles = Vector2(
			(motion.x / current_map_tile_size.x),
			(motion.y / current_map_tile_size.y)
		)
		current_virtual_tile += motion_in_tiles
	else:
		# Inicializar o recalcular desde la posición actual
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
		
	return Vector2i(0, 0) # Valor por defecto si no hay mapa


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
		
	return Vector2i(0, 0) # Valor por defecto si no hay mapa
	


func adjust_bounds() -> void:
	pass


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


#region movement
func run_animation() -> void:
	pass


func _on_grid_movement_finished(target_position: Vector2) -> void:
	# Ensure exact final position
	var wrapped_position = GameManager.current_map.get_wrapped_position(target_position)
	if wrapped_position != target_position:
		var camera = GameManager.get_camera()
		if camera:
			if camera.targets.size() > 1:
				camera.instantaneous_positioning()
			else:
				camera.global_position += (wrapped_position - target_position)
		position = wrapped_position
	else:
		position = target_position
	
	# update steps
	GameManager.game_state.stats.steps += 1
	
	is_moving = false
	movement_vector = Vector2.ZERO
	
	end_movement.emit()


func _reset(force_reset: bool = false) -> void:
	pass


func _animation_to_idle() -> void:
	if not is_moving:
		current_animation = "idle"
		#current_frame = 0


func _process_event_contact(contacting_entities: Array, stop_movement_on_activate: bool) -> bool:
	var page = get("current_event_page")
	if not page:
		return false

	var events_to_start: Array = []
	var self_id = page.get("id") if page else -1
	var self_launcher = page.launcher
	var primary_target = contacting_entities[0] if not contacting_entities.is_empty() else null
	var self_activated_this_check = false

	# Single loop for bidirectional logic
	for entity in contacting_entities:
		if entity in _ignore_events_contact:
			continue
		
		if "current_event_page" in entity and self in entity._ignore_events_contact:
			continue

		var activate_self = false
		var activate_other = false

		# 1. Check if 'entity' activates 'self'
		if not self_activated_this_check:
			if self_launcher == RPGEventPage.LAUNCHER_MODE.PLAYER_COLLISION and entity.is_in_group("player"):
				activate_self = true
			elif self_launcher == RPGEventPage.LAUNCHER_MODE.ANY_CONTACT:
				activate_self = true
			elif self_launcher == RPGEventPage.LAUNCHER_MODE.EVENT_COLLISION and not entity.is_in_group("player"):
				if "current_event_page" in entity and entity.current_event_page:
					var other_id = entity.current_event_page.get("id")
					var event_trigger_list = page.get("event_trigger_list")
					if other_id in event_trigger_list:
						activate_self = true
		
		# 2. Check if 'self' activates 'entity'
		if not entity.is_in_group("player"):
			if "current_event_page" in entity and entity.current_event_page:
				var other_page = entity.current_event_page
				var other_launcher = other_page.launcher
				
				if other_launcher == RPGEventPage.LAUNCHER_MODE.ANY_CONTACT or \
				   other_launcher == RPGEventPage.LAUNCHER_MODE.PLAYER_COLLISION:
					activate_other = true
				elif other_launcher == RPGEventPage.LAUNCHER_MODE.EVENT_COLLISION:
					var other_trigger_list = other_page.get("event_trigger_list")
					if self_id in other_trigger_list:
						activate_other = true

		# 3. Process activations and ignores
		if activate_self or activate_other:
			_ignore_events_contact.append(entity)
			entity._ignore_events_contact.append(self)

			if activate_self:
				if not self in events_to_start:
					events_to_start.append(self)
				primary_target = entity
				self_activated_this_check = true # Avoid 'self' being activated by multiple events

			if activate_other:
				if not entity in events_to_start:
					events_to_start.append(entity)

	# start events
	if not events_to_start.is_empty():
		var objs: Array[Dictionary] = []
		for ev in events_to_start:
			if ev.get("busy"):
				continue
				
			ev.activated_this_frame = true
			if stop_movement_on_activate:
				ev.is_moving = false
			
			ev._reset(true)
			objs.append({"obj": ev, "commands": ev.current_event_page.list, "id": str(ev.get_rid())})
			
			var target_to_look_at = self if ev != self else primary_target
			if target_to_look_at:
				if not ev.current_event_page.options.fixed_direction and "current_direction" in ev:
					ev.look_at_event(target_to_look_at)

		if not objs.is_empty():
			if stop_movement_on_activate and not self in events_to_start:
				_reset(true) 
				is_moving = false
				call_deferred("_animation_to_idle")
				run_animation()
				
			GameInterpreter.auto_start_automatic_events(objs)
			return true
			
	return false


func _check_contact(tile: Vector2i, check_passable: bool = false) -> bool:
	var im_player = is_in_group("player")
	
	if GameManager.current_map:
		if not im_player:
			if activated_this_frame:
				return false
				
			var valid_contacts: Array = []
			var all_entities_on_tile: Array = GameManager.current_map.get_in_game_events_in(tile)
			
			if GameManager.current_player and GameManager.current_player.get_current_tile() == tile:
				all_entities_on_tile.append(GameManager.current_player)

			for entity in all_entities_on_tile:
				if entity == self:
					continue
				
				var entity_passable = entity.character_options.passable
				if (check_passable and entity_passable) or (not check_passable and not entity_passable) and not entity in _ignore_events_contact:
					valid_contacts.append(entity)

			if not valid_contacts.is_empty():
				# Stop movement only if we were not checking for passable events (i.e., solid bump)
				var stop_movement = (not check_passable)
				return _process_event_contact(valid_contacts, stop_movement)

		else:
			# check if any event in the current tile can be initialed
			var events_to_start: Array = []
			var evs: Array = GameManager.current_map.get_in_game_events_in(tile)
			
			for ev in evs:
				if not ev in _ignore_events_contact:
					if "current_event_page" in ev and ev.current_event_page:
						var other_page = ev.current_event_page
						if other_page.launcher == RPGEventPage.LAUNCHER_MODE.ANY_CONTACT or \
						   other_page.launcher == RPGEventPage.LAUNCHER_MODE.PLAYER_COLLISION:
							
							var ev_passable = ev.character_options.passable
							var passability_ok = (check_passable and ev_passable) or (not check_passable and not ev_passable)

							if passability_ok:
								events_to_start.append(ev)
								_ignore_events_contact.append(ev)
								ev._ignore_events_contact.append(GameManager.current_player)
								ev.activated_this_frame = true
			
			if not events_to_start.is_empty():
				var objs: Array[Dictionary] = []
				for ev in events_to_start:
					if not ev.get("busy"):
						ev.activated_this_frame = true
						ev.is_moving = false
						ev._reset(true)
						objs.append({"obj": ev, "commands": ev.current_event_page.list, "id": str(ev.get_rid())})
						if not ev.current_event_page.options.fixed_direction and "current_direction" in ev:
							ev.look_at_event(self)
				
				if not objs.is_empty():
					_reset(true)
					is_moving = false
					call_deferred("_animation_to_idle")
					run_animation()
					GameInterpreter.auto_start_automatic_events(objs)
					return true
			
	return false


func _check_nearby_events_for_activation() -> void:
	if activated_this_frame:
		return
		
	var valid_contacts: Array = []
	var self_pos = position
	
	var nearby_entities: Array = GameManager.current_map.get_events_near_position(self_pos)
	
	if GameManager.current_player:
		nearby_entities.append(GameManager.current_player)
	
	var is_horizontal: bool
	var direction_multiplier: int
	
	match current_direction:
		DIRECTIONS.LEFT:
			is_horizontal = true
			direction_multiplier = -1
		DIRECTIONS.RIGHT:
			is_horizontal = true
			direction_multiplier = 1
		DIRECTIONS.UP:
			is_horizontal = false
			direction_multiplier = -1
		DIRECTIONS.DOWN:
			is_horizontal = false
			direction_multiplier = 1
		_:
			return

	const AXIS_TOLERANCE = 4.0

	for entity in nearby_entities:
		if entity == self:
			continue
			
		var entity_pos = entity.position
		if self_pos.distance_squared_to(entity_pos) <= _squared_tile_size:
			var is_on_axis = false
			var is_in_front = false
			
			if is_horizontal:
				is_on_axis = abs(entity_pos.y - self_pos.y) < AXIS_TOLERANCE
				is_in_front = (entity_pos.x - self_pos.x) * direction_multiplier >= 0
			else:
				is_on_axis = abs(entity_pos.x - self_pos.x) < AXIS_TOLERANCE
				is_in_front = (entity_pos.y - self_pos.y) * direction_multiplier >= 0
			
			if is_on_axis and is_in_front:
				valid_contacts.append(entity)

	if not valid_contacts.is_empty():
		# 'false' = Do not stop movement for this type of activation ("touch")
		_process_event_contact(valid_contacts, false)


func look_at_event(event: Variant) -> void:
	if event == self: return
	
	var direction = (event.global_position - global_position).normalized()
	if abs(direction.x) > abs(direction.y):
		current_direction = DIRECTIONS.RIGHT if direction.x > 0 else DIRECTIONS.LEFT
	else:
		current_direction = DIRECTIONS.DOWN if direction.y > 0 else DIRECTIONS.UP
	
	last_direction = current_direction


# Check contact before move
# Check contact before move
func _check_contact_before_move(tile: Vector2i, is_after_move: bool = false) -> bool:
	return true
	var my = self
	var my_is_solid = _is_solid(my)
	var my_is_moving = my.is_moving if "is_moving" in my else false
	var my_is_player = my.is_in_group("player")
	
	# Recolectar todas las entities en el tile destino
	var all_entities_on_tile: Array = GameManager.current_map.get_in_game_events_in(tile, false)
	
	# Agregar player si es necesario
	if not my_is_player and GameManager.current_player:
		if GameManager.current_player.get_current_tile() == tile:
			all_entities_on_tile.append(GameManager.current_player)
	
	# Limpiar duplicados
	all_entities_on_tile = _remove_duplicates(all_entities_on_tile)
	
	var i_can_move: bool = true
	var valid_contacts: Array = []
	
	# === PROCESAR CADA ENTITY ===
	for entity in all_entities_on_tile:
		if entity == my:
			continue
		
		var entity_is_solid = _is_solid(entity)
		var entity_is_moving = entity.is_moving if "is_moving" in entity else false
		var entity_is_player = entity.is_in_group("player")
		
		# Determinar qué hacer basado en los estados
		var can_move_result: bool
		var contacts_result: Array
		
		if my_is_player:
			# PLAYER vs ENTITY
			var result = _handle_player_contact(my, entity, entity_is_player)
			can_move_result = result["can_move"]
			contacts_result = result["contacts"]
		elif entity_is_player:
			# EVENT vs PLAYER
			var result = _handle_event_vs_player(my, entity, my_is_solid, my_is_moving)
			can_move_result = result["can_move"]
			contacts_result = result["contacts"]
		elif my_is_solid and entity_is_solid:
			# SOLID vs SOLID
			var result = _handle_solid_vs_solid(my, entity, my_is_moving, entity_is_moving)
			can_move_result = result["can_move"]
			contacts_result = result["contacts"]
		elif my_is_solid and not entity_is_solid:
			# SOLID vs PASSABLE
			var result = _handle_solid_vs_passable(my, entity, my_is_moving, entity_is_moving)
			can_move_result = result["can_move"]
			contacts_result = result["contacts"]
		elif not my_is_solid and entity_is_solid:
			# PASSABLE vs SOLID
			var result = _handle_passable_vs_solid(my, entity, entity_is_moving)
			can_move_result = result["can_move"]
			contacts_result = result["contacts"]
		else:
			# PASSABLE vs PASSABLE
			var result = _handle_passable_vs_passable(my, entity)
			can_move_result = result["can_move"]
			contacts_result = result["contacts"]
		
		i_can_move = i_can_move and can_move_result
		valid_contacts.append_array(contacts_result)
	
	# === Deduplicar contactos ===
	valid_contacts = _remove_duplicates(valid_contacts)
	
	# === Activar eventos ===
	_trigger_events(valid_contacts)
	
	return i_can_move


# === HELPERS DE DETECCIÓN ===
func _is_solid(entity) -> bool:
	if entity.is_in_group("player") or entity is RPGVehicle:
		if entity.has_method("is_passable"):
			return entity.is_passable()
		return true
	else:
		if "character_options" in entity and entity.character_options:
			var passable = not entity.character_options.passable
			return passable
		return false


func _can_activate_event(my_entity, other_entity) -> bool:
	var my_page = my_entity.get("current_event_page") if not my_entity.is_in_group("player") else null
	var other_page = other_entity.get("current_event_page") if not other_entity.is_in_group("player") else null
	
	if not my_page and not other_page:
		return false
	
	# Si yo soy el que puede activarme
	if my_page:
		var my_launcher = my_page.launcher
		if my_launcher in [RPGEventPage.LAUNCHER_MODE.ANY_CONTACT, RPGEventPage.LAUNCHER_MODE.EVENT_COLLISION]:
			if my_launcher == RPGEventPage.LAUNCHER_MODE.ANY_CONTACT:
				return true
			elif other_page:
				var other_id = other_page.get("id")
				var my_trigger_list = my_page.get("event_trigger_list")
				if other_id in my_trigger_list:
					return true
	
	# Si el otro puede activarme
	if other_page:
		var other_launcher = other_page.launcher
		if other_launcher in [RPGEventPage.LAUNCHER_MODE.ANY_CONTACT, RPGEventPage.LAUNCHER_MODE.EVENT_COLLISION]:
			if other_launcher == RPGEventPage.LAUNCHER_MODE.ANY_CONTACT:
				return true
			elif my_page:
				var my_id = my_page.get("id")
				var other_trigger_list = other_page.get("event_trigger_list")
				if my_id in other_trigger_list:
					return true
	
	return false


# === CASOS DE CONTACTO ===
func _handle_player_contact(player, entity, entity_is_player: bool) -> Dictionary:
	if entity_is_player:
		return {"can_move": true, "contacts": []}
	
	var entity_page = entity.get("current_event_page")
	if not entity_page:
		return {"can_move": true, "contacts": []}
	
	var entity_launcher = entity_page.launcher
	if entity_launcher in [RPGEventPage.LAUNCHER_MODE.ANY_CONTACT, RPGEventPage.LAUNCHER_MODE.PLAYER_COLLISION]:
		if not entity in _ignore_events_contact:
			_add_mutual_ignore(entity, player)
			return {"can_move": true, "contacts": [entity]}
	
	return {"can_move": true, "contacts": []}


func _handle_event_vs_player(event, player, my_is_solid: bool, my_is_moving: bool) -> Dictionary:
	var my_page = event.get("current_event_page")
	if not my_page:
		return {"can_move": true, "contacts": []}
	
	var my_launcher = my_page.launcher
	if my_launcher in [RPGEventPage.LAUNCHER_MODE.ANY_CONTACT, RPGEventPage.LAUNCHER_MODE.PLAYER_COLLISION]:
		if not event in _ignore_events_contact:
			_add_mutual_ignore(event, player)
			return {"can_move": true, "contacts": [event]}
	
	return {"can_move": true, "contacts": []}


func _handle_solid_vs_solid(my_event, other_event, my_is_moving: bool, other_is_moving: bool) -> Dictionary:
	# Ambos quietos: bloqueo
	if not my_is_moving and not other_is_moving:
		var can_activate = _can_activate_event(my_event, other_event)
		var contacts = []
		if can_activate and not other_event in _ignore_events_contact:
			_add_mutual_ignore(other_event, my_event)
			contacts.append(other_event)
		return {"can_move": false, "contacts": contacts}
	
	# Ambos moviéndose: no bloqueo, sin activación (se cruzan)
	if my_is_moving and other_is_moving:
		return {"can_move": true, "contacts": []}
	
	# Uno moviéndose, otro quieto: bloqueo y posible activación
	var can_activate = _can_activate_event(my_event, other_event)
	var contacts = []
	if can_activate and not other_event in _ignore_events_contact:
		_add_mutual_ignore(other_event, my_event)
		contacts.append(other_event)
	return {"can_move": false, "contacts": contacts}


func _handle_solid_vs_passable(my_event, other_event, my_is_moving: bool, other_is_moving: bool) -> Dictionary:
	# El otro se está moviendo: no bloqueo
	if other_is_moving:
		return {"can_move": true, "contacts": []}
	
	# El otro está quieto: sin bloqueo pero check activación
	var can_activate = _can_activate_event(my_event, other_event)
	var contacts = []
	if can_activate and not other_event in _ignore_events_contact:
		_add_mutual_ignore(other_event, my_event)
		contacts.append(other_event)
		contacts.append(my_event)
	return {"can_move": true, "contacts": contacts}


func _handle_passable_vs_solid(my_event, other_event, other_is_moving: bool) -> Dictionary:
	# El otro se está moviendo: bloqueo y activación
	if other_is_moving:
		var can_activate = _can_activate_event(my_event, other_event)
		var contacts = []
		if can_activate and not other_event in _ignore_events_contact:
			_add_mutual_ignore(other_event, my_event)
			contacts.append(other_event)
			contacts.append(my_event)
		return {"can_move": not can_activate, "contacts": contacts}
	
	# El otro está quieto: sin bloqueo pero check activación
	var can_activate = _can_activate_event(my_event, other_event)
	var contacts = []
	if can_activate and not other_event in _ignore_events_contact:
		_add_mutual_ignore(other_event, my_event)
		contacts.append(other_event)
		contacts.append(my_event)
	return {"can_move": true, "contacts": contacts}


func _handle_passable_vs_passable(my_event, other_event) -> Dictionary:
	var can_activate = _can_activate_event(my_event, other_event)
	var contacts = []
	if can_activate and not other_event in _ignore_events_contact:
		_add_mutual_ignore(other_event, my_event)
		contacts.append(other_event)
		contacts.append(my_event)
	return {"can_move": true, "contacts": contacts}


# === HELPERS ===
func _remove_duplicates(array: Array) -> Array:
	var result: Array = []
	for item in array:
		if not item in result:
			result.append(item)
	return result


func _trigger_events(valid_contacts: Array) -> void:
	if valid_contacts.is_empty():
		return
	
	var valid_objs: Array[Dictionary] = []
	var used: Array = []
	
	for ev in valid_contacts:
		if not ev in used:
			used.append(ev)
			if ev.get("current_event_page"):
				valid_objs.append({
					"obj": ev,
					"commands": ev.current_event_page.list,
					"id": str(ev.get_rid())
				})
	
	if valid_objs:
		GameInterpreter.auto_start_automatic_events(valid_objs)


# Check contact after move
func _check_contact_after_move() -> void:
	_check_contact_before_move(get_current_tile(), true)


func _add_mutual_ignore(entity_a: Node, entity_b: Node) -> void:
	# Validar que los nodos existen y son distintos
	if not is_instance_valid(entity_a) or not is_instance_valid(entity_b):
		return
	if entity_a == entity_b:
		return
	
	# Agregar entity_b al ignore de entity_a
	if not entity_b in entity_a._ignore_events_contact:
		entity_a._ignore_events_contact.append(entity_b)
	
	# Agregar entity_a al ignore de entity_b
	if not entity_a in entity_b._ignore_events_contact:
		entity_b._ignore_events_contact.append(entity_a)


func _add_to_ignore(entity: Node) -> void:
	if not entity == self and not entity in _ignore_events_contact:
		_ignore_events_contact.append(entity)


func _has_ignore_entity(entity: Node) -> bool:
	return entity in _ignore_events_contact


func get_event_at_adjacent_tile() -> Node:
	var node_found: Node = null
	var node: RPGMap = GameManager.current_map
	if node:
		var origin = global_position
		
		match current_direction:
			DIRECTIONS.LEFT: origin.x -= node.tile_size.x
			DIRECTIONS.RIGHT: origin.x += node.tile_size.x
			DIRECTIONS.UP: origin.y -= node.tile_size.y
			DIRECTIONS.DOWN: origin.y += node.tile_size.y
		
		var used_rect = node.get_used_rect(false)
		
		if node.infinite_horizontal_scroll:
			var map_width = used_rect.size.x
			var relative_x = origin.x - used_rect.position.x
			var wrapped_x = fmod(relative_x, map_width)
			if wrapped_x < 0:
				wrapped_x += map_width
			origin.x = wrapped_x + used_rect.position.x
		
		if node.infinite_vertical_scroll:
			var map_height = used_rect.end.y - used_rect.position.y
			var relative_y = origin.y - used_rect.position.y
			var wrapped_y = fmod(relative_y, map_height)
			if wrapped_y < 0:
				wrapped_y += map_height
			origin.y = wrapped_y + used_rect.position.y
		
		var target_pos = node.local_to_map(origin)
		var event: Variant = node.get_in_game_event_in(target_pos)
		
		if event is LPCEvent or event is EmptyLPCEvent or event is GenericLPCEvent or (event and event.get_class() == "RPGExtractionScene"):
			node_found = event
		else:
			var vehicle: RPGVehicle = node.get_in_game_vehicle_in(target_pos)
			
			if vehicle:
				node_found = vehicle
	
	return node_found


func start_movement(motion_data: Dictionary) -> void:
	if movement_tween:
		movement_tween.kill()

	movement_tween = create_tween()
	movement_tween.tween_interval(0.0)
	
	is_moving = true
	#previous_tile = get_current_tile()
	var final_motion = motion_data.final_motion
	var current_motion = motion_data.current_motion
	var map = GameManager.current_map
	
	if not final_motion:
		is_moving = false
		return
		
	target_position = position + final_motion
	var start_position = position
	var max_movement_time = max(grid_move_duration.x, grid_move_duration.y)
	var distance = final_motion.length()
	var base_distance = current_map_tile_size.x
	var time = max_movement_time * (distance / base_distance)

	movement_tween.tween_method(_update_position.bind([position]), position, target_position, time)

	movement_tween.tween_callback(func(): end_movement.emit())
	
	_animate_contact_area.call_deferred(motion_data.current_motion)


func _animate_contact_area(final_motion: Vector2) -> void:
	if (contact_area_tween and contact_area_tween.is_running()):
		return
		
	var node = get_node_or_null("%ContactArea")
	if GameManager.current_map and node and node.get_child_count() == 1:
		var collision_shape = node.get_child(0)
		if collision_shape is CollisionShape2D and collision_shape.shape is RectangleShape2D:
			var max_movement_time = max(grid_move_duration.x, grid_move_duration.y)
			var distance = final_motion.length()
			var base_distance = current_map_tile_size.x
			var time = max_movement_time * (distance / base_distance)
			if not collision_shape.has_meta("_original_position_and_size"):
				collision_shape.set_meta("_original_position_and_size",
					{"position": collision_shape.position, "size": collision_shape.shape.size}
				)
			var tile_size = Vector2(GameManager.current_map.tile_size)
				
			contact_area_tween = create_tween()
			contact_area_tween.set_parallel(true)
			contact_area_tween.tween_method(
				_set_contact_area_size.bind(collision_shape, final_motion),
				tile_size.x * 0.8125,
				tile_size.x * 1.3,
				time * 0.1
			).set_delay(time * 0.1)
			contact_area_tween.tween_method(
				_set_contact_area_size.bind(collision_shape, final_motion),
				tile_size.x * 1.3,
				tile_size.x * 0.8125,
				time * 0.1
			).set_delay(time * 0.3)


func _set_contact_area_size(width: float, collision_shape: CollisionShape2D, motion: Vector2) -> void:
	var original_data = collision_shape.get_meta("_original_position_and_size")
	var original_size = original_data.size
	var original_position = original_data.position
	
	var new_size = original_size
	var new_position = original_position
	
	if motion.x != 0:
		var diff = abs(original_size.x - width) / 2.0
		if motion.x > 0:
			diff *= -1
		new_size.x = width
		new_position.x = original_position.x - diff
	
	elif motion.y != 0:
		var diff = abs(original_size.y - width) / 2.0
		new_size.y = width
		if motion.y > 0:
			diff *= -1
		new_position.y = original_position.y - diff
	
	collision_shape.position = new_position
	collision_shape.shape.size = new_size


func _update_position(new_position: Vector2, old_position_cache: Array) -> void:
	position = new_position
	update_virtual_tile(new_position - old_position_cache[0])
	old_position_cache[0] = position


func vehicle_movement(motion: Vector2, route: RPGMovementRoute = null, keep_direction: bool = false) -> void:
	is_moving = true
	var vehicle_position = current_vehicle.global_position
	await current_vehicle.force_movement(motion, keep_direction)
	var new_vehicle_position = current_vehicle.global_position
	if vehicle_position == new_vehicle_position and !route.skippable:
		route_command_index -= 1
	is_moving = false
	end_movement.emit()


func move_event(new_pos: Vector2, route: RPGMovementRoute = null, keep_direction: bool = false) -> void:
	if is_moving or busy or is_jumping: return
	
	var has_route = route_commands and not route_commands.list.is_empty()
	if has_route and not route_commands.is_route_from_interpreter and GameInterpreter.is_busy():
		return
	
	var motion_data = get_motion(new_pos)
	var motion = motion_data.final_motion
	
	if motion:
		if not character_options.fixed_direction and not keep_direction:
			var diagonal_movement_direction_mode = RPGSYSTEM.database.system.options.get("movement_mode", 0)
			match diagonal_movement_direction_mode:
				0: set_vertical_look(motion)
				1: set_horizontal_look(motion)
				2: set_current_look(motion)
			current_direction = last_direction
		current_animation = "walk"
		run_animation()
	else:
		if route and !route.skippable:
			route_command_index -= 1
		call_deferred("_animation_to_idle")
		_animate_contact_area.call_deferred(motion_data.current_motion)
		return

	# Start Movement
	event_start_movement.emit()
	start_movement(motion_data)
	if movement_tween and movement_tween.is_valid():
		movement_tween.tween_callback(
			func():
				# End movement
				is_moving = false
				call_deferred("_animation_to_idle")
		)
		await movement_tween.finished
		
		position = GameManager.current_map.get_wrapped_position(position)


func jump_to(new_pos: Vector2, route: RPGMovementRoute = null, start_fx: Dictionary = {}, end_fx: Dictionary = {}) -> void:
	if is_moving or busy or is_jumping:
		return
	
	var possible_movement = get_possible_movements(new_pos)
	var motion = null if !possible_movement else new_pos * Vector2(current_map_tile_size)
	
	if motion:
		update_virtual_tile(motion)
		if not character_options.fixed_direction:
			match RPGSYSTEM.database.system.options.get("movement_mode", 0):
				0: set_vertical_look(motion)
				1: set_horizontal_look(motion)
				2: set_current_look(motion)
			current_direction = last_direction
		
		var start_pos = position
		var end_pos = position + motion
		var distance = motion.length()
		var jump_height = min(MAX_JUMP_HEIGHT, distance * 0.5)
		var jump_duration = clamp(distance * 0.1, 0.2, 0.35)
		
		if "get_shadow_data" in self:
			var shadow_data = call("get_shadow_data")
			if shadow_data is Dictionary and "sprite_shadow" in shadow_data and shadow_data.sprite_shadow is Node:
				var is_horizontal_jump = (motion.y == 0)
				shadow_data.sprite_shadow.set_meta("is_jumping", true)
				shadow_data.sprite_shadow.set_meta("jumping_shadow_global_position", global_position)
				shadow_data.sprite_shadow.set_meta("jumping_shadow_parent", self)
				shadow_data.sprite_shadow.set_meta("jumping_horizontal_mode", is_horizontal_jump)
				shadow_data.sprite_shadow.set_meta("jumping_start_position", start_pos)
				shadow_data.sprite_shadow.set_meta("jumping_target_position", end_pos)

		is_jumping = true
		
		current_animation = "start_jump"
		current_frame = 0
		force_animation_enabled = true
		
		if movement_tween:
			movement_tween.kill()
		
		movement_tween = create_tween()

		if start_fx:
			movement_tween.tween_callback(GameManager.play_se.bind(
				start_fx.get("path", ""), start_fx.get("volume", 0.0), start_fx.get("pitch", 1.0)
			))
		
		# Squash before jump
		movement_tween.tween_property(self, "scale", Vector2(0.94, 0.55), 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		movement_tween.tween_interval(0.01)
		
		movement_tween.tween_callback(
			func():
				var dust = JUMP_PARTICLES.instantiate()
				dust.position = position
				get_parent().add_child(dust)
		)
		
		movement_tween.tween_interval(0.001)
		movement_tween.set_parallel(true)
		
		movement_tween.tween_property(self, "scale", Vector2(1.02, 1.04), 0.06).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

		# Simulated parabola motion using custom tween (position + y arc)
		movement_tween.tween_method(
			func(t): position = start_pos.lerp(end_pos, t) - Vector2(0, sin(t * PI) * jump_height),
			0.0, 1.0, jump_duration
		).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		
		# Land sound
		if end_fx:
			movement_tween.tween_callback(GameManager.play_se.bind(
				end_fx.get("path", ""), end_fx.get("volume", 0.0), end_fx.get("pitch", 1.0)
			)).set_delay(jump_duration - 0.03)
		
		movement_tween.tween_callback(set.bind("current_frame", 0)).set_delay(jump_duration * 0.65)
		movement_tween.tween_callback(
			func():
				current_animation = "end_jump"
				run_animation()
		).set_delay(jump_duration * 0.65)
		
		movement_tween.set_parallel(false)
		movement_tween.tween_interval(0.01)
		
		movement_tween.tween_callback(
			func():
				var dust = JUMP_PARTICLES.instantiate()
				dust.position = position
				get_parent().add_child(dust)
		)

		# Compress and return to normal scale
		movement_tween.tween_property(self, "scale", Vector2(1.0, 0.92), 0.15).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CIRC)
		movement_tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.2).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)

		movement_tween.tween_callback(
			func():
				is_jumping = false
				force_animation_enabled = false
				if "get_shadow_data" in self:
					var shadow_data = call("get_shadow_data")
					if shadow_data is Dictionary and "sprite_shadow" in shadow_data and shadow_data.sprite_shadow is Node:
						shadow_data.sprite_shadow.set_meta("is_jumping", false)
		)

		await movement_tween.finished


func vehicle_jump_to(new_pos: Vector2, route: RPGMovementRoute = null, start_fx: Dictionary = {}, end_fx: Dictionary = {}) -> void:
	if is_moving or busy or is_jumping:
		return
	
	is_jumping = true
		
	await current_vehicle.jump_to(new_pos, route, start_fx, end_fx)
	
	is_jumping = false


func is_processin_moving() -> bool:
	return is_moving or (movement_tween and movement_tween.is_valid() and movement_tween.is_running())


func kill_movement() -> void:
	if movement_tween and movement_tween.is_valid():
		movement_tween.kill()


func _save_player_position_into_game_state() -> void:
	if GameManager.loading_game:
		return
	if GameManager.game_state:
		GameManager.game_state.current_map_position = get_current_tile()
		GameManager.game_state.current_direction = current_direction
	


func grid_movement() -> void:
	if is_moving or Vector2(movement_vector) == Vector2.ZERO or busy or is_jumping or GameInterpreter.is_busy() or GameManager.loading_game:
		return

	var motion_data = get_motion(movement_vector)
	var motion = motion_data.final_motion

	if !motion:
		_animate_contact_area.call_deferred(motion_data.current_motion)
		end_movement.emit()
		return

	# Start Movement
	start_movement(motion_data)
	if movement_tween:
		if movement_tween.finished.is_connected(_on_grid_movement_finished):
			movement_tween.finished.disconnect(_on_grid_movement_finished)
		movement_tween.finished.connect(_on_grid_movement_finished.bind(target_position))


func free_movement(delta: float) -> void:
	if !movement_vector or busy or is_jumping or GameManager.loading_game:
		return
	
	if abs(movement_vector.y) > 1 or abs(movement_vector.x) > 1:
		# Abnormal speed, should usually be between 0 and 1
		_reset(true)
		return

	var current_movement_vector = movement_vector
	var possible_movements = get_possible_movements(movement_vector)
	if possible_movements:
		movement_vector *= Vector2(possible_movements)
		movement_vector = movement_vector * (movement_speed if !is_running else running_speed)
		velocity = movement_vector
		move_and_slide()
		start_motion.emit(velocity * delta)
		velocity = Vector2.ZERO
	else:
		velocity = Vector2.ZERO
	
	# update steps
	if GameManager.current_map:
		update_virtual_tile(velocity * delta)
		
		cumulative_steps += (movement_vector * delta).length()
		var steps_to_add = int(cumulative_steps / GameManager.current_map.tile_size.x)
		if steps_to_add > 0:
			GameManager.game_state.stats.steps += steps_to_add
			cumulative_steps = int(cumulative_steps) % GameManager.current_map.tile_size.x
	
	end_movement.emit()


func get_tile_passability(target_tile: Vector2i, motion: Vector2) -> Vector2i:
	var result: Vector2i = Vector2i.ZERO
	var map = GameManager.current_map
	if map:
		if map.is_passable(target_tile, current_direction):
			if map.can_move_over_terrain(target_tile, can_move_on_terrains):
				result.x = 1 if motion.x != 0 else 0
				result.y = 1 if motion.y != 0 else 0
	
	return result


func _try_move_with_free_mode(current_tile: Vector2i, motion: Vector2) -> Vector2i:
	var result: Vector2i = Vector2i.ZERO
	
	var map = GameManager.current_map
	
	if map:
		var current_position = global_position
		var snapped = map.get_tile_position(current_tile)
		if (motion.x < 0 and current_position.x > snapped.x + 2) or (motion.x > 0 and current_position.x < snapped.x - 2):
			result.x = 1
		if (motion.y < 0 and current_position.y > snapped.y + 2) or (motion.y > 0 and current_position.y < snapped.y - 4):
			result.y = 1
	
	return result


func get_possible_movements(motion: Vector2) -> Vector2i:
	var result: Vector2i = Vector2i.ZERO

	# Redondear el motion hacia afuera
	motion.x = floor(motion.x) if motion.x < 0 else ceil(motion.x)
	motion.y = floor(motion.y) if motion.y < 0 else ceil(motion.y)

	if !motion or !can_move:
		return Vector2i.ZERO
		
	if (Input.is_key_pressed(KEY_CTRL) and OS.is_debug_build() and movement_current_mode != MOVEMENTMODE.EVENT) or character_options.passable:
		return Vector2i(
			1 if motion.x != 0 else 0,
			1 if motion.y != 0 else 0
		)

	var map = GameManager.current_map
	if not map:
		return result

	var current_tile = get_current_tile()

	var dx = int(motion.x)
	var dy = int(motion.y)

	var horizontal_tile = map.get_wrapped_tile(current_tile + Vector2i(dx, 0))
	var vertical_tile = map.get_wrapped_tile(current_tile + Vector2i(0, dy))
	var diagonal_tile = map.get_wrapped_tile(current_tile + Vector2i(dx, dy))

	var can_move_horizontally = dx != 0 and get_tile_passability(horizontal_tile, motion) != Vector2i.ZERO
	var can_move_vertically = dy != 0 and get_tile_passability(vertical_tile, motion) != Vector2i.ZERO
	var can_move_diagonally = dx != 0 and dy != 0 and get_tile_passability(diagonal_tile, motion) != Vector2i.ZERO

	if can_move_horizontally and can_move_vertically and can_move_diagonally:
		result = Vector2i(1, 1)
	elif can_move_horizontally:
		result.x = 1
	elif can_move_vertically:
		result.y = 1
	
	if result.x != 0 and not map.is_tile_passable_from_direction(get_current_tile(), current_direction, true):
		result.x = 0
	
	if result.y != 0 and not map.is_tile_passable_from_direction(get_current_tile(), current_direction, true):
		result.y = 0

	# Modo libre: intenta moverse aunque no esté alineado al grid
	if movement_current_mode == MOVEMENTMODE.FREE:
		if result == Vector2i.ZERO:
			result = _try_move_with_free_mode(current_tile, motion)
		elif result.x + result.y == 1:
			if result.x == 1:
				result.y = _try_move_with_free_mode(current_tile, Vector2(0, motion.y)).y
			else:
				result.x = _try_move_with_free_mode(current_tile, Vector2(motion.x, 0)).x

	return result
#endregion
