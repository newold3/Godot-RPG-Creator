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
				current_player.add_to_group("player")
				
		if not current_player:
			current_player = preload("uid://bfh5umy1vx2y3").instantiate()
			current_player.name = "Player_Empty"
			current_player.set_meta("actor_id", player_id)
			current_player.set_meta("party_id", 0)
			current_player.add_to_group("player")
			GameManager.get_main_scene().get_main_camera().set_target(current_player)
			
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


## Configures movement modes and binds the player to the camera. Prevents crash on empty party.
func _setup_player_properties() -> void:
	var current_player = GameManager.current_player
	var game_state = GameManager.game_state
	var current_map = GameManager.current_map
	var main_camera = GameManager.main_scene.get_main_camera()
	
	main_camera.add_target_to_array(current_player, 10)
	main_camera.fast_reposition.call_deferred()
	
	var first_actor = game_state.current_party[0] if not game_state.current_party.is_empty() else 0
	current_player.set_meta("actor_id", first_actor)
	current_player.set_meta("party_id", 0)
	
	if "movement_current_mode" in current_player:
		match RPGSYSTEM.database.system.movement_mode:
			0: current_player.movement_current_mode = CharacterBase.MOVEMENTMODE.GRID
			1: current_player.movement_current_mode = CharacterBase.MOVEMENTMODE.FREE
		
	if GameManager.main_scene.is_test_map and current_map:
		current_player.current_map_tile_size = current_map.tile_size
		current_player.calculate_grid_move_duration()
#endregion



#region Followers Core
func show_followers(instant: bool = false, force_regroup: bool = true) -> void:
	var game_state = GameManager.game_state
	var player = GameManager.current_player
	
	if not game_state or not player:
		return
		
	game_state.followers_enabled = true

	if game_state.followers_tracking_enabled and force_regroup:
		if player.has_method("clear_movement_history"):
			player.clear_movement_history()

	_refresh_follower_nodes(instant)
	await update_party_visuals(instant)
	
	if game_state.current_party.size() <= 1:
		return
	
	if game_state.followers_tracking_enabled:
		if force_regroup:
			for f in followers:
				f.global_position = player.global_position
				f.current_direction = player.current_direction
				if f.has_method("run_animation"):
					f.current_animation = "idle"
					f.run_animation()
				
	var is_tracking = game_state.followers_tracking_enabled
	for f in followers:
		f.is_sync_active = is_tracking
		if f.has_method("_initialize_queue") and is_tracking:
			f._initialize_queue()
			
	await appear(instant)


func load_followers_from_save(save_data: Dictionary) -> void:
	destroy()
	
	var list = save_data.get("follower_list", [])
	if list.is_empty() or not save_data.get("enabled", false):
		return
		
	_refresh_follower_nodes(true, list)
	await update_party_visuals(true)
	
	var game_state = GameManager.game_state
	var is_split = !game_state.followers_tracking_enabled
	var player = GameManager.current_player
	
	if not is_split and player:
		if player.has_method("clear_movement_history"):
			player.clear_movement_history()
		for f in followers:
			f.global_position = player.global_position
		
	for f in followers:
		f.is_sync_active = !is_split
		if f.has_method("_initialize_queue") and !is_split:
			f._initialize_queue()
			
	appear(true)


func update_party_visuals(instant: bool = false) -> void:
	var game_state = GameManager.game_state
	if not game_state:
		return
		
	var party = game_state.current_party
	var current_player = GameManager.current_player
	
	if current_player:
		if party.is_empty():
			current_player.visible = false
			current_player.set_meta("actor_id", 0)
			current_player.set_meta("party_id", 0)
		else:
			current_player.visible = true
			var leader_actor = RPGSYSTEM.database.actors[party[0]]
			var cached_dir = current_player.current_direction
			var cached_last_dir = current_player.get("last_direction")
			
			if current_player.get_meta("actor_id", -1) != party[0] or current_player.name == "Player_Empty":
				if leader_actor and leader_actor.get("character_data_file"):
					current_player.set_data(load(leader_actor.character_data_file))
					current_player.name = "Player_" + leader_actor.name
				
			current_player.set_meta("actor_id", party[0])
			current_player.set_meta("party_id", 0)
			current_player.current_direction = cached_dir
			
			if cached_last_dir != null:
				current_player.last_direction = cached_last_dir
				
			if current_player.has_method("run_animation"):
				current_player.run_animation(true)
			
	var old_size = followers.size()
	_refresh_follower_nodes(instant)
	
	for i in range(1, party.size()):
		var f_idx = i - 1
		if f_idx < followers.size():
			var follower = followers[f_idx]
			var target_actor_id = party[i]
			
			var body = follower.get_node_or_null("%Body")
			var is_naked = body.texture == null if body else true
			var actor_changed = follower.get_meta("actor_id", -1) != target_actor_id
			
			if f_idx >= old_size or actor_changed or is_naked:
				await follower.update_appearance_cascade(target_actor_id, instant)
				follower.set_meta("actor_id", target_actor_id)


