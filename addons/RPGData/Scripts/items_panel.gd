@tool
extends BasePanelData


func _ready() -> void:
	super()
	default_data_element = RPGItem.new()


func get_data() -> RPGItem:
	current_selected_index = max(1, min(current_selected_index, data.size() - 1))
	if data.size() > current_selected_index:
		return data[current_selected_index]
	else:
		return default_data_element


func _update_data_fields() -> void:
	busy = true
	
	if current_selected_index != -1:
		disable_all(false)
		fill_category_types()
		fill_rarity_types()
		fill_element_types()
		fill_item_conversion()
		fill_invocation_animation()
		fill_scope()
		var current_data = get_data()
		%NameLineEdit.text = current_data.name
		%IconPicker.set_icon(current_data.icon.path, current_data.icon.region)
		%EffectsPanel.set_data(database, current_data.effects)
		%DescriptionTextEdit.text = current_data.description
		%ItemTypeOptions.select(current_data.item_type)

		%PriceSpinBox.value = current_data.price
		%ConsumableOptions.select(current_data.consumable)
		%OccasionOptions.select(current_data.occasion)
		%SpeedSpinBox.value = current_data.invocation.speed
		%SuccessSpinBox.value = current_data.invocation.success
		%RepeatSpinBox.value = current_data.invocation.repeat
		%TPGainSpinBox.value = current_data.invocation.tp_gain
		%HitTypeOptions.select(current_data.invocation.hit_type)
		%DamageTypeOptions.select(current_data.damage.type)
		if current_data.damage.type == 0:
			%Damage.propagate_call("set_disabled", [true])
			%Damage.propagate_call("set_editable", [false])
			%DamageTypeOptions.set_disabled(false)
		%DamageFormulaLineEdit.text = current_data.damage.formula
		%DamageVarianceSpinBox.value = current_data.damage.variance
		%DamageCriticalHitsOptions.select(current_data.damage.critical)
		%IsPerishableOptionButton.select(current_data.perishable.is_perishable)
		%PerishableDurationSpinBox.value = current_data.perishable.duration
		%PerishableActionOptionButton.select(current_data.perishable.action)
		%PerishableDurationSpinBox.set_disabled(current_data.perishable.is_perishable == 0)
		%PerishableActionOptionButton.set_disabled(current_data.perishable.is_perishable == 0)
		%PerishableItemConversionButton.set_disabled(current_data.perishable.is_perishable == 0 or current_data.perishable.action == 0)
		%BattleMessageTextEdit.text = current_data.battle_message
		%NoteTextEdit.text = current_data.notes
	else:
		disable_all(true)
	
	busy = false


func fill_item_conversion() -> void:
	if !database: return
	
	var item_id = get_data().perishable.conversion_item_id
	var item_name: String
	
	if database.items.size() > item_id and item_id > 0:
		item_name = str(item_id).pad_zeros(str(database.items.size()).length()) + ": " + database.items[item_id].name
	elif item_id > 0:
		item_name = "⚠ Invalid Data"
	else:
		item_name = "none"
	%PerishableItemConversionButton.text = item_name


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


func fill_category_types() -> void:
	if !database: return
	
	var node = %ItemCategoryOptions
	node.clear()
	
	if database:
		for i in database.types.item_types.size():
			var item = database.types.item_types[i]
			if item.length() == 0:
				item = "# %s" % (i+1)
			node.add_item(item)
	
	var current_data = get_data()
	if database.types.item_types.size() + 1 >= current_data.item_category:
		node.select(current_data.item_category)
	else:
		node.select(-1)
		node.text = "⚠ Invalid Data"


func fill_rarity_types() -> void:
	if !database: return
	
	var node = %ItemRarityTypeOptions
	node.clear()
	
	if database:
		for i in database.types.item_rarity_types.size():
			var item = database.types.item_rarity_types[i]
			var color = database.types.item_rarity_color_types[i]
			var icon = Image.create(16, 16, true, Image.FORMAT_RGB8)
			icon.fill_rect(Rect2i(0, 0, 16, 16), color)
			var tex = ImageTexture.create_from_image(icon)
			if item.length() == 0:
				item = "# %s" % (i+1)
			node.add_icon_item(tex, item)
	
	var current_data = get_data()
	if database.types.item_rarity_types.size() + 1 >= current_data.rarity_type:
		node.select(current_data.rarity_type)
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
		node.text = TranslationManager.tr("none")


func fill_scope() -> void:
	if data:
		var scope = get_data().scope
		var button = %ScopeButton
		if scope.faction == 0:
			button.text = TranslationManager.tr("none")
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


func _on_visibility_changed() -> void:
	super()
	if visible:
		busy = true
		fill_category_types()
		fill_rarity_types()
		fill_element_types()
		fill_item_conversion()
		fill_invocation_animation()
		if current_selected_index != -1:
			%EffectsPanel.set_data(database, get_data().effects)
		else:
			%EffectsPanel.clear()
		busy = false


