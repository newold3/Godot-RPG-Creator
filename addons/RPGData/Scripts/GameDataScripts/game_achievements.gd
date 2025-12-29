class_name GameAchievement
extends Resource


enum STATE {COMPLETE, UNFINISHED}

@export var id: int = 0 # Unique identifier for this achievement
@export var name: String = "" # Achievement name
@export var description: String = "" # Achievement description
@export var state: STATE = STATE.UNFINISHED # Current achievement state
@export var progress: float = 0.0 # Achievement progress (0.0 to 1.0)
@export var first_time_achieved: float = 0.0 # Timestamp when first achieved

signal complete_achievement(res: Resource)

func update_progress(value: float) -> void:
	if state != STATE.COMPLETE:
		progress += value
		if progress >= 1.0:
			progress = 1.0
			first_time_achieved = Time.get_unix_time_from_system()
			state = STATE.COMPLETE
			complete_achievement.emit(self)
