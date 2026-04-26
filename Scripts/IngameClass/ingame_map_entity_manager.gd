class_name IngameMapEntityManager
extends RefCounted


var map: RPGMap
var current_ingame_events: Dictionary[int, IngameEvent] = {}
var current_ingame_extraction_events: Dictionary[int, IngameExtractionEvent] = {}
var current_ingame_vehicles: Array[RPGVehicle] = []
var current_ingame_weather_scenes: Dictionary = {}
var particle_container: Node2D

## Array containing all instanced events in the current map that have at least one pressable page.
var pressable_events: Array[int] = []
var processing_task: bool = false
var _initial_delay: float = 0.0

## Number of physics frames to wait before re-evaluating a pressure plate after a page change.
const PRESSURE_COOLDOWN_FRAMES: int = 4


func _init(p_map: RPGMap) -> void:
	map = p_map


func setup_vehicles() -> void:
	var ids = [
		"land_transport_start_position",
		"sea_transport_start_position",
		"air_transport_start_position"
	]
	for vehicle in current_ingame_vehicles:
		if vehicle and is_instance_valid(vehicle):
			vehicle.queue_free()
			
	GameManager.current_map_vehicles = current_ingame_vehicles
	current_ingame_vehicles.clear()
	for id in ids:
		var data: RPGMapPosition
		if Engine.is_editor_hint():
			data = RPGSYSTEM.database.system.get(id)
		else:
			data = GameManager.game_state.get(id)
		if data:
			if data.map_id == map.internal_id:
				var vehicle_id = id.replace("_start_position", "")
				var vehicle_path: String = RPGSYSTEM.database.system.get(vehicle_id)
				if ResourceLoader.exists(vehicle_path):
					var start_position = data.position
					var scn = ResourceLoader.load(vehicle_path).instantiate()
					map.add_child(scn)
					map.set_event_position(scn, Vector2i(start_position.x, start_position.y), LPCCharacter.DIRECTIONS.DOWN)
					current_ingame_vehicles.append(scn)
					if not scn.is_in_group("vehicle"):
						scn.add_to_group("vehicle")


func clear_all_ingame_events() -> void:
	for ev: IngameEvent in current_ingame_events.values():
		if not ev: continue
		if ev.lpc_event:
			ev.lpc_event.queue_free()
	current_ingame_events.clear()


func clear_all_ingame_extraction_events() -> void:
	for ev: IngameExtractionEvent in current_ingame_extraction_events.values():
		if ev.scene:
			ev.scene.queue_free()
	current_ingame_extraction_events.clear()


func inject_carried_event(lpc_node: Node2D, original_map_id: int) -> void:
	if not lpc_node or not "current_event" in lpc_node:
		return
		
	var ev_resource: RPGEvent = lpc_node.current_event
	var u_id: int = ev_resource._uniq_id
	
	var page = lpc_node.get("current_event_page")
	var p_id = page.page_id if page else 1
	
	var ingame_event = IngameEvent.new(map, ev_resource, null, lpc_node, original_map_id, null, p_id)
	
	current_ingame_events[u_id] = ingame_event
	
	if lpc_node.has_method("update_virtual_tile"):
		lpc_node.update_virtual_tile()
		
	register_pressable_event(ev_resource)
	
	if map:
		map.register_hp_page(u_id, page._uniq_id if page else 0, page.options.hp if page else 10)


