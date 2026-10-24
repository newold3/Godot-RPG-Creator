class_name EnemyDeadEffect
extends Node2D


@export var duration := 1.5
@export var trans_type: Tween.TransitionType = Tween.TRANS_LINEAR
@export var ease_type: Tween.EaseType = Tween.EASE_IN_OUT
@export var free_on_finish := true

var _elapsed := 0.0
var mat: ShaderMaterial
var target: Node2D

signal finished()


func _ready() -> void:
	finished.connect(queue_free)
	_start()


func set_target(_target: Node2D) -> void:
	target = _target


func set_shader_material(_mat: ShaderMaterial) -> void:
	mat = _mat.duplicate()


func _start() -> void:
	if target and mat:
		mat.set_shader_parameter("progress", 1.0)
		target.material = mat
		
		var t= create_tween()
		t.tween_property(mat, "shader_parameter/progress", 0.0, duration).set_ease(ease_type).set_trans(trans_type)
		t.tween_callback(_end)


func _end() -> void:
	queue_free()
