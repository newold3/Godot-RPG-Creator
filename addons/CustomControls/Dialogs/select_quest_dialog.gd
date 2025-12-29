@tool
extends Window

var current_editing_quest = -1

const ACTIVE_QUEST = "🔒 "


signal selected_items(items: PackedInt32Array)


func _ready() -> void:
	close_requested.connect(queue_free)
	fill_quests()


func fill_quests() -> void:
	var node = %QuestList
	node.clear()
	for i: int in range(1, RPGSYSTEM.database.quests.size(), 1):
		var quest: RPGQuest = RPGSYSTEM.database.quests[i]
		node.add_item("%s: %s" % [quest.id, quest.name])
		node.set_item_metadata(-1, quest.id)
		if quest.id ==  current_editing_quest:
			node.set_item_text(i - 1, ACTIVE_QUEST + node.get_item_text(i - 1))
			node.set_item_disabled(i, true)


func set_main_quest_selected(idx: int) -> void:
	var node = %QuestList
	for i in  node.get_item_count():
		if node.get_item_metadata(i) == idx:
			current_editing_quest = idx
			node.set_item_text(i, ACTIVE_QUEST + node.get_item_text(i))
			node.set_item_disabled(i, true)
			break


func set_item_disabled(idx: int, disabled: bool) -> void:
	var node = %QuestList
	for i in  node.get_item_count():
		if node.get_item_metadata(i) == idx:
			node.set_item_disabled(i, disabled)
			break


func set_selected_indexes(indexes: PackedInt32Array) -> void:
	var node = %QuestList
	for idx in indexes:
		for i in  node.get_item_count():
			if node.get_item_metadata(i) == idx:
				node.select(i, false)
				break


func set_single_item_mode() -> void:
	%QuestList.set_select_mode(ItemList.SELECT_SINGLE)
	title = tr("Select Quest")


func _on_ok_button_pressed() -> void:
	var node = %QuestList
	var indexes = node.get_selected_items()
	var real_indexes: PackedInt32Array = PackedInt32Array()
	for idx in indexes:
		real_indexes.append(node.get_item_metadata(idx))
	selected_items.emit(real_indexes)
	queue_free()


func _on_cancel_button_pressed() -> void:
	queue_free()


func _on_quest_list_item_activated(index: int) -> void:
	if %QuestList.select_mode == ItemList.SELECT_SINGLE:
		_on_ok_button_pressed()
