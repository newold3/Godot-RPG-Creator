extends MarginContainer

@export var menu_items_start_position: Vector2
@export var menu_items_end_position: Vector2

var current_actor: GameActor

var main_tween: Tween

@onready var stats_container: Control = %StatsContainer
@onready var equipment_container: Control = %EquipmentContainer
@onready var main_actor_container: VBoxContainer = %MainActorContainer
@onready var buttons_vertical_menu: MarginContainer = %ButtonsVerticalMenu
@onready var menu_items: Control = %MenuItems
@onready var current_selected_equipment_container: Control = %CurrentSelectedEquipmentContainer


signal update_description(description: String)
signal back_pressed()


func _ready() -> void:
	GameManager.set_cursor_manipulator(GameManager.MANIPULATOR_MODES.NONE)
	ControllerManager.controller_changed.connect(_on_controlled_changed)
	_on_controlled_changed(ControllerManager.current_controller)
	start()


func start() -> void:
	stats_container.start()
	buttons_vertical_menu.start()
	equipment_container.start()
	
	if  main_tween:
		main_tween.kill()

	main_tween = create_tween()
	main_tween.set_parallel(true)
	main_tween.tween_property(stats_container, "size:y", 398, 0.5).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN_OUT).from(20)
	main_tween.tween_property(buttons_vertical_menu, "position:x", 0, 0.5).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN_OUT).from(-100)
	main_tween.tween_property(equipment_container, "position:x", 0, 0.5).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN_OUT).from(550)
	main_tween.set_parallel(false)
	main_tween.tween_interval(0.001)
	stats_container.started = true


func end() -> void:
	pass


func _change_actor(actor_id: int) -> void:
	var actor: GameActor = GameManager.get_actor(actor_id)
	if actor:
		set_actor(actor)
	current_actor = actor


func _on_equipment_slot_selected(slot_id: int) -> void:
	if current_actor and slot_id >= 0 and current_actor.current_gear.size() > slot_id:
		var obj = current_actor.current_gear[slot_id]
		if obj:
			var real_item: Variant
			if obj is GameWeapon:
				if obj.id > 0 and RPGSYSTEM.database.weapons.size() > obj.id:
					real_item = RPGSYSTEM.database.weapons[obj.id]
			elif obj is GameArmor:
				if obj.id > 0 and RPGSYSTEM.database.armors.size() > obj.id:
					real_item = RPGSYSTEM.database.armors[obj.id]
			if real_item:
				update_description.emit(real_item.description)
				var formatted_item = equipment_container._get_item_display_data(obj, slot_id)
				formatted_item.current_level = obj.current_level
				formatted_item.max_level = real_item.upgrades.max_levels
				formatted_item.current_experience = obj.current_experience
				formatted_item.next_experience = obj.get_next_level_experience()
				current_selected_equipment_container.set_item(formatted_item)
			else:
				update_description.emit("")
				current_selected_equipment_container.set_item({})
		else:
			update_description.emit("")
			current_selected_equipment_container.set_item({})


func _on_controlled_changed(type: ControllerManager.CONTROLLER_TYPE):
	var help: String = ""
	if type == ControllerManager.CONTROLLER_TYPE.Joypad:
		help = "L1/R1 Change Actor  RS Stats Navigate  D-Pad Select Equipment  A Ok  B Cancel"
	else:
		help = "Q/E Change Actor  Mouse Stats Navigate  W/A/S/D Select Equipment  Space Ok  Escape Cancel"
	%HelpLabel.text = help


func _on_actors_menu_button_selected(_actor_index: int) -> void:
	GameManager.play_fx("cursor")


func set_actor(actor: GameActor) -> void:
	current_actor = actor
	stats_container.set_actor(actor)
	equipment_container.set_actor(actor)
	main_actor_container.set_actor(actor)


func _setup_initial_selection() -> void:
	if current_actor:
		buttons_vertical_menu.select(current_actor.id, true)
		equipment_container.select_last_slot()
		GameManager.force_hand_position_over_node(GameManager.get_cursor_manipulator())


func _on_equipment_container_slot_clicked(slot_id: int) -> void:
	_process_start_change_equip(slot_id)


func _process_start_change_equip(slot_id: int) -> void:
	var current_button_selected = equipment_container.get_button_selected()
	if not current_button_selected or (current_button_selected and current_button_selected.disabled):
		GameManager.play_fx("error")
		return
	
	var button_selected = slot_id
	var data = GameManager.game_state.weapons if button_selected == 0 else GameManager.game_state.armors
	var equippable_items = []
	for item_arr: Array in data.values():
		var item = item_arr[0]
		if item is GameArmor:
			if item.id > 0 and RPGSYSTEM.database.armors.size() > item.id:
				var real_armor = RPGSYSTEM.database.armors[item.id]
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
		@warning_ignore("incompatible_ternary")
		var real_data = RPGSYSTEM.database.weapons if button_selected == 0 else RPGSYSTEM.database.armors
		var color_data = RPGSYSTEM.database.types.weapon_rarity_color_types if button_selected == 0 else  RPGSYSTEM.database.types.armor_rarity_color_types
		
		for level in item.levels:
			var current_item = item.levels[level].item
			if current_item.id > 0 and real_data.size() > current_item.id:
				var real_item = real_data[current_item.id]
				var tex = null
				if ResourceLoader.exists(real_item.icon.path):
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
	menu_items.set_curren_equipped_item(curren_equipped_item)
	
	GameManager.play_fx("ok")
	
	formatted_items.sort_custom(func(a, b):
		# 1. Nuevos primero
		if a.is_new_item != b.is_new_item:
			return a.is_new_item and not b.is_new_item

		# 2. Orden alfabético por nombre
		var cmp = a.name.naturalnocasecmp_to(b.name)
		if cmp != 0:
			return cmp < 0

		# 3. Mismo nombre → nivel descendente
		return a.level > b.level
	)
	
	# Añadir remove item al inicio
	var remove_item = {
		"name": "- " + tr("Remove equip") + " -",
		"icon": preload("uid://cy1pny48ukkqg"),
		"disabled": false,
		"color": Color.WHITE,
		"is_new_item": false
	}
	formatted_items.insert(0, remove_item)
	menu_items.set_items(formatted_items)
	if current_actor:
		current_actor.is_comparation_enabled = true
	_show_menu()


