@tool
class_name RPGVehicle
extends CharacterBody2D

## Vehicle type (This information is used by the “conditional separation” command when the “vehicle being driven” option is selected).
@export_enum("Land Vehicle", "Sea Vehicle", "Air Veicle") var vehicle_type: int = 0

## Allows you to interact with map events while riding in this vehicle
@export var can_interact_from_the_vehicle: bool = false

## Initial direction
@export var current_direction: LPCCharacter.DIRECTIONS = LPCCharacter.DIRECTIONS.DOWN:
	set(value):
		current_direction = value
		last_direction = value
		start_direction_changed.emit()


## Change the offset of the vehicle so that they look good on the map with respect to the player's position.
@export var offset_view_from_bottom: int = -32
@export var offset_view_from_top: int = -100

## Vehicle Speed
@export var vehicle_speed: float = 200

## Specifies the container that will host the player
@export_node_path var player_container_node

## Specifies the position of the player inside the container.
@export var player_position: Vector2i

## Offset the size of this vehicle (by default they measure 1x1 tile). Use this to make the vehicle wider or longer.
@export var extra_dimensions: RPGDimension = RPGDimension.new()

@export var is_a_living_creature: bool = false

@export_category("Terrain Passability")
## Terrains over which this vehicle can move
## (Use a "*" at the beginning to include any terrain whose name contains the specified terrain name, or use a “^” at the beginning to exclude any terrain whose name contains the specified terrain name. or "all" to include any terrain.)
@export var can_move_on_terrains: PackedStringArray
## Terrains where this vehicle can disembark the player
## (Use a "*" at the beginning to include any terrain whose name contains the specified terrain name, or "all" to include any terrain.)
@export var can_disembark_on_terrains: PackedStringArray
## Indicates if the transport can fly (Flying transports ignore all collisions).
@export var flying_object: bool = false 

## Indicate whether or not this vehicle can be traversed.
@export var is_passable: bool = false : set = _set_passable


var player: LPCCharacter
var current_map: RPGMap
var current_animation = "IdleDown"
var is_moving: bool = false
var is_enabled: bool = false
var is_jumping: bool = false
var busy: bool = false
var grid_move_duration: Vector2
var movement_vector: Vector2
var target_position: Vector2
var teleport: Vector2
var initial_delay: float = 0.0
var last_direction: LPCCharacter.DIRECTIONS = LPCCharacter.DIRECTIONS.DOWN
var force_movement_enabled: bool = false
var force_jump_enabled: bool = false
var previous_tile: Vector2i

var movement_tween: Tween

var ctrl_pressed: bool = false

const MAX_JUMP_HEIGHT: int = 48
const JUMP_PARTICLES = preload("res://Scenes/ParticleScenes/jump_particles2.tscn")


signal starting()
signal ending()
signal start_movement()
#signal position_changed()
signal end_movement()
signal start_direction_changed()


func _ready() -> void:
	if not Engine.is_editor_hint():
		name = "Vehicle %s - %s" % [name, GameManager.current_map.generate_16_digit_id() if GameManager.current_map else randi_range(1000000, 9999999)]
	set_process(false)
	set_process_input(false)
	add_to_group("vehicles")
	last_direction = current_direction
	end_movement.connect(_on_end_movement)


func _set_passable(value: bool) -> void:
	is_passable = value
	var node = get_node_or_null("CollisionShape2D")
	if node:
		node.set_deferred("disabled", value)


func calculate_grid_move_duration():
	var sp = 0.0000000000001 + vehicle_speed
	grid_move_duration = Vector2(
		current_map.tile_size.x / sp,
		current_map.tile_size.y / sp
	)


func set_direction(direction: LPCCharacter.DIRECTIONS) -> void:
	current_direction = direction
	last_direction = direction


func get_direction_name() -> String:
	for key in LPCCharacter.DIRECTIONS.keys():
		if LPCCharacter.DIRECTIONS.get(key) == current_direction:
			return(key.capitalize())
		
	return ""


func add_player(passenger: LPCCharacter) -> void:
	if player and passenger == player: return
	
	var node = get_node_or_null(player_container_node)
	if node:
		player = passenger
		await _set_initial_player_position(player_position)
		current_map = passenger.get_parent()
		calculate_grid_move_duration()
		for child in node.get_children():
			node.remove_child(child)
		if passenger.is_inside_tree():
			passenger.reparent(node)
		else:
			node.add_child(passenger)
		player.position = player_position
		var t = create_tween()
		passenger.modulate.a = 0.8
		t.tween_property(passenger, "modulate:a", 1.0, 0.15)
		board_passenger(passenger)


