class_name CharacterBaseInteraction
extends RefCounted

var current_entity


## Sets the target destination for pathfinding and instantiates a visual click indicator
func _set_target_destination(tile: Vector2i, is_new_click: bool = true) -> void:
	if not GameManager.current_map:
		return

	current_entity._auto_target_tile = tile
	current_entity._auto_target_event = null
	current_entity._last_auto_path_tile = Vector2i(-1, -1)
	current_entity._auto_path_stuck_frames = 0
	current_entity.set_meta("was_new_click", is_new_click)

	if current_entity.click_indicator_scene and current_entity._click_indicator_cooldown <= 0.0:
		current_entity._click_indicator_cooldown = 0.1
		var indicator = current_entity.click_indicator_scene.instantiate()
		GameManager.current_map.add_child(indicator)
		var map = GameManager.current_map
		indicator.global_position = map.get_tile_position(tile) - Vector2(0, map.tile_size.y / 2 - 8.0)

	if not is_new_click:
		return

	var map = GameManager.current_map
	var events = map.get_in_game_events_in(tile)

	for ev in events:
		if ev is LPCEvent or ev is EmptyLPCEvent or ev is GenericLPCEvent or ev.get_class() == "RPGExtractionScene" or ev is RPGVehicle or ev.has_method("interact"):
			current_entity._auto_target_event = ev
			break

	if not current_entity._auto_target_event and map.has_method("get_in_game_vehicle_in"):
		var vehicle = map.get_in_game_vehicle_in(tile)
		
		if vehicle:
			current_entity._auto_target_event = vehicle

	if not current_entity._auto_target_event and is_instance_valid(current_entity.interactive_event) and current_entity.interactive_event.has_method("interact"):
		if map.local_to_map(current_entity.interactive_event.global_position) == tile:
			current_entity._auto_target_event = current_entity.interactive_event


## Processes pathfinding logic and event interactions step by step
func _process_auto_movement() -> void:
	var current_tile = current_entity.get_current_tile()
	
	if current_tile == current_entity._last_auto_path_tile:
		current_entity._auto_path_stuck_frames += 1
		
		if current_entity._auto_path_stuck_frames > 60:
			current_entity._auto_target_tile = Vector2i(-1, -1)
			current_entity.movement_vector = Vector2.ZERO
			current_entity.current_animation = "idle"
			current_entity.run_animation()
			current_entity._auto_path_stuck_frames = 0
			return
	else:
		current_entity._last_auto_path_tile = current_tile
		current_entity._auto_path_stuck_frames = 0

	if current_tile == current_entity._auto_target_tile:
		current_entity._auto_target_tile = Vector2i(-1, -1)
		current_entity.movement_vector = Vector2.ZERO
		current_entity.current_animation = "idle"
		current_entity.run_animation()
		_interact_with_click_target()
		return

	if current_entity._auto_target_event and is_instance_valid(current_entity._auto_target_event):
		if _is_solid(current_entity._auto_target_event) or current_entity._auto_target_event.has_method("interact"):
			var is_adjacent = false
			var diff = Vector2i.ZERO
			var my_tiles = [current_tile]
			
			if current_entity.has_method("get_current_tiles"):
				my_tiles = current_entity.call("get_current_tiles")
			
			var target_tiles = []
			
			if current_entity._auto_target_event.has_method("get_current_tiles"):
				target_tiles = current_entity._auto_target_event.get_current_tiles()
			elif current_entity._auto_target_event.has_method("get_current_tile"):
				target_tiles = [current_entity._auto_target_event.get_current_tile()]
			else:
				var map = GameManager.current_map
				if map:
					target_tiles = [map.local_to_map(current_entity._auto_target_event.global_position)]
				else:
					target_tiles = [current_entity._auto_target_tile]
			
			for my_t in my_tiles:
				for tgt_t in target_tiles:
					var temp_diff = tgt_t - my_t
					if abs(temp_diff.x) + abs(temp_diff.y) == 1:
						is_adjacent = true
						diff = temp_diff
						break
				if is_adjacent:
					break
			
			if is_adjacent:
				current_entity._auto_target_tile = Vector2i(-1, -1)
				current_entity.movement_vector = Vector2.ZERO
				if not current_entity.character_options.fixed_direction:
					_look_at_tile_direction(diff)
				current_entity.current_animation = "idle"
				current_entity.run_animation()
				_interact_with_click_target()
				return

	var next_step = current_entity._get_next_move_toward_target(current_entity._auto_target_tile, Vector2.ZERO)
	
	if next_step != Vector2i.ZERO:
		current_entity.movement_vector = next_step
		if not current_entity.character_options.fixed_direction:
			var diagonal_movement_direction_mode = RPGSYSTEM.database.system.options.get("movement_mode", 0)
			match diagonal_movement_direction_mode:
				0: current_entity.set_vertical_look(current_entity.movement_vector)
				1: current_entity.set_horizontal_look(current_entity.movement_vector)
				2: current_entity.set_current_look(current_entity.movement_vector)
			current_entity.current_direction = current_entity.last_direction
		current_entity.current_animation = "walk"
		current_entity.run_animation()
	else:
		current_entity._auto_target_tile = Vector2i(-1, -1)
		current_entity.movement_vector = Vector2.ZERO
		current_entity.current_animation = "idle"
		current_entity.run_animation()


