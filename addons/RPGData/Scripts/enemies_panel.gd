@tool
extends BasePanelData

#region Variables
#endregion



#region Lifecycle
## Initializes the panel and sets the default data resource
func _ready() -> void:
	super()
	default_data_element = RPGEnemy.new()
#endregion



#region Core Data Loading
## Retrieves the currently selected enemy with index safety
func get_data() -> RPGEnemy:
	current_selected_index = max(1, min(current_selected_index, data.size() - 1))
	return data[current_selected_index]



## Updates all visual fields in the editor based on the selected enemy
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



## Handles visibility changes to refresh traits and sub-lists
func _on_visibility_changed() -> void:
	super()
	if visible:
		busy = true
		if current_selected_index != -1:
			%TraitsPanel.set_data(database, get_data().traits)
			fill_battle_actions()
			fill_drop_list()
			fill_action_list()
		else:
			%TraitsPanel.clear()
		busy = false
#endregion



#region Drop List Management
## Fills the drop item list formatting names and UIDs properly
func fill_drop_list(selected_index: int = -1) -> void:
	var node = %DropList
	node.clear()
	
	var drop_list = get_data().drop_items
	for mat: RPGItemDrop in drop_list:
		var current_data
		var prefix
		var db_key = ""
		
		match mat.item.data_id:
			0: db_key = "items"; current_data = database.items; prefix = "<Item> "
			1: db_key = "weapons"; current_data = database.weapons; prefix = "<Weapon> "
			2: db_key = "armors"; current_data = database.armors; prefix = "<Armor> "
			3: db_key = "costumes"; current_data = database.costumes; prefix = "<🎭 Set / Costume> "
		
		var uid = mat.item.item_id
		if uid > 0 and uid < 1000000:
			uid = RPGSYSTEM.id_to_uid(db_key, uid)
			mat.item.item_id = uid
			
		var res_data = RPGSYSTEM.get_data(db_key, uid)
		
		if res_data:
			var classic_id = RPGSYSTEM.uid_to_id(db_key, uid)
			var id_p = str(classic_id).pad_zeros(str(current_data.size()).length())
			var item_name = id_p + ": " + res_data.name
			var quantity: String
			
			if mat.quantity != mat.quantity2:
				quantity = str(mat.quantity) + " ~ " + str(mat.quantity2)
			else:
				quantity = str(mat.quantity)
				
			var percent = "%.2f %%" % mat.percent
			node.add_column([prefix + item_name, quantity, percent])
		else:
			var quantity = str(mat.quantity)
			if mat.quantity != mat.quantity2:
				quantity = str(mat.quantity) + " ~ " + str(mat.quantity2)
			node.add_column([prefix + "⚠ Invalid Data", quantity, "%.2f %%" % mat.percent])
	
	if selected_index >= 0:
		await node.columns_setted
		node.select(selected_index)



## Opens the dialog to edit or create a drop item
func _on_drop_list_item_activated(index: int) -> void:
	var drop_list = get_data().drop_items
	if drop_list.size() > 0 and drop_list.size() > index:
		show_select_required_item_dialog(drop_list[index], index)
	else:
		show_select_required_item_dialog()



## Configures and opens the drop item sub-dialog
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



## Handles new drop item creation and prevents duplicates
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



## Updates an existing drop item and cleans up potential duplicates
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
#endregion



#region Drop List Signals (Clipboard)
## Deletes selected drop items from the list
func _on_drop_list_delete_pressed(indexes: PackedInt32Array) -> void:
	var remove_drops: Array[RPGItemDrop] = []
	var drop_list = get_data().drop_items
	for index in indexes:
		if index >= 0 and drop_list.size() > index:
			remove_drops.append(drop_list[index])
	for obj in remove_drops:
		drop_list.erase(obj)
	fill_drop_list(indexes[0])



