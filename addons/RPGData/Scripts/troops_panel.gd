@tool
extends BasePanelData


var current_page: RPGTroopPage


func _ready() -> void:
	super()
	default_data_element = RPGTroop.new()


func get_data() -> RPGTroop:
	current_selected_index = max(1, min(current_selected_index, data.size() - 1))
	if data.size() > current_selected_index and current_selected_index != -1:
		return data[current_selected_index]
	return null


func _update_data_fields() -> void:
	busy = true
	
	var current_data = get_data()
	if current_selected_index != -1:
		disable_all(false)
		fill_pages()
		%EventPageListEditor.set_data(current_data.pages[0].list)
		%NameLineEdit.text = data[current_selected_index].name
	else:
		disable_all(true)
		%NameLineEdit.text = ""
	
	fill_enemy_list()
	
	if ResourceLoader.exists(current_data.background):
		%EditBattlerPositions.set_background(load(current_data.background))
	else:
		%EditBattlerPositions.set_background(null)
	
	%EditBattlerPositions.call_deferred("fill_members", current_data.members)
	
	%Notes.text = str(current_data.notes)
		
	busy = false


func fill_pages(selected_tab_index: int = 0) -> void:
	busy = true
	
	var current_data = get_data()
	
	%EventPageContainer.update_tabs(current_data.pages.size(), selected_tab_index, true)
	
	%AddPageButton.set_disabled(false)
	%CopyPageButton.set_disabled(false)
	%PastePageButton.set_disabled(!StaticEditorVars.CLIPBOARD.has("troop_page"))
	%RemovePageButton.set_disabled(%EventPageContainer.selected_tab == 0)
	%CleanPageButton.set_disabled(false)

	fill_condition()
	
	busy = false


func fill_enemy_list() -> void:
	var node = %EnemyList
	node.clear()
	
	for enemy in database.enemies:
		if not enemy: continue
		node.add_item("%s: %s" % [enemy.id, enemy.name])


func _on_event_page_container_tab_changed(tab: int) -> void:
	setup_current_page(tab)
	%RemovePageButton.set_disabled(tab == 0)


func setup_current_page(tab: int) -> void:
	var page: RPGTroopPage = get_data().pages[tab]
	%EventPageListEditor.set_data(page.list)
	current_page = page
	fill_condition()


func fill_condition() -> void:
	# format condition
	var condition: RPGTroopCondition = current_page.condition
	var parts: Array = []

	if condition.turn_ending:
		parts.append("Turn End")
		
	if condition.turn_valid:
		if condition.turn_a == 0 and condition.turn_b > 0:
			parts.append("Turn %s*X" % condition.turn_b)
		elif condition.turn_b == 0:
			parts.append("Turn %s" % condition.turn_a)
		else:
			parts.append("Turn %s+%s*X" % [condition.turn_a, condition.turn_b])
			
	var param = ["HP", "MP", "Attack", "Defense", "Magical Attack", "Magical Defense", "Agility", "Luck"]
	var op = ["<", "<=", ">", ">=", "!=", "=="]
	
	if condition.enemy_valid:
		var perc = "%" if condition.enemy_param_value_is_percent else ""
		parts.append("Enemy (%s) %s %s %s %s" % [
			condition.enemy_id,
			param[condition.enemy_param_index],
			op[condition.enemy_param_operation],
			condition.enemy_param_value,
			perc
		])
	
	if condition.actor_valid:
		var perc = "%" if condition.actor_param_value_is_percent else ""
		parts.append("Actor (%s) %s %s %s %s" % [
			condition.actor_id,
			param[condition.actor_param_index],
			op[condition.actor_param_operation],
			condition.actor_param_value,
			perc
		])
	
	if condition.switch_valid:
		var obj = RPGSYSTEM.system.switches.data
		var obj_name: String
		var id = condition.switch_id
		if obj.size() > id:
			var state = ["Enabled", "Disabled"][int(condition.switch_value)]
			obj_name = "Switch <%s: %s> is %s" % [
				str(id).pad_zeros(str(obj.size()).length()),
				obj[id].name,
				state
			]
		else:
			obj_name = "⚠ Invalid Data"
		parts.append(obj_name)
	
	if condition.variable_valid:
		var obj = RPGSYSTEM.system.variables.data
		var obj_name: String
		var id = condition.variable_id
		if obj.size() > id:
			var operation = op[condition.variable_operation]
			obj_name = "Variable <%s: %s> is %s %s" % [
				str(id).pad_zeros(str(obj.size()).length()),
				obj[id].name,
				operation,
				condition.variable_value
			]
		else:
			obj_name = "⚠ Invalid Data"
		parts.append(obj_name)
	
	if !parts:
		parts.append("Always valid: no conditions set.")
	
	%ConditionButton.text = ", ".join(parts)
	%ConditionSpan.select(condition.span)
	%IsNonExclusive.set_pressed_no_signal(current_page.is_non_exclusive)


