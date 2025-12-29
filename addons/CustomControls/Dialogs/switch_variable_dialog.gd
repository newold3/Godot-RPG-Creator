@tool
extends Window

signal item_selected(index: int)

var data
var target

@export_enum("Variables", "Switches", "Text Variables") var data_type: int = 0


signal selected(id: int, target)
signal variable_or_switch_name_changed()


func _ready() -> void:
	close_requested.connect(queue_free)


func setup(id_selected: int) -> void:
	var node = Engine.get_main_loop().root.get_node_or_null("RPGSYSTEM")

	if node:
		if data_type == 0:
			data = node.system.variables.clone(true)
			set_label("variables")
		elif data_type == 1:
			data = node.system.switches.clone(true)
			set_label("switches")
		elif data_type == 2:
			data = node.system.text_variables.clone(true)
			set_label("variables")
		var index1: int = id_selected / 20
		var index2: int = id_selected % 20 - 1
		fill_list1(index1, index2)
	else:
		clear_all()
	
	await get_tree().process_frame
	%List2.grab_focus()


func clear_all() -> void:
	data = null
	%List1.clear()
	%List2.clear()
	%EditNameControl.text = ""
	%EditNameControl.editable = false


func set_label(_title: String) -> void:
	title = _title.to_camel_case()
	%SimpleLabel.set_title(_title)


func fill_list1(index: int, index2: int) -> void:
	var list = %List1
	list.clear()
	
	if data.size() == 0:
		disable_list2()
		return
	
	var data_size = data.size()
	var s: int = ceil(data_size / 20.0) if data_size >= 20 else 1

	list.busy = true
	for i in range(s):
		var from = (i * 20) + 1
		var to = min(from + 19, data_size)
		var item = "[%s - %s]" % [str(from).pad_zeros(s-1), str(to).pad_zeros(s-1)]
		list.add_item(item)
	list.busy = false
	list.queue_redraw()
	
	if index < list.item_count:
		list.select(index)
		fill_list2(index, index2)
	elif list.item_count > 0:
		index = list.item_count - 1
		list.select(index)
		fill_list2(index, index2)
	else:
		disable_list2()


func fill_list2(lis1_index: int, list2_index: int) -> void:
	var list = %List2
	list.clear()
	%EditNameControl.text = ""
	%EditNameControl.editable = false
	
	var data_size = data.size()
	var s = ceil(data_size / 20.0) if data_size >= 20 else 1
	var from = (lis1_index * 20) + 1
	var to = min(from + 20, data_size+1)
	list.busy = true
	for i in range(from, to):
		var item_name = data.get_item_name(i)
		var item = "%s:%s" % [str(i).pad_zeros(s-1), item_name]
		list.add_item(item)
	list.busy = false
	list.queue_redraw()
	
	if list2_index < list.item_count:
		list.select(list2_index)
		var index = lis1_index * 20 + list2_index + 1
		%EditNameControl.text = data.get_item_name(index)
		%EditNameControl.editable = true
	elif list.item_count > 0:
		list2_index = list.item_count - 1
		list.select(list.item_count - 1)
		var index = lis1_index * 20 + list2_index + 1
		%EditNameControl.text = data.get_item_name(index)
		%EditNameControl.editable = true


func disable_list2() -> void:
	%List2.clear()
	%EditNameControl.text = ""
	%EditNameControl.editable = false


func _on_list_1_item_selected(index: int) -> void:
	fill_list2(index, 0)


func _on_list_2_item_selected(index2: int) -> void:
	var index1 = %List1.get_selected_items()[0] * 20
	var index = index1 + index2
	if index >= 0:
		%EditNameControl.editable = true
		%EditNameControl.text = data.get_item_name(index+1)
	else:
		%EditNameControl.editable = false
		%EditNameControl.text = ""


func _on_edit_name_control_focus_entered() -> void:
	%EditNameControl.select_all()
	%EditNameControl.set_caret_column(%EditNameControl.text.length())


func _on_edit_name_control_text_changed(item_name: String) -> void:
	var index1 = %List1.get_selected_items()[0] * 20
	var index2 = %List2.get_selected_items()[0] + 1
	var index = index1 + index2
	data.set_item_name(index, item_name)
	var s = ceil(data.size() / 20.0) if data.size() >= 20 else 1
	var item = "%s:%s" % [str(index).pad_zeros(s-1), item_name]
	%List2.set_item_text(index2-1, item)
	%ApplyButton.set_disabled(false)


func _on_apply_button_pressed() -> void:
	var node = Engine.get_main_loop().root.get_node_or_null("RPGSYSTEM")
	if node:
		if data_type == 0:
			node.system.variables = data.clone(true)
		elif data_type == 1:
			node.system.switches = data.clone(true)
		elif data_type == 2:
			node.system.text_variables = data.clone(true)
	
	%ApplyButton.set_disabled(true)
	
	variable_or_switch_name_changed.emit()


func _on_ok_button_pressed() -> void:
	_on_apply_button_pressed()
	var index1 = %List1.get_selected_items()[0] * 20
	var index2 = %List2.get_selected_items()[0] + 1
	var index = index1 + index2
	selected.emit(index, target)
	queue_free()


func _on_cancel_button_pressed() -> void:
	queue_free()


func _on_change_max_button_pressed() -> void:
	var path = "res://addons/CustomControls/Dialogs/change_max_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	dialog.set_value(data.size())
	dialog.apply_changes.connect(_on_change_data_size)
	


func _on_change_data_size(value: int) -> void:
	if value != data.size():
		data.resize(value)
		fill_list1(%List1.get_selected_items()[0], %List2.get_selected_items()[0])


func _on_list_2_item_activated(index2: int) -> void:
	var index1 = %List1.get_selected_items()[0] * 20
	var index = index1 + index2 + 1
	item_selected.emit(index)
	_on_ok_button_pressed()


func _on_list_1_item_activated(index: int) -> void:
	var index1 = index * 20
	var index2 = %List2.get_selected_items()[0] + 1
	index = index1 + index2
	item_selected.emit(index)
	_on_ok_button_pressed()