## Updates character facing direction based on a tile difference vector
func _look_at_tile_direction(diff: Vector2i) -> void:
	if diff.x > 0:
		current_entity.current_direction = current_entity.DIRECTIONS.RIGHT
	elif diff.x < 0:
		current_entity.current_direction = current_entity.DIRECTIONS.LEFT
	elif diff.y > 0:
		current_entity.current_direction = current_entity.DIRECTIONS.DOWN
	elif diff.y < 0:
		current_entity.current_direction = current_entity.DIRECTIONS.UP
		
	current_entity.last_direction = current_entity.current_direction
	current_entity.run_animation()


## Triggers standard interaction logic with the clicked target event upon arrival
func _interact_with_click_target() -> void:
	var node = current_entity._auto_target_event
	current_entity._auto_target_event = null

	var was_click = current_entity.get_meta("was_new_click", false)
	current_entity.set_meta("was_new_click", false)

	await current_entity.get_tree().create_timer(0.05).timeout

	if is_instance_valid(node):
		if node is RPGVehicle:
			current_entity._reset(true)
			node.start(current_entity)
		elif node is LPCEvent or node is EmptyLPCEvent or node is GenericLPCEvent:
			current_entity._reset(true)
			current_entity.is_moving = false
			current_entity.current_animation = "idle"
			current_entity.current_frame = 0
			current_entity.run_animation()
			
			if "current_event" in node and node.current_event is RPGEvent and node.current_event.next_page_has_pressure():
				return
				
			await node.start(current_entity, RPGEventPage.LAUNCHER_MODE.ACTION_BUTTON)
		elif node.get_class() == "RPGExtractionScene":
			if not node.extraction_data.is_depleted():
				GameManager.manage_extraction_scene(node)
		elif node.has_method("interact"):
			current_entity._reset(true)
			current_entity.is_moving = false
			current_entity.current_animation = "idle"
			current_entity.current_frame = 0
			current_entity.run_animation()
			node.interact()
			
		return

	if was_click:
		if current_entity.interactive_event and is_instance_valid(current_entity.interactive_event) and current_entity.interactive_event.has_method("interact"):
			var dist = current_entity.global_position.distance_to(current_entity.interactive_event.global_position)
			var tile_size_len = GameManager.get_map_tile_size().length()
			var can_activate = false

			if dist < tile_size_len / 2.0:
				can_activate = true
			elif dist <= tile_size_len * 1.5:
				var diff = current_entity.interactive_event.global_position - current_entity.global_position
				
				match current_entity.current_direction:
					current_entity.DIRECTIONS.LEFT:
						if diff.x < 0 and abs(diff.x) >= abs(diff.y) * 0.5:
							can_activate = true
					current_entity.DIRECTIONS.RIGHT:
						if diff.x > 0 and abs(diff.x) >= abs(diff.y) * 0.5:
							can_activate = true
					current_entity.DIRECTIONS.UP:
						if diff.y < 0 and abs(diff.y) >= abs(diff.x) * 0.5:
							can_activate = true
					current_entity.DIRECTIONS.DOWN:
						if diff.y > 0 and abs(diff.y) >= abs(diff.x) * 0.5:
							can_activate = true

			if can_activate:
				current_entity._reset(true)
				current_entity.interactive_event.interact()