## Copies selected drop items to the global clipboard
func _on_drop_list_copy_requested(indexes: PackedInt32Array) -> void:
	var copy_drops: Array[RPGItemDrop]
	var drop_list = get_data().drop_items
	for index in indexes:
		if index >= drop_list.size() or index < 0:
			continue
		copy_drops.append(drop_list[index].clone(true))
		
	StaticEditorVars.CLIPBOARD["enemy_drop_list"] = copy_drops



## Cuts selected drop items to the global clipboard
func _on_drop_list_cut_requested(indexes: PackedInt32Array) -> void:
	var copy_drops: Array[RPGItemDrop]
	var remove_drops: Array[RPGItemDrop]
	var drop_list = get_data().drop_items
	for index in indexes:
		if index >= drop_list.size():
			continue
		if drop_list.size() > index and index >= 0:
			copy_drops.append(drop_list[index].clone(true))
			remove_drops.append(drop_list[index])
	for item in remove_drops:
		drop_list.erase(item)

	StaticEditorVars.CLIPBOARD["enemy_drop_list"] = copy_drops
	
	var item_selected = max(-1, indexes[0])
	fill_drop_list(item_selected)



## Pastes drop items from the clipboard handling duplicates
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



#region AI Pattern Management
## Populates the enemy action pattern list with UIDs and formatted conditions
func fill_action_list(selected_index: int = -1) -> void:
	var node = %PatternList
	node.clear()
	
	var action_list = get_data().action_patterns
	for at: RPGEnemyAction in action_list:
		var left_column: String
		var mid_column: String
		var right_column: String
		
		match at.condition_type:
			0: mid_column = tr("Always")
			1: mid_column = tr("Turn %s + %s*X") % [at.condition_param1, at.condition_param2]
			2: mid_column = tr("HP %s%% ~ %s%%") % [at.condition_param1, at.condition_param2]
			3: mid_column = tr("MP %s%% ~ %s%%") % [at.condition_param1, at.condition_param2]
			4:
				var state_uid = at.condition_param1
				if state_uid > 0 and state_uid < 1000000:
					state_uid = RPGSYSTEM.id_to_uid("states", state_uid)
					at.condition_param1 = state_uid
				
				var state_data = RPGSYSTEM.get_data("states", state_uid)
				if state_data:
					var cid = RPGSYSTEM.uid_to_id("states", state_uid)
					mid_column = tr("State < %s: %s >") % [str(cid).pad_zeros(3), state_data.name]
				else:
					mid_column = tr("State ⚠ Invalid Data")
			5:
				var operation = ["=", "<", "<=", ">", ">=", "!="][at.condition_param1]
				mid_column = tr("Party Level %s %s") % [operation, at.condition_param2]
			6:
				var switch_name = RPGSYSTEM.system.switches.get_item_name(at.condition_param1)
				mid_column = tr("Switch < %s: %s > is %s") % [str(at.condition_param1).pad_zeros(4), switch_name, tr("enabled") if at.condition_param2 == 0 else tr("disabled")]
			7:
				var var_name = RPGSYSTEM.system.variables.get_item_name(at.condition_param1)
				var operation = ["=", "<", "<=", ">", ">=", "!="][at.condition_param2]
				mid_column = tr("Variable < %s: %s > %s %s") % [str(at.condition_param1).pad_zeros(4), var_name, operation, at.condition_param3]
		
		var skill_uid = at.skill_id
		if skill_uid > 0 and skill_uid < 1000000:
			skill_uid = RPGSYSTEM.id_to_uid("skills", skill_uid)
			at.skill_id = skill_uid
			
		var skill_data = RPGSYSTEM.get_data("skills", skill_uid)
		if skill_data:
			var cid = RPGSYSTEM.uid_to_id("skills", skill_uid)
			left_column = "< %s: %s >" % [str(cid).pad_zeros(3), skill_data.name]
		else:
			left_column = "⚠ Invalid Data"
		
		right_column = str(at.rating)
		node.add_column([left_column, mid_column, right_column])
	
	if selected_index >= 0:
		await node.columns_setted
		node.select(selected_index)