func _refresh_follower_nodes(instant: bool = false, save_data_list: Array = []) -> void:
	var current_map = GameManager.current_map
	var current_player = GameManager.current_player
	var game_state = GameManager.game_state
	
	if not current_map or not current_player: return
	
	followers = followers.filter(func(f): return is_instance_valid(f))
	
	var max_active = RPGSYSTEM.database.system.party_active_members
	
	# Calculamos los necesarios, blindando que NUNCA sea negativo si la party es 1 o 0
	var needed = 0
	if game_state.current_party.size() > 1:
		needed = min(game_state.current_party.size() - 1, max_active - 1)
	
	var insert_idx = current_player.get_index()
	var is_loading = not save_data_list.is_empty()
	
	if followers.size() < needed:
		while followers.size() < needed:
			var f_idx = followers.size()
			var f = FOLLOWER_SCENE.instantiate() as SimpleFollower
			
			f.set_meta("actor_id", game_state.current_party[f_idx + 1])
			f.set_meta("party_id", f_idx + 1)
			f.follower_id = f_idx + 1
			f.z_index = current_player.z_index
			f.visible = true
			f.is_sync_active = false
			
			@warning_ignore("incompatible_ternary")
			var target = current_player if f_idx == 0 else followers[f_idx - 1]
			f.target_node = target
			
			current_map.add_child(f)
			current_map.move_child(f, insert_idx)
			
			if is_loading and f_idx < save_data_list.size():
				var s_data = save_data_list[f_idx]
				f.global_position = s_data.get("position", current_player.global_position)
				f.current_direction = s_data.get("direction", 8)
				f.modulate.a = 1.0
			else:
				var spawn_pos = current_player.global_position
				var spawn_dir = current_player.current_direction
				if "movement_history" in current_player and not current_player.movement_history.is_empty():
					var oldest_snap = current_player.movement_history[0]
					spawn_pos = oldest_snap.get("pos", spawn_pos)
					spawn_dir = oldest_snap.get("direction", spawn_dir)
					
				f.global_position = spawn_pos
				f.current_direction = spawn_dir
				f.modulate.a = 1.0 if instant else 0.0
			
			f.current_animation = "idle"
			f.is_fading_transition = not (instant or is_loading)
			
			if f.has_method("run_animation"):
				f.run_animation()
				
			followers.append(f)
			f.set_meta("requires_init", true)
			
	# Borrado de seguidores sobrantes garantizado
	while followers.size() > needed:
		var f = followers.pop_back()
		if is_instance_valid(f): f.queue_free()
#endregion



#region Visual Transitions
func appear(instant: bool = false) -> void:
	if followers.is_empty():
		return
		
	if instant:
		for f in followers:
			f.modulate.a = 1.0
			f.is_fading_transition = false
		return
		
	var tween = create_tween().set_parallel(true)
	var needs_tween = false
	
	for f in followers:
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
		if delete_after: destroy()
		return
		
	if instant:
		for f in followers:
			f.modulate.a = 0.0
			f.is_sync_active = false
			f.is_fading_transition = false
		if delete_after: destroy()
		return
		
	var tween = create_tween().set_parallel(true)
	var needs_tween = false
	
	for f in followers:
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
			
	if delete_after:
		destroy()


func destroy() -> void:
	for f in followers:
		if is_instance_valid(f): f.queue_free()
	followers.clear()
#endregion



#region Mode Switches
func disable_split_mode(time: float) -> void:
	if _is_transitioning: return
	
	var game_state = GameManager.game_state
	if not game_state or not game_state.followers_enabled:
		return
		
	var player = GameManager.current_player
	if not player or followers.is_empty():
		game_state.followers_tracking_enabled = true
		return
		
	_is_transitioning = true
	
	var fade_out_tween = create_tween().set_parallel(true)
	for f in followers:
		f.is_sync_active = false
		fade_out_tween.tween_property(f, "modulate:a", 0.0, time / 2.0)
	await fade_out_tween.finished
	
	if player.has_method("clear_movement_history"):
		player.clear_movement_history()
		
	for f in followers:
		f.global_position = player.global_position
		f.current_direction = player.current_direction
		if f.has_method("run_animation"):
			f.current_animation = "idle"
			f.run_animation()
	
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

	if active_count <= 1: return

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
