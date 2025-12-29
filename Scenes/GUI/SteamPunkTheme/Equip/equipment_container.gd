extends Control


@onready var equip_button_container: VBoxContainer = %EquipButtonContainer

var started: bool = false

var button_selected: int = 0
var current_actor: GameActor

var main_tween : Tween


const EQUIP_ITEM_BUTTON = preload("res://Scenes/GUI/SteamPunkTheme/Equip/equip_item_button.tscn")


signal slot_selected(slot_id: int)
signal slot_clicked(slot_id: int)
signal change_focus_requested()
signal back_pressed()


func _ready() -> void:
	_create_slots()


func start() -> void:
	if main_tween:
		main_tween.kill()
	
	var a = -PI / 2.0
	
	var t = create_tween()
	t.set_parallel(true)
	t.tween_property(%GearTopLeft, "rotation", a, 0.7).set_trans(Tween.TRANS_SINE)
	t.tween_interval(0.01)
	t.set_parallel(false)
	t.tween_callback(set.bind("started", [true]))


func end() -> void:
	if main_tween:
		main_tween.kill()


func _create_slots() -> void:
	for slot in equip_button_container.get_children():
		equip_button_container.remove_child(slot)
		slot.queue_free()
		
	var equipment = RPGSYSTEM.database.types.equipment_types
	var icons = RPGSYSTEM.database.types.icons.equipment_icons

	for i in equipment.size():
		var button = EQUIP_ITEM_BUTTON.instantiate()
		button.focus_entered.connect(_config_hand_in_equipment_button.bind(i))
		button.toggled.connect(_on_button_toggled.bind(i))
		equip_button_container.add_child(button)
		
		var icon: RPGIcon = icons[i]
		var type_name = equipment[i]
		var tex = null
		if ResourceLoader.exists(icon.path):
			var t = ResourceLoader.load(icon.path)
			
			if icon.region:
				tex = ImageTexture.create_from_image(t.get_image().get_region(icon.region))
			else:
				tex = t
				
		button.setup_button(
			tex, Color.GRAY, type_name.capitalize(),
			null, Color(0.75, 0.75, 0.75, 0.576), RPGSYSTEM.database.terms.search_message("Equip Empty Slot")
		)
		
		if i == 0:
			button.set_selected(true)


func set_actor(actor: GameActor) -> void:
	current_actor = actor
	var equip_slots = equip_button_container.get_child_count()
	
	for i: int in actor.current_gear.size():
		if i >= equip_slots: 
			return
		
		var gear = actor.current_gear[i] if actor.current_gear.size() > i and i >= 0 else null
		var slot = equip_button_container.get_child(i)
		
		var item_data = _get_item_display_data(gear, i)
		slot.setup_item(item_data.tex, item_data.item_color, item_data.item_name)
	
	for i in equip_button_container.get_child_count():
		var has_gear = i < current_actor.current_gear.size() and current_actor.current_gear[i] != null
		set_disabled(i, !_can_equip_item_in_slot(i) or (!_has_equippable_items_in_slot(i) and !has_gear))


func _has_equippable_items_in_slot(slot: int) -> bool:
	var data = GameManager.game_state.weapons if slot == 0 else GameManager.game_state.armors
	
	for item_arr: Array in data.values():
		var item = item_arr[0]
		if current_actor.can_equip(slot, item.id):
			for obj in item_arr:
				var available_amount = obj.quantity - obj.total_equipped
				if available_amount > 0:
					return true
	
	return false


func set_disabled(slot_id: int, value: bool) -> void:
	if slot_id >= 0 and equip_button_container.get_child_count() > slot_id:
		equip_button_container.get_child(slot_id).set_disabled(value)