## Opens the pattern action editor dialog
func _on_pattern_list_item_activated(index: int) -> void:
	var action_pattern_list = get_data().action_patterns
	if action_pattern_list.size() > 0 and action_pattern_list.size() > index:
		show_select_enemy_action_dialog(action_pattern_list[index], index)
	else:
		show_select_enemy_action_dialog()



## Launches the enemy action pattern sub-dialog
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



## Handles new action pattern creation
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



## Updates existing action patterns and cleans duplicates
func _on_enemy_action_updated(action: RPGEnemyAction, index: int) -> void:
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
#endregion



#region AI Pattern Signals (Clipboard)
## Deletes selected action patterns
func _on_pattern_list_delete_pressed(indexes: PackedInt32Array) -> void:
	var remove_actions: Array[RPGEnemyAction] = []
	var action_list = get_data().action_patterns
	for index in indexes:
		if index >= 0 and action_list.size() > index:
			remove_actions.append(action_list[index])
	for obj in remove_actions:
		action_list.erase(obj)
	fill_action_list(indexes[0])



## Copies selected action patterns to local panel clipboard
func _on_pattern_list_copy_requested(indexes: PackedInt32Array) -> void:
	var main_panel = get_tree().get_nodes_in_group("main_database")[0].get_child(0)
	var copy_actions: Array[RPGEnemyAction]
	var action_list = get_data().action_patterns
	for index in indexes:
		if index >= action_list.size() or index < 0:
			continue
		copy_actions.append(action_list[index].clone(true))
		
	main_panel.CLIPBOARD["enemy_actions"] = copy_actions



## Cuts selected action patterns to local panel clipboard
func _on_pattern_list_cut_requested(indexes: PackedInt32Array) -> void:
	var main_panel = get_tree().get_nodes_in_group("main_database")[0].get_child(0)
	var copy_actions: Array[RPGEnemyAction]
	var remove_actions: Array[RPGEnemyAction]
	var action_list = get_data().action_patterns
	for index in indexes:
		if index >= action_list.size():
			continue
		if action_list.size() > index and index >= 0:
			copy_actions.append(action_list[index].clone(true))
			remove_actions.append(action_list[index])
	for item in remove_actions:
		action_list.erase(item)

	main_panel.CLIPBOARD["enemy_actions"] = copy_actions
	fill_action_list(max(-1, indexes[0]))



## Pastes action patterns from clipboard preventing duplicates
func _on_pattern_list_paste_requested(index: int) -> void:
	var main_panel = get_tree().get_nodes_in_group("main_database")[0].get_child(0)
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
	
	fill_action_list(min(index, action_list.size() - 1))
	
	var list = %PatternList
	await list.columns_setted
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



#region Battle Actions Management
## Fills the battle actions list formatting triggers and common event UIDs
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
			var skill_uid = action.skill_id
			if skill_uid > 0 and skill_uid < 1000000:
				skill_uid = RPGSYSTEM.id_to_uid("skills", skill_uid)
				action.skill_id = skill_uid
			
			var sk_data = RPGSYSTEM.get_data("skills", skill_uid)
			if sk_data:
				column.append("%s (%s)" % [occasion[action.occasion], sk_data.name])
			else:
				column.append("%s (Skill %s)" % [occasion[action.occasion], skill_uid])
		else:
			column.append(occasion[action.occasion])
			
		if action.type == 0:
			var event_name = "%s %s" % [type[0], action.fx.filename.get_file()]
			if [2, 3, 4, 6, 7].has(action.occasion):
				event_name += " (condition %s)" % conditions[action.condition]
			column.append(event_name)
		else:
			var event_name = ""
			var ce_uid = action.common_event_id
			if ce_uid > 0 and ce_uid < 1000000:
				ce_uid = RPGSYSTEM.id_to_uid("common_events", ce_uid)
				action.common_event_id = ce_uid
				
			var ce_data = RPGSYSTEM.get_data("common_events", ce_uid)
			if ce_data:
				event_name = ce_data.name
			else:
				event_name = "Common Event %s" % ce_uid
				
			if [2, 3, 4, 6, 7].has(action.occasion):
				event_name += " (condition %s)" % conditions[action.condition]
			column.append("%s %s" % [type[1], event_name])

		column.append("%s%%" % action.condition_rate)
		node.add_column(column)
	
	await node.columns_setted
	if actions.size() > item_selected and item_selected != -1:
		node.select(item_selected)