func setup_events() -> void:
	clear_all_ingame_events()
	GameManager.current_map_events = current_ingame_events
	var automatic_events: Array[Dictionary] = []
	
	var saved_events_data: Dictionary = {}
	var migrated_data: Dictionary = {}
	
	if GameManager.game_state:
		if "current_events" in GameManager.game_state:
			saved_events_data = GameManager.game_state.current_events
		if "migrated_events" in GameManager.game_state:
			migrated_data = GameManager.game_state.migrated_events
	
	var events_to_spawn: Array[RPGEvent] = []
	
	for ev: RPGEvent in map.events.get_events():
		var is_migrated_away = false
		if ev._uniq_id in migrated_data:
			if migrated_data[ev._uniq_id].current_map_id != map.internal_id:
				is_migrated_away = true
		
		if not is_migrated_away:
			events_to_spawn.append(ev)
			
	var cached_external_collections: Dictionary = {}
			
	for u_id in migrated_data:
		var m_data = migrated_data[u_id]
		if m_data.current_map_id == map.internal_id and m_data.original_map_id != map.internal_id:
			if GameManager.current_player and GameManager.current_player.carried_event:
				var carried_res = GameManager.current_player.carried_event.get("current_event")
				if carried_res and carried_res._uniq_id == u_id:
					continue
					
			var orig_map_id = m_data.original_map_id
			if not orig_map_id in cached_external_collections:
				var file_path = "res://data/MapEvents/Map_%s_events.tres" % str(orig_map_id)
				if ResourceLoader.exists(file_path):
					cached_external_collections[orig_map_id] = load(file_path)
				else:
					cached_external_collections[orig_map_id] = null
					
			var collection = cached_external_collections[orig_map_id]
			if collection and collection.has_method("get_event_by_uniq_id"):
				var found_event = collection.get_event_by_uniq_id(u_id)
				if found_event:
					events_to_spawn.append(found_event.duplicate(true))
	
	for ev: RPGEvent in events_to_spawn:
		ev.initialize_page_ids()
		var page: RPGEventPage = ev.get_active_page()
		
		if page:
			page.id = ev.id
			var origin_map = migrated_data[ev._uniq_id].original_map_id if ev._uniq_id in migrated_data else map.internal_id
			var ingame_event = IngameEvent.new(map, ev, null, null, origin_map, null, page.page_id)
			ingame_event.load_event_graphics(page, page.direction)
			
			if ev._uniq_id in saved_events_data:
				var e_data = saved_events_data[ev._uniq_id]
				ingame_event.lpc_event.position = e_data.position
				ingame_event.lpc_event.current_direction = e_data.direction
				if map:
					map.update_event_position_in_layout(ingame_event.lpc_event)
			elif ev._uniq_id in migrated_data and migrated_data[ev._uniq_id].current_map_id == map.internal_id:
				var m_data = migrated_data[ev._uniq_id]
				if "current_pos" in m_data:
					ingame_event.lpc_event.global_position = m_data.current_pos
					if map:
						map.update_event_position_in_layout(ingame_event.lpc_event)
			
			register_pressable_event(ingame_event.event)
			
			if map:
				map.register_hp_page(ev._uniq_id, page._uniq_id, page.options.hp)
				
			if ingame_event:
				current_ingame_events[ev._uniq_id] = ingame_event
				var interpreter_id = "event_" + str(ev._uniq_id)
				
				if page.launcher == RPGEventPage.LAUNCHER_MODE.AUTOMATIC:
					automatic_events.append({"obj": ingame_event.lpc_event, "commands": page.list, "id": interpreter_id})
				elif page.launcher == RPGEventPage.LAUNCHER_MODE.PARALLEL:
					GameInterpreter.register_interpreter(ingame_event.lpc_event, page.list, true, interpreter_id)
					
			ingame_event.update_label_name(page)
	
	QuestManager.scan_map_events(current_ingame_events)
	
	if not automatic_events.is_empty():
		GameInterpreter.auto_start_automatic_events(automatic_events)
	
	_initial_delay = 0.5


func setup_extraction_events() -> void:
	clear_all_ingame_extraction_events()
	GameManager.current_map_extraction_events = current_ingame_extraction_events
	
	for ev: RPGExtractionItem in map.extraction_events:
		var ingame_extraction_event = IngameExtractionEvent.new(map, ev)
		ingame_extraction_event.build()
		
		if ingame_extraction_event.is_valid():
			current_ingame_extraction_events[ev.id] = ingame_extraction_event


func refresh_events() -> void:
	await GameManager.get_tree().process_frame
	for ev: IngameEvent in current_ingame_events.values():
		if not ev: continue
		var active_page = ev.event.get_active_page()
		
		if active_page and active_page.page_id != ev.page_id:
			var is_message_node = false
			if GameManager.message and GameManager.message.anchor_node == ev.lpc_event:
				is_message_node = true
			ev.refresh_page(active_page)
			if is_message_node:
				GameManager.message.anchor_node = ev.lpc_event
			if map:
				map.register_hp_page(ev.uniq_id, active_page._uniq_id, active_page.options.hp)
				
			QuestManager.notify_event_page_changed(ev)
	
	for obj: CollisionShape2D in map.ingame_event_regions:
		var region = obj.get_meta("region_data")
		var region_is_disabled = region.activation_mode == EventRegion.ActivationMode.SWITCH and not GameManager.get_switch(region.activation_switch_id)
		if obj.disabled != region_is_disabled:
			obj.set_deferred("disabled", region_is_disabled)


