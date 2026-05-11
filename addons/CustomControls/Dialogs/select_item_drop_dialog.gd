@tool
extends Window

#region Variables
var database: RPGDATA
var data: RPGItemDrop
var real_data: RPGItemDrop

var busy: bool = false

signal item_created(item: RPGItemDrop)
signal item_updated(item: RPGItemDrop)
#endregion



#region Lifecycle and Setup
## Initializes the dialog and sets initial focus
func _ready() -> void:
	close_requested.connect(queue_free)
	%Quantity.get_line_edit().grab_focus()



## Hides the percent container
func hide_percent() -> void:
	%PercentContainer.visible = false



## Sets the data to be edited, cloning it safely
func set_data(_data: RPGItemDrop) -> void:
	data = _data.clone(true)
	real_data = _data
	fill_all()



## Initializes a new data instance for creation
func create_new_data() -> void:
	data = RPGItemDrop.new()
	fill_all()



## Populates all UI fields with the current data
func fill_all() -> void:
	busy = true
	%DataType.select(data.item.data_id)
	%Quantity2.value = data.quantity2
	%Quantity.value = data.quantity
	%DropPercent.value = data.percent
	%MinLevel.value = data.min_level
	%MaxLevel.value = data.max_level
	
	fill_item()
	
	%LevelContainer.visible = data.item.data_id > 0
	size.y = 0
	busy = false



## Fetches the correct item using UID and formats the button text
func fill_item() -> void:
	if !database: return
	
	var node = %ItemType
	var db_key = ""
	
	match data.item.data_id:
		0: db_key = "items"
		1: db_key = "weapons"
		2: db_key = "armors"
		3: db_key = "costumes"
	
	var uid = data.item.item_id
	
	if uid > 0:
		if uid < 1000000:
			uid = RPGSYSTEM.id_to_uid(db_key, uid)
			data.item.item_id = uid
			
		var res_data = RPGSYSTEM.get_data(db_key, uid)
		if res_data:
			var classic_id = RPGSYSTEM.uid_to_id(db_key, uid)
			var id_padded = str(classic_id).pad_zeros(str(database[db_key].size()).length())
			var item_name = res_data.name if not res_data.name.is_empty() else "# %s" % classic_id
			node.text = "%s: %s" % [id_padded, item_name]
		else:
			node.text = "⚠ Invalid Data"
	else:
		node.text = TranslationManager.tr("none")
#endregion



#region Event Handlers
## Opens the generic item selection dialog passing the classic ID
func _on_item_type_pressed() -> void:
	var path = "res://addons/CustomControls/Dialogs/select_any_data_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	dialog.database = database
	dialog.destroy_on_hide = true
	
	var current_data
	var title = ""
	var db_key = ""
	
	match data.item.data_id:
		0:
			current_data = database.items
			title = TranslationManager.tr("Items")
			db_key = "items"
		1:
			current_data = database.weapons
			title = TranslationManager.tr("Weapons")
			db_key = "weapons"
		2:
			current_data = database.armors
			title = TranslationManager.tr("Armors")
			db_key = "armors"
		3:
			current_data = database.costumes
			title = TranslationManager.tr("Costumes")
			db_key = "costumes"
	
	var uid = data.item.item_id
	var classic_id = RPGSYSTEM.uid_to_id(db_key, uid) if uid > 0 else 1
	classic_id = max(1, min(classic_id, current_data.size() - 1))
	
	var target = self
	dialog.selected.connect(_on_item_selected, CONNECT_ONE_SHOT)
	dialog.setup(current_data, classic_id, title, target)



## Receives the classic ID from the sub-dialog, converts it to UID and updates the data
func _on_item_selected(id: int, target: Variant) -> void:
	var db_key = ""
	match data.item.data_id:
		0: db_key = "items"
		1: db_key = "weapons"
		2: db_key = "armors"
		3: db_key = "costumes"
		
	var uid = RPGSYSTEM.id_to_uid(db_key, id)
	data.item.item_id = uid
	fill_item()



## Handles data type changes and resets the item UID safely
func _on_data_type_item_selected(index: int) -> void:
	data.item.data_id = index
	
	var db_key = ""
	match index:
		0: db_key = "items"
		1: db_key = "weapons"
		2: db_key = "armors"
		3: db_key = "costumes"
		
	data.item.item_id = RPGSYSTEM.id_to_uid(db_key, 1)
	fill_item()
	
	%LevelContainer.visible = index > 0 and index < 3
	size.y = 0



## Updates the primary quantity value ensuring range constraints
func _on_quantity_value_changed(value: float) -> void:
	if busy or not data: return
	busy = true
	
	data.quantity = value
	data.quantity2 = max(value, data.quantity2)
	%Quantity2.value = data.quantity2
	
	busy = false



## Updates the secondary quantity value (range max)
func _on_quantity_2_value_changed(value: float) -> void:
	if busy or not data: return
	busy = true
	
	data.quantity2 = value
	data.quantity = min(value, data.quantity)
	%Quantity.value = data.quantity
	
	busy = false



## Updates the drop probability percent
func _on_drop_percent_value_changed(value: float) -> void:
	if not data: return
	data.percent = value



## Updates the minimum enemy level for this drop
func _on_min_level_value_changed(value: float) -> void:
	if busy or not data: return
	busy = true
	
	data.min_level = value
	data.max_level = max(value, data.max_level)
	%MaxLevel.value = data.max_level
	
	busy = false



## Updates the maximum enemy level for this drop
func _on_max_level_value_changed(value: float) -> void:
	if busy or not data: return
	busy = true
	
	data.max_level = value
	data.min_level = min(value, data.min_level)
	%MinLevel.value = data.min_level
	
	busy = false



## Submits the changes and closes the dialog
func _on_ok_button_pressed() -> void:
	%Quantity2.apply()
	%Quantity.apply()
	%DropPercent.apply()
	%MinLevel.apply()
	%MaxLevel.apply()
	
	if real_data:
		real_data.item.data_id = data.item.data_id
		real_data.item.item_id = data.item.item_id
		real_data.quantity = data.quantity
		real_data.quantity2 = data.quantity2
		real_data.percent = data.percent
		real_data.min_level = data.min_level
		real_data.max_level = data.max_level
		item_updated.emit(real_data)
	else:
		item_created.emit(data)
		
	queue_free()



## Cancels the operation and closes the dialog
func _on_cancel_button_pressed() -> void:
	queue_free()
#endregion
