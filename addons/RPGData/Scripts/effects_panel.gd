@tool
extends PanelContainer

## Deselect when lost focus
@export var deselect_when_lost_focus: bool = false :
	set(value):
		deselect_when_lost_focus = value
		var node = get_node_or_null("%EffectsList")
		if node:
			node.deselect_when_lost_focus = value

## ItemList tooltip
@export_multiline var itemlist_tooltip: String = "" :
	set(value):
		itemlist_tooltip = value
		get_child(0).itemlist_tooltip = value


var database: RPGDATA
var effects: Array[RPGEffect]

var effects_need_refresh_timer: float


func set_data(_database, _effects) -> void:
	database = _database
	effects = _effects
	
	fill_effects(-1)

#region EFFECTS
func set_need_refresh() -> void:
	effects_need_refresh_timer = 0.25
	set_process(true)


func _process(delta: float) -> void:
	if effects_need_refresh_timer > 0:
		effects_need_refresh_timer -= delta
		if effects_need_refresh_timer <= 0:
			effects_need_refresh_timer = 0
			refresh_effects()
			set_process(false)
	else:
		set_process(false)


func get_column(item: RPGEffect) -> Array:
	var column = []
	
	var left = [
		"Recover HP", "Recover MP", "Gain TP", "Add State",
		"Remove State", "Add Buff", "Add Debuff",
		"Remove Buff", "Remove Debuff", "Special Effect",
		"Grow", "Learn Skill", "Common Event"
	]
	column.append(left[item.code - 1])
	
	if [1, 2].has(item.code):
		var text = "%s %% + %s x Pharmacology" % [item.value1, item.value2]
		column.append(text)
	elif [3].has(item.code):
		var text = "%s" % item.value1
		column.append(text)
	elif [4, 5].has(item.code):
		var list = database.states
		if list.size() > item.data_id:
			column.append(list[item.data_id].name + " " + str(item.value2) + " %")
		else:
			column.append("⚠ Invalid Data")
	elif [6, 7].has(item.code):
		var list = ["Max HP", "Max MP", "Attack", "Defense", "Magical Attack", "Magical Defense", "Agility", "Luck"]
		if list.size() > item.data_id:
			column.append(list[item.data_id] + " x " + str(item.value2) + " turns")
		else:
			column.append("⚠ Invalid Data")
	elif [8, 9].has(item.code):
		var list = ["Max HP", "Max MP", "Attack", "Defense", "Magical Attack", "Magical Defense", "Agility", "Luck"]
		if list.size() > item.data_id:
			column.append(list[item.data_id])
		else:
			column.append("⚠ Invalid Data")
	elif [10].has(item.code):
		var list = ["Escape"]
		if list.size() > item.data_id:
			column.append(list[item.data_id])
		else:
			column.append("⚠ Invalid Data")
	elif [11].has(item.code):
		var list = ["Max HP", "Max MP", "Attack", "Defense", "Magical Attack", "Magical Defense", "Agility", "Luck"]
		if list.size() > item.data_id:
			column.append(list[item.data_id] + " + " + str(item.value2))
		else:
			column.append("⚠ Invalid Data")
	elif [12].has(item.code):
		var list = database.skills
		if list.size() > item.data_id:
			column.append(list[item.data_id].name)
		else:
			column.append("⚠ Invalid Data")
	elif [13].has(item.code):
		var list = database.common_events
		if list.size() > item.data_id:
			column.append(list[item.data_id].name)
		else:
			column.append("⚠ Invalid Data")
	
	return column


func refresh_effects() -> void:
	var node = %EffectsList
	var selected_items = node.get_selected_items()
	var scroll = node.get_v_scroll_bar().value
	
	await fill_effects(-1)
	
	node.set_selected_items(selected_items)
	await get_tree().process_frame
	node.get_v_scroll_bar().value = scroll


func clear() -> void:
	%EffectsList.clear()


func fill_effects(item_selected: int) -> void:
	var node = %EffectsList
	node.clear()
	for item in effects:
		node.add_column(get_column(item))
	
	if effects.size() > 0:
		await node.columns_setted
		if node.items.size() + 1 > item_selected and item_selected != -1:
			node.select(item_selected)
		else:
			node.deselect_all()
	else:
		node.deselect_all()


func _on_effects_list_item_activated(index: int) -> void:
	var path = "res://addons/CustomControls/Dialogs/select_effect_dialog.tscn"
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
	
	dialog.target_callable = _on_effect_selected
	if effects.size() > index:
		dialog.set_data(effects[index], index)
	else:
		dialog.set_data(null, -1)


func _on_effect_selected(current_effect: RPGEffect, target: int) -> void:
	if target == -1:
		effects.append(current_effect)
		fill_effects(effects.size() - 1)
	else:
		effects[target] = current_effect
		fill_effects(target)


func _on_effects_list_multi_selected(index: int, selected: bool) -> void:
	pass


func _on_effects_list_delete_pressed(indexes: PackedInt32Array) -> void:
	var remove_effects: Array[RPGEffect] = []
	for index in indexes:
		if index >= 0 and effects.size() > index:
			remove_effects.append(effects[index])
	for obj in remove_effects:
		effects.erase(obj)
	fill_effects(indexes[0])
	
#endregion


func _on_effects_list_copy_requested(indexes: PackedInt32Array) -> void:
	var copy_effects: Array[RPGEffect]
	for index in indexes:
		if index > effects.size() - 1:
			continue
		copy_effects.append(effects[index].clone(true))
		
	StaticEditorVars.CLIPBOARD["effects"] = copy_effects


func _on_effects_list_cut_requested(indexes: PackedInt32Array) -> void:
	var copy_effects: Array[RPGEffect]
	var remove_effects: Array[RPGEffect]
	for index in indexes:
		if index > effects.size() - 1:
			continue
		copy_effects.append(effects[index].clone(true))
		remove_effects.append(effects[index])
	for item in remove_effects:
		effects.erase(item)

	StaticEditorVars.CLIPBOARD["effects"] = copy_effects
	
	var item_selected = max(-1, indexes[0])
	fill_effects(item_selected)


func _on_effects_list_paste_requested(index: int) -> void:
	if StaticEditorVars.CLIPBOARD.has("effects"):
		for i in StaticEditorVars.CLIPBOARD["effects"].size():
			var real_index = index + i + 1
			var current_effect = StaticEditorVars.CLIPBOARD["effects"][i].clone()
			if real_index < effects.size():
				effects.insert(real_index, current_effect)
			else:
				effects.append(current_effect)
	
	fill_effects(min(index + 1, effects.size() - 1))
	
	var list = %EffectsList
	await list.columns_setted
	await get_tree().process_frame
	await get_tree().process_frame
	if StaticEditorVars.CLIPBOARD.has("effects"):
		for i in range(index + 1, index + StaticEditorVars.CLIPBOARD["effects"].size() + 1):
			if i >= effects.size():
				i = index
			list.select(i, false)
