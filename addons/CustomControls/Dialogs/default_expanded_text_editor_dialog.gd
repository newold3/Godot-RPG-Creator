@tool
extends Window

var current_message: RPGMessage
var target_textedit: TextEdit


func _ready() -> void:
	close_requested.connect(queue_free)
	visibility_changed.connect(_on_visibility_changed)


func set_target(target: TextEdit) -> void:
	%MainTextEdit.text = target.text
	target_textedit = target


func _on_ok_button_pressed() -> void:
	if target_textedit:
		target_textedit.text = %MainTextEdit.text
		target_textedit.select_all()
		target_textedit.text_changed.emit()
	
	queue_free()


func _on_cancel_button_pressed() -> void:
	queue_free()


func _on_visibility_changed() -> void:
	if visible:
		await get_tree().process_frame
		if visible:
			%MainTextEdit.select_all()
			%MainTextEdit.grab_focus()
