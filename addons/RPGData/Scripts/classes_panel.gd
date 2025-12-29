@tool
extends BasePanelData

var parameters_cache: Array[Dictionary]
var params_need_resize: float


func _ready() -> void:
	super()
	default_data_element = RPGClass.new()


func get_data() -> RPGClass:
	current_selected_index = max(1, min(current_selected_index, data.size() - 1))
	return data[current_selected_index]


func _process(delta: float) -> void:
	if params_need_resize > 0.0:
		params_need_resize -= delta
		if params_need_resize <= 0.0:
			params_need_resize = 0.0
			resize_params()


func _update_data_fields() -> void:
	busy = true
	await get_tree().process_frame # Wait 1 frame to void bug (reset class 1 to max level 1)
	if current_selected_index != -1:
		var current_data = get_data()
		disable_all(false)
		%NameLineEdit.text = current_data.name
		%TraitsPanel.set_data(database, current_data.traits)
		fill_params()
		%MaxLevelSpinBox.value = current_data.max_level
		%NoteTextEdit.text = current_data.notes
		%DescriptionText.text = current_data.description
		%AutomaticUpgrade.set_pressed(current_data.automatic_upgrade)
		%IconPicker.set_icon(current_data.icon.path, current_data.icon.region)
		fill_class_list(current_data.upgrade_to_class)
		fill_learnable_list()
		%PasteParameters.set_disabled(!StaticEditorVars.CLIPBOARD.get("class_parameters", false))
		fill_weights()
	else:
		disable_all(true)
	
	busy = false


func fill_weights() -> void:
	var current_data = get_data()
	%HPWeight.value = current_data.weights.get("HP", 1.5)
	%MPWeight.value = current_data.weights.get("MP", 1.0)
	%AttackWeight.value = current_data.weights.get("ATK", 2.0)
	%DefenseWeight.value = current_data.weights.get("DEF", 1.8)
	%MagicAttackWeight.value = current_data.weights.get("MATK", 1.5)
	%MagicDefenseWeight.value = current_data.weights.get("MDEF", 1.2)
	%AgilityWeight.value = current_data.weights.get("AGI", 1.3)
	%LuckWeight.value = current_data.weights.get("LUCK", 1.8)
	%PasteWeights.set_disabled(!StaticEditorVars.CLIPBOARD.get("class_weights", false))


func fill_learnable_list(selected_index: int = -1) -> void:
	var node = %LearnableSkillList
	node.clear()
	var current_data = get_data()
	for i in current_data.learnable_skills.size():
		var item: RPGLearnableSkill = current_data.learnable_skills[i]
		var column = []
		column.append(str(item.level))
		if database.skills.size() > item.skill_id:
			var item_name = database.skills[item.skill_id].name
			if item_name.length() == 0:
				item_name = "# %s" % item.skill_id
			column.append(item_name)
		else:
			column.append("⚠ Invalid Data")
		column.append(item.notes)
		node.add_column(column)
	
	if selected_index != -1 and current_data.learnable_skills.size() > 0 and current_data.learnable_skills.size() > selected_index:
		await node.columns_setted
		node.select(selected_index)


func fill_class_list(selected_index: int = -1) -> void:
	var node = %UpgradeToClass
	
	node.clear()
	node.add_item("None")
	for i in range(1, database.classes.size(), 1):
		var n = database.classes[i].name
		if !n:
			n = "Class %s" % i
		node.add_item(n)
	
	if selected_index != -1 and database.classes.size() > 0 and database.classes.size() > selected_index:
		node.select(selected_index)
	elif selected_index != -1:
		node.select(-1)
		node.text = "⚠ Invalid Data"
	
	var class_id = database.classes.find(get_data())
	node.set_item_disabled(class_id, true)


func fill_params() -> void:
	parameters_cache.clear()
	var current_data = get_data()
	var experience_data = {
		"min_value" : current_data.experience.min_value,
		"max_value" : current_data.experience.max_value,
		"initial_level" : 2,
		"background_color": Color("#000000e0"),
		"foreground_color": current_data.experience.background_color,
		"data": current_data.experience.data
	}
	%Experience.set_data(current_data.experience.data, experience_data)
	parameters_cache.append(experience_data)
	var parameters = [%MaxHp, %MaxMp, %Attack, %Defense, %MagicAttack, %MagicDefense, %Agility, %Luck]
	for i in parameters.size():
		var parameter_data = {
			"min_value" : current_data.params[i].min_value,
			"max_value" : current_data.params[i].max_value,
			"initial_level" : 1,
			"background_color": Color("#000000e0"),
			"foreground_color": current_data.params[i].background_color,
			"data": current_data.params[i].data
		}
		parameters[i].set_data(current_data.params[i].data, parameter_data)
		parameters_cache.append(parameter_data)


func resize_params() -> void:
	var current_data = get_data()
	var value = current_data.max_level + 1
	if current_data.experience.data.size() != value:
		var index1 = current_data.experience.data.size()
		var index2 = value
		current_data.experience.data.resize(value)
		if index2 > index1:
			for i in range(index1, index2, 1):
				current_data.experience.data[i] = current_data.experience.data[index1-1]
		for i in 8:
			current_data.params[i].data.resize(value)
			if index2 > index1:
				for j in range(index1, index2, 1):
					current_data.params[i].data[j] = current_data.params[i].data[index1-1]
	
	fill_params()


