@tool
extends BasePanelData


var quest_cache: Dictionary = {
	"npc_id": RPGMapEventID.new(),
	"item_type": 0,
	"item_id": 1,
	"weapon_id": 1,
	"armor_id": 1,
	"item_quantity": 1,
	"item_preserve": false,
	"enemy_id": 1,
	"enemy_quantity": 1,
	"map_id": -1,
	"global_event": -1
}

func get_custom_class() -> String:
	return "RPGQuest"


func get_data() -> RPGQuest:
	if not data: return null
	if current_selected_index != -1:
		current_selected_index = max(1, min(current_selected_index, data.size() - 1))
		return data[current_selected_index]
	else:
		return null


func _ready() -> void:
	super()
	default_data_element = RPGQuest.new()
	_fill_type_options()
	_fill_item_type_options()
	_fill_available_categories()
	
	%TypeOptions.item_selected.emit(0)


func _fill_type_options() -> void:
	var types = RPGQuest.QuestMode.keys()
	var node = %TypeOptions
	node.clear()
	
	for key: String in types:
		node.add_item(key.to_camel_case().capitalize().replace("  ", " "))


func _fill_item_type_options() -> void:
	var types = RPGQuest.ItemType.keys()

	var node = %ItemTypeOptions
	node.clear()
	
	for key: String in types:
		if key == "ENEMY": continue
		node.add_item(key.to_camel_case().capitalize().replace("  ", " "))


func _fill_reward_list(selected_index: int = -1) -> void:
	var node = %RewardList
	node.clear()
	
	var reward_list = get_data().reward.items
	for reward: RPGItemDrop in reward_list:
		var current_data
		var prefix
		if reward.item.data_id == 0: # items
			current_data = database.items
			prefix = "<Item> "
		elif reward.item.data_id == 1: # weapons
			current_data = database.weapons
			prefix = "<Weapon> "
		elif reward.item.data_id == 2: # armors
			current_data = database.armors
			prefix = "<Armor> "
		
		if current_data:
			var quantity: String
			if current_data.size() > reward.item.item_id:
				var item_name = str(reward.item.item_id).pad_zeros(str(current_data.size()).length())
				item_name += ": " + current_data[reward.item.item_id].name
				if reward.quantity != reward.quantity2:
					quantity = str(reward.quantity) + " ~ " + str(reward.quantity2)
				else:
					quantity = str(reward.quantity)
				node.add_column([prefix + item_name, quantity])
			else:
				if reward.quantity != reward.quantity2:
					quantity = str(reward.quantity) + " ~ " + str(reward.quantity2)
				else:
					quantity = str(reward.quantity)
				node.add_column([prefix + "⚠ Invalid Data", quantity])
	
	if selected_index >= 0:
		await node.columns_setted
		node.select(selected_index)


func clear_cache() -> void:
	quest_cache.npc_id = RPGMapEventID.new()
	quest_cache.item_type = 0
	quest_cache.item_id = 1
	quest_cache.weapon_id = 1
	quest_cache.armor_id = 1
	quest_cache.item_quantity = 1
	quest_cache.item_preserve = false
	quest_cache.enemy_id = 1
	quest_cache.enemy_quantity = 1
	quest_cache.map_id = -1
	quest_cache.global_event = -1


