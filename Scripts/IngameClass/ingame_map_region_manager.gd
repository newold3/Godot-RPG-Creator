class_name IngameMapRegionManager
extends RefCounted


var map: RPGMap


func _init(p_map: RPGMap) -> void:
	map = p_map


func build_world_walls() -> StaticBody2D:
	var body := StaticBody2D.new()
	body.collision_layer = int(pow(2, 3))
	body.name = "Walls"
	map.add_child(body)
	
	var rect = map.get_used_rect(false)
	
	if !map.infinite_vertical_scroll:
		var top_wall: CollisionShape2D = CollisionShape2D.new()
		top_wall.shape = RectangleShape2D.new()
		top_wall.shape.size = Vector2(rect.size.x * 2, 32)
		var p = Vector2i(Vector2(rect.position.x, rect.position.y) / Vector2(map.tile_size)) * map.tile_size - Vector2i(0, 16)
		top_wall.position = p
		top_wall.name = "TopWall"
		body.add_child(top_wall)
		
		var bottom_wall: CollisionShape2D = CollisionShape2D.new()
		bottom_wall.shape = RectangleShape2D.new()
		bottom_wall.shape.size = Vector2(rect.size.x * 2, 32)
		p = Vector2i(Vector2(rect.position.x, rect.position.y + rect.size.y) / Vector2(map.tile_size)) * map.tile_size + Vector2i(0, 16)
		bottom_wall.position = p
		bottom_wall.name = "BotomWall"
		body.add_child(bottom_wall)
		
	if !map.infinite_horizontal_scroll:
		var left_wall: CollisionShape2D = CollisionShape2D.new()
		left_wall.shape = RectangleShape2D.new()
		left_wall.shape.size = Vector2(32, rect.size.y * 2)
		var p = Vector2i(Vector2(rect.position.x, rect.position.y) / Vector2(map.tile_size)) * map.tile_size - Vector2i(16, 0)
		left_wall.position = p
		left_wall.name = "LeftWall"
		body.add_child(left_wall)
		
		var right_wall: CollisionShape2D = CollisionShape2D.new()
		right_wall.shape = RectangleShape2D.new()
		right_wall.shape.size = Vector2(32, rect.size.y * 2)
		p = Vector2i(Vector2(rect.position.x + rect.size.x, rect.position.y) / Vector2(map.tile_size)) * map.tile_size + Vector2i(16, 0)
		right_wall.position = p
		right_wall.name = "RightWall"
		body.add_child(right_wall)
		
	return body


func setup_event_monitor() -> Area2D:
	var area: Area2D = Area2D.new()
	area.name = "EventMonitor"
	area.collision_layer = int(pow(2, 5))
	area.collision_mask = int(pow(2, 0)) | int(pow(2, 2))
	area.body_shape_entered.connect(_on_event_monitor_body_entered.bind(area))
	area.body_shape_exited.connect(_on_event_monitor_body_exited.bind(area))
	map.add_child(area)
	return area


func create_region_events(collision_body: StaticBody2D, collision_area: Area2D) -> void:
	for region: EventRegion in map.event_regions:
		var obj: CollisionShape2D = CollisionShape2D.new()
		obj.debug_color = region.color
		obj.shape = RectangleShape2D.new()
		obj.shape.size = region.rect.size * map.tile_size
		var p = region.rect.position * map.tile_size + Vector2i(obj.shape.size / 2)
		obj.position = p
		obj.name = "EventRegion#%s" % region.id
		obj.z_index = 1
		obj.set_meta("region_data", region)
		var region_is_disabled = region.activation_mode == EventRegion.ActivationMode.SWITCH and not GameManager.get_switch(region.activation_switch_id)
		obj.set_disabled(region_is_disabled)
		if not region.can_entry:
			obj.set_meta("type", "collision_region")
			collision_body.add_child(obj)
		else:
			obj.set_meta("type", "event_region")
			collision_area.add_child(obj)
		map.ingame_event_regions.append(obj)


