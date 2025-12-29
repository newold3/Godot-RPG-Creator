@tool
class_name GameTransition
extends Control

## Create a Control and add a script that extends GameTransition
## so that when saving that scene it is cached as a transition scene.

var transition_time: float = 0.5
var transition_color: Color = Color.BLACK
var background_image: Texture = null


var main_tween: Tween

signal finish()


func get_class() -> String:
	return "GameTransition"


func set_data(_time: float, _color: Color) -> void:
	transition_time = _time
	transition_color = _color


func end_animation() -> void:
	finish.emit()


func start() -> void:
	pass


func end() -> void:
	queue_free()
