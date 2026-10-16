@tool
extends GuiCoreConfirmDialog

@onready var main_container: Control = %MainContainer
@onready var window_panel: Control = %WindowPanel


func _animate_start() -> void:
	if main_tween:
		main_tween.kill()

	var target_panel = window_panel if window_panel else main_container
	if target_panel:
		target_panel.pivot_offset = target_panel.size * 0.5

	main_tween = create_tween()
	main_tween.set_parallel(true)
	main_tween.tween_property(self, "color:a", 0.6, 0.25).from(0.0)
	if target_panel:
		main_tween.tween_property(target_panel, "scale", Vector2.ONE, 0.3).from(Vector2(0.7, 0.7)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		main_tween.tween_property(target_panel, "modulate:a", 1.0, 0.25).from(0.0)

	main_tween.tween_callback(_on_start_completed).set_delay(0.2)


func _animate_end(emit_cancel: bool = false) -> void:
	if main_tween:
		main_tween.kill()

	var target_panel = window_panel if window_panel else main_container
	main_tween = create_tween()
	main_tween.set_parallel(true)
	main_tween.tween_property(self, "color:a", 0.0, 0.2)
	if target_panel:
		main_tween.tween_property(target_panel, "scale", Vector2(0.8, 0.8), 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		main_tween.tween_property(target_panel, "modulate:a", 0.0, 0.2)

	if emit_cancel:
		main_tween.tween_callback(func(): cancel.emit()).set_delay(0.15)
	main_tween.set_parallel(false)
	main_tween.tween_callback(set.bind("visible", false))
