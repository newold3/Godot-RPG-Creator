class_name PartyManager
extends Node

## The packed scene used to instantiate new followers.
const FOLLOWER_SCENE = preload("uid://pbm7vnwv6qll")

## Active follower instances currently in the map.
var followers: Array[SimpleFollower] = []

## Lock to prevent overlapping visual transitions causing visual glitches.
var _is_transitioning: bool = false



#region Player
func add_actor_to_party(actor_id: int) -> void:
	var game_state = GameManager.game_state
	if RPGSYSTEM.database.actors.size() > actor_id:
		if !game_state.actors.has(actor_id):
			var actor = GameActor.new(actor_id)
			game_state.actors[actor_id] = actor
	
	if !game_state.current_party.has(actor_id):
		game_state.current_party.append(actor_id)


func remove_actor_from_party(remove_actor_id: int) -> void:
	var game_state = GameManager.game_state
	var index = game_state.current_party.find(remove_actor_id)
	if index != -1:
		game_state.current_party.remove_at(index)


func clear_current_player() -> void:
	var container = GameManager.main_scene.get_node_or_null("%PlayerContainer")
	if container:
		for player in container.get_children():
			player.queue_free()


func setup_player() -> void:
	var game_state = GameManager.game_state
	var current_map = GameManager.current_map
	
	if not current_map or current_map.internal_id != game_state.current_map_id:
		return
	
	_create_or_reuse_player()
	_position_player()
	_setup_player_properties()
	
	if GameManager._transfer_direction != -1:
		current_map.set_event_direction(GameManager.current_player, GameManager._transfer_direction)
		GameManager._transfer_direction = -1


func _create_or_reuse_player() -> void:
	var current_player = GameManager.current_player
	
	if GameManager.loading_game and current_player and is_instance_valid(current_player):
		current_player.queue_free()
		current_player = null
		
	if (not current_player or not is_instance_valid(current_player)) and GameManager.game_state:
		var player_id = GameManager.game_state.current_party[0] if not GameManager.game_state.current_party.is_empty() else 0
		if player_id > 0 and RPGSYSTEM.database.actors.size() > player_id:
			var actor = RPGSYSTEM.database.actors[player_id]
			var scene_path = actor.character_scene
			if AssetManager.exists(scene_path):
				current_player = load(scene_path).instantiate()
				current_player.name = "Player_" + actor.name
				current_player.set_meta("actor_id", player_id)
				current_player.set_meta("party_id", 0)
				
		if not current_player:
			current_player = preload("uid://bfh5umy1vx2y3").instantiate()
			current_player.name = "Player_Empty"
			current_player.set_meta("actor_id", player_id)
			current_player.set_meta("party_id", 0)
			
	elif current_player and current_player.is_inside_tree():
		current_player.get_parent().remove_child(current_player)
	
	if GameManager.current_map:
		if current_player:
			var tile_size: Vector2i = GameManager.get_map_tile_size()
			current_player.current_map_tile_size = tile_size
			
	GameManager.current_player = current_player


func _position_player() -> void:
	var game_state = GameManager.game_state
	var current_map = GameManager.current_map
	var current_player = GameManager.current_player
	var main_camera = GameManager.main_scene.get_main_camera()
	
	var start_position = Vector2(game_state.current_map_position.x, game_state.current_map_position.y)
	var target_position = current_map.map_to_local(start_position)
	target_position = target_position.snapped(current_map.tile_size)
	
	current_player.position = Vector2(target_position) + current_map.event_offset
	current_player.current_direction = game_state.current_direction
	current_player.last_direction = game_state.current_direction
	current_map.add_child(current_player)
	current_player.initialize_virtual_tile()
	
	main_camera.set_target(current_player)
	await get_tree().process_frame
	main_camera.fast_reposition.call_deferred()


func _setup_player_properties() -> void:
	var current_player = GameManager.current_player
	var game_state = GameManager.game_state
	var current_map = GameManager.current_map
	var main_camera = GameManager.main_scene.get_main_camera()
	
	main_camera.add_target_to_array(current_player, 10)
	main_camera.fast_reposition.call_deferred()
	
	current_player.set_meta("actor_id", game_state.current_party[0])
	current_player.set_meta("party_id", 0)
	
	if "movement_current_mode" in current_player:
		match RPGSYSTEM.database.system.movement_mode:
			0: current_player.movement_current_mode = CharacterBase.MOVEMENTMODE.GRID
			1: current_player.movement_current_mode = CharacterBase.MOVEMENTMODE.FREE
		
	if GameManager.main_scene.is_test_map and current_map:
		current_player.current_map_tile_size = current_map.tile_size
		current_player.calculate_grid_move_duration()
