class_name GameQuestProgress
extends Resource

## Array containing the quests currently active and in progress.
@export var active_quests: Array[GameQuest] = []

## Dictionary for ultra-fast lookup of unlocked quest IDs.
## Key: Quest ID (int) -> Value: true (bool)
@export var unlocked_quests: Dictionary = {}
