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
		
	# Only evict actors from cache who are completely removed from the current party
	var active_party = GameManager.game_state.current_party if GameManager.game_state else []
	for cached_id in _player_cache.keys():
		if not active_party.has(cached_id) and cached_id != actor_id:
			var old_node = _player_cache[cached_id]
			if is_instance_valid(old_node):
				old_node.queue_free()
			_player_cache.erase(cached_id)
		
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
	
	var escort_count = game_state.escorted_npcs.size() if ("escorted_npcs" in game_state and game_state.escorted_npcs is Array) else 0
	if game_state.current_party.size() <= 1 and escort_count == 0:
		return
		
	if game_state.followers_tracking_enabled:
		if force_regroup:
			for f in followers:
				if f.get("is_joining_queue"):
					continue
				f.global_position = player.global_position
				f.current_direction = player.current_direction
				if f.has_method("run_animation"):
					f.current_animation = "idle"
					f.run_animation()
					
	var is_tracking = game_state.followers_tracking_enabled
	for f in followers:
		if f.get("is_joining_queue"):
			continue
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
							"force_locked", "busy", "busy2", "_auto_target_tile", "_auto_target_event",
							"_last_recorded_pos", "_last_recorded_scale"
						]
						
						for prop in props_to_transfer:
							if prop in current_player and prop in new_player:
								new_player.set(prop, current_player.get(prop))
								
						if new_player.get("_last_recorded_pos") == Vector2.ZERO:
							new_player.set("_last_recorded_pos", cached_pos)
						new_player.velocity = Vector2.ZERO
						new_player.movement_vector = Vector2.ZERO
						new_player.is_moving = false
								
						if "movement_history" in current_player and "movement_history" in new_player:
							if not current_player.movement_history.is_empty():
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
	
	var max_active = RPGSYSTEM.database.system.party_active_members
	var party_needed = min(party.size() - 1, max_active - 1) if party.size() > 1 else 0
	
	for i in range(1, party_needed + 1):
		var f_idx = i - 1
		if f_idx < followers.size():
			var follower = followers[f_idx]
			if follower.get_meta("is_escort", false):
				continue
				
			var target_actor_id = party[i]
			
			if target_actor_id > 0 and target_actor_id < 1000000:
				target_actor_id = RPGSYSTEM.id_to_uid("actors", target_actor_id)
				party[i] = target_actor_id
				
			if follower.get_meta("actor_id", -1) != target_actor_id or follower.get_meta("requires_init", false):
				follower.visible = false
				
	for i in range(1, party_needed + 1):
		var f_idx = i - 1
		if f_idx < followers.size():
			var follower = followers[f_idx]
			if follower.get_meta("is_escort", false):
				continue
				
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

	# Ensure escort followers are visible and initialized
	for f_idx in range(party_needed, followers.size()):
		var follower = followers[f_idx]
		if is_instance_valid(follower) and follower.get_meta("is_escort", false):
			follower.visible = true
			follower.modulate.a = 1.0
			follower.is_fading_transition = false
			if not follower.get("is_joining_queue") and follower.has_method("_initialize_queue") and game_state.followers_tracking_enabled:
				follower._initialize_queue()



