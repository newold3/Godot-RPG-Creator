@tool
extends Node2D


func start() -> void:
	$AnimationPlayer.play("move")


func end() -> void:
	$AnimationPlayer.play_backwards("move")