func _update_data_fields() -> void:
	busy = true
	
	#clear_cache()
	quest_cache.global_event = -1
	
	if current_selected_index != -1:
		disable_all(false)
		var current_data = get_data()

		if current_data.type == RPGQuest.QuestMode.TALK_TO_NPC:
			quest_cache.npc_id = current_data.target_event.clone(true)
		elif current_data.type == RPGQuest.QuestMode.GATHER_ITEM:
			quest_cache.item_type = current_data.item_type
			match quest_cache.item_type:
				0: quest_cache.item_id = current_data.item_id
				1: quest_cache.weapon_id = current_data.item_id
				2: quest_cache.armor_id = current_data.item_id
			quest_cache.item_quantity = current_data.quantity
			quest_cache.item_preserve = current_data.keep_materials
		elif current_data.type == RPGQuest.QuestMode.BOUNTY_HUNTS:
			quest_cache.enemy_id = current_data.enemy_id
			quest_cache.enemy_quantity = current_data.quantity
		elif current_data.type == RPGQuest.QuestMode.FIND_LOCATION:
			quest_cache.map_id = current_data.item_id
			quest_cache.global_event = current_data.global_event
		
		%NameLineEdit.text = current_data.name
		%CategoryLineEdit.text = current_data.category
		%StartUnlocked.set_pressed(current_data.default_unlocked)
		%IsRepeatable.set_pressed(current_data.is_repeatable)
		%MinLevelSpinBox.value = current_data.min_level
		%TimeLimit.value = current_data.time_limit
		%TypeOptions.select(current_data.type)
		%TypeOptions.item_selected.emit(current_data.type)
		%Gold.value = current_data.reward.gold
		%Experience.value = current_data.reward.experience
		
		%Description.text = current_data.description
		
		%MissionAvailable.set_icon(current_data.icon_available.path, current_data.icon_available.region)
		%MissionProgress.set_icon(current_data.icon_progress.path, current_data.icon_progress.region)
		%MissionCompleted.set_icon(current_data.icon_completed.path, current_data.icon_completed.region)
		
		if current_data.prerequisites:
			set_button_text(%Prerequisites, current_data.prerequisites)
		else:
			%Prerequisites.text = tr("Select Quests")
		if current_data.multi_quests:
			set_button_text(%AutoStartQuests, current_data.multi_quests)
		else:
			%AutoStartQuests.text = tr("Select Quests")
		if current_data.chain_quest != -1:
			set_button_text(%ChainQuest, current_data.chain_quest)
		else:
			%ChainQuest.text = tr("Select Chain Quest")
		if current_data.quests_unlocked:
			set_button_text(%QuestUnlocked, current_data.quests_unlocked)
		else:
			%QuestUnlocked.text = tr("Select Quests")
		
		set_global_event_name()
		
		%Notes.text = str(current_data.notes)
		
		_fill_reward_list()

	else:
		disable_all(true)
		%NameLineEdit.text = ""
	
	busy = false


func _on_category_line_edit_text_changed(new_text: String) -> void:
	get_data().category = new_text
	_fill_available_categories()


func _on_start_unlocked_toggled(toggled_on: bool) -> void:
	get_data().default_unlocked = toggled_on


func _on_is_repeatable_toggled(toggled_on: bool) -> void:
	get_data().is_repeatable = toggled_on


func _on_max_level_spin_box_value_changed(value: float) -> void:
	if not get_data(): return
	get_data().min_level = value


func _on_type_options_item_selected(index: int) -> void:
	var current_data = get_data()
	if not current_data: return
	
	current_data.clear_objetive()
	current_data.type = index
	var nodes = [%ParametersLabel, %ObjetiveParam1, %ObjetiveParam2, %ObjetiveParam3, %ObjetiveParam4, %ObjetiveParam5, %ObjetiveParam6, %ObjetiveParam7]
	for node in nodes:
		node.visible = false

	match index:
		0:
			%ObjetiveParam5.visible = true
			
			current_data.target_event = quest_cache.npc_id.clone(true)
			current_data.quantity = quest_cache.enemy_quantity
			
			set_npc_name()
		1:
			%ObjetiveParam1.visible = true
			%ObjetiveParam3.visible = true
			
			current_data.item_type = quest_cache.item_type
			match quest_cache.item_type:
				0: current_data.item_id = quest_cache.item_id
				1: current_data.item_id = quest_cache.weapon_id
				2: current_data.item_id = quest_cache.armor_id
			current_data.quantity = quest_cache.item_quantity
			current_data.keep_materials = quest_cache.item_preserve
			
			set_item_name(quest_cache.item_type, quest_cache.item_id)
			%Quantity.value = quest_cache.item_quantity
			%Preserve.set_pressed(quest_cache.item_preserve)
		2:
			%ObjetiveParam2.visible = true
			
			current_data.enemy_id = quest_cache.enemy_id
			current_data.quantity = quest_cache.enemy_quantity
			
			%EnemyQuantity.value = quest_cache.enemy_quantity
			set_enemy_name()
		3:
			%ObjetiveParam6.visible = true
			%ObjetiveParam7.visible = true
			
			current_data.item_id = quest_cache.map_id
			current_data.global_event = quest_cache.global_event
			
			set_map_name()
			set_global_event_name()
	
	if index < 4:
		%ParametersLabel.visible = true


