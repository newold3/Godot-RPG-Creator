@tool
extends BasePanelData


func _ready() -> void:
	super()
	default_data_element = RPGSkill.new()


func get_data() -> RPGSkill:
	if not data: return null
	current_selected_index = max(1, min(current_selected_index, data.size() - 1))
	if data.size() > current_selected_index:
		return data[current_selected_index]
	else:
		return default_data_element


func _update_data_fields() -> void:
	busy = true
	
	if current_selected_index != -1:
		disable_all(false)
		fill_skill_types()
		fill_element_types()
		fill_invocation_animation()
		fill_required_equipment()
		fill_scope()
		var current_data = get_data()
		%NameLineEdit.text = current_data.name
		%IconPicker.set_icon(current_data.icon.path, current_data.icon.region)
		%EffectsPanel.set_data(database, current_data.effects)
		%DescriptionTextEdit.text = current_data.description
		%MPCostSpinBox.value = current_data.mp_cost
		%TPCostSpinBox.value = current_data.tp_cost
		%OccasionOptions.select(current_data.occasion)
		%SpeedSpinBox.value = current_data.invocation.speed
		%SuccessSpinBox.value = current_data.invocation.success
		%RepeatSpinBox.value = current_data.invocation.repeat
		%TPGainSpinBox.value = current_data.invocation.tp_gain
		%HitTypeOptions.select(current_data.invocation.hit_type)
		%BattleMessageTextEdit.text = current_data.battle_message
		%DamageTypeOptions.select(current_data.damage.type)
		if current_data.damage.type == 0:
			%Damage.propagate_call("set_disabled", [true])
			%Damage.propagate_call("set_editable", [false])
			%DamageTypeOptions.set_disabled(false)
		%DamageFormulaLineEdit.text = current_data.damage.formula
		%DamageVarianceSpinBox.value = current_data.damage.variance
		%DamageCriticalHitsOptions.select(current_data.damage.critical)
		%NoteTextEdit.text = current_data.notes
		if current_data.invocation.sequence:
			%Sequence.texture_normal.region.position.x = 216
		else:
			%Sequence.texture_normal.region.position.x = 168
			
	else:
		disable_all(true)
	
	
	busy = false


func fill_scope() -> void:
	if data:
		var scope = get_data().scope
		var button = %ScopeButton
		if scope.faction == 0:
			button.text = "none"
		elif scope.faction == 1:
			var texts = [
				"1 Enemy",
				"All Enemies",
				"1 Random Enemy" if scope.random == 1 else "%s Random Enemies" % scope.random
			]
			button.text = texts[scope.number]
		elif scope.faction == 2:
			var texts = [
				"1 Ally",
				"All Allies"
			]
			var text2 = [
				"(Alive)",
				"(Dead)",
				"(Unconditional)"
			]
			button.text = texts[scope.number] + " " + text2[scope.status]
		elif scope.faction == 3:
			button.text = TranslationManager.tr("All Allies and Enemies")
		elif scope.faction == 4:
			button.text = TranslationManager.tr("The User")


func _on_auto_message_options_item_selected(index: int) -> void:
	if index == 1:
		%BattleMessageTextEdit.text = TranslationManager.tr("%1 cast %2!")
	elif index == 2:
		%BattleMessageTextEdit.text = TranslationManager.tr("%1 does %2!")
	elif index == 3:
		%BattleMessageTextEdit.text = TranslationManager.tr("%1 uses %2!")
	
	%AutoMessageOptions.select(0)
	
	%BattleMessageTextEdit.text_changed.emit()


func _on_battle_message_text_edit_text_changed() -> void:
	get_data().battle_message = %BattleMessageTextEdit.text


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


func fill_skill_types() -> void:
	if !database: return
	
	var node = %SkillTypeOptions
	node.clear()
	
	node.add_item("None")
	
	if database:
		for i in database.types.skill_types.size():
			var item = database.types.skill_types[i]
			if item.length() == 0:
				item = "# %s" % (i+1)
			node.add_item(item)
	
	var current_data = get_data()
	if database.types.skill_types.size() >= current_data.skill_type:
		node.select(current_data.skill_type)
	else:
		node.select(-1)
		node.text = "⚠ Invalid Data"


