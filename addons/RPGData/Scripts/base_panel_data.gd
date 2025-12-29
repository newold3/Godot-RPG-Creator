@tool
class_name BasePanelData
extends HBoxContainer


var data: Array
var database: RPGDATA
var default_data_element

var current_selected_index: int = -1

var need_fix_data: bool = false

var busy: bool = false
var busy2: bool = false

var current_step: int = 0
var locked_items: Array = [0]

var is_disabled: bool = false

var main_list_popup_menu: PopupMenu
const MAIN_LIST_POPUP_MENU = preload("res://addons/RPGData/Scenes/main_list_popup_menu.tscn")

signal disable_right_panel()
signal item_created(item: Variant)


func _ready() -> void:
	main_list_popup_menu = MAIN_LIST_POPUP_MENU.instantiate()
	main_list_popup_menu.index_pressed.connect(_on_main_list_popup_menu_index_pressed)
	main_list_popup_menu.visible = false
	add_child(main_list_popup_menu)
	var node: ItemList = %MainList
	node.gui_input.connect(_on_main_list_gui_input)
	visibility_changed.connect(_on_visibility_changed)


func set_data(_data: Array) -> void:
	data = _data
	fill_main_list(0)
	%AddDataButton.set_disabled(data.size() == 10000)
	%RemoveDataButton.set_disabled(locked_items.has(0) or data.size() <= 1 )
	
	if data.size() <= 1:
		disable_all(true)


func fill_main_list(selected_index: int) -> void:

	var node: ItemList = %MainList

	if selected_index == -1 and node.is_anything_selected():
		selected_index = node.get_selected_items()[0]
	node.clear()

	for i in range(1, data.size()):
		var id = str(i).pad_zeros(str(data.size()-1).length())
		
		var data_name = id + ": " + data[i].name
		node.add_item(data_name)
		node.set_item_tooltip_enabled(-1,  false)

	if selected_index >= 0 and node.get_item_count() > selected_index:
		node.select(selected_index)
		node.multi_selected.emit(selected_index, true)
		node.ensure_current_is_visible()
		%RemoveDataButton.set_disabled(locked_items.has(selected_index))
	elif node.get_item_count() == 0:
		%RemoveDataButton.set_disabled(true)

	for lock_id in locked_items:
		node.lock_item(lock_id, true)

	if !node.is_anything_selected():
		disable_right_panel.emit()
		is_disabled = true


func _on_add_data_button_pressed() -> void:
	var node: ItemList = %MainList
	var new_data = default_data_element.clone(true)
	initialize_data(new_data)
	data.append(new_data)
	var current_index = node.get_item_count()
	var id = str(current_index+1).pad_zeros(str(data.size()-1).length())
	var data_name = id + ": "
	node.add_item(data_name)
	node.select(current_index)
	node.multi_selected.emit(current_index, true)
	
	%AddDataButton.set_disabled(data.size() == 10000)
	%RemoveDataButton.set_disabled(locked_items.has(current_index) or data.size() <= 1)
	
	fix_ids()
	need_fix_data = true
	
	item_created.emit(new_data)


func _on_remove_data_button_pressed() -> void:
	var node: ItemList = %MainList
	if node.is_anything_selected():
		var selected_indexes = node.get_selected_items()
		var remove_items: Array = []
		for i in range(selected_indexes.size() - 1, -1, -1):
			var id = selected_indexes[i]
			if !locked_items.has(id):
				remove_items.append(data[id+1])
				node.remove_item(id)

		for item in remove_items:
			data.erase(item)

		var selected_index = max(0, min(node.get_item_count() - 1, selected_indexes[0] - 1))

		if selected_indexes[0] > 0:
			node.select(selected_index)
			node.multi_selected.emit(selected_index, true)
		elif node.get_item_count() > 0:
			node.select(0)
			node.multi_selected.emit(0, true)
			selected_index = 0
		else:
			is_disabled = true
			%RightColumn.propagate_call("set_disabled", [true])
			%RightColumn.propagate_call("set_editable", [false])
			disable_right_panel.emit()
		
		%RemoveDataButton.set_disabled(locked_items.has(selected_index) or data.size() <= 1)
		
		fix_ids()
		need_fix_data = true


func fix_ids() -> void:
	var node = %MainList
	for i in node.get_item_count():
		var text: String = node.get_item_text(i)
		var id = str(int(text.get_slice(":", 0))).pad_zeros(str(data.size()-1).length())
		var item_name = text.get_slice(":", 1).strip_edges()
		var new_text = id + ": " + item_name
		node.set_item_text(i, new_text)
	
	for i in data.size():
		var item = data[i]
		if item and "id" in item:
			item.id = i