## Core processor for entity to entity interactions and triggers
func _process_event_contact(contacting_entities: Array, stop_movement_on_activate: bool) -> bool:
	var im_player = current_entity.is_in_group("player")
	var page = current_entity.get("current_event_page")
	
	if not im_player and not page:
		return false

	var events_to_start: Array = []
	var self_id = current_entity.get("current_event")._uniq_id if "current_event" in current_entity else -1
	var self_launcher = page.launcher if page else -1
	var primary_target = contacting_entities[0] if not contacting_entities.is_empty() else null
	var self_activated_this_check = false

	for entity in contacting_entities:
		if entity in current_entity._ignore_events_contact:
			continue
		
		if "current_event_page" in entity and current_entity in entity._ignore_events_contact:
			continue
		
		if "current_event" in entity and entity.current_event is RPGEvent and entity.current_event.next_page_has_pressure():
			return false

		var activate_self = false
		var activate_other = false

		if not im_player and not self_activated_this_check:
			var is_pressure = page.condition.use_pressure if page and page.condition else false
			
			if not is_pressure:
				if self_launcher == RPGEventPage.LAUNCHER_MODE.PLAYER_COLLISION and entity.is_in_group("player"):
					activate_self = true
				elif self_launcher == RPGEventPage.LAUNCHER_MODE.ANY_CONTACT:
					activate_self = true
				elif self_launcher == RPGEventPage.LAUNCHER_MODE.EVENT_COLLISION and not entity.is_in_group("player"):
					if "current_event_page" in entity and entity.current_event_page:
						var other_id = entity.get("current_event")._uniq_id if "current_event" in entity else -1
						var event_trigger_list = page.get("event_trigger_list")
						if other_id in event_trigger_list:
							activate_self = true
		
		if "current_event_page" in entity and entity.current_event_page:
			var other_page = entity.current_event_page
			var is_other_pressure = other_page.condition.use_pressure if other_page and other_page.condition else false
			
			if not is_other_pressure:
				var other_launcher = other_page.launcher
				
				if im_player:
					if other_launcher == RPGEventPage.LAUNCHER_MODE.ANY_CONTACT or \
					   other_launcher == RPGEventPage.LAUNCHER_MODE.PLAYER_COLLISION:
						activate_other = true
				else:
					if other_launcher == RPGEventPage.LAUNCHER_MODE.ANY_CONTACT:
						activate_other = true
					elif other_launcher == RPGEventPage.LAUNCHER_MODE.EVENT_COLLISION:
						var other_trigger_list = other_page.get("event_trigger_list")
						if self_id in other_trigger_list:
							activate_other = true

		if activate_self or activate_other:
			_add_mutual_ignore(current_entity, entity)

			if activate_self:
				if not current_entity in events_to_start:
					events_to_start.append(current_entity)
				primary_target = entity
				self_activated_this_check = true 

			if activate_other:
				if not entity in events_to_start:
					events_to_start.append(entity)

	if not events_to_start.is_empty():
		var objs: Array[Dictionary] = []
		
		for ev in events_to_start:
			if ev.get("busy"):
				continue
				
			ev.activated_this_frame = true
			
			if stop_movement_on_activate:
				ev.is_moving = false
			
			ev._reset(true)
			objs.append({"obj": ev, "commands": ev.current_event_page.list, "id": str(ev.get_rid())})
			
			var target_to_look_at = current_entity if ev != current_entity else primary_target
			
			if target_to_look_at:
				if not ev.current_event_page.options.fixed_direction and "current_direction" in ev:
					ev.look_at_event(target_to_look_at)

		if not objs.is_empty():
			if stop_movement_on_activate and not current_entity in events_to_start:
				current_entity._reset(true) 
				current_entity.is_moving = false
				current_entity.call_deferred("_animation_to_idle")
				current_entity.run_animation()
				
			GameInterpreter.auto_start_automatic_events(objs)
			return true
			
	return false


