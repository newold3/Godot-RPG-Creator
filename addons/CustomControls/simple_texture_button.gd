@tool
extends TextureButton

@export var hover_coler: Color = Color(1.5, 1.5, 1.5)

func _ready() -> void:
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)


func _on_mouse_entered() -> void:
	modulate = hover_coler


func _on_mouse_exited() -> void:
	modulate = Color.WHITE
