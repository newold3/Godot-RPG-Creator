extends MarginContainer


@export var auto_select_button: bool = true
@export var initial_selection_delay: float = 0.15


@onready var button_container: StaggeredButtonContainer = %ButtonContainer

var button_names = ["Items", "Skills", "Equipment", "Status", "Formation", "Quests", "Save", "Options", "Game End"]
var button_tooltips = [
	"Items Help", "Skills Help", "Equipment Help", "Status Help", "Formation Help",
	"Quests Help", "Save Help", "Options Help", "Game End Help"
]

var current_button
var current_button_index: int = 0
var busy = false

signal button_hovered(button: Control, index: int, tooltip: String)
signal selected(obj: Control, real_index: int)
signal begin_click(id: int)
signal clicked(id: int)
@warning_ignore("unused_signal")
signal started_animation_finished()
signal selection_completed()
signal finish()


func _ready() -> void:
	_disabled()
	_config_buttons()
	start()
	
	if auto_select_button:
		restart()


func restart() -> void:
	busy = false
	_disabled()
	start()
	await get_tree().create_timer(initial_selection_delay).timeout
	if not is_instance_valid(self) or not is_inside_tree(): return
	_enabled()
	select_button()
	var manipulator = GameManager.get_cursor_manipulator()
	GameManager.force_hand_position_over_node(manipulator)
	GameManager.force_show_cursor()


func get_button(button_id: int) -> MainMenuButton:
	if button_id >= 0 and button_container.get_child_count() > button_id:
		return button_container.get_child(button_container.get_child_count() - 1 - button_id)
	
	return null


func set_starting() -> void:
	for button: MainMenuButton in button_container.get_children():
		button.set_disabled()


func _config_hand_over_menu_main_buttons() -> void:
	var hand_manipulator = GameManager.MANIPULATOR_MODES.MAIN_MENU_MAIN_BUTTONS
	GameManager.set_cursor_manipulator(hand_manipulator)
	GameManager.set_confin_area(Rect2(), hand_manipulator)
	GameManager.set_hand_position(MainHandCursor.HandPosition.RIGHT, hand_manipulator)
	GameManager.set_cursor_offset(Vector2(-16, 0), hand_manipulator)
	ControllerManager.set_focusable_control_threshold(500, 500)


func _process(_delta: float) -> void:
	if busy: return

	if GameManager.get_cursor_manipulator() == GameManager.MANIPULATOR_MODES.MAIN_MENU_MAIN_BUTTONS:
		var direction = ControllerManager.get_pressed_direction()
		if direction and direction in ["up", "down"]:
			_change_selected_control(direction)
		elif ControllerManager.is_cancel_just_pressed([KEY_0, KEY_KP_0]):
			end()
		elif ControllerManager.is_confirm_just_pressed(false, [KEY_KP_ENTER]):
			clicked.emit(current_button_index)


func _change_selected_control(direction: String) -> void:
	var new_control = ControllerManager.get_closest_focusable_control(current_button, direction, true)
	if new_control:
		if new_control.has_method("select"):
			new_control.select()
		else:
			new_control.grab_focus()
		
		GameManager.play_fx("cursor")


func _config_buttons() -> void:
	for button: MainMenuButton in button_container.get_children():
		var real_button_index = button_container.get_child_count() - button.get_index() - 1
		current_button_index = real_button_index
		button.button_text = RPGSYSTEM.database.terms.search_message(button_names[real_button_index])
		button.focus_entered.connect(
			func():
				current_button_index = real_button_index
				#_set_keep_selected_state(button)
				var button_tooltip: String = RPGSYSTEM.database.terms.search_message(button_tooltips[real_button_index])
				button_hovered.emit(button, real_button_index, button_tooltip)
				_config_hand_over_menu_main_buttons()
		)
		button.selected.connect(
			func(b):
				current_button_index = real_button_index
				current_button = button
				selected.emit(b, button_container.get_child_count() - current_button.get_index() - 1)
		)
		button.begin_click.connect(
			func(_i):
				current_button = button
				begin_click.emit(real_button_index)
		)
		button.clicked.connect(
			func(_i):
				if not button.is_selected:
					button.select()
					button.keep_selected_state = true
				clicked.emit(real_button_index)
		)
		button.mouse_entered.connect(
			func():
				var button_tooltip: String = RPGSYSTEM.database.terms.search_message(button_tooltips[real_button_index])
				button_hovered.emit(button, real_button_index, button_tooltip)
		)


func disable_animations() -> void:
	for button in button_container.get_children():
		button.disable_animations()


func enable_animations() -> void:
	for button in button_container.get_children():
		button.enable_animations()


func enabled() -> void:
	_enabled()


func disabled() -> void:
	_disabled()


func _enabled():
	for button in button_container.get_children():
		button.set_enabled()


func _disabled():
	for button in button_container.get_children():
		button.set_disabled()


func remove_any_keep_state() -> void:
	for button: MainMenuButton in button_container.get_children():
		button.keep_selected_state = false
		button.busy = false
		button.busy2 = false


func _set_keep_selected_state(button: MainMenuButton) -> void:
	for other_button: MainMenuButton in button_container.get_children():
		if other_button == button:
			other_button.keep_selected_state = true
		else:
			other_button.keep_selected_state = false
			other_button.busy = false
			other_button._on_focus_exited()


func get_total_animation_time() -> float:
	return (button_container.get_child_count() - 1) * button_container.animation_delay + button_container.animation_duration * 2.0 + 0.15


func start() -> void:
	for button in button_container.get_children():
		if  "main_tween" in button and button.main_tween is Tween and button.main_tween.is_valid():
			button.main_tween.custom_step(999)
		var delay = button.get_index() * button_container.animation_delay
		button.animate_gear(1, button_container.animation_duration, delay)
	button_container.restart()


func end() -> void:
	button_container.end()
	finish.emit()


func select_button() -> void:
	busy = false
	if current_button_index >= 0 and current_button_index < button_container.get_child_count():
		var real_index = button_container.get_child_count() - current_button_index - 1
		var button = button_container.get_child(real_index)
		button.busy = false
		button.select()
		await get_tree().process_frame
		await get_tree().process_frame
		await get_tree().process_frame
		selection_completed.emit()
		busy = false
