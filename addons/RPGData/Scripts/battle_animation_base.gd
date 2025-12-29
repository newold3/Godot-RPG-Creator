@tool
class_name BattleAnimation
extends AnimatedSprite2D


var is_in_editor: bool = false


func get_class() -> String: return "BattleAnimation"
func get_custom_class() -> String: return "BattleAnimation"


func exit() -> void:
	queue_free()