func _set_initial_player_position(_target_position: Vector2) -> void:
	if player:
		player.position = _target_position
	
	await get_tree().process_frame


func _set_player_position(_target_position: Vector2) -> void:
	if player:
		player.position = _target_position
	
	await get_tree().process_frame


func _get_player_position() -> Vector2:
	return global_position


func remove_player() -> void:
	if player and current_map:
		var current_global_position = _get_player_position()
		player.reparent(current_map)
		player.global_position = current_global_position
		
		var current_tile = current_map.local_to_map(global_position)
		if current_direction == LPCCharacter.DIRECTIONS.LEFT:
			current_tile.x -= (extra_dimensions.grow_left + 1)
		elif current_direction == LPCCharacter.DIRECTIONS.RIGHT:
			current_tile.x += (extra_dimensions.grow_right + 1)
		if current_direction == LPCCharacter.DIRECTIONS.UP:
			current_tile.y -= (extra_dimensions.grow_up + 1)
		elif current_direction == LPCCharacter.DIRECTIONS.DOWN:
			current_tile.y += (extra_dimensions.grow_down + 1)

		var _target_position = current_map.get_tile_position(current_tile)
		current_map.set_event_direction(player, current_direction)
		await _set_player_position(_target_position)
		player.position = _target_position

		player.set_process(true)
		player.set_process_input(true)
		var camera = GameManager.get_camera()
		if camera:
			camera.remove_target_from_array(self)
			camera.add_target_to_array(player)
		player.current_direction = current_direction
		player.last_direction = current_direction
		var t = create_tween()
		player.modulate.a = 0.8
		player.is_on_vehicle = false
		player.current_vehicle = null
		t.tween_property(player, "modulate:a", 1.0, 0.25)
		player = null
		
	disembark_passenger()


func board_passenger(passenger: LPCCharacter) -> void:
	if passenger.has_method("kill_movement"):
		passenger.kill_movement()
	player = passenger
	player.current_animation = "idle"
	player.current_frame = 0
	player.is_on_vehicle = true
	player.current_vehicle = self
	player.current_direction = current_direction
	player.last_direction = current_direction
	#current_direction = player.current_direction
	player.run_animation()
	initial_delay = 0.06
	is_enabled = true


func can_disembark() -> bool:
	var motion = Vector2i.ZERO
	if current_direction == LPCCharacter.DIRECTIONS.LEFT:
		motion.x = -1
	elif current_direction == LPCCharacter.DIRECTIONS.RIGHT:
		motion.x = 1
	if current_direction == LPCCharacter.DIRECTIONS.UP:
		motion.y = -1
	elif current_direction == LPCCharacter.DIRECTIONS.DOWN:
		motion.y = 1

	var movement1 = get_possible_movement(motion)
	var movement2: Vector2i = Vector2i.ONE
	if player:
		movement2 = get_player_possible_movement(motion)
		#movement2 = player.get_possible_movements(motion)

	return movement1 != Vector2i.ZERO and movement2 != Vector2i.ZERO


func get_adjacent_event() -> Variant:
	var current_tile = current_map.local_to_map(global_position)
	var event = null
	
	if current_direction == LPCCharacter.DIRECTIONS.LEFT:
		var max_distance = extra_dimensions.grow_left + 1
		for distance in range(max_distance, 0, -1):  # Desde el más lejano hasta 1
			var adjacent_tile = Vector2(current_tile.x - distance, current_tile.y)
			event = current_map.get_in_game_event_in(adjacent_tile)
			if event:
				break
				
	elif current_direction == LPCCharacter.DIRECTIONS.RIGHT:
		var max_distance = extra_dimensions.grow_right + 1
		for distance in range(max_distance, 0, -1):  # Desde el más lejano hasta 1
			var adjacent_tile = Vector2(current_tile.x + distance, current_tile.y)
			event = current_map.get_in_game_event_in(adjacent_tile)
			if event:
				break
				
	elif current_direction == LPCCharacter.DIRECTIONS.UP:
		var max_distance = extra_dimensions.grow_up + 1
		for distance in range(max_distance, 0, -1):  # Desde el más lejano hasta 1
			var adjacent_tile = Vector2(current_tile.x, current_tile.y - distance)
			event = current_map.get_in_game_event_in(adjacent_tile)
			if event:
				break
				
	elif current_direction == LPCCharacter.DIRECTIONS.DOWN:
		var max_distance = extra_dimensions.grow_down + 1
		for distance in range(max_distance, 0, -1):  # Desde el más lejano hasta 1
			var adjacent_tile = Vector2(current_tile.x, current_tile.y + distance)
			event = current_map.get_in_game_event_in(adjacent_tile)
			if event:
				break
	
	return event


