@tool
extends BasePanelData


func _ready() -> void:
	super()
	default_data_element = RPGActor.new()


func get_data() -> RPGActor:
	current_selected_index = max(1, min(current_selected_index, data.size() - 1))
	return data[current_selected_index]


func _update_data_fields() -> void:
	busy = true
	
	var current_data = get_data()
	if current_selected_index != -1:
		disable_all(false)
		%NameLineEdit.text = current_data.name
		%NicknameLineEdit.text = current_data.nickname
		fill_classes()
		set_class(current_data.class_id - 1)
		%ProfileTextEdit.text = current_data.profile
		fill_equipment_list()
		fill_battle_actions()
		%TraitsPanel.set_data(database, current_data.traits)
		%NoteTextEdit.text = current_data.notes
		if current_data.character_scene.length() > 0:
			%CharacterSceneButton.text = current_data.character_scene
		else:
			%CharacterSceneButton.text = TranslationManager.tr("Select Character Scene")
		%FacePicker.set_icon(current_data.face_preview.path, current_data.face_preview.region)
		%CharacterPicker.set_icon(current_data.character_preview)
		%BattlerPicker.set_icon(current_data.battler_preview)
		%IconPicker.set_icon(current_data.icon.path, current_data.icon.region)
		%PoseVerticalOffset.value = current_data.pose_vertical_offset
	else:
		disable_all(true)
	
	busy = false


func get_equippable_weapons() -> Array:
	var obj: Array
	var result: Array
	# get valid types
	var current_data = get_data()
	obj = current_data.traits.filter(func(t: RPGTrait): return t.code == 17)
	if database.classes.size() > current_data.class_id:
		var current_class: RPGClass = database.classes[current_data.class_id]
		obj += current_class.traits.filter(func(t: RPGTrait): return t.code == 17)
	
	var valid_types: Array = obj.map(func(t: RPGTrait): return t.data_id - 1)
	
	# get valid  armors
	obj = database.weapons.filter(
		func(weapon: RPGWeapon):
			if weapon:
				if -1 in valid_types or weapon.weapon_type in valid_types or weapon.weapon_type == 0:
					return true
			return false
	)

	# get valid weapons id
	if obj.size() > 0:
		result = obj.map(func(weapon: RPGWeapon): return weapon.id)

	return result


func get_equippable_equipment(slot_id: int) -> Array:
	var obj: Array
	var result: Array
	# get valid types
	var current_data = get_data()
	obj = current_data.traits.filter(func(t: RPGTrait): return t.code == 18)
	if database.classes.size() > current_data.class_id:
		var current_class: RPGClass = database.classes[current_data.class_id]
		obj += current_class.traits.filter(func(t: RPGTrait): return t.code == 18)
	
	var valid_types: Array = obj.map(func(t: RPGTrait): return t.data_id - 1)
	
	# get valid  armors
	obj = database.armors.filter(
		func(armor: RPGArmor):
			if armor and (armor.equipment_type == 0 or armor.equipment_type == slot_id):
				if -1 in valid_types or armor.armor_type in valid_types or armor.armor_type == 0:
					return true
			return false
	)

	# get valid armors id
	if obj.size() > 0:
		result = obj.map(func(armor: RPGArmor): return armor.id)

	return result


