@tool
extends Node2D

## Waiting time after the end of the start animation to play the stop animation.
@export var pause_before_stop: float = 0.15
## Initial position for the bouble
@export var bouble_offset = Vector2i(0, -8):
	set(value):
		bouble_offset = value
		if is_inside_tree():
			%BoublePosition.position = bouble_offset


func get_class() -> String:
	return "ExpressiveBubble"


func _ready() -> void:
	%BoublePosition.position = bouble_offset
	if !Engine.is_editor_hint():
		$AnimationPlayer.animation_finished.connect(
			func(_anim):
				await get_tree().create_timer(pause_before_stop).timeout
				$AnimationPlayer.play("Stop")
				await $AnimationPlayer.animation_finished
				queue_free()
		, CONNECT_ONE_SHOT
		)
	
	# Adds a subtle scale animation to enhance the initial animator player transition
	var t = create_tween()
	t.tween_interval(0.2)
	t.tween_property(%BoublePosition.get_child(0), "scale", Vector2(1.15, 1.05), 0.1)
	t.tween_property(%BoublePosition.get_child(0), "scale", Vector2.ONE, 0.2)
