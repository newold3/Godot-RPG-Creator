@tool
extends Window


signal command_selected(command_mode: int, pos: int)


func _ready() -> void:
	close_requested.connect(queue_free)


func set_data(command: Dictionary = {}) -> void:
	var regex = RegEx.new()
	regex.compile("(\\w+)=(\"[^\"]+\"|[^=,\\s\\]]+)(?:,([^=,\\s\\]]+))?")
	var matches = regex.search_all(command.get("args", ""))
	var args: Array = []
	var p_mode = 0
	var p_pos = 0
	for m in matches:
		var value = m.get_string(1)
		if value == "mode":
			p_mode = int(m.get_string(2))
		elif value == "pos":
			p_pos = int(m.get_string(2))
	
	var command_mode = clamp(p_mode, 0, 1)
	var pos = clamp(p_pos, 0, 1)

	%Mode.select(command_mode)
	%Position.select(pos)
	%Position.set_disabled(command_mode == 1)


func _on_ok_button_pressed() -> void:
	command_selected.emit(%Mode.get_selected_id(), %Position.get_selected_id())
	queue_free()


func _on_cancel_button_pressed() -> void:
	queue_free()


func _on_mode_item_selected(index: int) -> void:
	%Position.set_disabled(index == 1)
