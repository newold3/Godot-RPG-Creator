@tool
extends Window

#region Variables
var data: RPGRecipe

signal recipe_changed(recipe: RPGRecipe)
#endregion



#region Initialization
## Called when the node enters the scene tree for the first time
func _ready() -> void:
	close_requested.connect(queue_free)



## Sets the dialog data safely duplicating the original recipe
func set_data(_data: RPGRecipe) -> void:
	data = _data.clone(true)
	
	_update_fields()
#endregion



#region UI Updates
## Updates all the visual fields based on the recipe data
func _update_fields() -> void:
	if not data: return
	
	%Name.text = data.name
	%Price.value = data.price
	%Quantity.value = data.quantity
	%LearnedByDefault.set_pressed_no_signal(data.learned_by_default)
	
	_fill_list()



## Populates the list of required materials formatting the names dynamically with UIDs
func _fill_list(index: int = -1) -> void:
	var node = %MaterialsPanel
	node.clear()
	
	if data:
		for item: RPGGearUpgradeComponent in data.materials:
			var item_name: String = ""
			var db_key: String = ""
			var prefix: String = ""
			
			match item.component.data_id:
				0: 
					prefix = tr("Item")
					db_key = "items"
				1: 
					prefix = tr("Weapon")
					db_key = "weapons"
				2: 
					prefix = tr("Armor")
					db_key = "armors"
					
			var uid = item.component.item_id
			
			# Fallback for legacy IDs
			if uid > 0 and uid < 1000000:
				uid = RPGSYSTEM.id_to_uid(db_key, uid)
				item.component.item_id = uid
				
			var res_data = RPGSYSTEM.get_data(db_key, uid)
			
			if res_data:
				var classic_id = RPGSYSTEM.uid_to_id(db_key, uid)
				var id_padded = str(classic_id).pad_zeros(str(RPGSYSTEM.database[db_key].size()).length())
				item_name = "%s (%s: %s)" % [prefix, id_padded, res_data.name]
			else:
				item_name = "%s (⚠ Invalid Data)" % prefix
				
			node.add_column([item_name, item.quantity])
		
		if data.materials.size() > 0:
			await node.columns_setted
			index = max(0, min(index, data.materials.size() - 1))
			node.select(index)
#endregion



#region Event Handlers
## Opens the dialog to add or edit a specific required material
func _on_materials_panel_item_activated(index: int) -> void:
	var path = "res://addons/CustomControls/Dialogs/select_required_item_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	dialog.database = RPGSYSTEM.database
	
	var item: Variant
	if index >= 0 and data.materials.size() > index:
		item = data.materials[index]
		
	if item:
		dialog.set_data(item)
		dialog.component_updated.connect(_on_component_updated.bind(index))
	else:
		dialog.create_new_data()
		dialog.component_created.connect(_on_component_created)



## Callback when a new component is successfully created
func _on_component_created(component: RPGGearUpgradeComponent) -> void:
	if data:
		data.materials.append(component)
		
	_fill_list(data.materials.size() - 1)



## Callback when an existing component is updated
func _on_component_updated(component: RPGGearUpgradeComponent, index: int) -> void:
	if data and data.materials.size() > index:
		data.materials[index] = component
		_fill_list(index)
	else:
		_on_component_created(component)



## Commits the recipe changes and closes the dialog
func _on_ok_button_pressed() -> void:
	propagate_call("apply")
	recipe_changed.emit(data)
	queue_free()



## Cancels the operation without saving
func _on_cancel_button_pressed() -> void:
	queue_free()



## Updates the name of the recipe
func _on_name_text_changed(new_text: String) -> void:
	data.name = new_text



## Updates the price of the recipe
func _on_price_value_changed(value: float) -> void:
	data.price = value



## Deletes selected materials from the list
func _on_materials_panel_delete_pressed(indexes: PackedInt32Array) -> void:
	var remove_materials: Array[RPGGearUpgradeComponent] = []
	var materials = data.materials
	
	for index in indexes:
		if index >= 0 and materials.size() > index:
			remove_materials.append(materials[index])
			
	for obj in remove_materials:
		materials.erase(obj)
		
	_fill_list(indexes[0])



## Updates the quantity of items yielded by the recipe
func _on_quantity_value_changed(value: float) -> void:
	data.quantity = value



## Toggles whether the recipe is known by default
func _on_learned_by_default_toggled(toggled_on: bool) -> void:
	data.learned_by_default = toggled_on
#endregion
