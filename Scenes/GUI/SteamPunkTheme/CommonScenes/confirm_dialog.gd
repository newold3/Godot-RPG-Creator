@tool
extends ColorRect

@export var contents: String = "" : set = _set_contents


@onready var title: Label = %Title
@onready var ok_button: NinePatchButton = %OKButton
@onready var cancel_button: NinePatchButton = %CancelButton
@onready var main_container: MarginContainer = $mainContainer
@onready var gear: TextureRect = %Gear
@onready var arm_left: Node2D = $Arms/Left/Arm
@onready var arm_right: Node2D = $Arms/Right/Arm

var gear_tween: Tween
var is_started: bool = false

signal ok()
signal cancel()


func _ready() -> void:
	ok_button.focus_entered.connect(_config_hand_in_left_button)
	cancel_button.focus_entered.connect(_config_hand_in_right_button)
	_disable_buttons()


func _process(_delta: float) -> void:
	if GameManager.get_cursor_manipulator() == GameManager.MANIPULATOR_MODES.CONFIRM:
		var direction = ControllerManager.get_pressed_direction()
		if direction:
			if direction in ["left", "right"]:
				_change_selected_control()
		elif ControllerManager.is_confirm_just_pressed():
			if ok_button.has_focus():
				ok_button.pressed.emit()
			elif cancel_button.has_focus():
				cancel_button.pressed.emit()
		elif ControllerManager.is_cancel_just_pressed([KEY_0, KEY_KP_0]):
			cancel_button.pressed.emit()


func _change_selected_control() -> void:
	if ok_button.has_focus():
		cancel_button.grab_focus()
	else:
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
	ok_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cancel_button.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _enable_buttons() -> void:
	ok_button.mouse_filter = Control.MOUSE_FILTER_STOP
	cancel_button.mouse_filter = Control.MOUSE_FILTER_STOP


func _set_contents(new_value: String) -> void:
	contents = new_value
	if title:
		title.text = tr(contents)
		title.refresh()


func start() -> void:
	GameManager.set_cursor_manipulator("")
	GameManager.force_hide_cursor()
	GameManager.set_fx_busy(true)
	is_started = false
	visible = true
	
	arm_left.start()
	arm_right.start()
	main_container.modulate.a = 1.0
	
	if gear_tween:
		gear_tween.kill()
	gear_tween = create_tween()
	gear_tween.set_loops()
	gear_tween.tween_property(gear, "rotation", TAU, 2.5).from(0.0)
	
	main_container.pivot_offset = main_container.size * 0.5
	var t = create_tween()
	t.set_parallel(true)
	t.tween_property(self, "self_modulate:a", 1.0, 0.5).from(0.0)
	t.tween_property(main_container, "scale:x", 1.0, 0.6
	).from(0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	t.tween_callback(
		func():
			is_started = true
			_enable_buttons()
			ok_button.grab_focus()
			GameManager.force_hand_position_over_node(GameManager.get_cursor_manipulator())
			GameManager.force_show_cursor()
			GameManager.set_fx_busy(false)
	).set_delay(0.3)
	


func end(emit_cancel: bool = false) -> void:
	GameManager.force_hide_cursor()
	_disable_buttons()
	is_started = false
	
	arm_left.end()
	arm_right.end()
	
	if gear_tween:
		gear_tween.kill()
	gear_tween = create_tween()
	gear_tween.set_loops()
	gear_tween.tween_property(gear, "rotation", -TAU, 1.25)
	
	var t = create_tween()
	t.set_parallel(true)
	t.tween_property(self, "self_modulate:a", 0.2, 0.35)
	t.tween_property(main_container, "modulate:a", 0.0, 0.15).set_delay(0.2)
	t.tween_property(main_container, "scale:x", 0.8, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	if emit_cancel:
		t.tween_callback(func(): cancel.emit()).set_delay(0.25)
	t.set_parallel(false)
	t.tween_callback(gear_tween.kill)
	t.tween_callback(set.bind("visible", false))


func _on_ok_button_pressed() -> void:
	if not is_started: return
	ok.emit()
	end()


func _on_cancel_button_pressed() -> void:
	if not is_started: return
	GameManager.play_fx("cancel")
	end(true)
