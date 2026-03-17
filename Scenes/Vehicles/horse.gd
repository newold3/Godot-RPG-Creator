@tool
extends RPGVehicle


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
		mouse_movement_started.connect(_on_mouse_movement_started)
		mouse_movement_ended.connect(_on_mouse_movement_ended)
	else:
		start_direction_changed.connect(run_animation)
	starting.connect(_on_starting)
	ending.connect(_on_ending)
	run_animation()


func _on_mouse_movement_started() -> void:
	var direction_name = get_direction_name()
	current_animation = "Galloping" + direction_name
	if %AnimationPlayer.current_animation != current_animation:
		%AnimationPlayer.play(current_animation)


func _on_mouse_movement_ended() -> void:
	var direction_name = get_direction_name()
	current_animation = "Idle" + direction_name
	if %AnimationPlayer.current_animation != current_animation:
		%AnimationPlayer.play(current_animation)


func _on_starting() -> void:
	if player:
		player.set_meta("current_scale_y", player.scale.y)
		player.scale.y = player.scale.y * 0.98


func _on_ending() -> void:
	if player and player.has_meta("current_scale_y"):
		player.scale.y = player.get_meta("current_scale_y")
		player.remove_meta("current_scale_y")


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


func get_player_visual_offset() -> Vector2:
	return Vector2(-1, -40)


func _get_player_position() -> Vector2:
	if player:
		if player.is_on_vehicle:
			return global_position + get_player_visual_offset()
		else:
			return player.global_position
	return global_position


func _set_player_position(_target_position: Vector2) -> void:
	if player:
		var t = create_tween()
		t.set_trans(Tween.TRANS_CIRC)
		player.z_index = 10
		var start_pos = player.global_position
		match current_direction:
			LPCCharacter.DIRECTIONS.LEFT:
				t.tween_property(player, "global_position", start_pos + Vector2(-16, -12), 0.08)
			LPCCharacter.DIRECTIONS.RIGHT:
				t.tween_property(player, "global_position", start_pos + Vector2(16, -12), 0.08)
			LPCCharacter.DIRECTIONS.UP:
				player.z_index = 1
				t.tween_property(player, "global_position", start_pos + Vector2(-1, -12), 0.08)
			LPCCharacter.DIRECTIONS.DOWN:
				t.tween_property(player, "global_position", start_pos + Vector2(1, -12), 0.08)
		t.tween_property(player, "global_position", _target_position, 0.06)
		t.tween_property(player, "scale:y", 0.9, 0.05)
		t.tween_property(player, "scale:y", 1.0, 0.05)
		await t.finished
		if GameManager.current_player:
			GameManager.current_player.z_index = 1


func _process(delta: float) -> void:
	if is_jumping or force_jump_enabled:
		return
	if GameInterpreter.is_busy():
		var direction_name = get_direction_name()
		current_animation = "Idle" + direction_name
		%AnimationPlayer.play(current_animation)
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
		if current_animation.find("Galloping") == -1:
			var direction_name = get_direction_name()
			current_animation = "Galloping" + direction_name
			%AnimationPlayer.play(current_animation)
		return
	if !is_enabled:
		if !Engine.is_editor_hint():
			run_animation()
		return
	super(delta)
	if is_mouse_moving:
		var direction_name = get_direction_name()
		var target_animation = "Galloping" + direction_name
		if %AnimationPlayer.current_animation != target_animation:
			current_animation = target_animation
			%AnimationPlayer.play(current_animation)
	else:
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
	if !is_mouse_moving and !is_moving and !movement_vector:
		var direction_name = get_direction_name()
		current_animation = "Idle" + direction_name
		if %AnimationPlayer.get_current_animation() != current_animation:
			%AnimationPlayer.play(current_animation)
	var ani = %AnimationPlayer.get_current_animation().to_lower()
	if (
		(is_mouse_moving or movement_vector or is_moving) and (
			current_animation.to_lower().find("left") != -1 and ani.find("left") == -1 or
			current_animation.to_lower().find("right") != -1 and ani.find("right") == -1 or
			current_animation.to_lower().find("up") != -1 and ani.find("up") == -1 or
			current_animation.to_lower().find("down") != -1 and ani.find("down") == -1
		)
	):
		var direction_name = get_direction_name()
		current_animation = "Galloping" + direction_name if (is_mouse_moving or movement_vector or is_moving) else "Idle" + direction_name
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


func run_animation() -> void:
	if not current_animation: return
	
	if player:
		player.current_direction = current_direction
		player.run_animation()
	var direction_name = get_direction_name()
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
	elif is_mouse_moving:
		current_animation = "Galloping" + direction_name
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


func get_shadow_data() -> Dictionary:
	var sprite = %FinalVehicle
	var tex = sprite.texture
	if not tex: return {}
	var img = tex.get_image()
	if not img: return {}
	var used_rect = img.get_used_rect()
	var atlas = AtlasTexture.new()
	atlas.atlas = tex
	atlas.region = used_rect
	var tex_origin = sprite.offset - (tex.get_size() / 2.0)
	var local_x_min = tex_origin.x + used_rect.position.x
	var local_x_max = tex_origin.x + used_rect.position.x + used_rect.size.x
	var local_y_min = tex_origin.y + used_rect.position.y
	var local_y_max = tex_origin.y + used_rect.position.y + used_rect.size.y
	var p_bl_local = Vector2(local_x_min, local_y_max)
	var p_br_local = Vector2(local_x_max, local_y_max)
	var p_tr_local = Vector2(local_x_max, local_y_min)
	var p_tl_local = Vector2(local_x_min, local_y_min)
	var quad_points = [
		sprite.to_global(p_bl_local),
		sprite.to_global(p_br_local),
		sprite.to_global(p_tr_local),
		sprite.to_global(p_tl_local)
	]
	quad_points[0].y -= 1
	quad_points[1].y -= 1
	var tile_size: Vector2 = GameManager.get_map_tile_size()
	return {
		"main_node": self,
		"texture": atlas,
		"quad_points": quad_points,
		"position": global_position,
		"cell": Vector2i(global_position / tile_size)
	}
