@tool
extends CommandBaseDialog


var force_emit: bool = false
var current_data: Dictionary


func _ready() -> void:
	super()
	parameter_code = 30
	await get_tree().process_frame
	%Filename.grab_focus()


func set_data() -> void:
	current_data = parameters[0].parameters.duplicate()
	var text = current_data.get("text", "")
	set_text(text)


func fill_labels(data: Array[RPGEventCommand]) -> void:
	var items: Array = []
	if data:
		for command in data:
			if command.code == 29: # Label
				if !items.has(command.parameters.text):
					items.append(command.parameters.text)
	
	var node: PopupMenu = %FileSelector
	node.clear()
	for item in items:
		node.add_item(item)


func set_text(text: String) -> void:
	%Filename.text = text


func _on_ok_button_pressed() -> void:
	if force_emit or %Filename.text.length() > 0:
		current_data.text = %Filename.text.strip_edges()
		var commands: Array[RPGEventCommand] = build_command_list()
		command_changed.emit(commands)
	queue_free()


func build_command_list() -> Array[RPGEventCommand]:
	var commands: Array[RPGEventCommand] = super()
	commands[-1].parameters = current_data
	return commands


func _on_filename_item_selected(index: int) -> void:
	if %Filename.text == " ": %Filename.text = ""
	current_data.text = %Filename.text


func _on_file_selector_index_pressed(index: int) -> void:
	var text = %FileSelector.get_item_text(index).strip_edges()
	var node: LineEdit = %Filename
	node.text = text
	node.caret_column = text.length()
	node.select_all()


func _on_expand_list_pressed() -> void:
	if %FileSelector.get_item_count() == 0:
		return
		
	%ExpandList.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var node1 = %Filename
	var node2 = %FileSelector
	var text = node1.text.strip_edges()
	for i in node2.get_item_count():
		if node2.get_item_text(i) == text:
			node2.set_focused_item(i)
			break
	node2.size.x = node1.size.x
	node2.position.x = position.x + node1.global_position.x
	node2.position.y = position.y + node1.global_position.y + node1.size.y + 2
	node2.show()


func _on_file_selector_popup_hide() -> void:
	%ExpandList.mouse_filter = Control.MOUSE_FILTER_STOP
