extends Node


#region VARIABLES & INITIALIZATION
## Emitted when a new quest is successfully added to the active list.
signal quest_started(quest: GameQuest)
## Emitted when a quest (and its sub-quests) are marked as success.
signal quest_completed(quest: GameQuest)
## Emitted when a quest is moved to the historical record as failed.
signal quest_failed(quest: GameQuest)

## Toggles the debug prints to the console.
@export var show_debug_prints: bool = true

var active_quests: Array[GameQuest] = []
var map_events_with_quests: Array[IngameEvent] = []
var _is_dirty: bool = false
#endregion



## Initializes the active missions referencing the saved game state array.
func setup_active_quest() -> void:
	if GameManager.game_state:
		active_quests = GameManager.game_state.quest_progress.active_quests
		if show_debug_prints:
			print("[QuestManager] Active quests initialized. Total: ", active_quests.size())


## Checks the dirty flag every frame to consolidate multiple scan requests into a single operation.
func _process(delta: float) -> void:
	var timer_dirty = false
	
	if active_quests.size() > 0:
		for quest in active_quests.duplicate():
			if quest.status == GameQuest.QuestStatus.ACTIVE and quest.timer > 0.0:
				quest.timer -= delta
				if quest.timer <= 0.0:
					quest.timer = 0.0
					if show_debug_prints:
						print("[QuestManager] Quest ID ", quest.id, " failed due to timeout.")
					fail_mission(quest)
					timer_dirty = true
					
	if _is_dirty or timer_dirty:
		_validate_gather_quests()
		if GameManager.current_map and "entity_manager" in GameManager.current_map:
			scan_map_events(GameManager.current_map.entity_manager.current_ingame_events)
		_is_dirty = false


#region MAP & ICONS SCANNING
## Registers the events of the current map and forces an update/clear of all icons.
func scan_map_events(events: Dictionary) -> void:
	var all_events = events.values()
	map_events_with_quests.clear()
	
	for event in all_events:
		if _event_has_quest_data(event) or _is_event_related_to_active_quest(event):
			map_events_with_quests.append(event)
			
	for event in all_events:
		if map_events_with_quests.has(event):
			var icon_data = _get_highest_priority_icon_for_event(event)
			_apply_icon_to_event(event, icon_data)
		else:
			_apply_icon_to_event(event, null)


## Verifies if an event is an Objective Target or a Delivery Target of any active quest cluster.
func _is_event_related_to_active_quest(ingame_event: IngameEvent) -> bool:
	for active_quest in active_quests:
		if active_quest.target_event_uniq_id == ingame_event.uniq_id:
			return true
			
		var parent_quest = _get_parent_active_quest(active_quest.id)
		var check_id = parent_quest.id if parent_quest else active_quest.id
		
		if _is_cluster_ready_to_deliver(check_id):
			var p_active = _get_active_quest_by_id(check_id)
			var pquest = _get_owner_quest_configuration(p_active)
			if pquest and _is_custom_page_valid(pquest.target_page) and pquest.target_page.event_id == ingame_event.uniq_id:
				return true
				
		var db_quest = _get_quest_from_database(active_quest.id)
		if db_quest and db_quest.type == RPGQuest.QuestMode.USER_QUEST and active_quest.status == GameQuest.QuestStatus.ACTIVE:
			if _page_contains_user_quest_update(ingame_event, active_quest.id):
				return true
				
	return false


## Evaluates quests to determine the highest priority icon based on objectives and full cluster deliveries.
func _get_highest_priority_icon_for_event(ingame_event: IngameEvent) -> RPGIcon:
	var highest_icon: RPGIcon = null
	var current_priority: int = -1
	
	for active_quest in active_quests:
		var db_quest = _get_quest_from_database(active_quest.id)
		if not db_quest:
			continue
			
		if active_quest.target_event_uniq_id == ingame_event.uniq_id and db_quest.type == RPGQuest.QuestMode.TALK_TO_NPC:
			if active_quest.status == GameQuest.QuestStatus.ACTIVE:
				if current_priority < 3:
					highest_icon = db_quest.icon_completed
					current_priority = 3
					
		if db_quest.type == RPGQuest.QuestMode.USER_QUEST and active_quest.status == GameQuest.QuestStatus.ACTIVE:
			if _page_contains_user_quest_update(ingame_event, active_quest.id):
				if current_priority < 1:
					highest_icon = db_quest.icon_progress
					current_priority = 1
					
		var parent_quest = _get_parent_active_quest(active_quest.id)
		var check_id = parent_quest.id if parent_quest else active_quest.id
		
		if _is_cluster_ready_to_deliver(check_id):
			var p_active = _get_active_quest_by_id(check_id)
			var pquest = _get_owner_quest_configuration(p_active)
			if pquest and _is_custom_page_valid(pquest.target_page) and pquest.target_page.event_id == ingame_event.uniq_id:
				if current_priority < 3:
					highest_icon = db_quest.icon_completed
					current_priority = 3
					
		if active_quest.status == GameQuest.QuestStatus.FAILED_PENDING_DELIVERY and active_quest.owner_event_uniq_id == ingame_event.uniq_id:
			if current_priority < 2:
				highest_icon = db_quest.icon_failed
				current_priority = 2
					
	var event_res = _get_event_resource(ingame_event)
	if event_res and current_priority < 3:
		for event_quest in event_res.quests:
			var db_quest = _get_quest_from_database(event_quest.id)
			if not db_quest:
				continue
				
			var active_quest = _get_active_quest_by_id(event_quest.id)
			if not active_quest:
				var progress = GameManager.game_state.quest_progress
				var historical = GameManager.game_state.stats.missions.historical_dictionary
				
				if progress.unlocked_quests.has(event_quest.id) and not historical.has(event_quest.id) and _are_prerequisites_met(db_quest) and current_priority < 0:
					highest_icon = db_quest.icon_available
					current_priority = 0
					
	return highest_icon


