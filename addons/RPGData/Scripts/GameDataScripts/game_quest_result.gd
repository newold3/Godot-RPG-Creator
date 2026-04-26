class_name GameQuestResult
extends Resource

enum FinalResult {
	SUCCESS,
	FAILED
}

## Real ID of this quest in database
@export var id: int = -1

## Unique 16-digit ID of the map where this quest was obtained
@export var owner_map_uniq_id: int = -1

## Unique 16-digit ID of the event that gave this quest
@export var owner_event_uniq_id: int = -1

## Quest status (fail, success)
@export var status: FinalResult = FinalResult.SUCCESS

## Date on which this quest was completed / failed (Unix timestamp)
@export var quest_completed_at: float = 0.0


## Initializes the result from an active quest
func generate_from_active_quest(quest: GameQuest, final_status: FinalResult) -> void:
	id = quest.id
	owner_map_uniq_id = quest.owner_map_uniq_id
	owner_event_uniq_id = quest.owner_event_uniq_id
	status = final_status
	quest_completed_at = Time.get_unix_time_from_system()