#endregion


#region Followers
func update_party_visuals(instant: bool = false) -> void:
	var game_state = GameManager.game_state
	if not game_state or game_state.current_party.is_empty():
		return
		
	var party = game_state.current_party
	var current_player = GameManager.current_player
	
	if current_player:
		var leader_actor = RPGSYSTEM.database.actors[party[0]]
		
		var cached_dir = current_player.current_direction
		var cached_last_dir = current_player.get("last_direction")
		
		if current_player.get_meta("actor_id", -1) != party[0] or current_player.name == "Player_Empty":
			current_player.set_data(load(leader_actor.character_data_file))
			current_player.name = "Player_" + leader_actor.name
			
		current_player.set_meta("actor_id", party[0])
		current_player.set_meta("party_id", 0)
		
		current_player.current_direction = cached_dir
		if cached_last_dir != null:
			current_player.last_direction = cached_last_dir
			
		if current_player.has_method("run_animation"):
			current_player.run_animation(true)
			
	var changed_indexes := []
	for i in range(1, party.size()):
		var f_idx = i - 1
		if f_idx < followers.size():
			var follower = followers[f_idx]
			if follower.get_meta("actor_id", -1) != party[i]:
				changed_indexes.append(f_idx)
				
	var old_size = followers.size()
	
	_refresh_follower_nodes(instant)
	
	for i in range(1, party.size()):
		var f_idx = i - 1
		if f_idx < followers.size():
			var follower = followers[f_idx]
			
			if f_idx in changed_indexes or f_idx >= old_size:
				await follower.update_appearance_cascade(party[i], instant)



func _refresh_follower_nodes(instant: bool = false) -> void:
	var current_map = GameManager.current_map
	var current_player = GameManager.current_player
	var game_state = GameManager.game_state
	
	if not current_map or not current_player: return
	
	var needed = game_state.current_party.size() - 1
	needed = min(needed, RPGSYSTEM.database.system.party_active_members - 1)
	
	var insert_idx = current_player.get_index()
	
	if followers.size() < needed:
		var start_spots = _get_follower_start_positions(needed)
		while followers.size() < needed:
			var f_idx = followers.size()
			var f = FOLLOWER_SCENE.instantiate() as SimpleFollower
			
			var expected_actor_id = game_state.current_party[f_idx + 1]
			f.set_meta("actor_id", expected_actor_id)
			f.set_meta("party_id", f_idx + 1)
			f.follower_id = f_idx + 1
			
			@warning_ignore("incompatible_ternary")
			var expected_target = current_player if f_idx == 0 else followers[f_idx - 1]
			f.target_node = expected_target
			
			if "current_direction" in expected_target:
				f.current_direction = expected_target.current_direction
				f.fixed_direction = expected_target.current_direction
				
			f.current_animation = "idle"
			f.modulate.a = 1.0 if instant else 0.0
			f.is_sync_active = true
			f.is_invalid_event = false
			f.is_fading_transition = not instant
			
			f.global_position = start_spots[f_idx]
			
			current_map.add_child(f)
			current_map.move_child(f, insert_idx)
			
			if f.has_method("run_animation"):
				f.run_animation()
				
			followers.append(f)
			f.set_meta("requires_init", true)
			
	while followers.size() > needed:
		var f = followers.pop_back()
		f.queue_free()
		
	for i in range(followers.size()):
		var expected_actor_id = game_state.current_party[i+1]
		followers[i].set_meta("actor_id", expected_actor_id)
		followers[i].set_meta("party_id", i+1)
		followers[i].follower_id = i + 1
		
		@warning_ignore("incompatible_ternary")
		var expected_target = current_player if i == 0 else followers[i-1]
		var target_changed = followers[i].get("target_node") != expected_target
		
		followers[i].target_node = expected_target
		
		if "current_direction" in followers[i] and "fixed_direction" in followers[i]:
			followers[i].fixed_direction = followers[i].current_direction
		
		if followers[i].get_meta("requires_init", false) or target_changed:
			if followers[i].has_method("_initialize_queue"):
				followers[i]._initialize_queue()
			followers[i].set_meta("requires_init", false)
			
		if "fixed_direction" in followers[i]:
			followers[i].fixed_direction = -1
	
	rebuild_snake_history.call_deferred()



