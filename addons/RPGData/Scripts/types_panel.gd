@tool
extends HBoxContainer


var data: RPGTypes
var database: RPGDATA
var need_fix_data: bool = false


func _ready() -> void:
	visibility_changed.connect(_on_visibility_changed)


func set_data(real_data: RPGTypes) -> void:
	data = real_data
	fill_list(%ElementList, data.element_types, 0, 1)
	fill_list(%SkillList, data.skill_types, 0, 2)
	fill_list(%WeaponList, data.weapon_types, 0, 3)
	fill_list(%WeaponRarityList, data.weapon_rarity_types, 0, "3b")
	fill_list(%ArmorList, data.armor_types, 0, 4)
	fill_list(%ArmorRarityList, data.armor_rarity_types, 0, "4b")
	fill_list(%ItemList, data.item_types, 0, 5)
	fill_list(%ItemRarityList, data.item_rarity_types, 0, "5b")
	fill_list(%EquipmentList, data.equipment_types, 0, 6)
	fill_list(%UserParametersList, data.user_parameters, 0, "6b")
	fill_list(%UserStatsList, data.user_stats, 0, "7b")
	fill_list(%MainParametersList, data.main_parameters, 0, "10")
	
	%ElementList.lock_item(0, true)
	%SkillList.lock_item(0, true)
	%WeaponList.lock_item(0, true)
	%WeaponRarityList.lock_item(0, true)
	%ArmorList.lock_item(0, true)
	%ArmorRarityList.lock_item(0, true)
	%ItemList.lock_item(0, true)
	%ItemRarityList.lock_item(0, true)
	%EquipmentList.lock_item(0, true)
	
	for i in data.main_parameters.size():
		%MainParametersList.lock_item(i, true)


func fill_list(itemlist: ItemList, items: Array, item_selected: int, button_id: Variant) -> void:
	itemlist.clear()
	if items.size() == 0:
		if str(button_id) == "6b":
			%Name6bLineEdit.set_disabled(true)
			%ParameterValue.set_disabled(true)
			%RemoveItem6bButton.set_disabled(true)
			%Name6bLineEdit.text = ""
			if %Name6bLineEdit.has_focus(): %Name6bLineEdit.release_focus()
			if %Name6bLineEdit.has_meta("original_text"):
				%Name6bLineEdit.remove_meta("original_text")
		elif str(button_id) == "7b":
			%Name7bLineEdit.set_disabled(true)
			%RemoveItem7bButton.set_disabled(true)
			%Name7bLineEdit.text = ""
			if %Name7bLineEdit.has_focus(): %Name7bLineEdit.release_focus()
			if %Name7bLineEdit.has_meta("original_text"):
				%Name7bLineEdit.remove_meta("original_text")
		return
	for i in items.size():
		var id = str(i+1).pad_zeros(str(items.size()).length())
		var item_name: String
		if items[i] is String:
			item_name = id + ": " + items[i]
		elif items[i] is RPGUserParameter:
			item_name = id + ": " + items[i].name
		itemlist.add_item(item_name)
	if item_selected >= 0 and item_selected < items.size():
		itemlist.select(item_selected)
		itemlist.item_selected.emit(item_selected)
		itemlist.ensure_current_is_visible()
	elif items.size() > 0:
		itemlist.select(0)
		itemlist.item_selected.emit(0)
		itemlist.ensure_current_is_visible()
	else:
		get_node("%Name%sLineEdit" % button_id).set_disabled(true)
		if button_id != "10":
			get_node("%RemoveItem%sButton" % button_id).set_disabled(true)
		get_node("%IconPicker%s" % button_id).set_disabled(true)
	if str(button_id) == "6b":
		var enabled = %UserParametersList.get_selected_items().size() > 0
		%Name6bLineEdit.set_disabled(!enabled)
		%ParameterValue.set_disabled(!enabled)
		%RemoveItem6bButton.set_disabled(!enabled)
		if !enabled:
			%Name6bLineEdit.text = ""
			if %Name6bLineEdit.has_focus(): %Name6bLineEdit.release_focus()
	elif str(button_id) == "7b":
		var enabled = %UserStatsList.get_selected_items().size() > 0
		if !enabled:
			%Name7bLineEdit.text = ""
			if %Name7bLineEdit.has_focus(): %Name7bLineEdit.release_focus()
		%Name7bLineEdit.set_disabled(!enabled)
		%RemoveItem7bButton.set_disabled(!enabled)