func refresh_extraction_events() -> void:
	for ev: IngameExtractionEvent in current_ingame_extraction_events.values():
		if ev.scene: ev.scene.refresh()


func deferred_injection(ev: IngameEvent, page: RPGEventPage, interpreter_id: String) -> void:
	await map.get_tree().process_frame
	await map.get_tree().process_frame
	await map.get_tree().process_frame
	if is_instance_valid(map):
		ev.perform_injection(page, interpreter_id)


func create_ingame_event(ev: RPGEvent, page: RPGEventPage) -> IngameEvent:
	var ingame_event = IngameEvent.new(map, ev, null, null, map.internal_id, null, page.page_id)
	ingame_event.load_event_graphics(page, page.direction)
	return ingame_event


func process_extraction_events(delta: float) -> void:
	for event: IngameExtractionEvent in current_ingame_extraction_events.values():
		event.process_extraction(delta)


func get_events_in_place(pos: Vector2i) -> int:
	var event_count = 0
	if GameManager.current_player and GameManager.current_player.get_current_tile() == pos:
		event_count += 1
	event_count += get_overlapped_events_number(pos)
	event_count += get_overlapped_vehicle_number(pos)
	return event_count


func get_events_objects_in(pos: Vector2i) -> Array:
	var objects: Array = []
	if GameManager.current_player and GameManager.current_player.get_current_tile() == pos:
		objects.append(GameManager.current_player)
	
	for ev: IngameEvent in current_ingame_events.values():
		if not ev.lpc_event or not is_instance_valid(ev.lpc_event): continue
		if ev.lpc_event.get_current_tile() == pos:
			objects.append(ev.lpc_event)
	
	for vehicle: RPGVehicle in current_ingame_vehicles:
		var vehicle_tile_position = map.local_to_map(vehicle.global_position)
		if pos == vehicle_tile_position:
			objects.append(vehicle)
		elif vehicle.extra_dimensions:
			var extra_dimensions: RPGDimension = vehicle.extra_dimensions
			var vehicle_left = vehicle_tile_position.x - extra_dimensions.grow_left
			var vehicle_right = vehicle_tile_position.x + extra_dimensions.grow_right + 1
			var vehicle_up = vehicle_tile_position.y - extra_dimensions.grow_up
			var vehicle_down = vehicle_tile_position.y + extra_dimensions.grow_down + 1
			if pos.x >= vehicle_left and pos.x < vehicle_right and pos.y >= vehicle_up and pos.y < vehicle_down:
				objects.append(vehicle)
	return objects


func get_in_game_event_in(pos: Vector2i) -> Variant:
	for ev: IngameEvent in current_ingame_events.values():
		if not ev: continue
		if ev.lpc_event:
			if ev.lpc_event.get_current_tile() == pos:
				return ev.lpc_event
	
	for ev: IngameExtractionEvent in current_ingame_extraction_events.values():
		if ev.scene:
			var scene = ev.scene
			if scene.get_current_tile() == pos:
				return scene
	return null


func get_in_game_events_in(pos: Vector2i, include_previous_tile: bool = false) -> Array:
	var in_game_events: Array = []
	var real_pos = map.map_to_local(pos)
	var evs = map.map_layout.get_events_near_position(real_pos)
	for ev: Variant in evs:
		if not ev: continue
		if ev.get_current_tile() == pos or (include_previous_tile and ev.get_previous_tile() == pos):
			in_game_events.append(ev)
	return in_game_events


func get_overlapped_events_number(pos: Vector2i) -> int:
	var n = 0
	for ev: IngameEvent in current_ingame_events.values():
		if not ev: continue
		if ev.lpc_event:
			if ev.lpc_event.get_current_tile() == pos:
				n += 1
	return n


func get_in_game_events() -> Array[IngameEvent]:
	return current_ingame_events.values().filter(func(obj: Variant): return not obj == null)


