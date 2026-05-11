@tool
extends PanelContainer

#region Variables
## Deselect when lost focus
@export var deselect_when_lost_focus: bool = false :
	set(value):
		deselect_when_lost_focus = value
		var node = get_node_or_null("%TraitsList")
		if node:
			node.deselect_when_lost_focus = value

## ItemList tooltip
@export_multiline var itemlist_tooltip: String = "" :
	set(value):
		itemlist_tooltip = value
		get_child(0).itemlist_tooltip = value

var database: RPGDATA
var traits: Array[RPGTrait]
var traits_need_refresh_timer: float

signal traits_update()
#endregion



#region Initialization
## Loads the dialog resource on ready
func _ready() -> void:
	ResourceLoader.load_threaded_request.call_deferred("res://addons/CustomControls/Dialogs/select_trait_dialog.tscn")



## Sets the data for the panel
func set_data(_database, _traits) -> void:
	database = _database
	traits = _traits
	
	fill_traits(-1)
#endregion



#region LogicAndProcessing
## Triggers a delayed refresh for the traits list
func set_need_refresh() -> void:
	traits_need_refresh_timer = 0.25
	set_process(true)



## Process loop to handle the delayed refresh
func _process(delta: float) -> void:
	if traits_need_refresh_timer > 0:
		traits_need_refresh_timer -= delta
		if traits_need_refresh_timer <= 0:
			traits_need_refresh_timer = 0
			refresh_traits()
			set_process(false)
	else:
		set_process(false)



## Resolves parameter names from the global actor list
func _get_parameter_name(id: int) -> String:
	var items = RPGActor.get_parameter_list(false)
	var parameter: String = ""
	
	if items.size() > id:
		parameter = items[id]
	
	return parameter



