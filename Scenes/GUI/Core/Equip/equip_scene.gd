class_name GuiCoreEquipScene
extends MarginContainer

#region SignalsAndVariables
signal update_description(description: String)
signal back_pressed()
signal actor_changed(actor: GameActor)
signal sub_menu_state_changed(is_open: bool)

@export var remove_item_icon: Texture2D = preload("uid://cy1pny48ukkqg")

var current_actor: GameActor
#endregion

#region VirtualGetters
func get_stats_container() -> Control:
	if has_node("%StatsContainer"):
		return get_node("%StatsContainer")
	return null


func get_equipment_container() -> Control:
	if has_node("%EquipmentContainer"):
		return get_node("%EquipmentContainer")
	return null


func get_main_actor_container() -> Control:
	if has_node("%MainActorContainer"):
		return get_node("%MainActorContainer")
	return null


func get_buttons_vertical_menu() -> Control:
	if has_node("%ButtonsVerticalMenu"):
		return get_node("%ButtonsVerticalMenu")
	return null


func get_menu_items() -> Control:
	if has_node("%MenuItems"):
		return get_node("%MenuItems")
	return null


func get_current_selected_equipment_container() -> Control:
	if has_node("%CurrentSelectedEquipmentContainer"):
		return get_node("%CurrentSelectedEquipmentContainer")
	return null


func get_costume_button_container() -> Control:
	if has_node("%CostumeButtonContainer"):
		return get_node("%CostumeButtonContainer")
	return null


func get_set_icon() -> TextureRect:
	if has_node("%SetIcon"):
		return get_node("%SetIcon")
	return null


func get_costume_button() -> Control:
	if has_node("%CostumeButton"):
		return get_node("%CostumeButton")
	return null
#endregion

#region VirtualHooks
func _animate_start(on_complete: Callable = Callable()) -> void:
	if on_complete:
		on_complete.call()


func _show_menu_visual(on_complete: Callable = Callable()) -> void:
	if on_complete:
		on_complete.call()


func _hide_menu_visual(on_complete: Callable = Callable()) -> void:
	if on_complete:
		on_complete.call()


func _set_help_text(_help: String) -> void:
	pass


func _update_costume_icon_visual(_texture: Texture2D) -> void:
	pass


func _play_ui_sound(_sound_name: String) -> void:
	pass


func _on_item_equipped_visual(_slot_id: int) -> void:
	pass
#endregion

#region InitializationAndCore
func _ready() -> void:
	GameManager.set_cursor_manipulator(GameManager.MANIPULATOR_MODES.NONE)
	ControllerManager.controller_changed.connect(_on_controlled_changed)
	_on_controlled_changed(ControllerManager.current_controller)
	if current_actor:
		set_actor(current_actor)
	start()


func start() -> void:
	var stats = get_stats_container()
	var buttons = get_buttons_vertical_menu()
	var equip = get_equipment_container()
	if stats and stats.has_method("start"): stats.start()
	if buttons and buttons.has_method("start"): buttons.start()
	if equip and equip.has_method("start"): equip.start()
	_animate_start()


func end() -> void:
	var stats = get_stats_container()
	var buttons = get_buttons_vertical_menu()
	var equip = get_equipment_container()
	if stats and stats.has_method("end"): stats.end()
	if buttons and buttons.has_method("end"): buttons.end()
	if equip and equip.has_method("end"): equip.end()


func destroy() -> void:
	_play_ui_sound("cancel")
	GameManager.set_cursor_manipulator(GameManager.MANIPULATOR_MODES.NONE)
	back_pressed.emit()
#endregion

#region ActorAndInputManagement
func _change_actor(actor_id: int) -> void:
	var actor: GameActor = GameManager.get_actor(actor_id)
	if actor:
		set_actor(actor)
	current_actor = actor


func set_actor(actor: GameActor) -> void:
	current_actor = actor
	if not is_inside_tree(): return
	var stats = get_stats_container()
	var equip = get_equipment_container()
	var actor_cnt = get_main_actor_container()
	if stats and stats.has_method("set_actor"): stats.set_actor(actor)
	if equip and equip.has_method("set_actor"): equip.set_actor(actor)
	if actor_cnt and actor_cnt.has_method("set_actor"): actor_cnt.set_actor(actor)
	_update_costume_icon()
	var selected_slot = equip.button_selected if equip and "button_selected" in equip and equip.button_selected >= 0 else 0
	_on_equipment_slot_selected(selected_slot)
	actor_changed.emit(actor)


