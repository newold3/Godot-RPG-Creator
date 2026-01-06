@tool
extends Window


var data: RPGRecipe

signal recipe_changed(recipe: RPGRecipe)

func _ready() -> void:
	close_requested.connect(queue_free)


func set_data(_data: RPGRecipe) -> void:
	data = _data.clone(true)
	
	_update_fields()


func _update_fields() -> void:
	if not data: return
	
	%Name.text = data.name
	%Price.value = data.price
	%Quantity.value = data.quantity
	%LearnedByDefault.set_pressed_no_signal(data.learned_by_default)
	
	_fill_list()


func _fill_list(index: int = -1) -> void:
	var node = %MaterialsPanel
	node.clear()
	
	if data:
		for item: RPGGearUpgradeComponent in data.materials:
			var item_name: String = ""
			var db: Variant
			match item.component.data_id:
				0: item_name = tr("Item"); db = RPGSYSTEM.database.items
				1: item_name = tr("Weapon"); db = RPGSYSTEM.database.weapons
				2: item_name = tr("Armor"); db = RPGSYSTEM.database.armors
			if item.component.item_id > 0 and db.size() > item.component.item_id:
				item_name = item_name + " " + db[item.component.item_id].name
			else:
				item_name = item_name + " ???" 
			node.add_column([item_name, item.quantity])
		
		if data.materials.size() > 0:
			await node.columns_setted
			index = max(0, min(index, data.materials.size() - 1))
			node.select(index)


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


func _on_component_created(component: RPGGearUpgradeComponent) -> void:
	if data:
		data.materials.append(component)
		
	_fill_list(data.materials.size() - 1)


func _on_component_updated(component: RPGGearUpgradeComponent, index: int) -> void:
	if data and data.materials.size() > index:
		data.materials[index] = component
		_fill_list(index)
	else:
		_on_component_created(component)


func _on_ok_button_pressed() -> void:
	propagate_call("apply")
	recipe_changed.emit(data)
	queue_free()


func _on_cancel_button_pressed() -> void:
	queue_free()


func _on_name_text_changed(new_text: String) -> void:
	data.name = new_text


func _on_price_value_changed(value: float) -> void:
	data.price = value


func _on_materials_panel_delete_pressed(indexes: PackedInt32Array) -> void:
	var remove_materials: Array[RPGGearUpgradeComponent] = []
	var materials = data.materials
	for index in indexes:
		if index >= 0 and materials.size() > index:
			remove_materials.append(materials[index])
	for obj in remove_materials:
		materials.erase(obj)
	_fill_list(indexes[0])


func _on_quantity_value_changed(value: float) -> void:
	data.quantity = value


func _on_learned_by_default_toggled(toggled_on: bool) -> void:
	data.learned_by_default = toggled_on