func _get_item_display_data(gear: Variant, slot_index: int) -> Dictionary:
	var result = {
		"tex": null,
		"item_color": Color.GRAY if not _can_equip_item_in_slot(slot_index) else Color.WHITE,
		"item_name": RPGSYSTEM.database.terms.search_message("Equip Empty Slot")
	}
	
	if not gear:
		return result
	
	var data
	var data2
	var real_item
	var item_id: int
	
	if slot_index == 0:  # Weapon
		var weapon: GameWeapon = gear
		item_id = weapon.id
		data = RPGSYSTEM.database.weapons
		data2 = RPGSYSTEM.database.types.weapon_rarity_color_types
	else:  # Armor
		var armor: GameArmor = gear
		item_id = armor.id
		data = RPGSYSTEM.database.armors
		data2 = RPGSYSTEM.database.types.armor_rarity_color_types
	
	if item_id <= 0 or data.size() <= item_id:
		return result
	
	real_item = data[item_id]
	
	result.item_name = real_item.name
	
	if not _can_equip_item_in_slot(slot_index):
		result.item_color = Color.GRAY
	elif real_item.rarity_type < 0 or real_item.rarity_type >= data2.size():
		result.item_color = Color.WHITE
	else:
		result.item_color = data2[real_item.rarity_type]
	
	var icon: RPGIcon = real_item.icon
	if ResourceLoader.exists(icon.path):
		var t = ResourceLoader.load(icon.path)
		if icon.region:
			result.tex = ImageTexture.create_from_image(t.get_image().get_region(icon.region))
		else:
			result.tex = t

	return result


func get_button_selected() -> EquipItemButton:
	if button_selected >= 0 and equip_button_container.get_child_count() > button_selected:
		return equip_button_container.get_child(button_selected)
	
	return null


func _can_equip_item_in_slot(slot: int) -> bool:
	if current_actor:
		return current_actor.is_slot_available(slot)
	
	return false


func _config_hand_in_equipment_button(_button_selected: int) -> void:
	button_selected = _button_selected
	_config_hand()


func _on_button_toggled(value: bool, slot_id: int) -> void:
	if value:
		slot_selected.emit(slot_id)


func select(slot_id: int) -> void:
	if slot_id >= 0 and equip_button_container.get_child_count() > slot_id:
		equip_button_container.get_child(slot_id).set_selected(true)


func select_last_slot() -> void:
	select(button_selected)
	_config_hand()


func update_slot(slot_id: int) -> void:
	if current_actor:
		if slot_id >= 0 and current_actor.current_gear.size() > 0:
			var slot = equip_button_container.get_child(slot_id)
			var gear = current_actor.current_gear[slot_id]
			var item_data = _get_item_display_data(gear, slot_id)
			slot.setup_item(item_data.tex, item_data.item_color, item_data.item_name)


func _change_selected_equipment(direction: String) -> void:
	var current_button = equip_button_container.get_child(0).button_group.get_selected_button()
	var new_control = ControllerManager.get_closest_focusable_control(current_button, direction, true)
	if new_control:
		new_control.set_selected(true)
		GameManager.play_fx("cursor")


func _process(_delta: float) -> void:
	var manipulator = GameManager.get_cursor_manipulator()
	if manipulator == GameManager.MANIPULATOR_MODES.EQUIP_MENU:
		var direction = ControllerManager.get_pressed_direction()
		if direction and direction in ["up", "down"]:
			_change_selected_equipment(direction)
		elif direction and direction in ["left", "right"]:
			GameManager.play_fx("cursor")
			change_focus_requested.emit()
		elif ControllerManager.is_cancel_just_pressed([KEY_0, KEY_KP_0]):
			back_pressed.emit()
		elif ControllerManager.is_confirm_just_pressed(false, [KEY_KP_ENTER]):
			slot_clicked.emit(button_selected)


func _config_hand() -> void:
	var manipulator = str(GameManager.MANIPULATOR_MODES.EQUIP_MENU)
	GameManager.set_cursor_manipulator(manipulator)
	GameManager.set_confin_area(Rect2(), manipulator)
	GameManager.set_hand_position(MainHandCursor.HandPosition.LEFT, manipulator)
	GameManager.set_cursor_offset(Vector2(8, 0), manipulator)
	GameManager.force_show_cursor()
