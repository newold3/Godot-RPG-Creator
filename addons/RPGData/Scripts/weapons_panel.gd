@tool
extends BasePanelData

#region Variables
#endregion



#region Lifecycle
## Called when the node enters the scene tree for the first time
func _ready() -> void:
	super()
	default_data_element = RPGWeapon.new()
	_fill_usage_restriction()
	item_created.connect(_on_weapon_created)
	%UserParametersControl.data = data
	%UserParametersControl.default_data_element = default_data_element
	%DefaultParametersControl.set_title(tr("Parameters (when weapon is level 1)"))


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


## Initializes user parameters for newly created weapons
func _on_weapon_created(weapon: RPGWeapon) -> void:
	weapon.user_parameters.resize(database.types.user_parameters.size())
	for i in database.types.user_parameters.size():
		weapon.user_parameters[i] = database.types.user_parameters[i].default_value



## Retrieves the currently selected weapon data
func get_data() -> RPGWeapon:
	if not data: return null
	current_selected_index = max(1, min(current_selected_index, data.size() - 1))
	if data.size() > current_selected_index:
		return data[current_selected_index]
	else:
		return default_data_element
#endregion



#region Core Data Loading
## Updates all the visual fields based on the selected weapon
func _update_data_fields() -> void:
	busy = true
	
	%UserParametersControl.current_selected_index = current_selected_index
	
	if current_selected_index != -1:
		disable_all(false)
		fill_weapon_types()
		fill_rarity_types()
		fill_user_parameters()
		fill_animation()
		
		var current_data = get_data()
		if current_data.tools_family == null:
			current_data.tools_family = []
			
		fill_tools(current_data.tools_family)
		%NameLineEdit.text = current_data.name
		%IconPicker.set_icon(current_data.icon.path, current_data.icon.region)
		%TraitsPanel.set_data(database, current_data.traits)
		%DescriptionTextEdit.text = current_data.description
		%PriceSpinBox.value = current_data.price
		%MaxQuantity.value = current_data.max_quantity
		
		%DefaultParametersControl.set_data(current_data.params)
		
		%WeaponMaxLevelsSpinBox.value = current_data.upgrades.max_levels
		%NoteTextEdit.text = current_data.notes
		%UpgradeSettingsButton.set_disabled(current_data.upgrades.max_levels == 1)
		
		%CopyUpgradeList.set_disabled(current_data.upgrades.max_levels == 1)
		%PasteUpgradeList.set_disabled(!StaticEditorVars.CLIPBOARD.get("upgrade_list", false))
		%PasteCraft.set_disabled(!StaticEditorVars.CLIPBOARD.get("items_craft", false))
		%PasteDisassemble.set_disabled(!StaticEditorVars.CLIPBOARD.get("items_disassemble", false))
		
		_fill_equipment_restriction()
		
		%InMapAttackPower.value = current_data.map_damage
		update_lpc_part_text()
		
	else:
		disable_all(true)

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


## Handles visibility changes
func _on_visibility_changed() -> void:
	super()
	if visible:
		if not get_data(): return
		busy = true
		fill_weapon_types()
		fill_rarity_types()
		fill_user_parameters()
		fill_animation()
		fill_tools(get_data().tools_family)
		_fill_usage_restriction()
		if current_selected_index != -1:
			%TraitsPanel.set_data(database, get_data().traits)
		else:
			%TraitsPanel.clear()
			
		busy = false
#endregion



#region Dropdowns and Lists Setup
## Formats the animation button text handling UIDs and Legacy IDs
func fill_animation() -> void:
	if !database: return
	
	var node = %AnimationButton
	var current_data = get_data()
	var uid = current_data.animation
	
	if uid > 0:
		if uid < 1000000:
			uid = RPGSYSTEM.id_to_uid("animations", uid)
			current_data.animation = uid
			
		var anim_data = RPGSYSTEM.get_data("animations", uid)
		if anim_data:
			var classic_id = RPGSYSTEM.uid_to_id("animations", uid)
			var id_padded = str(classic_id).pad_zeros(str(database.animations.size()).length())
			var anim_name = anim_data.name if not anim_data.name.is_empty() else "# %s" % classic_id
			node.text = "%s: %s" % [id_padded, anim_name]
		else:
			node.text = "⚠ Invalid Data"
	else:
		node.text = tr("None")