## Adds or hides followers to match the target party size limits
func _refresh_follower_nodes(instant: bool = false, save_data_list: Array = []) -> void:
	var current_map = GameManager.current_map
	var current_player = GameManager.current_player
	var game_state = GameManager.game_state
	
	if not current_map or not current_player: return
	
	followers = followers.filter(func(f): return is_instance_valid(f))
	
	var max_active = RPGSYSTEM.database.system.party_active_members
	var party_needed = 0
	if game_state.followers_enabled and game_state.current_party.size() > 1:
		party_needed = min(game_state.current_party.size() - 1, max_active - 1)
		
	var escort_needed = 0
	var escorted_list = []
	if "escorted_npcs" in game_state:
		escorted_list = game_state.escorted_npcs
		escort_needed = escorted_list.size()
		
	var needed = party_needed + escort_needed
	var insert_idx = current_player.get_index()
	var is_loading = not save_data_list.is_empty()
	
	# 1. Build list of desired slots
	var desired_slots: Array[Dictionary] = []
	for i in range(1, party_needed + 1):
		var target_actor_id = game_state.current_party[i]
		if target_actor_id > 0 and target_actor_id < 1000000:
			target_actor_id = RPGSYSTEM.id_to_uid("actors", target_actor_id)
			game_state.current_party[i] = target_actor_id
		desired_slots.append({
			"is_escort": false,
			"actor_id": target_actor_id,
			"escort_data": {}
		})
		
	for e_idx in range(escort_needed):
		desired_slots.append({
			"is_escort": true,
			"actor_id": 0,
			"escort_data": escorted_list[e_idx]
		})

	var new_followers: Array[SimpleFollower] = []
	var used_existing: Array[SimpleFollower] = []

	# Pass 1: Keep existing nodes that already match the desired identity
	for slot in desired_slots:
		var matched_f: SimpleFollower = null
		if slot.is_escort:
			var qid = slot.escort_data.get("quest_id", -1)
			var eid = slot.escort_data.get("event_uniq_id", -1)
			for f in followers:
				if is_instance_valid(f) and not used_existing.has(f) and f.get_meta("is_escort", false):
					var f_qid = f.get_meta("quest_id", -2)
					var f_eid = f.get_meta("event_uniq_id", -2)
					if (qid != -1 and f_qid == qid) or (eid != -1 and f_eid == eid):
						matched_f = f
						break
		else:
			for f in followers:
				if is_instance_valid(f) and not used_existing.has(f) and not f.get_meta("is_escort", false):
					if f.get_meta("actor_id", -1) == slot.actor_id:
						matched_f = f
						break
		if matched_f:
			new_followers.append(matched_f)
			used_existing.append(matched_f)
		else:
			new_followers.append(null)

	# Pass 2: Fill remaining slots with unused existing nodes, cached nodes, or new instances
	for slot_idx in range(desired_slots.size()):
		if new_followers[slot_idx] != null:
			continue
			
		var f: SimpleFollower = null
		for cand in followers:
			if is_instance_valid(cand) and not used_existing.has(cand):
				f = cand
				used_existing.append(f)
				break
				
		if not is_instance_valid(f):
			while _follower_cache.size() > 0 and not is_instance_valid(f):
				f = _follower_cache.pop_back()
				
		if not is_instance_valid(f):
			f = FOLLOWER_SCENE.instantiate() as SimpleFollower
			
		f.process_mode = Node.PROCESS_MODE_INHERIT
		if not f.is_in_group("follower"):
			f.add_to_group("follower")
		f.z_index = current_player.z_index
		f.visible = true
		
		if not f.is_inside_tree():
			current_map.add_child(f)
			current_map.move_child(f, insert_idx)
		elif f.get_parent() != current_map:
			f.get_parent().remove_child(f)
			current_map.add_child(f)
			current_map.move_child(f, insert_idx)
			
		if is_loading and slot_idx < save_data_list.size():
			var s_data = save_data_list[slot_idx]
			f.global_position = s_data.get("position", current_player.global_position)
			f.current_direction = s_data.get("direction", 8)
			f.modulate.a = 1.0
		else:
			var target_node = current_player if slot_idx == 0 else new_followers[slot_idx - 1]
			var spawn_pos = target_node.global_position if is_instance_valid(target_node) else current_player.global_position
			var spawn_dir = target_node.current_direction if is_instance_valid(target_node) else current_player.current_direction
			
			f.global_position = spawn_pos
			f.current_direction = spawn_dir
			f.modulate.a = 1.0 if instant else 0.0
			
		f.current_animation = "idle"
		f.is_fading_transition = not (instant or is_loading)
		f.set_meta("requires_init", true)
		new_followers[slot_idx] = f

	# Pass 3: Disable and cache any followers that were removed
	for old_f in followers:
		if is_instance_valid(old_f) and not used_existing.has(old_f):
			old_f.process_mode = Node.PROCESS_MODE_DISABLED
			old_f.visible = false
			if old_f.is_in_group("follower"):
				old_f.remove_from_group("follower")
			_follower_cache.append(old_f)
			
	followers = new_followers

	# Configure all followers (both party and escort)
	for f_idx in range(followers.size()):
		var f = followers[f_idx]
		if not is_instance_valid(f): continue
		
		@warning_ignore("incompatible_ternary")
		var target = current_player if f_idx == 0 else followers[f_idx - 1]
		f.target_node = target
		f.follower_id = f_idx + 1
		f.set_meta("party_id", f_idx + 1)
		f.is_sync_active = game_state.followers_tracking_enabled
		
		var slot = desired_slots[f_idx]
		var is_escort = slot.is_escort
		if is_escort:
			var npc = slot.escort_data
			f.set_meta("actor_id", 0)
			f.set_meta("is_escort", true)
			f.set_meta("quest_id", npc.get("quest_id", -1))
			f.set_meta("event_uniq_id", npc.get("event_uniq_id", -1))
			
			var r = npc.get("character_region", [0, 0, 0, 0])
			var rect = Rect2(r[0], r[1], r[2], r[3])
			f.setup_custom_graphics(npc.get("character_type", 0), npc.get("character_path", ""), rect)
			f.set_meta("requires_init", false)
			f.visible = true
			f.modulate.a = 1.0
			f.is_fading_transition = false
			
			if npc.get("walk_to_queue", false) and npc.has("spawn_pos"):
				var spos = Vector2(npc.spawn_pos[0], npc.spawn_pos[1])
				var sdir = npc.get("spawn_dir", current_player.current_direction)
				npc.erase("walk_to_queue")
				if f.has_method("start_joining_queue"):
					f.start_joining_queue(spos, sdir)
		else:
			f.set_meta("is_escort", false)
			if f.get_meta("actor_id", -1) != slot.actor_id:
				f.set_meta("actor_id", slot.actor_id)
				f.set_meta("requires_init", true)
				
		# Dynamic walk-to-queue adjustment:
		# If follower tracking is enabled and not during map loading/transfer,
		# check if the follower needs to walk to occupy its spot in the train
		var can_walk = not _is_transitioning and not is_loading and not GameManager.is_transfer_animating and game_state.followers_tracking_enabled and not f.get("is_walking_to_drop")
		if can_walk and not f.get("is_joining_queue"):
			var target_pos = f.get_target_queue_position() if f.has_method("get_target_queue_position") else target.global_position
			var dist = f.global_position.distance_to(target_pos)
			if dist > 16.0 and f.has_method("start_joining_queue"):
				f.start_joining_queue(f.global_position, f.current_direction)
			else:
				if f.has_method("_initialize_queue"):
					f._initialize_queue()
		else:
			if f.has_method("_initialize_queue") and game_state.followers_tracking_enabled:
				f._initialize_queue()
				
		if f.has_method("run_animation"):
			f.run_animation()
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



