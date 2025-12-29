extends PopupMenu


@export var main_parent: Control


func _process(delta: float) -> void:
	if main_parent and visible:
		position = main_parent.position + Vector2(main_parent.size.x / 2, main_parent.size.y) - Vector2(size.x / 2, 0)
