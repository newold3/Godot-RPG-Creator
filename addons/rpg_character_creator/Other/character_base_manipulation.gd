class_name CharacterBaseManipulation
extends RefCounted

var current_entity


## Retrieves or creates the internal marker used as the attachment point for carrying events
func _get_shoulders() -> Marker2D:
	var mark
	var parent = current_entity.get_node_or_null("Bounds")
	
	if not parent:
		parent = current_entity
		
	mark = parent.get_node_or_null("CarryPoint")
	
	if not mark:
		mark = Marker2D.new()
		mark.name = "CarryPoint"
		mark.position = Vector2(0.0, -48)
		parent.add_child(mark)
	
	return mark


## Handles the complex sequence of lifting a target event over the character
func pick_up_event(event_node: Node2D) -> void:
	if current_entity.carried_event or current_entity.is_lifting or current_entity.busy: return

	var type_params = {}
	
	if "current_event_page" in event_node and event_node.current_event_page:
		type_params = event_node.current_event_page.options.type_params
	
	var trigger_mask = type_params.get("activation_page_type", 0)
	
	if (trigger_mask & current_entity.LiftTriggers.PRE_LIFT) != 0:
		await current_entity._execute_real_event_page(event_node)
		if current_entity.carried_event or current_entity.is_lifting or current_entity.busy or not is_instance_valid(event_node): return

	var fx = type_params.get("lift_fx", null)
	
	if fx and fx.has("path") and fx.path != "":
		GameManager.play_se(fx.path, fx.get("volume", 0.0), fx.get("pitch", 1.0))

	current_entity.is_lifting = true
	current_entity.busy = true
	current_entity.carried_event = event_node
	current_entity.carried_event.process_mode = Node.PROCESS_MODE_DISABLED
	current_entity.carried_event.y_sort_enabled = false

	if current_entity.carried_event.has_meta("name_label"):
		var label = current_entity.carried_event.get_meta("name_label")
		if is_instance_valid(label):
			label.visible = false

	var backup = {
		"z_index": current_entity.carried_event.z_index,
		"rotation": current_entity.carried_event.rotation
	}
	var main_tex = current_entity.carried_event.get_node_or_null("%MainTexture")

	if main_tex:
		backup["texture"] = main_tex.texture
		backup["region_rect"] = main_tex.region_rect
		backup["offset"] = main_tex.offset
		backup["centered"] = main_tex.centered

		var offset_diff = main_tex.offset
		current_entity.carried_event.global_position += offset_diff
		main_tex.centered = true
		main_tex.offset = Vector2.ZERO

	backup["offsets"] = {
		current_entity.DIRECTIONS.LEFT: Vector2(type_params.get("offset_left_x", 0), type_params.get("offset_left_y", 0)),
		current_entity.DIRECTIONS.RIGHT: Vector2(type_params.get("offset_right_x", 0), type_params.get("offset_right_y", 0)),
		current_entity.DIRECTIONS.UP: Vector2(type_params.get("offset_up_x", 0), type_params.get("offset_up_y", 0)),
		current_entity.DIRECTIONS.DOWN: Vector2(type_params.get("offset_down_x", 0), type_params.get("offset_down_y", 0))
	}

	if current_entity.carried_event.has_method("_disable_collision_shape"):
		current_entity.carried_event._disable_collision_shape(true)
		
	current_entity.carried_event.y_sort_enabled = false
	current_entity.carried_event.z_index = current_entity.z_index + 1

	var mark = _get_shoulders()
	var target_rotation = deg_to_rad(type_params.get("lift_rotation", 0.0))
	var anim_type = type_params.get("animation_type", 0)
	var lift_anim = "lift" if anim_type == 0 else "lift_chest"
	var start_lift_anim = "start_lift" if anim_type == 0 else "start_lift_chest"
	var tween_duration: float = 0.15
	
	if not start_lift_anim.is_empty() and current_entity.has_method("get_current_animation"):
		current_entity.force_animation_enabled = true
		current_entity.current_animation = start_lift_anim
		current_entity.current_frame = 0
		var anim_data = current_entity.call("get_current_animation")
		if anim_data and anim_data.has("frames"):
			var fps = anim_data.get("fps", 0)
			var current_delay = 1.0 / float(fps) if fps > 0 else current_entity.frame_delay_max
			tween_duration = anim_data.frames.size() * current_delay

	var current_custom_offset = backup["offsets"][current_entity.current_direction]
	var target_global_pos = mark.global_position + current_custom_offset
	var mid_duration = tween_duration / 2.0
	var t = current_entity.create_tween()
	
	t.set_parallel(true)
	t.tween_property(current_entity.carried_event, "global_position", target_global_pos, tween_duration)
	t.tween_property(current_entity, "scale:y", current_entity.scale.y * 0.9, mid_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(current_entity, "scale:y", current_entity.scale.y, mid_duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(mid_duration)

	if target_rotation != 0.0:
		t.tween_property(current_entity.carried_event, "rotation", target_rotation, tween_duration)

	t.chain().tween_callback(
		func():
			if current_entity.carried_event != event_node: return
			if not current_entity.carried_event or not is_instance_valid(current_entity.carried_event): return
			
			var visual_parent = current_entity.get_node_or_null("%FullBody")
			if not visual_parent:
				visual_parent = current_entity
			current_entity.carried_event.reparent(visual_parent)
			
			current_entity.carried_event.position = current_entity.to_local(target_global_pos)
			current_entity.carried_event.z_index = 0

			var base_local = current_entity.to_local(mark.global_position)
			backup["x_position"] = base_local.x
			backup["y_position"] = base_local.y
			current_entity.carried_event.set_meta("backup_data", backup)

			if main_tex and type_params.has("lift_image") and type_params.lift_image.path != "":
				var img: RPGIcon = type_params.lift_image
				main_tex.texture = load(img.path)
				main_tex.region_enabled = (img.region != Rect2())
				if main_tex.region_enabled: main_tex.region_rect = img.region

			current_entity.carried_event.show_behind_parent = false
	)

	if not start_lift_anim.is_empty(): await current_entity.animation_finished
	
	if current_entity.carried_event == event_node:
		current_entity.dual_top_frame = 0
		current_entity.force_animation_enabled = false
		current_entity.is_dual_animation = true
		current_entity.dual_top_animation = lift_anim
		current_entity.current_animation = "idle"
		current_entity.current_frame = 0
		current_entity.set_deferred("is_lifting", false)
		current_entity.set_deferred("busy", false)
		
		if is_instance_valid(current_entity.carried_event):
			if anim_type == 0:
				current_entity.carried_event.show_behind_parent = current_entity.current_direction != current_entity.DIRECTIONS.UP
			else:
				current_entity.carried_event.show_behind_parent = current_entity.current_direction == current_entity.DIRECTIONS.UP
		
		if (trigger_mask & current_entity.LiftTriggers.POST_LIFT) != 0 and is_instance_valid(event_node):
			await current_entity._execute_real_event_page(event_node)
	else:
		current_entity.set_deferred("is_lifting", false)
		current_entity.set_deferred("busy", false)


## Calculates the landing parameters and validation target distance
func _get_throw_target_info() -> Dictionary:
	if not current_entity.carried_event:
		return {"distance": 0, "tile": current_entity.get_current_tile()}
		
	var type_params = {}
	
	if "current_event_page" in current_entity.carried_event and current_entity.carried_event.current_event_page:
		type_params = current_entity.carried_event.current_event_page.options.type_params
		
	var throw_strength = type_params.get("throw_strength", 1)
	var can_throw_over = true
	
	if type_params.has("can_throw_over_obstacles"):
		var val = type_params.can_throw_over_obstacles
		if typeof(val) == TYPE_INT:
			can_throw_over = (val == 0)
		else:
			can_throw_over = bool(val)
			
	var map = GameManager.current_map
	
	if not map:
		return {"distance": 0, "tile": current_entity.get_current_tile()}
		
	var current_tile = current_entity.get_current_tile()
	var target_tile = current_tile
	var throw_distance = 0
	var dir_vec = Vector2i.ZERO
	
	match current_entity.current_direction:
		current_entity.DIRECTIONS.UP: dir_vec = Vector2i(0, -1)
		current_entity.DIRECTIONS.DOWN: dir_vec = Vector2i(0, 1)
		current_entity.DIRECTIONS.LEFT: dir_vec = Vector2i(-1, 0)
		current_entity.DIRECTIONS.RIGHT: dir_vec = Vector2i(1, 0)

	var map_size = map.get_map_size_in_tiles() if map.has_method("get_map_size_in_tiles") else Vector2i(9999, 9999)

	if can_throw_over:
		for i in range(throw_strength, 0, -1):
			var check_tile = current_tile + (dir_vec * i)
			
			if not map.infinite_horizontal_scroll:
				if check_tile.x < 0 or check_tile.x >= map_size.x: continue
			if not map.infinite_vertical_scroll:
				if check_tile.y < 0 or check_tile.y >= map_size.y: continue
				
			var wrapped_check_tile = map.get_wrapped_tile(check_tile) if map.has_method("get_wrapped_tile") else check_tile
			var is_valid = map.is_passable(wrapped_check_tile, current_entity.current_direction, current_entity)
			
			if is_valid and map.has_method("can_move_over_terrain"):
				if not map.can_move_over_terrain(wrapped_check_tile, current_entity.can_move_on_terrains):
					is_valid = false
			
			if is_valid and map.has_method("has_any_region_impassable_in"):
				if map.has_any_region_impassable_in(wrapped_check_tile):
					is_valid = false
			
			if is_valid:
				var events_in_tile = map.get_in_game_events_in(wrapped_check_tile, false)
				for ev in events_in_tile:
					if ev == current_entity.carried_event or ev == current_entity: continue
					if current_entity._is_solid(ev):
						is_valid = false
						break
			
			if is_valid:
				return {"distance": i, "tile": check_tile}
				
	else:
		for i in range(1, throw_strength + 1):
			var check_tile = current_tile + (dir_vec * i)
			
			if not map.infinite_horizontal_scroll:
				if check_tile.x < 0 or check_tile.x >= map_size.x: break
			if not map.infinite_vertical_scroll:
				if check_tile.y < 0 or check_tile.y >= map_size.y: break
				
			var wrapped_check_tile = map.get_wrapped_tile(check_tile) if map.has_method("get_wrapped_tile") else check_tile
			var is_physically_blocked = not map.is_passable(wrapped_check_tile, current_entity.current_direction, current_entity)
			
			if not is_physically_blocked and map.has_method("has_any_region_impassable_in"):
				if map.has_any_region_impassable_in(wrapped_check_tile):
					is_physically_blocked = true
			
			if not is_physically_blocked:
				var events_in_tile = map.get_in_game_events_in(wrapped_check_tile, false)
				for ev in events_in_tile:
					if ev == current_entity.carried_event or ev == current_entity: continue
					if current_entity._is_solid(ev):
						is_physically_blocked = true
						break
			
			if is_physically_blocked:
				break
				
			var is_valid_landing = true
			
			if map.has_method("can_move_over_terrain"):
				if not map.can_move_over_terrain(wrapped_check_tile, current_entity.can_move_on_terrains):
					is_valid_landing = false
					
			if is_valid_landing:
				target_tile = check_tile
				throw_distance = i
				
	return {"distance": throw_distance, "tile": target_tile}


## Processes physics and graphics sequence for dropping the loaded event
func throw_event() -> void:
	if not current_entity.carried_event or current_entity.is_lifting or current_entity.busy: return
	
	var type_params = {}
	
	if "current_event_page" in current_entity.carried_event and current_entity.carried_event.current_event_page:
		type_params = current_entity.carried_event.current_event_page.options.type_params
	
	var trigger_mask = type_params.get("activation_page_type", 0)
	
	if (trigger_mask & current_entity.LiftTriggers.PRE_THROW) != 0:
		await current_entity._execute_real_event_page(current_entity.carried_event)
		if not current_entity.carried_event or current_entity.is_lifting or current_entity.busy: return
		
	var map = GameManager.current_map
	var throw_info = _get_throw_target_info()
	
	if not map or throw_info.distance == 0:
		current_entity.set_deferred("is_lifting", false)
		current_entity.set_deferred("busy", false)
		return
		
	var fx = type_params.get("throw_fx", null)
	
	if fx and fx.has("path") and fx.path != "":
		GameManager.play_se(fx.path, fx.get("volume", 0.0), fx.get("pitch", 1.0))
		
	current_entity.is_lifting = true
	current_entity.busy = true
	var target_tile = throw_info.tile
	var throw_distance = throw_info.distance
	var event_to_throw = current_entity.carried_event
	current_entity.carried_event = null
	
	current_entity.disable_dual_animation()
	current_entity.force_animation_enabled = true
	current_entity.current_animation = "slash"
	current_entity.current_frame = 0
	var base_time = type_params.get("time", 0.15) * 1.5
	var original_frame_delay_max = current_entity.frame_delay_max
	
	if current_entity.has_method("get_current_animation"):
		var anim_data = current_entity.call("get_current_animation")
		if anim_data and anim_data.has("frames"):
			var total_frames = anim_data.frames.size()
			if total_frames > 0:
				current_entity.frame_delay_max = base_time / float(total_frames)
				if "frame_delay" in current_entity:
					current_entity.set("frame_delay", 0.0)
					
	current_entity.run_animation()
	event_to_throw.reparent(map, true)
	
	var backup = event_to_throw.get_meta("backup_data", {})
	var target_global_pos = map.get_tile_position(target_tile)
	var jump_height = 24.0 + (throw_distance * 8.0)
	var start_pos = event_to_throw.global_position
	var t = current_entity.create_tween()
	
	t.set_parallel(true)
	
	if backup.has("rotation"):
		t.tween_property(event_to_throw, "rotation", backup["rotation"], base_time)
		
	t.tween_method(
		func(progress: float):
			if is_instance_valid(event_to_throw):
				event_to_throw.global_position = start_pos.lerp(target_global_pos, progress) - Vector2(0, sin(progress * PI) * jump_height),
		0.0,
		1.0,
		base_time
	).set_trans(Tween.TRANS_LINEAR)
	
	await t.finished
	current_entity.frame_delay_max = original_frame_delay_max
	current_entity.force_animation_enabled = false
	current_entity.current_animation = "idle"
	current_entity.current_frame = 0
	current_entity.run_animation()
	
	if is_instance_valid(event_to_throw):
		event_to_throw.process_mode = Node.PROCESS_MODE_INHERIT
		event_to_throw.set_process_internal(true)
		event_to_throw.is_invalid_event = false
		
		if event_to_throw.has_method("update_virtual_tile"):
			event_to_throw.update_virtual_tile()
			
		if event_to_throw.has_meta("name_label"):
			var label = event_to_throw.get_meta("name_label")
			if is_instance_valid(label):
				label.visible = true
				
		if backup.has("z_index"):
			event_to_throw.z_index = backup["z_index"]
		else:
			event_to_throw.z_index = 0
			
		event_to_throw.show_behind_parent = false
			
		if backup.has("collision_layer"):
			event_to_throw.set("collision_layer", backup["collision_layer"])
			event_to_throw.set("collision_mask", backup["collision_mask"])
			
		if event_to_throw.has_method("_disable_collision_shape"):
			event_to_throw._disable_collision_shape(false)
			
		if backup.has("texture") and event_to_throw.has_node("%MainTexture"):
			var main_tex = event_to_throw.get_node("%MainTexture")
			main_tex.texture = backup["texture"]
			main_tex.region_rect = backup["region_rect"]
			main_tex.region_enabled = true
			
		if backup.has("offset") and event_to_throw.has_node("%MainTexture"):
			var main_tex = event_to_throw.get_node("%MainTexture")
			var original_offset = backup["offset"]
			event_to_throw.global_position -= original_offset
			main_tex.centered = backup["centered"]
			main_tex.offset = original_offset
			
		if map.has_method("get_wrapped_position"):
			event_to_throw.global_position = map.get_wrapped_position(event_to_throw.global_position)
			
		if event_to_throw.has_meta("backup_data"):
			event_to_throw.remove_meta("backup_data")
			
		map.update_event_position_in_layout(event_to_throw)
		
		if event_to_throw.has_method("_check_contact_after_move"):
			event_to_throw._check_contact_after_move()
			
	current_entity.set_deferred("is_lifting", false)
	current_entity.set_deferred("busy", false)

	if (trigger_mask & current_entity.LiftTriggers.POST_THROW) != 0 and is_instance_valid(event_to_throw):
		await current_entity._execute_real_event_page(event_to_throw)


## Readies the internal visual indicators and physics bounds for pushing events
func enable_push_mode() -> void:
	current_entity.is_pushing = true
	current_entity.enable_dual_animation("", "push")


## Cancels the push mode logic resetting parameters
func disable_push_mode() -> void:
	current_entity.is_pushing = false
	current_entity.disable_dual_animation()


## Retrieves a pushable event in the intended movement direction if one exists
func _get_pushable_event_in_direction(dir: Vector2) -> Node2D:
	if abs(dir.x) > 0.1 and abs(dir.y) > 0.1:
		return null
		
	var map = GameManager.current_map
	
	if not map: return null
	
	var current_tile = current_entity.get_current_tile()
	var raw_target_tile = current_tile + Vector2i(sign(dir.x), sign(dir.y))
	var target_tile = map.get_wrapped_tile(raw_target_tile) if map.has_method("get_wrapped_tile") else raw_target_tile
	var events = map.get_in_game_events_in(target_tile)
	
	for e in events:
		if e.has_method("is_moveable") and e.is_moveable():
			return e
			
	return null


## Attempts to push a moveable event handling alignment delays and synchronized movement
func try_push_event(event: Node2D, dir: Vector2) -> void:
	if current_entity.busy or current_entity.is_pushing or current_entity.is_lifting:
		return
		
	if abs(dir.x) > 0.1 and abs(dir.y) > 0.1:
		return
	
	if not event.has_method("is_moveable") or not event.is_moveable():
		return
		
	var page = event.current_event_page
	var params = page.options.type_params
	var map = GameManager.current_map
	var trigger_mask = params.get("activation_push_type", 0)
	
	if (trigger_mask & 16) != 0:
		await current_entity._execute_real_event_page(event)
		if current_entity.is_pushing or current_entity.busy or not is_instance_valid(event): return

	current_entity.is_pushing = true
	current_entity.busy = true
	current_entity.is_running = false
	current_entity._cached_collision_layer = current_entity.collision_layer
	current_entity._cached_collision_mask = current_entity.collision_mask
	current_entity.collision_layer = 0
	current_entity.collision_mask = 0
	current_entity._disable_collision_shape(true)
	
	var push_offset = Vector2.ZERO
	
	match current_entity.current_direction:
		current_entity.DIRECTIONS.LEFT: push_offset = Vector2(params.get("push_offset_left_x", 0), params.get("push_offset_left_y", 0))
		current_entity.DIRECTIONS.RIGHT: push_offset = Vector2(params.get("push_offset_right_x", 0), params.get("push_offset_right_y", 0))
		current_entity.DIRECTIONS.UP: push_offset = Vector2(params.get("push_offset_up_x", 0), params.get("push_offset_up_y", 0))
		current_entity.DIRECTIONS.DOWN: push_offset = Vector2(params.get("push_offset_down_x", 0), params.get("push_offset_down_y", 0))
	
	var current_player_tile = current_entity.get_current_tile()
	var expected_base_pos = map.get_tile_position(current_player_tile)
	var target_start_pos = expected_base_pos + push_offset
	
	current_entity.enable_dual_animation("", "push")
	current_entity.current_animation = "walk"
	current_entity.run_animation()
	current_entity.target_position = target_start_pos
	
	var t_align = current_entity.create_tween()
	
	t_align.tween_method(current_entity._update_position.bind([current_entity.position]), current_entity.position, target_start_pos, 0.1)
	await t_align.finished
	
	var delay = params.get("initial_delay", 0.0)
	
	if delay > 0:
		var timer = current_entity.get_tree().create_timer(delay)
		while timer.time_left > 0:
			if not _is_push_input_active(dir):
				_cancel_push()
				return
			await current_entity.get_tree().process_frame
	
	_execute_push_loop(event, dir)


## Handles the synchronized movement between the player and the event ensuring tile alignment
func _execute_push_loop(event: Node2D, dir: Vector2) -> void:
	var page = event.current_event_page
	var params = page.options.type_params
	var map = GameManager.current_map
	
	while _is_push_input_active(dir):
		var is_debug_noclip = Input.is_key_pressed(KEY_CTRL) and OS.is_debug_build()
		var dir_v2i = Vector2i(sign(dir.x), sign(dir.y))
		var current_event_tile = event.get_current_tile()
		var raw_event_next_tile = current_event_tile + dir_v2i
		var event_next_tile = map.get_wrapped_tile(raw_event_next_tile) if map.has_method("get_wrapped_tile") else raw_event_next_tile
		var can_move_event = true
		
		if not is_debug_noclip:
			var possible_movements = event.get_possible_movements(dir)
			
			if possible_movements == Vector2i.ZERO:
				can_move_event = false
			elif map.has_method("has_any_region_impassable_in"):
				if map.has_any_region_impassable_in(event_next_tile):
					can_move_event = false
		
		if not can_move_event:
			current_entity.is_moving = true
			current_entity.is_running = false
			await current_entity.get_tree().process_frame
			continue
			
		var push_duration = params.get("speed", 0.15)
		var safe_speed = current_entity.movement_speed if current_entity.movement_speed > 0 else 1.0
		var player_move_duration = float(current_entity.current_map_tile_size.x) / safe_speed
		push_duration = max(push_duration, player_move_duration)
		
		var move_vector = Vector2(dir_v2i) * Vector2(current_entity.current_map_tile_size)
		var player_target = current_entity.position + move_vector
		var event_target = event.position + move_vector
		var fx = params.get("push_fx", null)
		
		if fx and fx.has("path") and fx.path != "":
			GameManager.play_se(fx.path, fx.get("volume", 0.0), fx.get("pitch", 1.0))
		
		current_entity.is_moving = true
		current_entity.is_running = false
		current_entity.current_animation = "walk"
		current_entity.run_animation()
		current_entity.target_position = player_target
		
		var t_move = current_entity.create_tween()
		
		t_move.set_parallel(true)
		t_move.tween_method(current_entity._update_position.bind([current_entity.position]), current_entity.position, player_target, push_duration)
		t_move.tween_property(event, "position", event_target, push_duration)
		await t_move.finished
		
		var wrapped_player = map.get_wrapped_position(current_entity.position)
		
		if wrapped_player != current_entity.position:
			var offset = wrapped_player - current_entity.position
			current_entity.shift_history_and_followers(offset)
			current_entity.position = wrapped_player
			
			if current_entity.is_in_group("player"):
				var camera = GameManager.get_camera()
				if camera: camera.global_position += offset
		
		event.position = map.get_wrapped_position(event.position)
		event.update_virtual_tile(move_vector)
		map.update_event_position_in_layout(current_entity)
		map.update_event_position_in_layout(event)
		
		if event.has_method("_check_contact_after_move"):
			event._check_contact_after_move()

		var trigger_mask = params.get("activation_push_type", 0)
		
		if (trigger_mask & 32) != 0:
			await current_entity._execute_real_event_page(event)
			if not is_instance_valid(event): break
			
		if current_entity.movement_current_mode != current_entity.MOVEMENTMODE.GRID:
			break
	
	_cancel_push()


## Validates if the player is still pressing the exact direction required to continue pushing
func _is_push_input_active(dir: Vector2) -> bool:
	var input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	
	if dir.x < 0 and input_dir.x >= -0.1: return false
	if dir.x > 0 and input_dir.x <= 0.1: return false
	if dir.y < 0 and input_dir.y >= -0.1: return false
	if dir.y > 0 and input_dir.y <= 0.1: return false
	
	return true


## Cleans up the push state restores physics and animations and snaps the player back to the grid
func _cancel_push() -> void:
	current_entity.collision_layer = current_entity._cached_collision_layer
	current_entity.collision_mask = current_entity._cached_collision_mask
	current_entity._disable_collision_shape(false)
	current_entity.disable_push_mode()
	current_entity.busy = false
	current_entity.is_pushing = false
	current_entity.is_moving = false
	current_entity.movement_vector = Vector2.ZERO
	current_entity.is_running = Input.is_key_pressed(KEY_SHIFT)
	
	if current_entity.movement_current_mode == current_entity.MOVEMENTMODE.GRID:
		var map = GameManager.current_map
		var current_tile = map.get_tile_from_position(current_entity.position)
		var snapped_pos = map.get_tile_position(current_tile)
		current_entity.target_position = snapped_pos
		current_entity._update_position(snapped_pos, [current_entity.position])
	
	current_entity.current_animation = "idle"
	current_entity.current_frame = 0
	current_entity.run_animation()
	current_entity.idle_setted.emit()