func _on_gold_value_changed(value: float) -> void:
	get_data().reward.gold = value


func _on_experience_value_changed(value: float) -> void:
	get_data().reward.experience = value


func _on_description_text_changed() -> void:
	get_data().description = %Description.text


func _open_icon_dialog(node: Control, key: String) -> void:
	var path = "res://addons/CustomControls/Dialogs/select_icon_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	dialog.set_data(get_data().get(key))
	dialog.extra_files = ["animated_images"]
	
	dialog.icon_changed.connect(update_icon.bind(node, key))


func update_icon(icon_panel: Control, key: String) -> void:
	var icon = get_data().get(key)
	icon_panel.set_icon(icon.path, icon.region)


func _on_mission_available_clicked() -> void:
	_open_icon_dialog(%MissionAvailable, "icon_available")


func _on_mission_available_paste_requested(icon: String, region: Rect2) -> void:
	var data_icon = get_data().icon_available
	data_icon.path = icon
	data_icon.region = region
	%MissionAvailable.set_icon(data_icon.path, data_icon.region)


func _on_mission_available_remove_requested() -> void:
	get_data().icon_available.clear()
	%MissionAvailable.clear()


func _on_mission_progress_clicked() -> void:
	_open_icon_dialog(%MissionProgress, "icon_progress")


func _on_mission_progress_paste_requested(icon: String, region: Rect2) -> void:
	var data_icon = get_data().icon_progress
	data_icon.path = icon
	data_icon.region = region
	%MissionProgress.set_icon(data_icon.path, data_icon.region)


func _on_mission_progress_remove_requested() -> void:
	get_data().icon_progress.clear()
	%MissionProgress.clear()


func _on_mission_completed_clicked() -> void:
	_open_icon_dialog(%MissionCompleted, "icon_completed")


func _on_mission_completed_paste_requested(icon: String, region: Rect2) -> void:
	var data_icon = get_data().icon_completed
	data_icon.path = icon
	data_icon.region = region
	%MissionCompleted.set_icon(data_icon.path, data_icon.region)


func _on_mission_completed_remove_requested() -> void:
	get_data().icon_completed.clear()
	%MissionCompleted.clear()


func _on_time_limit_value_changed(value: float) -> void:
	get_data().time_limit = value


func _on_prerequisites_middle_click_pressed() -> void:
	get_data().prerequisites.clear()
	%Prerequisites.text = tr("Select Quests")


func _select_quest(button: Button, id: String, is_single: bool = false) -> void:
	var path = "res://addons/CustomControls/Dialogs/select_quest_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	var current_indexes = get_data().get(id) if not is_single else [get_data().get(id)]
	dialog.set_selected_indexes(current_indexes)
	dialog.set_main_quest_selected(get_data().id)
	if is_single:
		dialog.set_single_item_mode()
	
	dialog.selected_items.connect(
		func(indexes: PackedInt32Array):
			if not is_single:
				get_data().set(id, indexes)
			else:
				get_data().set(id, indexes[0])
			set_button_text(button, get_data().get(id))
	)


func set_button_text(button: Button, text: Variant) -> void:
	var current_text = str(text)
	if not "[" in current_text:
		current_text = "[" + current_text + "]"
	button.text = current_text


func _on_prerequisites_pressed() -> void:
	_select_quest(%Prerequisites, "prerequisites")


func _on_auto_start_quests_middle_click_pressed() -> void:
	get_data().multi_quests.clear()
	%AutoStartQuests.text = tr("Select Quests")


func _on_auto_start_quests_pressed() -> void:
	_select_quest(%AutoStartQuests, "multi_quests")


func _on_chain_quest_middle_click_pressed() -> void:
	get_data().chain_quest = -1
	%ChainQuest.text = tr("Select Chain Quest")


func _on_chain_quest_pressed() -> void:
	_select_quest(%ChainQuest, "chain_quest", true)


func _on_quest_unlocked_middle_click_pressed() -> void:
	get_data().quests_unlocked.clear()
	%QuestUnlocked.text = tr("Select Quests")


