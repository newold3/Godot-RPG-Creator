class_name GuiCoreLeftButtonsMenu
extends MarginContainer

#region ExportsAndVariables
@export var auto_select_button: bool = true
@export var initial_selection_delay: float = 0.15

var button_names: Array[String] = ["Items", "Skills", "Equipment", "Status", "Formation", "Professions", "Quests", "Encyclopedia", "????", "Save", "Options", "Game End"]
var button_tooltips: Array[String] = [
	"Items Help", "Skills Help", "Equipment Help", "Status Help", "Formation Help",
	"Professions Help", "Quests Help", "Encyclopedia Help", "Unused Help",
	"Save Help", "Options Help", "Game End Help"
]
var button_mapping: Dictionary = {
	0: 0,
	1: 1,
	2: 2,
	3: 3,
	4: 4,
	5: 9,
	6: 5,
	7: 10,
	8: 11,
	9: 6,
	10: 7,
	11: 8
}

var current_button_index: int = 0
var busy: bool = false
var disabled_db_ids: Array[int] = []

signal button_hovered(button: Control, index: int, tooltip: String)
signal selected(obj: Control, real_index: int)
signal begin_click(id: int)
signal clicked(id: int)
@warning_ignore("unused_signal")
signal started_animation_finished()
signal selection_completed()
signal finish()
#endregion

#region Lifecycle
func _ready() -> void:
	_prepare_disabled_buttons()
	disabled()
	_setup_buttons()
	start()
	if auto_select_button:
		restart()


func _process(_delta: float) -> void:
	if busy: return
	if GameManager.get_cursor_manipulator() == GameManager.MANIPULATOR_MODES.MAIN_MENU_MAIN_BUTTONS:
		var direction = ControllerManager.get_pressed_direction()
		if direction and direction in ["up", "down"]:
			_change_selected_control(direction)
		elif ControllerManager.is_cancel_just_pressed([KEY_0, KEY_KP_0], true):
			end()
		elif ControllerManager.is_confirm_just_pressed(false, [KEY_KP_ENTER], true, true):
			clicked.emit(current_button_index)
#endregion

#region VirtualHooks
## Override in themes to return the container holding the buttons
func get_button_container() -> Control:
	if has_node("%ButtonContainer"):
		return %ButtonContainer
	return null


## Override in themes to configure hand cursor position
func config_cursor() -> void:
	pass


## Override in themes for entrance animation
func animate_start() -> void:
	pass


## Override in themes for exit animation
func animate_end() -> void:
	pass


## Hook called when a button is set up in the theme
func on_button_setup(_button: Control, _db_id: int, _button_title: String) -> void:
	pass
#endregion

#region LogicAndData
func _prepare_disabled_buttons() -> void:
	disabled_db_ids.clear()
	if not GameManager.game_state or GameManager.game_state.current_party.is_empty():
		disabled_db_ids = [3, 4, 5, 6, 9, 10, 11]
	
	if GameManager.game_state:
		if GameManager.game_state.save_scene_prohibited and not (6 in disabled_db_ids):
			disabled_db_ids.append(6)
		if GameManager.game_state.formation_scene_prohibited and not (4 in disabled_db_ids):
			disabled_db_ids.append(4)


func is_db_id_disabled(db_id: int) -> bool:
	return db_id in disabled_db_ids


func get_db_id_for_visual_index(visual_index: int) -> int:
	return button_mapping.get(visual_index, visual_index)


func get_button_title(visual_index: int) -> String:
	if visual_index >= 0 and visual_index < button_names.size() and RPGSYSTEM.database and RPGSYSTEM.database.terms:
		var txt = RPGSYSTEM.database.terms.search_message(button_names[visual_index])
		if not txt.is_empty():
			return txt
		return tr(button_names[visual_index])
	return ""


func get_button_tooltip(visual_index: int) -> String:
	if visual_index >= 0 and visual_index < button_tooltips.size() and RPGSYSTEM.database and RPGSYSTEM.database.terms:
		return RPGSYSTEM.database.terms.search_message(button_tooltips[visual_index])
	return ""


func restart() -> void:
	busy = false
	_prepare_disabled_buttons()
	disabled()
	start()
	
	await get_tree().create_timer(initial_selection_delay).timeout
	if not is_instance_valid(self) or not is_inside_tree(): return
	
	enabled()
	select_button()
	config_cursor()


