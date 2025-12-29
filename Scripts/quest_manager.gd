extends Node


var active_quests: Array[GameQuest] = []


func setp_active_quest() -> void:
	if GameManager.game_state:
		active_quests = GameManager.game_state.active_misions


func update_quests() -> void:
	pass


func add_active_mission(quest: GameQuest) -> void:
	active_quests.append(quest)


func manage_mission_for_event(_event: RPGEvent) -> bool:
	return false


func can_start_any_mission_for(_event: RPGEvent) -> bool:
	return false


func can_finish_any_mission_for(_event: RPGEvent) -> bool:
	return false


func start_next_quest_available_for(_event: RPGEvent) -> void:
	pass


func complete_mission() -> void:
	pass