## Instantiates or updates the visual quest icon above the given event.
func _apply_icon_to_event(ingame_event: IngameEvent, icon_data: RPGIcon) -> void:
	var lpc = ingame_event.lpc_event
	if not is_instance_valid(lpc):
		return
		
	var current_icon = lpc.get_meta("quest_icon") if lpc.has_meta("quest_icon") else null
	if current_icon and is_instance_valid(current_icon):
		current_icon.queue_free()
		lpc.set_meta("quest_icon", null)
		
	if not icon_data or icon_data.is_empty():
		return
		
	var res = load(icon_data.path)
	var icon_node: Node2D = null
	
	if res is PackedScene:
		icon_node = res.instantiate()
	elif res is Texture2D:
		var sprite = Sprite2D.new()
		sprite.texture = res
		if icon_data.region.has_area():
			sprite.region_enabled = true
			sprite.region_rect = icon_data.region
		icon_node = sprite
		
	if not icon_node:
		return
		
	icon_node.z_as_relative = false
	icon_node.z_index = 150
	lpc.add_child(icon_node)
	lpc.set_meta("quest_icon", icon_node)
	
	var up_node = lpc.get_node_or_null("%Up")
	var margin: Vector2 = Vector2(0, -24)
	
	if up_node:
		icon_node.position = up_node.position + margin
	else:
		icon_node.position = Vector2(0, -64)
#endregion


#region LIFECYCLE (START, COMPLETE, FAIL, NOTIFY)
## Periodically evaluates the conditions of the active quests.
func update_quests() -> void:
	pass


## Notifies the manager that an event's active page has changed, triggering an icon re-evaluation.
func notify_event_page_changed(_ingame_event: IngameEvent) -> void:
	_is_dirty = true


## Notifies the QuestManager that the player's inventory has changed.
func notify_inventory_changed() -> void:
	_is_dirty = true


## Notifies the QuestManager that the player has reached a new location or map.
func notify_location_reached(map_id: int) -> void:
	var objective_advanced = false
	
	for active_quest in active_quests.duplicate():
		if active_quest.status == GameQuest.QuestStatus.ACTIVE:
			var db_quest = _get_quest_from_database(active_quest.id)
			
			if db_quest and db_quest.type == RPGQuest.QuestMode.FIND_LOCATION:
				if db_quest.target_event.map_id == map_id:
					if show_debug_prints:
						print("[QuestManager] FIND_LOCATION Objective met for Quest ID: ", active_quest.id)
						
					active_quest.status = GameQuest.QuestStatus.COMPLETED_PENDING_DELIVERY
					objective_advanced = true
					
					var parent_quest = _get_parent_active_quest(active_quest.id)
					var check_id = parent_quest.id if parent_quest else active_quest.id
					
					if _is_cluster_ready_to_deliver(check_id):
						var p_active = _get_active_quest_by_id(check_id)
						var pquest = _get_owner_quest_configuration(p_active)
						if not _is_custom_page_valid(pquest.target_page):
							complete_mission(p_active)
							
	if objective_advanced:
		_is_dirty = true


## Notifies the manager that an enemy has been defeated, updating BOUNTY_HUNTS quests.
func notify_enemy_killed(enemy_id: int, amount: int = 1) -> void:
	var progress_made = false
	
	for active_quest in active_quests.duplicate():
		if active_quest.status == GameQuest.QuestStatus.ACTIVE:
			var db_quest = _get_quest_from_database(active_quest.id)
			
			if db_quest and db_quest.type == RPGQuest.QuestMode.BOUNTY_HUNTS:
				if db_quest.enemy_id == enemy_id:
					var added_progress = float(amount) / float(db_quest.enemy_amount)
					active_quest.current_progress = clamp(active_quest.current_progress + added_progress, 0.0, 1.0)
					progress_made = true
					
					if show_debug_prints:
						print("[QuestManager] BOUNTY_HUNTS progress updated for Quest ID: ", active_quest.id, " to ", active_quest.current_progress)
						
					if active_quest.current_progress >= 1.0:
						active_quest.status = GameQuest.QuestStatus.COMPLETED_PENDING_DELIVERY
						
						if show_debug_prints:
							print("[QuestManager] BOUNTY_HUNTS Objective met for Quest ID: ", active_quest.id)
							
						var parent_quest = _get_parent_active_quest(active_quest.id)
						var check_id = parent_quest.id if parent_quest else active_quest.id
						
						if _is_cluster_ready_to_deliver(check_id):
							var p_active = _get_active_quest_by_id(check_id)
							var pquest = _get_owner_quest_configuration(p_active)
							
							if pquest and not _is_custom_page_valid(pquest.target_page):
								if show_debug_prints:
									print("[QuestManager] Cluster fully completed. Auto-delivering BOUNTY_HUNTS Quest ID: ", check_id)
								complete_mission(p_active)
								
	if progress_made:
		_is_dirty = true


## Explicitly creates a new active quest and triggers any multi-quests auto-start sequentially.
func accept_quest(quest_id: int, owner_uniq_id: int, target_uniq_id: int = -1) -> void:
	var new_quest = GameQuest.new()
	new_quest.id = quest_id
	new_quest.status = GameQuest.QuestStatus.ACTIVE
	new_quest.owner_event_uniq_id = owner_uniq_id
	new_quest.target_event_uniq_id = target_uniq_id
	
	var owner_pquest = _get_owner_quest_configuration(new_quest)
	if owner_pquest and owner_pquest.use_custom_timer and owner_pquest.custom_timer >= 1.0:
		new_quest.timer = owner_pquest.custom_timer
	else:
		new_quest.timer = -1.0
		
	if show_debug_prints:
		print("[QuestManager] Accepted Quest ID: ", quest_id)
		
	add_active_mission(new_quest)
	
	var db_quest = _get_quest_from_database(quest_id)
	if db_quest and not db_quest.multi_quests.is_empty():
		for sub_id in db_quest.multi_quests:
			if not _get_active_quest_by_id(sub_id) and not GameManager.game_state.stats.missions.historical_dictionary.has(sub_id):
				var sub_target = _get_target_uniq_id_from_db(sub_id)
				accept_quest(sub_id, owner_uniq_id, sub_target)