func fill_equipment_list() -> void:
	var node = %EquipmentList
	node.clear()
	
	var equipment = get_data().equipment
	var equipment_level = get_data().equipment_level
	equipment_level.resize(equipment.size())
	for i in equipment_level.size():
		if equipment_level[i]  <= 0:
			equipment_level[i] = 1
	var equippable_weapons = get_equippable_weapons()

	for i in database.types.equipment_types.size():
		var column = []
		column.append(database.types.equipment_types[i])
		var none = tr("none")
		var equipment_name = none
		if equipment.size() > i:
			var selected_id = equipment[i]
			if selected_id != -1:
				if i == 0: # Weapon
					if database.weapons.size() > selected_id and selected_id > 0:
						var weapon_type = database.weapons[selected_id].weapon_type - 1
						if weapon_type >= 0 and weapon_type in equippable_weapons or -1 in equippable_weapons:
							equipment_name = database.weapons[selected_id].name
							if equipment_name.length() == 0:
								equipment_name = "# %s" % selected_id
					elif selected_id > 0:
						equipment_name = "⚠ Invalid Item"
				else: # Armor
					var equippable_equipment = get_equippable_equipment(i)
					if not selected_id in equippable_equipment:
						equipment_name = "⚠ Invalid Item"
					else:
						if database.armors.size() > selected_id and selected_id > 0:
							equipment_name = database.armors[selected_id].name
							if equipment_name.length() == 0:
								equipment_name = "# %s" % selected_id
						elif selected_id > 0:
							equipment_name = "⚠ Invalid Item"

		column.append(equipment_name)
		if equipment_name != none:
			column.append(str(equipment_level[i]))
		else:
			column.append("-")
		node.add_column(column)


func fill_battle_actions(item_selected: int = -1) -> void:
	var node = %BattleActionList
	node.clear()
	var actions = get_data().battle_actions
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



func fill_classes() -> void:
	var node: OptionButton = %ClassOptions
	node.clear()
	
	for i in range(1, database.classes.size(), 1):
		var c = database.classes[i]
		var id = str(i).pad_zeros(str(database.classes.size()-1).length())
		var data_name = id + ": " + c.name
		node.add_item(data_name)


func set_class(selected_index: int) -> void:
	var node: OptionButton = %ClassOptions
	if node.get_item_count() > selected_index:
		var current_data = get_data()
		node.select(selected_index)
		node.item_selected.emit(selected_index)
		var class_data = database.classes[selected_index + 1]
		%InitialLevelSpinBox.max_value = class_data.max_level
		%InitialLevelSpinBox.min_value = 1
		%MaxLevelSpinBox.max_value = class_data.max_level
		%MaxLevelSpinBox.min_value = 1
		%InitialLevelSpinBox.value = current_data.initial_level
		%MaxLevelSpinBox.value = current_data.max_level
	else:
		node.select(-1)
		node.text = "⚠ Invalid Data"
		%InitialLevelSpinBox.set_disabled(true)
		%MaxLevelSpinBox.set_disabled(true)
		%InitialLevelSpinBox.value = %InitialLevelSpinBox.min_value
		%MaxLevelSpinBox.value = %MaxLevelSpinBox.max_value


func _on_visibility_changed() -> void:
	super()
	if visible:
		if current_selected_index != -1:
			busy = true
			var current_data = get_data()
			%TraitsPanel.set_data(database, current_data.traits)
			fill_equipment_list()
			fill_classes()
			fill_battle_actions()
			set_class(current_data.class_id - 1)
			busy = false
		else:
			%TraitsPanel.clear()
			%EquipmentList.clear()


func _on_nickname_line_edit_text_changed(new_text: String) -> void:
	get_data().nickname = new_text 


func _on_profile_text_edit_text_changed() -> void:
	get_data().profile = %ProfileTextEdit.text


func _on_initial_level_spin_box_value_changed(value: float) -> void:
	if busy: return
	var new_value = min(value, %MaxLevelSpinBox.value)
	get_data().initial_level = new_value
	if new_value != value:
		%InitialLevelSpinBox.value = new_value


func _on_max_level_spin_box_value_changed(value: float) -> void:
	if busy: return
	var new_value = max(value, %InitialLevelSpinBox.value)
	get_data().max_level = new_value
	if new_value != value:
		%MaxLevelSpinBox.value = new_value


func _on_class_options_item_selected(index: int) -> void:
	var real_index = index + 1
	get_data().class_id = real_index
	%InitialLevelSpinBox.set_disabled(false)
	if database.classes.size() > real_index:
		%InitialLevelSpinBox.max_value = database.classes[real_index].max_level
		%MaxLevelSpinBox.max_value = database.classes[real_index].max_level
	%MaxLevelSpinBox.set_disabled(false)


