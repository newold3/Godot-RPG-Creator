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
	if GameManager.loading_game:
		return
		
	if frame_delay == 0.0:
		run_animation()
		frame_delay = frame_delay_max if !is_running else frame_delay_max_running
	else:
		frame_delay = max(0.0, frame_delay - delta)
	
	if force_animation_enabled or !can_perform_action() or is_on_vehicle:
		return

	if not character_options.fixed_direction:
		var diagonal_movement_direction_mode = RPGSYSTEM.database.system.options.get("movement_mode", 0)
		match diagonal_movement_direction_mode:
			0: prioritize_vertical_look()
			1: prioritize_horizontal_look()
			2: maintain_current_look()
		current_direction = last_direction
	
	movement_vector = Vector2(Input.get_axis("ui_left", "ui_right"), Input.get_axis("ui_up", "ui_down"))

	if movement_vector != Vector2.ZERO:
		current_animation = "walk"
		movement_vector = movement_vector.normalized()
	else:
		current_animation = "idle"
	
	if current_animation == "walk":
		var last_is_running = is_running
		is_running = Input.is_action_pressed("running")
		if last_is_running != is_running and movement_current_mode == MOVEMENTMODE.GRID:
			calculate_grid_move_duration()
	elif is_running:
		is_running = false
		calculate_grid_move_duration()
	
	if Input.is_key_pressed(KEY_CTRL) and OS.is_debug_build() and not ctrl_pressed:
		ctrl_pressed = true
		call_deferred("propagate_call", "set_disabled", [true])
	elif ctrl_pressed and not Input.is_key_pressed(KEY_CTRL):
		ctrl_pressed = false
		call_deferred("propagate_call", "set_disabled", [false])


func _input(event: InputEvent) -> void:
	if GameManager.loading_game:
		return
	
	if !can_perform_action():
		return
	
	if event.is_action_pressed("ui_select") and can_attack:
		_reset()
		var node = get_event_at_adjacent_tile()
		var action_found: bool = false
		if node:
			if node is RPGVehicle:
				_reset(true)
				node.start(self)
				action_found = true
			elif node is LPCEvent or node is EmptyLPCEvent or node is GenericLPCEvent:
				_reset(true)
				is_moving = false
				current_animation = "idle"
				current_frame = 0
				run_animation()
				var result = await node.start(self, RPGEventPage.LAUNCHER_MODE.ACTION_BUTTON)
				if not result:
					if current_weapon_data and current_weapon_data.get("id", "none") != "none":
						attack_with_weapon()
					else:
						attack_without_weapon()
				action_found = true
			elif node.get_class() == "RPGExtractionScene":
				if not node.extraction_data.is_depleted():
					GameManager.manage_extraction_scene(node)
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
	if movement_tween:
		movement_tween.kill()
	if force_reset: current_animation = "idle"
	#is_moving = false
	movement_vector = Vector2.ZERO


#endregion