## Adds a newly discovered quest to the game state, updates player stats, and emits the start signal.
func add_active_mission(quest: GameQuest) -> void:
	if not GameManager.game_state:
		return
		
	var progress_array = GameManager.game_state.quest_progress.active_quests
	if not progress_array.has(quest):
		progress_array.append(quest)
		
	GameManager.game_state.stats.missions.total_found += 1
	GameManager.game_state.stats.missions.in_progress += 1
	
	setup_active_quest()
	_is_dirty = true
	quest_started.emit(quest)


## Processes a successfully completed quest, granting rewards, and cascading cleanup to sub-quests.
func complete_mission(quest: GameQuest, force_subquest_cleanup: bool = false, force_repeatable: bool = false) -> void:
	if not GameManager.game_state:
		return
		
	var db_quest = _get_quest_from_database(quest.id)
	var is_sub = _is_sub_quest_of_active_parent(quest.id) or force_subquest_cleanup
	
	if db_quest and db_quest.type == RPGQuest.QuestMode.GATHER_ITEM and not db_quest.item_preserve:
		match db_quest.item_type:
			0:
				GameManager.remove_item_amount(db_quest.item_id, db_quest.item_quantity)
			1:
				GameManager.remove_weapon_amount(db_quest.item_id, db_quest.item_quantity, false)
			2:
				GameManager.remove_armor_amount(db_quest.item_id, db_quest.item_quantity, false)
			3:
				GameManager.remove_costume_amount(db_quest.item_id, db_quest.item_quantity, false)
				
	var progress_array = GameManager.game_state.quest_progress.active_quests
	for i in range(progress_array.size() - 1, -1, -1):
		if progress_array[i].id == quest.id:
			progress_array.remove_at(i)
			break
			
	GameManager.game_state.stats.missions.in_progress -= 1
	GameManager.game_state.stats.missions.completed += 1
	
	var result = GameQuestResult.new()
	result.generate_from_active_quest(quest, GameQuestResult.FinalResult.SUCCESS)
	GameManager.game_state.stats.missions.missions.append(result)
	
	var is_repeatable = force_repeatable or (db_quest and db_quest.is_repeatable)
	
	if is_repeatable:
		GameManager.game_state.stats.missions.historical_dictionary.erase(quest.id)
	else:
		GameManager.game_state.stats.missions.historical_dictionary[quest.id] = GameQuestResult.FinalResult.SUCCESS
		
	if not is_sub and db_quest:
		_grant_quest_rewards_and_unlocks(db_quest)
		_trigger_chain_quest(db_quest, quest.owner_event_uniq_id)
		
		var owner_pquest = _get_owner_quest_configuration(quest)
		if owner_pquest and "on_complete_common_event" in owner_pquest and owner_pquest.on_complete_common_event > -1:
			if RPGSYSTEM.database.common_events.size() > owner_pquest.on_complete_common_event:
				var common_event = RPGSYSTEM.database.common_events[owner_pquest.on_complete_common_event]
				if common_event:
					GameInterpreter.start_common_event(null, common_event.list)
					
		for sub_id in db_quest.multi_quests:
			var sub_active = _get_active_quest_by_id(sub_id)
			if sub_active:
				complete_mission(sub_active, true, is_repeatable)
				
	setup_active_quest()
	_is_dirty = true
	
	if not force_subquest_cleanup:
		quest_completed.emit(quest)


## Processes a failed quest, updating stats, archiving the result, and emitting the fail signal.
func fail_mission(quest: GameQuest, force_subquest_cleanup: bool = false, force_repeatable: bool = false) -> void:
	if not GameManager.game_state:
		return
		
	var db_quest = _get_quest_from_database(quest.id)
	var is_sub = _is_sub_quest_of_active_parent(quest.id) or force_subquest_cleanup
	
	var progress_array = GameManager.game_state.quest_progress.active_quests
	for i in range(progress_array.size() - 1, -1, -1):
		if progress_array[i].id == quest.id:
			progress_array.remove_at(i)
			break
			
	GameManager.game_state.stats.missions.in_progress -= 1
	
	var result = GameQuestResult.new()
	result.generate_from_active_quest(quest, GameQuestResult.FinalResult.FAILED)
	GameManager.game_state.stats.missions.missions.append(result)
	
	var is_repeatable = force_repeatable or (db_quest and db_quest.is_repeatable)
	
	if is_repeatable:
		GameManager.game_state.stats.missions.historical_dictionary.erase(quest.id)
	else:
		GameManager.game_state.stats.missions.historical_dictionary[quest.id] = GameQuestResult.FinalResult.FAILED
		
	if not is_sub and db_quest:
		var owner_pquest = _get_owner_quest_configuration(quest)
		if owner_pquest and "on_fail_common_event" in owner_pquest and owner_pquest.on_fail_common_event > -1:
			if RPGSYSTEM.database.common_events.size() > owner_pquest.on_fail_common_event:
				var common_event = RPGSYSTEM.database.common_events[owner_pquest.on_fail_common_event]
				if common_event:
					GameInterpreter.start_common_event(null, common_event.list)
					
		for sub_id in db_quest.multi_quests:
			var sub_active = _get_active_quest_by_id(sub_id)
			if sub_active:
				fail_mission(sub_active, true, is_repeatable)
				
	setup_active_quest()
	_is_dirty = true
	
	if not force_subquest_cleanup:
		quest_failed.emit(quest)