## Populates the weapon type options
func fill_weapon_types() -> void:
	if !database: return
	
	var node = %WeaponTypeOptions
	node.clear()
	node.add_item("None")
	
	if database:
		for i in database.types.weapon_types.size():
			var item = database.types.weapon_types[i]
			if item.length() == 0:
				item = "# %s" % (i+1)
			node.add_item(item)
	
	var current_data = get_data()
	if database.types.weapon_types.size() >= current_data.weapon_type:
		node.select(current_data.weapon_type)
	else:
		node.select(-1)
		node.text = "⚠ Invalid Data"



## Populates the weapon rarity options
func fill_rarity_types() -> void:
	if !database: return
	
	var node = %WeaponRarityTypeOptions
	node.clear()
	
	if database:
		for i in database.types.weapon_rarity_types.size():
			var item = database.types.weapon_rarity_types[i]
			var color = database.types.weapon_rarity_color_types[i]
			var icon = Image.create(16, 16, true, Image.FORMAT_RGB8)
			icon.fill_rect(Rect2i(0, 0, 16, 16), color)
			var tex = ImageTexture.create_from_image(icon)
			if item.length() == 0:
				item = "# %s" % (i+1)
			node.add_icon_item(tex, item)
	
	var current_data = get_data()
	if database.types.weapon_rarity_types.size() + 1 >= current_data.rarity_type:
		node.select(current_data.rarity_type)
	else:
		node.select(-1)
		node.text = "⚠ Invalid Data"



## Populates the tools family multi-selection list
func fill_tools(_selected_ids: PackedInt32Array) -> void:
	var node = %Tools
	node.clear()
	node.add_item("none")
	
	if not get_data(): 
		if not node.multi_selection_changed.is_connected(_on_tools_multi_selection_changed):
			node.multi_selection_changed.connect(_on_tools_multi_selection_changed)
		return
	
	var selected_tools = _selected_ids
	if 0 in selected_tools:
		node.set_item_selected(0, true, true)

	for i in database.types.tool_types.size():
		var tool = database.types.tool_types[i]
		var item_index = i + 1 
		var icon = database.types.icons.tool_icons[i]
		
		if AssetManager.file_exists(icon.path):
			node.add_icon_item(load(icon.path), "Tool %s: %s" % [i + 1, tool], item_index)
		else:
			node.add_item("Tool %s: %s" % [i + 1, tool], item_index)

		if item_index in selected_tools:
			node.set_item_selected(item_index, true, true)



## Populates the user parameters list
func fill_user_parameters(selected_index: int = 0) -> void:
	%UserParametersControl.fill_user_parameters(selected_index)
#endregion



#region UI Interactions
## Clears the icon assignment
func _on_icon_picker_remove_requested() -> void:
	get_data().icon.clear()
	%IconPicker.set_icon("")



## Opens the icon picker dialog
func _on_icon_picker_clicked() -> void:
	var path = "res://addons/CustomControls/Dialogs/select_icon_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	dialog.set_data(get_data().icon)
	dialog.icon_changed.connect(update_icon)



## Refreshes the icon picker preview
func update_icon() -> void:
	var icon = get_data().icon
	%IconPicker.set_icon(icon.path, icon.region)



## Updates description notes
func _on_description_text_edit_text_changed() -> void:
	get_data().description = %DescriptionTextEdit.text



## Updates weapon type assignment
func _on_weapon_type_options_item_selected(index: int) -> void:
	get_data().weapon_type = index



