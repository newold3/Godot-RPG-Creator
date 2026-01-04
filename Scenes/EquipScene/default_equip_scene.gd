class_name DefaultEquipScene
extends WindowBase

@export var menu_items_start_position: Vector2
@export var menu_items_end_position: Vector2


@onready var equipment_container: Control = %EquipmentContainer
@onready var main_actor_container: VBoxContainer = %MainActorContainer
@onready var stats_container: Control = %StatsContainer
@onready var icon_gear_container: Control = %IconGearContainer
@onready var buttons_vertical_menu: PanelContainer = %ButtonsVerticalMenu


var current_actor: GameActor

var animator_tween1: Tween
var animator_tween2: Tween


func _ready() -> void:
	ControllerManager.controller_changed.connect(_on_controlled_changed)
	fill_actors()
	%MenuItems.position = menu_items_start_position
	%IconGearContainer.title = RPGSYSTEM.database.terms.search_message("Equip Title")
	
	GameManager.set_text_config(self)
	visibility_changed.connect(_on_visibility_changed)
	%EquipmentContainer.cancel.connect(_on_equipment_cancel)
	%EquipmentContainer.slot_clicked.connect(_on_equipment_slot_clicked)
	call_deferred("_setup_all")
	
	_on_controlled_changed(ControllerManager.current_controller)


func _process(_delta: float) -> void:
	var manipulator = GameManager.get_cursor_manipulator()
	if manipulator == GameManager.MANIPULATOR_MODES.EQUIP_MENU:
		if ControllerManager.is_action_pressed("Button L1"):
			buttons_vertical_menu.navigate_button(-1)
		elif ControllerManager.is_action_pressed("Button R1"):
			buttons_vertical_menu.navigate_button(1)
	
	if manipulator in [GameManager.MANIPULATOR_MODES.EQUIP_MENU, GameManager.MANIPULATOR_MODES.EQUIP_MENU_SUB_MENU]:
		if ControllerManager.current_controller == ControllerManager.CONTROLLER_TYPE.Joypad:
			var direction = ControllerManager.get_right_stick_direction()
			if direction in ["up", "down"]:
				var scroll = -1 if direction == "up" else 1
				var strength = remap(abs(ControllerManager.get_right_stick_vector().y), 0.0, 1.0, 10, 250)
				stats_container.scroll_to(scroll, strength)


func fill_actors() -> void:
	if not GameManager.game_state: return
	
	var textures: Array[Dictionary] = []
	var real_ids: PackedInt32Array = []
	for actor_id in GameManager.game_state.current_party:
		var actor: GameActor = GameManager.get_actor(actor_id)
		if actor:
			var real_actor: RPGActor = actor.get_real_actor()
			if real_actor:
				var current_icon: RPGIcon = real_actor.face_preview
				var tex = null
				
				if current_icon and ResourceLoader.exists(current_icon.path):
					tex = ResourceLoader.load(current_icon.path)
					
				textures.append({"texture": tex, "region": current_icon.region})
				real_ids.append(real_actor.id)

	buttons_vertical_menu.set_images(textures)
	buttons_vertical_menu.set_real_ids(real_ids)
	
	%ButtonsVerticalMenu.button_clicked.connect(_change_actor)
	%ButtonsVerticalMenu.button_selected.connect(_on_actors_menu_button_selected)


func _on_equipment_cancel() -> void:
	GameManager.play_fx("cancel")
	end()


func _on_equipment_slot_clicked(slot_clicked: int) -> void:
	_process_start_change_equip(slot_clicked)


func _setup_all() -> void:
	free_when_end = false
	GameManager.set_text_config(self, false)
	if GameManager.game_state:
		start()


func _on_visibility_changed() -> void:
	if visible:
		equipment_container.select_button(0)
		start()
	else:
		if animator_tween1:
			animator_tween1.custom_step(999)
		if animator_tween2:
			animator_tween2.custom_step(999)
		animator_tween1 = null
		animator_tween2 = null
		%MenuItems.position = menu_items_start_position


