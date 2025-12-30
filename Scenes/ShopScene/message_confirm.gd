extends Control


@export var hand_manipulator: String

var main_tween: Tween
var is_enabled: bool = false

@onready var cancel_confirm_cancel: Button = %CancelConfirmCancel
@onready var cancel_confirm_ok: Button = %CancelConfirmOK
@onready var cancel_confirm_message: Label = %CancelConfirmMessage
@onready var cancel_confirm_panel: MarginContainer = %CancelConfirmPanel


signal cancel_requested()
signal ok_requested()


func _ready() -> void:
	visible = false


func _process(_delta: float) -> void:
	if not hand_manipulator.is_empty() and not GameManager.get_cursor_manipulator() == hand_manipulator: return
	if is_enabled:
		var direction = ControllerManager.get_pressed_direction()
		if direction:
			var play_fx = false
			if direction == "left" or direction == "right":
				if cancel_confirm_cancel.has_focus():
					cancel_confirm_ok.grab_focus()
				else:
					cancel_confirm_cancel.grab_focus()
				play_fx = true
				
			if play_fx:
				GameManager.play_fx("cursor")
		elif ControllerManager.is_confirm_pressed(false, [KEY_KP_ENTER]) or ControllerManager.is_key_pressed(KEY_ENTER) or ControllerManager.is_joy_button_pressed(JOY_BUTTON_START):
			if cancel_confirm_cancel.has_focus():
				_on_cancel_confirm_cancel_pressed()
				cancel_requested.emit()
				
			elif cancel_confirm_ok.has_focus():
				_on_cancel_confirm_ok_pressed()
				ok_requested.emit()
				
		elif ControllerManager.is_cancel_pressed([KEY_0, KEY_KP_0]) or ControllerManager.is_key_pressed(KEY_ESCAPE) or ControllerManager.is_joy_button_pressed(JOY_BUTTON_BACK):
			GameManager.play_fx("cancel")
			cancel_confirm_cancel.grab_focus()
			_on_cancel_confirm_cancel_pressed()
			cancel_requested.emit()


func show_message() -> void:
	var terms: RPGTerms = RPGSYSTEM.database.terms
	
	GameManager.hide_cursor(true, GameManager.get_cursor_manipulator())
	
	var text = terms.get_message("Shop Cancel Message")
	text = text.replace("\\n", "\n\n")
	cancel_confirm_message.text = text
	text = terms.get_message("Shop Cancel Button Cancel")
	cancel_confirm_cancel.text = text
	text = terms.get_message("Shop Cancel Button Ok")
	cancel_confirm_ok.text = text
	
	modulate.a = 0.0
	visible = true
	
	await get_tree().process_frame
	
	if main_tween:
		main_tween.kill()
	
	GameManager.play_fx("cancel")
	
	cancel_confirm_panel.pivot_offset = cancel_confirm_panel.size / 2
	cancel_confirm_panel.scale = Vector2.ZERO
	main_tween = create_tween()
	main_tween.set_parallel(true)
	main_tween.tween_property(self, "modulate:a", 1.0, 0.2)
	main_tween.tween_property(cancel_confirm_panel, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK)
	
	await main_tween.finished

	cancel_confirm_cancel.grab_focus()
	var manipulator = GameManager.get_cursor_manipulator()
	GameManager.force_hand_position_over_node(manipulator)
	GameManager.show_cursor(MainHandCursor.HandPosition.LEFT, manipulator)
	is_enabled = true


func hide_message() -> void:
	GameManager.hide_cursor(false, GameManager.get_cursor_manipulator())
	cancel_confirm_panel.pivot_offset = cancel_confirm_panel.size / 2
	
	if main_tween:
		main_tween.kill()
	
	is_enabled = false
	
	await get_tree().create_timer(0.2).timeout
	if not is_instance_valid(self) or not is_inside_tree(): return
		
	main_tween = create_tween()
	main_tween.set_parallel(true)
	main_tween.tween_property(self, "modulate:a", 0.0, 0.2)
	main_tween.tween_property(cancel_confirm_panel, "scale", Vector2.ZERO, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	main_tween.set_parallel(false)
	main_tween.tween_callback(set.bind("visible", false))
	
	await main_tween.finished


func _on_cancel_confirm_cancel_focus_entered() -> void:
	var manipulator = hand_manipulator
	GameManager.set_cursor_manipulator(manipulator)
	GameManager.set_confin_area(Rect2(), manipulator)
	GameManager.set_hand_position(MainHandCursor.HandPosition.LEFT, manipulator)
	GameManager.set_cursor_offset(Vector2(10, 0), manipulator)


func _on_cancel_confirm_ok_focus_entered() -> void:
	var manipulator = hand_manipulator
	GameManager.set_cursor_manipulator(manipulator)
	GameManager.set_confin_area(Rect2(), manipulator)
	GameManager.set_hand_position(MainHandCursor.HandPosition.RIGHT, manipulator)
	GameManager.set_cursor_offset(Vector2(-10, 0), manipulator)


func _on_cancel_confirm_cancel_pressed() -> void:
	if is_enabled:
		var button = cancel_confirm_cancel
		button.pivot_offset = button.size / 2
		var t = create_tween()
		t.tween_property(button, "scale", Vector2(0.9, 0.9), 0.1)
		t.tween_property(button, "scale", Vector2.ONE, 0.2)
		GameManager.play_fx("cancel")


func _on_cancel_confirm_ok_pressed() -> void:
	if is_enabled:
		var button = cancel_confirm_ok
		button.pivot_offset = button.size / 2
		var t = create_tween()
		t.tween_property(button, "scale", Vector2(0.9, 0.9), 0.1)
		t.tween_property(button, "scale", Vector2.ONE, 0.2)
		GameManager.play_fx("ok")