func _update_costume_icon() -> void:
	if not is_inside_tree(): return
	if current_actor and current_actor.current_set:
		var real_item = current_actor.current_set.get_real_data()
		if real_item:
			var path = real_item.lpc_part
			var preview_path = path.get_basename().trim_suffix("_data") + "_preview.png"
			if AssetManager.exists(preview_path):
				var tex = ResourceLoader.load(preview_path)
				_update_costume_icon_visual(tex)
				return
	_update_costume_icon_visual(null)


func _setup_initial_selection() -> void:
	if current_actor:
		var buttons = get_buttons_vertical_menu()
		var equip = get_equipment_container()
		if buttons and buttons.has_method("select"):
			buttons.select(current_actor.id, true)
		if equip and equip.has_method("select_last_slot"):
			equip.select_last_slot()
		GameManager.force_hand_position_over_node(GameManager.get_cursor_manipulator())


func _on_controlled_changed(type: ControllerManager.CONTROLLER_TYPE) -> void:
	var help: String = ""
	if type == ControllerManager.CONTROLLER_TYPE.Joypad:
		help = tr("L1/R1 Change Actor  RS Stats Navigate  D-Pad Select Equipment  A Ok  B Cancel")
	else:
		help = tr("Q/E Change Actor  Mouse Stats Navigate  W/A/S/D Select Equipment  Space Ok  Escape Cancel")
	_set_help_text(help)


func _on_actors_menu_button_selected(_actor_index: int) -> void:
	_play_ui_sound("cursor")
#endregion

#region EquipmentSlotAndInventoryLogic
func _on_equipment_container_slot_clicked(slot_id: int) -> void:
	_process_start_change_equip(slot_id)


func _on_equipment_slot_selected(slot_id: int) -> void:
	var card = get_current_selected_equipment_container()
	var equip = get_equipment_container()
	if current_actor and slot_id >= 0 and current_actor.current_gear.size() > slot_id:
		var obj = current_actor.current_gear[slot_id]
		if obj:
			var real_item: Variant
			if obj is GameWeapon:
				real_item = RPGSYSTEM.get_data("weapons", obj.id)
			elif obj is GameArmor:
				real_item = RPGSYSTEM.get_data("armors", obj.id)
				
			if real_item:
				update_description.emit(real_item.description)
				var formatted_item = equip._get_item_display_data(obj, slot_id) if equip and equip.has_method("_get_item_display_data") else {}
				formatted_item.current_level = obj.current_level if "current_level" in obj else 1
				formatted_item.max_level = real_item.upgrades.max_levels if "upgrades" in real_item and real_item.upgrades else 1
				formatted_item.current_experience = obj.current_experience if "current_experience" in obj else 0.0
				formatted_item.next_experience = obj.get_next_level_experience() if obj.has_method("get_next_level_experience") else 1.0
				formatted_item.icon = real_item.icon
				if card and card.has_method("set_item"):
					card.set_item(formatted_item)
				return
	
	update_description.emit("")
	if card and card.has_method("set_item"):
		card.set_item({})