#endregion


#region EVENT INTERACTION (INTERCEPTOR)
## Intercepts the player interaction with an event to manage quest flows.
func manage_mission_for_event(event: IngameEvent) -> bool:
	var objective_advanced = false
	
	for active_quest in active_quests.duplicate():
		if active_quest.target_event_uniq_id == event.uniq_id and active_quest.status == GameQuest.QuestStatus.ACTIVE:
			var db_quest = _get_quest_from_database(active_quest.id)
			if db_quest and db_quest.type == RPGQuest.QuestMode.TALK_TO_NPC:
				if _is_event_on_required_page(event, db_quest.target_event.event_page_id):
					active_quest.status = GameQuest.QuestStatus.COMPLETED_PENDING_DELIVERY
					objective_advanced = true
					
					var parent_quest = _get_parent_active_quest(active_quest.id)
					var check_id = parent_quest.id if parent_quest else active_quest.id
					
					if _is_cluster_ready_to_deliver(check_id):
						var p_active = _get_active_quest_by_id(check_id)
						var pquest = _get_owner_quest_configuration(p_active)
						if not _is_custom_page_valid(pquest.target_page):
							complete_mission(p_active)
							
	if objective_advanced:
		_is_dirty = true
		return false
		
	if can_finish_cluster_delivery(event):
		finish_cluster_delivery(event)
		return true
		
	if can_finish_failed_mission_for(event):
		finish_failed_mission_for(event)
		return true
		
	if can_start_any_mission_for(event):
		start_next_quest_available_for(event)
		return true
		
	return false


## Checks if the event offers any mission that the player meets all requirements to start.
func can_start_any_mission_for(ingame_event: IngameEvent) -> bool:
	var event_res = _get_event_resource(ingame_event)
	if not event_res:
		return false
		
	var progress = GameManager.game_state.quest_progress
	var historical = GameManager.game_state.stats.missions.historical_dictionary
	
	for event_quest in event_res.quests:
		var db_quest = _get_quest_from_database(event_quest.id)
		if db_quest and progress.unlocked_quests.has(event_quest.id) and not historical.has(event_quest.id):
			if _are_prerequisites_met(db_quest):
				var active_quest = _get_active_quest_by_id(event_quest.id)
				if not active_quest:
					return true
					
	return false


## Starts the dialogue sequence or delegates to the event page for the first available mission.
func start_next_quest_available_for(ingame_event: IngameEvent) -> void:
	var event_res = _get_event_resource(ingame_event)
	if not event_res:
		return
		
	var progress = GameManager.game_state.quest_progress
	var historical = GameManager.game_state.stats.missions.historical_dictionary
	var target_quest: RPGEventPQuest = null
	
	for event_quest in event_res.quests:
		var db_quest = _get_quest_from_database(event_quest.id)
		if db_quest and progress.unlocked_quests.has(event_quest.id) and not historical.has(event_quest.id):
			if _are_prerequisites_met(db_quest):
				if not _get_active_quest_by_id(event_quest.id):
					target_quest = event_quest
					break
					
	if not target_quest:
		return
		
	var target_id = _get_target_uniq_id_from_db(target_quest.id)
	var interpreter_id = "quest_start_" + str(ingame_event.uniq_id)
		
	if _is_custom_page_valid(target_quest.start_page):
		if show_debug_prints:
			print("[QuestManager] Using custom start_page for Quest ID: ", target_quest.id)
		var commands = _get_commands_from_custom_page(target_quest.start_page)
		await GameInterpreter.start_event(ingame_event.lpc_event, commands, false, interpreter_id)
	else:
		if show_debug_prints:
			print("[QuestManager] Using fallback start for Quest ID: ", target_quest.id)
		var commands = _generate_fallback_start_commands(target_quest)
		var is_auto = not target_quest.use_confirm_message
		if commands.is_empty() and is_auto:
			accept_quest(target_quest.id, ingame_event.uniq_id, target_id)
		else:
			await GameInterpreter.start_event(ingame_event.lpc_event, commands, false, interpreter_id)
			if is_auto:
				accept_quest(target_quest.id, ingame_event.uniq_id, target_id)


## Checks if the event is the Delivery Target of a fully completed mission cluster.
func can_finish_cluster_delivery(ingame_event: IngameEvent) -> bool:
	for active_quest in active_quests:
		var parent_quest = _get_parent_active_quest(active_quest.id)
		var check_id = parent_quest.id if parent_quest else active_quest.id
		if _is_cluster_ready_to_deliver(check_id):
			var p_active = _get_active_quest_by_id(check_id)
			var pquest = _get_owner_quest_configuration(p_active)
			if pquest and _is_custom_page_valid(pquest.target_page) and pquest.target_page.event_id == ingame_event.uniq_id:
				return true
	return false


## Executes the finish/delivery sequence executing the target page commands.
func finish_cluster_delivery(ingame_event: IngameEvent) -> void:
	var target_parent_active: GameQuest = null
	var target_pquest: RPGEventPQuest = null
	for active_quest in active_quests:
		var parent_quest = _get_parent_active_quest(active_quest.id)
		var check_id = parent_quest.id if parent_quest else active_quest.id
		if _is_cluster_ready_to_deliver(check_id):
			var p_active = _get_active_quest_by_id(check_id)
			var pquest = _get_owner_quest_configuration(p_active)
			if pquest and _is_custom_page_valid(pquest.target_page) and pquest.target_page.event_id == ingame_event.uniq_id:
				target_parent_active = p_active
				target_pquest = pquest
				break
	if target_parent_active and target_pquest:
		if show_debug_prints:
			print("[QuestManager] Launching Delivery Commands for Quest ID: ", target_parent_active.id)
		var commands = _get_commands_from_custom_page(target_pquest.target_page)
		var interpreter_id = "quest_finish_" + str(ingame_event.uniq_id)
		await GameInterpreter.start_event(ingame_event.lpc_event, commands, false, interpreter_id)