func disembark_passenger() -> void:
	if player:
		player.set_process(true)
		player.set_process_input(true)
		player = null
	
	var vehicles = ["land_transport_start_position", "sea_transport_start_position", "air_transport_start_position"]
	var id = clamp(int(vehicle_type), 0, 2)
	
	if GameManager.current_map:
		var vehicle_position: RPGMapPosition = RPGMapPosition.new(GameManager.current_map.internal_id, get_current_tile())
		GameManager.game_state.set(vehicles[id], vehicle_position)


func _process(delta: float) -> void:
	if GameManager.busy or GameInterpreter.busy or force_movement_enabled or is_jumping or force_jump_enabled or GameManager.loading_game:
		return
	
	if Input.is_key_pressed(KEY_CTRL) and OS.is_debug_build() and not ctrl_pressed:
		ctrl_pressed = true
		call_deferred("propagate_call", "set_disabled", [true])
	elif ctrl_pressed and not Input.is_key_pressed(KEY_CTRL):
		ctrl_pressed = false
		call_deferred("propagate_call", "set_disabled", [false])

	movement_vector = Vector2.ZERO
	if !is_enabled:
		fix_offsets()
		return
	elif initial_delay > 0:
		initial_delay -= delta
		return
	elif !is_moving:
		if Input.is_action_just_pressed("ui_select"):
			if can_disembark():
				end()
			elif player and can_interact_from_the_vehicle:
				var event = get_adjacent_event()
				if event and "start" in event and not event.get_class() == "RPGExtractionScene":
					event.start(player, RPGEventPage.LAUNCHER_MODE.ACTION_BUTTON)
		
		if player:
			player.current_direction = current_direction
			player.run_animation()
		
		movement_vector = Vector2(Input.get_axis("ui_left", "ui_right"), Input.get_axis("ui_up", "ui_down"))

	var diagonal_movement_direction_mode = RPGSYSTEM.database.system.options.get("movement_mode", 0)
	match diagonal_movement_direction_mode:
		0: prioritize_vertical_look()
		1: prioritize_horizontal_look()
		2: maintain_current_look()
	
	current_direction = last_direction
	
	var direction_name = get_direction_name()
	var animation_name = %AnimationPlayer.get_current_animation()
	if not direction_name in animation_name:
		_update_animation(animation_name, direction_name)


func _update_animation(animation_name: String, direction_name: String) -> void:
	var regex = RegEx.new()
	regex.compile("[A-Z]")
	var matchs = regex.search_all(animation_name)
	
	var arr = []
	var s = 0
	
	for m in matchs:
		if m.get_start() > s:
			arr.append(animation_name.substr(s, m.get_start() - s))
		s = m.get_start()
	
	if arr.size() > 0:
		arr.pop_back()
	
	current_animation = "".join(arr) + direction_name
	if %AnimationPlayer.has_animation(current_animation):
		%AnimationPlayer.play(current_animation)


func force_movement(motion: Vector2, keep_direction: bool = false) -> void:
	movement_vector = motion
	force_movement_enabled = true
	
	if not keep_direction:
		var diagonal_movement_direction_mode = RPGSYSTEM.database.system.options.get("movement_mode", 0)
		match diagonal_movement_direction_mode:
			0: prioritize_vertical_look(true, movement_vector)
			1: prioritize_horizontal_look(true, movement_vector)
			2: maintain_current_look(true, movement_vector)
		
		current_direction = last_direction
	
	
	await move_vehicle()


func reset_force_movement() -> void:
	force_movement_enabled = false
	force_jump_enabled = false


func _physics_process(_delta: float) -> void:
	if GameManager.loading_game:
		return
		
	_fix_z_ordering()
	
	if is_moving or movement_vector == Vector2.ZERO or not is_enabled or is_jumping or force_movement_enabled or force_jump_enabled:
		return
	
	move_vehicle()


