class_name GameQuest
extends Resource

## Real ID of this quest in database
@export var id: int = -1
## Quick access to quest type
@export var qyest_type: int = 0
## ID of the map where this quest was obtained
@export var owner_map_id: int = -1
## ID of the event that gave this quest
@export var owner_event_id: int = -1
## flag to indicate that this quest is complete
@export var completed: bool = false
## Map required to complete this quest
@export var target_map_id: int = -1
## Event required to complete this quest
@export var target_event_id: int = -1
## timer required to complete this quest
@export var timer: int = -1