## Checks if the event has an assigned mission in a failed state ready to report.
func can_finish_failed_mission_for(ingame_event: IngameEvent) -> bool:
	for active_quest in active_quests:
		if active_quest.owner_event_uniq_id == ingame_event.uniq_id:
			if active_quest.status == GameQuest.QuestStatus.FAILED_PENDING_DELIVERY:
				return true
	return false


## Executes the fail sequence for a failed mission assigned to this owner event.
func finish_failed_mission_for(ingame_event: IngameEvent) -> void:
	var target_active_quest: GameQuest = null
	var target_event_quest: RPGEventPQuest = null
	for active_quest in active_quests:
		if active_quest.owner_event_uniq_id == ingame_event.uniq_id:
			if active_quest.status == GameQuest.QuestStatus.FAILED_PENDING_DELIVERY:
				target_active_quest = active_quest
				target_event_quest = _get_event_pquest_data_from_owner(ingame_event, active_quest.id)
				break
	if target_active_quest and target_event_quest:
		var interpreter_id = "quest_fail_" + str(ingame_event.uniq_id)
		if target_event_quest.on_failure_quest_page > -1:
			if show_debug_prints:
				print("[QuestManager] Using local on_failure_quest_page for Quest ID: ", target_active_quest.id)
			var commands = _get_commands_from_page_index(ingame_event, target_event_quest.on_failure_quest_page)
			await GameInterpreter.start_event(ingame_event.lpc_event, commands, false, interpreter_id)
			fail_mission(target_active_quest)
		else:
			if show_debug_prints:
				print("[QuestManager] Using fallback fail for Quest ID: ", target_active_quest.id)
			var commands = _generate_fallback_fail_commands(target_event_quest, target_active_quest)
			if not commands.is_empty():
				await GameInterpreter.start_event(ingame_event.lpc_event, commands, false, interpreter_id)
			fail_mission(target_active_quest)
#endregion


#region UTILITIES & DATA RETRIEVAL
## Checks if the event's active page contains a command (126, type 6) to update the given USER_QUEST.
func _page_contains_user_quest_update(ingame_event: IngameEvent, quest_id: int) -> bool:
	var active_page = _get_active_event_page(ingame_event)
	if not active_page: return false
	for cmd in active_page.list:
		if cmd.code == 126 and cmd.parameters.get("operation_type") == 6:
			var scope = cmd.parameters.get("quest_scope", 0)
			if scope == 0:
				if cmd.parameters.get("global_ids", []).has(quest_id): return true
			elif scope == 1:
				if cmd.parameters.get("specific_ids", []).has(quest_id): return true
	return false


## Returns the parent quest if this quest was auto-started as a multi-quest.
func _get_parent_active_quest(child_quest_id: int) -> GameQuest:
	for active in active_quests:
		var db = _get_quest_from_database(active.id)
		if db and db.multi_quests.has(child_quest_id): return active
	return null


## Validates if the parent quest and all its multi-quests are entirely fulfilled.
func _is_cluster_ready_to_deliver(parent_quest_id: int) -> bool:
	var parent_active = _get_active_quest_by_id(parent_quest_id)
	if not parent_active or parent_active.status != GameQuest.QuestStatus.COMPLETED_PENDING_DELIVERY: return false
	var parent_db = _get_quest_from_database(parent_quest_id)
	if not parent_db: return false
	for sub_id in parent_db.multi_quests:
		var sub_active = _get_active_quest_by_id(sub_id)
		if sub_active and sub_active.status != GameQuest.QuestStatus.COMPLETED_PENDING_DELIVERY: return false
	return true


## Checks if the event is currently active on the exact page required by the database.
func _is_event_on_required_page(ingame_event: IngameEvent, req_page_id: int) -> bool:
	if req_page_id == -1: return true
	var active_page = _get_active_event_page(ingame_event)
	return active_page and active_page._uniq_id == req_page_id


## Sums rewards from the quest and its multi-quests, grants them, and unlocks new quests.
func _grant_quest_rewards_and_unlocks(db_quest: RPGQuest) -> void:
	if not db_quest or not GameManager.game_state:
		return
		
	if show_debug_prints:
		print("[QuestManager] Granting rewards for Quest ID: ", db_quest.id)
		
	var progress = GameManager.game_state.quest_progress
	for unlock_id in db_quest.quests_unlocked:
		if not progress.unlocked_quests.has(unlock_id):
			progress.unlocked_quests[unlock_id] = true
			if show_debug_prints:
				print("[QuestManager] Unlocked new Quest ID: ", unlock_id)
				
	var reward_cmds = _generate_reward_commands(db_quest.reward)
	if not reward_cmds.is_empty():
		GameInterpreter.start_event(null, reward_cmds, false, "quest_reward_" + str(db_quest.id))


