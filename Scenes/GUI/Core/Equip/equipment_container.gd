class_name GuiCoreEquipmentContainer
extends Control

#region VariablesAndSignals
@export var equip_button_scene: PackedScene

var started: bool = false
var button_selected: int = 0
var current_actor: GameActor

signal slot_selected(slot_id: int)
signal slot_clicked(slot_id: int)
signal change_focus_requested()
signal back_pressed()
#endregion

#region Hooks
func get_equip_button_container() -> Control:
	if has_node("%EquipButtonContainer"):
		return get_node("%EquipButtonContainer")
	return get_node_or_null("MarginContainer/VBoxContainer/MarginContainer/BottomContainer/EquipButtonContainer")


func _get_equip_button_scene() -> PackedScene:
	return equip_button_scene


func _animate_start(on_complete: Callable = Callable()) -> void:
	started = true
	if on_complete:
		on_complete.call()


func _animate_end(on_complete: Callable = Callable()) -> void:
	if on_complete:
		on_complete.call()


func _config_hand() -> void:
	pass


func _config_hand_in_equipment_button(_button_selected: int) -> void:
	button_selected = _button_selected
	_config_hand()
#endregion

#region Initialization
func _ready() -> void:
	_create_slots()


func start() -> void:
	_animate_start()


func end() -> void:
	started = false
	_animate_end()


func _create_slots() -> void:
	var container = get_equip_button_container()
	if not container: return
	for slot in container.get_children():
		container.remove_child(slot)
		slot.queue_free()
		
	var equipment = RPGSYSTEM.database.types.equipment_types
	var icons = RPGSYSTEM.database.types.icons.equipment_icons
	var scene_res = _get_equip_button_scene()
	if not scene_res:
		return

	for i in equipment.size():
		var button = scene_res.instantiate()
		button.focus_entered.connect(_on_button_focus_entered.bind(i))
		button.toggled.connect(_on_button_toggled.bind(i))
		container.add_child(button)
		
		var icon = icons[i] if icons.size() > i else null
		var type_name = tr(equipment[i])
		var tex = _resolve_icon_texture(icon)
				
		button.setup_button(
			tex, Color.GRAY, type_name.capitalize(),
			null, Color(0.75, 0.75, 0.75, 0.576), tr(RPGSYSTEM.database.terms.search_message("Equip Empty Slot"))
		)
		
		if i == 0:
			button.set_selected(true)
#endregion

#region UI_Updates
func set_actor(actor: GameActor) -> void:
	current_actor = actor
	var container = get_equip_button_container()
	if not container: return
	var equip_slots = container.get_child_count()
	
	for i: int in actor.current_gear.size():
		if i >= equip_slots: 
			return
		
		var gear = actor.current_gear[i] if actor.current_gear.size() > i and i >= 0 else null
		var slot = container.get_child(i)
		var item_data = _get_item_display_data(gear, i)
		slot.setup_item(item_data.tex, item_data.item_color, item_data.item_name)
	
	for i in container.get_child_count():
		var has_gear = i < current_actor.current_gear.size() and current_actor.current_gear[i] != null
		set_disabled(i, !_can_equip_item_in_slot(i) or (!_has_equippable_items_in_slot(i) and !has_gear))


func set_disabled(slot_id: int, value: bool) -> void:
	var container = get_equip_button_container()
	if container and slot_id >= 0 and container.get_child_count() > slot_id:
		container.get_child(slot_id).set_disabled(value)


func update_slot(slot_id: int) -> void:
	var container = get_equip_button_container()
	if current_actor and container:
		if slot_id >= 0 and current_actor.current_gear.size() > slot_id:
			var slot = container.get_child(slot_id)
			var gear = current_actor.current_gear[slot_id]
			var item_data = _get_item_display_data(gear, slot_id)
			slot.setup_item(item_data.tex, item_data.item_color, item_data.item_name)
#endregion