func _get_follower_start_positions(count: int) -> Array[Vector2]:
	var spots: Array[Vector2] = []
	var current_player = GameManager.current_player
	
	if not current_player:
		for i in range(count): spots.append(Vector2.ZERO)
		return spots
		
	var has_history: bool = "movement_history" in current_player and not current_player.movement_history.is_empty()

	if has_history:
		var history: Array = current_player.movement_history
		var history_offset: int = 24 
		
		for i in range(1, count + 1):
			var target_index: int = history.size() - 1 - (i * history_offset)
			
			if target_index >= 0 and target_index < history.size():
				var snap = history[target_index]
				var pos: Vector2 = snap if typeof(snap) == TYPE_VECTOR2 else snap.get("pos", current_player.global_position)
				spots.append(pos)
			else:
				var oldest_snap = history[0]
				var pos: Vector2 = oldest_snap if typeof(oldest_snap) == TYPE_VECTOR2 else oldest_snap.get("pos", current_player.global_position)
				spots.append(pos)
				
		return spots
		
	return _get_procedural_party_positions(count)


func rebuild_snake_history() -> void:
	var player = GameManager.current_player
	if not player or followers.is_empty():
		return

	var key_points: Array[Node2D] = [player]
	for f in followers:
		key_points.append(f)
	
	if player.has_method("clear_movement_history"):
		player.clear_movement_history()
	
	var spacing: int = 16
	if followers[0].get("spacing_steps"):
		spacing = followers[0].spacing_steps

	for i in range(key_points.size() - 1, 0, -1):
		var start_node = key_points[i]
		var end_node = key_points[i - 1]
		
		var start_pos = start_node.global_position
		var end_pos = end_node.global_position
		
		var segment_dir = _get_direction_from_vector(end_pos - start_pos)
		
		var cached_dir = start_node.current_direction
		start_node.current_direction = segment_dir
		if start_node.has_method("run_animation"):
			start_node.current_animation = "walk"
			start_node.run_animation()
			
		var segment_rect = start_node.get_body_region_rect()
		
		var segment_flip = false
		if "flip_h" in start_node:
			segment_flip = start_node.flip_h
		elif start_node.has_node("Sprite2D"):
			segment_flip = start_node.get_node("Sprite2D").flip_h
			
		start_node.current_direction = cached_dir
		start_node.current_animation = "idle"
		if start_node.has_method("run_animation"):
			start_node.run_animation()
		
		for step in range(spacing):
			var t = float(step) / float(spacing)
			var interp_pos = start_pos.lerp(end_pos, t)
			
			var fake_snap = {
				"pos": interp_pos,
				"direction": segment_dir,
				"scale": Vector2.ONE,
				"z_index": player.z_index,
				"modulate": Color.WHITE,
				"region_rect": segment_rect,
				"flip_h": segment_flip,
				"rotation": player.rotation
			}
			
			player.movement_history.push_back(fake_snap)

	if player.has_method("_smart_record_history"):
		player._smart_record_history()


func _get_direction_from_vector(vec: Vector2) -> int:
	if abs(vec.x) > abs(vec.y):
		return CharacterBase.DIRECTIONS.RIGHT if vec.x > 0 else CharacterBase.DIRECTIONS.LEFT
	else:
		return CharacterBase.DIRECTIONS.DOWN if vec.y > 0 else CharacterBase.DIRECTIONS.UP


func appear(instant: bool = false) -> void:
	if followers.is_empty():
		return
		
	if instant:
		for f in followers:
			f.modulate.a = 1.0
			f.is_sync_active = true
			f.is_invalid_event = false
			f.is_fading_transition = false
		return
		
	var tween = create_tween().set_parallel(true)
	var needs_tween = false
	
	for f in followers:
		f.is_sync_active = true
		f.is_invalid_event = false
		f.is_fading_transition = true
		
		if not is_equal_approx(f.modulate.a, 1.0):
			tween.tween_property(f, "modulate:a", 1.0, 0.3)
			needs_tween = true
			
	if needs_tween:
		await tween.finished
	else:
		tween.kill()
		
	for f in followers:
		f.is_fading_transition = false



