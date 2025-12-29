@tool
extends BasePanelData


func _ready() -> void:
	super()
	default_data_element = RPGEnemy.new()


func get_data() -> RPGEnemy:
	current_selected_index = max(1, min(current_selected_index, data.size() - 1))
	return data[current_selected_index]


func _update_data_fields() -> void:
	busy = true
	
	if current_selected_index != -1:
		disable_all(false)
		var current_data = get_data()
		%IconPicker.set_icon(current_data.icon.path, current_data.icon.region)
		%ExperienceSpinBox.value = current_data.experience_reward
		%GoldSpinBox1.value = current_data.gold_reward_from
		%GoldSpinBox2.value = current_data.gold_reward_to
		%NameLineEdit.text = current_data.name
		%BattlerPicker.set_icon(current_data.battler)
		%TraitsPanel.set_data(database, current_data.traits)
		%NoteTextEdit.text = current_data.notes
		%DescriptionTextEdit.text = current_data.description
		%MaxHPSpinBox.value = current_data.params[0]
		%AttackSpinBox.value = current_data.params[1]
		%MagicAttackSpinBox.value = current_data.params[2]
		%AgilitySpinBox.value = current_data.params[3]
		%MaxMPSpinBox.value = current_data.params[4]
		%DefenseSpinBox.value = current_data.params[5]
		%MagicDefenseSpinBox.value = current_data.params[6]
		%LuckSpinBox.value = current_data.params[7]
		var scene_name: String = "Select Enemy Scene"
		if current_data.enemy_scene.length() > 0:
			scene_name = current_data.enemy_scene
		%EnemySceneButton.text = scene_name
		
		%PasteParameters.set_disabled(!StaticEditorVars.CLIPBOARD.get("equipment_parameters_list", false))
		
		fill_drop_list()
		fill_action_list()
		fill_battle_actions()
	else:
		disable_all(true)
		%NameLineEdit.text = ""
		%BattlerPicker.set_icon(null)
		%TraitsPanel.clear()

	busy = false