func _process_start_change_equip(slot_id: int) -> void:
	var equip = get_equipment_container()
	var menu = get_menu_items()
	if not equip: return
	if menu and "is_enabled" in menu and menu.is_enabled: return
	var current_button_selected = equip.get_button_selected() if equip.has_method("get_button_selected") else null
	if not current_button_selected or (current_button_selected and "disabled" in current_button_selected and current_button_selected.disabled):
		_play_ui_sound("error")
		return
	
	var button_selected = slot_id
	var data = GameManager.game_state.weapons if button_selected == 0 else GameManager.game_state.armors
	var equippable_items = []
	
	for item_arr: Array in data.values():
		var item = item_arr[0]
		if item is GameArmor:
			var real_armor = RPGSYSTEM.get_data("armors", item.id)
			if real_armor:
				if real_armor.equipment_type != 0 and real_armor.equipment_type != button_selected:
					continue
			else:
				continue
				
		if current_actor.can_equip(button_selected, item.id):
			var equippable_item = {
				"levels": {},
				"total": 0
			}
			for obj in item_arr:
				var available_amount = obj.quantity - obj.total_equipped
				if available_amount > 0:
					if not obj.current_level in equippable_item.levels:
						equippable_item.levels[obj.current_level] = {
							"item": obj,
							"is_new_item": obj.newly_added
						}
					equippable_item.total += available_amount
						
			if equippable_item.total > 0:
				equippable_items.append(equippable_item)

	var formatted_items: Array[Dictionary] = []
	var inner_icon_cache: Dictionary = {}
	
	for item in equippable_items:
		var color_data = RPGSYSTEM.database.types.weapon_rarity_color_types if button_selected == 0 else RPGSYSTEM.database.types.armor_rarity_color_types
		for level in item.levels:
			var current_item = item.levels[level].item
			var real_item = null
			if current_item is GameWeapon:
				real_item = RPGSYSTEM.get_data("weapons", current_item.id)
			elif current_item is GameArmor:
				real_item = RPGSYSTEM.get_data("armors", current_item.id)
				
			if real_item:
				var tex = null
				if AssetManager.exists(real_item.icon.path):
					var icon_id = "%s_%s" % [real_item.icon.path, real_item.icon.region]
					if not icon_id in inner_icon_cache:
						var t = ResourceLoader.load(real_item.icon.path)
						if real_item.icon.region:
							tex = ImageTexture.create_from_image(t.get_image().get_region(real_item.icon.region))
						else:
							tex = t
						inner_icon_cache[icon_id] = tex
					else:
						tex = inner_icon_cache[icon_id]

				var new_item = {
					"current_item": current_item,
					"icon": tex,
					"name": real_item.name,
					"quantity": item.total,
					"disabled": false,
					"color": color_data[real_item.rarity_type],
					"level": level,
					"is_new_item": item.levels[level].is_new_item
				}
				formatted_items.append(new_item)
		
	var curren_equipped_item = current_actor.get_equip_in_slot(slot_id)
	if menu and menu.has_method("set_curren_equipped_item"):
		menu.set_curren_equipped_item(curren_equipped_item)
	
	_play_ui_sound("ok")
	
	formatted_items.sort_custom(func(a, b):
		if a.is_new_item != b.is_new_item:
			return a.is_new_item and not b.is_new_item
		var cmp = a.name.naturalnocasecmp_to(b.name)
		if cmp != 0:
			return cmp < 0
		return a.level > b.level
	)
	
	var remove_item = {
		"name": "- " + tr("Remove equip") + " -",
		"icon": remove_item_icon,
		"disabled": false,
		"color": Color.WHITE,
		"is_new_item": false
	}
	formatted_items.insert(0, remove_item)
	if menu and menu.has_method("set_items"):
		menu.set_items(formatted_items)
	
	if current_actor:
		current_actor.is_comparation_enabled = true
		
	_show_menu()


func _process_start_change_costume() -> void:
	var menu = get_menu_items()
	var equip = get_equipment_container()
	if menu and "is_enabled" in menu and menu.is_enabled: return
	var equippable_costumes = GameManager.inventory_manager.get_equippable_items(current_actor, -1, 0, false)
	var formatted_items: Array[Dictionary] = []
	var inner_icon_cache: Dictionary = {}
	
	for item_dict in equippable_costumes:
		var current_item = item_dict.item
		var real_item = item_dict.real_item
		if not real_item:
			continue
			
		var tex = null
		if item_dict.icon and item_dict.icon.path:
			var icon_id = "%s_%s" % [item_dict.icon.path, item_dict.icon.region]
			if not icon_id in inner_icon_cache:
				if AssetManager.exists(item_dict.icon.path):
					var t = ResourceLoader.load(item_dict.icon.path)
					if item_dict.icon.region:
						tex = ImageTexture.create_from_image(t.get_image().get_region(item_dict.icon.region))
					else:
						tex = t
					inner_icon_cache[icon_id] = tex
			else:
				tex = inner_icon_cache[icon_id]
				
		var new_item = {
			"current_item": current_item,
			"icon": tex,
			"name": real_item.name,
			"quantity": item_dict.quantity,
			"disabled": item_dict.is_disabled,
			"color": item_dict.item_color,
			"level": -1,
			"is_new_item": item_dict.is_new
		}
		formatted_items.append(new_item)
		
	var curren_equipped_item = current_actor.current_set
	if menu and menu.has_method("set_curren_equipped_item"):
		menu.set_curren_equipped_item(curren_equipped_item)
	
	_play_ui_sound("ok")
	
	formatted_items.sort_custom(func(a, b):
		if a.is_new_item != b.is_new_item:
			return a.is_new_item and not b.is_new_item
		return a.name.naturalnocasecmp_to(b.name) < 0
	)
	
	var remove_item = {
		"name": "- " + tr("Remove costume") + " -",
		"icon": remove_item_icon,
		"disabled": false,
		"color": Color.WHITE,
		"is_new_item": false
	}
	formatted_items.insert(0, remove_item)
	if menu and menu.has_method("set_items"):
		menu.set_items(formatted_items)
	
	if current_actor:
		current_actor.is_comparation_enabled = true
		
	if equip and "button_selected" in equip:
		equip.button_selected = -1
		
	_show_menu()