func disappear(instant: bool = false, delete_after: bool = false) -> void:
	if followers.is_empty():
		if delete_after:
			destroy()
		return
		
	if instant:
		for f in followers:
			f.modulate.a = 0.0
			f.is_sync_active = false
			f.is_invalid_event = true
			f.is_fading_transition = false
		if delete_after:
			destroy()
		return
		
	var tween = create_tween().set_parallel(true)
	var needs_tween = false
	
	for f in followers:
		f.is_sync_active = true
		f.is_invalid_event = false
		f.is_fading_transition = true
		
		if not is_equal_approx(f.modulate.a, 0.0):
			tween.tween_property(f, "modulate:a", 0.0, 0.3)
			needs_tween = true
			
	if needs_tween:
		await tween.finished
	else:
		tween.kill()
		
	for f in followers:
		f.is_fading_transition = false
		if not delete_after:
			f.is_sync_active = false
			f.is_invalid_event = true
		
	if delete_after:
		destroy()



func destroy() -> void:
	for f in followers:
		if is_instance_valid(f):
			f.queue_free()
	followers.clear()



func _get_procedural_party_positions(count: int) -> Array[Vector2]:
	var spots: Array[Vector2] = []
	var map = GameManager.current_map
	var current_player = GameManager.current_player
	
	if not map or not current_player:
		for i in range(count): spots.append(Vector2.ZERO)
		return spots
	
	var visited_tiles: Array[Vector2i] = []
	var current_center_tile = map.get_tile_from_position(current_player.global_position)
	visited_tiles.append(current_center_tile)

	for i in range(count):
		var adjacent_directions = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
		adjacent_directions.shuffle()
		
		var found_spot = false
		for dir in adjacent_directions:
			var target_tile = Vector2i(current_center_tile + dir)
			
			if not target_tile in visited_tiles and map.is_passable(target_tile, 0, current_player):
				var world_pos = map.get_tile_position(target_tile)
				spots.append(world_pos)
				visited_tiles.append(target_tile)
				current_center_tile = target_tile
				found_spot = true
				break
		
		if not found_spot:
			var fallback_pos = spots[-1] if not spots.is_empty() else current_player.global_position
			spots.append(fallback_pos)

	return spots



func disable_split_mode(time: float) -> void:
	if _is_transitioning: return
	
	var game_state = GameManager.game_state
	if not game_state or not game_state.followers_enabled:
		return
		
	var current_player = GameManager.current_player
	if not current_player or followers.is_empty():
		game_state.followers_tracking_enabled = true
		return
		
	_is_transitioning = true
	
	var target_spots = _get_procedural_party_positions(followers.size())
	
	var fade_out_tween = create_tween().set_parallel(true)
	for f in followers:
		f.is_sync_active = false
		fade_out_tween.tween_property(f, "modulate:a", 0.0, time / 2.0)
		
	await fade_out_tween.finished
	
	for i in range(followers.size()):
		var f = followers[i]
		f.global_position = target_spots[i]
		
		if "current_direction" in f and "current_direction" in current_player:
			f.current_direction = current_player.current_direction
			
		if f.has_method("run_animation"):
			f.current_animation = "idle"
			f.run_animation()
	
	rebuild_snake_history()
	
	for f in followers:
		f._extra_history_offset_f = 0.0 
		f._is_waiting = false
		f.is_sync_active = true
		if f.has_method("_initialize_queue"):
			f._initialize_queue()
	
	var fade_in_tween = create_tween().set_parallel(true)
	for f in followers:
		fade_in_tween.tween_property(f, "modulate:a", 1.0, time / 2.0)
		
	await fade_in_tween.finished
	
	game_state.followers_tracking_enabled = true
	_is_transitioning = false