## Triggers verifications for entity encounters over a designated map coordinate
func _check_contact(tile: Vector2i, check_passable: bool = false) -> bool:
	var im_player = current_entity.is_in_group("player")
	
	if GameManager.current_map:
		if not im_player:
			if current_entity.activated_this_frame:
				return false
				
			var valid_contacts: Array = []
			var all_entities_on_tile: Array = GameManager.current_map.get_in_game_events_in(tile)
			
			if GameManager.current_player and GameManager.current_player.get_current_tile() == tile:
				all_entities_on_tile.append(GameManager.current_player)

			for entity in all_entities_on_tile:
				if entity == current_entity:
					continue
				
				var entity_passable = entity.character_options.passable
				
				if (check_passable and entity_passable) or (not check_passable and not entity_passable) and not entity in current_entity._ignore_events_contact:
					valid_contacts.append(entity)

			if not valid_contacts.is_empty():
				var stop_movement = (not check_passable)
				return _process_event_contact(valid_contacts, stop_movement)

		else:
			var events_to_start: Array = []
			var evs: Array = GameManager.current_map.get_in_game_events_in(tile)
			
			for ev in evs:
				if not ev in current_entity._ignore_events_contact:
					if "current_event_page" in ev and ev.current_event_page:
						var other_page = ev.current_event_page
						
						if other_page.launcher == RPGEventPage.LAUNCHER_MODE.ANY_CONTACT or \
						   other_page.launcher == RPGEventPage.LAUNCHER_MODE.PLAYER_COLLISION:
							
							var ev_passable = ev.character_options.passable
							var passability_ok = (check_passable and ev_passable) or (not check_passable and not ev_passable)

							if passability_ok:
								events_to_start.append(ev)
								current_entity._ignore_events_contact.append(ev)
								ev._ignore_events_contact.append(GameManager.current_player)
								ev.activated_this_frame = true
			
			if not events_to_start.is_empty():
				var objs: Array[Dictionary] = []
				
				for ev in events_to_start:
					if not ev.get("busy"):
						ev.activated_this_frame = true
						ev.is_moving = false
						ev._reset(true)
						objs.append({"obj": ev, "commands": ev.current_event_page.list, "id": str(ev.get_rid())})
						
						if not ev.current_event_page.options.fixed_direction and "current_direction" in ev:
							ev.look_at_event(current_entity)
				
				if not objs.is_empty():
					current_entity._reset(true)
					current_entity.is_moving = false
					current_entity.call_deferred("_animation_to_idle")
					current_entity.run_animation()
					GameInterpreter.auto_start_automatic_events(objs)
					return true
			
	return false


## Analyzes proximity across axis lines for adjacent event bumps
func _check_nearby_events_for_activation() -> void:
	if current_entity.activated_this_frame or not GameManager.current_map:
		return

	var valid_contacts: Array = []
	var self_pos = current_entity.position
	var nearby_entities: Array = GameManager.current_map.get_events_near_position(self_pos)

	if GameManager.current_player:
		nearby_entities.append(GameManager.current_player)
	
	var is_horizontal: bool
	var direction_multiplier: int
	
	match current_entity.current_direction:
		current_entity.DIRECTIONS.LEFT:
			is_horizontal = true
			direction_multiplier = -1
		current_entity.DIRECTIONS.RIGHT:
			is_horizontal = true
			direction_multiplier = 1
		current_entity.DIRECTIONS.UP:
			is_horizontal = false
			direction_multiplier = -1
		current_entity.DIRECTIONS.DOWN:
			is_horizontal = false
			direction_multiplier = 1
		_:
			return

	const AXIS_TOLERANCE = 4.0

	for entity in nearby_entities:
		if entity == current_entity or not is_instance_valid(entity):
			continue
			
		if not _is_solid(entity):
			continue
			
		var entity_pos = entity.position
		
		if self_pos.distance_squared_to(entity_pos) <= current_entity._squared_tile_size:
			var is_on_axis = false
			var is_in_front = false
			
			if is_horizontal:
				is_on_axis = abs(entity_pos.y - self_pos.y) < AXIS_TOLERANCE
				is_in_front = (entity_pos.x - self_pos.x) * direction_multiplier >= 0
			else:
				is_on_axis = abs(entity_pos.x - self_pos.x) < AXIS_TOLERANCE
				is_in_front = (entity_pos.y - self_pos.y) * direction_multiplier >= 0
			
			if is_on_axis and is_in_front:
				valid_contacts.append(entity)

	if not valid_contacts.is_empty():
		_process_event_contact(valid_contacts, false)


