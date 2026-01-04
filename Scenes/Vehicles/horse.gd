@tool
extends RPGVehicle


#const SMOKE_1 = preload("res://Scenes/ParticleScenes/smoke_1.tscn")
@onready var smoke: GPUParticles2D = %Smoke


func _ready() -> void:
	super ()
	%Character.texture = %CharacterViewport.get_texture()
	%MainCharacter.texture = %FinalCharacter.get_texture()
	%VehicleFinal.texture = %VehicleViewport.get_texture()
	%FinalShadow.texture = %Final.get_texture()
	%FinalVehicle.texture = %Final.get_texture()
	
	set_extra_dimensions()
	if !Engine.is_editor_hint():
		start_movement.connect(run_animation)
		end_movement.connect(run_animation)
	else:
		start_direction_changed.connect(run_animation)
	starting.connect(_on_starting)
	ending.connect(_on_ending)

	run_animation()


func _on_starting() -> void:
	if player:
		player.set_meta("current_scale_y", player.scale.y)
		player.scale.y = player.scale.y * 0.98


func _on_ending() -> void:
	if player and player.has_meta("current_scale_y"):
		player.scale.y = player.get_meta("current_scale_y")
		player.remove_meta("current_scale_y")


func _get_player_position() -> Vector2:
	return global_position + Vector2(0, -%MainCharacter.global_position.y)


func _set_initial_player_position(_target_position: Vector2) -> void:
	if player and "current_direction" in player:
		player.z_index = 10
		var dest = %StartPlayerPosition.get_global_position()
		var t = create_tween()
		t.set_trans(Tween.TRANS_CIRC)
		t.tween_property(player, "global_position", dest, 0.1)

		await t.finished
		player.z_index = 1
	else:
		player.position = _target_position
		await get_tree().process_frame


func _set_player_position(_target_position: Vector2) -> void:
	if player:
		var t = create_tween()
		t.set_trans(Tween.TRANS_CIRC)
		player.z_index = 10
		match current_direction:
			LPCCharacter.DIRECTIONS.LEFT:
				t.tween_property(player, "position", Vector2(player.position.x - 16, player.position.y - 8), 0.08)
			LPCCharacter.DIRECTIONS.RIGHT:
				t.tween_property(player, "position", Vector2(player.position.x + 16, player.position.y - 8), 0.08)
			LPCCharacter.DIRECTIONS.UP:
				player.z_index = 1
				t.tween_property(player, "position", Vector2(player.position.x - 1, player.position.y - 6), 0.08)
			LPCCharacter.DIRECTIONS.DOWN:
				t.tween_property(player, "position", Vector2(player.position.x + 1, player.position.y - 6), 0.08)
		t.tween_property(player, "position", _target_position, 0.06)
		t.tween_property(player, "scale:y", 0.9, 0.05)
		t.tween_property(player, "scale:y", 1.0, 0.05)
		await t.finished
		GameManager.current_player.z_index = 1