func change_leader_to(direction: String) -> void:
	if _is_transitioning: return
	
	if not GameManager.game_state or not GameManager.game_state.followers_enabled or GameManager.get_followers().size() == 0:
		return

	var party: Array = GameManager.game_state.current_party
	var active_max: int = RPGSYSTEM.database.system.party_active_members
	var active_count: int = min(party.size(), active_max)

	if active_count <= 1:
		return

	var active_party: Array = party.slice(0, active_count)
	var reserve_party: Array = party.slice(active_count, party.size())
	
	var is_split_mode_enabled: bool = !GameManager.game_state.followers_tracking_enabled
	var camera: Camera2D = GameManager.get_camera()

	if is_split_mode_enabled:
		var current_player = GameManager.current_player
		var target_follower: Node2D = null
		
		if direction == "up":
			target_follower = followers.back()
		else:
			target_follower = followers.front()
			
		if current_player and target_follower:
			_is_transitioning = true
			
			var viewport_img = get_viewport().get_texture().get_image()
			var static_tex = ImageTexture.create_from_image(viewport_img)
			var overlay_canvas = CanvasLayer.new()
			overlay_canvas.layer = 128
			
			var overlay_rect = TextureRect.new()
			overlay_rect.texture = static_tex
			overlay_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
			overlay_canvas.add_child(overlay_rect)
			get_tree().root.add_child(overlay_canvas)
			
			await get_tree().process_frame
			
			for f in followers:
				f.is_sync_active = false
			
			var is_grid_mode: bool = false
			if "movement_current_mode" in current_player:
				is_grid_mode = (current_player.movement_current_mode == CharacterBase.MOVEMENTMODE.GRID)
				
			var new_player_pos = target_follower.global_position
			var new_follower_pos = current_player.global_position
				
			if is_grid_mode:
				var current_map = GameManager.current_map
				if current_map:
					var p_tile = current_map.get_tile_from_position(current_player.global_position)
					new_follower_pos = current_map.get_tile_position(p_tile)
					
					var f_tile = current_map.get_tile_from_position(target_follower.global_position)
					new_player_pos = current_map.get_tile_position(f_tile)
					
			var target_player_dir = target_follower.current_direction
			var target_follower_dir = current_player.current_direction

			if direction == "up":
				var last_actor = active_party.pop_back()
				active_party.push_front(last_actor)
				if followers.size() > 0:
					var last_follower = followers.pop_back()
					followers.push_front(last_follower)
			else:
				var first_actor = active_party.pop_front()
				active_party.push_back(first_actor)
				if followers.size() > 0:
					var first_follower = followers.pop_front()
					followers.push_back(first_follower)

			GameManager.game_state.current_party = active_party + reserve_party

			for f in followers:
				if "current_direction" in f:
					f.fixed_direction = f.current_direction

			await update_party_visuals(true)

			current_player.global_position = new_player_pos
			target_follower.global_position = new_follower_pos
			
			current_player.current_direction = target_player_dir
			if "last_direction" in current_player:
				current_player.last_direction = target_player_dir
				
			target_follower.current_direction = target_follower_dir
			target_follower.fixed_direction = target_follower_dir
			
			if current_player.has_method("force_update_transform"):
				current_player.force_update_transform()
			if target_follower.has_method("force_update_transform"):
				target_follower.force_update_transform()
				
			if current_player.has_method("reset_physics_interpolation"):
				current_player.reset_physics_interpolation()
			if target_follower.has_method("reset_physics_interpolation"):
				target_follower.reset_physics_interpolation()
				
			if current_player.has_method("clear_movement_history"):
				current_player.clear_movement_history()
				
			if current_player.has_method("initialize_virtual_tile"):
				current_player.initialize_virtual_tile()
			if target_follower.has_method("initialize_virtual_tile"):
				target_follower.initialize_virtual_tile()
				
			if current_player.has_method("run_animation"):
				current_player.run_animation(true)
			if target_follower.has_method("run_animation"):
				target_follower.run_animation()
				
			current_player.modulate.a = 1.0
			for f in followers:
				f.modulate.a = 1.0
				f.fixed_direction = -1
				f.is_sync_active = true
				
			if camera and camera.has_method("scroll_to_position"):
				var cam_data = camera.get_target_position_and_zoom()
				camera.scroll_to_position(cam_data.position, cam_data.zoom, 0.3)
				
			await get_tree().process_frame
			await get_tree().process_frame
			await get_tree().process_frame
			
			if is_instance_valid(overlay_canvas):
				overlay_canvas.queue_free()
				
			_is_transitioning = false
				
	else:
		if direction == "up":
			var last_member = active_party.pop_back()
			active_party.push_front(last_member)
		else:
			var first_member = active_party.pop_front()
			active_party.push_back(first_member)

		GameManager.game_state.current_party = active_party + reserve_party
		
		await update_party_visuals(true)


func regroup(time: float = 0.6, delete_followers: bool = false) -> void:
	var game_state = GameManager.game_state
	if game_state:
		game_state.followers_enabled = false
		
	if followers.is_empty(): return
	
	var tween = create_tween().set_parallel(true)
	var target_pos = GameManager.current_player.global_position if GameManager.current_player else Vector2.ZERO
	
	for f in followers:
		f.is_invalid_event = true
		tween.tween_property(f, "global_position", target_pos, time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		if delete_followers:
			tween.tween_property(f, "modulate:a", 0.0, time * 0.95)
		
	await tween.finished
	
	if delete_followers:
		destroy()
	else:
		for f in followers:
			f.modulate.a = 0.0
			f.is_invalid_event = true
	
	if GameManager.current_player and delete_followers:
		GameManager.current_player.clear_movement_history()
#endregion