func _on_note_text_edit_text_changed() -> void:
	get_data().notes = %NoteTextEdit.text


func _on_equipment_list_item_activated(index: int) -> void:
	var path = "res://addons/CustomControls/Dialogs/Select_one_data_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	
	var list = ["none"]
	var real_ids = [-1]
	var title = database.types.equipment_types[index]
	var selected_id = 0
	var current_data: Variant
	
	if index == 0:
		current_data = database.weapons
		var equippable_weapons = get_equippable_weapons()
		for i in equippable_weapons.size():
			var weapon: RPGWeapon = current_data[equippable_weapons[i]]
			var current_name = weapon.name
			if current_name.length() == 0:
				current_name = "Weapon ID = %s" % weapon.id
			list.append(current_name)
			real_ids.append(weapon.id)
	else:
		current_data = database.armors
		var equippable_armors = get_equippable_equipment(index)
		for i in equippable_armors.size():
			var armor: RPGArmor = current_data[equippable_armors[i]]
			var current_name = armor.name
			if current_name.length() == 0:
				current_name = "Armor ID = %s" % armor.id
			list.append(current_name)
			real_ids.append(armor.id)
	
	
	var equipment = get_data().equipment
	if equipment.size() > index:
		selected_id = equipment[index]
	
	var equipment_level = get_data().equipment_level
	equipment_level.resize(get_data().equipment.size())
	for i in equipment_level.size():
		if equipment_level[i] <= 0: equipment_level[i] = 1
	dialog.data = current_data

	dialog.set_data(title, list, real_ids, selected_id, get_data().equipment_level[index], _on_equipment_selected.bind(index))


func _on_equipment_selected(item_id: int, item_level: int, data_id: int) -> void:
	var equipment = get_data().equipment
	var equipment_level = get_data().equipment_level
	if equipment.size() <= data_id:
		equipment.resize(data_id + 1)
	if equipment_level.size() <= data_id:
		equipment_level.resize(data_id + 1)
		for i in equipment_level.size():
			if equipment_level[i] <= 0: equipment_level[i] = 1
	equipment[data_id] = item_id
	equipment_level[data_id] = item_level
	
	var node = %EquipmentList
	var items_selected = node.get_selected_items()
	fill_equipment_list()
	await node.columns_setted
	for item in items_selected:
		node.select(item, false)


func _on_character_scene_button_middle_click_pressed() -> void:
	get_data().character_scene = ""
	%CharacterSceneButton.text = TranslationManager.tr("Select Character Scene")
	


func _on_character_scene_button_pressed() -> void:
	var dialog = await open_file_dialog()

	dialog.target_callable = update_character_scene
	dialog.set_file_selected(get_data().character_data_file)
	
	dialog.fill_files("characters")


func update_character_scene(path: String) -> void:
	if ResourceLoader.exists(path):
		var res: RPGLPCCharacter = load(path)
		var current_data = get_data()
		current_data.character_data_file = path
		current_data.character_scene = res.scene_path
		current_data.face_preview.path = res.face_preview
		current_data.character_preview = res.character_preview
		current_data.battler_preview = res.battler_preview
		%CharacterSceneButton.text = current_data.character_scene
		%FacePicker.set_icon(current_data.face_preview.path, current_data.face_preview.region)
		%CharacterPicker.set_icon(current_data.character_preview)
		%BattlerPicker.set_icon(current_data.battler_preview)
	else:
		get_data().character_scene = ""
		%CharacterSceneButton.text = TranslationManager.tr("Select Character Scene")


func open_file_dialog() -> Window:
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
	
	return dialog


func open_image_dialog(target_callable: Callable, default_path: String = "") -> void:
	var dialog = await open_file_dialog()
	
	dialog.target_callable = target_callable
	dialog.set_file_selected(default_path)
	
	dialog.fill_files("images")


func _on_face_picker_clicked() -> void:
	var path = "res://addons/CustomControls/Dialogs/select_icon_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	dialog.set_data(get_data().face_preview)
	
	dialog.icon_changed.connect(update_face)