func _process(delta: float) -> void:
	if is_jumping or force_jump_enabled:
		return
	
	if Input.is_key_pressed(KEY_I):
		last_direction = LPCCharacter.DIRECTIONS.UP
		current_direction = last_direction
		var direction_name = get_direction_name()
		current_animation = "Idle" + direction_name
		%AnimationPlayer.play(current_animation)
	elif Input.is_key_pressed(KEY_K):
		last_direction = LPCCharacter.DIRECTIONS.DOWN
		current_direction = last_direction
		var direction_name = get_direction_name()
		current_animation = "Idle" + direction_name
		%AnimationPlayer.play(current_animation)
	elif Input.is_key_pressed(KEY_J):
		last_direction = LPCCharacter.DIRECTIONS.LEFT
		current_direction = last_direction
		var direction_name = get_direction_name()
		current_animation = "Idle" + direction_name
		%AnimationPlayer.play(current_animation)
	elif Input.is_key_pressed(KEY_L):
		last_direction = LPCCharacter.DIRECTIONS.RIGHT
		current_direction = last_direction
		var direction_name = get_direction_name()
		current_animation = "Idle" + direction_name
		%AnimationPlayer.play(current_animation)
	
	
	if force_movement_enabled:
		# When in forced movement, only handle galloping animation
		if current_animation.find("Galloping") == -1:
			var direction_name = get_direction_name()
			current_animation = "Galloping" + direction_name
			%AnimationPlayer.play(current_animation)
		return
		
	if !is_enabled:
		if !Engine.is_editor_hint():
			run_animation()
		return

	super (delta)
	
	if (!is_moving and !movement_vector and current_animation.find("Galloping") != -1) or (GameManager.busy and not is_moving):
		var direction_name = get_direction_name()
		current_animation = "Idle" + direction_name
		%AnimationPlayer.play(current_animation)
	
	if is_moving and not smoke.is_emitting():
		smoke.emitting = true
	elif not is_moving and smoke.is_emitting():
		if not is_moving:
			smoke.emitting = false
	
	set_extra_dimensions()
	
	if current_map:
		var _extra_position: Vector2
		
		if current_direction == LPCCharacter.DIRECTIONS.LEFT:
			_extra_position = Vector2(- (extra_dimensions.grow_left + 1) * current_map.tile_size.x, 0)
			%Character.rotation_degrees = 8.8
			player.current_animation = "holding_reins"
		elif current_direction == LPCCharacter.DIRECTIONS.RIGHT:
			_extra_position = Vector2((extra_dimensions.grow_right + 1) * current_map.tile_size.x, 0)
			%Character.rotation_degrees = -2.8
			player.current_animation = "holding_reins"
		if current_direction == LPCCharacter.DIRECTIONS.UP:
			_extra_position = Vector2(0, - (extra_dimensions.grow_up + 1) * current_map.tile_size.y)
			%Character.rotation_degrees = 0
			player.current_animation = "holding_reins"
		elif current_direction == LPCCharacter.DIRECTIONS.DOWN:
			_extra_position = Vector2(0, (extra_dimensions.grow_down + 1) * current_map.tile_size.y)
			%Character.rotation_degrees = 0
			player.current_animation = "holding_reins"
	
	if !is_moving and !movement_vector:
		var direction_name = get_direction_name()
		current_animation = "Idle" + direction_name
		if %AnimationPlayer.get_current_animation() != current_animation:
			%AnimationPlayer.play(current_animation)
	
	var ani = %AnimationPlayer.get_current_animation().to_lower()
	if (
		movement_vector and (
			current_animation.to_lower().find("left") != -1 and ani.find("left") == -1 or
			current_animation.to_lower().find("right") != -1 and ani.find("right") == -1 or
			current_animation.to_lower().find("up") != -1 and ani.find("up") == -1 or
			current_animation.to_lower().find("down") != -1 and ani.find("down") == -1
		)
	):
		var direction_name = get_direction_name()
		current_animation = "Idle" + direction_name
		if %AnimationPlayer.get_current_animation() != current_animation:
			%AnimationPlayer.play(current_animation)


func set_extra_dimensions() -> void:
	var horizontal_extra = 1 if ([LPCCharacter.DIRECTIONS.LEFT, LPCCharacter.DIRECTIONS.RIGHT].has(current_direction)) else 0
	var vertical_extra = 1 if ([LPCCharacter.DIRECTIONS.UP, LPCCharacter.DIRECTIONS.DOWN].has(current_direction)) else 0
	extra_dimensions.grow_left = horizontal_extra
	extra_dimensions.grow_right = horizontal_extra
	extra_dimensions.grow_up = vertical_extra
	extra_dimensions.grow_down = 0


func create_particle() -> void:
	pass


#func create_particle() -> void:
	#var opposite_angle: float
	#var particle_offset: Vector2 = Vector2.ZERO
	#
	## Check if there is diagonal movement (x and y != 0)
	#if movement_vector.x != 0 and movement_vector.y != 0:
		## Diagonal movement - use vector angle
		#opposite_angle = movement_vector.angle() + PI/2
		#
		## Diagonal offset based on direction
		#var normalized_movement = movement_vector.normalized()
		#particle_offset.x = normalized_movement.x * 20
		#particle_offset.y = normalized_movement.y * -60  # Negative because Y grows downwards
		#
	#else:
		## Movement in a single direction - use original match
		#match current_direction:
			#LPCCharacter.DIRECTIONS.LEFT:
				#opposite_angle = PI/2
				#particle_offset.x -= 20
			#LPCCharacter.DIRECTIONS.RIGHT:
				#opposite_angle = -PI/2
				#particle_offset.x += 20
			#LPCCharacter.DIRECTIONS.DOWN:
				#opposite_angle = -PI
				#particle_offset.y -= 60
			#LPCCharacter.DIRECTIONS.UP:
				#particle_offset.y -= 60
				#opposite_angle = PI
	#
	#var smoke = SMOKE_1.instantiate()
	#smoke.position = position + particle_offset
	#smoke.rotation = opposite_angle
	#get_parent().add_child(smoke)
	#get_parent().move_child(smoke, get_index())
