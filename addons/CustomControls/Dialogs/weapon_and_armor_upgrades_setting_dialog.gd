@tool
extends Window

var database: RPGDATA
var data: RPGGearUpgrade
var real_data: RPGGearUpgrade

var current_level: int

var busy: bool = false


func _ready() -> void:
	close_requested.connect(queue_free)
	%CurrentLevel.get_line_edit().focus_entered.connect(apply_upgrades)
	%MaterialList.set_lock_items(PackedInt32Array([0, 1]))


func set_data(_database: RPGDATA, _data: RPGGearUpgrade) -> void:
	database = _database
	data = _data.clone(true)
	real_data = _data
	set_level()


func get_data() -> RPGGearUpgradeLevel:
	if not data: return
	var current_level_data: RPGGearUpgradeLevel = data.levels[current_level]
	return current_level_data


func set_level() -> void:
	busy = true
	%CurrentLevel.min_value = 2
	%CurrentLevel.max_value = data.max_levels
	%CurrentLevel.value = 2
	%MaxLevelsLabel.text = "/ %s" % data.max_levels
	%AutoLevel.set_pressed(data.auto_level)
	busy = false
	current_level = 1
	fill_current_data(-1)


func fill_current_data(material_list_selected_index: int = 0) -> void:
	fill_material_list(material_list_selected_index)
	
	var current_level_data: RPGGearUpgradeLevel = get_data()
	%MaxHPSpinBox.value = current_level_data.parameters_multiplier[RPGActor.BaseParamType.HP]
	%AttackSpinBox.value = current_level_data.parameters_multiplier[RPGActor.BaseParamType.ATK]
	%MagicAttackSpinBox.value = current_level_data.parameters_multiplier[RPGActor.BaseParamType.MATK]
	%AgilitySpinBox.value = current_level_data.parameters_multiplier[RPGActor.BaseParamType.AGI]
	%MaxMPSpinBox.value = current_level_data.parameters_multiplier[RPGActor.BaseParamType.MP]
	%DefenseSpinBox.value = current_level_data.parameters_multiplier[RPGActor.BaseParamType.DEF]
	%MagicDefenseSpinBox.value = current_level_data.parameters_multiplier[RPGActor.BaseParamType.MDEF]
	%LuckSpinBox.value = current_level_data.parameters_multiplier[RPGActor.BaseParamType.LUK]
	%CostChanged.value = current_level_data.price_increment
	
	var user_parameter_disabled = (database.types.user_parameters.size() == 0)
	%UserParameters.set_disabled(user_parameter_disabled)
	%CopyUserParameters.set_disabled(user_parameter_disabled)
	%PasteUserParameters.set_disabled(user_parameter_disabled or !StaticEditorVars.CLIPBOARD.get("items_user_parameters", false))
	if user_parameter_disabled:
		%UserParameters.clear()
	else:
		fill_user_parameters()


func fill_material_list(selected_index: int = -1) -> void:
	var node = %MaterialList
	node.clear()
	
	var current_level_data: RPGGearUpgradeLevel = get_data()
	node.add_column(["Experience", str(current_level_data.required_experience)])
	node.add_column(["Gold", str(current_level_data.required_gold)])
	
	if !database: return
	
	for mat: RPGGearUpgradeComponent in current_level_data.required_materials:
		var current_data
		var prefix
		if mat.component.data_id == 0: # items
			current_data = database.items
			prefix = "<Item> "
		elif mat.component.data_id == 1: # weapons
			current_data = database.weapons
			prefix = "<Weapon> "
		elif mat.component.data_id == 2: # armors
			current_data = database.armors
			prefix = "<Armor> "
		
		if current_data:
			if current_data.size() > mat.component.item_id:
				var item_name = str(mat.component.item_id).pad_zeros(str(current_data.size()).length()) + ": " + current_data[mat.component.item_id].name
				var quantity = str(mat.quantity)
				node.add_column([prefix + item_name, quantity])
			else:
				var quantity = str(mat.quantity)
				node.add_column([prefix + "⚠ Invalid Data", quantity])
	
	if selected_index >= 0:
		await node.columns_setted
		node.select(selected_index)


func fill_user_parameters(selected_index: int = 0) -> void:
	var node = %UserParameters
	node.clear()
	
	var user_parameters = get_data().user_parameters
	var user_parameter_data = RPGSYSTEM.database.types.user_parameters
	if user_parameters.size() != user_parameter_data.size():
		user_parameters.resize(user_parameter_data.size())

	for i in user_parameter_data.size():
		var column = []
		column.append(user_parameter_data[i].name)
		column.append("%.2f" % user_parameters[i])

		node.add_column(column)
	
	await node.columns_setted
	
	if selected_index >= 0 and node.get_item_count() > selected_index:
		node.select(selected_index)


