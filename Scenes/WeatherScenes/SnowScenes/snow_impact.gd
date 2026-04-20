extends GPUParticles2D


func _ready() -> void:
	texture = load("res://Assets/EffekEffects/tktk02/Parts/SnowCrystals_S.png")
	finished.connect(queue_free)


func start(start_position: Vector2) -> void:
	global_position = start_position
	restart()
