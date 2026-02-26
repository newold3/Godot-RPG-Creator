class_name PartyManager
extends Node


## The packed scene used to instantiate new followers.
const FOLLOWER_SCENE = preload("uid://pbm7vnwv6qll")

## Active follower instances currently in the map.
var followers: Array[SimpleFollower] = []



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
		current_player.set_meta("actor_id", party[0])
		current_player.set_meta("party_id", 0)
		current_player.set_data(load(leader_actor.character_data_file))
		current_player.name = "Player_" + leader_actor.name
		
	_refresh_follower_nodes(instant)
	
	for i in range(1, party.size()):
		if (i - 1) < followers.size():
			var follower = followers[i - 1]
			follower.update_appearance_cascade(party[i], instant)



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
			var f = FOLLOWER_SCENE.instantiate() as SimpleFollower
			
			f.modulate.a = 1.0 if instant else 0.0
			f.is_sync_active = true
			f.is_invalid_event = false
			f.is_fading_transition = not instant
			
			current_map.add_child(f)
			current_map.move_child(f, insert_idx)
			
			f.global_position = start_spots[followers.size()]
			
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
		
		var expected_target = current_player if i == 0 else followers[i-1]
		var target_changed = followers[i].get("target_node") != expected_target
		
		followers[i].target_node = expected_target
		
		if followers[i].get_meta("requires_init", false) or target_changed:
			if followers[i].has_method("_initialize_queue"):
				followers[i]._initialize_queue()
			followers[i].set_meta("requires_init", false)
			
		if followers[i].has_method("_update_facing_direction"):
			followers[i]._update_facing_direction()



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



func change_leader_to(direction: String) -> void:
	if not GameManager.game_state or not GameManager.game_state.followers_enabled:
		return

	var party: Array = GameManager.game_state.current_party
	var active_max: int = RPGSYSTEM.database.system.party_active_members
	var active_count: int = min(party.size(), active_max)

	if active_count <= 1:
		return

	var active_party: Array = party.slice(0, active_count)
	var reserve_party: Array = party.slice(active_count, party.size())
	
	var target_party_id: int

	if direction == "up":
		var last_member = active_party.pop_back()
		active_party.push_front(last_member)
		target_party_id = active_party[0]
	else:
		var first_member = active_party.pop_front()
		active_party.push_back(first_member)
		target_party_id = active_party[active_party.size() - 1]

	GameManager.game_state.current_party = active_party + reserve_party
	
	var is_split_mode_enabled: bool = !GameManager.game_state.followers_tracking_enabled
	
	if is_split_mode_enabled:
		var actor1 = GameManager.current_player
		var actor2
		var current_followers = GameManager.get_followers()
		for follower in current_followers:
			if follower.get_meta("party_id") == target_party_id:
				actor2 = follower
				
		if actor1 and actor2:
			var p = actor1.global_position
			actor1.global_position = actor2.global_position
			actor2.global_position = p
		
			if actor1.has_method("clear_movement_history"):
				actor1.clear_movement_history()
		
	update_party_visuals(true)



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
