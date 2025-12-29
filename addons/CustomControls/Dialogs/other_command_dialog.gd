@tool
extends Window


var select_any_data_dialog: Window
static var cache: Dictionary
var busy: bool = false


signal command_selected(command: String)


func _ready() -> void:
	if !cache:
		cache = {}
	close_requested.connect(queue_free)
	%CommandType.select(0)
	%CommandType.item_selected.emit(0)
	%ChainSize.set_pressed(cache.get("chain_size", true))


func set_data(selected_comand_id: int, value: int, show_icon_pressed: bool, width:int, height: int, show_icon_pressed2: bool = false) -> void:
	busy = true
	if selected_comand_id == -1:
		selected_comand_id = cache.get("last_index_used", 0)
	var id = clamp(selected_comand_id, 0, %CommandType.get_item_count() - 1)
	%CommandType.select(id)
	%CommandType.item_selected.emit(id)
	%ID.value = value
	%ShowIcon.set_pressed(show_icon_pressed)
	%ShowIcon2.set_pressed(show_icon_pressed2)
	%ShowIcon2.visible = selected_comand_id == 3
	%SizeContainer.visible = selected_comand_id != 3
	busy = false


func _on_ok_button_pressed() -> void:
	busy = true
	propagate_call("apply")
	busy = false
	var index = %CommandType.get_selected_id()
	var command_name = ["variable", "actor", "party", "gold", "class", "item", "weapon", "armor", "enemy", "state", "profession_name", "profession_level"][index]
	var args: String = ""
	if index in [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]:
		if index != 2 and index != 3 and index != 11:
			args = " id=%s extra=%s" % [%ID.value, int(%ShowIcon.is_pressed())]
		elif index != 3:
			args = " id=%s" % %ID.value
		elif index == 3:
			args = " extra=%s extra2=%s" % [int(%ShowIcon.is_pressed()), int(%ShowIcon2.is_pressed())]
	if !index in [0, 2, 3, 11]:
		if %Width.value != 0 and %Height.value != 0:
			args += " size=%sx%s" % [%Width.value, %Height.value]
		elif %Width.value != 0:
			args += " size=%s" % %Width.value
		elif %Height.value != 0:
			args += " size=%s" % %Height.value
	var command = "[" + command_name + args + "]"
	command_selected.emit(command)
	
	cache.last_index_used = index
	
	queue_free()


func _on_cancel_button_pressed() -> void:
	queue_free()


func _on_command_type_item_selected(index: int) -> void:
	if index in [0, 1, 4, 5, 6, 7, 8, 9, 10]:
		%SetValue.set_disabled(false)
		if index == 0:
			%ShowIcon.text = TranslationManager.tr("Show variable name to the left of the value?")
		else:
			%ShowIcon.text = TranslationManager.tr("Show icon to the left of the name?")
		%ShowIcon.set_disabled(false)
		%ID.set_disabled(false)
		%ID.min_value = 1
		%SizeContainer.visible = true
		%ShowIcon2.visible = false
	elif index == 3:
		%SetValue.set_disabled(true)
		%ID.set_disabled(true)
		%ShowIcon.set_disabled(false)
		%ShowIcon.text = TranslationManager.tr("Show currency unit after value?")
		%SizeContainer.visible = false
		%ShowIcon2.visible = true
	else:
		%ShowIcon.set_disabled(true)
		%SetValue.set_disabled(index != 11)
		%ID.set_disabled(index == 3)
		%ID.min_value = 0
		%SizeContainer.visible = true
		%ShowIcon2.visible = false
	
	var disable_size = index in [0, 2, 3, 11] or !%ShowIcon.is_pressed()
	%Width.set_disabled(disable_size)
	%Height.set_disabled(disable_size)


func _open_select_any_data_dialog(current_data, id_selected: int, title: String, target: int) -> void:
	var path = "res://addons/CustomControls/Dialogs/select_any_data_dialog.tscn"
	var parent = self
	var dialog
	if select_any_data_dialog:
		dialog = select_any_data_dialog
		RPGDialogFunctions.show_dialog(dialog, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	else:
		dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
		dialog.database = RPGSYSTEM.database
	
	dialog.selected.connect(_on_any_data_selected, CONNECT_ONE_SHOT)
	
	dialog.setup(current_data, id_selected, title, target)


func _on_any_data_selected(id: int, _data_index: int) -> void:
	%ID.value = id


func _open_select_variable_dialog(id_selected: int) -> void:
	var path = "res://addons/CustomControls/Dialogs/switch_variable_dialog.tscn"
	var callable = _on_any_data_selected
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	dialog.data_type = 0
	dialog.target = -1
	dialog.selected.connect(callable)
	dialog.setup(id_selected)


func _on_set_value_pressed() -> void:
	var index = %CommandType.get_selected_id()
	var value = %ID.value
	match index:
		0: _open_select_variable_dialog(max(1, index))
		1: _open_select_any_data_dialog(RPGSYSTEM.database.actors, value, "Select Actor", index)
		4: _open_select_any_data_dialog(RPGSYSTEM.database.classes, value, "Select Class", index)
		5: _open_select_any_data_dialog(RPGSYSTEM.database.items, value, "Select Item", index)
		6: _open_select_any_data_dialog(RPGSYSTEM.database.weapons, value, "Select Weapon", index)
		7: _open_select_any_data_dialog(RPGSYSTEM.database.armors, value, "Select Armor", index)
		8: _open_select_any_data_dialog(RPGSYSTEM.database.enemies, value, "Select Enemy", index)
		9: _open_select_any_data_dialog(RPGSYSTEM.database.states, value, "Select State", index)
		10: _open_select_any_data_dialog(RPGSYSTEM.database.professions, value, "Select Profession", index)
		11: _open_select_any_data_dialog(RPGSYSTEM.database.professions, value, "Select Profession", index)


func _on_show_icon_toggled(toggled_on: bool) -> void:
	var id = %CommandType.get_selected_id()
	if !id in [0, 2, 3]:
		%Width.set_disabled(!toggled_on)
		%Height.set_disabled(!toggled_on)


func _on_chain_size_toggled(toggled_on: bool) -> void:
	cache.chain_size = toggled_on


func _on_width_value_updated(old_value: float, new_value: float) -> void:
	if busy: return
	if cache.get("chain_size", true):
		busy = true
		if old_value != 0:
			var ratio: float = new_value / old_value
			%Height.value = %Height.value * ratio
		else:
			%Height.value = 0
		busy = false


func _on_height_value_updated(old_value: float, new_value: float) -> void:
	if busy: return
	if cache.get("chain_size", true):
		busy = true
		if old_value != 0:
			var ratio: float = new_value / old_value
			%Width.value = %Width.value * ratio
		else:
			%Width.value = 0
		busy = false
