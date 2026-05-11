class_name GameQuest
extends Resource

enum QuestStatus {
	ACTIVE,
	COMPLETED_PENDING_DELIVERY,
	FAILED_PENDING_DELIVERY
}

## Unique ID of the specific local event configuration (RPGEventPQuest) that started this quest.
@export var owner_pquest_uniq_id: int = -1

## Real ID of this quest in database
@export var id: int = -1

## Quick access to quest type
@export var quest_type: int = 0

## Current status of the quest
@export var status: QuestStatus = QuestStatus.ACTIVE

## Unique 16-digit ID of the map where this quest was obtained
@export var owner_map_uniq_id: int = -1

## Unique 16-digit ID of the event that gave this quest
@export var owner_event_uniq_id: int = -1

## This quest is sub-mission (objetive to the other mission)
@export var parent_quest_id: int = -1

## Unique 16-digit ID of the map required to complete this quest
@export var target_map_uniq_id: int = -1

## Unique 16-digit ID of the event required to complete this quest
@export var target_event_uniq_id: int = -1

## Timer required to complete this quest (in seconds remaining)
@export var timer: float = -1.0

## Tracks quantity of items gathered, enemies killed, or custom progress
@export var current_progress: float = 0.0


## Returns true if the quest is ready to be turned in to an NPC
func is_ready_for_delivery() -> bool:
	return status == QuestStatus.COMPLETED_PENDING_DELIVERY or status == QuestStatus.FAILED_PENDING_DELIVERY
