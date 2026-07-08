class_name PartyManager
extends Node

#region Constants & Variables
## The packed scene used to instantiate new followers.
const FOLLOWER_SCENE = preload("uid://pbm7vnwv6qll")

## Active follower instances currently in the map.
var followers: Array[SimpleFollower] = []

## Lock to prevent overlapping visual transitions causing visual glitches.
var _is_transitioning: bool = false

## Cache for unused player nodes to prevent instantiation lag.
var _player_cache: Dictionary = {}

## Cache for unused follower nodes to prevent instantiation lag.
var _follower_cache: Array[SimpleFollower] = []
#endregion



#region Cache Management
## Stores a player node in the cache, disabling its processing, visibility, and removing it from the player group.
func _store_player_in_cache(actor_id: Variant, player_node: Node2D) -> void:
	if not is_instance_valid(player_node):
		return
		
	if _player_cache.size() >= RPGSYSTEM.database.system.party_active_members and not _player_cache.has(actor_id):
		var keys = _player_cache.keys()
		var old_node = _player_cache[keys[0]]
		if is_instance_valid(old_node):
			old_node.queue_free()
		_player_cache.erase(keys[0])
		
	player_node.process_mode = Node.PROCESS_MODE_DISABLED
	player_node.visible = false
	if player_node.is_in_group("player"):
		player_node.remove_from_group("player")
	_player_cache[actor_id] = player_node



## Retrieves a player node from the cache or instantiates a new one if not found.
func _get_player_from_cache(actor_id: Variant, scene_path: String) -> Node2D:
	if _player_cache.has(actor_id):
		var cached_node = _player_cache[actor_id]
		if is_instance_valid(cached_node):
			cached_node.process_mode = Node.PROCESS_MODE_INHERIT
			_player_cache.erase(actor_id)
			return cached_node
		else:
			_player_cache.erase(actor_id)
			
	if AssetManager.exists(scene_path):
		return load(scene_path).instantiate()
		
	return null



## Cleans invalid nodes from the caches, typically called on map changes.
func clear_caches() -> void:
	for id in _player_cache:
		var node = _player_cache[id]
		if is_instance_valid(node):
			node.queue_free()
			
	_player_cache.clear()
	
	for f in _follower_cache:
		if is_instance_valid(f):
			f.queue_free()
			
	_follower_cache.clear()
#endregion



#region Player Operations
## Safely adds an actor to the party supporting both legacy IDs and UIDs
func add_actor_to_party(actor_id: int) -> void:
	var game_state = GameManager.game_state
	var uid = actor_id
	
	if uid > 0 and uid < 1000000:
		uid = RPGSYSTEM.id_to_uid("actors", uid)
		
	var actor_data = RPGSYSTEM.get_data("actors", uid)
	
	if actor_data:
		if !game_state.actors.has(uid):
			var actor = GameActor.new(uid)
			game_state.actors[uid] = actor
			
		if !game_state.current_party.has(uid):
			game_state.current_party.append(uid)



## Removes an actor from the active party array using UIDs
func remove_actor_from_party(remove_actor_id: int) -> void:
	var game_state = GameManager.game_state
	var uid = remove_actor_id
	
	if uid > 0 and uid < 1000000:
		uid = RPGSYSTEM.id_to_uid("actors", uid)
		
	var index = game_state.current_party.find(uid)
	if index != -1:
		game_state.current_party.remove_at(index)



## Destroys the current active player visuals and clears the local caches
func clear_current_player() -> void:
	var container = GameManager.main_scene.get_node_or_null("%PlayerContainer")
	if container:
		for player in container.get_children():
			player.queue_free()
	clear_caches()



## Orchestrates the instantiation, positioning and configuration of the player entity
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



## Handles the core instantiation of the player fetching the proper UID scene
func _create_or_reuse_player() -> void:
	var current_player = GameManager.current_player
	
	if GameManager.loading_game and current_player and is_instance_valid(current_player):
		current_player.queue_free()
		current_player = null
		
	if (not current_player or not is_instance_valid(current_player)) and GameManager.game_state:
		var player_id = GameManager.game_state.current_party[0] if not GameManager.game_state.current_party.is_empty() else 0
		
		# UID translation layer
		if player_id > 0 and player_id < 1000000:
			player_id = RPGSYSTEM.id_to_uid("actors", player_id)
			GameManager.game_state.current_party[0] = player_id
			
		var actor = RPGSYSTEM.get_data("actors", player_id) if player_id > 0 else null
		
		if actor:
			var scene_path = actor.character_scene
			current_player = _get_player_from_cache(player_id, scene_path)
			if current_player:
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



## Places the player in the correct map coordinates based on the save file
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



## Configures movement modes and binds the player to the camera.
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
## Spawns the party followers mapping to the active leader coordinates
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



## Loads and displays the specific positions and status of the followers from a save file
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



