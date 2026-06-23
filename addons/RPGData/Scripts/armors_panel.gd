@tool
extends BasePanelData


#region Lifecycle
## Initializes the panel and connects the armor creation signal
func _ready() -> void:
	super()
	default_data_element = RPGArmor.new()
	_fill_usage_restriction()
	item_created.connect(_on_armor_created)
	%UserParametersControl.data = data
	%UserParametersControl.default_data_element = default_data_element
	%DefaultParametersControl.set_title(tr("Parameters (when armor is level 1)"))


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
		node.add_item("%s: %s" % [c.id, c.name])
		node.set_item_metadata(-1, c._uniq_id)
	
	node = %RequiresActorGender
	node.clear()
	node.add_item(tr("Any Gender"))
	
	for i: int in database.types.gender_types.size():
		var t: String = database.types.gender_types[i]
		node.add_item("%s: %s" % [i + 1, t])


## Initializes user parameters for newly created armors
func _on_armor_created(armor: RPGArmor) -> void:
	armor.user_parameters.resize(database.types.user_parameters.size())
	for i in database.types.user_parameters.size():
		armor.user_parameters[i] = database.types.user_parameters[i].default_value


## Retrieves the currently selected armor data
func get_data() -> RPGArmor:
	if not data: return null
	current_selected_index = max(1, min(current_selected_index, data.size() - 1))
	if data.size() > current_selected_index:
		return data[current_selected_index]
	else:
		return default_data_element
#endregion


#region Core Data Loading
## Updates all visual fields based on the selected armor data
func _update_data_fields() -> void:
	busy = true
	
	%UserParametersControl.current_selected_index = current_selected_index
	
	if current_selected_index != -1:
		disable_all(false)
		fill_armor_types()
		fill_equipment_types()
		fill_user_parameters()
		fill_rarity_types()
		
		var current_data = get_data()
		if not current_data: return
		%NameLineEdit.text = data[current_selected_index].name
		%IconPicker.set_icon(current_data.icon.path, current_data.icon.region)
		%TraitsPanel.set_data(database, data[current_selected_index].traits)
		%DescriptionTextEdit.text = current_data.description
		%PriceSpinBox.value = current_data.price
		%MaxQuantity.value = current_data.max_quantity
		
		%DefaultParametersControl.set_data(current_data.params)
		
		%ArmorMaxLevelsSpinBox.value = current_data.upgrades.max_levels
		%NoteTextEdit.text = current_data.notes
		%UpgradeSettingsButton.set_disabled(current_data.upgrades.max_levels == 1)
		%CopyUpgradeList.set_disabled(current_data.upgrades.max_levels == 1)
		
		if current_data.lpc_part.length() > 0:
			%LPCPartButton.text = current_data.lpc_part
		else:
			%LPCPartButton.text = tr("Select LPC Equipment")
			
		%PasteUpgradeList.set_disabled(!StaticEditorVars.CLIPBOARD.get("upgrade_list", false))
		%PasteCraft.set_disabled(!StaticEditorVars.CLIPBOARD.get("items_craft", false))
		%PasteDisassemble.set_disabled(!StaticEditorVars.CLIPBOARD.get("items_disassemble", false))
		
		_fill_equipment_restriction()
		
	else:
		disable_all(true)
		%NameLineEdit.text = ""
		%IconPicker.set_icon(null)
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


## Handles visibility changes to refresh dropdowns
func _on_visibility_changed() -> void:
	super()
	if visible:
		busy = true
		fill_armor_types()
		fill_equipment_types()
		fill_user_parameters()
		fill_rarity_types()
		_fill_usage_restriction()
		
		if current_selected_index != -1:
			%TraitsPanel.set_data(database, get_data().traits)
		else:
			%TraitsPanel.clear()
			
		busy = false
#endregion


#region Dropdowns and Lists Setup
## Populates the armor type options
func fill_armor_types() -> void:
	if !database: return
	
	var node = %ArmorTypeOptions
	node.clear()
	node.add_item("None")
	
	for i in database.types.armor_types.size():
		var item = database.types.armor_types[i]
		if item.length() == 0:
			item = "# %s" % (i+1)
		node.add_item(item)
	
	var current_data = get_data()
	if current_data and database.types.armor_types.size() >= current_data.armor_type:
		node.select(current_data.armor_type)
	else:
		node.select(-1)
		node.text = "⚠ Invalid Data"