func prioritize_vertical_look(use_motion: bool = false, motion: Vector2 = Vector2.ZERO) -> void:
	# Preferred vertical direction when moving diagonally
	if use_motion:
		if motion.y < 0:
			last_direction = LPCCharacter.DIRECTIONS.UP
		elif motion.y > 0:
			last_direction = LPCCharacter.DIRECTIONS.DOWN
		elif motion.x < 0:
			last_direction = LPCCharacter.DIRECTIONS.LEFT
		elif motion.x > 0:
			last_direction = LPCCharacter.DIRECTIONS.RIGHT
	else:
		if Input.is_action_pressed("ui_up"):
			last_direction = LPCCharacter.DIRECTIONS.UP
		elif Input.is_action_pressed("ui_down"):
			last_direction = LPCCharacter.DIRECTIONS.DOWN
		elif Input.is_action_pressed("ui_left"):
			last_direction = LPCCharacter.DIRECTIONS.LEFT
		elif Input.is_action_pressed("ui_right"):
			last_direction = LPCCharacter.DIRECTIONS.RIGHT


func prioritize_horizontal_look(use_motion: bool = false, motion: Vector2 = Vector2.ZERO) -> void:
	# Preferred horizontal direction when moving diagonally
	if use_motion:
		if motion.x < 0:
			last_direction = LPCCharacter.DIRECTIONS.LEFT
		elif motion.x > 0:
			last_direction = LPCCharacter.DIRECTIONS.RIGHT
		elif motion.y < 0:
			last_direction = LPCCharacter.DIRECTIONS.UP
		elif motion.y > 0:
			last_direction = LPCCharacter.DIRECTIONS.DOWN
	else:
		if Input.is_action_pressed("ui_left"):
			last_direction = LPCCharacter.DIRECTIONS.LEFT
		elif Input.is_action_pressed("ui_right"):
			last_direction = LPCCharacter.DIRECTIONS.RIGHT
		elif Input.is_action_pressed("ui_up"):
			last_direction = LPCCharacter.DIRECTIONS.UP
		elif Input.is_action_pressed("ui_down"):
			last_direction = LPCCharacter.DIRECTIONS.DOWN


func maintain_current_look(use_motion: bool = false, motion: Vector2 = Vector2.ZERO) -> void:
	# Preferred current direction used when moving diagonally
	var dir_pressed_count = 0
	
	if use_motion:
		if motion.x < 0: dir_pressed_count += 1
		if motion.x > 0: dir_pressed_count += 1
		if motion.y < 0: dir_pressed_count += 1
		if motion.y > 0: dir_pressed_count += 1
	else:
		if Input.is_action_pressed("ui_left"): dir_pressed_count += 1
		if Input.is_action_pressed("ui_right"): dir_pressed_count += 1
		if Input.is_action_pressed("ui_up"): dir_pressed_count += 1
		if Input.is_action_pressed("ui_down"): dir_pressed_count += 1
		
	if dir_pressed_count == 1:
		prioritize_vertical_look()


#await result.target.move_event(result.value, result.route)
				#GameManager.game_state.stats.steps += 1
			#"jump":
				#await result.target.jump_to(result.value, result.route, result.start_fx, result.end_fx)
				#
#func move_event() -> void:
	#pass
#
#
#func jump_to


func move_vehicle() -> void:
	await start_vehicle_movement()


func start_vehicle_movement() -> void:
	previous_tile = get_current_tile()
	if is_moving or movement_vector == Vector2.ZERO or busy:
		return

	# Verify if the movement is possible
	var possible_movements = get_possible_movement(movement_vector)
	if !possible_movements:
		return
	
	start_movement.emit()
	
	# Calculate the target position
	movement_vector.x = floor(movement_vector.x) if movement_vector.x < 0 else ceil(movement_vector.x)
	movement_vector.y = floor(movement_vector.y) if movement_vector.y < 0 else ceil(movement_vector.y)
	movement_vector *= Vector2(possible_movements)
	
	var motion = movement_vector * Vector2(GameManager.current_map.tile_size)
	if motion.x != 0:
		var collision_x: KinematicCollision2D = move_and_collide(Vector2(motion.x, 0), true)
		if collision_x:
			motion.x = 0
	if motion.y != 0:
		var collision_y: KinematicCollision2D = move_and_collide(Vector2(0, motion.y), true)
		if collision_y:
			motion.y = 0
	
	if !motion:
		return
	
	# Start Movement
	is_moving = true
	var _target_position = position + motion
	var time = max(grid_move_duration.x, grid_move_duration.y)
	
	if movement_tween:
		movement_tween.kill()
	
	movement_tween = create_tween()
	movement_tween.tween_property(self, "position", _target_position, time)
	movement_tween.finished.connect(_on_grid_movement_finished.bind(_target_position))
	
	await movement_tween.finished


