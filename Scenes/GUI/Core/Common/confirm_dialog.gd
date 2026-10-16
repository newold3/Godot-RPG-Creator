@tool
class_name GuiCoreConfirmDialog
extends ColorRect

#region Variables & Signals
@export var contents: String = "" : set = _set_contents

@onready var title: Control = _find_title_node()
@onready var ok_button: Control = _find_ok_button()
@onready var cancel_button: Control = _find_cancel_button()

var is_started: bool = false
var main_tween: Tween

signal ok()
signal cancel()
#endregion



#region Lifecycle & Initialization
func _ready() -> void:
	if ok_button:
		if not ok_button.focus_entered.is_connected(_config_hand_in_left_button):
			ok_button.focus_entered.connect(_config_hand_in_left_button)
		if ok_button.has_signal("pressed") and not ok_button.pressed.is_connected(_on_ok_button_pressed):
			ok_button.pressed.connect(_on_ok_button_pressed)
	if cancel_button:
		if not cancel_button.focus_entered.is_connected(_config_hand_in_right_button):
			cancel_button.focus_entered.connect(_config_hand_in_right_button)
		if cancel_button.has_signal("pressed") and not cancel_button.pressed.is_connected(_on_cancel_button_pressed):
			cancel_button.pressed.connect(_on_cancel_button_pressed)
	_disable_buttons()


func _process(_delta: float) -> void:
	if not is_started:
		return
	if GameManager.get_cursor_manipulator() == GameManager.MANIPULATOR_MODES.CONFIRM:
		var direction = ControllerManager.get_pressed_direction()
		if direction:
			if direction in ["left", "right"]:
				_change_selected_control()
		elif ControllerManager.is_confirm_just_pressed():
			if ok_button and ok_button.has_focus():
				_on_ok_button_pressed()
			elif cancel_button and cancel_button.has_focus():
				_on_cancel_button_pressed()
		elif ControllerManager.is_cancel_just_pressed([KEY_0, KEY_KP_0]):
			_on_cancel_button_pressed()
#endregion



#region Node Resolution
func _find_title_node() -> Control:
	if has_node("%Title"):
		return get_node("%Title") as Control
	return null


func _find_ok_button() -> Control:
	if has_node("%OKButton"):
		return get_node("%OKButton") as Control
	return null


func _find_cancel_button() -> Control:
	if has_node("%CancelButton"):
		return get_node("%CancelButton") as Control
	return null
#endregion



#region Navigation & Focus
func _change_selected_control() -> void:
	if ok_button and ok_button.has_focus():
		if cancel_button:
			cancel_button.grab_focus()
	else:
		if ok_button:
			ok_button.grab_focus()


func _config_hand_in_left_button() -> void:
	var manipulator = GameManager.MANIPULATOR_MODES.CONFIRM
	GameManager.set_cursor_manipulator(manipulator)
	GameManager.set_hand_position(MainHandCursor.HandPosition.LEFT, manipulator)
	GameManager.set_cursor_offset(Vector2(14, 2), manipulator)
	GameManager.set_confin_area(Rect2(), manipulator)
	GameManager.play_fx("cursor")


func _config_hand_in_right_button() -> void:
	var manipulator = GameManager.MANIPULATOR_MODES.CONFIRM
	GameManager.set_cursor_manipulator(manipulator)
	GameManager.set_hand_position(MainHandCursor.HandPosition.RIGHT, manipulator)
	GameManager.set_cursor_offset(Vector2(-14, 2), manipulator)
	GameManager.set_confin_area(Rect2(), manipulator)
	GameManager.play_fx("cursor")


func _disable_buttons() -> void:
	if ok_button:
		ok_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if cancel_button:
		cancel_button.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _enable_buttons() -> void:
	if ok_button:
		ok_button.mouse_filter = Control.MOUSE_FILTER_STOP
	if cancel_button:
		cancel_button.mouse_filter = Control.MOUSE_FILTER_STOP
#endregion



#region Content & State
func _set_contents(new_value: String) -> void:
	contents = new_value
	if title:
		if "text" in title:
			title.text = tr(contents)
		if title.has_method("refresh"):
			title.call("refresh")


func start() -> void:
	GameManager.set_cursor_manipulator("")
	GameManager.force_hide_cursor()
	GameManager.set_fx_busy(true)
	is_started = false
	visible = true
	_animate_start()


func end(emit_cancel: bool = false) -> void:
	GameManager.force_hide_cursor()
	_disable_buttons()
	is_started = false
	_animate_end(emit_cancel)


## Virtual method for entrance animations; override in theme subclasses.
func _animate_start() -> void:
	_on_start_completed()


## Virtual method for exit animations; override in theme subclasses.
func _animate_end(emit_cancel: bool = false) -> void:
	if emit_cancel:
		cancel.emit()
	visible = false


func _on_start_completed() -> void:
	is_started = true
	_enable_buttons()
	if ok_button:
		ok_button.grab_focus()
	GameManager.force_hand_position_over_node(GameManager.get_cursor_manipulator())
	GameManager.force_show_cursor()
	GameManager.set_fx_busy(false)


func _on_ok_button_pressed() -> void:
	if not is_started:
		return
	GameManager.play_fx("select")
	ok.emit()
	end()


func _on_cancel_button_pressed() -> void:
	if not is_started:
		return
	GameManager.play_fx("cancel")
	end(true)
#endregion