func _process_start_change_equip(slot_id: int) -> void:
	var current_button_selected = %EquipmentContainer.get_button_selected()
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
		var color_data = RPGSYSTEM.database.types.weapon_rarity_color_types if button_selected == 0 else RPGSYSTEM.database.types.armor_rarity_color_types
		
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
		
	GameManager.play_fx("ok")
	
	formatted_items.sort_custom(func(a, b):
		# 1. New items first
		if a.is_new_item != b.is_new_item:
			return a.is_new_item and not b.is_new_item

		# 2. Alphabetical order by name
		var cmp = a.name.naturalnocasecmp_to(b.name)
		if cmp != 0:
			return cmp < 0

		# 3. Same name -> descending level
		return a.level > b.level
	)
	
	# Add remove item at start
	var remove_item = {
		"name": "- " + tr("Remove equip") + " -",
		"icon": preload("uid://cy1pny48ukkqg"),
		"disabled": false,
		"color": Color.WHITE,
		"is_new_item": false
	}
	formatted_items.insert(0, remove_item)
	%MenuItems.set_items(formatted_items)
	_show_menu()


func _show_menu() -> void:
	if animator_tween1:
		animator_tween1.custom_step(999)
	if animator_tween2:
		animator_tween2.custom_step(999)
	busy = true
	
	GameManager.set_cursor_manipulator(GameManager.MANIPULATOR_MODES.NONE)
	GameManager.force_hide_cursor()
	var gears = %StatsContainer.get_gears()
	var gears2 = %MenuItems.get_gears()
	gears2[0].rotation = PI / 2
	gears2[1].rotation = PI / 2
	var t = create_tween()
	t.set_parallel(true)
	t.tween_property(%MenuItems, "position", menu_items_end_position - Vector2(3, 0), 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_property(gears2[0], "rotation", 0.0, 0.4)
	t.tween_property(gears2[1], "rotation", 0.0, 0.4)
	t.tween_property(%StatsContainer, "position:x", %StatsContainer.position.x - 12, 0.08).set_delay(0.16)
	t.tween_property(gears[0], "rotation", -PI / 2, 0.1).set_delay(0.16)
	t.tween_property(gears[1], "rotation", -PI / 2, 0.1).set_delay(0.16)
	t.tween_property(%StatsContainer, "position:x", %StatsContainer.position.x, 0.11).set_delay(0.26)
	t.tween_property(gears[0], "rotation", 0, 0.2).set_delay(0.26)
	t.tween_property(gears[1], "rotation", 0, 0.2).set_delay(0.26)
	t.tween_callback(
		func():
			GameManager.play_se("res://Assets/Sounds/SE/wood_hit.ogg")
			%StatsContainer.set_show_comparison(true)
	).set_delay(0.20)
	
	var t2 = create_tween()
	t2.tween_callback(%MenuItems.enabled).set_delay(0.2)
	t2.tween_property(%MenuItems, "position:x", menu_items_end_position.x, 0.3)
	
	animator_tween1 = t
	animator_tween2 = t2


func _hide_menu() -> void:
	if animator_tween1:
		animator_tween1.custom_step(999)
	if animator_tween2:
		animator_tween2.custom_step(999)
		
	GameManager.set_cursor_manipulator(GameManager.MANIPULATOR_MODES.NONE)
	%StatsContainer.set_show_comparison(false)
	%MenuItems.disabled()
	var gears = %MenuItems.get_gears()
	var t = create_tween()
	t.set_parallel(true)
	t.tween_property(%MenuItems, "position", menu_items_start_position, 0.2).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	t.tween_property(gears[0], "rotation", PI, 0.4)
	t.tween_property(gears[1], "rotation", PI, 0.4)
	t.tween_interval(0.01)
	t.set_parallel(false)
	t.tween_callback(
		func():
			equipment_container.config_hand()
			equipment_container.select_button(equipment_container.button_selected)
			GameManager.force_show_cursor()
	)
	
	var t2 = create_tween()
	t2.tween_callback(set.bind("busy", false)).set_delay(0.2)
	
	animator_tween1 = t
	animator_tween2 = t2


func set_actor(actor: GameActor) -> void:
	current_actor = actor
	stats_container.set_actor(actor)
	equipment_container.set_actor(actor)
	main_actor_container.set_actor(actor)
	buttons_vertical_menu.call_deferred("select", actor.id)


func _change_actor(actor_id: int) -> void:
	var actor: GameActor = GameManager.get_actor(actor_id)
	if actor:
		set_actor(actor)


func _on_actors_menu_button_selected(_actor_index: int) -> void:
	GameManager.play_fx("cursor")


func start() -> void:
	super ()
	
	icon_gear_container.start()
	
	stats_container.start()
	equipment_container.start()
	
	
	var t = create_tween()
	t.set_parallel(true)
	
	var main_actor_container_x = 84
	main_actor_container.position.x = -180
	main_actor_container.modulate.a = 0
	
	t.tween_property(main_actor_container, "position:x", main_actor_container_x, 0.35).set_delay(0.15).set_trans(Tween.TRANS_SINE)
	t.tween_property(main_actor_container, "modulate:a", 1.0, 0.25).set_delay(0.15).set_trans(Tween.TRANS_SINE)


func end() -> void:
	super ()
	icon_gear_container.end()
	stats_container.end()
	equipment_container.end()


func _on_menu_items_cancel() -> void:
	_hide_menu()


func _on_equipment_container_slot_selected(slot_id: int) -> void:
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
				%Description.text = real_item.description
				var formatted_item = equipment_container._get_item_display_data(obj, slot_id)
				formatted_item.current_level = obj.current_level
				formatted_item.max_level = real_item.upgrades.max_levels
				formatted_item.current_experience = obj.current_experience
				formatted_item.next_experience = obj.get_next_level_experience()
				%CurrentSelectedEquipmentContainer.set_item(formatted_item)
			else:
				%Description.text = ""
				%CurrentSelectedEquipmentContainer.set_item({})
		else:
			%Description.text = ""
			%CurrentSelectedEquipmentContainer.set_item({})


func _on_menu_items_item_hovered(index: int, item: Dictionary) -> void:
	if index < 0: return
	var slot_id = %EquipmentContainer.button_selected
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
			%Description.text = real_item.description
			description_setted = true
			%StatsContainer.set_equipment_compararison(slot_id, item.get("current_item", null))
	
	if not description_setted:
		%Description.text = "Remove item"
		%StatsContainer.set_equipment_compararison(slot_id, null)


func _on_menu_items_item_selected(index: int, item: Dictionary) -> void:
	_on_menu_items_item_hovered(index, item)


func _on_menu_items_item_clicked(index: int, item: Dictionary) -> void:
	if current_actor:
		var slot_id = %EquipmentContainer.button_selected
		#var initial_current_equipment = current_actor.current_gear.duplicate()
		if index != 0:
			current_actor.equip_equipment_from_inventory(slot_id, item.current_item)
		else:
			current_actor.remove_current_equipment(slot_id)
		%EquipmentContainer.update_slot(slot_id)
		%StatsContainer.set_actor(current_actor)
		GameManager.play_fx("equip")
		if ControllerManager.current_controller == ControllerManager.CONTROLLER_TYPE.Mouse:
			var slot_selected = %EquipmentContainer.get_button_selected()
			Input.warp_mouse(slot_selected.global_position + slot_selected.size * 0.5)
			await get_tree().process_frame
			await get_tree().process_frame
			await get_tree().process_frame
			DisplayServer.cursor_set_shape(DisplayServer.CURSOR_POINTING_HAND)
	_hide_menu()


func _on_controlled_changed(type: ControllerManager.CONTROLLER_TYPE):
	var help: String = ""
	if type == ControllerManager.CONTROLLER_TYPE.Joypad:
		help = "L1/R1 Change Actor  RS Stats Navigate  D-Pad Select Equipment  A Ok  B Cancel"
	else:
		help = "Q/E Change Actor  Mouse Stats Navigate  W/A/S/D Select Equipment  Space Ok  Escape Cancel"
		
	%HelpLabel.text = help
