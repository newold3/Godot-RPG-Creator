extends Control


@export var hand_manipulator: String


var main_tween: Tween

var is_enabled: bool = false

@onready var buy_list: ItemList = %BuyList
@onready var sell_list: ItemList = %SellList
@onready var confirm_question: RichTextLabel = %ConfirmQuestion
@onready var complete_transaction: Button = %CompleteTransaction
@onready var cancel_transaction: Button = %CancelTransaction

var busy: bool = false
var last_button_selected: Button

signal cancel_pressed()
signal ok_pressed()


func _ready() -> void:
	pass


func focus() -> void:
	if last_button_selected:
		if last_button_selected == complete_transaction:
			complete_transaction.grab_focus()
		else:
			cancel_transaction.grab_focus()

func add_items(items: Array) -> void:
	var buy_item_list = items.filter(func(item): return item.source == "stock")
	var sell_item_list = items.filter(func(item): return item.source == "inventory")
	buy_list.add_items(buy_item_list)
	sell_list.add_items(sell_item_list)
	
	var total_transaction: int = 0
	
	for item in items:
		total_transaction += item.unit_price * item.quantity
	
	_update_total_label(total_transaction)


func _update_total_label(total_transaction: int) -> void:
	var text = RPGSYSTEM.database.terms.get_message("Shop Confirm Ticket Confirm")
	var total_transaction_str: String
	var extra_plus = "+" if total_transaction > 0 else ""
	var transaction_formatted = GameManager.get_number_formatted(total_transaction, 2, extra_plus)
	if total_transaction < 0:
		total_transaction_str = "[color=red]%s[/color]" % transaction_formatted
	elif total_transaction > 0:
		total_transaction_str = "[color=green]%s[/color]" % transaction_formatted
	else:
		total_transaction_str = "[color=#B0B0B0]%s[/color]" % transaction_formatted
		
	text = text.replace("\\n", total_transaction_str)
	confirm_question.text = text


func _process(_delta: float) -> void:
	if not hand_manipulator.is_empty() and not GameManager.get_cursor_manipulator() == hand_manipulator: return
	if is_enabled and not busy:
		var direction = ControllerManager.get_pressed_direction()
		if direction and direction in ["left", "right"]:
			var current = complete_transaction if complete_transaction.has_focus() else cancel_transaction
			var new_control = ControllerManager.get_closest_focusable_control(current, direction, true)
			if new_control:
				new_control.grab_focus()
				GameManager.play_fx("cursor")
					
		elif ControllerManager.is_confirm_pressed(false, [KEY_KP_ENTER]) or ControllerManager.is_key_pressed(KEY_ENTER) or ControllerManager.is_joy_button_pressed(JOY_BUTTON_START):
			if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and not %CompleteTransaction.get_global_rect().has_point(get_global_mouse_position()) and not %CancelTransaction.get_global_rect().has_point(get_global_mouse_position()):
				return
				
			if complete_transaction.has_focus():
				_on_complete_transaction_pressed()
			else:
				_on_cancel_transaction_pressed()
				
		elif ControllerManager.is_cancel_pressed([KEY_0, KEY_KP_0]) or ControllerManager.is_key_pressed(KEY_ESCAPE) or ControllerManager.is_joy_button_pressed(JOY_BUTTON_BACK):
			cancel_transaction.grab_focus()
			_on_cancel_transaction_pressed()


func start() -> void:
	if main_tween:
		main_tween.kill()
	
	busy = true
	is_enabled = false
	
	var node = %Back
	
	node.position.x = -905
	modulate.a = 0.0
	
	main_tween = create_tween()
	main_tween.set_parallel(true)
	
	main_tween.tween_property(node, "position:x", -14, 0.25).set_trans(Tween.TRANS_CIRC).set_ease(Tween.EASE_OUT).set_delay(0.1)
	main_tween.tween_property(self, "modulate:a", 1.0, 0.15).set_trans(Tween.TRANS_CIRC).set_ease(Tween.EASE_OUT)
	
	main_tween.set_parallel(false)
	main_tween.tween_callback(
		func():
			GameManager.show_cursor(MainHandCursor.HandPosition.LEFT, GameManager.get_cursor_manipulator())
			set("is_enabled", true)
			set("busy", false)
			complete_transaction.grab_focus()
	)


func end(emit_signal_enabled: bool = true) -> void:
	is_enabled = false
	busy = true
	
	if main_tween:
		main_tween.kill()
	
	var node = %Back
	
	main_tween = create_tween()
	main_tween.set_parallel(true)
	
	main_tween.tween_property(node, "position:x", -905, 0.25).set_trans(Tween.TRANS_CIRC).set_ease(Tween.EASE_OUT)
	main_tween.tween_property(self, "modulate:a", 0.0, 0.15).set_trans(Tween.TRANS_CIRC).set_ease(Tween.EASE_OUT).set_delay(0.1)
	
	main_tween.set_parallel(false)
	main_tween.tween_callback(
		func():
			set("visible", false)
			if emit_signal_enabled:
				cancel_pressed.emit()
	)


func _animate_button(button) -> void:
	button.pivot_offset = button.size / 2
	var t = create_tween()
	t.tween_property(button, "scale", Vector2(0.9, 0.9), 0.1)
	t.tween_property(button, "scale", Vector2.ONE, 0.2)
	await t.finished


func _on_complete_transaction_pressed(ignore_enabled: bool = false) -> void:
	if ignore_enabled: return
	busy = true
	GameManager.play_fx("select")
	await _animate_button(complete_transaction)
	end(false)
	ok_pressed.emit()

func _on_cancel_transaction_pressed(ignore_enabled: bool = false) -> void:
	if ignore_enabled: return
	busy = true
	GameManager.play_fx("cancel")
	await _animate_button(cancel_transaction)
	end()


func _on_complete_transaction_focus_entered() -> void:
	last_button_selected = complete_transaction
	var manipulator = hand_manipulator
	GameManager.set_cursor_manipulator(manipulator)
	GameManager.set_confin_area(Rect2(), manipulator)
	GameManager.set_hand_position(MainHandCursor.HandPosition.LEFT, manipulator)
	GameManager.set_cursor_offset(Vector2(10, 0), manipulator)


func _on_cancel_transaction_focus_entered() -> void:
	last_button_selected = cancel_transaction
	var manipulator = hand_manipulator
	GameManager.set_cursor_manipulator(manipulator)
	GameManager.set_confin_area(Rect2(), manipulator)
	GameManager.set_hand_position(MainHandCursor.HandPosition.RIGHT, manipulator)
	GameManager.set_cursor_offset(Vector2(-10, 0), manipulator)