func get_in_game_event(event_id: int) -> Variant:
	for ev: IngameEvent in current_ingame_events.values():
		if not ev: continue
		if ev.event and ev.event.id == event_id and ev.lpc_event:
			return ev.lpc_event
	return null


func get_in_game_event_by_pos(event_id: int) -> Variant:
	return get_in_game_event(event_id)


func get_in_game_event_by_id(event_id: int) -> Variant:
	return get_in_game_event(event_id)


func get_in_game_event_by_uniq_id(uniq_id: int, return_ingame_event: bool = false) -> Variant:
	if uniq_id in current_ingame_events:
		if return_ingame_event:
			return current_ingame_events[uniq_id]
		else:
			return current_ingame_events[uniq_id].lpc_event
	return null


func get_in_game_vehicle_in(pos: Vector2i) -> RPGVehicle:
	var current_vehicle: RPGVehicle = null
	for vehicle: RPGVehicle in current_ingame_vehicles:
		var vehicle_tile_position = map.local_to_map(vehicle.global_position)
		if pos == vehicle_tile_position:
			current_vehicle = vehicle
		elif vehicle.extra_dimensions:
			var extra_dimensions: RPGDimension = vehicle.extra_dimensions
			var vehicle_left = vehicle_tile_position.x - extra_dimensions.grow_left
			var vehicle_right = vehicle_tile_position.x + extra_dimensions.grow_right + 1
			var vehicle_up = vehicle_tile_position.y - extra_dimensions.grow_up
			var vehicle_down = vehicle_tile_position.y + extra_dimensions.grow_down + 1
			if pos.x >= vehicle_left and pos.x < vehicle_right and pos.y >= vehicle_up and pos.y < vehicle_down:
				current_vehicle = vehicle
		if current_vehicle: break
	return current_vehicle


func get_in_game_vehicles() -> Array[RPGVehicle]:
	return current_ingame_vehicles


func get_overlapped_vehicle_number(pos: Vector2i) -> int:
	var n = 0
	for vehicle: RPGVehicle in current_ingame_vehicles:
		var vehicle_tile_position = map.local_to_map(vehicle.global_position)
		if pos == vehicle_tile_position:
			n += 1
		elif vehicle.extra_dimensions:
			var extra_dimensions: RPGDimension = vehicle.extra_dimensions
			var vehicle_left = vehicle_tile_position.x - extra_dimensions.grow_left
			var vehicle_right = vehicle_tile_position.x + extra_dimensions.grow_right + 1
			var vehicle_up = vehicle_tile_position.y - extra_dimensions.grow_up
			var vehicle_down = vehicle_tile_position.y + extra_dimensions.grow_down + 1
			if pos.x >= vehicle_left and pos.x < vehicle_right and pos.y >= vehicle_up and pos.y < vehicle_down:
				n += 1
	return n


func add_weather_scene(id: int, weather_scene: Node, force_hidden: bool = false, is_reinject: bool = false) -> void:
	remove_weather_scene(id)
	current_ingame_weather_scenes[id] = weather_scene
	
	map.add_child(weather_scene)
	
	var takes_args = false
	for method in weather_scene.get_method_list():
		if method.name == "start":
			takes_args = method.args.size() > 0
			break
			
	if is_reinject:
		if weather_scene.has_method("start"):
			if takes_args:
				weather_scene.start(true)
			else:
				weather_scene.start()
		weather_scene.set_meta("started", true)
	else:
		weather_scene.visible = false
		if weather_scene.has_method("start"):
			if takes_args:
				weather_scene.start(false)
			else:
				weather_scene.start()
		weather_scene.set_meta("started", true)
		
		await map.get_tree().process_frame
		await map.get_tree().process_frame
		await map.get_tree().process_frame
		
	if is_instance_valid(weather_scene):
		if force_hidden:
			if weather_scene.has_method("pause_weather"):
				weather_scene.pause_weather()
			else:
				weather_scene.hide()
				weather_scene.process_mode = Node.PROCESS_MODE_DISABLED
		else:
			weather_scene.process_mode = Node.PROCESS_MODE_INHERIT
			if weather_scene.has_method("resume_weather"):
				weather_scene.resume_weather()
			await weather_scene.get_tree().process_frame
			if is_instance_valid(weather_scene):
				weather_scene.visible = true