## Opens the dialog to edit battle actions
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



## Receives data from the battle action sub-dialog
func _on_battle_action_updated(action: RPGActorBattleAction, target_id: int) -> void:
	var actions = get_data().battle_actions
	if target_id != -1:
		actions[target_id] = action
	else:
		actions.append(action)
		target_id = actions.size() - 1
	
	fill_battle_actions(target_id)
#endregion



#region Battle Action Signals (Clipboard)
## Deletes selected battle actions
func _on_battle_action_list_delete_pressed(indexes: PackedInt32Array) -> void:
	var remove_actions: Array[RPGActorBattleAction] = []
	var action_list = get_data().battle_actions
	for index in indexes:
		if index >= 0 and action_list.size() > index:
			remove_actions.append(action_list[index])
	for obj in remove_actions:
		action_list.erase(obj)
	fill_battle_actions(indexes[0])



## Copies battle actions to panel clipboard
func _on_battle_action_list_copy_requested(indexes: PackedInt32Array) -> void:
	var main_panel = get_tree().get_nodes_in_group("main_database")[0].get_child(0)
	var copy_actions: Array[RPGActorBattleAction]
	var actions_list = get_data().battle_actions
	for index in indexes:
		if index >= actions_list.size() or index < 0:
			continue
		copy_actions.append(actions_list[index].clone(true))
		
	main_panel.CLIPBOARD["actor_battle_actions"] = copy_actions



## Cuts battle actions to panel clipboard
func _on_battle_action_list_cut_requested(indexes: PackedInt32Array) -> void:
	var main_panel = get_tree().get_nodes_in_group("main_database")[0].get_child(0)
	var copy_actions: Array[RPGActorBattleAction]
	var remove_actions: Array[RPGActorBattleAction]
	var action_list = get_data().battle_actions
	for index in indexes:
		if index >= action_list.size():
			continue
		if action_list.size() > index and index >= 0:
			copy_actions.append(action_list[index].clone(true))
			remove_actions.append(action_list[index])
	for item in remove_actions:
		action_list.erase(item)

	main_panel.CLIPBOARD["actor_battle_actions"] = copy_actions
	fill_battle_actions(max(-1, indexes[0]))



## Pastes battle actions from clipboard
func _on_battle_action_list_paste_requested(index: int) -> void:
	var main_panel = get_tree().get_nodes_in_group("main_database")[0].get_child(0)
	var action_list = get_data().battle_actions
	var pasted_indexes = []
	
	if main_panel.CLIPBOARD.has("actor_battle_actions"):
		for i in main_panel.CLIPBOARD["actor_battle_actions"].size():
			var mat1: RPGActorBattleAction = main_panel.CLIPBOARD["actor_battle_actions"][i].clone()
			var real_index = index + i
			if real_index < action_list.size():
				action_list.insert(real_index, mat1)
				pasted_indexes.append(real_index)
			else:
				action_list.append(mat1)
				pasted_indexes.append(action_list.size() - 1)
	else:
		return
	
	fill_battle_actions(min(index, action_list.size() - 1))
	
	var list = %BattleActionList
	await list.columns_setted
	await get_tree().process_frame
	list.deselect_all()
	for i in pasted_indexes:
		list.select(i, false)
#endregion



#region Scene and Resource Selection
## Opens file selection dialog for enemy battler images
func _on_battler_picker_clicked() -> void:
	var parent = get_tree().get_nodes_in_group("main_database")[0]
	var dialog
	var main_panel = parent.get_child(0)
	var path = "res://addons/CustomControls/Dialogs/select_file_dialog.tscn"
	
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



## Updates the battler path in the data
func update_battler(path: String) -> void:
	%BattlerPicker.set_icon(path)
	get_data().battler = path



