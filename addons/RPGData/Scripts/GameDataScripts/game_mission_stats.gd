class_name GameMissionStats
extends Resource


@export var completed: int = 0 # Number of missions completed
@export var in_progress: int = 0 # Number of missions currently in progress
@export var failed: int = 0 # Number of missions failed
@export var total_found: int = 0 # Total number of missions discovered
@export var missions: Array[GameQuestResult] = []