func remove_weather_scene(id: int) -> void:
	if id in current_ingame_weather_scenes:
		if is_instance_valid(current_ingame_weather_scenes[id]):
			current_ingame_weather_scenes[id].queue_free()
			current_ingame_weather_scenes.erase(id)


func create_particle_container() -> void:
	particle_container = Node2D.new()
	particle_container.name = "ParticleContainer"
	particle_container.z_index = 1
	map.add_child(particle_container)


func get_particle_container() -> Node2D:
	return particle_container


func set_event_position(target: Node, tile: Vector2i, direction: LPCCharacter.DIRECTIONS, center_camera: bool = false, is_global_position: bool = false) -> void:
	if not target or not "position" in target:
		return
	
	if not is_global_position:
		target.position = map.layout_helper.get_tile_position(tile)
	else:
		target.position = tile
	map.update_event_position_in_layout(target)
	
	set_event_direction(target, direction)
	if center_camera:
		GameManager.get_camera().fast_reposition()


func set_event_direction(target: Variant, direction: LPCCharacter.DIRECTIONS) -> void:
	if "current_direction" in target:
		target.current_direction = direction
	if "last_direction" in target:
		target.last_direction = direction


#region Pressurable Events
## Registers an event to the pressable update list if it contains pressable pages.
func register_pressable_event(event: RPGEvent) -> void:
	if not event:
		return
		
	for page in event.pages:
		if page.condition and page.condition.use_pressure:
			if not event._uniq_id in pressable_events:
				pressable_events.append(event._uniq_id)
			return


## Evaluates pressure plates every physics tick, utilizing a frame-based cooldown to prevent flickering.
func update_pressable_events() -> void:
	if pressable_events.is_empty() or processing_task:
		return
		
	var is_startup_phase: bool = false
	if _initial_delay > 0.0:
		_initial_delay -= GameManager.get_process_delta_time()
		is_startup_phase = true
	
	if processing_task:
		return
	
	for i in range(pressable_events.size() - 1, -1, -1):
		var uniq_id: int = pressable_events[i]
		
		if not uniq_id in current_ingame_events:
			pressable_events.remove_at(i)
			continue
			
		var ingame_event: IngameEvent = current_ingame_events[uniq_id]
		var event: RPGEvent = ingame_event.event
		var lpc_event = ingame_event.lpc_event
		
		if not is_instance_valid(lpc_event) or ("is_invalid_event" in lpc_event and lpc_event.is_invalid_event):
			continue
		
		var old_page: RPGEventPage = lpc_event.current_event_page
		var new_page: RPGEventPage = event.get_active_page()
		
		if new_page != old_page:
			if is_startup_phase:
				if ingame_event.has_method("refresh_page"):
					ingame_event.refresh_page(new_page)

			else:
				if old_page.condition.use_pressure or new_page.condition.use_pressure:
					processing_task = true
					
					await GameInterpreter.start_event(lpc_event, old_page.list, false, "pressure_change")
					
					if ingame_event.has_method("refresh_page"):
						ingame_event.refresh_page(new_page)
					
					processing_task = false


## Clears the list when changing maps.
func clear_pressable_events() -> void:
	pressable_events.clear()
#endregion


#region Hot Reload
## Replaces an existing event node with a new one created from the updated resource, stopping any active interpreter
func spawn_event(ev: RPGEvent) -> void:
	var uniq_id = ev._uniq_id
	var interpreter_id = "event_" + str(uniq_id)
	
	if GameInterpreter.is_event_running(interpreter_id):
		GameInterpreter.remove_interpreter_by_id(interpreter_id)
		
	if uniq_id in current_ingame_events:
		var old_ev: IngameEvent = current_ingame_events[uniq_id]
		
		if old_ev and is_instance_valid(old_ev.lpc_event):
			old_ev.lpc_event.queue_free()
			
		current_ingame_events.erase(uniq_id)
		
	ev.initialize_page_ids()
	
	var page: RPGEventPage = ev.get_active_page()
	
	if page:
		page.id = ev.id
		
		var ingame_event = create_ingame_event(ev, page)
		register_pressable_event(ingame_event.event)
		
		if map:
			map.register_hp_page(uniq_id, page._uniq_id, page.options.hp)
			
		if ingame_event:
			current_ingame_events[uniq_id] = ingame_event
			
			if page.launcher == RPGEventPage.LAUNCHER_MODE.AUTOMATIC:
				GameInterpreter.auto_start_automatic_events([{"obj": ingame_event.lpc_event, "commands": page.list, "id": interpreter_id}])
			elif page.launcher == RPGEventPage.LAUNCHER_MODE.PARALLEL:
				GameInterpreter.register_interpreter(ingame_event.lpc_event, page.list, true, interpreter_id)
				
		ingame_event.update_label_name(page)