func apply_upgrades() -> void:
	var nodes = [%MaxHPSpinBox, %AttackSpinBox, %MagicAttackSpinBox, %AgilitySpinBox, %MaxMPSpinBox, %DefenseSpinBox, %MagicDefenseSpinBox, %LuckSpinBox]
	for i in nodes.size():
		nodes[i].apply()
		if nodes[i].get_line_edit().has_focus():
			nodes[i].release_focus()
	
	%CostChanged.apply()


func _on_current_level_value_changed(value: float) -> void:
	if busy: return

	apply_upgrades()
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	current_level = value - 1
	fill_current_data()


func _on_ok_button_pressed() -> void:
	apply_upgrades()
	real_data.max_levels = data.max_levels
	real_data.levels = data.levels
	real_data.auto_level = data.auto_level
	queue_free()


func _on_cancel_button_pressed() -> void:
	queue_free()



func _on_max_hp_spin_box_value_changed(value: float) -> void:
	get_data().parameters_multiplier[RPGActor.BaseParamType.HP] = value


func _on_attack_spin_box_value_changed(value: float) -> void:
	get_data().parameters_multiplier[RPGActor.BaseParamType.ATK] = value


func _on_magic_attack_spin_box_value_changed(value: float) -> void:
	get_data().parameters_multiplier[RPGActor.BaseParamType.MATK] = value


func _on_agility_spin_box_value_changed(value: float) -> void:
	get_data().parameters_multiplier[RPGActor.BaseParamType.AGI] = value


func _on_max_mp_spin_box_value_changed(value: float) -> void:
	get_data().parameters_multiplier[RPGActor.BaseParamType.MP] = value


func _on_defense_spin_box_value_changed(value: float) -> void:
	get_data().parameters_multiplier[RPGActor.BaseParamType.DEF] = value


func _on_magic_defense_spin_box_value_changed(value: float) -> void:
	get_data().parameters_multiplier[RPGActor.BaseParamType.MDEF] = value


func _on_luck_spin_box_value_changed(value: float) -> void:
	get_data().parameters_multiplier[RPGActor.BaseParamType.LUK] = value


func _on_auto_level_toggled(toggled_on: bool) -> void:
	data.auto_level = toggled_on


func _on_material_list_item_activated(index: int) -> void:
	if index == 0: # Experience
		show_select_number_dialog("Experience", 0)
	elif index == 1: # Gold
		show_select_number_dialog("Gold", 1)
	else: # Items, weapons or armors
		var current_data = get_data().required_materials
		if current_data.size() > index - 2:
			show_select_required_item_dialog(current_data[index-2], index)
		else: # new_material
			show_select_required_item_dialog()


func show_select_number_dialog(_title: String, index: int) -> void:
	var path = "res://addons/CustomControls/Dialogs/select_number_value_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	dialog.title = _title + TranslationManager.tr(" quantity")
	var current_data = get_data()
	if index == 0:
		dialog.set_min_max_values(1, 0)
		dialog.set_value(current_data.required_experience)
	elif index == 1:
		dialog.set_min_max_values(0, 0)
		dialog.set_value(current_data.required_gold)
	dialog.selected_value.connect(_on_select_number_dialog_selected_value.bind(index))


func _on_select_number_dialog_selected_value(value: int, index: int) -> void:
	var current_data = get_data()
	if index == 0:
		current_data.required_experience = value
	elif index == 1:
		current_data.required_gold = value
	
	fill_material_list(index)


func show_select_required_item_dialog(item: RPGGearUpgradeComponent = null, index: int = -1) -> void:
	var path = "res://addons/CustomControls/Dialogs/select_required_item_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	dialog.database = database
	if item:
		dialog.set_data(item)
		dialog.component_updated.connect(_on_component_updated.bind(index))
	else:
		dialog.create_new_data()
		dialog.component_created.connect(_on_component_created)


func _on_component_created(component: RPGGearUpgradeComponent) -> void:
	var current_data = get_data()
	
	var material_found: bool = false
	var material_index: int = -1
	for i in current_data.required_materials.size():
		var mat: RPGGearUpgradeComponent = current_data.required_materials[i]
		if component.component.data_id == mat.component.data_id and component.component.item_id == mat.component.item_id:
			mat.quantity = component.quantity
			material_found = true
			material_index = i
			break

	if !material_found:
		current_data.required_materials.append(component)
		fill_material_list(current_data.required_materials.size() + 1)
	else:
		fill_material_list(material_index + 2)


func _on_component_updated(_component: RPGGearUpgradeComponent, index: int) -> void:
	var current_data = get_data()
	var duplicate_found: bool = false
	for i in current_data.required_materials.size():
		var mat1: RPGGearUpgradeComponent = current_data.required_materials[i]
		for j in range(current_data.required_materials.size() - 1, i, -1):
			var mat2: RPGGearUpgradeComponent = current_data.required_materials[j]
			if mat1.component.data_id == mat2.component.data_id and mat1.component.item_id == mat2.component.item_id:
				mat1.quantity = mat2.quantity
				current_data.required_materials.erase(mat2)
				index = i + 2
				duplicate_found = true
				break
		if duplicate_found: break

	fill_material_list(index)