## Updates weapon price
func _on_price_spin_box_value_changed(value: float) -> void:
	get_data().price = value



## Opens animation selection dialog
func _on_animation_button_button_pressed() -> void:
	var path = "res://addons/CustomControls/Dialogs/select_any_data_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	dialog.database = database
	dialog.destroy_on_hide = true
	dialog.set_animation_mode()
	
	var current_anims = database.animations
	var uid = get_data().animation
	var classic_id = RPGSYSTEM.uid_to_id("animations", uid) if uid > 0 else 1
	classic_id = max(1, min(classic_id, current_anims.size() - 1))
	
	dialog.selected.connect(_on_animation_selected, CONNECT_ONE_SHOT)
	dialog.setup(current_anims, classic_id, tr("Animations"), self)



## Updates animation UID selection
func _on_animation_selected(id: int, target: Variant) -> void:
	var uid = RPGSYSTEM.id_to_uid("animations", id)
	get_data().animation = uid
	fill_animation()



## Clears assigned animation
func _on_animation_button_middle_click_pressed() -> void:
	get_data().animation = -1
	fill_animation()


## Resizes upgrade level array and initializes levels
func _on_weapon_max_levels_spin_box_value_changed(value: float) -> void:
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



## Opens weapon upgrade settings dialog
func _on_upgrade_settings_button_pressed() -> void:
	var path = "res://addons/CustomControls/Dialogs/weapon_and_armor_upgrades_setting_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	dialog.title = tr("Weapon Upgrades Setting")
	dialog.set_data(database, get_data().upgrades)



## Updates notes text
func _on_note_text_edit_text_changed() -> void:
	get_data().notes = %NoteTextEdit.text



## Handles rarity type selection
func _on_weapon_rarity_type_options_item_selected(index: int) -> void:
	get_data().rarity_type = index



## Opens craft materials dialog
func _on_craft_button_pressed() -> void:
	show_craft_dialog(tr("Craft Materials"), get_data().craft_materials, "craft_cost")



## Opens disassemble materials dialog
func _on_disassemble_button_pressed() -> void:
	show_craft_dialog(tr("Disassemble Materials"), get_data().disassemble_materials, "disassemble_cost", true)



## Generic craft dialog launcher
func show_craft_dialog(_title: String, mats: Array[RPGGearUpgradeComponent], cost_id: String, percent_enabled: bool = false) -> void:
	var path = "res://addons/CustomControls/Dialogs/weapon_and_armor_craft_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	dialog.title = _title
	
	if percent_enabled:
		dialog.enabled_percent(true)
		
	dialog.set_data(database, mats, get_data()[cost_id])
	dialog.materials_changed.connect(_on_craft_material_changed.bind(mats, cost_id))



## Callback for craft/disassemble material changes
func _on_craft_material_changed(new_mats: Array[RPGGearUpgradeComponent], cost: int, real_mats: Array[RPGGearUpgradeComponent], cost_id: String ) -> void:
	get_data()[cost_id] = cost
	real_mats.clear()
	for mat in new_mats:
		real_mats.append(mat)



## Clears LPC part configuration
func _on_lpc_part_button_middle_click_pressed() -> void:
	get_data().lpc_part = ""
	get_data().lpc_part_custom_script = ""
	update_lpc_part_text()



## Opens generic file selection dialog
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



## Opens LPC part selection dialog
func _on_lpc_part_button_pressed() -> void:
	var dialog = await open_file_dialog()
	dialog.target_callable = update_lpc_part
	dialog.set_file_selected(get_data().lpc_part)
	dialog.fill_files("equipment_parts_weapons")



## Updates LPC part path
func update_lpc_part(path: String) -> void:
	get_data().lpc_part = path
	update_lpc_part_text(true)