#region Data_Handling
func _has_equippable_items_in_slot(slot: int) -> bool:
	var is_weapon_slot = (slot == 0)
	var data = GameManager.game_state.weapons if is_weapon_slot else GameManager.game_state.armors
	
	for item_arr: Array in data.values():
		var item = item_arr[0]
		if item is GameArmor:
			var real_armor = RPGSYSTEM.get_data("armors", item.id)
			if real_armor:
				if real_armor.equipment_type != 0 and real_armor.equipment_type != slot:
					continue
			else:
				continue
		
		if current_actor.can_equip(slot, item.id):
			for obj in item_arr:
				var available_amount = obj.quantity - obj.total_equipped
				if available_amount > 0:
					return true
	return false


func _get_item_display_data(gear: Variant, slot_index: int) -> Dictionary:
	var result = {
		"tex": null,
		"item_color": Color.GRAY if not _can_equip_item_in_slot(slot_index) else Color.WHITE,
		"item_name": tr(RPGSYSTEM.database.terms.search_message("Equip Empty Slot"))
	}
	
	if not gear:
		return result
	
	var data2
	var real_item
	var item_id: int = gear.id if gear and "id" in gear else -1
	
	if slot_index == 0: 
		var weapon: GameWeapon = gear
		item_id = weapon.id
		real_item = RPGSYSTEM.get_data("weapons", item_id)
		data2 = RPGSYSTEM.database.types.weapon_rarity_color_types
	else: 
		var armor: GameArmor = gear
		item_id = armor.id
		real_item = RPGSYSTEM.get_data("armors", item_id)
		data2 = RPGSYSTEM.database.types.armor_rarity_color_types
	
	if item_id <= 0 or not real_item:
		return result
	
	result.item_name = tr(real_item.name)
	
	if not _can_equip_item_in_slot(slot_index):
		result.item_color = Color.GRAY
	elif real_item.rarity_type < 0 or not data2 or real_item.rarity_type >= data2.size():
		result.item_color = Color.WHITE
	else:
		result.item_color = data2[real_item.rarity_type]
	
	var icon: RPGIcon = real_item.icon
	result.tex = _resolve_icon_texture(icon)

	return result


func _resolve_icon_texture(icon: Variant) -> Texture2D:
	if not icon:
		return null
	if icon is Texture2D:
		return icon
	if icon is RPGIcon:
		var path = icon.path
		if AssetManager.exists(path):
			var t = ResourceLoader.load(path)
			if t:
				if icon.region and icon.region.size.x > 0 and icon.region.size.y > 0:
					var img = t.get_image()
					if img:
						return ImageTexture.create_from_image(img.get_region(icon.region))
				return t
	return null


func _can_equip_item_in_slot(slot: int) -> bool:
	if current_actor:
		return current_actor.is_slot_available(slot)
	return false
#endregion

#region InputAndFocus
func get_button_selected() -> Control:
	var container = get_equip_button_container()
	if container and button_selected >= 0 and container.get_child_count() > button_selected:
		return container.get_child(button_selected)
	return null


func _on_button_focus_entered(slot_id: int) -> void:
	button_selected = slot_id
	_config_hand_in_equipment_button(slot_id)


func _on_button_toggled(value: bool, slot_id: int) -> void:
	if value:
		button_selected = slot_id
		slot_selected.emit(slot_id)


func _on_button_pressed(slot_id: int) -> void:
	button_selected = slot_id
	slot_clicked.emit(slot_id)


func select(slot_id: int) -> void:
	var container = get_equip_button_container()
	if container and slot_id >= 0 and container.get_child_count() > slot_id:
		container.get_child(slot_id).set_selected(true)


func select_last_slot() -> void:
	select(button_selected)
	_config_hand()


func _change_selected_equipment(direction: String) -> void:
	var container = get_equip_button_container()
	if not container or container.get_child_count() == 0: return
	var first_child = container.get_child(0)
	if not "button_group" in first_child or not first_child.button_group: return
	var current_button = first_child.button_group.get_selected_button()
	var new_control = ControllerManager.get_closest_focusable_control(current_button, direction, true)
	if new_control:
		if new_control.has_method("set_selected"):
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
#endregion