func _on_add_page_button_pressed() -> void:
	if busy:
		return
		
	var index = %EventPageContainer.selected_tab + 1
	var new_page = RPGTroopPage.new()
	if index >= 0 and index < get_data().pages.size():
		get_data().pages.insert(index, new_page)
	else:
		get_data().pages.append(new_page)
	get_data().fix_pages_ids()
	fill_pages(index)


func _on_copy_page_button_pressed() -> void:
	if busy:
		return
		
	StaticEditorVars.CLIPBOARD["troop_page"] = current_page.clone(true)
	%PastePageButton.set_disabled(false)


func _on_paste_page_button_pressed() -> void:
	if busy:
		return
		
	if StaticEditorVars.CLIPBOARD.has("troop_page"):
		var index = %EventPageContainer.selected_tab + 1
		get_data().pages.insert(index, StaticEditorVars.CLIPBOARD["troop_page"].clone(true))
		get_data().fix_pages_ids()
		fill_pages(index)


func _on_remove_page_button_pressed() -> void:
	if busy:
		return
		
	var index = %EventPageContainer.selected_tab
	if index >= 0 and index < get_data().pages.size():
		get_data().pages.remove_at(index)
		index = min(index, get_data().pages.size() - 1)
		get_data().fix_pages_ids()
		fill_pages(index)


func _on_clean_page_button_pressed() -> void:
	if busy:
		return
	
	var index = %EventPageContainer.selected_tab
	var page: RPGTroopPage = RPGTroopPage.new()
	page.id = index
	get_data().pages[index] = page
	setup_current_page(index)


func _on_condition_button_pressed() -> void:
	var path: String = "res://addons/CustomControls/Dialogs/troop_conditions_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	
	var members: Array = get_data().members.filter(
		func(e: RPGTroopMember):
			e.type == 1
	)
	var enemies: PackedStringArray = []
	var enemy_data = RPGSYSTEM.database.enemies
	for i in members.size():
		var enemy: RPGTroopMember = members[i]
		var enemy_name = "%s: %s" % [i+1, enemy_data[enemy.id].name]
		enemies.append(enemy_name)
		
	dialog.set_condition(current_page.condition)
	dialog.set_enemies(enemies)
	dialog.condition_changed.connect(fill_condition)


func _on_condition_span_item_selected(index: int) -> void:
	current_page.condition.span = index
	%ConditionButton.set_disabled(index > 2)


func _on_visibility_changed() -> void:
	super()
	if visible:
		if current_selected_index != -1:
			busy = true
			fill_enemy_list()
			%EditBattlerPositions.call_deferred("fill_members", get_data().members)
			if current_page:
				var index = %EventPageContainer.selected_tab
				fill_pages(index)
			busy = false
		else:
			pass



func _on_h_separator_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.is_pressed():
				%HSeparator.set_meta("dragging", true)
			else:
				%HSeparator.remove_meta("dragging")
	elif event is InputEventMouseMotion and %HSeparator.has_meta("dragging"):
		var panel = %PanelContainer
		var first_panel_y = %GeneralSettings.get("custom_minimum_size").y
		var last_panel_y = %PanelContainer2.get("custom_minimum_size").y
		if !panel.has_meta("real_min_size"):
			panel.set_meta("real_min_size", panel.get("custom_minimum_size"))
		var min_y = panel.get_meta("real_min_size").y
		var application_y = get_tree().get_first_node_in_group("main_database").size.y
		var max_y = application_y - last_panel_y - first_panel_y - 210
		var y = max(min_y, min(max_y, panel.size.y + event.relative.y))
		panel.size.y = y
		panel.set("custom_minimum_size", Vector2(0, y))