func get_button(button_id: int) -> Control:
	var container = get_button_container()
	if not container: return null
	for button in container.get_children():
		var visual_index = container.get_child_count() - button.get_index() - 1
		if get_db_id_for_visual_index(visual_index) == button_id:
			return button
	return null


func _change_selected_control(direction: String) -> void:
	var container = get_button_container()
	if not container: return
	var current_btn = get_button(current_button_index)
	var new_control = ControllerManager.get_closest_focusable_control(current_btn, direction, true)
	if new_control:
		if new_control.has_method("select"):
			new_control.select()
		else:
			new_control.grab_focus()
		GameManager.play_fx("cursor")


func _setup_buttons() -> void:
	var container = get_button_container()
	if not container: return
	
	for button in container.get_children():
		var visual_index = container.get_child_count() - button.get_index() - 1
		var db_id = get_db_id_for_visual_index(visual_index)
		var b_title = get_button_title(visual_index)
		var b_tooltip = get_button_tooltip(visual_index)
		
		on_button_setup(button, db_id, b_title)
		
		button.focus_entered.connect(
			func():
				if current_button_index != db_id:
					GameManager.play_fx("cursor")
				current_button_index = db_id
				button_hovered.emit(button, db_id, b_tooltip)
				config_cursor()
		)
		
		if button.has_signal("selected"):
			button.selected.connect(
				func(b):
					if current_button_index != db_id:
						GameManager.play_fx("cursor")
					current_button_index = db_id
					selected.emit(b, db_id)
					if "keep_selected_state" in b:
						b.keep_selected_state = false
			)
		
		if button.has_signal("begin_click"):
			button.begin_click.connect(func(_i): begin_click.emit(db_id))
		
		if button.has_signal("clicked"):
			button.clicked.connect(
				func(_i):
					if "is_selected" in button and not button.is_selected:
						if button.has_method("select"): button.select()
						if "keep_selected_state" in button: button.keep_selected_state = true
					clicked.emit(db_id)
			)
		
		button.mouse_entered.connect(
			func():
				button_hovered.emit(button, db_id, b_tooltip)
				if not is_db_id_disabled(db_id) and current_button_index != db_id:
					GameManager.play_fx("cursor")
		)


func enabled() -> void:
	var container = get_button_container()
	if not container: return
	for button in container.get_children():
		var visual_index = container.get_child_count() - button.get_index() - 1
		var db_id = get_db_id_for_visual_index(visual_index)
		if not is_db_id_disabled(db_id) and button.has_method("set_enabled"):
			button.set_enabled()


func disabled() -> void:
	var container = get_button_container()
	if not container: return
	for button in container.get_children():
		if button.has_method("set_disabled"):
			button.set_disabled()


func disable_button(index: int) -> void:
	var b = get_button(index)
	if b and b.has_method("set_disabled"):
		b.set_disabled()


func enable_button(index: int) -> void:
	if not is_db_id_disabled(index):
		var b = get_button(index)
		if b and b.has_method("set_enabled"):
			b.set_enabled()


func remove_any_keep_state() -> void:
	var container = get_button_container()
	if not container: return
	for button in container.get_children():
		if "keep_selected_state" in button: button.keep_selected_state = false
		if "busy" in button: button.busy = false
		if "busy2" in button: button.busy2 = false


func start() -> void:
	animate_start()


func end() -> void:
	animate_end()
	finish.emit()


func select_button() -> void:
	busy = true
	var container = get_button_container()
	if not container:
		busy = false
		return
	
	var target_btn = get_button(current_button_index)
	var is_btn_enabled = target_btn.is_enabled if (target_btn and "is_enabled" in target_btn) else true
	
	if target_btn and is_btn_enabled:
		if "busy" in target_btn: target_btn.busy = false
		if target_btn.has_method("select"):
			target_btn.select()
		else:
			target_btn.grab_focus()
	else:
		# Fallback to last enabled button
		for i in range(container.get_child_count() - 1, -1, -1):
			var b = container.get_child(i)
			var b_enabled = b.is_enabled if "is_enabled" in b else true
			if b_enabled:
				if "busy" in b: b.busy = false
				if b.has_method("select"): b.select()
				else: b.grab_focus()
				var v_idx = container.get_child_count() - i - 1
				current_button_index = get_db_id_for_visual_index(v_idx)
				break
	
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	selection_completed.emit()
	busy = false
#endregion