func _on_element_list_item_selected(index: int) -> void:
	%Name1LineEdit.text = data.element_types[index]
	%RemoveItem1Button.set_disabled(index == 0)
	var current_icon = data.icons.element_icons[index]
	%IconPicker1.set_disabled(false)
	%IconPicker1.set_icon(current_icon.path, current_icon.region)
	var current_element_color = data.element_colors[index]
	%ElementAttackColor.set_pick_color(current_element_color)
	#data.colorize_element_numbers.resize(data.element_types.size())
	var using_element_color = data.colorize_element_numbers[index]
	%ColorizeElementNumbers.set_pressed(using_element_color == 1)


func _on_name_1_line_edit_text_changed(new_text: String) -> void:
	var index = %ElementList.get_selected_items()[0]
	data.element_types[index] = new_text
	var id = str(index+1).pad_zeros(str(data.element_types.size()).length())
	var item_name = id + ": " + new_text
	%ElementList.set_item_text(index, item_name)


func _on_add_item_1_button_pressed() -> void:
	data.element_types.append("")
	data.icons.element_icons.append(RPGIcon.new())
	data.element_colors.resize(data.element_types.size())
	data.colorize_element_numbers.resize(data.element_types.size())
	fill_list(%ElementList, data.element_types, data.element_types.size() - 1, 1)
	%Name1LineEdit.grab_focus()
	need_fix_data = true


func _on_remove_item_1_button_pressed() -> void:
	var index = %ElementList.get_selected_items()[0]
	if index > 0:
		data.element_types.remove_at(index)
		data.icons.element_icons.remove_at(index)
		index = min(index, data.element_types.size() - 1)
		fill_list(%ElementList, data.element_types, index, 1)
		need_fix_data = true


func _on_skill_list_item_selected(index: int) -> void:
	%Name2LineEdit.text = data.skill_types[index]
	%RemoveItem2Button.set_disabled(index == 0)
	var current_icon = data.icons.skill_icons[index]
	%IconPicker2.set_disabled(false)
	%IconPicker2.set_icon(current_icon.path, current_icon.region)


func _on_name_2_line_edit_text_changed(new_text: String) -> void:
	var index = %SkillList.get_selected_items()[0]
	data.skill_types[index] = new_text
	var id = str(index+1).pad_zeros(str(data.skill_types.size()).length())
	var item_name = id + ": " + new_text
	%SkillList.set_item_text(index, item_name)


func _on_add_item_2_button_pressed() -> void:
	data.skill_types.append("")
	data.icons.skill_icons.append(RPGIcon.new())
	fill_list(%SkillList, data.skill_types, data.skill_types.size() - 1, 2)
	%Name2LineEdit.grab_focus()
	need_fix_data = true


func _on_remove_item_2_button_pressed() -> void:
	var index = %SkillList.get_selected_items()[0]
	if index > 0:
		data.skill_types.remove_at(index)
		data.icons.skill_icons.remove_at(index)
		index = min(index, data.skill_types.size() - 1)
		fill_list(%SkillList, data.skill_types, index, 2)
		need_fix_data = true


func _on_weapon_list_item_selected(index: int) -> void:
	%Name3LineEdit.text = data.weapon_types[index]
	%RemoveItem3Button.set_disabled(index == 0)
	var current_icon = data.icons.weapon_icons[index]
	%IconPicker3.set_disabled(false)
	%IconPicker3.set_icon(current_icon.path, current_icon.region)


func _on_name_3_line_edit_text_changed(new_text: String) -> void:
	var index = %WeaponList.get_selected_items()[0]
	data.weapon_types[index] = new_text
	var id = str(index+1).pad_zeros(str(data.weapon_types.size()).length())
	var item_name = id + ": " + new_text
	%WeaponList.set_item_text(index, item_name)


func _on_add_item_3_button_pressed() -> void:
	data.weapon_types.append("")
	data.icons.weapon_icons.append(RPGIcon.new())
	fill_list(%WeaponList, data.weapon_types, data.weapon_types.size() - 1, 3)
	%Name3LineEdit.grab_focus()
	need_fix_data = true


