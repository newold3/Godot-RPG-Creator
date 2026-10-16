extends GuiCoreEquipmentContainer

#region VisualAssetsAndNodes
const EQUIP_ITEM_BUTTON = preload("res://Scenes/GUI/SteamPunkTheme/Equip/equip_item_button.tscn")

@onready var equip_button_container: VBoxContainer = %EquipButtonContainer if has_node("%EquipButtonContainer") else null
@onready var gear_top_left: Control = %GearTopLeft if has_node("%GearTopLeft") else null

var main_tween: Tween
#endregion

#region HookOverrides
func get_equip_button_container() -> Control:
	if not equip_button_container and has_node("%EquipButtonContainer"):
		equip_button_container = %EquipButtonContainer
	if not equip_button_container:
		equip_button_container = get_node_or_null("MarginContainer/VBoxContainer/MarginContainer/BottomContainer/EquipButtonContainer")
	return equip_button_container


func _get_equip_button_scene() -> PackedScene:
	if equip_button_scene:
		return equip_button_scene
	return EQUIP_ITEM_BUTTON


func _animate_start(on_complete: Callable = Callable()) -> void:
	if main_tween:
		main_tween.kill()

	if gear_top_left:
		var a = -PI / 2.0
		main_tween = create_tween()
		main_tween.set_parallel(true)
		main_tween.tween_property(gear_top_left, "rotation", a, 0.7).set_trans(Tween.TRANS_SINE)
		main_tween.tween_interval(0.01)
		main_tween.set_parallel(false)
		main_tween.tween_callback(func():
			started = true
			if on_complete:
				on_complete.call()
		)
	else:
		started = true
		if on_complete:
			on_complete.call()


func _animate_end(on_complete: Callable = Callable()) -> void:
	if main_tween:
		main_tween.kill()
	if on_complete:
		on_complete.call()


func _config_hand() -> void:
	var manipulator = str(GameManager.MANIPULATOR_MODES.EQUIP_MENU)
	GameManager.set_cursor_manipulator(manipulator)
	GameManager.set_confin_area(Rect2(), manipulator)
	GameManager.set_hand_position(MainHandCursor.HandPosition.LEFT, manipulator)
	GameManager.set_cursor_offset(Vector2(8, 0), manipulator)
	GameManager.force_show_cursor()


func _config_hand_in_equipment_button(slot_id: int) -> void:
	var container = get_equip_button_container()
	if not container or container.get_child_count() <= slot_id:
		return
	var manipulator = str(GameManager.MANIPULATOR_MODES.EQUIP_MENU)
	GameManager.set_cursor_manipulator(manipulator)
	var rect = Rect2(0, global_position.y - 12, get_viewport().size.x, size.y + 24)
	GameManager.set_confin_area(rect, manipulator)
	GameManager.set_hand_position(MainHandCursor.HandPosition.LEFT, manipulator)
	GameManager.set_cursor_offset(Vector2(8, 0), manipulator)
	GameManager.force_show_cursor()
#endregion