func get_tile_passability(target_tile: Vector2i, motion: Vector2) -> Vector2i:
	var result: Vector2i = Vector2i.ZERO
	var map = GameManager.current_map
	if map:
		if map.is_passable(target_tile, current_direction, self):
			if map.can_move_over_terrain(target_tile, can_move_on_terrains):
				result.x = 1 if motion.x != 0 else 0
				result.y = 1 if motion.y != 0 else 0
	
	return result


func get_player_possible_movement(motion: Vector2) -> Vector2i:
	if motion.x < 0 and extra_dimensions.grow_left > 0:
		motion.x -= extra_dimensions.grow_left
	elif motion.x > 0 and extra_dimensions.grow_right > 0:
		motion.x += extra_dimensions.grow_right
	if motion.y < 0 and extra_dimensions.grow_up > 0:
		motion.y -= extra_dimensions.grow_up
	elif motion.y > 0 and extra_dimensions.grow_down > 0:
		motion.y += extra_dimensions.grow_down
		
	var result = player.get_possible_movements(motion)

	return result


func get_possible_movement(motion: Vector2) -> Vector2i:
	var result: Vector2i = Vector2i.ZERO
	
	# Comprobar si hay movimiento y si puede moverse
	if motion.is_zero_approx():
		return Vector2i.ZERO
		
	# Redondear motion
	motion.x = floor(motion.x) if motion.x < 0 else ceil(motion.x)
	motion.y = floor(motion.y) if motion.y < 0 else ceil(motion.y)
	
	# Atajo de depuración
	if Input.is_key_pressed(KEY_CTRL) and OS.is_debug_build():
		return Vector2i(
			1 if motion.x != 0 else 0,
			1 if motion.y != 0 else 0
		)
	
	var real_motion = motion * Vector2(GameManager.current_map.tile_size)
	var collision: KinematicCollision2D = move_and_collide(real_motion, true)
	if collision:
		return(Vector2i.ZERO)
		
	var map = GameManager.current_map
	if not map:
		return result
		
	var current_tile = get_current_tile()
	var dx = int(motion.x)
	var dy = int(motion.y)
	
	# Primera comprobación sin tamaño extra
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
		
	# Si no se puede mover el centro, no hay que comprobar más
	if result == Vector2i.ZERO:
		return result
		
	# Comprobar si hay dimensiones extra en la dirección del movimiento
	var has_extra_dimension = (
		(extra_dimensions.grow_left > 0 and motion.x < 0) or
		(extra_dimensions.grow_right > 0 and motion.x > 0) or
		(extra_dimensions.grow_up > 0 and motion.y < 0) or
		(extra_dimensions.grow_down > 0 and motion.y > 0)
	)
	
	if has_extra_dimension:
		# Ahora verificar todos los tiles entre el centro y el extremo
		if motion.x < 0:  # Movimiento izquierda
			for i in range(1, extra_dimensions.grow_left + 1):
				var test_tile = current_tile + Vector2i(-i, 0)
				if get_tile_passability(map.get_wrapped_tile(test_tile + Vector2i(dx, 0)), motion) == Vector2i.ZERO:
					result.x = 0
					break
		elif motion.x > 0:  # Movimiento derecha
			for i in range(1, extra_dimensions.grow_right + 1):
				var test_tile = current_tile + Vector2i(i, 0)
				if get_tile_passability(map.get_wrapped_tile(test_tile + Vector2i(dx, 0)), motion) == Vector2i.ZERO:
					result.x = 0
					break
		if motion.y < 0:  # Movimiento arriba
			for i in range(1, extra_dimensions.grow_up + 1):
				var test_tile = current_tile + Vector2i(0, -i)
				if get_tile_passability(map.get_wrapped_tile(test_tile + Vector2i(0, dy)), motion) == Vector2i.ZERO:
					result.y = 0
					break
		elif motion.y > 0:  # Movimiento abajo
			for i in range(1, extra_dimensions.grow_down + 1):
				var test_tile = current_tile + Vector2i(0, i)
				if get_tile_passability(map.get_wrapped_tile(test_tile + Vector2i(0, dy)), motion) == Vector2i.ZERO:
					result.y = 0
					break
		
		# Para movimientos diagonales, comprobar los extremos adicionales
		if dx != 0 and dy != 0 and result.x != 0 and result.y != 0:
			var corner_x = current_tile.x + (extra_dimensions.grow_right if dx > 0 else -extra_dimensions.grow_left)
			var corner_y = current_tile.y + (extra_dimensions.grow_down if dy > 0 else -extra_dimensions.grow_up)
			var corner_tile = Vector2i(corner_x, corner_y)
			
			if get_tile_passability(map.get_wrapped_tile(corner_tile + Vector2i(dx, dy)), motion) == Vector2i.ZERO:
				result = Vector2i.ZERO
	
	return result


