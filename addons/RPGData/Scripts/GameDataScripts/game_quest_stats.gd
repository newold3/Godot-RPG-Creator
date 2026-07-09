class_name GameQuestStats
extends Resource

@export var completed: int = 0
@export var in_progress: int = 0
@export var failed: int = 0
@export var total_found: int = 0
@export var quests: Array[GameQuestResult] = []

## Dictionary for ultra-fast lookup of quest final states.
## Key: Quest ID (int) -> Value: FinalResult (int/enum)
@export var historical_dictionary: Dictionary = {}