func create_enemy_spawn_areas(collision_area: Area2D) -> void:
	for region: EnemySpawnRegion in map.regions:
		var obj: CollisionShape2D = CollisionShape2D.new()
		obj.shape = RectangleShape2D.new()
		obj.shape.size = region.rect.size * map.tile_size
		obj.debug_color = region.color
		var p = region.rect.position * map.tile_size + Vector2i(obj.shape.size / 2)
		obj.position = p
		obj.name = "EnemyEventRegion#%s" % region.id
		obj.z_index = 1
		
		obj.set_meta("type", "enemy_spawn_area")
		obj.set_meta("region_data", region)
		collision_area.add_child(obj)


func _on_event_monitor_body_entered(_body_rid: RID, body: Node2D, _body_shape_index: int, local_shape_index: int, main_area: Area2D) -> void:
	if body.is_in_group("vehicle") and not body.is_enabled:
		return
		
	var shape_owner_id = main_area.shape_find_owner(local_shape_index)
	var shape_node = main_area.shape_owner_get_owner(shape_owner_id)
	
	if "force_locked" in body and typeof(body.force_locked) == TYPE_BOOL:
		body.force_locked = true
	
	if body.has_method("is_processin_moving"):
		while body.is_processin_moving():
			await map.get_tree().process_frame
	
	if shape_node and shape_node.has_meta("type") and shape_node.has_meta("region_data"):
		var action_type = shape_node.get_meta("type")
		var region_data = shape_node.get_meta("region_data")
		
		if action_type == "event_region": 
			var reg := (region_data as EventRegion)
			
			if body.is_in_group("player"):
				QuestManager.notify_region_entered(map.internal_id, reg.id)
				
			var triggers = reg.triggers
			
			var is_in_player_group = body.is_in_group("player")
			#var is_in_event_group = body.is_in_group("event")
			var is_valid: bool = false

			if is_in_player_group and -1 in triggers:
				is_valid = true
			
			if not is_valid and body and body is LPCBase or body is EmptyLPCEvent or body is GenericLPCEvent:
				if (
					"current_event_page" in body and
					body.current_event_page and
					body.current_event_page is RPGEventPage
				):
					is_valid =  body.current_event_page._event_owner in triggers or body.current_event_page.id in triggers
			
			if not is_valid:
				if "force_locked" in body and typeof(body.force_locked) == TYPE_BOOL:
					body.force_locked = false
				return
			
			var commands: Array[RPGEventCommand]
			
			if reg.event_mode == reg.EventMode.COMMON_EVENTS:
				var event_id = reg.entry_common_event
				if RPGSYSTEM.database.common_events.size() > event_id and event_id > 0:
					var ev = RPGSYSTEM.database.common_events[event_id]
					commands = ev.list
			
			elif reg.event_mode == reg.EventMode.CALLER_EVENTS:
				var event_id = reg.trigger_caller_event_on_entry
				if event_id > 0:
					var ev = map.entity_manager.get_in_game_event_by_uniq_id(event_id)
					if ev and "current_event_page" in ev and ev.current_event_page is RPGEventPage:
						var event_page: RPGEventPage = ev.current_event_page
						if event_page.launcher == event_page.LAUNCHER_MODE.CALLER:
							commands = event_page.list
				
			if commands:
				if body.has_method("_reset"):
					body._reset(true)

				GameInterpreter.start_event(body, commands, true)
				
		elif action_type == "enemy_spawn_area" and (body.is_in_group("player") or body.is_in_group("vehicle")):
			map.current_in_game_enemy_spawn_region = region_data
	
	if "force_locked" in body and typeof(body.force_locked) == TYPE_BOOL:
		body.force_locked = false