func _on_quest_unlocked_pressed() -> void:
	_select_quest(%QuestUnlocked, "quests_unlocked")


func set_npc_name() -> void:
	var event_name: String = ""
	var map_name: String = ""
	var page_name: String = ""
	var node = %TargetEvent
	var ev = get_data().target_event
	if ev and ev.map_id != -1 and ev.event_id != -1:
		map_name = RPGSYSTEM.map_infos.get_map_name_from_id(ev.map_id)
		map_name = (map_name if not map_name.is_empty() else str(ev.map_id))
		event_name = "%s: %s" % [ev.event_id, RPGSYSTEM.map_infos.get_event_name(ev.map_id, ev.event_id)]
		page_name = RPGSYSTEM.map_infos.get_event_page_name(ev.map_id, ev.event_id, ev.event_page_id)
	
	if not event_name.is_empty():
		node.text = "Map < %s > event %s - %s" % [map_name, event_name, page_name]
	else:
		node.text = tr("Select Event")


func set_item_name(type: int, id: int) -> void:
	var node = %ItemID
	
	var current_data = RPGSYSTEM.database.items if type == 0 \
		else RPGSYSTEM.database.weapons if type == 1 \
		else RPGSYSTEM.database.armors
	
	%ItemID.text = "%s: %s" % [id, current_data[id].name]


func set_enemy_name() -> void:
	var node = %EnemyID
	var enemy_name: String
	
	var enemy_id = get_data().enemy_id
	if enemy_id > 0 and RPGSYSTEM.database.enemies.size() > enemy_id:
		enemy_name = "%s: %s" % [enemy_id, RPGSYSTEM.database.enemies[enemy_id].name]
	
	if not enemy_name.is_empty():
		node.text = enemy_name
	else:
		node.text = tr("Select Enemy")
		


func set_map_name() -> void:
	var node = %TargetMap
	
	var map_id = get_data().item_id
	var map_name = RPGSYSTEM.map_infos.get_map_name_from_id(map_id)
	
	if map_name or RPGSYSTEM.map_infos.get_map_by_id(map_id):
		%TargetMap.text = "Map: < %s >" % (map_name if not map_name.is_empty() else map_id)
	else:
		%TargetMap.text = tr("Select Map")


func set_global_event_name() -> void:
	var current_data = get_data()
	var global_event_id = current_data.global_event
	if global_event_id <= 0:
		current_data.global_event = -1
		%GlobalEvent.text = tr("Select Global Event")
	else:
		var global_event_name: String = ""
		if global_event_id > 0 and RPGSYSTEM.database.common_events.size() > global_event_id:
			global_event_name = "%s: %s" % [global_event_id, RPGSYSTEM.database.common_events[global_event_id].name]
		else:
			global_event_name = "⚠ Invalid Data"
			
		%GlobalEvent.text = tr("Run Global Event") + " : " + global_event_name


func _on_item_type_options_item_selected(index: int) -> void:
	if not busy: quest_cache.item_type = index
	get_data().item_type = index
	get_data().item_id = quest_cache.item_id if index == 0 \
		else quest_cache.weapon_id if index == 1 \
		else quest_cache.armor_id
	
	set_item_name(index, get_data().item_id)


func _open_select_any_data_dialog(current_data, id_selected: int, title: String, target: int) -> void:
	var path = "res://addons/CustomControls/Dialogs/select_any_data_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	dialog.database = RPGSYSTEM.database
	
	dialog.destroy_on_hide = true
	dialog.selected.connect(_on_any_data_selected, CONNECT_ONE_SHOT)
	
	dialog.setup(current_data, id_selected, title, target)


func _on_any_data_selected(id: int, target: int) -> void:
	if target in [0, 1, 2]:
		get_data().item_id = id
		set_item_name(target, id)
	elif target == 4:
		get_data().enemy_id = id
		set_enemy_name()
	elif target == 5:
		get_data().global_event = id
		set_global_event_name()
	if not busy:
		match target:
			0: # Item
				quest_cache.item_id = id
			1: # Weapon
				quest_cache.weapon_id = id
			2: # Armor
				quest_cache.armor_id = id
			4: # Enemy
				quest_cache.enemy_id = id
			5: # Global Event
				quest_cache.global_event = id


