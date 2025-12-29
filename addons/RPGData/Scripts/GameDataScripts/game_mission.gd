@tool
class_name GameMission
extends Resource

enum MissionState {NOT_STARTED, IN_PROGRESS, READY_TO_COMPLETE, COMPLETED, FAILED}

# Core identifier - allows lookup in the database
@export var quest_id: int = 0

# Which event starts this quest? "MapID_EventID"1
@export var owner: String = ""

# Runtime state tracking
@export var state: MissionState = MissionState.NOT_STARTED
@export var progress: float = 0.0  ## Progress from 0.0 to 1.0 (used in USER_QUEST)
@export var current_quantity: int = 0  ## Track the current quantity for quests of the type TALK_TO_NPC, GATHER_ITEM, BOUNTY_HUNTS, or FIND_LOCATION.
@export var time_remaining: float = 0.0  ## For timed quests (used in TIMER_QUEST)

# Multi-mission handling
@export var is_chain_quest: bool = false  # Part of a quest chain
@export var is_multi_quest: bool = false  # Has multiple objectives
@export var is_timer_quest: bool = false  # The quest has a timer to be finished or it will fail.
@export var sub_missions: Array[GameMission] = []  # Child missions for multi-quests


# Signals
signal mission_state_changed(new_state: MissionState)
signal mission_progress_updated(new_progress: float)


func _init(quest_id: int = 0) -> void:
	self.quest_id = quest_id
	self.progress = 0.0
	_set_flags()
	_initialize_time()
	
	if is_multi_quest:
		_initialize_sub_missions()


func get_quest_data() -> RPGQuest:
	if RPGSYSTEM.database.quests.size() > quest_id:
		return RPGSYSTEM.database.quests[quest_id]
	else:
		return null


func _set_flags() -> void:
	var quest_data: RPGQuest = get_quest_data()
	if quest_data:
		# Check if this is part of a quest chain
		is_chain_quest = quest_data.chain_mission_id != 0
		
		# Check if this is a multi-quest (has multiple objectives)
		is_multi_quest = quest_data.multi_quests.size() > 0
		
		# Check if this is a timer mission
		is_timer_quest = quest_data.time_limit > 0
	else:
		is_chain_quest = false
		is_multi_quest = false
		is_timer_quest = false


func _initialize_time() -> void:
	var quest_data: RPGQuest = get_quest_data()
	if is_timer_quest:
		time_remaining = quest_data.time_limit


func _initialize_sub_missions() -> void:
	var quest_data: RPGQuest = get_quest_data()
	if quest_data and is_multi_quest:
		sub_missions.clear()
		
		# Create sub-missions for each quest in multi_quests
		for sub_quest_id in quest_data.multi_quests:
			if sub_quest_id != quest_id:  # Don't include self
				var sub_mission = GameMission.new(sub_quest_id)
				sub_missions.append(sub_mission)


func update_progress(additional_progress: float) -> void:
	var quest_data: RPGQuest = get_quest_data()
	if not quest_data:
		return
		
	if quest_data.type == RPGQuest.QuestMode.USER_QUEST:
		# Add progress
		progress += additional_progress
		
		# Clamp between 0 and 1
		progress = clampf(progress, 0.0, 1.0)
		
		# Emit signal
		mission_progress_updated.emit(progress)
		
		# Check if complete
		if progress >= 1.0 and state == MissionState.IN_PROGRESS:
			state = MissionState.READY_TO_COMPLETE
			mission_state_changed.emit(state)


func calculate_progress() -> float:
	var quest_data: RPGQuest = get_quest_data()
	if not quest_data:
		return 0.0
	
	# For multi-quests, calculate average progress of all sub-missions
	if is_multi_quest and sub_missions.size() > 0:
		var total_progress: float = progress  # Include main mission progress
		var mission_count: int = 1  # Start with 1 for main mission
		
		for sub_mission in sub_missions:
			total_progress += sub_mission.progress
			mission_count += 1
			
		return total_progress / mission_count
	
	# For single quests, return direct progress
	return progress


func update_state(new_state: MissionState) -> void:
	if state != new_state:
		state = new_state
		mission_state_changed.emit(state)
		
		# If this is a multi-quest, propagate state to sub-missions
		if is_multi_quest and (new_state == MissionState.COMPLETED or new_state == MissionState.FAILED):
			for sub_mission in sub_missions:
				sub_mission.update_state(new_state)


func are_all_sub_missions_ready() -> bool:
	if not is_multi_quest or sub_missions.size() == 0:
		return true
		
	# Check if all sub-missions are ready to complete
	for sub_mission in sub_missions:
		if sub_mission.state != MissionState.READY_TO_COMPLETE:
			return false
			
	return true


func reset() -> void:
	state = MissionState.NOT_STARTED
	progress = 0.0
	
	# Reset timer if needed
	var quest_data: RPGQuest = get_quest_data()
	if is_timer_quest:
		time_remaining = quest_data.time_limit
	
	# Reset sub-missions if this is a multi-quest
	if is_multi_quest:
		for sub_mission in sub_missions:
			sub_mission.reset()


func clone(deep: bool = true) -> GameMission:
	var new_mission = duplicate(deep)
	
	# Clone sub-missions
	if deep and is_multi_quest:
		new_mission.sub_missions = []
		for sub_mission in sub_missions:
			new_mission.sub_missions.append(sub_mission.clone(deep))
			
	return new_mission