## Clears the battler image
func _on_battler_picker_remove_requested() -> void:
	get_data().battler = ""
	%BattlerPicker.set_icon("")



## Resets enemy combat scene to default
func _on_enemy_scene_button_middle_click_pressed() -> void:
	get_data().enemy_scene = ""
	%EnemySceneButton.text = TranslationManager.tr("Select Enemy Scene")



## Opens file dialog to select the enemy battle scene
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



## Updates enemy scene path and button text
func update_enemy_scene(path: String) -> void:
	if ResourceLoader.exists(path):
		var current_data = get_data()
		current_data.enemy_scene = path
		%EnemySceneButton.text = path
	else:
		get_data().enemy_scene = ""
		%EnemySceneButton.text = TranslationManager.tr("Select Character Scene")



## Clears enemy icon
func _on_icon_picker_remove_requested() -> void:
	get_data().icon.clear()
	%IconPicker.set_icon("")



## Opens icon picker dialog
func _on_icon_picker_clicked() -> void:
	var path = "res://addons/CustomControls/Dialogs/select_icon_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	dialog.set_data(get_data().icon)
	dialog.icon_changed.connect(update_icon)



## Updates icon preview
func update_icon() -> void:
	var icon = get_data().icon
	%IconPicker.set_icon(icon.path, icon.region)
#endregion



#region UI Event Handlers
## Synchronizes gold range when minimum reward changes
func _on_gold_spin_box_1_value_changed(value: float) -> void:
	if busy: return
	busy = true
	%GoldSpinBox2.value = max(value, %GoldSpinBox2.value)
	get_data().gold_reward_from = %GoldSpinBox1.value
	get_data().gold_reward_to = %GoldSpinBox2.value
	busy = false



## Synchronizes gold range when maximum reward changes
func _on_gold_spin_box_2_value_changed(value: float) -> void:
	if busy: return
	busy = true
	%GoldSpinBox1.value = min(value, %GoldSpinBox1.value)
	get_data().gold_reward_from = %GoldSpinBox1.value
	get_data().gold_reward_to = %GoldSpinBox2.value
	busy = false



## Updates experience reward
func _on_experience_spin_box_value_changed(value: float) -> void:
	get_data().experience_reward = value



## Updates notes
func _on_note_text_edit_text_changed() -> void:
	get_data().notes = %NoteTextEdit.text



## Updates description
func _on_description_text_edit_text_changed() -> void:
	get_data().description = %DescriptionTextEdit.text



## Updates specific enemy parameter
func update_enemy_param(value: float, param_id: int) -> void:
	get_data().params[param_id] = value



## Handles tab visibility switching
func _on_config_data_tabs_tab_changed(index: int) -> void:
	var node_path = "%%Tab%s" % (index + 1)
	var node = get_node_or_null(node_path)
	if node:
		for child in node.get_parent().get_children():
			child.visible = false
		node.visible = true



## Pastes icon from clipboard
func _on_icon_picker_paste_requested(icon: String, region: Rect2) -> void:
	var data_icon = get_data().icon
	data_icon.path = icon
	data_icon.region = region
	%IconPicker.set_icon(data_icon.path, data_icon.region)



## Pastes battler image from clipboard
func _on_battler_picker_paste_requested(icon: String, region: Rect2) -> void:
	if not region:
		get_data().battler = icon
		%BattlerPicker.set_icon(icon)
#endregion



#region Global Clipboard
## Copies base parameters to the local panel clipboard
func _on_copy_parameters_pressed() -> void:
	var main_panel = get_tree().get_nodes_in_group("main_database")[0].get_child(0)
	main_panel.CLIPBOARD.equipment_parameters_list = get_data().params.duplicate()
	%PasteParameters.set_disabled(false)



## Pastes base parameters from the local panel clipboard
func _on_paste_parameters_pressed() -> void:
	var main_panel = get_tree().get_nodes_in_group("main_database")[0].get_child(0)
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
#endregion