## Calculates the rotation of the entity based on a specific target
func look_at_event(event: Variant) -> void:
	if event == current_entity: 
		return
		
	if current_entity.character_options and current_entity.character_options.fixed_direction:
		return
	
	var diff = event.global_position - current_entity.global_position
	
	if diff.length_squared() < 4.0:
		if "current_direction" in event:
			current_entity.current_direction = current_entity.get_opposite_direction(event.current_direction)
			current_entity.last_direction = current_entity.current_direction
		return
	
	var direction = diff.normalized()
	
	if abs(direction.x) > abs(direction.y):
		current_entity.current_direction = current_entity.DIRECTIONS.RIGHT if direction.x > 0 else current_entity.DIRECTIONS.LEFT
	else:
		current_entity.current_direction = current_entity.DIRECTIONS.DOWN if direction.y > 0 else current_entity.DIRECTIONS.UP
	
	current_entity.last_direction = current_entity.current_direction


## Verifies physical impediments right before movement processing applies
func _check_contact_before_move(tile: Vector2i, is_after_move: bool = false) -> bool:
	if not GameManager.current_map or current_entity.is_invalid_event:
		return true

	var im_player = current_entity.is_in_group("player")
	
	if im_player and current_entity.is_on_vehicle and GameManager.current_vehicle and GameManager.current_vehicle.flying_object:
		return false
		
	var all_entities_on_tile: Array = GameManager.current_map.get_in_game_events_in(tile, false)
	
	if not im_player and GameManager.current_player:
		if GameManager.current_player.get_current_tile() == tile:
			all_entities_on_tile.append(GameManager.current_player)
	
	var can_continue_movement: bool = true
	var valid_contacts: Array = []

	for entity in all_entities_on_tile:
		if entity == current_entity or ("is_invalid_event" in entity and entity.is_invalid_event):
			continue
		
		var entity_is_solid = _is_solid(entity)
		
		if entity_is_solid:
			if not (current_entity.character_options.passable or (im_player and Input.is_key_pressed(KEY_CTRL) and OS.is_debug_build())):
				can_continue_movement = false
			
			if not is_after_move and not entity in current_entity._ignore_events_contact:
				valid_contacts.append(entity)
		else:
			if is_after_move and not entity in current_entity._ignore_events_contact:
				valid_contacts.append(entity)

	if not valid_contacts.is_empty():
		var trigger_result = _process_event_contact(valid_contacts, not is_after_move)
		
		if trigger_result and not is_after_move:
			return false

	return can_continue_movement


## Wrapper for post-movement passability validations
func _check_contact_after_move() -> void:
	_check_contact_before_move(current_entity.get_current_tile(), true)


## Evaluates solidity and block capability of external entities
func _is_solid(entity: Node) -> bool:
	if entity.is_in_group("player") or entity is RPGVehicle:
		if entity.has_method("is_passable"):
			return not entity.is_passable()
		return true
	
	if "character_options" in entity and entity.character_options:
		return not entity.character_options.passable
		
	return false


## Confirms standard contact activation rule sets mapped in event pages
func _can_activate_event(my_entity, other_entity) -> bool:
	var my_page = my_entity.get("current_event_page") if not my_entity.is_in_group("player") else null
	var other_page = other_entity.get("current_event_page") if not other_entity.is_in_group("player") else null
	
	if not my_page and not other_page:
		return false
	
	if my_page:
		var my_launcher = my_page.launcher
		
		if my_launcher in [RPGEventPage.LAUNCHER_MODE.ANY_CONTACT, RPGEventPage.LAUNCHER_MODE.EVENT_COLLISION]:
			if my_launcher == RPGEventPage.LAUNCHER_MODE.ANY_CONTACT:
				return true
			elif other_page:
				var other_id = other_page.get("_uniq_id")
				var my_trigger_list = my_page.get("event_trigger_list")
				
				if other_id in my_trigger_list:
					return true
	
	if other_page:
		var other_launcher = other_page.launcher
		
		if other_launcher in [RPGEventPage.LAUNCHER_MODE.ANY_CONTACT, RPGEventPage.LAUNCHER_MODE.EVENT_COLLISION]:
			if other_launcher == RPGEventPage.LAUNCHER_MODE.ANY_CONTACT:
				return true
			elif my_page:
				var my_id = my_page.get("_uniq_id")
				var other_trigger_list = other_page.get("event_trigger_list")
				
				if my_id in other_trigger_list:
					return true
	
	return false