func _on_battler_picker_clicked() -> void:
	var path = "res://addons/CustomControls/Dialogs/select_file_dialog.tscn"
	var parent = get_tree().get_nodes_in_group("main_database")[0]
	var dialog
	var main_panel = parent.get_child(0)
	if main_panel.cache_dialog.has(path) and is_instance_valid(main_panel.cache_dialog[path]):
		dialog = main_panel.cache_dialog[path]
		RPGDialogFunctions.show_dialog(dialog, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	else:
		dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
		main_panel.cache_dialog[path] = dialog
	await get_tree().process_frame
	
	dialog.target_callable = update_battler
	dialog.set_dialog_mode(0)
	dialog.set_file_selected(get_data().battler)
	
	dialog.fill_files("images")


func update_battler(path: String) -> void:
	%BattlerPicker.set_icon(path)
	get_data().battler = path


func _on_battler_picker_remove_requested() -> void:
	get_data().battler = ""
	%BattlerPicker.set_icon("")


func _on_visibility_changed() -> void:
	super()
	if visible:
		busy = true
		if current_selected_index != -1:
			%TraitsPanel.set_data(database, get_data().traits)
			fill_battle_actions()
		else:
			%TraitsPanel.clear()
		busy = true


func _on_gold_spin_box_1_value_changed(value: float) -> void:
	if busy: return
	busy = true
	%GoldSpinBox2.value = max(value, %GoldSpinBox2.value)
	get_data().gold_reward_from = %GoldSpinBox1.value
	get_data().gold_reward_to = %GoldSpinBox2.value
	busy = false


func _on_gold_spin_box_2_value_changed(value: float) -> void:
	if busy: return
	busy = true
	%GoldSpinBox1.value = min(value, %GoldSpinBox1.value)
	get_data().gold_reward_from = %GoldSpinBox1.value
	get_data().gold_reward_to = %GoldSpinBox2.value
	busy = false


func _on_experience_spin_box_value_changed(value: float) -> void:
	get_data().experience_reward = value


func _on_note_text_edit_text_changed() -> void:
	get_data().notes = %NoteTextEdit.text


func _on_description_text_edit_text_changed() -> void:
	get_data().description = %DescriptionTextEdit.text


func update_enemy_param(value: float, param_id: int) -> void:
	get_data().params[param_id] = value


func fill_drop_list(selected_index: int = -1) -> void:
	var node = %DropList
	node.clear()
	
	var drop_list = get_data().drop_items
	for mat: RPGItemDrop in drop_list:
		var current_data
		var prefix
		if mat.item.data_id == 0: # items
			current_data = database.items
			prefix = "<Item> "
		elif mat.item.data_id == 1: # weapons
			current_data = database.weapons
			prefix = "<Weapon> "
		elif mat.item.data_id == 2: # armors
			current_data = database.armors
			prefix = "<Armor> "
		
		if current_data:
			var quantity: String
			if current_data.size() > mat.item.item_id:
				var item_name = str(mat.item.item_id).pad_zeros(str(current_data.size()).length())
				item_name += ": " + current_data[mat.item.item_id].name
				if mat.quantity != mat.quantity2:
					quantity = str(mat.quantity) + " ~ " + str(mat.quantity2)
				else:
					quantity = str(mat.quantity)
				var percent = "%.2f %%" % mat.percent
				node.add_column([prefix + item_name, quantity, percent])
			else:
				if mat.quantity != mat.quantity2:
					quantity = str(mat.quantity) + " ~ " + str(mat.quantity2)
				else:
					quantity = str(mat.quantity)
				var percent = "%.2f %%" % mat.percent
				node.add_column([prefix + "⚠ Invalid Data", quantity, percent])
	
	if selected_index >= 0:
		await node.columns_setted
		node.select(selected_index)


func _on_drop_list_item_activated(index: int) -> void:
	var drop_list = get_data().drop_items
	if drop_list.size() > 0 and drop_list.size() > index: # update item
		show_select_required_item_dialog(drop_list[index], index)
	else: # new item
		show_select_required_item_dialog()


func show_select_required_item_dialog(item: RPGItemDrop = null, index: int = -1) -> void:
	var path = "res://addons/CustomControls/Dialogs/select_item_drop_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	dialog.database = database
	if item:
		dialog.set_data(item)
		dialog.item_updated.connect(_on_drop_updated.bind(index))
	else:
		dialog.create_new_data()
		dialog.item_created.connect(_on_drop_created)


func _on_drop_created(new_item: RPGItemDrop) -> void:
	var material_found: bool = false
	var material_index: int = -1
	var drop_list = get_data().drop_items
	for i in drop_list.size():
		var mat: RPGItemDrop = drop_list[i]
		if new_item.item.data_id == mat.item.data_id and new_item.item.item_id == mat.item.item_id:
			mat.quantity = new_item.quantity
			mat.quantity2 = new_item.quantity2
			mat.percent = new_item.percent
			material_found = true
			material_index = i
			break

	if !material_found:
		drop_list.append(new_item)
		fill_drop_list(drop_list.size() - 1)
	else:
		fill_drop_list(material_index)


func _on_drop_updated(_drop: RPGItemDrop, index: int) -> void:
	var duplicate_found: bool = false
	var drop_list = get_data().drop_items
	for i in drop_list.size():
		var mat1: RPGItemDrop = drop_list[i]
		for j in range(drop_list.size() - 1, i, -1):
			var mat2: RPGItemDrop = drop_list[j]
			if mat1.item.data_id == mat2.item.data_id and mat1.item.item_id == mat2.item.item_id:
				mat1.quantity = mat2.quantity
				mat1.quantity2 = mat2.quantity2
				mat1.percent = mat2.percent
				drop_list.erase(mat2)
				index = i
				duplicate_found = true
				break
		if duplicate_found: break

	fill_drop_list(index)



#region Drop list signals
func _on_drop_list_delete_pressed(indexes: PackedInt32Array) -> void:
	var remove_drops: Array[RPGItemDrop] = []
	var drop_list = get_data().drop_items
	for index in indexes:
		if index >= 0 and drop_list.size() > index:
			remove_drops.append(drop_list[index])
	for obj in remove_drops:
		drop_list.erase(obj)
	fill_drop_list(indexes[0])


func _on_drop_list_copy_requested(indexes: PackedInt32Array) -> void:
	var copy_drops: Array[RPGItemDrop]
	var drop_list = get_data().drop_items
	for index in indexes:
		if index > drop_list.size() or index < 0:
			continue
		copy_drops.append(drop_list[index].clone(true))
		
	StaticEditorVars.CLIPBOARD["enemy_drop_list"] = copy_drops


func _on_drop_list_cut_requested(indexes: PackedInt32Array) -> void:
	var copy_drops: Array[RPGItemDrop]
	var remove_drops: Array[RPGItemDrop]
	var drop_list = get_data().drop_items
	for index in indexes:
		if index > drop_list.size():
			continue
		if drop_list.size() > index and index >= 0:
			copy_drops.append(drop_list[index].clone(true))
			remove_drops.append(drop_list[index])
	for item in remove_drops:
		drop_list.erase(item)

	StaticEditorVars.CLIPBOARD["enemy_drop_list"] = copy_drops
	
	var item_selected = max(-1, indexes[0])
	fill_drop_list(item_selected)


func _on_drop_list_paste_requested(index: int) -> void:
	var drop_list = get_data().drop_items
	
	if StaticEditorVars.CLIPBOARD.has("enemy_drop_list"):
		for i in StaticEditorVars.CLIPBOARD["enemy_drop_list"].size():
			var mat1: RPGItemDrop = StaticEditorVars.CLIPBOARD["enemy_drop_list"][i].clone()
			var material_setted: bool = false
			for j in drop_list.size():
				var mat2: RPGItemDrop = drop_list[j]
				if mat1.item.data_id == mat2.item.data_id and mat1.item.item_id == mat2.item.item_id:
					mat2.quantity = mat1.quantity
					mat2.percent = mat1.percent
					material_setted = true
					break
					
			if material_setted: continue
			
			var real_index = index + i
			if real_index < drop_list.size():
				drop_list.insert(real_index, mat1)
			else:
				drop_list.append(mat1)
	else:
		return
	
	fill_drop_list(min(index, drop_list.size() - 1))
	
	var list = %DropList
	await list.columns_setted
	await get_tree().process_frame
	await get_tree().process_frame
	list.deselect_all()
	if StaticEditorVars.CLIPBOARD.has("enemy_drop_list"):
		for i in StaticEditorVars.CLIPBOARD["enemy_drop_list"].size():
			for j in drop_list.size():
				var mat1: RPGItemDrop = StaticEditorVars.CLIPBOARD["enemy_drop_list"][i]
				var mat2: RPGItemDrop = drop_list[j]
				if mat1.item.data_id == mat2.item.data_id and mat1.item.item_id == mat2.item.item_id:
					list.select(j, false)
					break

#endregion


func fill_action_list(selected_index: int = -1) -> void:
	var node = %PatternList
	node.clear()
	
	var action_list = get_data().action_patterns
	for at: RPGEnemyAction in action_list:
		var left_column: String
		var mid_column: String
		var right_column: String
		match at.condition_type:
			0: # Always
				mid_column = "Always"
			1: # Turn
				mid_column = "Turn %s + %s*X" % [at.condition_param1, at.condition_param2]
			2: # HP
				mid_column = "HP %s ~%s" % [at.condition_param1, at.condition_param2]
			3: # MP
				mid_column = "MP %s ~%s" % [at.condition_param1, at.condition_param2]
			4: # State
				var item_name = "⚠ Invalid Data"
				var current_data = database.states
				if current_data.size() > at.condition_param1:
					var id = str(at.condition_param1).pad_zeros(str(current_data.size()).length())
					item_name = "< " + id + ": " + current_data[at.condition_param1].name + " >"
				mid_column = "State %s" % item_name
			5: # Party Level
				var operation = ["=", "<", "<=", ">", ">=", "!="][at.condition_param1]
				mid_column = "Party Level %s %s" % [operation, at.condition_param2]
			6: # Switch
				var item_name = "⚠ Invalid Data"
				var current_data = RPGSYSTEM.system.switches.data
				if current_data.size() > at.condition_param1:
					var id = str(at.condition_param1).pad_zeros(str(current_data.size()).length())
					item_name = "< " + id + ": " + current_data[at.condition_param1].name + " >"
				var value = ["enabled", "disabled"][at.condition_param2]
				mid_column = "Switch %s is %s" % [item_name, value]
			7: # Variable
				var item_name = "⚠ Invalid Data"
				var current_data = RPGSYSTEM.system.variables.data
				if current_data.size() > at.condition_param1:
					var id = str(at.condition_param1).pad_zeros(str(current_data.size()).length())
					item_name = "< " + id + ": " + current_data[at.condition_param1].name + " >"
				var operation = ["=", "<", "<=", ">", ">=", "!="][at.condition_param2]
				var value = at.condition_param3
				mid_column = "Variable %s is %s to %s" % [item_name, operation, value]
		
		left_column = "⚠ Invalid Data"
		var current_data = database.skills
		if current_data.size() > at.skill_id:
			var id = str(at.skill_id).pad_zeros(str(current_data.size()).length())
			left_column = "< " + id + ": " + current_data[at.skill_id].name + " >"
		
		right_column = str(at.rating)
		
		node.add_column([left_column, mid_column, right_column])
	
	if selected_index >= 0:
		await node.columns_setted
		node.select(selected_index)


func _on_pattern_list_item_activated(index: int) -> void:
	var action_pattern_list = get_data().action_patterns
	if action_pattern_list.size() > 0 and action_pattern_list.size() > index: # update item
		show_select_enemy_action_dialog(action_pattern_list[index], index)
	else: # new item
		show_select_enemy_action_dialog()


func show_select_enemy_action_dialog(item: RPGEnemyAction = null, index: int = -1) -> void:
	var path = "res://addons/CustomControls/Dialogs/enemy_action_pattern_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	dialog.database = database
	if item:
		dialog.set_data(item, index)
		dialog.action_updated.connect(_on_enemy_action_updated)
	else:
		dialog.create_new_data()
		dialog.action_created.connect(_on_enemy_action_created)


func _on_enemy_action_created(action: RPGEnemyAction) -> void:
	var action_found: bool = false
	var action_index: int = -1
	var action_list = get_data().action_patterns
	for i in action_list.size():
		var at: RPGEnemyAction = action_list[i]
		if action.skill_id == at.skill_id and action.condition_type == at.condition_type:
			at.rating = action.rating
			at.condition_param1 = action.condition_param1
			at.condition_param2 = action.condition_param2
			at.condition_param3 = action.condition_param3
			action_found = true
			action_index = i
			break

	if !action_found:
		action_list.append(action)
		fill_action_list(action_list.size() - 1)
	else:
		fill_action_list(action_index)


func _on_enemy_action_updated(action: RPGEnemyAction, index: int) -> void:
	var duplicate_found: bool = false
	var action_list = get_data().action_patterns
	for i in action_list.size():
		if i == index: continue
		var at: RPGEnemyAction = action_list[i]
		if at.skill_id == action.skill_id and at.condition_type == action.condition_type:
			action_list.remove_at(index)
			index = i
			break
	
	var current_action = action_list[index]
	current_action.condition_type = action.condition_type
	current_action.skill_id = action.skill_id
	current_action.rating = action.rating
	current_action.condition_param1 = action.condition_param1
	current_action.condition_param2 = action.condition_param2
	current_action.condition_param3 = action.condition_param3

	fill_action_list(index)


#region Pattern Action list signals
func _on_pattern_list_delete_pressed(indexes: PackedInt32Array) -> void:
	var remove_actions: Array[RPGEnemyAction] = []
	var action_list = get_data().action_patterns
	for index in indexes:
		if index >= 0 and action_list.size() > index:
			remove_actions.append(action_list[index])
	for obj in remove_actions:
		action_list.erase(obj)
	fill_action_list(indexes[0])


func _on_pattern_list_copy_requested(indexes: PackedInt32Array) -> void:
	var parent = get_tree().get_nodes_in_group("main_database")[0]
	var main_panel = parent.get_child(0)
	var copy_actions: Array[RPGEnemyAction]
	var action_list = get_data().action_patterns
	for index in indexes:
		if index > action_list.size() or index < 0:
			continue
		copy_actions.append(action_list[index].clone(true))
		
	main_panel.CLIPBOARD["enemy_actions"] = copy_actions


func _on_pattern_list_cut_requested(indexes: PackedInt32Array) -> void:
	var parent = get_tree().get_nodes_in_group("main_database")[0]
	var main_panel = parent.get_child(0)
	var copy_actions: Array[RPGEnemyAction]
	var remove_actions: Array[RPGEnemyAction]
	var action_list = get_data().action_patterns
	for index in indexes:
		if index > action_list.size():
			continue
		if action_list.size() > index and index >= 0:
			copy_actions.append(action_list[index].clone(true))
			remove_actions.append(action_list[index])
	for item in remove_actions:
		action_list.erase(item)

	main_panel.CLIPBOARD["enemy_actions"] = copy_actions
	
	var item_selected = max(-1, indexes[0])
	fill_action_list(item_selected)


func _on_pattern_list_paste_requested(index: int) -> void:
	var parent = get_tree().get_nodes_in_group("main_database")[0]
	var main_panel = parent.get_child(0)
	
	var action_list = get_data().action_patterns
	
	if main_panel.CLIPBOARD.has("enemy_actions"):
		for i in main_panel.CLIPBOARD["enemy_actions"].size():
			var mat1: RPGEnemyAction = main_panel.CLIPBOARD["enemy_actions"][i].clone()
			var material_setted: bool = false
			for j in action_list.size():
				var mat2: RPGEnemyAction = action_list[j]
				if mat1.skill_id == mat2.skill_id and mat1.condition_type == mat2.condition_type:
					mat2.condition_type = mat1.condition_type
					mat2.skill_id = mat1.skill_id
					mat2.rating = mat1.rating
					mat2.condition_param1 = mat1.condition_param1
					mat2.condition_param2 = mat1.condition_param2
					mat2.condition_param3 = mat1.condition_param3
					material_setted = true
					break
					
			if material_setted: continue
			
			var real_index = index + i
			if real_index < action_list.size():
				action_list.insert(real_index, mat1)
			else:
				action_list.append(mat1)
	else:
		return
	
	fill_action_list(min(index, action_list.size() - 1))
	
	var list = %PatternList
	await list.columns_setted
	await get_tree().process_frame
	await get_tree().process_frame
	list.deselect_all()
	if main_panel.CLIPBOARD.has("enemy_actions"):
		for i in main_panel.CLIPBOARD["enemy_actions"].size():
			for j in action_list.size():
				var mat1: RPGEnemyAction = main_panel.CLIPBOARD["enemy_actions"][i]
				var mat2: RPGEnemyAction = action_list[j]
				if mat1.skill_id == mat2.skill_id and mat1.condition_type == mat2.condition_type:
					list.select(j, false)
					break

#endregion


func _on_enemy_scene_button_middle_click_pressed() -> void:
	get_data().enemy_scene = ""
	%EnemySceneButton.text = TranslationManager.tr("Select Enemy Scene")


func _on_enemy_scene_button_pressed() -> void:
	var path = "res://addons/CustomControls/Dialogs/select_file_dialog.tscn"
	var parent = get_tree().get_nodes_in_group("main_database")[0]
	var dialog
	var main_panel = parent.get_child(0)
	if main_panel.cache_dialog.has(path) and is_instance_valid(main_panel.cache_dialog[path]):
		dialog = main_panel.cache_dialog[path]
		RPGDialogFunctions.show_dialog(dialog, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	else:
		dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
		main_panel.cache_dialog[path] = dialog
	await get_tree().process_frame
	
	dialog.set_dialog_mode(0)

	dialog.target_callable = update_enemy_scene
	dialog.set_file_selected(get_data().enemy_scene)
	
	dialog.fill_files("enemies")


func update_enemy_scene(path: String) -> void:
	if ResourceLoader.exists(path):
		var current_data = get_data()
		current_data.enemy_scene = path
		%EnemySceneButton.text = path
	else:
		get_data().enemy_scene = ""
		%EnemySceneButton.text = TranslationManager.tr("Select Character Scene")


func _on_icon_picker_remove_requested() -> void:
	get_data().icon.clear()
	%IconPicker.set_icon("")


func _on_icon_picker_clicked() -> void:
	var path = "res://addons/CustomControls/Dialogs/select_icon_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	dialog.set_data(get_data().icon)
	
	dialog.icon_changed.connect(update_icon)


func update_icon() -> void:
	var icon = get_data().icon
	%IconPicker.set_icon(icon.path, icon.region)


func _on_copy_parameters_pressed() -> void:
	var current_data = get_data()
	var parent = get_tree().get_nodes_in_group("main_database")[0]
	var main_panel = parent.get_child(0)
	main_panel.CLIPBOARD.equipment_parameters_list = current_data.params.duplicate()
	%PasteParameters.set_disabled(false)


func _on_paste_parameters_pressed() -> void:
	var current_data = get_data()
	var parent = get_tree().get_nodes_in_group("main_database")[0]
	var main_panel = parent.get_child(0)
	var params = main_panel.CLIPBOARD.get("equipment_parameters_list", null)
	if params:
		%MaxHPSpinBox.value = params[0]
		%AttackSpinBox.value = params[1]
		%MagicAttackSpinBox.value = params[2]
		%AgilitySpinBox.value = params[3]
		%MaxMPSpinBox.value = params[4]
		%DefenseSpinBox.value = params[5]
		%MagicDefenseSpinBox.value = params[6]
		%LuckSpinBox.value = params[7]


func _on_battle_action_list_copy_requested(indexes: PackedInt32Array) -> void:
	var parent = get_tree().get_nodes_in_group("main_database")[0]
	var main_panel = parent.get_child(0)
	var copy_actions: Array[RPGActorBattleAction]
	var actions_list = get_data().battle_actions
	for index in indexes:
		if index > actions_list.size() or index < 0:
			continue
		copy_actions.append(actions_list[index].clone(true))
		
	main_panel.CLIPBOARD["actor_battle_actions"] = copy_actions


func _on_battle_action_list_cut_requested(indexes: PackedInt32Array) -> void:
	var parent = get_tree().get_nodes_in_group("main_database")[0]
	var main_panel = parent.get_child(0)
	var copy_actions: Array[RPGActorBattleAction]
	var remove_actions: Array[RPGActorBattleAction]
	var action_list = get_data().battle_actions
	for index in indexes:
		if index > action_list.size():
			continue
		if action_list.size() > index and index >= 0:
			copy_actions.append(action_list[index].clone(true))
			remove_actions.append(action_list[index])
	for item in remove_actions:
		action_list.erase(item)

	main_panel.CLIPBOARD["actor_battle_actions"] = copy_actions
	
	var item_selected = max(-1, indexes[0])
	fill_battle_actions(item_selected)


func _on_battle_action_list_delete_pressed(indexes: PackedInt32Array) -> void:
	var remove_actions: Array[RPGActorBattleAction] = []
	var action_list = get_data().battle_actions
	for index in indexes:
		if index >= 0 and action_list.size() > index:
			remove_actions.append(action_list[index])
	for obj in remove_actions:
		action_list.erase(obj)
	fill_battle_actions(indexes[0])


func _on_battle_action_list_item_activated(index: int) -> void:
	var path = "res://addons/CustomControls/Dialogs/select_actor_battle_action_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	
	dialog.title = "Enemy Battle Actions"
	
	var actions = get_data().battle_actions
	if actions.size() > index:
		dialog.set_data(actions[index])
		dialog.target_id = index
	else:
		dialog.target_id = -1
	
	dialog.battle_action_updated.connect(_on_battle_action_updated)


func _on_battle_action_list_paste_requested(index: int) -> void:
	var parent = get_tree().get_nodes_in_group("main_database")[0]
	var main_panel = parent.get_child(0)
	
	var action_list = get_data().battle_actions
	var indexes = []
	
	if main_panel.CLIPBOARD.has("actor_battle_actions"):
		for i in main_panel.CLIPBOARD["actor_battle_actions"].size():
			var mat1: RPGActorBattleAction = main_panel.CLIPBOARD["actor_battle_actions"][i].clone()
			var real_index = index + i
			if real_index < action_list.size():
				action_list.insert(real_index, mat1)
				indexes.append(real_index)
			else:
				action_list.append(mat1)
				indexes.append(action_list.size() - 1)
	else:
		return
	
	fill_battle_actions(min(index, action_list.size() - 1))
	
	var list = %BattleActionList
	await list.columns_setted
	await get_tree().process_frame
	await get_tree().process_frame
	list.deselect_all()
	for i in indexes:
		list.select(i, false)


func _on_battle_action_updated(action: RPGActorBattleAction, target_id: int) -> void:
	var actions = get_data().battle_actions
	if target_id != -1:
		actions[target_id] = action
	else:
		actions.append(action)
		target_id = actions.size() - 1
	
	fill_battle_actions(target_id)



func fill_battle_actions(item_selected: int = -1) -> void:
	var node = %BattleActionList
	node.clear()
	var current_data = get_data()
	var actions = current_data.battle_actions
	if !actions:
		var new_actions: Array[RPGActorBattleAction] = []
		current_data.battle_actions = new_actions
		actions = new_actions
	var occasion = [
		"Battle Start", "Battle End", "Battle Amidst", "Attacking",
		"Taking Damage", "Dying", "Before Skill Launch",
		"After Skill Launch", "Ally Receives Healing", "Ally Revives", "Ally Dies"
	]
	var type = ["Play Sound: ", "Run: "]
	var conditions = [
		"Percentage", "Ally Loses HP", "Ally Dies",
		"Enemy Loses HP", "Enemy Dies"
	]
	for i in actions.size():
		var action = actions[i]
		var column = []
		if [6, 7].has(action.occasion):
			if database.skills.size() > action.skill_id:
				var n = database.skills[action.skill_id].name
				if !n:
					n = "Skill ID %s" % action.skill_id
				column.append("%s (%s)" % [occasion[action.occasion], n])
			else:
				column.append("%s (?)" % occasion[action.occasion])
		else:
			column.append(occasion[action.occasion])
		if action.type == 0:
			var event_name = "%s %s" % [type[0], action.fx.filename.get_file()]
			if [2, 3, 4, 6, 7].has(action.occasion):
				event_name += " (condition %s)" % conditions[action.condition]
				
			column.append(event_name)
		else:
			var event_name = ""
			if database.common_events.size() > action.common_event_id:
				var n = database.common_events[action.common_event_id].name
				if !n:
					n = "Common Event %s" % action.common_event_id
				event_name = n
			if [2, 3, 4, 6, 7].has(action.occasion):
				event_name += " (condition %s)" % conditions[action.condition]
				
			column.append("%s %s" % [type[1], event_name])

		column.append("%s%%" % action.condition_rate)
		
		node.add_column(column)
	
	await node.columns_setted
	
	if actions.size() > item_selected and item_selected != -1:
		node.select(item_selected)


func _on_config_data_tabs_tab_changed(index: int) -> void:
	var node_path = "%%Tab%s" % (index + 1)
	var node = get_node_or_null(node_path)
	if node:
		for child in node.get_parent().get_children():
			child.visible = false
		node.visible = true


func _on_icon_picker_paste_requested(icon: String, region: Rect2) -> void:
	var data_icon = get_data().icon
	data_icon.path = icon
	data_icon.region = region
	%IconPicker.set_icon(data_icon.path, data_icon.region)


func _on_battler_picker_paste_requested(icon: String, region: Rect2) -> void:
	if not region:
		get_data().battler = icon
		%BattlerPicker.set_icon(icon)