func _on_remove_item_3_button_pressed() -> void:
	var index = %WeaponList.get_selected_items()[0]
	if index > 0:
		data.weapon_types.remove_at(index)
		data.icons.weapon_icons.remove_at(index)
		index = min(index, data.weapon_types.size() - 1)
		fill_list(%WeaponList, data.weapon_types, index, 3)
		need_fix_data = true


func _on_armor_list_item_selected(index: int) -> void:
	%Name4LineEdit.text = data.armor_types[index]
	%RemoveItem4Button.set_disabled(index == 0)
	var current_icon = data.icons.armor_icons[index]
	%IconPicker4.set_disabled(false)
	%IconPicker4.set_icon(current_icon.path, current_icon.region)


func _on_name_4_line_edit_text_changed(new_text: String) -> void:
	var index = %ArmorList.get_selected_items()[0]
	data.armor_types[index] = new_text
	var id = str(index+1).pad_zeros(str(data.armor_types.size()).length())
	var item_name = id + ": " + new_text
	%ArmorList.set_item_text(index, item_name)


func _on_add_item_4_button_pressed() -> void:
	data.armor_types.append("")
	data.icons.armor_icons.append(RPGIcon.new())
	fill_list(%ArmorList, data.armor_types, data.armor_types.size() - 1, 4)
	%Name4LineEdit.grab_focus()
	need_fix_data = true


func _on_remove_item_4_button_pressed() -> void:
	var index = %ArmorList.get_selected_items()[0]
	if index > 0:
		data.armor_types.remove_at(index)
		data.icons.armor_icons.remove_at(index)
		index = min(index, data.armor_types.size() - 1)
		fill_list(%ArmorList, data.armor_types, index, 4)
		need_fix_data = true


func _on_item_list_item_selected(index: int) -> void:
	%Name5LineEdit.text = data.item_types[index]
	%RemoveItem5Button.set_disabled(index == 0)
	var current_icon = data.icons.item_icons[index]
	%IconPicker5.set_disabled(false)
	%IconPicker5.set_icon(current_icon.path, current_icon.region)


func _on_name_5_line_edit_text_changed(new_text: String) -> void:
	var index = %ItemList.get_selected_items()[0]
	data.item_types[index] = new_text
	var id = str(index+1).pad_zeros(str(data.item_types.size()).length())
	var item_name = id + ": " + new_text
	%ItemList.set_item_text(index, item_name)


func _on_add_item_5_button_pressed() -> void:
	data.item_types.append("")
	data.icons.item_icons.append(RPGIcon.new())
	fill_list(%ItemList, data.item_types, data.item_types.size() - 1, 5)
	%Name5LineEdit.grab_focus()
	need_fix_data = true


func _on_remove_item_5_button_pressed() -> void:
	var index = %ItemList.get_selected_items()[0]
	if index > 0:
		data.item_types.remove_at(index)
		data.icons.item_icons.remove_at(index)
		index = min(index, data.item_types.size() - 1)
		fill_list(%ItemList, data.item_types, index, 5)
		need_fix_data = true


func _on_equipment_list_item_selected(index: int) -> void:
	%Name6LineEdit.text = data.equipment_types[index]
	%RemoveItem6Button.set_disabled(index == 0)
	var current_icon = data.icons.equipment_icons[index]
	%IconPicker6.set_disabled(false)
	%IconPicker6.set_icon(current_icon.path, current_icon.region)


func _on_name_6_line_edit_text_changed(new_text: String) -> void:
	var index = %EquipmentList.get_selected_items()[0]
	data.equipment_types[index] = new_text
	var id = str(index+1).pad_zeros(str(data.equipment_types.size()).length())
	var item_name = id + ": " + new_text
	%EquipmentList.set_item_text(index, item_name)


func _on_add_item_6_button_pressed() -> void:
	data.equipment_types.append("")
	data.icons.equipment_icons.append(RPGIcon.new())
	fill_list(%EquipmentList, data.equipment_types, data.equipment_types.size() - 1, 6)
	%Name6LineEdit.grab_focus()
	need_fix_data = true


