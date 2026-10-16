extends GuiCoreEquipScene

#region ExportedVariables
@export var menu_items_start_position: Vector2
@export var menu_items_end_position: Vector2
#endregion

#region NodeReferences
@onready var stats_container: Control = %StatsContainer if has_node("%StatsContainer") else null
@onready var equipment_container: Control = %EquipmentContainer if has_node("%EquipmentContainer") else null
@onready var main_actor_container: VBoxContainer = %MainActorContainer if has_node("%MainActorContainer") else null
@onready var buttons_vertical_menu: MarginContainer = %ButtonsVerticalMenu if has_node("%ButtonsVerticalMenu") else null
@onready var menu_items: Control = %MenuItems if has_node("%MenuItems") else null
@onready var current_selected_equipment_container: Control = %CurrentSelectedEquipmentContainer if has_node("%CurrentSelectedEquipmentContainer") else null
@onready var costume_button_container: MarginContainer = %CostumeButtonContainer if has_node("%CostumeButtonContainer") else null
@onready var set_icon: TextureRect = %SetIcon if has_node("%SetIcon") else null
@onready var help_label: Label = %HelpLabel if has_node("%HelpLabel") else null
@onready var costume_button: Control = %CostumeButton if has_node("%CostumeButton") else null

var main_tween: Tween
#endregion

#region GetterOverrides
func get_stats_container() -> Control:
	if not stats_container and has_node("%StatsContainer"):
		stats_container = %StatsContainer
	if not stats_container:
		stats_container = get_node_or_null("HBoxContainer/MainStatsContainer/Stats/StatsContainer")
	return stats_container


func get_equipment_container() -> Control:
	if not equipment_container and has_node("%EquipmentContainer"):
		equipment_container = %EquipmentContainer
	if not equipment_container:
		equipment_container = get_node_or_null("HBoxContainer/EquipmentContainer/Equipment/VBoxContainer/EquipmentContainer")
	return equipment_container


func get_main_actor_container() -> Control:
	if not main_actor_container and has_node("%MainActorContainer"):
		main_actor_container = %MainActorContainer
	if not main_actor_container:
		main_actor_container = get_node_or_null("HBoxContainer/ActorPanel/MainActorPanel/ActorContainer/MainActorContainer")
	return main_actor_container


func get_buttons_vertical_menu() -> Control:
	if not buttons_vertical_menu and has_node("%ButtonsVerticalMenu"):
		buttons_vertical_menu = %ButtonsVerticalMenu
	return buttons_vertical_menu


func get_menu_items() -> Control:
	if not menu_items and has_node("%MenuItems"):
		menu_items = %MenuItems
	return menu_items


func get_current_selected_equipment_container() -> Control:
	if not current_selected_equipment_container and has_node("%CurrentSelectedEquipmentContainer"):
		current_selected_equipment_container = %CurrentSelectedEquipmentContainer
	return current_selected_equipment_container


func get_costume_button_container() -> Control:
	if not costume_button_container and has_node("%CostumeButtonContainer"):
		costume_button_container = %CostumeButtonContainer
	return costume_button_container


func get_set_icon() -> TextureRect:
	if not set_icon and has_node("%SetIcon"):
		set_icon = %SetIcon
	return set_icon


func get_costume_button() -> Control:
	if not costume_button and has_node("%CostumeButton"):
		costume_button = %CostumeButton
	return costume_button
#endregion

#region VisualOverrides
func _set_help_text(help: String) -> void:
	if help_label:
		help_label.text = help


func _update_costume_icon_visual(texture: Texture2D) -> void:
	if set_icon:
		set_icon.texture = texture
		set_icon.visible = (texture != null)


func _play_ui_sound(sound_name: String) -> void:
	GameManager.play_fx(sound_name)


func _on_item_equipped_visual(_slot_id: int) -> void:
	if ControllerManager.current_controller == ControllerManager.CONTROLLER_TYPE.Mouse:
		var slot_selected = equipment_container.get_button_selected() if equipment_container and equipment_container.has_method("get_button_selected") else null
		if slot_selected:
			Input.warp_mouse(slot_selected.global_position + slot_selected.size * 0.5)
			await get_tree().process_frame
			await get_tree().process_frame
			await get_tree().process_frame
			DisplayServer.cursor_set_shape(DisplayServer.CURSOR_POINTING_HAND)
		elif costume_button:
			Input.warp_mouse(costume_button.global_position + costume_button.size * 0.5)
			await get_tree().process_frame
			await get_tree().process_frame
			await get_tree().process_frame
			DisplayServer.cursor_set_shape(DisplayServer.CURSOR_POINTING_HAND)