func _on_item_id_pressed() -> void:
	var item_type = get_data().item_type
	match item_type:
		0: _open_select_any_data_dialog(RPGSYSTEM.database.items, get_data().item_id, "items", item_type)
		1: _open_select_any_data_dialog(RPGSYSTEM.database.weapons, get_data().item_id, "weapons", item_type)
		2: _open_select_any_data_dialog(RPGSYSTEM.database.armors, get_data().item_id, "armors", item_type)


func _on_quantity_value_changed(value: float) -> void:
	if not get_data(): return
	if not busy: quest_cache.item_quantity = value
	get_data().quantity = value


func _on_preserve_toggled(toggled_on: bool) -> void:
	if not busy: quest_cache.item_preserve
	get_data().keep_materials = toggled_on


func _on_enemy_id_pressed() -> void:
	_open_select_any_data_dialog(RPGSYSTEM.database.enemies, get_data().enemy_id, "Enemies", 4)


func _on_enemy_quantity_value_changed(value: float) -> void:
	if not get_data(): return
	if not busy: quest_cache.enemy_quantity = value
	get_data().quantity = value


func _on_target_map_pressed() -> void:
	var path = "res://addons/CustomControls/Dialogs/select_map_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	
	dialog.set_selected(get_data().item_id)
	
	dialog.selected_item.connect(
		func(index):
			quest_cache.map_id = index
			get_data().item_id = index
			set_map_name()
	)


func _on_target_event_pressed() -> void:
	var path = "res://addons/CustomControls/Dialogs/select_event_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	
	dialog.set_selection(get_data().target_event.map_id, get_data().target_event.event_id, get_data().target_event.event_page_id)
	
	dialog.event_selected.connect(
		func(map_id: int, event_id: int, page_id: int):
			var ev = RPGMapEventID.new(map_id, event_id, page_id)
			get_data().target_event = ev
			if not busy: quest_cache.npc_id = ev.clone(true)
			set_npc_name()
	)


func _on_reward_list_copy_requested(indexes: PackedInt32Array) -> void:
	var copy_rewards: Array[RPGItemDrop]
	var list = get_data().reward.items
	for index in indexes:
		if index > list.size() or index < 0:
			continue
		copy_rewards.append(list[index].clone(true))
		
	StaticEditorVars.CLIPBOARD["mission_reward"] = copy_rewards


func _on_reward_list_cut_requested(indexes: PackedInt32Array) -> void:
	var copy_rewards: Array[RPGItemDrop]
	var remove_rewards: Array[RPGItemDrop]
	var list = get_data().reward.items
	for index in indexes:
		if index > list.size():
			continue
		if list.size() > index and index >= 0:
			copy_rewards.append(list[index].clone(true))
			remove_rewards.append(list[index])
	for item in remove_rewards:
		list.erase(item)

	StaticEditorVars.CLIPBOARD["mission_reward"] = copy_rewards
	
	var item_selected = max(-1, indexes[0])
	_fill_reward_list(item_selected)


func _on_reward_list_delete_pressed(indexes: PackedInt32Array) -> void:
	var remove_rewards: Array[RPGItemDrop] = []
	var list = get_data().reward.items
	for index in indexes:
		if index >= 0 and list.size() > index:
			remove_rewards.append(list[index])
	for obj in remove_rewards:
		list.erase(obj)
	_fill_reward_list(indexes[0])


func _on_reward_list_item_activated(index: int) -> void:
	var list = get_data().reward.items
	if list.size() > 0 and list.size() > index: # update item
		_show_reward_dialog(list[index], index)
	else: # new item
		_show_reward_dialog()