func fill_element_types() -> void:
	if !database: return
	
	var node = %DamageElementOptions
	node.clear()
	
	node.add_item("Normal Attack")
	node.add_item("None")
	
	if database:
		for i in database.types.element_types.size():
			var item = database.types.element_types[i]
			if item.length() == 0:
				item = "# %s" % (i+1)
			node.add_item(item)
	
	var current_data = get_data()
	if database.types.element_types.size() + 1 >= current_data.damage.element_id:
		node.select(current_data.damage.element_id)
	else:
		node.select(-1)
		node.text = "⚠ Invalid Data"


func fill_invocation_animation() -> void:
	if !database: return
	
	var node = %AnimationButton
	
	var current_data = get_data()
	if database.animations.size() > current_data.invocation.animation and current_data.invocation.animation > 0:
		var animation_name = database.animations[current_data.invocation.animation].name
		if animation_name.length() == 0:
			animation_name = "# %s" % (current_data.invocation.animation)
		node.text = animation_name
	elif current_data.invocation.animation > 0:
		node.text = "⚠ Invalid Data"
	else:
		if current_data.invocation.animation == -2:
			node.text = TranslationManager.tr("Normal Attack")
		else:
			node.text = TranslationManager.tr("none")


func _on_visibility_changed() -> void:
	super()
	if visible:
		busy = true
		fill_skill_types()
		fill_element_types()
		fill_invocation_animation()
		fill_required_equipment()
		if current_selected_index != -1:
			%EffectsPanel.set_data(database, get_data().effects)
		else:
			%EffectsPanel.clear()
		busy = false


func fill_required_equipment(selected_index: int = -1) -> void:
	var node = %EquipmentList
	node.clear()
	
	if!database: return
	var current_data = get_data().required_weapons
	
	for item: RPGSkillRequiredWeapon in current_data:
		var item_name: String
		if item.category_id == 0:
			var data = database.weapons
			if data.size() > item.item_id:
				item_name = str(item.item_id).pad_zeros(str(data.size()).length()) + ": " + data[item.item_id].name
		else:
			var data = database.armors
			if data.size() > item.item_id:
				item_name = str(item.item_id).pad_zeros(str(data.size()).length()) + ": " + data[item.item_id].name
		node.add_column([item_name])
	
	if current_data.size() > 0:
		await node.columns_setted
		if node.items.size() + 1 > selected_index and selected_index != -1:
			node.select(selected_index)
		else:
			node.deselect_all()
	else:
		node.deselect_all()


func _on_description_text_edit_text_changed() -> void:
	get_data().description = %DescriptionTextEdit.text


func _on_skill_type_options_item_selected(index: int) -> void:
	get_data().skill_type = index


func _on_mp_cost_spin_box_value_changed(value: float) -> void:
	get_data().mp_cost = value


func _on_tp_cost_spin_box_value_changed(value: float) -> void:
	get_data().tp_cost = value


func _on_occasion_options_item_selected(index: int) -> void:
	get_data().occasion = index


func _on_speed_spin_box_value_changed(value: float) -> void:
	get_data().invocation.speed = value


func _on_success_spin_box_value_changed(value: float) -> void:
	get_data().invocation.success = value


func _on_repeat_spin_box_value_changed(value: float) -> void:
	if not get_data(): return
	get_data().invocation.repeat = value


func _on_tp_gain_spin_box_value_changed(value: float) -> void:
	if not get_data(): return
	get_data().invocation.tp_gain = value


func _on_hit_type_options_item_selected(index: int) -> void:
	if not get_data(): return
	get_data().invocation.hit_type = index