## Generates the interpreter commands required to grant the specific quest reward.
func _generate_reward_commands(reward: RPGQuestReward) -> Array[RPGEventCommand]:
	var cmds: Array[RPGEventCommand] = []
	
	if not reward:
		return cmds
		
	if reward.gold > 0:
		var cmd_gold = RPGEventCommand.new()
		cmd_gold.code = 12
		cmd_gold.parameters = {"operation_type": 0, "value": float(reward.gold), "value_type": 0}
		cmds.append(cmd_gold)
		
	if reward.experience > 0:
		var cmd_exp = RPGEventCommand.new()
		cmd_exp.code = 42
		cmd_exp.parameters = {"actor_id": 0, "actor_type": 0, "operand": 0, "operand_type": 0, "operand_value": float(reward.experience), "parameter_id": -1, "show_level_up": true}
		cmds.append(cmd_exp)
		
	for drop in reward.items:
		var q_min = min(drop.quantity, drop.quantity2)
		var q_max = max(drop.quantity, drop.quantity2)
		var final_amount = randi_range(q_min, q_max)
		
		if final_amount <= 0:
			continue
			
		var l_min = min(drop.min_level, drop.max_level)
		var l_max = max(drop.min_level, drop.max_level)
		var final_level = randi_range(l_min, l_max)
		
		var comp = drop.item
		var cmd_item = RPGEventCommand.new()
		
		match comp.data_id:
			0:
				cmd_item.code = 13
				cmd_item.parameters = {"item_id": comp.item_id, "operation_type": 0, "value": float(final_amount), "value_type": 0}
			1:
				cmd_item.code = 14
				cmd_item.parameters = {"include_equipment": false, "item_id": comp.item_id, "level": float(final_level), "operation_type": 0, "value": float(final_amount), "value_type": 0}
			2:
				cmd_item.code = 15
				cmd_item.parameters = {"include_equipment": false, "item_id": comp.item_id, "level": float(final_level), "operation_type": 0, "value": float(final_amount), "value_type": 0}
			3:
				cmd_item.code = 127
				cmd_item.parameters = {"include_equipment": false, "item_id": comp.item_id, "operation_type": 0, "value": float(final_amount), "value_type": 0}
				
		cmds.append(cmd_item)
		
	return cmds


## Checks if the provided quest is a sub-quest of any currently active multi-quest parent.
func _is_sub_quest_of_active_parent(sub_quest_id: int) -> bool:
	for active in active_quests:
		var parent_db = _get_quest_from_database(active.id)
		if parent_db and parent_db.multi_quests.has(sub_quest_id): return true
	return false


## Auto-accepts the defined chain quest sequentially after the main quest finishes.
func _trigger_chain_quest(db_quest: RPGQuest, owner_uniq_id: int) -> void:
	if db_quest.chain_quest != -1:
		var progress = GameManager.game_state.quest_progress
		progress.unlocked_quests[db_quest.chain_quest] = true
		
		if show_debug_prints:
			print("[QuestManager] Triggering Chain Quest ID: ", db_quest.chain_quest)
			
		var chain_target = _get_target_uniq_id_from_db(db_quest.chain_quest)
		accept_quest(db_quest.chain_quest, owner_uniq_id, chain_target)


## Validates if all required prerequisite quests exist in the historical dictionary as SUCCESS.
func _are_prerequisites_met(db_quest: RPGQuest) -> bool:
	if not db_quest or db_quest.prerequisites.is_empty(): return true
	var historical = GameManager.game_state.stats.missions.historical_dictionary
	for pre_req in db_quest.prerequisites:
		if not historical.has(pre_req) or historical[pre_req] != GameQuestResult.FinalResult.SUCCESS: return false
	return true


## Helper to extract the physical target NPC from the global database quest.
func _get_target_uniq_id_from_db(quest_id: int) -> int:
	var db_quest = _get_quest_from_database(quest_id)
	if db_quest and db_quest.target_event and db_quest.target_event.event_id != -1:
		return db_quest.target_event.event_id
	return -1


## Safely retrieves the RPGEvent resource from an IngameEvent or its associated LPC node.
func _get_event_resource(ingame_event: IngameEvent) -> RPGEvent:
	if not is_instance_valid(ingame_event): return null
	if is_instance_valid(ingame_event.lpc_event):
		if ingame_event.lpc_event.get("current_event") is RPGEvent:
			return ingame_event.lpc_event.current_event
	return ingame_event.event


## Retrieves the currently active page from the event resource safely.
func _get_active_event_page(ingame_event: IngameEvent) -> RPGEventPage:
	if is_instance_valid(ingame_event) and is_instance_valid(ingame_event.lpc_event):
		if "current_event_page" in ingame_event.lpc_event:
			return ingame_event.lpc_event.current_event_page
	return null


## Verifies if an event contains variables or configurations related to missions.
func _event_has_quest_data(ingame_event: IngameEvent) -> bool:
	var event_res = _get_event_resource(ingame_event)
	return event_res and not event_res.quests.is_empty()


## Retrieves a quest resource from the main database by its ID.
func _get_quest_from_database(quest_id: int) -> RPGQuest:
	for q in RPGSYSTEM.database.quests:
		if q and q.id == quest_id: return q
	return null


## Retrieves an active quest from the current progression state by its ID.
func _get_active_quest_by_id(quest_id: int) -> GameQuest:
	if not GameManager.game_state: return null
	for q in GameManager.game_state.quest_progress.active_quests:
		if q.id == quest_id: return q
	return null


## Verifies if an RPGMapEventID object contains valid targeting data.
func _is_custom_page_valid(page_id: RPGMapEventID) -> bool:
	return page_id and page_id.map_id != -1 and page_id.event_id != -1 and page_id.event_page_id != -1


## Retrieves the command list from a specific RPGMapEventID configuration safely searching the map and migrated events.
func _get_commands_from_custom_page(page_id: RPGMapEventID) -> Array[RPGEventCommand]:
	if not page_id or page_id.event_id == -1: return []
	if GameManager.current_map:
		var ingame_event = GameManager.current_map.get_in_game_event_by_uniq_id(page_id.event_id, true)
		if ingame_event and ingame_event.event:
			for page in ingame_event.event.pages:
				if page._uniq_id == page_id.event_page_id: return page.list
	return []


