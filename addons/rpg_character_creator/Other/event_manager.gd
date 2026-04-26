class_name EventManager
extends RefCounted


## Checks if the event node is passable.
static func is_passable(event_node: Node) -> bool:
	if event_node.is_invalid_event:
		return true
		
	return event_node.character_options.passable


## Checks if the event node can be lifted by the player.
static func is_liftable(event_node: Node) -> bool:
	if event_node.current_event_page:
		return event_node.current_event_page.options.event_type == 1
		
	return false


## Checks if the event node can be moved.
static func is_moveable(event_node: Node) -> bool:
	if event_node.current_event_page:
		return event_node.current_event_page.options.event_type == 2
		
	return false


## Calculates the next tile coordinate to move toward the target event.
static func get_next_move_toward_event(event_node: Node) -> Vector2i:
	var goal = Vector2i.ZERO
	var target_screen_position: Vector2 = Vector2.ZERO
	
	if event_node.current_event_page and GameManager.current_map:
		var target_id = event_node.current_event_page.movement_to_target
		var event = GameManager.current_map.get_in_game_event_by_uniq_id(target_id)
		
		if event and event.has_method("get_current_tile"):
			goal = event.get_current_tile()
			target_screen_position = event.get_global_transform_with_canvas().origin
	else:
		return goal
		
	return event_node._get_next_move_toward_target(goal, target_screen_position)


## Checks if the event node is currently being pressed.
static func is_pressed(event_node: Node) -> bool:
	if event_node.is_in_group("event") and GameManager.current_map:
		if event_node.current_event_page and event_node.current_event_page.condition.use_pressure:
			return true
			
	return false


## Starts the lift animation and calls the player to pick up the event.
static func start_lift_animation(event_node: Node) -> void:
	event_node.is_invalid_event = true
	var player = GameManager.current_player
	
	if player and player.has_method("pick_up_event"):
		player.pick_up_event(event_node)


## Triggers the event interaction logic and starts the interpreter if applicable.
static func start_event(event_node: Node, obj: Node, launcher_mode: RPGEventPage.LAUNCHER_MODE) -> bool:
	if event_node.is_invalid_event:
		return false
		
	if GameManager.game_state and GameManager.current_map:
		var id = "%s_%s" % [GameManager.current_map.internal_id, event_node.current_event.id]
		if not id in GameManager.game_state.stats.interactive_events_found:
			GameManager.game_state.stats.interactive_events_found[id] = true
			
	if obj in event_node.targets_over_me:
		return false
		
	var ingame_event = GameManager.current_map.get_in_game_event_by_uniq_id(event_node.current_event._uniq_id, true)

	
	if QuestManager.manage_mission_for_event(ingame_event):
		return true
		
	if is_liftable(event_node):
		start_lift_animation(event_node)
		return true
		
	if event_node.current_event_page:
		if event_node.current_event_page.launcher != launcher_mode:
			return false
			
		if not event_node.current_event_page.options.fixed_direction and "current_direction" in obj:
			event_node.last_direction = event_node.get_opposite_direction(obj.current_direction)
			event_node.current_direction = event_node.last_direction
			
		var interpreter_id = "event_" + str(event_node.current_event.id)
		GameInterpreter.start_event(event_node, event_node.current_event_page.list, false, interpreter_id)
		
	event_node.targets_over_me.append(obj)
	
	return true