func _on_max_level_spin_box_value_changed(value: float) -> void:
	if busy: return
	get_data().max_level = value
	params_need_resize = 0.15


func _on_note_text_edit_text_changed() -> void:
	get_data().notes = %NoteTextEdit.text


func _on_experience_clicked() -> void:
	show_parameter_curve_editor(0)


func _on_max_hp_clicked() -> void:
	show_parameter_curve_editor(1)


func _on_max_mp_clicked() -> void:
	show_parameter_curve_editor(2)


func _on_attack_clicked() -> void:
	show_parameter_curve_editor(3)


func _on_defense_clicked() -> void:
	show_parameter_curve_editor(4)


func _on_m_attack_clicked() -> void:
	show_parameter_curve_editor(5)


func _on_m_defense_clicked() -> void:
	show_parameter_curve_editor(6)


func _on_agility_clicked() -> void:
	show_parameter_curve_editor(7)


func _on_luck_clicked() -> void:
	show_parameter_curve_editor(8)


func show_parameter_curve_editor(selected_id: int) -> void:
	var path = "res://addons/CustomControls/Dialogs/parameter_curve_editor_dialog.tscn"
	var parent = get_tree().get_nodes_in_group("main_database")[0]
	var dialog
	var main_panel = parent.get_child(0)
	if main_panel.cache_dialog.has(path) and is_instance_valid(main_panel.cache_dialog[path]):
		dialog = main_panel.cache_dialog[path]
		RPGDialogFunctions.show_dialog(dialog, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	else:
		dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
		main_panel.cache_dialog[path] = dialog
		dialog.visibility_changed.connect(_on_parameter_curve_editor_dialog_visibility_changed.bind(dialog))
	
	dialog.set_data(parameters_cache)
	dialog.select_data_type(selected_id)


func _on_parameter_curve_editor_dialog_visibility_changed(dialog: Window) -> void:
	if !dialog.visible:
		var current_data = get_data()
		current_data.experience.min_value = parameters_cache[0].min_value
		current_data.experience.max_value = parameters_cache[0].max_value
		for i in range(1, parameters_cache.size(), 1):
			var index = i - 1
			current_data.params[index].min_value = parameters_cache[i].min_value
			current_data.params[index].max_value = parameters_cache[i].max_value
		fill_params()


func _on_visibility_changed() -> void:
	super()
	if visible:
		if current_selected_index != -1:
			busy = true
			%TraitsPanel.set_data(database, get_data().traits)
			fill_learnable_list()
			fill_class_list(get_data().upgrade_to_class)
			busy = false
		else:
			%TraitsPanel.clear()
			%LearnableSkillList.clear()


func _on_learnable_skill_list_item_activated(index: int) -> void:
	var path = "res://addons/CustomControls/Dialogs/add_learnable_skill_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	var current_data = get_data()
	dialog.database = database
	dialog.set_min_max_level(1, current_data.max_level)
	if current_data.learnable_skills.size() > index:
		dialog.set_current_learnable_skill(current_data.learnable_skills[index])
		dialog.target = _learnable_skill_added.bind(index)
		dialog.title = TranslationManager.tr("Edit Learnable Skill")
	else:
		dialog.set_new_learnable_skill()
		dialog.target = _learnable_skill_added.bind(-1)
		dialog.title = TranslationManager.tr("Add Learnable Skill")


func _learnable_skill_added(obj: RPGLearnableSkill, target_index: int) -> void:
	var current_data = get_data().learnable_skills
	if target_index != -1:
		current_data[target_index] = obj
		fill_learnable_list(target_index)
	else:
		current_data.append(obj)
		fill_learnable_list(current_data.size() - 1)



func _on_learnable_skill_list_copy_requested(indexes: PackedInt32Array) -> void:
	if !database: return

	var copy_learnable_skill: Array[RPGLearnableSkill]
	var learnable_skill = get_data().learnable_skills
	for index in indexes:
		if index > learnable_skill.size() - 1:
			continue
		copy_learnable_skill.append(learnable_skill[index].clone(true))
		
	StaticEditorVars.CLIPBOARD["learnable_skill"] = copy_learnable_skill


func _on_learnable_skill_list_cut_requested(indexes: PackedInt32Array) -> void:
	if !database: return
	
	var copy_learnable_skill: Array[RPGLearnableSkill]
	var learnable_skill = get_data().learnable_skills
	var remove_learnable_skill: Array[RPGLearnableSkill]
	for index in indexes:
		if index > learnable_skill.size() - 1:
			continue
		copy_learnable_skill.append(learnable_skill[index].clone(true))
		remove_learnable_skill.append(learnable_skill[index])
	for item in remove_learnable_skill:
		learnable_skill.erase(item)

	StaticEditorVars.CLIPBOARD["learnable_skill"] = copy_learnable_skill
	
	var item_selected = max(-1, indexes[0])
	fill_learnable_list(item_selected)


func _on_learnable_skill_list_paste_requested(index: int) -> void:
	if !database: return
	
	var learnable_skill = get_data().learnable_skills
	
	if StaticEditorVars.CLIPBOARD.has("learnable_skill"):
		for i in StaticEditorVars.CLIPBOARD["learnable_skill"].size():
			var real_index = index + i + 1
			var current_learnable_skill = StaticEditorVars.CLIPBOARD["learnable_skill"][i].clone()
			if real_index < learnable_skill.size():
				learnable_skill.insert(real_index, current_learnable_skill)
			else:
				learnable_skill.append(current_learnable_skill)

	fill_learnable_list(min(index + 1, learnable_skill.size() - 1))
	
	var list = %LearnableSkillList
	await list.columns_setted
	await get_tree().process_frame
	await get_tree().process_frame
	if StaticEditorVars.CLIPBOARD.has("learnable_skill"):
		for i in range(index + 1, index + StaticEditorVars.CLIPBOARD["learnable_skill"].size() + 1):
			if i >= learnable_skill.size():
				i = index
			list.select(i, false)


func _on_learnable_skill_list_delete_pressed(indexes: PackedInt32Array) -> void:
	if !database: return
	
	var learnable_skill = get_data().learnable_skills
	var remove_learnable_skill: Array[RPGLearnableSkill] = []
	for index in indexes:
		if index >= 0 and learnable_skill.size() > index:
			remove_learnable_skill.append(learnable_skill[index])
	for obj in remove_learnable_skill:
		learnable_skill.erase(obj)
		
	fill_learnable_list(indexes[0])


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


func _on_description_text_edit_text_changed() -> void:
	get_data().description = %DescriptionText.text


func _on_automatic_upgrade_toggled(toggled_on: bool) -> void:
	get_data().automatic_upgrade = toggled_on


func _on_upgrade_to_class_item_selected(index: int) -> void:
	get_data().upgrade_to_class = index


func _on_name_line_edit_text_changed_update_class_list(new_text: String) -> void:
	var id = database.classes.find(get_data())
	if !new_text:
		new_text = "class %s" % id
	%UpgradeToClass.set_item_text(id, new_text)


func _on_copy_parameters_pressed() -> void:
	var current_data = get_data()
	var params: Array[RPGCurveParams] = []
	for param: RPGCurveParams in current_data.params:
		params.append(param.clone(true))
	StaticEditorVars.CLIPBOARD.class_parameters = {
		"params": params,
		"experience": current_data.experience.clone(true)
	}
	%PasteParameters.set_disabled(false)


func _on_paste_parameters_pressed() -> void:
	var current_data = get_data()
	var class_parameters = StaticEditorVars.CLIPBOARD.get("class_parameters", null)
	if class_parameters:
		var new_params: Array[RPGCurveParams] = []
		for param: RPGCurveParams in class_parameters.params:
			new_params.append(param.clone(true))
		current_data.params = new_params
		current_data.experience = class_parameters.experience.clone(true)
		fill_params()


func _on_config_data_tabs_tab_changed(index: int) -> void:
	var node_path = "%%Tab%s" % (index + 1)
	var node = get_node_or_null(node_path)
	if node:
		for child in node.get_parent().get_children():
			child.visible = false
		node.visible = true


func _on_tick_interval_value_changed(value: float) -> void:
	get_data().tick_interval = value


func _on_hp_weight_value_changed(value: float) -> void:
	get_data().weights["HP"] = value


func _on_mp_weight_value_changed(value: float) -> void:
	get_data().weights["MP"] = value


func _on_attack_weight_value_changed(value: float) -> void:
	get_data().weights["ATK"] = value


func _on_defense_weight_value_changed(value: float) -> void:
	get_data().weights["DEF"] = value


func _on_magic_attack_weight_value_changed(value: float) -> void:
	get_data().weights["MATK"] = value


func _on_magic_defense_weight_value_changed(value: float) -> void:
	get_data().weights["MDEF"] = value


func _on_agility_weight_value_changed(value: float) -> void:
	get_data().weights["AGI"] = value


func _on_luck_weight_value_changed(value: float) -> void:
	get_data().weights["LUCK"] = value


func _on_copy_weights_pressed() -> void:
	var current_data = get_data()
	var weights: Dictionary = current_data.weights.duplicate()
	StaticEditorVars.CLIPBOARD.class_weights = weights
	%PasteWeights.set_disabled(false)


func _on_paste_weights_pressed() -> void:
	var current_data = get_data()
	var class_weights = StaticEditorVars.CLIPBOARD.get("class_weights", null)
	if class_weights:
		current_data.weights.merge(class_weights, true)
		fill_weights()


func _on_reset_weights_pressed() -> void:
	get_data().set_param_weights()
	fill_weights()


func _on_icon_picker_paste_requested(icon: String, region: Rect2) -> void:
	var data_icon = get_data().icon
	data_icon.path = icon
	data_icon.region = region
	%IconPicker.set_icon(data_icon.path, data_icon.region)