## Retrieves the command list from a local event page by its index.
func _get_commands_from_page_index(_ingame_event: IngameEvent, _page_index: int) -> Array[RPGEventCommand]:
	return []


## Finds the local RPGEventPQuest configuration from an owner event.
func _get_event_pquest_data_from_owner(ingame_event: IngameEvent, quest_id: int) -> RPGEventPQuest:
	var event_res = _get_event_resource(ingame_event)
	if event_res:
		for q in event_res.quests:
			if q.id == quest_id: return q
	return null


## Extracts the specific quest dialogues and settings from the original NPC who gave the quest.
func _get_owner_quest_configuration(active_quest: GameQuest) -> RPGEventPQuest:
	if not active_quest: return null
	var owner_uniq_id = active_quest.owner_event_uniq_id
	var owner_ingame_event = GameManager.current_map.get_in_game_event_by_uniq_id(owner_uniq_id, true)
	var event_res = _get_event_resource(owner_ingame_event)
	if event_res:
		for q in event_res.quests:
			if q.id == active_quest.id: return q
	return null


## Validates all GATHER_ITEM quests dynamically based on current inventory.
func _validate_gather_quests() -> void:
	for active_quest in active_quests:
		if active_quest.status == GameQuest.QuestStatus.FAILED_PENDING_DELIVERY:
			continue
			
		var db_quest = _get_quest_from_database(active_quest.id)
		if db_quest and db_quest.type == RPGQuest.QuestMode.GATHER_ITEM:
			var is_ready = _is_gather_quest_ready(db_quest)
			
			if is_ready and active_quest.status == GameQuest.QuestStatus.ACTIVE:
				active_quest.status = GameQuest.QuestStatus.COMPLETED_PENDING_DELIVERY
				
				if show_debug_prints:
					print("[QuestManager] GATHER_ITEM Objective met for Quest ID: ", active_quest.id)
					
				var parent_quest = _get_parent_active_quest(active_quest.id)
				var check_id = parent_quest.id if parent_quest else active_quest.id
				
				if _is_cluster_ready_to_deliver(check_id):
					var p_active = _get_active_quest_by_id(check_id)
					var pquest = _get_owner_quest_configuration(p_active)
					if pquest and not _is_custom_page_valid(pquest.target_page):
						complete_mission(p_active)
						
			elif not is_ready and active_quest.status == GameQuest.QuestStatus.COMPLETED_PENDING_DELIVERY:
				active_quest.status = GameQuest.QuestStatus.ACTIVE
				
				if show_debug_prints:
					print("[QuestManager] GATHER_ITEM Objective lost for Quest ID: ", active_quest.id)


## Checks if the inventory contains the required items for a GATHER_ITEM quest.
func _is_gather_quest_ready(db_quest: RPGQuest) -> bool:
	var amount = 0
	
	match db_quest.item_type:
		0:
			amount = GameManager.get_item_amount(db_quest.item_id)
		1:
			amount = GameManager.get_weapon_amount(db_quest.item_id)
		2:
			amount = GameManager.get_armor_amount(db_quest.item_id)
		3:
			amount = GameManager.get_costume_amount(db_quest.item_id)
			
	return amount >= db_quest.item_quantity
#endregion


#region FALLBACK COMMANDS GENERATION
## Generates the interpreter command array for starting a quest via fallback dialogue.
func _generate_fallback_start_commands(event_quest: RPGEventPQuest) -> Array[RPGEventCommand]:
	var cmds: Array[RPGEventCommand] = []
	if event_quest.dialogue_on_start != "":
		cmds.append_array(_create_message_commands(event_quest.dialogue_on_start))
	if event_quest.use_confirm_message:
		var cmd_choices = RPGEventCommand.new()
		cmd_choices.code = 4
		cmd_choices.parameters = {"cancel": 1, "default": 1, "max_choices": 4.0, "position": 5, "use_message_bounds": true}
		cmds.append(cmd_choices)
		var cmd_yes = RPGEventCommand.new()
		cmd_yes.code = 5
		cmd_yes.parameters = {"name": event_quest.confirm_ok_option}
		cmds.append(cmd_yes)
		cmds.append(_create_change_quest_state_command(event_quest.id, 1))
		var cmd_end_yes = RPGEventCommand.new()
		cmd_end_yes.code = 0
		cmds.append(cmd_end_yes)
		var cmd_no = RPGEventCommand.new()
		cmd_no.code = 5
		cmd_no.parameters = {"name": event_quest.confirm_cancel_option}
		cmds.append(cmd_no)
		var cmd_end_no = RPGEventCommand.new()
		cmd_end_no.code = 0
		cmds.append(cmd_end_no)
		var cmd_end_all = RPGEventCommand.new()
		cmd_end_all.code = 7
		cmds.append(cmd_end_all)
	return cmds


## Generates the interpreter command array for delivering a completed quest via fallback dialogue.
func _generate_fallback_finish_commands(event_quest: RPGEventPQuest, _active_quest: GameQuest) -> Array[RPGEventCommand]:
	var cmds: Array[RPGEventCommand] = []
	if event_quest.dialogue_on_finish != "":
		cmds.append_array(_create_message_commands(event_quest.dialogue_on_finish))
	return cmds


## Generates the interpreter command array for reporting a failed quest via fallback dialogue.
func _generate_fallback_fail_commands(event_quest: RPGEventPQuest, _active_quest: GameQuest) -> Array[RPGEventCommand]:
	var cmds: Array[RPGEventCommand] = []
	if event_quest.dialogue_on_failure != "":
		cmds.append_array(_create_message_commands(event_quest.dialogue_on_failure))
	return cmds