#endregion

#region InventorySubMenuLogic
func _on_menu_items_cancel() -> void:
	_hide_menu()


func _on_menu_items_item_hovered(index: int, item: Dictionary) -> void:
	var equip = get_equipment_container()
	var stats = get_stats_container()
	var card = get_current_selected_equipment_container()
	if index < 0 or not equip: return
	var slot_id = equip.button_selected if "button_selected" in equip else 0
	var obj = item.get("current_item", null)
	var description_setted = false
	
	if obj:
		var real_item: Variant
		if obj is GameWeapon:
			real_item = RPGSYSTEM.get_data("weapons", obj.id)
		elif obj is GameArmor:
			real_item = RPGSYSTEM.get_data("armors", obj.id)
		elif obj is IngameCostume or obj is IngameGearSet:
			real_item = RPGSYSTEM.get_data("costumes", obj.id)
			
		if real_item:
			update_description.emit(real_item.description)
			description_setted = true
			if stats and stats.has_method("set_equipment_compararison"):
				stats.set_equipment_compararison(slot_id, item.get("current_item", null))
			if card and card.has_method("set_item"):
				var preview_item = {
					"item_name": tr(real_item.name),
					"item_color": item.get("color", Color.WHITE),
					"icon": real_item.icon,
					"tex": item.get("icon", null),
					"current_level": obj.current_level if "current_level" in obj else item.get("level", 1),
					"max_level": real_item.upgrades.max_levels if "upgrades" in real_item and real_item.upgrades else 1,
					"current_experience": obj.current_experience if "current_experience" in obj else 0.0,
					"next_experience": obj.get_next_level_experience() if obj.has_method("get_next_level_experience") else 1.0
				}
				card.set_item(preview_item)
	
	if not description_setted:
		if slot_id == -1:
			update_description.emit(tr("Remove costume"))
		else:
			update_description.emit(tr("Remove item"))
		if stats and stats.has_method("set_equipment_compararison"):
			stats.set_equipment_compararison(slot_id, null)
		if card and card.has_method("set_item"):
			card.set_item({})


func _on_menu_items_item_selected(index: int, item: Dictionary) -> void:
	_on_menu_items_item_hovered(index, item)


func _on_menu_items_item_clicked(_index: int, item: Dictionary) -> void:
	if current_actor:
		current_actor.is_comparation_enabled = false
		var equip = get_equipment_container()
		var slot_id = equip.button_selected if equip and "button_selected" in equip else 0
		
		if item.get("current_item") != null:
			current_actor.equip_equipment_from_inventory(slot_id, item.current_item)
		else:
			current_actor.remove_current_equipment(slot_id)
			
		set_actor(current_actor)
		
		if GameManager.has_node("PartyManager") and GameManager.party_manager:
			var party_manager = GameManager.party_manager
			for follower in party_manager.followers:
				if follower and is_instance_valid(follower):
					follower.set_meta("requires_init", true)
			party_manager.update_party_visuals(true)
		
		_play_ui_sound("equip")
		_on_item_equipped_visual(slot_id)
			
	_hide_menu()


func _show_menu() -> void:
	_show_menu_visual()
	sub_menu_state_changed.emit(true)


func _hide_menu() -> void:
	if current_actor:
		current_actor.is_comparation_enabled = true
	_hide_menu_visual()
	sub_menu_state_changed.emit(false)
#endregion
