@tool
class_name LPCCharacter
extends LPCBase


func get_class() -> String: return "LPCCharacter"
func get_custom_class() -> String: return "LPCCharacter"


#region Constants, Signals and Variables
@export var actor_data: RPGLPCCharacter

var ctrl_pressed: bool = false # Debug key

#endregion


func _ready() -> void:
	end_movement.connect(_reset)
	current_data = actor_data
	super()


func set_data(_data: RPGLPCCharacter) -> void:
	current_data = _data
	install_parts()


func is_passable() -> bool:
	var node = get_node_or_null("%CollisionShape")
	var passable = not node.disabled
	if node: return passable
	return false


func get_character_sprite() -> Sprite2D:
	return body


func set_modulate(color: Color) -> void:
	# Overwrite the set_modulate method to change the color in body and wings nodes
	body.modulate = color
	wings_back.modulate = color


func change_blend_mode(blend_mode: CanvasItemMaterial.BlendMode) -> void:
	body.get_material().set("blend_mode", blend_mode)


func change_graphics(path: String) -> void:
	pass


# call only when character creator editor create it
func _build() -> void:
	add_to_group("player")
	super()



#region Movement and actions:
func prioritize_vertical_look() -> void:
	# Preferred vertical direction when moving diagonally
	if Input.is_action_pressed("ui_up"):
		last_direction = DIRECTIONS.UP
	elif Input.is_action_pressed("ui_down"):
		last_direction = DIRECTIONS.DOWN
	elif Input.is_action_pressed("ui_left"):
		last_direction = DIRECTIONS.LEFT
	elif Input.is_action_pressed("ui_right"):
		last_direction = DIRECTIONS.RIGHT


func prioritize_horizontal_look() -> void:
	# Preferred horizontal direction when moving diagonally
	if Input.is_action_pressed("ui_left"):
		last_direction = DIRECTIONS.LEFT
	elif Input.is_action_pressed("ui_right"):
		last_direction = DIRECTIONS.RIGHT
	elif Input.is_action_pressed("ui_up"):
		last_direction = DIRECTIONS.UP
	elif Input.is_action_pressed("ui_down"):
		last_direction = DIRECTIONS.DOWN


func maintain_current_look() -> void:
	# Preferred current direction used when moving diagonally
	var dir_pressed_count = 0
	if Input.is_action_pressed("ui_left"): dir_pressed_count += 1
	if Input.is_action_pressed("ui_right"): dir_pressed_count += 1
	if Input.is_action_pressed("ui_up"): dir_pressed_count += 1
	if Input.is_action_pressed("ui_down"): dir_pressed_count += 1
	if dir_pressed_count == 1:
		prioritize_vertical_look()


func _process(delta: float) -> void:
	if busy2: return
	super(delta)
	if GameManager.loading_game or is_invalid_event:
		return
		
	if frame_delay <= 0.0:
		run_animation()
		var current_anim_data = get_current_animation()
		var target_fps = current_anim_data.get("fps", 0)
		if target_fps > 0:
			frame_delay = 1.0 / float(target_fps)
		else:
			if is_attacking:
				frame_delay = frame_delay_max_attacking
			elif is_running:
				frame_delay = frame_delay_max_running
			else:
				frame_delay = frame_delay_max
	else:
		frame_delay = max(0.0, frame_delay - delta)
		
	if is_pushing and is_running:
		is_running = false
		if movement_current_mode == MOVEMENTMODE.GRID:
			calculate_grid_move_duration()
			
	if force_animation_enabled or !can_perform_action() or is_on_vehicle:
		return
		
	var input_vector = Vector2(Input.get_axis("ui_left", "ui_right"), Input.get_axis("ui_up", "ui_down"))
	if input_vector != Vector2.ZERO:
		movement_vector = input_vector
		_auto_target_tile = Vector2i(-1, -1)
		_auto_target_event = null
		if not character_options.fixed_direction:
			var diagonal_movement_direction_mode = RPGSYSTEM.database.system.options.get("movement_mode", 0)
			match diagonal_movement_direction_mode:
				0: prioritize_vertical_look()
				1: prioritize_horizontal_look()
				2: maintain_current_look()
			current_direction = last_direction
			
	if Vector2(movement_vector) != Vector2.ZERO:
		current_animation = "walk"
		movement_vector = Vector2(movement_vector).normalized()
	else:
		if _auto_target_tile == Vector2i(-1, -1):
			current_animation = "idle"
			
	if current_animation == "walk" and not is_pushing:
		var last_is_running = is_running
		is_running = Input.is_action_pressed("running")
		if last_is_running != is_running and movement_current_mode == MOVEMENTMODE.GRID:
			calculate_grid_move_duration()
	elif is_running:
		is_running = false
		if movement_current_mode == MOVEMENTMODE.GRID:
			calculate_grid_move_duration()
			
	if Input.is_key_pressed(KEY_CTRL) and OS.is_debug_build() and not ctrl_pressed:
		ctrl_pressed = true
		call_deferred("propagate_call", "set_disabled", [true])
	elif ctrl_pressed and not Input.is_key_pressed(KEY_CTRL):
		ctrl_pressed = false
		call_deferred("propagate_call", "set_disabled", [false])


