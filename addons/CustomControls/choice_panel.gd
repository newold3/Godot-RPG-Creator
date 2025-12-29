@tool
class_name ChoicePanel
extends HBoxContainer


signal delete_requested(choice_panel: ChoicePanel)


func _ready() -> void:
	update_id()


func update_id() -> void:
	%ID.text = "#%s" % str(get_index() + 1)
	disable_remove_button(get_index() == 0 or get_index() < get_parent().get_child_count() - 1)


func disable_remove_button(value: bool) -> void:
	$EraseChoice.set_disabled(value)


func set_choice_name(text: String) -> void:
	%Value.text = text


func get_choice_name() -> String:
	return %Value.text


func select() -> void:
	await get_tree().process_frame
	%Value.grab_focus()


func _on_erase_choice_pressed() -> void:
	delete_requested.emit(self)
