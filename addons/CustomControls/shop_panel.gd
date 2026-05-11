@tool
class_name ShopPanel
extends MarginContainer

var current_item_id: int = 1
var current_weapon_id: int = 1
var current_armor_id: int = 1
var current_costume_id: int = 1

var current_data: Dictionary
var current_price: int
var busy: bool = false
var initializing: bool = true

signal remove_panel_request(obj: ShopPanel)
signal move_down_request(id: int)
signal move_up_request(id: int)



## Initializes the panel and connects UI signals
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



## Updates the status of the move buttons based on panel position
func _process(delta: float) -> void:
	%MoveDown.set_disabled(get_index() == get_parent().get_child_count() - 1)
	%MoveUp.set_disabled(get_index() == 0)



## Gives focus to the quantity input field
func select() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	%Quantity.get_line_edit().grab_focus()



## Loads the data into the panel controls
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
		3: current_costume_id = item_id
		
	%Type.select(type)
	update_id_text()
		
	var price_mode = current_data.get("price_mode", 0)
	
	if price_mode == 0:
		%DefaultPrice.set_pressed(true)
	else:
		current_price = current_data.get("price", 0)
		%CustomPrice.set_pressed(true)
	
	%LevelContainer.set_visible(type != 0 and type != 3)
	%RestockAmount.value = current_data.get("restock_amount", -1)
	initializing = false



## Triggers the panel removal
func _on_close_panel_button_pressed() -> void:
	remove_panel_request.emit(self)



## Sets the item price mode to default
func _on_default_price_toggled(toggled_on: bool) -> void:
	if toggled_on:
		%CustomPriceValue.set_disabled(true)
		current_data.price_mode = 0
		%CustomPriceValue.value = get_item_price_in_db()



## Sets the item price mode to custom
func _on_custom_price_toggled(toggled_on: bool) -> void:
	if toggled_on:
		%CustomPriceValue.set_disabled(false)
		current_data.price_mode = 1
		%CustomPriceValue.value = current_price
		if not initializing:
			%CustomPriceValue.get_line_edit().grab_focus()



## Updates the quantity value in the data dictionary
func _on_quantity_value_changed(value: float) -> void:
	current_data.quantity = value
	%RestockAmount.set_disabled(value == 0)



## Updates the selected item type and refreshes the panel data
func _on_type_item_selected(index: int) -> void:
	current_data.type = index
	%LevelContainer.set_visible(index != 0 and index != 3)
	update_id_text()



## Updates the custom price value in the data dictionary
func _on_custom_price_value_value_changed(value: float) -> void:
	if not current_data or not "price" in current_data: return
	
	current_data.price = value
	if current_data.price_mode == 1:
		current_price = value



## Refreshes the visual text displaying the item ID and name using the UID system
func update_id_text() -> void:
	var db_key: String
	var current_id: int
	
	match current_data.type:
		0:
			db_key = "items"
			current_id = current_item_id
		1:
			db_key = "weapons"
			current_id = current_weapon_id
		2:
			db_key = "armors"
			current_id = current_armor_id
		3:
			db_key = "costumes"
			current_id = current_costume_id
			
	var item = RPGSYSTEM.get_data(db_key, current_id)
	var classic_id = RPGSYSTEM.uid_to_id(db_key, current_id)
	var items_size = RPGSYSTEM.database[db_key].size()
	
	var max_level: int = 1
	var current_level: int = 1
	
	if item:
		var id_padded = str(classic_id).pad_zeros(str(items_size).length())
		%ItemID.text = "%s: %s" % [id_padded, item.name]
		
		if has_node("%ItemName"):
			%ItemName.text = ""
			
		if "upgrades" in item:
			max_level = item.upgrades.max_levels
			current_level = max(1, min(max_level, current_data.get("level", 1)))
	else:
		%ItemID.text = "⚠ Invalid Data"
		if has_node("%ItemName"):
			%ItemName.text = ""
	
	current_data.level = current_level
	%Level.max_value = max_level
	%Level.value = current_level
	%MaxLevelLabel.text = " / %s" % max_level



## Retrieves the default price of the selected item from the database
func get_item_price_in_db() -> int:
	var db_key: String
	var current_id: int
	
	match current_data.type:
		0:
			db_key = "items"
			current_id = current_item_id
		1:
			db_key = "weapons"
			current_id = current_weapon_id
		2:
			db_key = "armors"
			current_id = current_armor_id
		3:
			db_key = "costumes"
			current_id = current_costume_id
			
	var item = RPGSYSTEM.get_data(db_key, current_id)
	return item.price if item and "price" in item else 0



## Opens the selection dialog for the specific item type
func _on_item_id_pressed() -> void:
	var path = "res://addons/CustomControls/Dialogs/select_any_data_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	dialog.database = RPGSYSTEM.database
	dialog.destroy_on_hide = true
	
	var data: Variant
	var db_key: String
	var current_uid: int
	var title: String
	
	match current_data.type:
		0:
			db_key = "items"
			current_uid = current_item_id
			title = TranslationManager.tr("Items")
		1:
			db_key = "weapons"
			current_uid = current_weapon_id
			title = TranslationManager.tr("Weapons")
		2:
			db_key = "armors"
			current_uid = current_armor_id
			title = TranslationManager.tr("Armors")
		3:
			db_key = "costumes"
			current_uid = current_costume_id
			title = TranslationManager.tr("Costumes")
			
	data = RPGSYSTEM.database[db_key]
	var classic_id = RPGSYSTEM.uid_to_id(db_key, current_uid)
	classic_id = max(1, min(classic_id, data.size() - 1))
	
	dialog.selected.connect(_on_item_selected, CONNECT_ONE_SHOT)
	dialog.setup(data, classic_id, title, self)



## Handles the result from the selection dialog and converts the classic ID to UID
func _on_item_selected(index: int, target: Variant) -> void:
	var db_key: String
	
	match current_data.type:
		0: db_key = "items"
		1: db_key = "weapons"
		2: db_key = "armors"
		3: db_key = "costumes"
		
	var uid = RPGSYSTEM.id_to_uid(db_key, index)
	current_data.item_id = uid
	
	match current_data.type:
		0: current_item_id = uid
		1: current_weapon_id = uid
		2: current_armor_id = uid
		3: current_costume_id = uid
		
	update_id_text()



## Triggers the move down action
func _on_move_down_pressed() -> void:
	move_down_request.emit(get_index())



## Triggers the move up action
func _on_move_up_pressed() -> void:
	move_up_request.emit(get_index())



## Updates the level value in the data dictionary
func _on_level_value_changed(value: float) -> void:
	current_data.level = value



## Updates the restock amount value in the data dictionary
func _on_restock_amount_value_changed(value: float) -> void:
	current_data.restock_amount = value
