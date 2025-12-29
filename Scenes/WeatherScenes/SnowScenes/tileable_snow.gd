extends Polygon2D


@export var velocity: Vector2 = Vector2(3, 1)


func _process(delta: float) -> void:
	texture_offset += velocity * delta