## Parses a trait into a visual column representation
func get_column(item: RPGTrait) -> Array:
	var column = []
	var left = {
		1: "Element Rate (damage recevied)",
		2: "Debuff Rate",
		3: "State Rate",
		4: "State Resist",
		5: "Parameter",
		6: "Ex-Parameter",
		7: "Sp-Parameter",
		8: "Attack Element",
		9: "Attack State",
		10: "Attack Speed",
		11: "Attack Times +",
		12: "Attack Skill",
		13: "Add Skill Type",
		14: "Seal Skill Type",
		15: "Add Skill",
		16: "Seal Skill",
		17: "Equip Weapon",
		18: "Equip Armor",
		19: "Lock Equip",
		20: "Seal Equip",
		21: "Slot Type",
		22: "Action Times +",
		23: "Special Flag",
		24: "Collapse Effect",
		25: "Party Ability",
		26: "Skill Special Flag",
		27: "Element Rate (damage done)",
		28: "Add Permanent State",
		101: "User Parameter"
	}
	
	column.append(left[item.code])

	if [1, 27].has(item.code):
		var list = database.types.element_types
		if list.size() > item.data_id:
			column.append(list[item.data_id] + " * " + str(item.value) + " %")
		else:
			column.append("⚠ Invalid Data")
	elif [2, 5].has(item.code):
		var param = _get_parameter_name(item.data_id)
		if not param.is_empty():
			column.append(param + " * " + str(item.value) + "%")
		else:
			column.append("⚠ Invalid Data")
	elif item.code == 101:
		var list = []
		for i in database.types.user_parameters.size():
			list.append(database.types.user_parameters[i].name)
		if list.size() > item.data_id:
			column.append(list[item.data_id] + " * " + str(item.value) + "%")
		else:
			column.append("⚠ Invalid Data * " + str(item.value) + "%")
	elif item.code == 3:
		var state = RPGSYSTEM.get_data("states", item.data_id)
		if state:
			column.append(state.name + " * " + str(item.value) + "%")
		else:
			column.append("⚠ Invalid Data")
	elif [4, 28].has(item.code):
		var state = RPGSYSTEM.get_data("states", item.data_id)
		if state:
			column.append(state.name)
		else:
			column.append("⚠ Invalid Data")
	elif item.code == 6:
		var list = ["Hit Rate", "Evasion Rate", "Critical Rate", "Critical Evasion", "Magic Evasion", "Magic Reflection", "Counter Attack", "HP Regeneration", "MP Regeneration", "TP Regeneration"]
		if list.size() > item.data_id:
			column.append(list[item.data_id] + " * " + str(item.value) + "%")
		else:
			column.append("⚠ Invalid Data")
	elif item.code == 7:
		var list = ["Target Rate", "Guard Effect", "Recovery Effect", "Pharmacology", "MP Cost Rate", "TP Charge Rate", "Physical Damage", "Magical Damage", "Floor Damage", "Experience", "Gold"]
		if list.size() > item.data_id:
			column.append(list[item.data_id] + " * " + str(item.value) + "%")
		else:
			column.append("⚠ Invalid Data")
	elif item.code == 8:
		var list = database.types.element_types
		if list.size() > item.data_id:
			column.append(list[item.data_id])
		else:
			column.append("⚠ Invalid Data")
	elif item.code == 9:
		var state = RPGSYSTEM.get_data("states", item.data_id)
		if state:
			column.append(state.name + " + " + str(item.value) + "%")
		else:
			column.append("⚠ Invalid Data")
	elif [10, 11, 22].has(item.code):
		var str_val = str(item.value)
		if item.code == 22:
			str_val += "%"
		column.append(str_val)
	elif [12, 15, 16].has(item.code):
		var skill = RPGSYSTEM.get_data("skills", item.data_id)
		if skill:
			column.append(skill.name)
		else:
			column.append("⚠ Invalid Data")
	elif [13, 14].has(item.code):
		var list = database.types.skill_types
		if list.size() > item.data_id:
			column.append(list[item.data_id])
		else:
			column.append("⚠ Invalid Data")
	elif item.code == 17:
		var list = database.types.weapon_types
		if item.data_id == 0:
			column.append("All Weapon Types")
		else:
			if list.size() > item.data_id - 1:
				column.append(list[item.data_id - 1])
			else:
				column.append("⚠ Invalid Data")
	elif item.code == 18:
		var list = database.types.armor_types
		if item.data_id == 0:
			column.append("All Armor Types")
		else:
			if list.size() > item.data_id - 1:
				column.append(list[item.data_id - 1])
			else:
				column.append("⚠ Invalid Data")
	elif [19, 20].has(item.code):
		var list = database.types.equipment_types
		if list.size() > item.data_id:
			column.append(list[item.data_id])
		else:
			column.append("⚠ Invalid Data")
	elif item.code == 21:
		var list = ["Normal", "Dual Wield"]
		if list.size() > item.data_id:
			column.append(list[item.data_id])
		else:
			column.append("⚠ Invalid Data")
	elif item.code == 23:
		var list = ["Auto Battle", "Guard", "Substitute", "Preserve TP"]
		if list.size() > item.data_id:
			column.append(list[item.data_id])
		else:
			column.append("⚠ Invalid Data")
	elif item.code == 24:
		var list = ["Normal", "Boss", "Instant", "No Dissapear"]
		if list.size() > item.data_id:
			column.append(list[item.data_id])
		else:
			column.append("⚠ Invalid Data")
	elif item.code == 25:
		var list = ["Encounter Half", "Encounter None", "Cancel Surprise", "Raise Preemptive", "Gold Double", "Drop Item Double"]
		if list.size() > item.data_id:
			column.append(list[item.data_id])
		else:
			column.append("⚠ Invalid Data")
	elif item.code == 26:
		var list = ["MP Cost Down", "Double Cast Chance"]
		var str_val = ""
		if list.size() > item.data_id:
			str_val = list[item.data_id]
		else:
			str_val = "⚠ Invalid Data"
		str_val += " * " + str(item.value) + " %"
		column.append(str_val)

	return column



## Refreshes the visual traits list retaining selection
func refresh_traits() -> void:
	var node = %TraitsList
	var selected_items = node.get_selected_items()
	var scroll = node.get_v_scroll_bar().value
	
	await fill_traits(-1)
	
	node.set_selected_items(selected_items)
	await get_tree().process_frame
	node.get_v_scroll_bar().value = scroll



## Clears the entire traits list
func clear() -> void:
	%TraitsList.clear()



## Fixes trait offsets matching internal engine rules
func _fix_traits() -> void:
	var items = RPGActor.get_parameter_list(false)
	var category_offsets: Array[int] = []

	for i in items.size():
		if items[i] == "":
			category_offsets.append(i + 1)

	var ex_offset: int = category_offsets[1] if category_offsets.size() > 1 else 0
	var sp_offset: int = category_offsets[2] if category_offsets.size() > 2 else 0
	var user_offset: int = category_offsets[3] if category_offsets.size() > 3 else 0

	for item in traits:
		match item.code:
			6:
				item.code = 5
				item.data_id += ex_offset
			7:
				item.code = 5
				item.data_id += sp_offset
			101:
				item.code = 5
				item.data_id += user_offset



## Populates the node UI list with processed trait data
func fill_traits(item_selected: int) -> void:
	var node = %TraitsList
	node.clear()
	_fix_traits()
	
	for item in traits:
		var item_name = get_column(item)
		node.add_column(item_name)
	
	if traits.size() > 0:
		await node.columns_setted
		if node.items.size() + 1 > item_selected and item_selected != -1:
			node.select(item_selected)
		else:
			node.deselect_all()
	else:
		node.deselect_all()
	
	traits_update.emit()