## Populates the equipment slot options
func fill_equipment_types() -> void:
	if !database: return
	
	var node = %EquipmentOptions
	node.clear()
	node.add_item("None")
	
	for i in range(1, database.types.equipment_types.size()):
		var item = database.types.equipment_types[i]
		if item.length() == 0:
			item = "# %s" % (i+1)
		node.add_item(item)
	
	var current_data = get_data()
	if current_data and database.types.equipment_types.size() >= current_data.equipment_type:
		node.select(current_data.equipment_type)
	else:
		node.select(-1)
		node.text = "⚠ Invalid Data"


## Populates the armor rarity options with icons
func fill_rarity_types() -> void:
	if !database: return
	
	var node = %ArmorRarityTypeOptions
	node.clear()
	
	for i in database.types.armor_rarity_types.size():
		var item = database.types.armor_rarity_types[i]
		var color = database.types.armor_rarity_color_types[i]
		var icon = Image.create(16, 16, true, Image.FORMAT_RGB8)
		icon.fill_rect(Rect2i(0, 0, 16, 16), color)
		var tex = ImageTexture.create_from_image(icon)
		
		if item.length() == 0:
			item = "# %s" % (i+1)
		node.add_icon_item(tex, item)
	
	var current_data = get_data()
	if current_data and database.types.armor_rarity_types.size() + 1 >= current_data.rarity_type:
		node.select(current_data.rarity_type)
	else:
		node.select(-1)
		node.text = "⚠ Invalid Data"


## Refreshes the user parameters list
func fill_user_parameters(selected_index: int = 0) -> void:
	%UserParametersControl.fill_user_parameters(selected_index)
#endregion


#region UI Interactions
## Clears the armor icon
func _on_icon_picker_remove_requested() -> void:
	get_data().icon.clear()
	%IconPicker.set_icon("")


## Opens the icon selection dialog
func _on_icon_picker_clicked() -> void:
	var path = "res://addons/CustomControls/Dialogs/select_icon_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	dialog.set_data(get_data().icon)
	
	dialog.icon_changed.connect(update_icon)


## Updates the icon preview
func update_icon() -> void:
	var icon = get_data().icon
	%IconPicker.set_icon(icon.path, icon.region)


## Resizes upgrade levels and initializes new ones
func _on_armor_max_levels_spin_box_value_changed(value: float) -> void:
	if not get_data(): return
	var current_data = get_data()
	current_data.upgrades.max_levels = value
	current_data.upgrades.levels.resize(value)
	
	for i in value:
		if current_data.upgrades.levels[i] == null:
			var upgrade = RPGGearUpgradeLevel.new()
			upgrade.user_parameters.resize(database.types.user_parameters.size())
			current_data.upgrades.levels[i] = upgrade
	
	%UpgradeSettingsButton.set_disabled(value == 1)
	%CopyUpgradeList.set_disabled(value == 1)


## Opens the equipment upgrade settings dialog
func _on_upgrade_settings_button_pressed() -> void:
	var path = "res://addons/CustomControls/Dialogs/weapon_and_armor_upgrades_setting_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	dialog.title = tr("Equipment Upgrades Setting")
	dialog.set_data(database, get_data().upgrades)


## Opens the craft materials dialog
func _on_craft_button_pressed() -> void:
	show_craft_dialog("Craft Materials", get_data().craft_materials, "craft_cost")


## Opens the disassemble materials dialog
func _on_disassemble_button_pressed() -> void:
	show_craft_dialog("Disassemble Materials", get_data().disassemble_materials, "disassemble_cost", true)


## Generic function to show the craft/disassemble dialog
func show_craft_dialog(_title: String, mats: Array[RPGGearUpgradeComponent], cost_id: String, percent_enabled: bool = false) -> void:
	var path = "res://addons/CustomControls/Dialogs/weapon_and_armor_craft_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	dialog.title = _title
	
	if percent_enabled:
		dialog.enabled_percent(true)
		
	dialog.set_data(database, mats, get_data()[cost_id])
	dialog.materials_changed.connect(_on_craft_material_changed.bind(mats, cost_id))


## Updates materials and costs when the dialog is accepted
func _on_craft_material_changed(new_mats: Array[RPGGearUpgradeComponent], cost: int, real_mats: Array[RPGGearUpgradeComponent], cost_id: String ) -> void:
	get_data()[cost_id] = cost
	real_mats.clear()
	for mat in new_mats:
		real_mats.append(mat)


## Updates rarity selection
func _on_armor_rarity_type_options_item_selected(index: int) -> void:
	get_data().rarity_type = index