func _on_background_button_pressed() -> void:
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
	
	dialog.target_callable = _select_background
	dialog.set_file_selected(get_data().background)
	
	dialog.fill_files("images")


func _select_background(path: String) -> void:
	get_data().background = path
	%EditBattlerPositions.set_background(load(path))


func _on_notes_text_changed() -> void:
	get_data().notes = %Notes.text


func _on_is_non_exclusive_toggled(toggled_on: bool) -> void:
	current_page.is_non_exclusive = toggled_on


func _on_config_data_tabs_tab_changed(index: int) -> void:
	var node_path = "%%Tab%s" % (index + 1)
	var node = get_node_or_null(node_path)
	if node:
		for child in node.get_parent().get_children():
			child.visible = false
		node.visible = true


func _on_add_enemy_pressed() -> void:
	var current_data = get_data()
	var enemy_id = %EnemyList.get_selected_id() + 1
	var member = RPGTroopMember.new(1, enemy_id, 2, Vector2(0.12, 0.3))
	current_data.members.append(member)
	
	%EditBattlerPositions.call_deferred("fill_members", current_data.members)


func _on_edit_battler_positions_battler_is_selected(value: bool) -> void:
	%EditBattlerPresets.show_align_controls(value)


func _on_edit_battler_presets_aligment_requested(align: EditBattlerPresets.ALIGN) -> void:
	var candidates = []
	for child: BattlerPositionScene in %EditBattlerPositions.get_battler_container().get_children():
		if child.is_selected:
			candidates.append(child)
	
	if candidates.size() > 1:
		match align:
			EditBattlerPresets.ALIGN.LEFT:
				# Alinear todos los candidatos al lado izquierdo del más a la izquierda
				var leftmost_x = candidates[0].position.x
				for candidate in candidates:
					if candidate.position.x < leftmost_x:
						leftmost_x = candidate.position.x
				for candidate in candidates:
					candidate.position.x = leftmost_x
			
			EditBattlerPresets.ALIGN.HORIZONTAL_CENTER:
				# Alinear todos los candidatos al centro horizontal promedio
				var center_x = 0.0
				for candidate in candidates:
					center_x += candidate.position.x
				center_x /= candidates.size()
				for candidate in candidates:
					candidate.position.x = center_x
			
			EditBattlerPresets.ALIGN.RIGHT:
				# Alinear todos los candidatos al lado derecho del más a la derecha
				var rightmost_x = candidates[0].position.x
				for candidate in candidates:
					if candidate.position.x > rightmost_x:
						rightmost_x = candidate.position.x
				for candidate in candidates:
					candidate.position.x = rightmost_x
			
			EditBattlerPresets.ALIGN.TOP:
				# Alinear todos los candidatos al lado superior del más arriba
				var topmost_y = candidates[0].position.y
				for candidate in candidates:
					if candidate.position.y < topmost_y:
						topmost_y = candidate.position.y
				for candidate in candidates:
					candidate.position.y = topmost_y
			
			EditBattlerPresets.ALIGN.VERTICAL_CENTER:
				# Alinear todos los candidatos al centro vertical promedio
				var center_y = 0.0
				for candidate in candidates:
					center_y += candidate.position.y
				for candidate in candidates:
					candidate.position.y = center_y / candidates.size()
			
			EditBattlerPresets.ALIGN.BOTTOM:
				# Alinear todos los candidatos al lado inferior del más abajo
				var bottommost_y = candidates[0].position.y
				for candidate in candidates:
					if candidate.position.y > bottommost_y:
						bottommost_y = candidate.position.y
				for candidate in candidates:
					candidate.position.y = bottommost_y
