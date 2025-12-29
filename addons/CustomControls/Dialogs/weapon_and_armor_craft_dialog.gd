@tool
extends Window

var database: RPGDATA
var data: Array[RPGGearUpgradeComponent]

var cost: int

var busy: bool = false

signal materials_changed(materials: Array[RPGGearUpgradeComponent], cost: int)


func _ready() -> void:
	close_requested.connect(queue_free)
	%MaterialList.set_lock_items(PackedInt32Array([0]))


func set_data(_database: RPGDATA, _data: Array[RPGGearUpgradeComponent], _cost: int) -> void:
	database = _database
	data = []
	for component in _data:
		data.append(component.clone())
	cost = _cost
	
	fill_material_list()
	
	if title.begins_with("Disassemble"):
		
		%MaterialList.default_tooltip = "Materials obtained after dismantling this item."
	else:
		%MaterialList.default_tooltip = "Materials required for the construction of this item."


func fill_material_list(selected_index: int = -1) -> void:
	var node = %MaterialList
	node.clear()
	
	node.add_column(["Cost", str(cost)])
	
	if !database: return
	
	for mat: RPGGearUpgradeComponent in data:
		var current_data
		var prefix
		if mat.component.data_id == 0: # items
			current_data = database.items
			prefix = "<Item> "
		elif mat.component.data_id == 1: # weapons
			current_data = database.weapons
			prefix = "<Weapon> "
		elif mat.component.data_id == 2: # armors
			current_data = database.armors
			prefix = "<Armor> "
		
		if current_data:
			if current_data.size() > mat.component.item_id:
				var item_name = str(mat.component.item_id).pad_zeros(str(current_data.size()).length()) + ": " + current_data[mat.component.item_id].name
				var quantity = str(mat.quantity)
				node.add_column([prefix + item_name, quantity])
			else:
				var quantity = str(mat.quantity)
				node.add_column([prefix + "⚠ Invalid Data", quantity])
	
	if selected_index >= 0:
		await node.columns_setted
		node.select(selected_index)


func _on_ok_button_pressed() -> void:
	materials_changed.emit(data, cost)
	queue_free()


func _on_cancel_button_pressed() -> void:
	queue_free()


func _on_material_list_item_activated(index: int) -> void:
	if index == 0: # Gold
		show_select_number_dialog("Cost", 0)
	else: # Items, weapons or armors
		if data.size() > index - 1:
			show_select_required_item_dialog(data[index-1], index)
		else: # new_material
			show_select_required_item_dialog()


func show_select_number_dialog(_title: String, index: int) -> void:
	var path = "res://addons/CustomControls/Dialogs/select_number_value_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	dialog.title = _title + TranslationManager.tr(" amount")
	if index == 0:
		dialog.set_min_max_values(0, 0)
		dialog.set_value(cost)
	dialog.selected_value.connect(_on_select_number_dialog_selected_value.bind(index))


func _on_select_number_dialog_selected_value(value: int, index: int) -> void:
	if index == 0:
		cost = value
	
	fill_material_list(index)


func show_select_required_item_dialog(item: RPGGearUpgradeComponent = null, index: int = -1) -> void:
	var path = "res://addons/CustomControls/Dialogs/select_required_item_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	dialog.database = database
	if item:
		dialog.set_data(item)
		dialog.component_updated.connect(_on_component_updated.bind(index))
	else:
		dialog.create_new_data()
		dialog.component_created.connect(_on_component_created)


func _on_component_created(component: RPGGearUpgradeComponent) -> void:
	var material_found: bool = false
	var material_index: int = -1
	for i in data.size():
		var mat: RPGGearUpgradeComponent = data[i]
		if component.component.data_id == mat.component.data_id and component.component.item_id == mat.component.item_id:
			mat.quantity = component.quantity
			material_found = true
			material_index = i
			break

	if !material_found:
		data.append(component)
		fill_material_list(data.size() + 1)
	else:
		fill_material_list(material_index + 1)


func _on_component_updated(_component: RPGGearUpgradeComponent, index: int) -> void:
	var duplicate_found: bool = false
	for i in data.size():
		var mat1: RPGGearUpgradeComponent = data[i]
		for j in range(data.size() - 1, i, -1):
			var mat2: RPGGearUpgradeComponent = data[j]
			if mat1.component.data_id == mat2.component.data_id and mat1.component.item_id == mat2.component.item_id:
				mat1.quantity = mat2.quantity
				data.erase(mat2)
				index = i + 1
				duplicate_found = true
				break
		if duplicate_found: break

	fill_material_list(index)

#region Material list signals
func _on_material_list_delete_pressed(indexes: PackedInt32Array) -> void:
	var remove_components: Array[RPGGearUpgradeComponent] = []
	for index in indexes:
		if index >= 1 and data.size() > index - 1:
			remove_components.append(data[index - 1])
	for obj in remove_components:
		data.erase(obj)
	fill_material_list(indexes[0])


func _on_material_list_copy_requested(indexes: PackedInt32Array) -> void:
	var copy_components: Array[RPGGearUpgradeComponent]
	for index in indexes:
		var real_index = index - 1
		if real_index > data.size() or real_index < 0:
			continue
		copy_components.append(data[real_index].clone(true))
		
	StaticEditorVars.CLIPBOARD["components"] = copy_components


func _on_material_list_cut_requested(indexes: PackedInt32Array) -> void:
	var copy_components: Array[RPGGearUpgradeComponent]
	var remove_components: Array[RPGGearUpgradeComponent]
	for index in indexes:
		var real_index = index - 1
		if real_index > data.size():
			continue
		if data.size() > real_index and real_index >= 0:
			copy_components.append(data[real_index].clone(true))
			remove_components.append(data[real_index])
	for item in remove_components:
		data.erase(item)

	StaticEditorVars.CLIPBOARD["components"] = copy_components
	
	var item_selected = max(-1, indexes[0])
	fill_material_list(item_selected)


func _on_material_list_paste_requested(index: int) -> void:
	if index < 1: index = 1
	
	if StaticEditorVars.CLIPBOARD.has("components"):
		for i in StaticEditorVars.CLIPBOARD["components"].size():
			var mat1: RPGGearUpgradeComponent = StaticEditorVars.CLIPBOARD["components"][i].clone()
			var material_setted: bool = false
			for j in data.size():
				var mat2: RPGGearUpgradeComponent = data[j]
				if mat1.component.data_id == mat2.component.data_id and mat1.component.item_id == mat2.component.item_id:
					mat2.quantity = mat1.quantity
					material_setted = true
					break
					
			if material_setted: continue
			
			var real_index = index + i - 1
			if real_index < data.size():
				data.insert(real_index, mat1)
			else:
				data.append(mat1)
	
	fill_material_list(min(index + 1, data.size() - 1))
	
	var list = %MaterialList
	await list.columns_setted
	await get_tree().process_frame
	await get_tree().process_frame
	list.deselect_all()
	if StaticEditorVars.CLIPBOARD.has("components"):
		for i in StaticEditorVars.CLIPBOARD["components"].size():
			for j in data.size():
				var mat1: RPGGearUpgradeComponent = StaticEditorVars.CLIPBOARD["components"][i]
				var mat2: RPGGearUpgradeComponent = data[j]
				if mat1.component.data_id == mat2.component.data_id and mat1.component.item_id == mat2.component.item_id:
					list.select(j+1, false)
					break

#endregion