func _on_event_monitor_body_exited(_body_rid: RID, body: Node2D, _body_shape_index: int, local_shape_index: int, main_area: Area2D) -> void:
	if not is_instance_valid(body): return
	
	if body.is_in_group("vehicle") and not body.is_enabled:
		return
		
	var shape_owner_id = main_area.shape_find_owner(local_shape_index)
	var shape_node = main_area.shape_owner_get_owner(shape_owner_id)
	
	if shape_node and shape_node.has_meta("type") and shape_node.has_meta("region_data"):
		var action_type = shape_node.get_meta("type")
		var region_data = shape_node.get_meta("region_data")
		
		if action_type == "event_region":
			var reg := (region_data as EventRegion)
			var commands: Array[RPGEventCommand]
			
			if reg.event_mode == reg.EventMode.COMMON_EVENTS:
				var event_id = reg.exit_common_event
				if RPGSYSTEM.database.common_events.size() > event_id and event_id > 0:
					var ev = RPGSYSTEM.database.common_events[event_id]
					commands = ev.list
			
			elif reg.event_mode == reg.EventMode.CALLER_EVENTS:
				var event_id = reg.trigger_caller_event_on_exit
				if event_id > 0:
					var ev = map.entity_manager.get_in_game_event_by_pos(event_id)
					if ev and "current_event_page" in ev and ev.current_event_page is RPGEventPage:
						var event_page: RPGEventPage = ev.current_event_page
						if event_page.launcher == event_page.LAUNCHER_MODE.CALLER:
							commands = event_page.list
				
			if commands:
				GameInterpreter.start_event(body, commands, true)
				
		elif action_type == "enemy_spawn_area" and (body.is_in_group("player") or body.is_in_group("vehicle")):
			if map.current_in_game_enemy_spawn_region and map.current_in_game_enemy_spawn_region == region_data:
				map.current_in_game_enemy_spawn_region = null


#region Hot Reload
## Replaces an existing enemy spawn region by removing its previous collision shape and creating a new one in the monitor
func spawn_enemy_region(region: EnemySpawnRegion) -> void:
	var event_monitor = map.get_node_or_null("EventMonitor")
	
	if event_monitor:
		var old_node = event_monitor.get_node_or_null("EnemyEventRegion#" + str(region.id))
		
		if old_node:
			old_node.name = "DeletedEnemyRegion_" + str(old_node.get_instance_id())
			old_node.queue_free()
			
		var obj: CollisionShape2D = CollisionShape2D.new()
		obj.shape = RectangleShape2D.new()
		obj.shape.size = region.rect.size * map.tile_size
		var p = region.rect.position * map.tile_size + Vector2i(obj.shape.size / 2)
		obj.position = p
		obj.name = "EnemyEventRegion#" + str(region.id)
		obj.z_index = 1
		obj.set_meta("type", "enemy_spawn_area")
		obj.set_meta("region_data", region)
		
		event_monitor.add_child(obj)



## Replaces an existing event region updating its logic, shape and reparenting it if its passability has changed
func spawn_event_region(region: EventRegion) -> void:
	var target_name = "EventRegion#" + str(region.id)
	var old_node = map.get_node_or_null("Walls/" + target_name)
	
	if not old_node:
		old_node = map.get_node_or_null("EventMonitor/" + target_name)
		
	if old_node:
		map.ingame_event_regions.erase(old_node)
		old_node.name = "DeletedRegion_" + str(old_node.get_instance_id())
		old_node.queue_free()
		
	var collision_body = map.get_node_or_null("Walls")
	var collision_area = map.get_node_or_null("EventMonitor")
	
	if collision_body and collision_area:
		var obj: CollisionShape2D = CollisionShape2D.new()
		obj.shape = RectangleShape2D.new()
		obj.shape.size = region.rect.size * map.tile_size
		var p = region.rect.position * map.tile_size + Vector2i(obj.shape.size / 2)
		obj.position = p
		obj.name = target_name
		obj.z_index = 1
		obj.set_meta("region_data", region)
		
		var region_is_disabled = region.activation_mode == EventRegion.ActivationMode.SWITCH and not GameManager.get_switch(region.activation_switch_id)
		obj.set_disabled(region_is_disabled)
		
		if not region.can_entry:
			obj.set_meta("type", "collision_region")
			collision_body.add_child(obj)
		else:
			obj.set_meta("type", "event_region")
			collision_area.add_child(obj)
			
		map.ingame_event_regions.append(obj)
#region
