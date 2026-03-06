extends GPUParticles2D

@export var keep_position: bool = true


var _initial_position: Vector2

func _ready() -> void:
	texture = load("res://Assets/EffekEffects/MAGICALxSPIRAL/Texture/smoke_01.png")
	_initial_position = global_position
	if not one_shot: return
	emitting  = true
	restart(true)
	await finished
	queue_free()


func _process(_delta: float) -> void:
	if not one_shot or not keep_position: return
	global_position = _initial_position