func _on_remove_item_6_button_pressed() -> void:
	var index = %EquipmentList.get_selected_items()[0]
	if index > 0:
		data.equipment_types.remove_at(index)
		data.icons.equipment_icons.remove_at(index)
		index = min(index, data.equipment_types.size() - 1)
		fill_list(%EquipmentList, data.equipment_types, index, 6)
		need_fix_data = true


func _on_visibility_changed() -> void:
	if !visible and need_fix_data:
		fix_data()
	elif visible:
		need_fix_data = false


func fix_data() -> void:
	if database:
		for actor in database.actors:
			if not actor: continue
			if actor.equipment.size() != database.types.equipment_types.size():
				actor.equipment.resize(database.types.equipment_types.size())
				actor.equipment_level.resize(database.types.equipment_types.size())
		
		for weapon in database.weapons:
			if not weapon: continue
			weapon.user_parameters.resize(data.user_parameters.size())
			for level in weapon.upgrades.levels:
				level.user_parameters.resize(data.user_parameters.size())
		
		for armor in database.armors:
			if not armor: continue
			armor.user_parameters.resize(data.user_parameters.size())
			for level in armor.upgrades.levels:
				level.user_parameters.resize(data.user_parameters.size())


func _on_weapon_rarity_list_item_selected(index: int) -> void:
	%Name3bLineEdit.text = data.weapon_rarity_types[index]
	%WeaponRarityColorButton.set_pick_color(data.weapon_rarity_color_types[index])
	%RemoveItem3bButton.set_disabled(index == 0)


func _on_name_3b_line_edit_text_changed(new_text: String) -> void:
	var index = %WeaponRarityList.get_selected_items()[0]
	data.weapon_rarity_types[index] = new_text
	var id = str(index+1).pad_zeros(str(data.weapon_rarity_types.size()).length())
	var item_name = id + ": " + new_text
	%WeaponRarityList.set_item_text(index, item_name)


func _on_add_item_3b_button_pressed() -> void:
	data.weapon_rarity_types.append("")
	data.weapon_rarity_color_types.resize(data.weapon_rarity_types.size())
	fill_list(%WeaponRarityList, data.weapon_rarity_types, data.weapon_rarity_types.size() - 1, "3b")
	%WeaponRarityList.grab_focus()
	need_fix_data = true


func _on_remove_item_3b_button_pressed() -> void:
	var index = %WeaponRarityList.get_selected_items()[0]
	if index > 0:
		data.weapon_rarity_types.remove_at(index)
		data.weapon_rarity_color_types.remove_at(index)
		index = min(index, data.weapon_rarity_types.size() - 1)
		fill_list(%WeaponRarityList, data.weapon_rarity_types, index, "3b")
		need_fix_data = true


func _on_armor_rarity_list_item_selected(index: int) -> void:
	%Name4bLineEdit.text = data.armor_rarity_types[index]
	%ArmorRarityColorButton.set_pick_color(data.armor_rarity_color_types[index])
	%RemoveItem4bButton.set_disabled(index == 0)


func _on_name_4b_line_edit_text_changed(new_text: String) -> void:
	var index = %ArmorRarityList.get_selected_items()[0]
	data.armor_rarity_types[index] = new_text
	var id = str(index+1).pad_zeros(str(data.armor_rarity_types.size()).length())
	var item_name = id + ": " + new_text
	%ArmorRarityList.set_item_text(index, item_name)


func _on_add_item_4b_button_pressed() -> void:
	data.armor_rarity_types.append("")
	data.armor_rarity_color_types.resize(data.armor_rarity_types.size())
	fill_list(%ArmorRarityList, data.armor_rarity_types, data.armor_rarity_types.size() - 1, "4b")
	%ArmorRarityList.grab_focus()
	need_fix_data = true


func _on_remove_item_4b_button_pressed() -> void:
	var index = %ArmorRarityList.get_selected_items()[0]
	if index > 0:
		data.armor_rarity_types.remove_at(index)
		data.armor_rarity_color_types.remove_at(index)
		index = min(index, data.armor_rarity_types.size() - 1)
		fill_list(%ArmorRarityList, data.armor_rarity_types, index, "4b")
		need_fix_data = true


func _on_item_rarity_list_item_selected(index: int) -> void:
	%Name5bLineEdit.text = data.item_rarity_types[index]
	%ItemRarityColorButton.set_pick_color(data.item_rarity_color_types[index])
	%RemoveItem5bButton.set_disabled(index == 0)


