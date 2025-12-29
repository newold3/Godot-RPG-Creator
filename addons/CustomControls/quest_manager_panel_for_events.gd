@tool
extends MarginContainer

var quests: Array[RPGEventPQuest]
var pages: Array[RPGEventPage]
var relationship_levels: Array[RPGRelationshipLevel]


func set_data(p_quests: Array[RPGEventPQuest]) -> void:
	quests = p_quests
	fill_list(0)


func fill_list(index: int) -> void:
	var node = %QuestList
	node.clear()
	
	for quest: RPGEventPQuest in quests:
		if quest.id > 0 and RPGSYSTEM.database.quests.size() > quest.id:
			var real_quest = RPGSYSTEM.database.quests
			var quest_name = real_quest[quest.id].name
			node.add_column([quest_name])
		else:
			node.add_column(["⚠ Invalid Data"])
	
	await node.columns_setted
	
	if index >= 0 and quests.size() > index:
		node.select(index)


func _on_quest_list_copy_requested(indexes: PackedInt32Array) -> void:
	var copy_quest: Array[RPGEventPQuest]
	for index in indexes:
		if index > quests.size() - 1:
			continue
		copy_quest.append(quests[index].clone(true))
		
	StaticEditorVars.CLIPBOARD["event_quest_list"] = copy_quest


func _on_quest_list_cut_requested(indexes: PackedInt32Array) -> void:
	var copy_quests: Array[RPGEventPQuest]
	var remove_quests: Array[RPGEventPQuest]
	for index in indexes:
		if index > quests.size() - 1:
			continue
		copy_quests.append(quests[index].clone(true))
		remove_quests.append(quests[index])
	for quest in remove_quests:
		quests.erase(quest)

	StaticEditorVars.CLIPBOARD["event_quest_list"] = copy_quests
	
	var item_selected = max(-1, indexes[0])
	fill_list(item_selected)


func _on_quest_list_paste_requested(index: int) -> void:
	if StaticEditorVars.CLIPBOARD.has("event_quest_list"):
		for i in StaticEditorVars.CLIPBOARD["event_quest_list"].size():
			var real_index = index + i
			var current_quest = StaticEditorVars.CLIPBOARD["event_quest_list"][i].clone()
			if real_index < quests.size():
				quests.insert(real_index, current_quest)
			else:
				quests.append(current_quest)
	
	fill_list(min(index + 1, quests.size() - 1))
	
	var list = %QuestList
	await list.columns_setted
	await get_tree().process_frame
	await get_tree().process_frame
	if StaticEditorVars.CLIPBOARD.has("event_quest_list"):
		for i in range(index, index + StaticEditorVars.CLIPBOARD["event_quest_list"].size()):
			if i >= quests.size():
				i = index
			list.select(i, false)


func _on_quest_list_delete_pressed(indexes: PackedInt32Array) -> void:
	var remove_quests: Array[RPGEventPQuest] = []
	for index in indexes:
		if index >= 0 and quests.size() > index:
			remove_quests.append(quests[index])
	for quest in remove_quests:
		quests.erase(quest)
	fill_list(indexes[0])


func _on_quest_list_item_activated(index: int) -> void:
	var path = "res://addons/CustomControls/Dialogs/select_event_quest_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	dialog.pages = pages
	dialog.relationship_levels = relationship_levels
	var data: RPGEventPQuest
	if index >= 0 and quests.size() > index:
		data = quests[index]
	else:
		data = RPGEventPQuest.new()
	dialog.set_data(data)
	dialog.data_changed.connect(_on_quest_changed.bind(index))


func _on_quest_changed(quest: RPGEventPQuest, index: int) -> void:
	if index >= 0 and quests.size() > index:
		quests[index] = quest
	else:
		quests.append(quest)
	
	fill_list(index)


func _on_quest_list_duplicate_requested(indexes: PackedInt32Array) -> void:
	var current_quests: Array[RPGEventPQuest] = []

	for index in indexes:
		if index > quests.size() - 1:
			continue
		current_quests.append(quests[index].clone(true))
	
	var index = indexes[-1] + 1
	
	if current_quests:
		for i in current_quests.size():
			var current_quest: RPGEventPQuest = current_quests[i]
			var real_index = index + i
			if real_index < quests.size():
				quests.insert(real_index, current_quest)
			else:
				quests.append(current_quest)
	
	fill_list(-1)
	
	var list = %QuestList
	await list.columns_setted
	await get_tree().process_frame
	await get_tree().process_frame
	for i in range(index, index + current_quests.size()):
		if i >= quests.size():
			i = index
		list.select(i, false)
