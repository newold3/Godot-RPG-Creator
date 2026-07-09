class_name GameQuestResult
extends Resource

const FinalResult = RPGEnums.QuestResult

## Real ID of this quest in database
@export var id: int = -1

## Unique 16-digit ID of the map where this quest was obtained
@export var owner_map_uniq_id: int = -1

## Unique 16-digit ID of the event that gave this quest
@export var owner_event_uniq_id: int = -1

## Quest status (fail, success, cancelled)
@export var status: FinalResult = FinalResult.SUCCESS

## How many times has this quest been recorded with this status
@export var count: int = 1

## Date on which this quest was last completed / failed (Unix timestamp)
@export var quest_completed_at: float = 0.0


## Initializes the result from an active quest
func generate_from_active_quest(quest: GameQuest, final_status: FinalResult) -> void:
	id = quest.id
	owner_map_uniq_id = quest.owner_map_uniq_id
	owner_event_uniq_id = quest.owner_event_uniq_id
	status = final_status
	count = 1
	quest_completed_at = Time.get_unix_time_from_system()