func _on_name_5b_line_edit_text_changed(new_text: String) -> void:
	var index = %ItemRarityList.get_selected_items()[0]
	data.item_rarity_types[index] = new_text
	var id = str(index+1).pad_zeros(str(data.item_rarity_types.size()).length())
	var item_name = id + ": " + new_text
	%ItemRarityList.set_item_text(index, item_name)


func _on_add_item_5b_button_pressed() -> void:
	data.item_rarity_types.append("")
	data.item_rarity_color_types.resize(data.item_rarity_types.size())
	fill_list(%ItemRarityList, data.item_rarity_types, data.item_rarity_types.size() - 1, "5b")
	%ItemRarityList.grab_focus()
	need_fix_data = true


func _on_remove_item_5b_button_pressed() -> void:
	var index = %ItemRarityList.get_selected_items()[0]
	if index > 0:
		data.item_rarity_types.remove_at(index)
		data.item_rarity_color_types.remove_at(index)
		index = min(index, data.item_rarity_types.size() - 1)
		fill_list(%ItemRarityList, data.item_rarity_types, index, "5b")
		need_fix_data = true


func _on_weapon_rarity_color_button_color_changed(color: Color) -> void:
	var index = %WeaponRarityList.get_selected_items()[0]
	data.weapon_rarity_color_types[index] = color


func _on_armor_rarity_color_button_color_changed(color: Color) -> void:
	var index = %ArmorRarityList.get_selected_items()[0]
	data.armor_rarity_color_types[index] = color


func _on_item_rarity_color_button_color_changed(color: Color) -> void:
	var index = %ItemRarityList.get_selected_items()[0]
	data.item_rarity_color_types[index] = color


func _on_add_item_6b_button_pressed() -> void:
	%Name6bLineEdit.text = ""
	data.user_parameters.append(RPGUserParameter.new())
	data.icons.user_parameters_icons.append(RPGIcon.new())
	fill_list(%UserParametersList, data.user_parameters, data.user_parameters.size() - 1, "6b")
	%Name6bLineEdit.grab_focus()
	need_fix_data = true


func _on_remove_item_6b_button_pressed() -> void:
	var index = %UserParametersList.get_selected_items()[0]
	data.user_parameters.remove_at(index)
	data.icons.user_parameters_icons.remove_at(index)
	index = min(index, data.user_parameters.size() - 1)
	fill_list(%UserParametersList, data.user_parameters, index, "6b")
	need_fix_data = true


func _on_user_parameters_list_item_selected(index: int) -> void:
	%Name6bLineEdit.text = data.user_parameters[index].name
	%ParameterValue.value = data.user_parameters[index].default_value
	%ParameterValue.set_disabled(false)
	%IconPicker8.set_disabled(false)
	var current_icon = data.icons.user_parameters_icons[index]
	%IconPicker8.set_icon(current_icon.path, current_icon.region)


func _on_name_6b_line_edit_text_changed(new_text: String) -> void:
	var index = %UserParametersList.get_selected_items()[0]
	data.user_parameters[index].name = new_text
	var id = str(index+1).pad_zeros(str(data.user_parameters.size()).length())
	var item_name = id + ": " + new_text
	%UserParametersList.set_item_text(index, item_name)


func _on_parameter_value_value_changed(value: float) -> void:
	var index = %UserParametersList.get_selected_items()[0]
	data.user_parameters[index].default_value = value


func _on_parameter_value_text_changed(text: String) -> void:
	var index = %UserParametersList.get_selected_items()[0]
	data.user_parameters[index].default_value = float(text)