## Retrieves collision payload response considering player context rules
func _handle_player_contact(player, entity, entity_is_player: bool) -> Dictionary:
	if entity_is_player:
		return {"can_move": true, "contacts": []}
	
	var entity_page = entity.get("current_event_page")
	
	if not entity_page:
		return {"can_move": true, "contacts": []}
	
	var entity_launcher = entity_page.launcher
	
	if entity_launcher in [RPGEventPage.LAUNCHER_MODE.ANY_CONTACT, RPGEventPage.LAUNCHER_MODE.PLAYER_COLLISION]:
		if not entity in current_entity._ignore_events_contact:
			_add_mutual_ignore(entity, player)
			return {"can_move": true, "contacts": [entity]}
	
	return {"can_move": true, "contacts": []}


## Resolves general event interaction rules towards the player controller
func _handle_event_vs_player(event, player, my_is_solid: bool, my_is_moving: bool) -> Dictionary:
	var my_page = event.get("current_event_page")
	
	if not my_page:
		return {"can_move": true, "contacts": []}
	
	var my_launcher = my_page.launcher
	
	if my_launcher in [RPGEventPage.LAUNCHER_MODE.ANY_CONTACT, RPGEventPage.LAUNCHER_MODE.PLAYER_COLLISION]:
		if not event in current_entity._ignore_events_contact:
			_add_mutual_ignore(event, player)
			return {"can_move": true, "contacts": [event]}
	
	return {"can_move": true, "contacts": []}


## Computes interaction results for overlapping two solid event bounds
func _handle_solid_vs_solid(my_event, other_event, my_is_moving: bool, other_is_moving: bool) -> Dictionary:
	if not my_is_moving and not other_is_moving:
		var can_activate = _can_activate_event(my_event, other_event)
		var contacts = []
		
		if can_activate and not other_event in current_entity._ignore_events_contact:
			_add_mutual_ignore(other_event, my_event)
			contacts.append(other_event)
			
		return {"can_move": false, "contacts": contacts}
	
	if my_is_moving and other_is_moving:
		return {"can_move": true, "contacts": []}
	
	var can_activate = _can_activate_event(my_event, other_event)
	var contacts = []
	
	if can_activate and not other_event in current_entity._ignore_events_contact:
		_add_mutual_ignore(other_event, my_event)
		contacts.append(other_event)
		
	return {"can_move": false, "contacts": contacts}


## Computes interaction boundaries between a solid and a transparent entity
func _handle_solid_vs_passable(my_event, other_event, my_is_moving: bool, other_is_moving: bool) -> Dictionary:
	if other_is_moving:
		return {"can_move": true, "contacts": []}
	
	var can_activate = _can_activate_event(my_event, other_event)
	var contacts = []
	
	if can_activate and not other_event in current_entity._ignore_events_contact:
		_add_mutual_ignore(other_event, my_event)
		contacts.append(other_event)
		contacts.append(my_event)
		
	return {"can_move": true, "contacts": contacts}


## Computes interaction boundaries mapped from a passable to a solid element
func _handle_passable_vs_solid(my_event, other_event, other_is_moving: bool) -> Dictionary:
	if other_is_moving:
		var can_activate = _can_activate_event(my_event, other_event)
		var contacts = []
		
		if can_activate and not other_event in current_entity._ignore_events_contact:
			_add_mutual_ignore(other_event, my_event)
			contacts.append(other_event)
			contacts.append(my_event)
			
		return {"can_move": not can_activate, "contacts": contacts}
	
	var can_activate = _can_activate_event(my_event, other_event)
	var contacts = []
	
	if can_activate and not other_event in current_entity._ignore_events_contact:
		_add_mutual_ignore(other_event, my_event)
		contacts.append(other_event)
		contacts.append(my_event)
		
	return {"can_move": true, "contacts": contacts}