## Refreshes LPC weapon info and projectile/melee logic
func update_lpc_part_text(update_ammo: bool = false, update_cache: bool = false) -> void:
	var data_obj = get_data()
	var path: String = data_obj.lpc_part
	
	if not path.is_empty():
		%LPCPartButton.text = path
	else:
		%LPCPartButton.text = tr("Select LPC Weapon")
		
	var script_path: String = ""
	var cache_id: String = ""
	var projectile_id: String = ""
	var is_melee: bool = true
	
	if AssetManager.file_exists(path):
		var res = load(path)
		var tags = Array(res.tags)
		var valid_tags = tags.filter(func(tag: String): return not tag.to_lower() in ["mainhand", "weapon", "large"])
		
		%LPCPartInfo.text = tr("Detected part: ") + ", ".join(valid_tags)
		
		var ammo = res.get("ammo")
		if ammo and not ammo.config_path.is_empty():
			var json_text = ZipMediaLoader.get_text_content(ammo.config_path)
			if not json_text.is_empty():
				var config = JSON.parse_string(json_text)
				if config and typeof(config) == TYPE_DICTIONARY:
					projectile_id = config.get("projectile", "")
					if not projectile_id.is_empty():
						cache_id = "projectile_default_" + projectile_id
						is_melee = false
		
		if is_melee:
			cache_id = "melee_attack_default"
		
		if update_ammo:
			data_obj.lpc_part_custom_script = ""
			if not cache_id.is_empty():
				script_path = FileCache.options.get(cache_id, "")
				if script_path.is_empty():
					var default_path = "res://Scenes/OtherScenes/IngameProjectil/"
					if is_melee:
						script_path = default_path + "melee_base.gd"
					else:
						match projectile_id:
							"boomerang": script_path = default_path + "projectile_boomerang_base.gd"
							"rock": script_path = default_path + "projectile_rock_base.gd"
							"bolt": script_path = default_path + "projectile_bolt_base.gd"
							"arrow": script_path = default_path + "projectile_arrow_base.gd"
							"arcane1": script_path = default_path + "projectile_arcane_base.gd"
							_: script_path = ""
				data_obj.lpc_part_custom_script = script_path
		else:
			script_path = data_obj.lpc_part_custom_script
			
		if update_cache and not cache_id.is_empty() and not script_path.is_empty():
			FileCache.options[cache_id] = script_path
			
		var is_valid_script = not script_path.is_empty()
		var same_as_cache = (FileCache.options.get(cache_id, "") == script_path) if not cache_id.is_empty() else false
			
		%SetAttackScriptAsDefault.set_pressed_no_signal(same_as_cache)
		%SetAttackScriptAsDefault.set_disabled(not is_valid_script or cache_id.is_empty())
		%ConfigScript.set_disabled(not is_valid_script)
		
	else:
		%LPCPartInfo.text = tr("No weapon part selected.")
		data_obj.lpc_part_custom_script = ""
		%SetAttackScriptAsDefault.set_pressed_no_signal(false)
		%SetAttackScriptAsDefault.set_disabled(true)
		%ConfigScript.set_disabled(true)
		
	if data_obj.lpc_part_custom_script.is_empty():
		%LPCPartScript.text = tr("No script installed.")
	else:
		%LPCPartScript.text = tr("Script installed:") + " " + data_obj.lpc_part_custom_script



## Copies upgrade configuration to clipboard
func _on_copy_upgrade_list_pressed() -> void:
	var current_data = get_data()
	StaticEditorVars.CLIPBOARD.upgrade_list = current_data.upgrades.clone(true)
	%PasteUpgradeList.set_disabled(false)
	RPGEditorToast.show_message("Gear upgrade list copied to Clipboard")



## Pastes upgrade configuration from clipboard
func _on_paste_upgrade_list_pressed() -> void:
	var upgrade_data = StaticEditorVars.CLIPBOARD.get("upgrade_list", null)
	if upgrade_data:
		var current_data = get_data()
		current_data.upgrades = upgrade_data.clone(true)
		%WeaponMaxLevelsSpinBox.value = current_data.upgrades.max_levels