## Propagates visual traits down the follower cascade updating sprites
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
			var leader_id = party[0]
			
			if leader_id > 0 and leader_id < 1000000:
				leader_id = RPGSYSTEM.id_to_uid("actors", leader_id)
				party[0] = leader_id
				
			var leader_actor = RPGSYSTEM.get_data("actors", leader_id) if leader_id > 0 else null
			var cached_dir = current_player.current_direction
			var cached_last_dir = current_player.get("last_direction")
			var cached_pos = current_player.global_position
			
			if current_player.get_meta("actor_id", -1) != leader_id or current_player.name == "Player_Empty":
				if leader_actor and leader_actor.get("character_scene"):
					var new_player = _get_player_from_cache(leader_id, leader_actor.character_scene)
					if new_player:
						new_player.visible = false
						var parent = current_player.get_parent()
						var index = current_player.get_index()
						
						if not new_player.is_inside_tree():
							parent.add_child(new_player)
							parent.move_child(new_player, index)
						elif new_player.get_parent() != parent:
							new_player.get_parent().remove_child(new_player)
							parent.add_child(new_player)
							parent.move_child(new_player, index)
							
						new_player.global_position = cached_pos
						new_player.current_direction = cached_dir
						if cached_last_dir != null:
							new_player.last_direction = cached_last_dir
							
						var props_to_transfer = [
							"movement_current_mode", "current_map_tile_size", "previous_tile",
							"is_running", "map_offset", "cumulative_steps", "is_on_vehicle", 
							"current_vehicle", "current_virtual_tile", "collision_disabled", 
							"force_locked", "busy", "busy2", "_auto_target_tile", "_auto_target_event"
						]
						
						for prop in props_to_transfer:
							if prop in current_player and prop in new_player:
								new_player.set(prop, current_player.get(prop))
								
						if "movement_history" in current_player and "movement_history" in new_player:
							new_player.movement_history = current_player.movement_history.duplicate(true)
							
						if leader_actor.get("character_data_file") and new_player.has_method("set_data"):
							new_player.set_data(load(leader_actor.character_data_file))
							
						new_player.name = "Player_" + leader_actor.name
						if not new_player.is_in_group("player"):
							new_player.add_to_group("player")
							
						if new_player.has_method("initialize_virtual_tile"):
							new_player.initialize_virtual_tile()
						if new_player.has_method("calculate_grid_move_duration"):
							new_player.calculate_grid_move_duration()
							
						if new_player.has_method("force_update_transform"):
							new_player.force_update_transform()
						if new_player.has_method("reset_physics_interpolation"):
							new_player.reset_physics_interpolation()
							
						new_player.visible = true
						GameManager.current_player = new_player
						
						var main_camera = GameManager.main_scene.get_main_camera()
						var is_cam_target = false
						
						if main_camera:
							if main_camera.get("target") == current_player or (main_camera.has_method("has_target") and main_camera.has_target(current_player)):
								is_cam_target = true
								
						if is_cam_target:
							if main_camera.has_method("add_target_to_array"):
								main_camera.add_target_to_array(new_player, 10)
							if "target" in main_camera and main_camera.get("target") == current_player:
								main_camera.target = new_player
							if main_camera.has_method("remove_target_from_array"):
								main_camera.remove_target_from_array(current_player)
								
						if followers.size() > 0:
							followers[0].target_node = new_player
							
						current_player.visible = false
						_store_player_in_cache(current_player.get_meta("actor_id", -1), current_player)
						current_player = new_player
						
			elif leader_actor and leader_actor.get("character_data_file") and current_player.has_method("set_data"):
				current_player.set_data(load(leader_actor.character_data_file))
				current_player.name = "Player_" + leader_actor.name
				current_player.visible = true
				
			current_player.set_meta("actor_id", leader_id)
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
			
			if target_actor_id > 0 and target_actor_id < 1000000:
				target_actor_id = RPGSYSTEM.id_to_uid("actors", target_actor_id)
				party[i] = target_actor_id
				
			if follower.get_meta("actor_id", -1) != target_actor_id or follower.get_meta("requires_init", false):
				follower.visible = false
				
	for i in range(1, party.size()):
		var f_idx = i - 1
		if f_idx < followers.size():
			var follower = followers[f_idx]
			var target_actor_id = party[i]
			
			var body = follower.get_node_or_null("%Body")
			var is_naked = body.texture == null if body else true
			var actor_changed = follower.get_meta("actor_id", -1) != target_actor_id
			var requires_init = follower.get_meta("requires_init", false)
			
			if f_idx >= old_size or actor_changed or is_naked or requires_init:
				follower.visible = false
				follower.set_meta("actor_id", target_actor_id)
				await follower.update_appearance_cascade(target_actor_id, instant)
				follower.set_meta("requires_init", false)
				
			follower.visible = true