## Helper function to convert a multiline string into a sequence of RPGEventCommand message commands.
func _create_message_commands(text: String) -> Array[RPGEventCommand]:
	var cmds: Array[RPGEventCommand] = []
	var cmd_msg_setup = RPGEventCommand.new()
	cmd_msg_setup.code = 2
	cmd_msg_setup.parameters = {"character_name": {"type": 0, "value": ""}, "face": null, "height": 0.0, "is_floating_dialog": false, "position": 0, "width": 0.0}
	cmds.append(cmd_msg_setup)
	var lines = text.split("\n")
	for line in lines:
		var cmd_line = RPGEventCommand.new()
		cmd_line.code = 3
		cmd_line.parameters = {"line": line}
		cmds.append(cmd_line)
	return cmds


## Creates the specific interpreter command to mutate the state of a quest (Start, Fail, Complete).
func _create_change_quest_state_command(quest_id: int, new_state: int) -> RPGEventCommand:
	var cmd = RPGEventCommand.new()
	cmd.code = -1
	cmd.parameters = {"quest_id": quest_id, "state": new_state}
	return cmd
#endregion


#region INTERPRETER COMMANDS
## Master function to process Interpreter Command 126 (Quest Operations).
func execute_interpreter_command_manage_quest(params: Dictionary) -> void:
	if not GameManager.game_state:
		return
		
	var op_type = params.get("operation_type", 0)
	var scope = params.get("quest_scope", 0)
	var owner_id = params.get("event_id", -1)
	
	var target_ids: Array = []
	if scope == 0:
		target_ids = params.get("global_ids", [])
	else:
		target_ids = params.get("specific_ids", [])
		
	for q_id in target_ids:
		match op_type:
			0:
				if not _get_active_quest_by_id(q_id) and not GameManager.game_state.stats.missions.historical_dictionary.has(q_id):
					var target_uniq = _get_target_uniq_id_from_db(q_id)
					accept_quest(q_id, owner_id, target_uniq)
					
			1:
				_cancel_mission(q_id)
				
			2:
				var active_q = _get_active_quest_by_id(q_id)
				if active_q:
					complete_mission(active_q)
					
			3:
				var active_q = _get_active_quest_by_id(q_id)
				if active_q:
					fail_mission(active_q)
					
			4:
				GameManager.game_state.quest_progress.unlocked_quests[q_id] = true
				if show_debug_prints:
					print("[QuestManager] Command 126: Unlocked Quest ID ", q_id)
				_is_dirty = true
				
			5:
				_reset_mission(q_id)
				
			6:
				var progress_val = params.get("progress", 0.0)
				update_user_quest_progress(q_id, progress_val)
#endregion


#region INTERPRETER COMMAND HELPERS
## Updates the internal progress of a USER_QUEST.
func update_user_quest_progress(quest_id: int, added_progress: float) -> void:
	var active_quest = _get_active_quest_by_id(quest_id)
	
	if not active_quest or active_quest.status != GameQuest.QuestStatus.ACTIVE:
		return
		
	var db_quest = _get_quest_from_database(quest_id)
	if not db_quest or db_quest.type != RPGQuest.QuestMode.USER_QUEST:
		return
		
	active_quest.current_progress = clamp(active_quest.current_progress + added_progress, 0.0, 1.0)
	
	if show_debug_prints:
		print("[QuestManager] USER_QUEST ID ", quest_id, " progress updated to: ", active_quest.current_progress)
	
	if active_quest.current_progress >= 1.0:
		if show_debug_prints:
			print("[QuestManager] USER_QUEST ID ", quest_id, " reached 1.0! Ready to deliver.")
			
		active_quest.status = GameQuest.QuestStatus.COMPLETED_PENDING_DELIVERY
		
		var parent_quest = _get_parent_active_quest(active_quest.id)
		var check_id = parent_quest.id if parent_quest else active_quest.id
					
		if _is_cluster_ready_to_deliver(check_id):
			var p_active = _get_active_quest_by_id(check_id)
			var pquest = _get_owner_quest_configuration(p_active)
			
			if pquest and not _is_custom_page_valid(pquest.target_page):
				if show_debug_prints:
					print("[QuestManager] Cluster fully completed. Auto-delivering Quest ID: ", check_id)
				complete_mission(p_active)
				return
				
	_is_dirty = true


## Silently removes a quest from the active list without sending it to the historical record.
func _cancel_mission(quest_id: int) -> void:
	var db_quest = _get_quest_from_database(quest_id)
	if db_quest:
		for sub_id in db_quest.multi_quests:
			_cancel_mission(sub_id)
			
	var progress_array = GameManager.game_state.quest_progress.active_quests
	for i in range(progress_array.size() - 1, -1, -1):
		if progress_array[i].id == quest_id:
			progress_array.remove_at(i)
			GameManager.game_state.stats.missions.in_progress -= 1
			
			if show_debug_prints:
				print("[QuestManager] Command 126: Cancelled active Quest ID ", quest_id)
				
			_is_dirty = true
			break


## Wipes all memory of a quest, removing it from active arrays and the historical dictionary.
func _reset_mission(quest_id: int) -> void:
	var db_quest = _get_quest_from_database(quest_id)
	if db_quest:
		for sub_id in db_quest.multi_quests:
			_reset_mission(sub_id)
			
	_cancel_mission(quest_id)
	
	var historical = GameManager.game_state.stats.missions.historical_dictionary
	if historical.has(quest_id):
		historical.erase(quest_id)
		
	var results_array = GameManager.game_state.stats.missions.missions
	for i in range(results_array.size() - 1, -1, -1):
		if results_array[i].id == quest_id:
			results_array.remove_at(i)
			
	if show_debug_prints:
		print("[QuestManager] Command 126: Completely RESET Quest ID ", quest_id)
		
	_is_dirty = true
#endregion