func _on_icon_picker_clicked(id: int) -> void:
	var path = "res://addons/CustomControls/Dialogs/select_icon_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	match id:
		1:
			var itemlist_index = %ElementList.get_selected_items()[0]
			dialog.set_data(data.icons.element_icons[itemlist_index])
		2:
			var itemlist_index = %SkillList.get_selected_items()[0]
			dialog.set_data(data.icons.skill_icons[itemlist_index])
		3:
			var itemlist_index = %WeaponList.get_selected_items()[0]
			dialog.set_data(data.icons.weapon_icons[itemlist_index])
		4:
			var itemlist_index = %ArmorList.get_selected_items()[0]
			dialog.set_data(data.icons.armor_icons[itemlist_index])
		5:
			var itemlist_index = %ItemList.get_selected_items()[0]
			dialog.set_data(data.icons.item_icons[itemlist_index])
		6:
			var itemlist_index = %EquipmentList.get_selected_items()[0]
			dialog.set_data(data.icons.equipment_icons[itemlist_index])
		8:
			var itemlist_index = %UserParametersList.get_selected_items()[0]
			dialog.set_data(data.icons.user_parameters_icons[itemlist_index])
		10:
			var itemlist_index = %MainParametersList.get_selected_items()[0]
			dialog.set_data(data.icons.main_parameters_icons[itemlist_index])
	
	dialog.icon_changed.connect(update_icon.bind(id))


func update_icon(id: int) -> void:
	var icon: RPGIcon
	match id:
		1:
			var itemlist_index = %ElementList.get_selected_items()[0]
			icon = data.icons.element_icons[itemlist_index]
		2:
			var itemlist_index = %SkillList.get_selected_items()[0]
			icon = data.icons.skill_icons[itemlist_index]
		3:
			var itemlist_index = %WeaponList.get_selected_items()[0]
			icon = data.icons.weapon_icons[itemlist_index]
		4:
			var itemlist_index = %ArmorList.get_selected_items()[0]
			icon = data.icons.armor_icons[itemlist_index]
		5:
			var itemlist_index = %ItemList.get_selected_items()[0]
			icon = data.icons.item_icons[itemlist_index]
		6:
			var itemlist_index = %EquipmentList.get_selected_items()[0]
			icon = data.icons.equipment_icons[itemlist_index]
		8:
			var itemlist_index = %UserParametersList.get_selected_items()[0]
			icon = data.icons.user_parameters_icons[itemlist_index]
		10:
			var itemlist_index = %MainParametersList.get_selected_items()[0]
			icon = data.icons.main_parameters_icons[itemlist_index]
			
	var node_path = "%%IconPicker%s" % id
	get_node(node_path).set_icon(icon.path, icon.region)


func _on_icon_picker_remove_requested(id: int) -> void:
	match id:
		1:
			var itemlist_index = %ElementList.get_selected_items()[0]
			data.icons.element_icons[itemlist_index].clear()
		2:
			var itemlist_index = %SkillList.get_selected_items()[0]
			data.icons.skill_icons[itemlist_index].clear()
		3:
			var itemlist_index = %WeaponList.get_selected_items()[0]
			data.icons.weapon_icons[itemlist_index].clear()
		4:
			var itemlist_index = %ArmorList.get_selected_items()[0]
			data.icons.armor_icons[itemlist_index].clear()
		5:
			var itemlist_index = %ItemList.get_selected_items()[0]
			data.icons.item_icons[itemlist_index].clear()
		6:
			var itemlist_index = %EquipmentList.get_selected_items()[0]
			data.icons.equipment_icons[itemlist_index].clear()
		8:
			var itemlist_index = %UserParametersList.get_selected_items()[0]
			data.icons.user_parameters_icons[itemlist_index].clear()
		10:
			var itemlist_index = %MainParametersList.get_selected_items()[0]
			data.icons.main_parameters_icons[itemlist_index].clear()
	
	var node_path = "%%IconPicker%s" % id
	get_node(node_path).set_icon("")


func _on_icon_paste_requested(icon: String, region: Rect2, index: int) -> void:
	var icon_data: RPGIcon
	match index:
		1:
			var itemlist_index = %ElementList.get_selected_items()[0]
			icon_data = data.icons.element_icons[itemlist_index]
		2:
			var itemlist_index = %SkillList.get_selected_items()[0]
			icon_data = data.icons.skill_icons[itemlist_index]
		3:
			var itemlist_index = %WeaponList.get_selected_items()[0]
			icon_data = data.icons.weapon_icons[itemlist_index]
		4:
			var itemlist_index = %ArmorList.get_selected_items()[0]
			icon_data = data.icons.armor_icons[itemlist_index]
		5:
			var itemlist_index = %ItemList.get_selected_items()[0]
			icon_data = data.icons.item_icons[itemlist_index]
		6:
			var itemlist_index = %EquipmentList.get_selected_items()[0]
			icon_data = data.icons.equipment_icons[itemlist_index]
		8:
			var itemlist_index = %UserParametersList.get_selected_items()[0]
			icon_data = data.icons.user_parameters_icons[itemlist_index]
		10:
			var itemlist_index = %MainParametersList.get_selected_items()[0]
			icon_data = data.icons.main_parameters_icons[itemlist_index]
	
	if icon_data:
		icon_data.path = icon
		icon_data.region = region
		update_icon(index)