## Handles player input events for movement cancellation and interaction
func _input(event: InputEvent) -> void:
	if GameManager.loading_game or is_invalid_event:
		return

	if event.is_action_pressed("ui_up") or event.is_action_pressed("ui_down") or event.is_action_pressed("ui_left") or event.is_action_pressed("ui_right") or event.is_action_pressed("ui_select"):
		_auto_target_tile = Vector2i(-1, -1)
		_auto_target_event = null

	if busy or is_lifting:
		return

	if !can_perform_action() and not carried_event:
		return

	if event.is_action_pressed("ui_select") and not active_boomerang:
		if carried_event:
			if not is_moving and not is_jumping:
				throw_event()
			return
			
		_reset()
		var action_found: bool = false
		
		var nodes = get_events_at_adjacent_tile()

		for node in nodes:
			if node is RPGVehicle:
				_reset(true)
				node.start(self)
				action_found = true
				break
				
			elif node is LPCEvent or node is EmptyLPCEvent or node is GenericLPCEvent:
				_reset(true)
				is_moving = false
				current_animation = "idle"
				current_frame = 0
				run_animation()
				
				if "current_event" in node and node.current_event is RPGEvent and node.current_event.next_page_has_pressure():
					action_found = true
					break
					
				var result = await node.start(self, RPGEnums.LauncherMode.ACTION_BUTTON)
				if result:
					action_found = true
					break
				
			elif node is RPGExtractionItem:
				var scene = node.scene
				if scene and not scene.extraction_data.is_depleted():
					GameManager.manage_extraction_scene(scene)
					action_found = true
					break
			
			elif node is EventRegion:
				if node.trigger_mode == EventRegion.TriggerMode.PRESS_BUTTON:
					_reset(true)
					GameManager.start_event_region(node, self, 0)
					return

		if not action_found and interactive_event and is_instance_valid(interactive_event) and interactive_event.has_method("interact"):
			var dist = global_position.distance_to(interactive_event.global_position)
			var tile_size_len = GameManager.get_map_tile_size().length()
			var can_activate = false

			if dist < tile_size_len / 2.0:
				can_activate = true
			elif dist <= tile_size_len * 1.5:
				var diff = interactive_event.global_position - global_position
				
				match current_direction:
					DIRECTIONS.LEFT:
						if diff.x < 0 and abs(diff.x) >= abs(diff.y) * 0.5:
							can_activate = true
					DIRECTIONS.RIGHT:
						if diff.x > 0 and abs(diff.x) >= abs(diff.y) * 0.5:
							can_activate = true
					DIRECTIONS.UP:
						if diff.y < 0 and abs(diff.y) >= abs(diff.x) * 0.5:
							can_activate = true
					DIRECTIONS.DOWN:
						if diff.y > 0 and abs(diff.y) >= abs(diff.x) * 0.5:
							can_activate = true

			if can_activate:
				_reset(true)
				interactive_event.interact()
				action_found = true

		if not action_found:
			if current_weapon_data and current_weapon_data.get("id", "none") != "none":
				attack_with_weapon()
			else:
				attack_without_weapon()


func _reset(force_reset: bool = false) -> void:
	is_moving = false
	velocity = Vector2.ZERO
	if movement_current_mode == MOVEMENTMODE.FREE and not force_reset:
		return
	if movement_tween and not _processing_command_route:
		movement_tween.kill()
	if force_reset: current_animation = "idle"
	#is_moving = false
	movement_vector = Vector2.ZERO
	if is_on_vehicle and current_vehicle:
		current_vehicle._reset(true)


#endregion