## Validates whether party leader can be shifted at this moment
func can_change_leader() -> bool:
	if _is_transitioning or GameManager.busy:
		return false
	if not GameManager.game_state or not GameManager.game_state.followers_enabled or GameManager.get_followers().size() == 0:
		return false
	var party: Array = GameManager.game_state.current_party
	var active_max: int = RPGSYSTEM.database.system.party_active_members
	var active_count: int = min(party.size(), active_max)
	if active_count <= 1:
		return false
	var current_p = GameManager.current_player
	if current_p and (current_p.get("is_moving") or current_p.get("is_jumping")):
		return false
	for f in followers:
		if is_instance_valid(f):
			if f.get("is_jumping_locally") or f.get("is_force_walking") or f.get("is_walking_to_drop") or f.get("is_joining_queue"):
				return false
	return true



## Checks whether the line between two positions is free of map obstacles and blocked tiles
func _is_direct_line_passable(from_pos: Vector2, to_pos: Vector2) -> bool:
	var map = GameManager.current_map
	if not map:
		return true
		
	var tile_a = map.get_tile_from_position(from_pos)
	var tile_b = map.get_tile_from_position(to_pos)
	if tile_a == tile_b:
		return true
		
	var diff = tile_b - tile_a
	var steps = max(abs(diff.x), abs(diff.y))
	if steps <= 1:
		if diff.x == 0 or diff.y == 0:
			return not map.is_tile_block(tile_b, false)
		else:
			if map.is_tile_block(tile_b, false):
				return false
			if map.is_tile_block(Vector2i(tile_a.x + diff.x, tile_a.y), false):
				return false
			if map.is_tile_block(Vector2i(tile_a.x, tile_a.y + diff.y), false):
				return false
			return true
			
	for s in range(1, steps + 1):
		var t = float(s) / float(steps)
		var check_tile = Vector2i(round(lerp(float(tile_a.x), float(tile_b.x), t)), round(lerp(float(tile_a.y), float(tile_b.y), t)))
		if map.is_tile_block(check_tile, false):
			return false
		if s > 0:
			var prev_t = float(s - 1) / float(steps)
			var prev_tile = Vector2i(round(lerp(float(tile_a.x), float(tile_b.x), prev_t)), round(lerp(float(tile_a.y), float(tile_b.y), prev_t)))
			if prev_tile != check_tile and prev_tile.x != check_tile.x and prev_tile.y != check_tile.y:
				if map.is_tile_block(Vector2i(check_tile.x, prev_tile.y), false) or map.is_tile_block(Vector2i(prev_tile.x, check_tile.y), false):
					return false
					
	return true



