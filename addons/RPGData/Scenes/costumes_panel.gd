@tool
extends BasePanelData

#region Variables
#endregion



#region Lifecycle
## Initializes the panel and connects the costume creation signal
func _ready() -> void:
	super()
	default_data_element = RPGCostume.new()
	_fill_usage_restriction()
	item_created.connect(_on_costume_created)
	disable_right_panel.connect(clear)
	locked_items.clear()
	%UserParametersControl.data = data
	%UserParametersControl.default_data_element = default_data_element
	%DefaultParametersControl.set_title(tr("Costume Params"))


func set_data(_data: Array) -> void:
	super(_data)
	%UserParametersControl.data = data


func _fill_usage_restriction() -> void:
	var node = %RequiresActorClass
	node.clear()
	node.add_item(tr("Any Class"))
	node.set_item_metadata(-1, 0)
	
	if not database: database = RPGSYSTEM.database
	
	for c: RPGClass in database.classes:
		if not c: continue
		var is_sep = false
		if "separator" in c and c.separator != null:
			is_sep = true
		node.add_item("%s: %s" % [c.id, c.name])
		node.set_item_metadata(-1, c._uniq_id)
		if is_sep:
			node.set_item_disabled(node.get_item_count() - 1, true)
	
	node = %RequiresActorGender
	node.clear()
	node.add_item(tr("Any Gender"))
	
	for i: int in database.types.gender_types.size():
		var t: String = database.types.gender_types[i]
		node.add_item("%s: %s" % [i + 1, t])


## Initializes user parameters for newly created costumes
func _on_costume_created(costume: RPGCostume) -> void:
	costume.user_parameters.resize(database.types.user_parameters.size())
	
	for i in database.types.user_parameters.size():
		costume.user_parameters[i] = database.types.user_parameters[i].default_value


## Retrieves the currently selected costume data
func get_data() -> RPGCostume:
	if not data: return null
	
	current_selected_index = max(1, min(current_selected_index, data.size() - 1))
	
	if data.size() > current_selected_index:
		return data[current_selected_index]
	else:
		return default_data_element
#endregion



#region Core Data Loading
## Updates all visual fields based on the selected costume
func _update_data_fields() -> void:
	busy = true
	
	%UserParametersControl.current_selected_index = current_selected_index
	
	if current_selected_index != -1:
		var current_data = get_data()
		disable_all(false)

		if not current_data: return
		
		fill_user_parameters()
		%NameLineEdit.text = data[current_selected_index].name
		
		var lpc_part_path = data[current_selected_index].lpc_part
		var preview_path = lpc_part_path.get_basename().trim_suffix("_data") + "_preview.png"
		%IconPicker.set_icon(preview_path)
		
		%TraitsPanel.set_data(database, data[current_selected_index].traits)
		%DescriptionTextEdit.text = current_data.description
		%PriceSpinBox.value = current_data.price
		%MaxQuantity.value = current_data.max_quantity
		
		%DefaultParametersControl.set_data(current_data.params)
		
		%NoteTextEdit.text = current_data.notes
			
		%PasteCraft.set_disabled(!StaticEditorVars.CLIPBOARD.get("items_craft", false))
		%PasteDisassemble.set_disabled(!StaticEditorVars.CLIPBOARD.get("items_disassemble", false))
		
		_fill_equipment_restriction()
		
	else:
		disable_all(true)
		%NameLineEdit.text = ""
		%IconPicker.set_icon("")
		%TraitsPanel.clear()
	
	busy = false


func _fill_equipment_restriction() -> void:
	var current_data = get_data()
	if not current_data.equipment_restriction:
		current_data.equipment_restriction = RPGEquipRestrictions.new()
	
	%RequiresActorLevel.value = current_data.equipment_restriction.level_restriction
	
	var class_id = current_data.equipment_restriction.class_restriction
	var class_found: bool = false
	for i in %RequiresActorClass.get_item_count():
		if %RequiresActorClass.get_item_metadata(i) == class_id:
			%RequiresActorClass.select(i)
			class_found = true
			break
	if not class_found:
		current_data.equipment_restriction.class_restriction = 0
		%RequiresActorClass.select(0)
		
	var gender_id = current_data.equipment_restriction.gender_restriction
	if gender_id < 0 or gender_id >= %RequiresActorGender.get_item_count():
		gender_id = 0
		current_data.equipment_restriction.gender_restriction = 0
	%RequiresActorGender.select(gender_id)


## Handles visibility changes to refresh parameters and traits
func _on_visibility_changed() -> void:
	super()
	
	if visible:
		if not get_data(): return
		busy = true
		
		fill_user_parameters()
		_fill_usage_restriction()
		
		if current_selected_index != -1:
			%TraitsPanel.set_data(database, get_data().traits)
		else:
			%TraitsPanel.clear()
			
		busy = false


## Populates the user parameters list
func fill_user_parameters(selected_index: int = 0) -> void:
	%UserParametersControl.fill_user_parameters(selected_index)


## Clears the UI visuals
func clear() -> void:
	%IconPicker.set_icon("")
	%TraitsPanel.clear()
	%UserParametersControl.clear()
#endregion



#region UI Interactions
## Clears the LPC part reference
func _on_icon_picker_remove_requested() -> void:
	get_data().lpc_part = ""
	%IconPicker.set_icon("")