## Replaces an existing extraction event by destroying its scene and rebuilding it from the new resource
func spawn_extraction_event(ev: RPGExtractionItem) -> void:
	if ev.id in current_ingame_extraction_events:
		var old_ev: IngameExtractionEvent = current_ingame_extraction_events[ev.id]
		
		if old_ev and is_instance_valid(old_ev.scene):
			old_ev.scene.queue_free()
			
		current_ingame_extraction_events.erase(ev.id)
		
	var ingame_extraction_event = IngameExtractionEvent.new(map, ev)
	
	ingame_extraction_event.build()
	
	if ingame_extraction_event.is_valid():
		current_ingame_extraction_events[ev.id] = ingame_extraction_event


## Updates the game state with the new vehicle start position and reconstructs map vehicles
func hot_reload_start_position(target_id: String, new_map_id: int, new_pos: Vector2i) -> void:
	if target_id.is_empty():
		return
		
	var player = GameManager.current_player
	var is_deleting = (new_map_id == -1)
	
	if target_id == "player_start_position" and player and is_instance_valid(player):
		if not is_deleting and new_map_id == map.internal_id:
			set_event_position(player, new_pos, player.current_direction, true)
			player.clear_movement_history()
			
			if player.has_method("update_virtual_tile"):
				player.update_virtual_tile()
				
			var camera = GameManager.get_camera()
			
			if camera and camera.has_method("fast_reposition"):
				camera.fast_reposition.call_deferred()
		return
		
	var v_index = -1
	
	match target_id:
		"land_transport_start_position": v_index = 0
		"sea_transport_start_position": v_index = 1
		"air_transport_start_position": v_index = 2
		
	var v_node = null
	
	for vehicle in current_ingame_vehicles:
		if vehicle.vehicle_type == v_index:
			v_node = vehicle
			break
	
	if (is_deleting or new_map_id != map.internal_id) and player and is_instance_valid(player) and "is_on_vehicle" in player and player.is_on_vehicle:
		if "current_vehicle" in player and is_instance_valid(player.current_vehicle):
			if player.current_vehicle == v_node:
				var safe_tile: Vector2i = Vector2i.ZERO
				
				if v_node.has_method("get_current_tile"):
					safe_tile = v_node.get_current_tile()
				else:
					safe_tile = map.local_to_map(v_node.global_position)
					
				player.reparent(map)
				player.is_on_vehicle = false
				player.current_vehicle = null
				
				set_event_position(player, safe_tile, player.current_direction)
				player.clear_movement_history()
				
				if player.has_method("update_virtual_tile"):
					player.update_virtual_tile()
					
				player.show()
				
				if "force_locked" in player:
					player.force_locked = false
					
				var camera = GameManager.get_camera()
				
				if camera and camera.has_method("fast_reposition"):
					camera.fast_reposition.call_deferred()
						
	var data: RPGMapPosition
	
	if Engine.is_editor_hint():
		data = RPGSYSTEM.database.system.get(target_id)
	else:
		if GameManager.game_state:
			data = GameManager.game_state.get(target_id)
			if not data:
				data = RPGMapPosition.new()
				GameManager.game_state.set(target_id, data)
				
	if data:
		if is_deleting:
			data.map_id = -1
			data.position = Vector2i.ZERO
		else:
			data.map_id = new_map_id
			data.position = new_pos
		
	if is_deleting or new_map_id != map.internal_id:
		if is_instance_valid(v_node):
			v_node.name = "DeletedVehicle_" + str(v_node.get_instance_id())
			v_node.queue_free()
			current_ingame_vehicles.erase(v_node)
	else:
		if is_instance_valid(v_node):
			map.set_event_position(v_node, new_pos, v_node.current_direction)
		else:
			setup_vehicles()
#endregion