func _animate_start(on_complete: Callable = Callable()) -> void:
	if main_tween:
		main_tween.kill()

	main_tween = create_tween()
	main_tween.set_parallel(true)
	if stats_container:
		main_tween.tween_property(stats_container, "size:y", 398, 0.5).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN_OUT).from(20)
	if buttons_vertical_menu:
		main_tween.tween_property(buttons_vertical_menu, "position:x", 0, 0.5).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN_OUT).from(-100)
	if equipment_container:
		main_tween.tween_property(equipment_container, "position:x", 0, 0.5).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN_OUT).from(550)
	main_tween.set_parallel(false)
	main_tween.tween_interval(0.001)
	if stats_container:
		stats_container.started = true
	if on_complete:
		main_tween.tween_callback(on_complete)


func _show_menu_visual(on_complete: Callable = Callable()) -> void:
	GameManager.set_cursor_manipulator(GameManager.MANIPULATOR_MODES.NONE)
	var t = create_tween()
	t.set_parallel(true)
	if menu_items:
		t.tween_property(menu_items, "position", menu_items_end_position, 0.2).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
		if menu_items.has_method("start"):
			t.tween_callback(menu_items.start).set_delay(0.2)
	
	if stats_container:
		if not stats_container.has_meta("original_position"):
			stats_container.set_meta("original_position", stats_container.position)
		if stats_container.has_method("get_gears"):
			var gears = stats_container.get_gears()
			for gear in gears:
				t.tween_property(gear, "rotation", -PI / 4, 0.5).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT).set_delay(0.18)
		t.tween_property(stats_container, "position:x", stats_container.get_meta("original_position").x - 40, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(0.18)
		t.tween_callback(
			func():
				GameManager.play_se("res://Assets/Sounds/SE/wood_hit.ogg")
				stats_container.set_show_comparison(true)
				if menu_items and menu_items.has_method("emit_selected_item"):
					menu_items.emit_selected_item()
		).set_delay(0.20)
	
	if costume_button_container:
		if not costume_button_container.has_meta("original_position"):
			costume_button_container.set_meta("original_position", costume_button_container.position)
		t.tween_property(costume_button_container, "position:x", costume_button_container.get_meta("original_position").x - 40, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(0.18)
		
	if on_complete:
		t.tween_callback(on_complete).set_delay(0.25)


func _hide_menu_visual(on_complete: Callable = Callable()) -> void:
	GameManager.set_cursor_manipulator(GameManager.MANIPULATOR_MODES.NONE)
	if stats_container and stats_container.has_method("set_show_comparison"):
		stats_container.set_show_comparison(false)
	if menu_items and menu_items.has_method("end"):
		menu_items.end()
	
	var t = create_tween()
	t.set_parallel(true)
	if menu_items:
		t.tween_property(menu_items, "position", menu_items_start_position, 0.4).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
		t.tween_callback(
			func():
				if equipment_container:
					if equipment_container.button_selected == -1:
						equipment_container.button_selected = 0
						var manager = get_node_or_null("Manager")
						if manager and manager.has_method("_select_costume"):
							manager._select_costume()
					else:
						equipment_container.select_last_slot()
					_on_equipment_slot_selected(equipment_container.button_selected)
				GameManager.force_show_cursor()
				GameManager.force_hand_position_over_node(GameManager.get_cursor_manipulator())
		).set_delay(0.4)
	
	if stats_container:
		if stats_container.has_method("get_gears"):
			var gears = stats_container.get_gears()
			for gear in gears:
				t.tween_property(gear, "rotation", 0.0, 0.5).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT).set_delay(0.2)
		if stats_container.has_meta("original_position"):
			t.tween_property(stats_container, "position:x", stats_container.get_meta("original_position").x, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(0.2)
	
	if costume_button_container and costume_button_container.has_meta("original_position"):
		t.tween_property(costume_button_container, "position:x", costume_button_container.get_meta("original_position").x, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(0.2)
		
	if on_complete:
		t.tween_callback(on_complete).set_delay(0.4)
#endregion