func _on_material_list_delete_pressed(indexes: PackedInt32Array) -> void:
	var current_data = get_data()
	var remove_components: Array[RPGGearUpgradeComponent] = []
	for index in indexes:
		if index >= 2 and current_data.required_materials.size() > index - 2:
			remove_components.append(current_data.required_materials[index - 2])
	for obj in remove_components:
		current_data.required_materials.erase(obj)
	fill_material_list(indexes[0])
	
#endregion


func _on_material_list_copy_requested(indexes: PackedInt32Array) -> void:
	var current_data = get_data()
	var copy_components: Array[RPGGearUpgradeComponent]
	for index in indexes:
		var real_index = index - 2
		if real_index > current_data.required_materials.size() or real_index < 0:
			continue
		copy_components.append(current_data.required_materials[real_index].clone(true))
		
	StaticEditorVars.CLIPBOARD["components"] = copy_components


func _on_material_list_cut_requested(indexes: PackedInt32Array) -> void:
	var current_data = get_data()
	var copy_components: Array[RPGGearUpgradeComponent]
	var remove_components: Array[RPGGearUpgradeComponent]
	for index in indexes:
		if index - 2 > current_data.required_materials.size():
			continue
		if current_data.required_materials.size() > index-2 and index-2 >= 0:
			copy_components.append(current_data.required_materials[index-2].clone(true))
			remove_components.append(current_data.required_materials[index-2])
	for item in remove_components:
		current_data.required_materials.erase(item)

	StaticEditorVars.CLIPBOARD["components"] = copy_components
	
	var item_selected = max(-1, indexes[0])
	fill_material_list(item_selected)


func _on_material_list_paste_requested(index: int) -> void:
	var current_data = get_data()
	
	if index < 1: index = 1
	
	if StaticEditorVars.CLIPBOARD.has("components"):
		for i in StaticEditorVars.CLIPBOARD["components"].size():
			var mat1: RPGGearUpgradeComponent = StaticEditorVars.CLIPBOARD["components"][i].clone()
			var material_setted: bool = false
			for j in current_data.required_materials.size():
				var mat2: RPGGearUpgradeComponent = current_data.required_materials[j]
				if mat1.component.data_id == mat2.component.data_id and mat1.component.item_id == mat2.component.item_id:
					mat2.quantity = mat1.quantity
					material_setted = true
					break
					
			if material_setted: continue
			
			var real_index = index + i - 1
			if real_index < current_data.required_materials.size():
				current_data.required_materials.insert(real_index, mat1)
			else:
				current_data.required_materials.append(mat1)
	
	fill_material_list(min(index + 1, current_data.required_materials.size() - 1))
	
	var list = %MaterialList
	await list.columns_setted
	await get_tree().process_frame
	await get_tree().process_frame
	list.deselect_all()
	if StaticEditorVars.CLIPBOARD.has("components"):
		for i in StaticEditorVars.CLIPBOARD["components"].size():
			for j in current_data.required_materials.size():
				var mat1: RPGGearUpgradeComponent = StaticEditorVars.CLIPBOARD["components"][i]
				var mat2: RPGGearUpgradeComponent = current_data.required_materials[j]
				if mat1.component.data_id == mat2.component.data_id and mat1.component.item_id == mat2.component.item_id:
					list.select(j+2, false)
					break


func _on_cost_changed_value_changed(value: float) -> void:
	if not get_data(): return
	get_data().price_increment = value


func _on_user_parameters_item_activated(index: int) -> void:
	if database.types.user_parameters.size() > index and index >= 0:
		var path = "res://addons/CustomControls/Dialogs/select_number_value_dialog.tscn"
		var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
		var user_param_name = database.types.user_parameters[index].name
		var user_param_value = get_data().user_parameters[index]
		dialog.set_min_max_values(0, 0, 0.01)
		dialog.set_title_and_contents(tr("Set Parameter value"), user_param_name)
		dialog.set_value(user_param_value)
		dialog.selected_value.connect(
			func(value: float):
				get_data().user_parameters[index] = value
				fill_user_parameters(index)
		)


func _on_copy_user_parameters_pressed() -> void:
	StaticEditorVars.CLIPBOARD.items_user_parameters = get_data().user_parameters.duplicate()
	%PasteUserParameters.set_disabled(false)


func _on_paste_user_parameters_pressed() -> void:
	if "items_user_parameters" in StaticEditorVars.CLIPBOARD:
		for i in get_data().user_parameters.size():
			if StaticEditorVars.CLIPBOARD.items_user_parameters.size() > i:
				get_data().user_parameters[i] = StaticEditorVars.CLIPBOARD.items_user_parameters[i]
		fill_user_parameters()