func destroy() -> void:
	GameManager.play_fx("cancel")
	GameManager.set_cursor_manipulator(GameManager.MANIPULATOR_MODES.NONE)
	back_pressed.emit()


func _on_menu_items_cancel() -> void:
	_hide_menu()


func _on_menu_items_item_hovered(index: int, item: Dictionary) -> void:
	if index < 0: return
	var slot_id = equipment_container.button_selected
	var obj = item.get("current_item", null)
	var description_setted = false
	if obj:
		var real_item: Variant
		if obj is GameWeapon:
			if obj.id > 0 and RPGSYSTEM.database.weapons.size() > obj.id:
				real_item = RPGSYSTEM.database.weapons[obj.id]
		elif obj is GameArmor:
			if obj.id > 0 and RPGSYSTEM.database.armors.size() > obj.id:
				real_item = RPGSYSTEM.database.armors[obj.id]
		if real_item:
			update_description.emit(real_item.description)
			description_setted = true
			stats_container.set_equipment_compararison(slot_id, item.get("current_item", null))
	
	if not description_setted:
		update_description.emit(tr("Remove item"))
		stats_container.set_equipment_compararison(slot_id, null)


func _on_menu_items_item_selected(index: int, item: Dictionary) -> void:
	_on_menu_items_item_hovered(index, item)


func _on_menu_items_item_clicked(index: int, item: Dictionary) -> void:
	if current_actor:
		current_actor.is_comparation_enabled = false
		var slot_id = equipment_container.button_selected
		#var initial_current_equipment = current_actor.current_gear.duplicate()
		if index != 0:
			current_actor.equip_equipment_from_inventory(slot_id, item.current_item)
		else:
			current_actor.remove_current_equipment(slot_id)
		equipment_container.set_actor(current_actor)
		stats_container.set_actor(current_actor)
		GameManager.play_fx("equip")
		if ControllerManager.current_controller == ControllerManager.CONTROLLER_TYPE.Mouse:
			var slot_selected = equipment_container.get_button_selected()
			Input.warp_mouse(slot_selected.global_position + slot_selected.size * 0.5)
			await get_tree().process_frame
			await get_tree().process_frame
			await get_tree().process_frame
			DisplayServer.cursor_set_shape(DisplayServer.CURSOR_POINTING_HAND)
	_hide_menu()


func _show_menu() -> void:
	GameManager.set_cursor_manipulator(GameManager.MANIPULATOR_MODES.NONE)
	var t = create_tween()
	t.set_parallel(true)
	t.tween_property(menu_items, "position", menu_items_end_position, 0.2).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	t.tween_callback(menu_items.start).set_delay(0.2)
	
	if not stats_container.has_meta("original_position"):
		stats_container.set_meta("original_position", stats_container.position)
		
	var gears = stats_container.get_gears()
	for gear in gears:
		t.tween_property(gear, "rotation", - PI / 4, 0.5).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT).set_delay(0.18)
	t.tween_property(stats_container, "position:x", stats_container.get_meta("original_position").x - 40, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(0.18)
	t.tween_callback(
		func():
			GameManager.play_se("res://Assets/Sounds/SE/wood_hit.ogg")
			stats_container.set_show_comparison(true)
			menu_items.emit_selected_item()
	).set_delay(0.20)


func _hide_menu() -> void:
	if current_actor:
		current_actor.is_comparation_enabled = true
	GameManager.set_cursor_manipulator(GameManager.MANIPULATOR_MODES.NONE)
	stats_container.set_show_comparison(false)
	menu_items.end()
	var t = create_tween()
	t.set_parallel(true)
	t.tween_property(menu_items, "position", menu_items_start_position, 0.4).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	t.tween_callback(
		func():
			equipment_container.select_last_slot()
			GameManager.force_show_cursor()
			GameManager.force_hand_position_over_node(GameManager.get_cursor_manipulator())
	).set_delay(0.4)
	
	var gears = stats_container.get_gears()
	for gear in gears:
		t.tween_property(gear, "rotation", 0.0, 0.5).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT).set_delay(0.2)
	t.tween_property(stats_container, "position:x", stats_container.get_meta("original_position").x, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(0.2)