#endregion



#region SignalsAndInteractions
## Triggered when a trait is double clicked to edit
func _on_traits_list_item_activated(index: int) -> void:
	var path = "res://addons/CustomControls/Dialogs/select_trait_dialog.tscn"
	var parent = get_tree().get_nodes_in_group("main_database")[0]
	var dialog
	var main_panel = parent.get_child(0)
	
	if main_panel.cache_dialog.has(path) and is_instance_valid(main_panel.cache_dialog[path]):
		dialog = main_panel.cache_dialog[path]
		RPGDialogFunctions.show_dialog(dialog, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	else:
		dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
		main_panel.cache_dialog[path] = dialog
		dialog.database = database
		dialog.fill_all()
	
	dialog.target_callable = _on_trait_selected
	if traits.size() > index:
		dialog.set_data(traits[index], index)
	else:
		dialog.set_data(null, -1)



## Callback when a trait dialog finishes edition
func _on_trait_selected(current_trait: RPGTrait, target: int) -> void:
	if target == -1:
		traits.append(current_trait)
		fill_traits(traits.size() - 1)
	else:
		traits[target] = current_trait
		fill_traits(target)



## Handle multi selection logic
func _on_traits_list_multi_selected(index: int, selected: bool) -> void:
	pass



## Process keyboard delete input
func _on_traits_list_delete_pressed(indexes: PackedInt32Array) -> void:
	if indexes.is_empty():
		return
		
	var remove_traits: Array[RPGTrait] = []
	for index in indexes:
		if index >= 0 and traits.size() > index:
			remove_traits.append(traits[index])
			
	for obj in remove_traits:
		traits.erase(obj)
		
	fill_traits(indexes[0])



## Handle item copy action to clipboard
func _on_traits_list_copy_requested(indexes: PackedInt32Array) -> void:
	if indexes.is_empty():
		return
		
	var copy_traits: Array[RPGTrait]
	for index in indexes:
		if index > traits.size() - 1:
			continue
		copy_traits.append(traits[index].clone(true))
		
	StaticEditorVars.CLIPBOARD["traits"] = copy_traits



## Handle item cut action to clipboard
func _on_traits_list_cut_requested(indexes: PackedInt32Array) -> void:
	if indexes.is_empty():
		return
		
	var copy_traits: Array[RPGTrait]
	var remove_traits: Array[RPGTrait]
	for index in indexes:
		if index > traits.size() - 1:
			continue
		copy_traits.append(traits[index].clone(true))
		remove_traits.append(traits[index])
		
	for item in remove_traits:
		traits.erase(item)

	StaticEditorVars.CLIPBOARD["traits"] = copy_traits
	
	var item_selected = max(-1, indexes[0])
	fill_traits(item_selected)



## Handle item paste action from clipboard
func _on_traits_list_paste_requested(index: int) -> void:
	if StaticEditorVars.CLIPBOARD.has("traits"):
		for i in StaticEditorVars.CLIPBOARD["traits"].size():
			var real_index = index + i
			var current_trait = StaticEditorVars.CLIPBOARD["traits"][i].clone()
			if real_index < traits.size():
				traits.insert(real_index, current_trait)
			else:
				traits.append(current_trait)
	
	fill_traits(min(index + 1, traits.size() - 1))
	
	var list = %TraitsList
	await list.columns_setted
	await get_tree().process_frame
	await get_tree().process_frame
	
	if StaticEditorVars.CLIPBOARD.has("traits"):
		for i in range(index, index + StaticEditorVars.CLIPBOARD["traits"].size()):
			if i >= traits.size():
				i = index
			list.select(i, false)



## Handle item duplication natively
func _on_traits_list_duplicate_requested(indexes: PackedInt32Array) -> void:
	if indexes.is_empty():
		return
		
	var current_traits: Array[RPGTrait] = []

	for index in indexes:
		if index > traits.size() - 1:
			continue
		current_traits.append(traits[index].clone(true))
	
	var index = indexes[-1] + 1
	
	if current_traits:
		for i in current_traits.size():
			var current_trait: RPGTrait = current_traits[i]
			var real_index = index + i
			if real_index < traits.size():
				traits.insert(real_index, current_trait)
			else:
				traits.append(current_trait)
	
	fill_traits(-1)
	
	var list = %TraitsList
	await list.columns_setted
	await get_tree().process_frame
	await get_tree().process_frame
	
	for i in range(index, index + current_traits.size()):
		if i >= traits.size():
			i = index
		list.select(i, false)



## Updates minimum sizes if rect is changed manually
func _on_traits_list_item_rect_changed() -> void:
	return
#endregion
