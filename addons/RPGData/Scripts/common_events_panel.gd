@tool
extends BasePanelData


var system = Engine.get_main_loop().root.get_node_or_null("RPGSYSTEM")


func get_custom_class() -> String:
	return "RPGCommonEvent"


func get_data() ->  RPGCommonEvent:
	if current_selected_index != -1:
		current_selected_index = max(0, min(current_selected_index, data.size() - 1))
		return data[current_selected_index]
	else:
		return null


func _ready() -> void:
	super()
	visibility_changed.connect(
		func():
			if visible:
				%EventPageListEditor._fill_favorite_buttons()
	)
	default_data_element = RPGCommonEvent.new()


func _update_data_fields() -> void:
	busy = true
	
	if current_selected_index != -1:
		disable_all(false)
		%NameLineEdit.text = data[current_selected_index].name
		%TriggerOptions.select(data[current_selected_index].trigger)
		%SwitchButton.set_disabled(data[current_selected_index].trigger == 0)
		set_switch_name()
		
		if data[current_selected_index].list.size() == 0:
			data[current_selected_index].list.append(RPGEventCommand.new())
		%EventPageListEditor.set_data(data[current_selected_index].list)
	else:
		disable_all(true)
		%NameLineEdit.text = ""
	
	%Notes.text = str(data[current_selected_index].notes)
	
	busy = false


func _on_trigger_options_item_selected(index: int) -> void:
	data[current_selected_index].trigger = index
	%SwitchButton.set_disabled(index == 0)


func _on_switch_changed(index: int, target: Node) -> void:
	data[current_selected_index].switch_id = index
	set_switch_name()


func set_switch_name() -> void:
	if system:
		var index = data[current_selected_index].switch_id
		var switch_name = "%s:%s" % [
			str(index).pad_zeros(4),
			system.system.switches.get_item_name(index)
		]
		%SwitchButton.text = switch_name


func _on_switch_button_pressed() -> void:
	var path = "res://addons/CustomControls/Dialogs/switch_variable_dialog.tscn"
	var callable = _on_switch_changed
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	dialog.data_type = 1
	dialog.target = %SwitchButton
	dialog.selected.connect(callable)
	dialog.variable_or_switch_name_changed.connect(set_switch_name)
	dialog.setup(data[current_selected_index].switch_id)


func _on_notes_text_changed() -> void:
	data[current_selected_index].notes = %Notes.text


func _on_config_data_tabs_tab_changed(index: int) -> void:
	var node_path = "%%Tab%s" % (index + 1)
	var node = get_node_or_null(node_path)
	if node:
		for child in node.get_parent().get_children():
			child.visible = false
		node.visible = true


func _on_visibility_changed() -> void:
	if data[current_selected_index].list.size() == 0:
		data[current_selected_index].list.append(RPGEventCommand.new())
	%EventPageListEditor.set_data(data[current_selected_index].list)