## Computes interaction results involving two transparent bounds
func _handle_passable_vs_passable(my_event, other_event) -> Dictionary:
	var can_activate = _can_activate_event(my_event, other_event)
	var contacts = []
	
	if can_activate and not other_event in current_entity._ignore_events_contact:
		_add_mutual_ignore(other_event, my_event)
		contacts.append(other_event)
		contacts.append(my_event)
		
	return {"can_move": true, "contacts": contacts}


## Binds two objects via reference arrays to prohibit recursive triggers
func _add_mutual_ignore(entity_a: Node, entity_b: Node) -> void:
	if not is_instance_valid(entity_a) or not is_instance_valid(entity_b):
		return
		
	if entity_a == entity_b:
		return
	
	if not entity_b in entity_a._ignore_events_contact:
		entity_a._ignore_events_contact.append(entity_b)
	
	if not entity_a in entity_b._ignore_events_contact:
		entity_b._ignore_events_contact.append(entity_a)


## Blocks continuous collision processing per target reference
func _add_to_ignore(entity: Node) -> void:
	if not entity == current_entity and not entity in current_entity._ignore_events_contact:
		current_entity._ignore_events_contact.append(entity)


## Validates active blacklists per target node
func _has_ignore_entity(entity: Node) -> bool:
	return entity in current_entity._ignore_events_contact


## Sanitizes data outputs by scrubbing redundant entities from arrays
func _remove_duplicates(array: Array) -> Array:
	var result: Array = []
	
	for item in array:
		if not item in result:
			result.append(item)
			
	return result


## Forcefully launches sequential event contacts via script command
func _trigger_events(valid_contacts: Array) -> void:
	if valid_contacts.is_empty():
		return
	
	_process_event_contact(valid_contacts, true)


## Looks around current location parameters looking for adjacent target handlers
func get_events_at_adjacent_tile() -> Array:
	var nodes_found: Array = []
	var node: RPGMap = GameManager.current_map
	
	if node:
		var origin = current_entity.global_position
		
		match current_entity.current_direction:
			current_entity.DIRECTIONS.LEFT: origin.x -= node.tile_size.x
			current_entity.DIRECTIONS.RIGHT: origin.x += node.tile_size.x
			current_entity.DIRECTIONS.UP: origin.y -= node.tile_size.y
			current_entity.DIRECTIONS.DOWN: origin.y += node.tile_size.y
		
		var used_rect = node.get_used_rect(false)
		
		if node.infinite_horizontal_scroll:
			var map_width = used_rect.size.x
			var relative_x = origin.x - used_rect.position.x
			var wrapped_x = fmod(relative_x, map_width)
			
			if wrapped_x < 0:
				wrapped_x += map_width
				
			origin.x = wrapped_x + used_rect.position.x
		
		if node.infinite_vertical_scroll:
			var map_height = used_rect.end.y - used_rect.position.y
			var relative_y = origin.y - used_rect.position.y
			var wrapped_y = fmod(relative_y, map_height)
			
			if wrapped_y < 0:
				wrapped_y += map_height
				
			origin.y = wrapped_y + used_rect.position.y
		
		var target_pos = node.local_to_map(origin)
		
		if node.has_method("get_in_game_events_in"):
			var events = node.get_in_game_events_in(target_pos)
			
			for ev in events:
				if ev is LPCEvent or ev is EmptyLPCEvent or ev is GenericLPCEvent or (ev and ev.get_class() == "RPGExtractionScene"):
					nodes_found.append(ev)
		
		if node.has_method("get_in_game_vehicle_in"):
			var vehicle = node.get_in_game_vehicle_in(target_pos)
			
			if vehicle and not vehicle in nodes_found:
				nodes_found.append(vehicle)
		
		if node.has_method("get_event_regions_in"):
			var regions = node.get_event_regions_in(target_pos)
			regions.reverse()
			for region: EventRegion in regions:
				if not region.can_entry and region.trigger_mode != EventRegion.TriggerMode.NONE:
					nodes_found.append(region)
					break
	
	return nodes_found
