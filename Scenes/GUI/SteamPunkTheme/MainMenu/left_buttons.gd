extends GuiCoreLeftButtonsMenu

#region ThemeNodes
@onready var button_container: Control = %ButtonContainer if has_node("%ButtonContainer") else null
#endregion

#region HookOverrides
func get_button_container() -> Control:
	if not button_container and has_node("%ButtonContainer"):
		button_container = %ButtonContainer
	return button_container


func on_button_setup(button: Control, _db_id: int, button_title: String) -> void:
	if "button_text" in button:
		button.button_text = button_title
	
	button.focus_entered.connect(func(): button.z_index = 100)
	button.focus_exited.connect(func(): button.z_index = 0)


func config_cursor() -> void:
	var hand_manipulator = GameManager.MANIPULATOR_MODES.MAIN_MENU_MAIN_BUTTONS
	GameManager.set_cursor_manipulator(hand_manipulator)
	GameManager.set_confin_area(Rect2(), hand_manipulator)
	GameManager.set_hand_position(MainHandCursor.HandPosition.RIGHT, hand_manipulator)
	GameManager.set_cursor_offset(Vector2(-16, 0), hand_manipulator)
	ControllerManager.set_focusable_control_threshold(150, 150)
	GameManager.force_show_cursor()


func animate_start() -> void:
	var container = get_button_container()
	if not container: return
	
	for button in container.get_children():
		if "main_tween" in button and button.main_tween is Tween and button.main_tween.is_valid():
			button.main_tween.custom_step(999)
		
		var delay = button.get_index() * (container.animation_delay if "animation_delay" in container else 0.05)
		var duration = container.animation_duration if "animation_duration" in container else 0.2
		if button.has_method("animate_gear"):
			button.animate_gear(1, duration, delay)
	
	if container.has_method("restart"):
		container.restart()


func animate_end() -> void:
	var container = get_button_container()
	if container and container.has_method("end"):
		container.end()


func disable_animations() -> void:
	var container = get_button_container()
	if not container: return
	for button in container.get_children():
		if button.has_method("disable_animations"):
			button.disable_animations()


func enable_animations() -> void:
	var container = get_button_container()
	if not container: return
	for button in container.get_children():
		if button.has_method("enable_animations"):
			button.enable_animations()
#endregion