func _on_is_perishable_option_button_item_selected(index: int) -> void:
	var current_data = get_data().perishable
	current_data.is_perishable = index
	%Perishable.propagate_call("set_disabled", [index == 0])
	%IsPerishableOptionButton.set_disabled(false)
	if index == 1:
		%PerishableItemConversionButton.set_disabled(current_data.action == 0)


func _on_perishable_duration_spin_box_value_changed(value: float) -> void:
	get_data().perishable.duration = value


func _on_perishable_action_option_button_item_selected(index: int) -> void:
	get_data().perishable.action = index
	%PerishableItemConversionButton.set_disabled(index == 0)


func _on_perishable_item_conversion_button_pressed() -> void:
	var path = "res://addons/CustomControls/Dialogs/select_any_data_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	dialog.database = database
	dialog.destroy_on_hide = true
	var current_data = database.items
	var id_selected = get_data().perishable.conversion_item_id
	var title = TranslationManager.tr("Items")
	var target = self
	dialog.selected.connect(_on_perishable_item_selected, CONNECT_ONE_SHOT)
	dialog.setup(current_data, id_selected, title, target)


func _on_perishable_item_selected(id: int, target: Variant) -> void:
	get_data().perishable.conversion_item_id = id
	fill_item_conversion()


func _on_name_line_edit_text_changed(new_text: String) -> void:
	super(new_text)
	fill_item_conversion()


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
	get_data().invocation.animation = id
	fill_invocation_animation()


func _on_animation_button_middle_click_pressed() -> void:
	get_data().invocation.animation = -1
	fill_invocation_animation()


func _on_animation_button_right_click_pressed() -> void:
	get_data().invocation.animation = -2
	fill_invocation_animation()


func _on_speed_spin_box_value_changed(value: float) -> void:
	get_data().invocation.speed = value


func _on_success_spin_box_value_changed(value: float) -> void:
	get_data().invocation.success = value


func _on_repeat_spin_box_value_changed(value: float) -> void:
	get_data().invocation.repeat = value


func _on_tp_gain_spin_box_value_changed(value: float) -> void:
	get_data().invocation.tp_gain = value


func _on_hit_type_options_item_selected(index: int) -> void:
	get_data().invocation.hit_type = index


func _on_damage_type_options_item_selected(index: int) -> void:
	get_data().damage.type = index
	
	if index == 0:
		%Damage.propagate_call("set_disabled", [true])
		%Damage.propagate_call("set_editable", [false])
		%DamageTypeOptions.set_disabled(false)
	else:
		%Damage.propagate_call("set_disabled", [false])
		%Damage.propagate_call("set_editable", [true])


func _on_damage_element_options_item_selected(index: int) -> void:
	get_data().damage.element_id = index


func _on_damage_formula_line_edit_text_changed(new_text: String) -> void:
	get_data().damage.formula = new_text


func _on_damage_variance_spin_box_value_changed(value: float) -> void:
	get_data().damage.variance  = value


func _on_damage_critical_hits_options_item_selected(index: int) -> void:
	get_data().damage.critical = index


func _on_note_text_edit_text_changed() -> void:
	get_data().notes = %NoteTextEdit.text


func _on_description_text_edit_text_changed() -> void:
	get_data().description = %DescriptionTextEdit.text


func _on_item_type_options_item_selected(index: int) -> void:
	get_data().item_type = index


func _on_item_category_options_item_selected(index: int) -> void:
	get_data().item_category = index


func _on_price_spin_box_value_changed(value: float) -> void:
	get_data().price = value


func _on_consumable_options_item_selected(index: int) -> void:
	get_data().consumable = index


func _on_occasion_options_item_selected(index: int) -> void:
	get_data().occasion = index


func _on_scope_button_pressed() -> void:
	var path = "res://addons/CustomControls/Dialogs/Select_scope_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	dialog.set_data(get_data().scope)
	dialog.tree_exiting.connect(fill_scope)



func _on_item_rarity_type_options_item_selected(index: int) -> void:
	get_data().rarity_type = index


func _on_auto_message_options_item_selected(index: int) -> void:
	if index == 1:
		%BattleMessageTextEdit.text = TranslationManager.tr("%1 uses %2!")
	elif index == 2:
		%BattleMessageTextEdit.text = TranslationManager.tr("%1 activates %2!")
	elif index == 3:
		%BattleMessageTextEdit.text = TranslationManager.tr("%1 employs %2!")
	
	%AutoMessageOptions.select(0)
	
	%BattleMessageTextEdit.text_changed.emit()


func _on_battle_message_text_edit_text_changed() -> void:
	get_data().battle_message = %BattleMessageTextEdit.text


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
	node.text_changed.emit(formula)


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