func _on_reward_list_paste_requested(index: int) -> void:
	var reward_list = get_data().reward.items
	
	if StaticEditorVars.CLIPBOARD.has("mission_reward"):
		for i in StaticEditorVars.CLIPBOARD["mission_reward"].size():
			var reward1: RPGItemDrop = StaticEditorVars.CLIPBOARD["mission_reward"][i].clone()
			var material_setted: bool = false
			for j in reward_list.size():
				var reward2: RPGItemDrop = reward_list[j]
				if reward1.item.data_id == reward2.item.data_id and reward1.item.item_id == reward2.item.item_id:
					reward2.quantity = reward1.quantity
					reward2.percent = reward1.percent
					material_setted = true
					break
					
			if material_setted: continue
			
			var real_index = index + i
			if real_index < reward_list.size():
				reward_list.insert(real_index, reward1)
			else:
				reward_list.append(reward1)
	else:
		return
	
	_fill_reward_list(min(index, reward_list.size() - 1))
	
	var list = %RewardList
	await list.columns_setted
	await get_tree().process_frame
	await get_tree().process_frame
	list.deselect_all()
	if StaticEditorVars.CLIPBOARD.has("mission_reward"):
		for i in StaticEditorVars.CLIPBOARD["mission_reward"].size():
			for j in reward_list.size():
				var reward1: RPGItemDrop = StaticEditorVars.CLIPBOARD["mission_reward"][i]
				var reward2: RPGItemDrop = reward_list[j]
				if reward1.item.data_id == reward2.item.data_id and reward1.item.item_id == reward2.item.item_id:
					list.select(j, false)
					break


func _show_reward_dialog(item: RPGItemDrop = null, index: int = -1) -> void:
	var path = "res://addons/CustomControls/Dialogs/select_item_drop_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	dialog.hide_percent()
	dialog.database = database
	if item:
		dialog.set_data(item)
		dialog.item_updated.connect(_on_reward_updated.bind(index))
	else:
		dialog.create_new_data()
		dialog.item_created.connect(_on_reward_created)


func _on_reward_created(new_item: RPGItemDrop) -> void:
	var reward_found: bool = false
	var reward_index: int = -1
	var list = get_data().reward.items
	for i in list.size():
		var reward: RPGItemDrop = list[i]
		if new_item.item.data_id == reward.item.data_id and new_item.item.item_id == reward.item.item_id:
			reward.quantity = new_item.quantity
			reward.quantity2 = new_item.quantity2
			reward.percent = new_item.percent
			reward_found = true
			reward_index = i
			break

	if !reward_found:
		list.append(new_item)
		_fill_reward_list(list.size() - 1)
	else:
		_fill_reward_list(reward_index)


func _on_reward_updated(_reward: RPGItemDrop, index: int) -> void:
	var duplicate_found: bool = false
	var list = get_data().reward.items
	for i in list.size():
		var reward1: RPGItemDrop = list[i]
		for j in range(list.size() - 1, i, -1):
			var reward2: RPGItemDrop = list[j]
			if reward1.item.data_id == reward2.item.data_id and reward1.item.item_id == reward2.item.item_id:
				reward1.quantity = reward2.quantity
				reward1.quantity2 = reward2.quantity2
				reward1.percent = reward2.percent
				list.erase(reward2)
				index = i
				duplicate_found = true
				break
		if duplicate_found: break

	_fill_reward_list(index)


func _on_notes_text_changed() -> void:
	get_data().notes = %Notes.text


func _on_config_data_tabs_tab_changed(index: int) -> void:
	var node_path = "%%Tab%s" % (index + 1)
	var node = get_node_or_null(node_path)
	if node:
		for child in node.get_parent().get_children():
			child.visible = false
		node.visible = true


func _fill_available_categories() -> void:
	var node = %SelectCategory
	node.clear()
	node.add_item("Select Category")
	var categories = []
	for quest in RPGSYSTEM.database.quests:
		if not quest: continue
		if not quest.category.is_empty() and not quest.category.to_lower() in categories:
			categories.append(quest.category.to_lower())
			node.add_item(quest.category)
	node.select(0)


func _on_category_popup_menu_index_pressed(index: int) -> void:
	var category = %CategoryPopupMenu.get_item_text(index)
	get_data().category = category
	%CategoryLineEdit.text = category


func _on_select_category_item_selected(index: int) -> void:
	if index != 0:
		%SelectCategory.select(0)
		var category = %SelectCategory.get_item_text(index)
		%CategoryLineEdit.text = category


func _on_global_event_pressed() -> void:
	_open_select_any_data_dialog(RPGSYSTEM.database.common_events, get_data().global_event, "Global Event", 5)


func _on_global_event_middle_click_pressed() -> void:
	quest_cache.global_event = -1
	get_data().global_event = -1
	set_global_event_name()