## Copies craft materials to clipboard
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



## Pastes craft materials from clipboard
func _on_paste_craft_pressed() -> void:
	var current_data = get_data()
	var items_craft = StaticEditorVars.CLIPBOARD.get("items_craft", null)
	if items_craft:
		var components = []
		for component: RPGGearUpgradeComponent in items_craft.components:
			components.append(component.clone(true))
		current_data.craft_materials = components
		current_data.craft_cost = items_craft.cost



## Copies disassemble materials to clipboard
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



## Pastes disassemble materials from clipboard
func _on_paste_disassemble_pressed() -> void:
	var current_data = get_data()
	var items_disassemble = StaticEditorVars.CLIPBOARD.get("items_disassemble", null)
	if items_disassemble:
		var components = []
		for component: RPGGearUpgradeComponent in items_disassemble.components:
			components.append(component.clone(true))
		current_data.disassemble_materials = components
		current_data.disassemble_cost = items_disassemble.cost



## Handles tab switches in the config view
func _on_config_data_tabs_tab_changed(index: int) -> void:
	var node_path = "%%Tab%s" % (index + 1)
	var node = get_node_or_null(node_path)
	if node:
		for child in node.get_parent().get_children():
			child.visible = false
		node.visible = true



## Updates tick interval for effects
func _on_tick_interval_value_changed(value: float) -> void:
	get_data().tick_interval = value



## Pastes icon from clipboard
func _on_icon_picker_paste_requested(icon: String, region: Rect2) -> void:
	var data_icon = get_data().icon
	data_icon.path = icon
	data_icon.region = region
	%IconPicker.set_icon(data_icon.path, data_icon.region)


## Logic for tools family multi-selection (mutual exclusion with 'none')
func _on_tools_multi_selection_changed(selected_ids: PackedInt32Array) -> void:
	var node = %Tools
	var clicked_index = node.get_hovered_item_index()
	if clicked_index != -1:
		if clicked_index == 0:
			for id in selected_ids:
				if id != 0:
					node.set_item_selected(id, false)
		elif selected_ids[0] == 0:
			node.set_item_selected(0, false)
	
	get_data().tools_family.clear()
	selected_ids = node.get_selected_items()
	get_data().tools_family.append_array(PackedInt32Array(selected_ids))



## Resets tool family to 'none' via middle click
func _on_tools_middle_click() -> void:
	get_data().tools_family.clear()
	await get_tree().process_frame
	await get_tree().process_frame
	get_data().tools_family.append(0)
	fill_tools(get_data().tools_family)



## Opens file picker for custom attack script
func _on_config_script_pressed() -> void:
	var dialog = await open_file_dialog()
	dialog.target_callable = update_attack_script
	dialog.set_file_selected(get_data().lpc_part_custom_script)
	dialog.fill_files("weapon_attack_scripts")



## Updates attack script path
func update_attack_script(path: String) -> void:
	get_data().lpc_part_custom_script = path
	update_lpc_part_text(false)



## Updates default script preference in cache
func _on_set_attack_script_as_default_toggled(toggled_on: bool) -> void:
	update_lpc_part_text(false, toggled_on)



## Updates map attack power
func _on_in_map_attack_power_value_changed(value: float) -> void:
	if not busy and get_data():
		get_data().map_damage = value



## Updates max stack quantity
func _on_max_quantity_value_changed(value: float) -> void:
	if get_data():
		get_data().max_quantity = value
#endregion


func _on_requires_actor_level_value_changed(value: float) -> void:
	get_data().equipment_restriction.level_restriction = value


func _on_requires_actor_class_item_selected(index: int) -> void:
	var real_index = 0 if index == 0 else %RequiresActorClass.get_item_metadata(index)
	get_data().equipment_restriction.class_restriction = real_index


func _on_requires_actor_gender_item_selected(index: int) -> void:
	get_data().equipment_restriction.gender_restriction = index
