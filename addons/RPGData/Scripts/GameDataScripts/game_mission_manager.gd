extends Node

signal mission_started(mission: GameMission)
signal mission_completed(mission: GameMission)
signal mission_failed(mission: GameMission)
signal mission_progress_updated(mission: GameMission, progress: float)
signal mission_ready_to_complete(mission: GameMission)
signal mission_unlocked(mission_id: int)
signal mission_chain_completed(missions: Array[GameMission])

var _missions: Dictionary = {}  # Dictionary of all missions, keyed by mission ID (int)
var unlocked_missions: Array[int] = []
var active_missions: Array[GameMission] = []

# Save/Load system integration
signal save_requested
signal load_completed
signal mission_time_limit_expired(mission: GameMission)


func _ready() -> void:
	pass


func _process(delta: float) -> void:
	# Process timer for timed missions
	for mission in active_missions:
		if mission.state == GameMission.MissionState.IN_PROGRESS:
			if mission.is_timer_quest:
				process_timer_mission(mission, delta)


func process_timer_mission(mission: GameMission, delta: float) -> void:
	mission.time_remaining -= delta
	if mission.time_remaining <= 0:
		mission.time_remaining = 0
		fail_mission(mission.quest_id)
		mission_time_limit_expired.emit(mission)
		return
	
	# Update progress based on time
	var quest_data = mission.get_quest_data()
	if quest_data and quest_data.time_limit > 0:
		mission.progress = 1.0 - (mission.time_remaining / quest_data.time_limit)
		mission.progress = clampf(mission.progress, 0.0, 1.0)
		
		# Emit signals
		mission.mission_progress_updated.emit(mission.progress)
		mission_progress_updated.emit(mission, mission.progress)


func unlock_mission(mission_id: int) -> void:
	if not unlocked_missions.has(mission_id):
		unlocked_missions.append(mission_id)
		mission_unlocked.emit(mission_id)


func is_mission_unlocked(mission_id: int) -> bool:
	return unlocked_missions.has(mission_id)


func add_mission(mission_id: int, force_unlock: bool = true) -> bool:
	if RPGSYSTEM.database.quests.size() > mission_id:
		# First we unlock the mission if it is not already unlocked.
		if not is_mission_unlocked(mission_id):
			if force_unlock or RPGSYSTEM.database.quests[mission_id].default_unlocked:
				unlock_mission(mission_id)
			else:
				return false
		
		# We obtain or create the mission
		var mission = get_mission(mission_id)
		if not mission:
			mission = create_mission(mission_id)
			_missions[mission_id] = mission
		
		# We check if the mission is available
		if not is_mission_available(mission):
			return false
		
		# Start the mission
		start_mission(mission_id)

		return true
	
	return false


func create_mission(quest_id: int) -> GameMission:
	var mission = GameMission.new(quest_id)
	return mission


func start_mission(quest_id: int) -> void:
	if _missions.has(quest_id):
		var mission = _missions[quest_id]
		if is_mission_available(mission):
			# Change state to in progress
			mission.update_state(GameMission.MissionState.IN_PROGRESS)
			
			# Add to active missions
			if not active_missions.has(mission):
				active_missions.append(mission)
			
			# If this is a multi-quest, also activate sub-missions
			if mission.is_multi_quest:
				for sub_mission in mission.sub_missions:
					sub_mission.update_state(GameMission.MissionState.IN_PROGRESS)
			
			# Emit signal
			mission_started.emit(mission)


func cancel_mission(quest_id: int, force_cancel: bool = false) -> void:
	if _missions.has(quest_id):
		var mission = _missions[quest_id]
		
		# Only cancel if in progress or if forced
		if force_cancel or mission.state == GameMission.MissionState.IN_PROGRESS:
			# Reset the mission
			mission.reset()
			
			# Remove from active missions
			active_missions.erase(mission)
			
			# Emit signal (you could add this)
			# emit_signal("mission_cancelled", mission)


func is_mission_available(mission: GameMission) -> bool:
	var quest_data = mission.get_quest_data()
	if not quest_data:
		return false
		
	# Check if mission is already active or completed
	if mission.state != GameMission.MissionState.NOT_STARTED:
		return false
		
	# Check if mission is unlocked
	if not unlocked_missions.has(mission.quest_id):
		return false
		
	# Check if all prerequisites are completed
	for prereq_id in quest_data.prerequisites:
		if not is_mission_completed(prereq_id):
			return false
	
	# Check party level if required
	if quest_data.min_level > 0:
		var party_level = _get_party_level()
		if party_level < quest_data.min_level:
			return false
	
	return true


func _get_party_level() -> int:
	var party_level: int = 0
	if GameManager.game_state:
		for actor: GameActor in GameManager.game_state.actors.values():
			party_level = max(party_level, actor.current_level)
	
	return party_level