func _on_config_data_tabs_tab_changed(index: int) -> void:
	var node_path = "%%Tab%s" % (index + 1)
	var node = get_node_or_null(node_path)
	if node:
		for child in node.get_parent().get_children():
			child.visible = false
		node.visible = true


func _on_equipment_list_item_activated(index: int) -> void:
	%Name6LineEdit.grab_focus()


func _on_item_list_item_activated(index: int) -> void:
	%Name5LineEdit.grab_focus()


func _on_weapon_list_item_activated(index: int) -> void:
	%Name3LineEdit.grab_focus()


func _on_armor_list_item_activated(index: int) -> void:
	%Name4LineEdit.grab_focus()


func _on_skill_list_item_activated(index: int) -> void:
	%Name2LineEdit.grab_focus()


func _on_element_list_item_activated(index: int) -> void:
	%Name1LineEdit.grab_focus()


func _on_item_rarity_list_item_activated(index: int) -> void:
	%Name5bLineEdit.grab_focus()


func _on_weapon_rarity_list_item_activated(index: int) -> void:
	%Name3bLineEdit.grab_focus()


func _on_armor_rarity_list_item_activated(index: int) -> void:
	%Name4bLineEdit.grab_focus()


func _on_user_parameters_list_item_activated(index: int) -> void:
	%ParameterValue.gain_focus()


func _on_element_attack_color_color_changed(color: Color) -> void:
	var index = %ElementList.get_selected_items()[0]
	data.element_colors[index] = color


func _on_colorize_element_numbers_toggled(toggled_on: bool) -> void:
	var index = %ElementList.get_selected_items()[0]
	data.colorize_element_numbers[index] = 1 if toggled_on else 0


func _on_user_stats_list_item_activated(index: int) -> void:
	%Name7bLineEdit.grab_focus()


func _on_user_stats_list_item_selected(index: int) -> void:
	%Name7bLineEdit.text = data.user_stats[index]


func _on_name_7b_line_edit_text_changed(new_text: String) -> void:
	var index = %UserStatsList.get_selected_items()[0]
	data.user_stats[index] = new_text
	var id = str(index+1).pad_zeros(str(data.user_stats.size()).length())
	var item_name = id + ": " + new_text
	%UserStatsList.set_item_text(index, item_name)


func _on_add_item_7b_button_pressed() -> void:
	%Name7bLineEdit.text = ""
	data.user_stats.resize(data.user_stats.size() + 1)
	fill_list(%UserStatsList, data.user_stats, data.user_stats.size() - 1, "7b")
	%Name7bLineEdit.grab_focus()
	need_fix_data = true


func _on_remove_item_7b_button_pressed() -> void:
	var index = %UserStatsList.get_selected_items()[0]
	data.user_stats.remove_at(index)
	index = min(index, data.user_stats.size() - 1)
	fill_list(%UserStatsList, data.user_stats, index, "7b")
	need_fix_data = true


func _on_name_10_line_edit_text_changed(new_text: String) -> void:
	var index = %MainParametersList.get_selected_items()[0]
	data.main_parameters[index] = new_text
	var id = str(index+1).pad_zeros(str(data.main_parameters.size()).length())
	var item_name = id + ": " + new_text
	%MainParametersList.set_item_text(index, item_name)


func _on_main_parameters_list_item_activated(index: int) -> void:
	%Name10LineEdit.grab_focus()


func _on_main_parameters_list_item_selected(index: int) -> void:
	%Name10LineEdit.text = data.main_parameters[index]
	%IconPicker10.set_disabled(false)
	var current_icon = data.icons.main_parameters_icons[index]
	%IconPicker10.set_icon(current_icon.path, current_icon.region)
