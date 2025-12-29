extends GPUParticles2D


func _ready() -> void:
	finished.connect(queue_free)


func start(start_position: Vector2) -> void:
	global_position = start_position
	restart()
