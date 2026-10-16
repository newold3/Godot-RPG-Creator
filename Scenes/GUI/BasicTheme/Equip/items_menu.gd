extends Control


@export_enum("DRAW_LEVEL_AND_QUANTITY", "DRAW_LEVEL_ONLY", "DRAW_QUANTITY_ONLY") var display_mode: int = 0 : set = _set_display_mode

var is_enabled: bool = false
var last_item_hovered: int = -1


@warning_ignore("unused_signal")
signal cancel()
signal item_hovered(index: int, item: Dictionary)
signal item_selected(index: int, item: Dictionary)
signal item_clicked(index: int, item: Dictionary)
signal back_pressed()


func start() -> void:
	enabled()
	%Gear1.rotation = 0
	%Gear2.rotation = 0
	%Gear3.rotation = 0
	var a = -PI / 8
	
	var t = create_tween()
	t.set_parallel(true)
	t.tween_property(%Gear1, "rotation", a, 0.28).set_trans(Tween.TRANS_SINE)
	t.tween_property(%Gear2, "rotation", a, 0.28).set_trans(Tween.TRANS_SINE)
	t.tween_property(%Gear3, "rotation", a, 0.28).set_trans(Tween.TRANS_SINE)


func end() -> void:
	disabled()
	var a = 0.0
	
	var t = create_tween()
	t.set_parallel(true)
	t.tween_property(%Gear1, "rotation", a, 0.28).set_trans(Tween.TRANS_SINE)
	t.tween_property(%Gear2, "rotation", a, 0.28).set_trans(Tween.TRANS_SINE)
	t.tween_property(%Gear3, "rotation", a, 0.28).set_trans(Tween.TRANS_SINE)
	t.tween_interval(0.01)
	t.set_parallel(false)


func _set_display_mode(value: int) -> void:
	display_mode = value
	%MainScene.display_mode = value


func set_items(new_items: Array[Dictionary]) -> void:
	%MainScene.set_items(new_items)


func enabled() -> void:
	is_enabled = true
	%MainScene.enabled()


func disabled() -> void:
	is_enabled = false
	%MainScene.disabled()


func set_curren_equipped_item(item: Variant) -> void:
	%MainScene.curren_equipped_item = item


func emit_selected_item() -> void:
	%MainScene.emit_selected_item()


func _on_main_scene_cancel() -> void:
	GameManager.play_fx("cancel")
	back_pressed.emit()


func _on_main_scene_item_clicked(index: int, item: Dictionary) -> void:
	item_clicked.emit(index, item)


func _on_main_scene_item_hovered(index: int, item: Dictionary) -> void:
	item_hovered.emit(index, item)


func _on_main_scene_item_selected(index: int, item: Dictionary) -> void:
	item_selected.emit(index, item)