func _on_face_picker_remove_requested() -> void:
	get_data().face_preview.clear()
	%FacePicker.set_icon("")



func _on_character_picker_clicked() -> void:
	open_image_dialog(update_character_preview, get_data().character_preview)


func _on_character_picker_remove_requested() -> void:
	get_data().character_preview = ""
	%CharacterPicker.set_icon("")


func update_character_preview(path: String) -> void:
	get_data().character_preview = path
	%CharacterPicker.set_icon(path)


func _on_battler_picker_clicked() -> void:
	open_image_dialog(update_battler_preview, get_data().battler_preview)


func _on_battler_picker_remove_requested() -> void:
	get_data().battler_preview = ""
	%BattlerPicker.set_icon("")


func update_battler_preview(path: String) -> void:
	get_data().battler_preview = path
	%BattlerPicker.set_icon(path)


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


func update_face() -> void:
	var face = get_data().face_preview
	%FacePicker.set_icon(face.path, face.region)


func _on_battle_action_list_item_activated(index: int) -> void:
	var path = "res://addons/CustomControls/Dialogs/select_actor_battle_action_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	
	var actions = get_data().battle_actions
	if actions.size() > index:
		dialog.set_data(actions[index])
		dialog.target_id = index
	else:
		dialog.target_id = -1
	
	dialog.battle_action_updated.connect(_on_battle_action_updated)


func _on_battle_action_updated(action: RPGActorBattleAction, target_id: int) -> void:
	var actions = get_data().battle_actions
	if target_id != -1:
		actions[target_id] = action
	else:
		actions.append(action)
		target_id = actions.size() - 1
	
	fill_battle_actions(target_id)


func _on_battle_action_list_copy_requested(indexes: PackedInt32Array) -> void:
	var copy_actions: Array[RPGActorBattleAction]
	var actions_list = get_data().battle_actions
	for index in indexes:
		if index > actions_list.size() or index < 0:
			continue
		copy_actions.append(actions_list[index].clone(true))
		
	StaticEditorVars.CLIPBOARD["actor_battle_actions"] = copy_actions


func _on_battle_action_list_cut_requested(indexes: PackedInt32Array) -> void:
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

	StaticEditorVars.CLIPBOARD["actor_battle_actions"] = copy_actions
	
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


func _on_battle_action_list_paste_requested(index: int) -> void:
	var action_list = get_data().battle_actions
	var indexes = []
	
	if StaticEditorVars.CLIPBOARD.has("actor_battle_actions"):
		for i in StaticEditorVars.CLIPBOARD["actor_battle_actions"].size():
			var mat1: RPGActorBattleAction = StaticEditorVars.CLIPBOARD["actor_battle_actions"][i].clone()
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


func _on_config_data_tabs_tab_changed(index: int) -> void:
	var node_path = "%%Tab%s" % (index + 1)
	var node = get_node_or_null(node_path)
	if node:
		for child in node.get_parent().get_children():
			child.visible = false
		node.visible = true


func _on_tick_interval_value_changed(value: float) -> void:
	get_data().tick_interval = value


func _on_face_picker_paste_requested(icon: String, region: Rect2) -> void:
	var data_icon = get_data().face_preview
	data_icon.path = icon
	data_icon.region = region
	%FacePicker.set_icon(data_icon.path, data_icon.region)


func _on_character_picker_paste_requested(icon: String, region: Rect2) -> void:
	if not region:
		get_data().character_preview = icon
		%CharacterPicker.set_icon(icon)


func _on_battler_picker_paste_requested(icon: String, region: Rect2) -> void:
	if not region:
		get_data().battler_preview = icon
		%BattlerPicker.set_icon(icon)


func _on_icon_picker_paste_requested(icon: String, region: Rect2) -> void:
	var data_icon = get_data().icon
	data_icon.path = icon
	data_icon.region = region
	%IconPicker.set_icon(data_icon.path, data_icon.region)


func _on_custom_spin_box_value_changed(value: float) -> void:
	get_data().pose_vertical_offset = value