## Updates all relevant active missions when an item is collected, location visited, etc.
## @param item_type: The type of data (RPGQuest.ItemType.ITEM, WEAPON, ARMOR, ENEMY)
## @param item_id: The ID of the specific item or location
## @param amount: The amount to increase (defaults to 1)
func update_mission_objective(item_type: RPGQuest.ItemType, item_id: int, amount: int = 1) -> void:
	# Check all active missions
	for mission in active_missions:
		if mission.state != GameMission.MissionState.IN_PROGRESS:
			continue
			
		var quest_data = mission.get_quest_data()
		if not quest_data:
			continue
			
		# Check if this item/location is relevant to this mission
		match quest_data.type:
			RPGQuest.QuestMode.GATHER_ITEM, RPGQuest.QuestMode.BOUNTY_HUNTS:
				# Check if both type and ID match
				if quest_data.item_type == item_type and quest_data.item_id == item_id:
					# Update progress
					mission.current_quantity += amount
					var new_progress = mission.progress + (float(mission.current_quantity) / quest_data.quantity)
					mission.progress = clampf(new_progress, 0.0, 1.0)
					
					# Check if objective is completed
					if mission.progress >= 1.0:
						mark_mission_ready_to_complete(mission)
					
					# Update progress signal
					mission.mission_progress_updated.emit(mission.progress)
					mission_progress_updated.emit(mission, mission.progress)


## Updates all relevant active missions using progress value(This only affects quests of type RPGQuest.QuestMode.USER_QUEST.).
## @param mission_id: The ID of the specific mission
## @param progress: The amount to increase the current progress of the mission.
func update_mission_progress(mission_id: int, progress: float = 0.01) -> void:
	if _missions.has(mission_id):
		var mission = _missions[mission_id]
		var quest_data = mission.get_quest_data()
		
		if not quest_data or mission.state != GameMission.MissionState.IN_PROGRESS:
			return
			
		# This is only for USER_QUEST type quests
		if quest_data.type == RPGQuest.QuestMode.USER_QUEST:
			# Add progress
			mission.progress += progress
			
			# Clamp between 0 and 1
			mission.progress = clampf(mission.progress, 0.0, 1.0)
			
			# Check if quest is now complete
			if mission.progress >= quest_data.progress:
				mark_mission_ready_to_complete(mission)
			
			# Emit signals
			mission.mission_progress_updated.emit(mission.progress)
			mission_progress_updated.emit(mission, mission.progress)


func update_talk_to_npc_objective(map_id: int, event_id: int) -> void:
	# Check all active missions
	for mission in active_missions:
		if mission.state != GameMission.MissionState.IN_PROGRESS:
			continue
			
		var quest_data = mission.get_quest_data()
		if not quest_data:
			continue
			
		# Check if this NPC is relevant to this mission
		if quest_data.type == RPGQuest.QuestMode.TALK_TO_NPC and quest_data.target_event.map_id == map_id and quest_data.target_event.event_id == event_id:
			mission.progress = 1.0
			mark_mission_ready_to_complete(mission)
			
			# Update progress signal
			mission.mission_progress_updated.emit(mission.progress)
			mission_progress_updated.emit(mission, mission.progress)


func update_find_location_objective(map_id: int) -> void:
	# Check all active missions
	for mission in active_missions:
		if mission.state != GameMission.MissionState.IN_PROGRESS:
			continue
			
		var quest_data = mission.get_quest_data()
		if not quest_data:
			continue
			
		# Check if this NPC is relevant to this mission
		if quest_data.type == RPGQuest.QuestMode.FIND_LOCATION and quest_data.item_id == map_id:
			mission.progress = 1.0
			mark_mission_ready_to_complete(mission)
			
			# Update progress signal
			mission.mission_progress_updated.emit(mission.progress)
			mission_progress_updated.emit(mission, mission.progress)


func mark_mission_ready_to_complete(mission: GameMission) -> void:
	# For multi-quests, we need to check if all sub-missions are ready
	if mission.is_multi_quest and not mission.are_all_sub_missions_ready():
		return
		
	mission.update_state(GameMission.MissionState.READY_TO_COMPLETE)
	mission_ready_to_complete.emit(mission)


## Completes a mission if it's ready to complete or if force_completion is true
## @param quest_id: The ID of the quest to complete
## @param force_completion: If true, completes the mission regardless of its current state
func complete_mission(quest_id: int, force_completion: bool = false) -> void:
	if _missions.has(quest_id):
		var mission = _missions[quest_id]
		
		# Check if mission can be completed
		if (mission.state == GameMission.MissionState.READY_TO_COMPLETE || 
		   (force_completion && mission.state != GameMission.MissionState.COMPLETED)):
			
			# Update mission state
			mission.update_state(GameMission.MissionState.COMPLETED)
			
			# Remove from active missions
			active_missions.erase(mission)
			
			# Handle mission rewards
			_give_mission_rewards(mission)
			
			# Handle unlocking next missions
			_handle_mission_unlocks(mission)
			
			# Emit completion signal
			mission_completed.emit(mission)