func _on_grid_movement_finished(_target_position: Vector2) -> void:
	# Ensure exact final position
	var wrapped_position = GameManager.current_map.get_wrapped_position(_target_position)
	if wrapped_position != _target_position:
		var camera = GameManager.get_camera()
		if camera:
			camera.global_position += (wrapped_position - _target_position)
		position = wrapped_position
	else:
		position = _target_position
	
	# update steps
	GameManager.game_state.stats.steps += 1
	
	is_moving = false
	movement_vector = Vector2.ZERO
	
	end_movement.emit()


func get_player() -> LPCCharacter:
	if player:
		return player
	else:
		var node = get_tree().get_first_node_in_group("player")
		if node  and node is LPCCharacter:
			return node
	
	return null


func fix_offsets() -> void:
	var p = get_player()
	if p:
		var player_feet_position = p.global_position
		if player_feet_position.y < global_position.y:
			var diff = offset_view_from_top - %Vehicle.offset.y
			%Vehicle.offset.y = offset_view_from_top
			%Vehicle.position.y -= diff
		elif player_feet_position.y > global_position.y:
			var diff = offset_view_from_bottom - %Vehicle.offset.y
			%Vehicle.offset.y = offset_view_from_bottom
			%Vehicle.position.y -= diff


func start(passenger: LPCCharacter) -> void:
	#passenger.set_process(false)
	#passenger.set_process_input(false)
	GameManager.busy = true
	add_player(passenger)
	GameManager.busy = false
	GameManager.current_vehicle = self
	get_viewport().set_input_as_handled()
	var camera = GameManager.get_camera()
	if camera:
		camera.remove_target_from_array(passenger)
		camera.add_target_to_array(self)
	starting.emit()
	set_process(true)
	set_process_input(true)


func end() -> void:
	set_process(false)
	set_process_input(false)
	GameManager.current_vehicle = null
	is_enabled = false
	ending.emit()
	remove_player()


func set_shadow(_color: Color, _offset: Vector2, _skew: float, _scale: Vector2, _parent: SubViewport, _map_offset: Vector2) -> void:
	pass


func get_current_tile() -> Vector2i:
	if GameManager.current_map:
		return Vector2i(Vector2i(global_position) / GameManager.current_map.tile_size)
	else:
		return Vector2i()


func get_current_tiles() -> Array[Vector2i]:
	var tiles: Array[Vector2i] = []
	
	var vehicle_tile_position = get_current_tile()
	tiles.append(vehicle_tile_position)
	
	if extra_dimensions:
		var vehicle_left = vehicle_tile_position.x - extra_dimensions.grow_left
		if vehicle_left != vehicle_tile_position.x: tiles.append(Vector2i(vehicle_left, vehicle_tile_position.y))
		var vehicle_right = vehicle_tile_position.x + extra_dimensions.grow_right + 1
		if vehicle_right != vehicle_tile_position.x: tiles.append(Vector2i(vehicle_right, vehicle_tile_position.y))
		var vehicle_up = vehicle_tile_position.y - extra_dimensions.grow_up
		if vehicle_up != vehicle_tile_position.y: tiles.append(Vector2i(vehicle_tile_position.x, vehicle_up))
		var vehicle_down = vehicle_tile_position.y + extra_dimensions.grow_down + 1
		if vehicle_down != vehicle_tile_position.y: tiles.append(Vector2i(vehicle_tile_position.x, vehicle_down))
	
	return tiles


