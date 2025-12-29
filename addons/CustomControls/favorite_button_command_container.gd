@tool
extends HFlowContainer

var command_buttons: Array

const FAVORITE_BUTTON = preload("uid://bawafq08jue4j")

signal create_command_requested(id: int)


func fill() -> void:
	var favorites = FileCache.options.get("current_favorite_commands", [])

	var node = %FavoriteButtonContainer
	if command_buttons.is_empty():
		var buttons_dialog = load("res://addons/CustomControls/Dialogs/event_commands_dialog.tscn").instantiate()
		buttons_dialog.visible = false
		add_child(buttons_dialog)
		command_buttons = buttons_dialog.get_buttons()
		for i in command_buttons.size():
			command_buttons[i] = command_buttons[i].duplicate()
		buttons_dialog.queue_free()

	for child in node.get_children():
		remove_child(child)
		child.queue_free()
	
	size.y = 0
	
	for favorite_id in favorites:
		var b = FAVORITE_BUTTON.instantiate()
		b.custom_minimum_size = Vector2(24, 24)
		var real_button = command_buttons.filter(func(button): return int(button.name) == favorite_id)
		if not real_button.is_empty():
			var button = real_button[0]
			b.text = button.text.get_slice(" ", 0)
			var help_text = button.get_meta("current_tooltip") if button.has_meta("current_tooltip") else button.tooltip_text
			b.tooltip_text = help_text
			b.mouse_filter = MOUSE_FILTER_STOP
			b.z_index = 10
			b.pressed.connect(
				func():
					create_command_requested.emit(favorite_id)
			)
			node.add_child(b)
