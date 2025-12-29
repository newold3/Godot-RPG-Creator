@tool
extends TextureProgressBar


@export var child: Control

func _ready() -> void:
	value_changed.connect(_on_value_changed)


func _on_value_changed(new_value: float) -> void:
	if child:
		var percent: float = new_value / max_value
		child.size.x = size.x * percent