## Updates price selection
func _on_price_spin_box_value_changed(value: float) -> void:
	get_data().price = value


## Updates equipment type selection
func _on_equipment_options_item_selected(index: int) -> void:
	get_data().equipment_type = index


## Updates armor type selection
func _on_armor_type_options_item_selected(index: int) -> void:
	get_data().armor_type = index


## Updates description text
func _on_description_text_edit_text_changed() -> void:
	get_data().description = %DescriptionTextEdit.text


## Updates notes text
func _on_note_text_edit_text_changed() -> void:
	get_data().notes = %NoteTextEdit.text


## Updates effect tick interval
func _on_tick_interval_value_changed(value: float) -> void:
	get_data().tick_interval = value


## Handles icon pasting from clipboard
func _on_icon_picker_paste_requested(icon: String, region: Rect2) -> void:
	var data_icon = get_data().icon
	data_icon.path = icon
	data_icon.region = region
	%IconPicker.set_icon(data_icon.path, data_icon.region)


## Updates max stack quantity
func _on_max_quantity_value_changed(value: float) -> void:
	if get_data():
		get_data().max_quantity = value
#endregion


#region LPC and File Management
## Clears the LPC part path
func _on_lpc_part_button_middle_click_pressed() -> void:
	get_data().lpc_part = ""
	%LPCPartButton.text = tr("Select LPC Equipment")


## Helper to open the file selection dialog
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


## Opens the file dialog for LPC armor parts
func _on_lpc_part_button_pressed() -> void:
	var dialog = await open_file_dialog()
	dialog.target_callable = update_lpc_part
	dialog.set_file_selected(get_data().lpc_part)
	dialog.fill_files("equipment_parts_others")


## Updates the LPC part path and button text
func update_lpc_part(path: String) -> void:
	get_data().lpc_part = path
	
	if path.length() > 0:
		%LPCPartButton.text = path
	else:
		%LPCPartButton.text = tr("Select LPC Equipment")
#endregion


#region Clipboard Operations
## Copies the upgrade list to the clipboard
func _on_copy_upgrade_list_pressed() -> void:
	var current_data = get_data()
	StaticEditorVars.CLIPBOARD.upgrade_list = current_data.upgrades.clone(true)
	%PasteUpgradeList.set_disabled(false)
	RPGEditorToast.show_message("Gear upgrade list copied to Clipboard")


## Pastes the upgrade list from the clipboard
func _on_paste_upgrade_list_pressed() -> void:
	var upgrade_data = StaticEditorVars.CLIPBOARD.get("upgrade_list", null)
	if upgrade_data:
		var current_data = get_data()
		current_data.upgrades = upgrade_data.clone(true)
		%ArmorMaxLevelsSpinBox.value = current_data.upgrades.max_levels


## Copies craft materials to the clipboard
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


## Pastes craft materials from the clipboard
func _on_paste_craft_pressed() -> void:
	var items_craft = StaticEditorVars.CLIPBOARD.get("items_craft", null)
	if items_craft:
		var components = []
		for component: RPGGearUpgradeComponent in items_craft.components:
			components.append(component.clone(true))
		var current_data = get_data()
		current_data.craft_materials = components
		current_data.craft_cost = items_craft.cost


## Copies disassemble materials to the clipboard
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


## Pastes disassemble materials from the clipboard
func _on_paste_disassemble_pressed() -> void:
	var items_disassemble = StaticEditorVars.CLIPBOARD.get("items_disassemble", null)
	if items_disassemble:
		var components = []
		for component: RPGGearUpgradeComponent in items_disassemble.components:
			components.append(component.clone(true))
		var current_data = get_data()
		current_data.disassemble_materials = components
		current_data.disassemble_cost = items_disassemble.cost


## Handles tab changing logic
func _on_config_data_tabs_tab_changed(index: int) -> void:
	var node_path = "%%Tab%s" % (index + 1)
	var node = get_node_or_null(node_path)
	if node:
		for child in node.get_parent().get_children():
			child.visible = false
		node.visible = true
#endregion


func _on_requires_actor_level_value_changed(value: float) -> void:
	get_data().equipment_restriction.level_restriction = value


func _on_requires_actor_class_item_selected(index: int) -> void:
	var real_index = 0 if index == 0 else %RequiresActorClass.get_item_metadata(index)
	get_data().equipment_restriction.class_restriction = real_index


func _on_requires_actor_gender_item_selected(index: int) -> void:
	get_data().equipment_restriction.gender_restriction = index
