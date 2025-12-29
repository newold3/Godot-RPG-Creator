class_name GameQuestResult
extends Resource

## Real ID of this quest in database
@export var id: int = -1
## ID of the map where this quest was obtained
@export var owner_map_id: int = -1
## ID of the event that gave this quest
@export var owner_event_id: int = -1
## Quest status (fail, success)
@export var status: int = 0
## Date on which this quest was completed / failed
@export var quest_completed_at: float = 0.0