func _fix_z_ordering() -> void:
	if not GameManager.current_map:
		return
	
	# 1. RECUPERAR MI Z BASE (NATURAL)
	var my_base_z = z_index
	if has_meta("_backup_z_index"):
		my_base_z = get_meta("_backup_z_index")
	
	var vehicle_tiles = get_current_tiles()
	
	var tiles_to_check_up: int = 2
	var max_floor_z: int = -99999
	var found_floor: bool = false
	
	for tile_feet in vehicle_tiles:
		
		for i in range(0, tiles_to_check_up + 1):
			var tile_to_check = tile_feet - Vector2i(0, i)
			
			var cell_data: Dictionary = GameManager.current_map.get_cell_data(tile_to_check)
			if cell_data.get("keep_events_on_top", false):
				found_floor = true
				max_floor_z = max(max_floor_z, cell_data.get("layer_z_index", 0))
			
			var entities = GameManager.current_map.get_events_objects_in(tile_to_check)
			for entity in entities:
				if entity == self: continue 
				
				if entity.has_meta("_current_floor_z"):
					found_floor = true
					max_floor_z = max(max_floor_z, entity.get_meta("_current_floor_z"))

	if found_floor:
		set_meta("_current_floor_z", max_floor_z)
		
		var terrain_required_z = max_floor_z + 1
		var final_z = max(my_base_z, terrain_required_z)
		
		if z_index != final_z:
			if not has_meta("_backup_z_index"):
				set_meta("_backup_z_index", my_base_z)
			z_index = final_z
			
		elif z_index == my_base_z and has_meta("_backup_z_index"):
			remove_meta("_backup_z_index")
	else:
		if has_meta("_current_floor_z"):
			remove_meta("_current_floor_z")
			
		if has_meta("_backup_z_index"):
			z_index = get_meta("_backup_z_index")
			remove_meta("_backup_z_index")


func get_shadow_data() -> Dictionary:
	return {}


func run_animation() -> void:
	pass


func jump_to(new_pos: Vector2, _route: RPGMovementRoute = null, start_fx: Dictionary = {}, end_fx: Dictionary = {}) -> void:
	if is_moving or busy or is_jumping:
		return
		
	var possible_movement = get_possible_movement(new_pos)
	@warning_ignore("incompatible_ternary")
	var motion = null if !possible_movement else new_pos * Vector2(GameManager.current_map.tile_size)
	
	if !motion:
		return
		
	match RPGSYSTEM.database.system.options.get("movement_mode", 0):
		0: prioritize_vertical_look(true, motion)
		1: prioritize_horizontal_look(true, motion)
		2: maintain_current_look(true, motion)
	current_direction = last_direction
	
	var start_pos = position
	var end_pos = position + motion
	var distance = motion.length()
	var jump_height = min(MAX_JUMP_HEIGHT, distance * 0.5)
	var jump_duration = clamp(distance * 0.1, 0.2, 0.35)
	is_jumping = true
	force_jump_enabled = true
	
	current_animation = "start_jump"
	run_animation()
	
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
	
	if movement_tween:
		movement_tween.kill()
		
		movement_tween = create_tween()

		if start_fx:
			movement_tween.tween_callback(GameManager.play_se.bind(
				start_fx.get("path", ""), start_fx.get("volume", 0.0), start_fx.get("pitch", 1.0)
			))
		
		# Squash before jump
		movement_tween.tween_property(self, "scale", Vector2(0.94, 0.8), 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
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
		
		movement_tween.tween_callback(
			func():
				current_animation = "end_jump"
				run_animation()
		).set_delay(jump_duration * 0.75)
		
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
				if "get_shadow_data" in self:
					var shadow_data = call("get_shadow_data")
					if shadow_data is Dictionary and "sprite_shadow" in shadow_data and shadow_data.sprite_shadow is Node:
						shadow_data.sprite_shadow.set_meta("is_jumping", false)
		)

		await movement_tween.finished


func _on_end_movement() -> void:
	if player and player.has_signal("end_movement"):
		player.emit_signal("end_movement")


func get_player_position() -> Vector2:
	return global_position


func get_current_position() -> Vector2:
	return global_position


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