## Opens the file dialog to select a costume or set part
func _on_icon_picker_clicked() -> void:
	var path = "res://addons/CustomControls/Dialogs/select_file_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	
	await get_tree().process_frame
	
	dialog.target_callable = update_icon
	dialog.destroy_on_hide = true
	
	dialog.fill_mix_files(["sets", "costumes"])


## Updates the LPC part path and refreshes the preview icon
func update_icon(path: String) -> void:
	get_data().lpc_part = path
	var preview_path = path.get_basename().trim_suffix("_data") + "_preview.png"
	%IconPicker.set_icon(preview_path)


## Opens the craft materials dialog
func _on_craft_button_pressed() -> void:
	show_craft_dialog("Craft Materials", get_data().craft_materials, "craft_cost")


## Opens the disassemble materials dialog
func _on_disassemble_button_pressed() -> void:
	show_craft_dialog("Disassemble Materials", get_data().disassemble_materials, "disassemble_cost", true)


## Generic function to display the crafting/disassembling dialog
func show_craft_dialog(_title: String, mats: Array[RPGGearUpgradeComponent], cost_id: String, percent_enabled: bool = false) -> void:
	var path = "res://addons/CustomControls/Dialogs/weapon_and_armor_craft_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	dialog.title = _title
	
	if percent_enabled:
		dialog.enabled_percent(true)
		
	dialog.set_data(database, mats, get_data()[cost_id])
	dialog.materials_changed.connect(_on_craft_material_changed.bind(mats, cost_id))


## Updates crafting materials and costs when the dialog is closed
func _on_craft_material_changed(new_mats: Array[RPGGearUpgradeComponent], cost: int, real_mats: Array[RPGGearUpgradeComponent], cost_id: String ) -> void:
	get_data()[cost_id] = cost
	real_mats.clear()
	
	for mat in new_mats:
		real_mats.append(mat)


## Updates costume price
func _on_price_spin_box_value_changed(value: float) -> void:
	get_data().price = value


## Updates costume description
func _on_description_text_edit_text_changed() -> void:
	get_data().description = %DescriptionTextEdit.text


## Updates costume notes
func _on_note_text_edit_text_changed() -> void:
	get_data().notes = %NoteTextEdit.text


## Swaps visibility of configuration tabs
func _on_config_data_tabs_tab_changed(index: int) -> void:
	var node_path = "%%Tab%s" % (index + 1)
	var node = get_node_or_null(node_path)
	
	if node:
		for child in node.get_parent().get_children():
			child.visible = false
		node.visible = true


## Placeholder for icon pasting (not implemented for costumes)
func _on_icon_picker_paste_requested(_icon: String, _region: Rect2) -> void:
	return


## Updates max quantity stack
func _on_max_quantity_value_changed(value: float) -> void:
	if get_data():
		get_data().max_quantity = value
#endregion



#region Clipboard and File Dialog
## Helper to open the generic file selection dialog
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


## Copies crafting configuration to clipboard
func _on_copy_craft_pressed() -> void:
	var current_data = get_data()
	var components = []
	
	for component: RPGGearUpgradeComponent in current_data.craft_materials:
		components.append(component.clone(true))
		
	StaticEditorVars.CLIPBOARD.items_craft = {
		"cost": current_data.craft_cost,
		"components": components
	}
	
	%PasteCraft.set_disabled(false)
	RPGEditorToast.show_message("Craft materials copied to Clipboard")


## Pastes crafting configuration from clipboard
func _on_paste_craft_pressed() -> void:
	var current_data = get_data()
	var items_craft = StaticEditorVars.CLIPBOARD.get("items_craft", null)
	
	if items_craft:
		var components = []
		for component: RPGGearUpgradeComponent in items_craft.components:
			components.append(component.clone(true))
		current_data.craft_materials = components
		current_data.craft_cost = items_craft.cost


## Copies disassembly configuration to clipboard
func _on_copy_disassemble_pressed() -> void:
	var current_data = get_data()
	var components = []
	
	for component: RPGGearUpgradeComponent in current_data.disassemble_materials:
		components.append(component.clone(true))
		
	StaticEditorVars.CLIPBOARD.items_disassemble = {
		"cost": current_data.disassemble_cost,
		"components": components
	}
	
	%PasteDisassemble.set_disabled(false)
	RPGEditorToast.show_message("Salvaged materials copied to Clipboard")


## Pastes disassembly configuration from clipboard
func _on_paste_disassemble_pressed() -> void:
	var current_data = get_data()
	var items_disassemble = StaticEditorVars.CLIPBOARD.get("items_disassemble", null)
	
	if items_disassemble:
		var components = []
		for component: RPGGearUpgradeComponent in items_disassemble.components:
			components.append(component.clone(true))
		current_data.disassemble_materials = components
		current_data.disassemble_cost = items_disassemble.cost

#endregion


func _on_requires_actor_level_value_changed(value: float) -> void:
	get_data().equipment_restriction.level_restriction = value


func _on_requires_actor_class_item_selected(index: int) -> void:
	var real_index = 0 if index == 0 else %RequiresActorClass.get_item_metadata(index)
	get_data().equipment_restriction.class_restriction = real_index


func _on_requires_actor_gender_item_selected(index: int) -> void:
	get_data().equipment_restriction.gender_restriction = index
