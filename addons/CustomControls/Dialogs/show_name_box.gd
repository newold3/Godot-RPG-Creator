@tool
extends Window


signal command_selected(type: int, value: Variant, pos: int)


func _ready() -> void:
	close_requested.connect(queue_free)
	%Name.set_disabled(true)
	%CharacterID.set_disabled(true)
	%EnemyID.set_disabled(true)
	%CheckBox1.set_pressed(true)


func set_data(type: int, value: String, pos: int) -> void:
	if type == 0:
		%Name.set_disabled(false)
		%CheckBox1.set_pressed(true)
		%Name.text = value
		%Name.grab_focus()
	elif type == 1:
		%CharacterID.set_disabled(false)
		%CheckBox2.set_pressed(true)
		if value:
			%CharacterID.text = TranslationManager.tr("Character ID = ") + value
		else:
			%CharacterID.text = TranslationManager.tr("Select character ID")
	elif type == 2:
		%EnemyID.set_disabled(false)
		%CheckBox3.set_pressed(true)
		if value:
			%EnemyID.text = TranslationManager.tr("Enemy ID = ") + value
		else:
			%EnemyID.text = TranslationManager.tr("Select enemy ID")
	
	var id = clamp(pos, 0, %Position.get_item_count() - 1)
	%Position.select(id)


func hide_box_position(value: bool) -> void:
	%BoxPosition.visible = !value
	size.y = min_size.y


func _on_ok_button_pressed() -> void:
	var type = 0 if %CheckBox1.is_pressed() else 1 if %CheckBox2.is_pressed() else 2
	var value = %Name.text if type == 0 else int(%CharacterID.text) if type == 1 else int(%EnemyID.text)
	var pos = %Position.get_selected_id()
	command_selected.emit(type, value, pos)
	queue_free()


func _on_cancel_button_pressed() -> void:
	queue_free()


func _on_check_box_1_toggled(toggled_on: bool) -> void:
	var node = %CheckBox1.get_parent().get_child(%CheckBox1.get_index() + 1)
	node.propagate_call("set_disabled", [!toggled_on])
	if toggled_on: %Name.grab_focus()


func _on_check_box_2_toggled(toggled_on: bool) -> void:
	var node = %CheckBox2.get_parent().get_child(%CheckBox2.get_index() + 1)
	node.propagate_call("set_disabled", [!toggled_on])


func _on_check_box_3_toggled(toggled_on: bool) -> void:
	var node = %CheckBox3.get_parent().get_child(%CheckBox3.get_index() + 1)
	node.propagate_call("set_disabled", [!toggled_on])


func _open_select_any_data_dialog(current_data, id_selected: int, title: String, target: int) -> void:
	var path = "res://addons/CustomControls/Dialogs/select_any_data_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	dialog.database = RPGSYSTEM.database
	
	dialog.destroy_on_hide = true
	dialog.selected.connect(_on_any_data_selected, CONNECT_ONE_SHOT)
	
	dialog.setup(current_data, id_selected, title, target)


func _on_any_data_selected(id: int, target: int) -> void:
	if id:
		if target == 0:
			%CharacterID.text = TranslationManager.tr("Character ID = %s") % id
		else:
			%EnemyID.text = TranslationManager.tr("Enemy ID = %s") % id


func _on_character_id_pressed() -> void:
	var data = RPGSYSTEM.database.actors
	var id_selected = max(1, min(int(%CharacterID.text), data.size()))
	_open_select_any_data_dialog(data, id_selected, "Select Actor", 0)


func _on_enemy_id_pressed() -> void:
	var data = RPGSYSTEM.database.enemies
	var id_selected = max(1, min(int(%CharacterID.text), data.size()))
	_open_select_any_data_dialog(data, id_selected, "Select Enemy", 1)