func _on_damage_type_options_item_selected(index: int) -> void:
	if not get_data(): return
	get_data().damage.type = index
	
	if index == 0:
		%Damage.propagate_call("set_disabled", [true])
		%Damage.propagate_call("set_editable", [false])
		%DamageTypeOptions.set_disabled(false)
	else:
		%Damage.propagate_call("set_disabled", [false])
		%Damage.propagate_call("set_editable", [true])


func _on_damage_element_options_item_selected(index: int) -> void:
	if not get_data(): return
	get_data().damage.element_id = index


func _on_damage_formula_line_edit_text_changed(new_text: String) -> void:
	if not get_data(): return
	get_data().damage.formula = new_text


func _on_damage_variance_spin_box_value_changed(value: float) -> void:
	if not get_data(): return
	get_data().damage.variance  = value


func _on_damage_critical_hits_options_item_selected(index: int) -> void:
	if not get_data(): return
	get_data().damage.critical = index


func _on_note_text_edit_text_changed() -> void:
	if not get_data(): return
	get_data().notes = %NoteTextEdit.text


func _on_scope_button_pressed() -> void:
	var path = "res://addons/CustomControls/Dialogs/Select_scope_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	dialog.set_data(get_data().scope)
	dialog.tree_exiting.connect(fill_scope)


func _on_animation_button_pressed() -> void:
	var path = "res://addons/CustomControls/Dialogs/select_any_data_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	dialog.database = database
	dialog.destroy_on_hide = true
	var current_data = database.animations
	var id_selected = get_data().invocation.animation
	var title = TranslationManager.tr("Animations")
	var target = self
	dialog.selected.connect(_on_animation_selected, CONNECT_ONE_SHOT)
	dialog.setup(current_data, id_selected, title, target)


func _on_animation_selected(id: int, target: Variant) -> void:
	if not get_data(): return
	get_data().invocation.animation = id
	fill_invocation_animation()


func _on_animation_button_middle_click_pressed() -> void:
	if not get_data(): return
	get_data().invocation.animation = -1
	fill_invocation_animation()


func _on_animation_button_right_click_pressed() -> void:
	if not get_data(): return
	get_data().invocation.animation = -2
	fill_invocation_animation()


func _on_equipment_list_item_activated(index: int) -> void:
	var path = "res://addons/CustomControls/Dialogs/select_skill_required_equipment.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	dialog.item_selected.connect(_on_required_equipment_selected)
	
	var selected_equipment = 0
	var selected_id = 0
	var current_data = get_data().required_weapons
	if current_data.size() > index:
		selected_equipment = current_data[index].category_id
		selected_id = current_data[index].item_id
	dialog.set_data(database, index, selected_equipment, selected_id)


func _on_required_equipment_selected(target_index: int, selected_equipment: int, selected_id: int) -> void:
	var current_data = get_data().required_weapons
	if current_data.size() > target_index:
		current_data[target_index].category_id = selected_equipment
		current_data[target_index].item_id = selected_id
		fill_required_equipment(target_index)
	else:
		var required_weapon = RPGSkillRequiredWeapon.new(selected_equipment, selected_id)
		current_data.append(required_weapon)
		fill_required_equipment(current_data.size() - 1)


func _on_damage_set_formula_button_pressed() -> void:
	var path = "res://addons/CustomControls/Dialogs/fast_damage_formula.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	
	dialog.fill_formulas(%DamageTypeOptions.get_selected_id())
	
	dialog.formula_selected.connect(_on_fast_formula_selected)


func _on_fast_formula_selected(formula: String) -> void:
	var node: LineEdit = %DamageFormulaLineEdit
	node.text = formula
	if node.has_focus():
		node.release_focus()
	node.grab_focus()


func _on_sequence_pressed() -> void:
	var path = "res://addons/CustomControls/Dialogs/skill_sequence_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path)
	dialog.set_data(get_data().invocation.sequence)
	dialog.sequence_changed.connect(
		func(sequence: Array[RPGInvocationSequence]):
			var current_data = get_data()
			current_data.invocation.sequence = sequence
			if sequence:
				%Sequence.texture_normal.region.position.x = 216
			else:
				%Sequence.texture_normal.region.position.x = 168
	)


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
