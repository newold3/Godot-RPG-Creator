@tool
class_name ShopPanel
extends MarginContainer


var current_item_id: int = 1
var current_weapon_id: int = 1
var current_armor_id: int = 1

var current_data: Dictionary
var current_price: int
var busy: bool = false # prevents infinite loops when recalculating sizes
var initializing: bool = true

signal remove_panel_request(obj: ShopPanel)
signal move_down_request(id: int)
signal move_up_request(id: int)


func _ready() -> void:
	var button_group = ButtonGroup.new()
	%DefaultPrice.button_group = button_group
	%CustomPrice.button_group = button_group
	%CustomPriceValue.get_line_edit().focus_exited.connect(%CustomPriceValue.apply)
	var lineedit = %Quantity.get_line_edit()
	lineedit.set_expand_to_text_length_enabled(true)
	lineedit.item_rect_changed.connect(
		func():
			if busy: return
			busy = true
			var x = %Quantity.get_parent().size.x + \
				%MainMarginContainer.get("theme_override_constants/margin_left") * 5 + \
				%MainMarginContainer.get("theme_override_constants/margin_right") * 5
			queue_sort()
			get_viewport().size.x = x
			await get_tree().process_frame
			busy = false
	)


func _process(delta: float) -> void:
	%MoveDown.set_disabled(get_index() == get_parent().get_child_count() - 1)
	%MoveUp.set_disabled(get_index() == 0)


func select() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	%Quantity.get_line_edit().grab_focus()


func set_data(data: Dictionary) -> void:
	current_data = data
	
	var quantity = current_data.get("quantity", 0)
	%Quantity.value = quantity
	
	var type = clamp(current_data.get("type", 0), 0, %Type.get_item_count() - 1)
	var item_id = current_data.get("item_id", 1)
	match type:
		0: current_item_id = item_id
		1: current_weapon_id = item_id
		2: current_armor_id = item_id
	%Type.select(type)
	update_id_text()
		
	var price_mode = current_data.get("price_mode", 0)
	if price_mode == 0:
		%DefaultPrice.set_pressed(true)
	else:
		current_price = current_data.get("price", 0)
		%CustomPrice.set_pressed(true)
	
	%LevelContainer.set_visible(type != 0)
	
	%RestockAmount.value = current_data.get("restock_amount", -1)
	
	initializing = false


func _on_close_panel_button_pressed() -> void:
	remove_panel_request.emit(self)


func _on_default_price_toggled(toggled_on: bool) -> void:
	if toggled_on:
		%CustomPriceValue.set_disabled(true)
		current_data.price_mode = 0
		%CustomPriceValue.value = get_item_price_in_db()


func _on_custom_price_toggled(toggled_on: bool) -> void:
	if toggled_on:
		%CustomPriceValue.set_disabled(false)
		current_data.price_mode = 1
		%CustomPriceValue.value = current_price
		if not initializing:
			%CustomPriceValue.get_line_edit().grab_focus()


func _on_quantity_value_changed(value: float) -> void:
	current_data.quantity = value
	%RestockAmount.set_disabled(value == 0)


func _on_type_item_selected(index: int) -> void:
	current_data.type = index
	%LevelContainer.set_visible(index != 0)
	update_id_text()


func _on_custom_price_value_value_changed(value: float) -> void:
	current_data.price = value
	if current_data.price_mode == 1:
		current_price = value


func update_id_text() -> void:
	var data: Variant
	var current_id: int
	match current_data.type:
		0:
			%ItemID.text = "#%s" % current_item_id
			data = RPGSYSTEM.database.items
			current_id = current_item_id
		1:
			%ItemID.text = "#%s" % current_weapon_id
			data = RPGSYSTEM.database.weapons
			current_id = current_weapon_id
		2:
			%ItemID.text = "#%s" % current_armor_id
			data = RPGSYSTEM.database.armors
			current_id = current_armor_id
	
	var max_level: int = 1
	var current_level: int = 1
	if data.size() > current_id and current_id > 0:
		%ItemName.text = data[current_id].name
		if "upgrades" in data[current_id]:
			max_level = data[current_id].upgrades.max_levels
			current_level = max(1, min(max_level, current_data.get("level", 1)))
	else:
		%ItemName.text = ""
	
	current_data.level = current_level
	%Level.max_value = max_level
	%Level.value = current_level
	%MaxLevelLabel.text = " / %s" % max_level


func get_item_price_in_db() -> int:
	var data
	var value: int = 0
	match current_data.type:
		0: value = RPGSYSTEM.database.items[current_item_id].price if RPGSYSTEM.database.items.size() > current_item_id else 0
		1: value = RPGSYSTEM.database.weapons[current_weapon_id].price if RPGSYSTEM.database.weapons.size() > current_weapon_id else 0
		2: value = RPGSYSTEM.database.armors[current_armor_id].price if RPGSYSTEM.database.armors.size() > current_armor_id else 0
	
	return value


func _on_item_id_pressed() -> void:
	var path = "res://addons/CustomControls/Dialogs/select_any_data_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	dialog.database = RPGSYSTEM.database
	dialog.destroy_on_hide = true
	var data
	var id_selected: int
	var title: String
	match current_data.type:
		0:
			data = RPGSYSTEM.database.items
			id_selected = current_item_id
			title = TranslationManager.tr("Items")
		1:
			data = RPGSYSTEM.database.weapons
			id_selected = current_weapon_id
			title = TranslationManager.tr("Weapons")
		2:
			data = RPGSYSTEM.database.armors
			id_selected = current_armor_id
			title = TranslationManager.tr("Armors")

	var target = self
	dialog.selected.connect(_on_item_selected, CONNECT_ONE_SHOT)
	dialog.setup(data, id_selected, title, target)


func _on_item_selected(item_id: int, target: Variant) -> void:
	current_data.item_id = item_id
	match current_data.type:
		0: current_item_id = item_id
		1: current_weapon_id = item_id
		2: current_armor_id = item_id
	update_id_text()


func _on_move_down_pressed() -> void:
	move_down_request.emit(get_index())


func _on_move_up_pressed() -> void:
	move_up_request.emit(get_index())


func _on_level_value_changed(value: float) -> void:
	current_data.level = value


func _on_restock_amount_value_changed(value: float) -> void:
	current_data.restock_amount = value