## Adds or hides followers to match the target party size limits
func _refresh_follower_nodes(instant: bool = false, save_data_list: Array = []) -> void:
	var current_map = GameManager.current_map
	var current_player = GameManager.current_player
	var game_state = GameManager.game_state
	
	if not current_map or not current_player: return
	
	followers = followers.filter(func(f): return is_instance_valid(f))
	
	var max_active = RPGSYSTEM.database.system.party_active_members
	var needed = 0
	
	if game_state.current_party.size() > 1:
		needed = min(game_state.current_party.size() - 1, max_active - 1)
		
	var insert_idx = current_player.get_index()
	var is_loading = not save_data_list.is_empty()
	
	if followers.size() < needed:
		while followers.size() < needed:
			var f_idx = followers.size()
			var f: SimpleFollower = null
			
			while _follower_cache.size() > 0 and not is_instance_valid(f):
				f = _follower_cache.pop_back()
				
			if not is_instance_valid(f):
				f = FOLLOWER_SCENE.instantiate() as SimpleFollower
				
			f.process_mode = Node.PROCESS_MODE_INHERIT
			if not f.is_in_group("follower"):
				f.add_to_group("follower")
				
			var f_actor_id = game_state.current_party[f_idx + 1]
			if f_actor_id > 0 and f_actor_id < 1000000:
				f_actor_id = RPGSYSTEM.id_to_uid("actors", f_actor_id)
				game_state.current_party[f_idx + 1] = f_actor_id
				
			f.set_meta("actor_id", f_actor_id)
			f.set_meta("party_id", f_idx + 1)
			f.follower_id = f_idx + 1
			f.z_index = current_player.z_index
			f.visible = true
			f.is_sync_active = false
			
			@warning_ignore("incompatible_ternary")
			var target = current_player if f_idx == 0 else followers[f_idx - 1]
			f.target_node = target
			
			if not f.is_inside_tree():
				current_map.add_child(f)
				current_map.move_child(f, insert_idx)
			elif f.get_parent() != current_map:
				f.get_parent().remove_child(f)
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
			
	while followers.size() > needed:
		var f = followers.pop_back()
		if is_instance_valid(f):
			f.process_mode = Node.PROCESS_MODE_DISABLED
			f.visible = false
			if f.is_in_group("follower"):
				f.remove_from_group("follower")
			_follower_cache.append(f)
#endregion



#region Visual Transitions
## Smoothly fades followers onto the screen
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



## Smoothly fades followers out of the screen
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
	tween.tween_interval(0.0)
	var needs_tween = false
	
	for f in followers:
		if not is_instance_valid(f): return
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



## Hard removes all instances of followers adding them to the cache
func destroy() -> void:
	for f in followers:
		if is_instance_valid(f):
			f.process_mode = Node.PROCESS_MODE_DISABLED
			f.visible = false
			if f.is_in_group("follower"):
				f.remove_from_group("follower")
			_follower_cache.append(f)
	followers.clear()
#endregion



#region Mode Switches
## Ends the split party mode and recalls followers to the player
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
		if not is_instance_valid(f): return
		f.is_sync_active = false
		fade_out_tween.tween_property(f, "modulate:a", 0.0, time / 2.0)
	await fade_out_tween.finished
	
	if player.has_method("clear_movement_history"):
		player.clear_movement_history()
		
	for f in followers:
		if not is_instance_valid(f): return
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



## Cycles the visible leader of the party swapping with followers
func change_leader_to(direction: String) -> void:
	if _is_transitioning: return
	
	if not GameManager.game_state or not GameManager.game_state.followers_enabled or GameManager.get_followers().size() == 0:
		return
		
	var party: Array = GameManager.game_state.current_party
	var active_max: int = RPGSYSTEM.database.system.party_active_members
	var active_count: int = min(party.size(), active_max)
	
	if active_count <= 1: return
	
	_is_transitioning = true
	
	var active_party: Array = party.slice(0, active_count)
	var reserve_party: Array = party.slice(active_count, party.size())
	
	var is_split_mode_enabled: bool = !GameManager.game_state.followers_tracking_enabled
	
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
	
	if is_split_mode_enabled:
		var current_player = GameManager.current_player
		var target_follower: Node2D = null
		
		if direction == "up":
			target_follower = followers.back()
		else:
			target_follower = followers.front()
			
		if current_player and target_follower:
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
			
			current_player = GameManager.current_player
			
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
				
	else:
		if direction == "up":
			var last_member = active_party.pop_back()
			active_party.push_front(last_member)
		else:
			var first_member = active_party.pop_front()
			active_party.push_back(first_member)
			
		GameManager.game_state.current_party = active_party + reserve_party
		
		await update_party_visuals(true)
		
	await get_tree().process_frame
	
	if is_instance_valid(overlay_canvas):
		overlay_canvas.queue_free()
		
	_is_transitioning = false



## Forces followers to pathfind to the player location
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
