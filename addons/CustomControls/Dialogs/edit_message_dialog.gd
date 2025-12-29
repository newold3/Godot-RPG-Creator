@tool
extends Window

var current_message: RPGMessage
var target_callable: Callable


func _ready() -> void:
	close_requested.connect(hide)


func lock_id(value: bool) -> void:
	%IDLineEdit.set_editable(!value)


func edit_message(message: RPGMessage) -> void:
	%IDLineEdit.text = message.id
	%MessageLineEdit.text = message.message
	title = TranslationManager.tr("Edit Message")
	current_message = message.clone(true)
	select()


func new_message() -> void:
	current_message = RPGMessage.new()
	%IDLineEdit.text = ""
	%MessageLineEdit.text = ""
	title = TranslationManager.tr("Create A New Message")
	select()


func select() -> void:
	await get_tree().process_frame
	if %IDLineEdit.is_editable():
		%IDLineEdit.grab_focus()
	else:
		%MessageLineEdit.grab_focus()


func _on_id_line_edit_text_changed(new_text: String) -> void:
	current_message.id = new_text


func _on_message_line_edit_text_changed(new_text: String) -> void:
	current_message.message = new_text


func _on_ok_button_pressed() -> void:
	if target_callable:
		target_callable.call(current_message)
	
	hide()


func _on_cancel_button_pressed() -> void:
	hide()