#

#func create_particle_explicit_diagonals() -> void:
	#var opposite_angle: float
	#var particle_offset: Vector2 = Vector2.ZERO
	#
	## Determine direction based on movement_vector
	#var direction_x = sign(movement_vector.x)
	#var direction_y = sign(movement_vector.y)
	#
	#if direction_x != 0 and direction_y != 0:
		## Diagonal directions
		#if direction_x > 0 and direction_y > 0:  # Right-Down
			#opposite_angle = -3*PI/4  # -135°
			#particle_offset = Vector2(15, -45)
		#elif direction_x > 0 and direction_y < 0:  # Right-Up
			#opposite_angle = -PI/4   # -45°
			#particle_offset = Vector2(15, -45)
		#elif direction_x < 0 and direction_y > 0:  # Left-Down
			#opposite_angle = 3*PI/4  # 135°
			#particle_offset = Vector2(-15, -45)
		#elif direction_x < 0 and direction_y < 0:  # Left-Up
			#opposite_angle = PI/4    # 45°
			#particle_offset = Vector2(-15, -45)
	#else:
		## Cardinal directions - your original code
		#match current_direction:
			#LPCCharacter.DIRECTIONS.LEFT:
				#opposite_angle = PI/2
				#particle_offset.x -= 20
			#LPCCharacter.DIRECTIONS.RIGHT:
				#opposite_angle = -PI/2
				#particle_offset.x += 20
			#LPCCharacter.DIRECTIONS.DOWN:
				#opposite_angle = -PI
				#particle_offset.y -= 60
			#LPCCharacter.DIRECTIONS.UP:
				#particle_offset.y -= 60
				#opposite_angle = PI
	#
	#var smoke = SMOKE_1.instantiate()
	#smoke.position = position + particle_offset
	#smoke.rotation = opposite_angle
	#get_parent().add_child(smoke)
	#get_parent().move_child(smoke, get_index())


func run_animation() -> void:
	if player:
		player.current_direction = current_direction
		player.run_animation()
	
	var direction_name = get_direction_name()
	
	# If in forced movement, always keep galloping animation
	if force_movement_enabled and not force_jump_enabled:
		current_animation = "Galloping" + direction_name
		if %AnimationPlayer.current_animation != current_animation:
			%AnimationPlayer.play(current_animation)
		return
	
	if is_jumping:
		if current_animation == "start_jump":
			current_animation = "StartJump" + direction_name
		elif current_animation == "end_jump":
			current_animation = "EndJump" + direction_name
	elif (is_moving or (is_enabled and Input.is_action_pressed("any_direction"))) and not force_jump_enabled:
		current_animation = "Galloping" + direction_name
	elif current_animation.find("Animation") == -1 and randf() > 0.992:
		current_animation = "Idle" + direction_name + "Animation"
	elif (
		!current_animation or
		(current_animation.find("Animation") != -1 and !%AnimationPlayer.is_playing()) or
		current_animation.find("Galloping") != -1 or
		!movement_vector
	) and not force_movement_enabled:
		current_animation = "Idle" + direction_name

	if %AnimationPlayer.current_animation != current_animation:
		%AnimationPlayer.play(current_animation)


func is_any_direction_pressed() -> bool:
	var result = \
		Input.is_action_pressed("ui_left") or \
		Input.is_action_pressed("ui_right") or \
		Input.is_action_pressed("ui_up") or \
		Input.is_action_pressed("ui_down")
	
	return result


#override
func get_player_position() -> Vector2:
	var p = %MainCharacter.global_position - %MainCharacter.get_texture().get_size() * 0.5
	return global_position + p + %FinalVehicle.offset


func get_shadow_data() -> Dictionary:
	var tex = $Final.get_texture()
	
	var shadow = {
		"texture": tex,
		"position": global_position - tex.get_size() * 0.5 + $FinalVehicle.position + $FinalVehicle.offset,
		"is_shadow_viewport": true,
		"texture_viewport": %Shadow.get_texture(),
		"sprite_shadow": %FinalShadow,
		"shadow_position": global_position - %Shadow.get_texture().get_size() * 0.5,
		"sprite_scale": scale
	}
	
	if GameManager.current_map:
		shadow.cell = Vector2i(global_position / Vector2(GameManager.current_map.tile_size))
	
	return shadow
