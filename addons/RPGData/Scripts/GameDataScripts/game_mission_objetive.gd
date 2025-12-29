class_name GameMissionObjective
extends Resource

@export var description: String
@export var required_amount: int
@export var current_amount: int
@export var is_completed: bool


func _init(desc: String, req: int) -> void:
	description = desc
	required_amount = req
	current_amount = 0
	is_completed = false


func update_progress(amount: int) -> void:
	current_amount += amount
	if current_amount >= required_amount:
		is_completed = true
