@tool
extends BattleAnimation


func _ready() -> void:
	play("default")
	$AnimationPlayer.play("Start")
	$GPUParticles2D.restart()
	$GPUParticles2D.emitting = true


func _on_animation_player_animation_finished(anim_name: StringName) -> void:
	if is_in_editor and anim_name != "RESET":
		queue_free()