func _handle_mission_unlocks(mission: GameMission) -> void:
	var quest_data = mission.get_quest_data()
	if not quest_data:
		return
		
	# Unlock next missions
	for next_quest_id in quest_data.quests_unlocked:
		unlock_mission(next_quest_id)
		
	# Auto-start next mission in chain if specified
	if mission.is_chain_quest:
		var next_mission_id = quest_data.is_chain_quest
		start_mission(next_mission_id)


func _give_mission_rewards(mission: GameMission) -> void:
	var quest_data = mission.get_quest_data()
	if not quest_data or not quest_data.reward:
		return
		
	# Add experience
	if quest_data.reward.experience > 0:
		RPGSYSTEM.player.add_exp(quest_data.reward.experience)
	
	# Add gold
	if quest_data.reward.gold > 0:
		RPGSYSTEM.player.add_gold(quest_data.reward.gold)
	
	# Add items
	for item in quest_data.reward.items:
		RPGSYSTEM.inventory.add_item(item.id, item.amount)
	
	# If this is a multi-quest, also give rewards for sub-missions
	if mission.is_multi_quest:
		for sub_mission in mission.sub_missions:
			var sub_quest_data = sub_mission.get_quest_data()
			if sub_quest_data and sub_quest_data.reward:
				# Add experience
				if sub_quest_data.reward.experience > 0:
					RPGSYSTEM.player.add_exp(sub_quest_data.reward.experience)
				
				# Add gold
				if sub_quest_data.reward.gold > 0:
					RPGSYSTEM.player.add_gold(sub_quest_data.reward.gold)
				
				# Add items
				for item in sub_quest_data.reward.items:
					RPGSYSTEM.inventory.add_item(item.id, item.amount)


func fail_mission(quest_id: int) -> void:
	if _missions.has(quest_id):
		var mission = _missions[quest_id]
		
		# Update state
		mission.update_state(GameMission.MissionState.FAILED)
		
		# Remove from active missions
		active_missions.erase(mission)
		
		# Emit signal
		mission_failed.emit(mission)


# Mission tracking functions
func get_mission(quest_id: int) -> GameMission:
	return _missions.get(quest_id, null)


func get_active_missions() -> Array[GameMission]:
	return active_missions


func get_available_missions() -> Array[GameMission]:
	var available = []
	for mission_id in unlocked_missions:
		if _missions.has(mission_id):
			var mission = _missions[mission_id]
			if is_mission_available(mission):
				available.append(mission)
		else:
			var mission = create_mission(mission_id)
			if is_mission_available(mission):
				available.append(mission)
	return available


func is_mission_completed(quest_id: int) -> bool:
	return _missions.has(quest_id) and _missions[quest_id].state == GameMission.MissionState.COMPLETED


func reset_mission(quest_id: int) -> void:
	if _missions.has(quest_id):
		var mission = _missions[quest_id]
		
		# If already active, remove from active list
		if mission.state == GameMission.MissionState.IN_PROGRESS:
			active_missions.erase(mission)
		
		# Reset the mission
		mission.reset()


func load_data(loaded_missions: Array[GameMission]) -> void:
	# Clear current mission data
	_missions.clear()
	active_missions.clear()
	unlocked_missions.clear()
	
	# Process each loaded mission
	for mission in loaded_missions:
		# Add to missions dictionary
		_missions[mission.quest_id] = mission
		
		# Reconnect signals
		if not mission.mission_state_changed.is_connected(_on_mission_state_changed):
			mission.mission_state_changed.connect(_on_mission_state_changed.bind(mission))
		if not mission.mission_progress_updated.is_connected(_on_mission_progress_updated):
			mission.mission_progress_updated.connect(_on_mission_progress_updated.bind(mission))
		
		# Update unlocked missions list
		if not unlocked_missions.has(mission.quest_id):
			unlocked_missions.append(mission.quest_id)
		
		# Add to active missions if in progress
		if mission.state == GameMission.MissionState.IN_PROGRESS:
			active_missions.append(mission)


func get_data() -> Array[GameMission]:
	# Create a copy of all missions for saving
	var missions_to_save: Array[GameMission] = []
	
	# Add all missions from the dictionary to the save array
	for mission_id in _missions:
		missions_to_save.append(_missions[mission_id])
	
	return missions_to_save


func _on_mission_state_changed(new_state: GameMission.MissionState, mission: GameMission) -> void:
	# This is a relay for the individual mission signals
	# No additional logic needed since it's handled in change_mission_state
	pass


func _on_mission_progress_updated(new_progress: float, mission: GameMission) -> void:
	# This is a relay for the individual mission signals
	# No additional logic needed
	pass