## Cycles the visible leader of the party swapping with followers
func change_leader_to(direction: String) -> void:
	if not can_change_leader():
		return
	
	_is_transitioning = true
	
	var party: Array = GameManager.game_state.current_party
	var active_max: int = RPGSYSTEM.database.system.party_active_members
	var active_count: int = min(party.size(), active_max)
	var active_party: Array = party.slice(0, active_count)
	var reserve_party: Array = party.slice(active_count, party.size())
	
	var is_split_mode_enabled: bool = !GameManager.game_state.followers_tracking_enabled
	
	if is_split_mode_enabled:
		var viewport_img = get_viewport().get_texture().get_image()
		var static_tex = ImageTexture.create_from_image(viewport_img)
		var overlay_canvas = CanvasLayer.new()
		overlay_canvas.layer = 128
		
		var overlay_rect = TextureRect.new()
		overlay_rect.texture = static_tex
		overlay_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		overlay_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		overlay_canvas.add_child(overlay_rect)
		get_tree().root.add_child(overlay_canvas)
		
		await get_tree().process_frame

		var current_player = GameManager.current_player
		var target_follower: Node2D = null
		
		var party_followers: Array = []
		for f in followers:
			if is_instance_valid(f) and not f.get_meta("is_escort", false):
				party_followers.append(f)
				
		if party_followers.is_empty():
			if is_instance_valid(overlay_canvas):
				overlay_canvas.queue_free()
			_is_transitioning = false
			return
		
		if direction == "up":
			target_follower = party_followers.back()
		else:
			target_follower = party_followers.front()
			
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
				var last_f = party_followers.pop_back()
				followers.erase(last_f)
				followers.push_front(last_f)
			else:
				var first_actor = active_party.pop_front()
				active_party.push_back(first_actor)
				var first_f = party_followers.pop_front()
				followers.erase(first_f)
				var insert_pos = party_followers.size()
				followers.insert(insert_pos, first_f)
					
			GameManager.game_state.current_party = active_party + reserve_party
			
			for f in followers:
				if is_instance_valid(f):
					if "current_direction" in f:
						f.fixed_direction = f.current_direction
					if not f.get_meta("is_escort", false):
						f.set_meta("requires_init", true)
					
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

		await get_tree().process_frame
		if is_instance_valid(overlay_canvas):
			overlay_canvas.queue_free()
		_is_transitioning = false
	else:
		# Train Mode: smooth 0.24s transition without pop, screenshot overlay, or glitches
		GameManager.busy = true
		
		var current_player = GameManager.current_player
		var current_map = GameManager.current_map
		if not current_player or not current_map:
			GameManager.busy = false
			_is_transitioning = false
			return
			
		var old_leader_id = current_player.get_meta("actor_id", active_party[0])
		
		# 1. Snapshot all train positions and directions
		var slot_positions: Array[Vector2] = [current_player.global_position]
		var slot_directions: Array[int] = [current_player.current_direction]
		
		for f in followers:
			if is_instance_valid(f):
				slot_positions.append(f.global_position)
				slot_directions.append(f.current_direction)
				f.is_sync_active = false
				f.is_joining_queue = false
				
		# 2. Rotate active party order
		var old_active: Array = active_party.duplicate()
		if direction == "up":
			var last_member = active_party.pop_back()
			active_party.push_front(last_member)
		else:
			var first_member = active_party.pop_front()
			active_party.push_back(first_member)
			
		var new_active: Array = active_party.duplicate()
		var new_leader_id = new_active[0]
		GameManager.game_state.current_party = new_active + reserve_party
		
		# 3. Create a follower clone representing the outgoing leader at slot 0
		var old_leader_follower: SimpleFollower = null
		while _follower_cache.size() > 0 and not is_instance_valid(old_leader_follower):
			old_leader_follower = _follower_cache.pop_back()
			
		if not is_instance_valid(old_leader_follower):
			old_leader_follower = FOLLOWER_SCENE.instantiate() as SimpleFollower
			
		old_leader_follower.process_mode = Node.PROCESS_MODE_INHERIT
		if not old_leader_follower.is_in_group("follower"):
			old_leader_follower.add_to_group("follower")
		old_leader_follower.z_index = current_player.z_index
		
		var insert_idx = current_player.get_index()
		if not old_leader_follower.is_inside_tree():
			current_map.add_child(old_leader_follower)
			current_map.move_child(old_leader_follower, insert_idx)
		elif old_leader_follower.get_parent() != current_map:
			old_leader_follower.get_parent().remove_child(old_leader_follower)
			current_map.add_child(old_leader_follower)
			current_map.move_child(old_leader_follower, insert_idx)
			
		old_leader_follower.global_position = slot_positions[0]
		old_leader_follower.current_direction = slot_directions[0]
		old_leader_follower.set_meta("actor_id", old_leader_id)
		old_leader_follower.set_meta("is_escort", false)
		old_leader_follower.visible = true
		old_leader_follower.modulate.a = 1.0
		old_leader_follower.is_sync_active = false
		old_leader_follower.is_joining_queue = false
		await old_leader_follower.update_appearance_cascade(old_leader_id, true)
		
		# 4. Hide current_player and store in cache
		current_player.visible = false
		_store_player_in_cache(old_leader_id, current_player)
		
		# 5. Prepare the new player at slot 0 (invisible for now)
		var new_player: CharacterBody2D = null
		var leader_actor = RPGSYSTEM.get_data("actors", new_leader_id) if new_leader_id > 0 else null
		if leader_actor and leader_actor.get("character_scene"):
			new_player = _get_player_from_cache(new_leader_id, leader_actor.character_scene) as CharacterBody2D
		elif leader_actor and leader_actor.get("character_data_file"):
			if current_player.scene_file_path:
				new_player = _get_player_from_cache(new_leader_id, current_player.scene_file_path) as CharacterBody2D
				
		if new_player:
			new_player.visible = false
			var parent = current_map
			if not new_player.is_inside_tree():
				parent.add_child(new_player)
				parent.move_child(new_player, insert_idx)
			elif new_player.get_parent() != parent:
				new_player.get_parent().remove_child(new_player)
				parent.add_child(new_player)
				parent.move_child(new_player, insert_idx)
				
			new_player.global_position = slot_positions[0]
			new_player.current_direction = slot_directions[0]
			if "last_direction" in new_player and "last_direction" in current_player:
				new_player.last_direction = current_player.last_direction
				
			var props_to_transfer = [
				"movement_current_mode", "current_map_tile_size", "previous_tile",
				"is_running", "map_offset", "cumulative_steps", "is_on_vehicle", 
				"current_vehicle", "current_virtual_tile", "collision_disabled", 
				"force_locked", "busy", "busy2", "_auto_target_tile", "_auto_target_event",
				"_last_recorded_pos", "_last_recorded_scale"
			]
			for prop in props_to_transfer:
				if prop in current_player and prop in new_player:
					new_player.set(prop, current_player.get(prop))
					
			if new_player.get("_last_recorded_pos") == Vector2.ZERO:
				new_player.set("_last_recorded_pos", slot_positions[0])
			new_player.velocity = Vector2.ZERO
			new_player.movement_vector = Vector2.ZERO
			new_player.is_moving = false
			
			if "movement_history" in current_player and "movement_history" in new_player:
				if not current_player.movement_history.is_empty():
					new_player.movement_history = current_player.movement_history.duplicate(true)
					
			if leader_actor and leader_actor.get("character_data_file") and new_player.has_method("set_data"):
				new_player.set_data(load(leader_actor.character_data_file))
				
			if leader_actor:
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
				
			new_player.set_meta("actor_id", new_leader_id)
			new_player.set_meta("party_id", 0)
			
		# 6. Map all party member follower nodes to their movement paths
		var member_nodes: Array[SimpleFollower] = [old_leader_follower]
		for i in range(1, active_count):
			if i - 1 < followers.size():
				member_nodes.append(followers[i - 1])
				
		var move_time: float = 0.28
		var parallel_tween = create_tween().set_parallel(true)
		var active_tweens: Array[Tween] = [parallel_tween]
		
		for k in range(member_nodes.size()):
			var node = member_nodes[k]
			if not is_instance_valid(node): continue
			var start_slot = k
			var dest_slot = new_active.find(old_active[k])
			if start_slot == dest_slot:
				continue
				
			node.fixed_direction = -1
			node.is_transition_walking = true
			node.current_animation = "walk"
			
			var target_pos = slot_positions[dest_slot]
			var is_direct = _is_direct_line_passable(node.global_position, target_pos)
			
			if is_direct or abs(start_slot - dest_slot) == 1:
				var diff = target_pos - node.global_position
				if diff.length() >= 1.0:
					if abs(diff.x) > abs(diff.y):
						node.current_direction = CharacterBase.DIRECTIONS.RIGHT if diff.x > 0 else CharacterBase.DIRECTIONS.LEFT
					else:
						node.current_direction = CharacterBase.DIRECTIONS.DOWN if diff.y > 0 else CharacterBase.DIRECTIONS.UP
				node.run_animation()
				parallel_tween.tween_property(node, "global_position", target_pos, move_time).set_trans(Tween.TRANS_LINEAR)
			else:
				var sub_tween = create_tween().set_parallel(false)
				active_tweens.append(sub_tween)
				var step_dir = 1 if dest_slot > start_slot else -1
				var steps_count = abs(dest_slot - start_slot)
				var step_time = move_time / float(steps_count)
				
				# Set initial direction immediately towards the first step
				var first_step_slot = start_slot + step_dir
				var first_step_pos = slot_positions[first_step_slot]
				var initial_diff = first_step_pos - node.global_position
				if initial_diff.length() >= 1.0:
					if abs(initial_diff.x) > abs(initial_diff.y):
						node.current_direction = CharacterBase.DIRECTIONS.RIGHT if initial_diff.x > 0 else CharacterBase.DIRECTIONS.LEFT
					else:
						node.current_direction = CharacterBase.DIRECTIONS.DOWN if initial_diff.y > 0 else CharacterBase.DIRECTIONS.UP
				node.run_animation()
				
				var curr_slot = start_slot
				while curr_slot != dest_slot:
					var next_slot = curr_slot + step_dir
					var next_pos = slot_positions[next_slot]
					sub_tween.tween_callback(func(n = node, p = next_pos):
						if is_instance_valid(n):
							var d = p - n.global_position
							if d.length() >= 1.0:
								if abs(d.x) > abs(d.y):
									n.current_direction = CharacterBase.DIRECTIONS.RIGHT if d.x > 0 else CharacterBase.DIRECTIONS.LEFT
								else:
									n.current_direction = CharacterBase.DIRECTIONS.DOWN if d.y > 0 else CharacterBase.DIRECTIONS.UP
							n.current_animation = "walk"
							n.run_animation()
					)
					sub_tween.tween_property(node, "global_position", next_pos, step_time).set_trans(Tween.TRANS_LINEAR)
					curr_slot = next_slot
					
		for tw in active_tweens:
			if tw and tw.is_valid() and tw.is_running():
				await tw.finished
		await get_tree().process_frame
		
		# Reset walking transition flag on all member nodes
		for node in member_nodes:
			if is_instance_valid(node):
				node.is_transition_walking = false
				node.current_animation = "idle"
				if node.has_method("run_animation"):
					node.run_animation()
		
		# 7. Reveal new player and retire the incoming leader follower
		var incoming_leader_idx = old_active.find(new_leader_id)
		if incoming_leader_idx != -1 and incoming_leader_idx < member_nodes.size():
			var incoming_leader_node = member_nodes[incoming_leader_idx]
			if is_instance_valid(incoming_leader_node):
				incoming_leader_node.visible = false
				incoming_leader_node.process_mode = Node.PROCESS_MODE_DISABLED
				if incoming_leader_node.is_in_group("follower"):
					incoming_leader_node.remove_from_group("follower")
				_follower_cache.append(incoming_leader_node)
				
		if is_instance_valid(new_player):
			new_player.global_position = slot_positions[0]
			new_player.current_direction = slot_directions[0]
			new_player.visible = true
			GameManager.current_player = new_player
			
			var main_camera = GameManager.main_scene.get_main_camera()
			if main_camera:
				if main_camera.has_method("add_target_to_array"):
					main_camera.add_target_to_array(new_player, 10)
				if "target" in main_camera and main_camera.get("target") == current_player:
					main_camera.target = new_player
				if main_camera.has_method("remove_target_from_array"):
					main_camera.remove_target_from_array(current_player)
					
			if new_player.has_method("run_animation"):
				new_player.run_animation(true)
				
		# 8. Reconstruct followers array
		var final_followers: Array[SimpleFollower] = []
		for j in range(1, active_count):
			var node_idx = old_active.find(new_active[j])
			if node_idx != -1 and node_idx < member_nodes.size():
				var f_node = member_nodes[node_idx]
				if is_instance_valid(f_node):
					f_node.global_position = slot_positions[j]
					f_node.current_direction = slot_directions[j]
					f_node.current_animation = "idle"
					f_node.visible = true
					f_node.modulate.a = 1.0
					if f_node.has_method("run_animation"):
						f_node.run_animation()
					final_followers.append(f_node)
					
		for orig_f in followers:
			if is_instance_valid(orig_f) and orig_f.get_meta("is_escort", false):
				final_followers.append(orig_f)
				
		followers = final_followers
		
		# 9. Re-chain followers and re-enable tracking
		for f_idx in range(followers.size()):
			var f = followers[f_idx]
			if not is_instance_valid(f): continue
			var target = new_player if f_idx == 0 else followers[f_idx - 1]
			f.target_node = target
			f.follower_id = f_idx + 1
			f.set_meta("party_id", f_idx + 1)
			f.is_sync_active = true
			f.is_joining_queue = false
			if f.has_method("_initialize_queue"):
				f._initialize_queue()
				
		GameManager.busy = false
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
