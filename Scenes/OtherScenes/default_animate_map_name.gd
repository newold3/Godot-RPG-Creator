extends CanvasLayer


func _ready() -> void:
	%MainContainer.item_rect_changed.connect(_on_resize)


func _on_resize() -> void:
	%MainContainer.pivot_offset = %MainContainer.size * 0.5


func set_map_name(text: String) -> void:
	%MapName.text = text


func start() -> void:
	%AnimationPlayer.play("Start")
