@tool
extends MarginContainer

var relationship: RPGRelationship


func set_data(p_relationship: RPGRelationship) -> void:
	relationship = p_relationship
	fill_list(0)


func fill_list(index: int) -> void:
	var node = %RelationshipList
	node.clear()
	
	for level: RPGRelationshipLevel in relationship.levels:
		var column = [level.name, str(int(level.experience))]
		node.add_column(column)
	
	await node.columns_setted
	
	if index >= 0 and relationship.levels.size() > index:
		node.select(index)


func _on_relationship_list_copy_requested(indexes: PackedInt32Array) -> void:
	var copy_levels: Array[RPGRelationshipLevel]
	for index in indexes:
		if index > relationship.levels.size() - 1:
			continue
		copy_levels.append(relationship.levels[index].clone(true))
		
	StaticEditorVars.CLIPBOARD["relationship_list"] = copy_levels


func _on_relationship_list_cut_requested(indexes: PackedInt32Array) -> void:
	var copy_levels: Array[RPGRelationshipLevel]
	var remove_levels: Array[RPGRelationshipLevel]
	for index in indexes:
		if index > relationship.levels.size() - 1:
			continue
		copy_levels.append(relationship.levels[index].clone(true))
		remove_levels.append(relationship.levels[index])
	for level in remove_levels:
		relationship.levels.erase(level)

	StaticEditorVars.CLIPBOARD["relationship_list"] = copy_levels
	
	var item_selected = max(-1, indexes[0])
	fill_list(item_selected)


func _on_relationship_list_delete_pressed(indexes: PackedInt32Array) -> void:
	var remove_levels: Array[RPGRelationshipLevel] = []
	for index in indexes:
		if index >= 0 and relationship.levels.size() > index:
			remove_levels.append(relationship.levels[index])
	for level in remove_levels:
		relationship.levels.erase(level)
	fill_list(indexes[0])


func _on_relationship_list_item_activated(index: int) -> void:
	var path = "res://addons/CustomControls/Dialogs/select_relationship_level_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	var data: RPGRelationshipLevel
	if index >= 0 and relationship.levels.size() > index:
		data = relationship.levels[index]
	else:
		data = RPGRelationshipLevel.new()
	dialog.set_data(data)
	dialog.data_changed.connect(_on_level_changed.bind(index))


func _on_level_changed(level: RPGRelationshipLevel, index: int) -> void:
	if index >= 0 and relationship.levels.size() > index:
		relationship.levels[index] = level
	else:
		relationship.levels.append(level)
	
	fill_list(index)


func _on_relationship_list_paste_requested(index: int) -> void:
	if StaticEditorVars.CLIPBOARD.has("relationship_list"):
		for i in StaticEditorVars.CLIPBOARD["relationship_list"].size():
			var real_index = index + i
			var current_level = StaticEditorVars.CLIPBOARD["relationship_list"][i].clone()
			if real_index < relationship.levels.size():
				relationship.levels.insert(real_index, current_level)
			else:
				relationship.levels.append(current_level)
	
	fill_list(min(index + 1, relationship.levels.size() - 1))
	
	var list = %RelationshipList
	await list.columns_setted
	await get_tree().process_frame
	await get_tree().process_frame
	if StaticEditorVars.CLIPBOARD.has("relationship_list"):
		for i in range(index, index + StaticEditorVars.CLIPBOARD["relationship_list"].size()):
			if i >= relationship.levels.size():
				i = index
			list.select(i, false)


func _on_relationship_list_duplicate_requested(indexes: PackedInt32Array) -> void:
	var current_levels: Array[RPGRelationshipLevel] = []

	for index in indexes:
		if index > relationship.levels.size() - 1:
			continue
		current_levels.append(relationship.levels[index].clone(true))
	
	var index = indexes[-1] + 1
	
	if current_levels:
		for i in current_levels.size():
			var current_level: RPGRelationshipLevel = current_levels[i]
			var real_index = index + i
			if real_index < relationship.levels.size():
				relationship.levels.insert(real_index, current_level)
			else:
				relationship.levels.append(current_level)
	
	fill_list(-1)
	
	var list = %RelationshipList
	await list.columns_setted
	await get_tree().process_frame
	await get_tree().process_frame
	for i in range(index, index + current_levels.size()):
		if i >= relationship.levels.size():
			i = index
		list.select(i, false)
