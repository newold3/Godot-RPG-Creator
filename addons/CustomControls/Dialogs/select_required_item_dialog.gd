@tool
extends Window

#region Variables
var database: RPGDATA
var data: RPGGearUpgradeComponent
var real_data: RPGGearUpgradeComponent

signal component_created(component: RPGGearUpgradeComponent)
signal component_updated(component: RPGGearUpgradeComponent)
#endregion



#region Lifecycle
## Initializes the dialog and sets initial focus
func _ready() -> void:
	close_requested.connect(queue_free)
	%Quantity.get_line_edit().grab_focus()
#endregion



#region Setup
## Toggles the visibility of the percentage container
func enable_percent(value: bool) -> void:
	%PercentContainer.visible = value
	size.y = 0



## Loads existing component data into the dialog
func set_data(_data: RPGGearUpgradeComponent) -> void:
	data = _data.clone(true)
	real_data = _data
	fill_all()



## Initializes fresh data for a new component
func create_new_data() -> void:
	data = RPGGearUpgradeComponent.new()
	fill_all()



## Updates all UI fields based on current data
func fill_all() -> void:
	%DataType.select(data.component.data_id)
	%Quantity.value = data.quantity
	%Percent.value = data.percent
	fill_item()



## Fetches the correct item from the database using its UID and formats the button text
func fill_item() -> void:
	if !database: return
	
	var node = %ItemType
	var db_key = ""
	
	match data.component.data_id:
		0: db_key = "items"
		1: db_key = "weapons"
		2: db_key = "armors"
	
	var uid = data.component.item_id
	
	if uid > 0:
		if uid < 1000000:
			uid = RPGSYSTEM.id_to_uid(db_key, uid)
			data.component.item_id = uid
			
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
## Opens the generic selection dialog converting the UID to a classic ID first
func _on_item_type_pressed() -> void:
	var path = "res://addons/CustomControls/Dialogs/select_any_data_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	dialog.database = database
	dialog.destroy_on_hide = true
	
	var current_data
	var title
	var db_key = ""
	
	match data.component.data_id:
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
			
	var uid = data.component.item_id
	var classic_id = RPGSYSTEM.uid_to_id(db_key, uid) if uid > 0 else 1
	classic_id = max(1, min(classic_id, current_data.size() - 1))
	
	var target = self
	dialog.selected.connect(_on_item_selected, CONNECT_ONE_SHOT)
	dialog.setup(current_data, classic_id, title, target)



## Receives the selected ID from the sub-dialog, converts it to UID and updates the data
func _on_item_selected(id: int, target: Variant) -> void:
	var db_key = ""
	match data.component.data_id:
		0: db_key = "items"
		1: db_key = "weapons"
		2: db_key = "armors"
		
	var uid = RPGSYSTEM.id_to_uid(db_key, id)
	data.component.item_id = uid
	fill_item()



## Handles changing the data category and resets the selected item UID safely
func _on_data_type_item_selected(index: int) -> void:
	data.component.data_id = index
	
	var db_key = ""
	match index:
		0: db_key = "items"
		1: db_key = "weapons"
		2: db_key = "armors"
		
	data.component.item_id = RPGSYSTEM.id_to_uid(db_key, 1)
	fill_item()



## Updates the required quantity
func _on_quantity_value_changed(value: float) -> void:
	if not data: return
	data.quantity = value



## Submits the configured component and closes the dialog
func _on_ok_button_pressed() -> void:
	propagate_call("apply")
	if real_data:
		real_data.component.data_id = data.component.data_id
		real_data.component.item_id = data.component.item_id
		real_data.quantity = data.quantity
		real_data.percent = data.percent
		component_updated.emit(real_data)
	else:
		component_created.emit(data)
	queue_free()



## Cancels the operation and closes the dialog
func _on_cancel_button_pressed() -> void:
	queue_free()



## Updates the percent value
func _on_percent_value_changed(value: float) -> void:
	data.percent = value
#endregion
