extends GPUParticles2D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	emitting = true
	await finished
	queue_free()