func _on_main_list_multi_selected(index: int, selected: bool) -> void:
	var step = current_step
	if current_selected_index != -1:
		var viewport = get_viewport()
		if viewport:
			var focus_owner = get_viewport().gui_get_focus_owner()
			if focus_owner is LineEdit and focus_owner.get_parent() is SpinBox:
				focus_owner.get_parent().apply()
		else:
			pass
		#%RightColumn.propagate_call("apply")
		if is_inside_tree():
			await get_tree().process_frame
			await get_tree().process_frame
			await get_tree().process_frame
		else:
			return
		if step != current_step:
			return
	current_step = wrapi(current_step + 1, 0, 1000)
	var node = %MainList
	if node.is_anything_selected():
		index = node.get_selected_items()[-1]
	else:
		if node.get_item_count() > 0:
			index = 0
			node.select(0)
		else:
			%RightColumn.propagate_call("set_disabled", [true])
			%RightColumn.propagate_call("set_editable", [false])
			%RemoveDataButton.set_disabled(true)
			disable_right_panel.emit()
			is_disabled = true
			return
	%RemoveDataButton.set_disabled(locked_items.has(index) or data.size() <= 1)
	current_selected_index = index + 1
	
	if is_disabled:
		is_disabled = false
		%RightColumn.propagate_call("set_disabled", [false])
		%RightColumn.propagate_call("set_editable", [true])
	
	_update_data_fields()


func _on_main_list_item_selected(index: int) -> void:
	pass


func _on_name_line_edit_text_changed(new_text: String) -> void:
	data[current_selected_index].name = new_text
	var id = str(current_selected_index).pad_zeros(str(data.size()-1).length())
	var data_name = id + ": " + new_text
	%MainList.set_item_text(current_selected_index-1, data_name)


func disable_all(value: bool) -> void:
	%RightColumn.propagate_call("set_disabled", [value])
	
	if value:
		reset_values(%RightColumn)


func reset_values(node: Node) -> void:
	if "value" in node:
		node.value = 0
	elif node is OptionButton and node.get_item_count() > 0:
		node.select(0)
	elif "text" in node:
		node.text = ""
	elif node.get_class() in ["ColumnItemList", "CurveParameter"]:
		node.clear()
	elif node.get_class() == "CustomimagePicker":
		node.set_icon(null)
	
	for child in node.get_children():
		reset_values(child)


func _update_data_fields() -> void:
	pass


func _on_visibility_changed() -> void:
	if !visible and need_fix_data:
		_fix_data()
	elif visible:
		need_fix_data = false


func _fix_data() -> void:
	pass


func initialize_data(item) -> void:
	pass


func _on_main_list_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.is_pressed():
		show_main_list_popup_menu()


func show_main_list_popup_menu() -> void:
	var data_name: String
	if has_method("get_custom_class"):
		data_name = call("get_custom_class")
	else:
		data_name = call("get_data").get_class()
	data_name += "_data"
	main_list_popup_menu.set_item_disabled(1, !StaticEditorVars.CLIPBOARD.get(data_name, null))
	main_list_popup_menu.show()
	var mouse_position = Vector2(DisplayServer.mouse_get_position())
	var p: Vector2 = mouse_position - main_list_popup_menu.size * 0.5
	main_list_popup_menu.position = p


func _on_main_list_popup_menu_index_pressed(menu_index: int) -> void:
	match menu_index:
		0: copy_main_data()
		1: paste_main_data()
		3: clear_main_data()


func copy_main_data() -> void:
	var indexes = %MainList.get_selected_items()
	var copy_data: Array
	
	for index in indexes:
		copy_data.append(data[index+1].clone(true))
		
	var data_name: String
	if has_method("get_custom_class"):
		data_name = call("get_custom_class")
	else:
		data_name = call("get_data").get_class()
	data_name += "_data"

	StaticEditorVars.CLIPBOARD[data_name] = copy_data


func paste_main_data() -> void:
	var indexes = %MainList.get_selected_items()
	
	var data_name: String
	if has_method("get_custom_class"):
		data_name = call("get_custom_class")
	else:
		data_name = call("get_data").get_class()
	data_name += "_data"
	
	var paste_data = StaticEditorVars.CLIPBOARD.get(data_name, null)
	if paste_data:
		var paste_index = 0
		for index in indexes:
			var real_index = index + 1
			if paste_data.size() > paste_index:
				var current_id = data[real_index].id
				data[real_index] = paste_data[paste_index].clone(true)
				data[real_index].id = current_id
			else:
				break
			paste_index += 1
	
		fill_main_list(current_selected_index)
		
		%MainList.deselect_all()
		for index in indexes:
			%MainList.select(index, false)
		
		_on_main_list_multi_selected(current_selected_index, true)


func clear_main_data() -> void:
	var indexes = %MainList.get_selected_items()
	
	for index in indexes:
		var real_index = index + 1
		data[real_index].call("clear")
	
	fill_main_list(current_selected_index)
		
	%MainList.deselect_all()
	for index in indexes:
		%MainList.select(index, false)
	
	_on_main_list_multi_selected(current_selected_index, true)
