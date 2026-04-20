extends CanvasLayer

func _ready() -> void:
	%MainContainer.item_rect_changed.connect(_on_resize)
	set_map_name("test Map")
	start()

func _on_resize() -> void:
	%MainContainer.set_deferred("pivot_offset", %MainContainer.size * 0.5)

func set_map_name(text: String) -> void:
	%MapName.text = text

func start() -> void:
	%AnimationPlayer.play("Start")

func fix_pivot() -> void:
	%MainContainer.pivot_offset = %MainContainer.size * 0.5
