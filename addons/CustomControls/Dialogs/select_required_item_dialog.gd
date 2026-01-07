@tool
extends Window

var database: RPGDATA
var data: RPGGearUpgradeComponent
var real_data: RPGGearUpgradeComponent


signal component_created(component: RPGGearUpgradeComponent)
signal component_updated(component: RPGGearUpgradeComponent)


func _ready() -> void:
	close_requested.connect(queue_free)
	%Quantity.get_line_edit().grab_focus()


func enable_percent(value: bool) -> void:
	%PercentContainer.visible = value
	size.y = 0


func set_data(_data: RPGGearUpgradeComponent) -> void:
	data = _data.clone(true)
	real_data = _data
	fill_all()


func create_new_data() -> void:
	data = RPGGearUpgradeComponent.new()
	fill_all()


func fill_all() -> void:
	%DataType.select(data.component.data_id)
	%Quantity.value = data.quantity
	%Percent.value = data.percent
	fill_item()


func fill_item() -> void:
	if !database: return
	
	var node = %ItemType
	
	var current_data
	if data.component.data_id == 0:
		current_data = database.items
	elif data.component.data_id == 1:
		current_data = database.weapons
	elif data.component.data_id == 2:
		current_data = database.armors
	
	if current_data.size() > data.component.item_id:
		var item_name = current_data[data.component.item_id].name
		if item_name.length() == 0:
			item_name = "# %s" % (data.component.item_id)
		node.text = item_name
	elif data.component.item_id > 0:
		node.text = "⚠ Invalid Data"
	else:
		node.text = TranslationManager.tr("none")

func _on_item_type_pressed() -> void:
	var path = "res://addons/CustomControls/Dialogs/select_any_data_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	dialog.database = database
	dialog.destroy_on_hide = true
	var current_data
	var title
	if data.component.data_id == 0:
		current_data = database.items
		title = TranslationManager.tr("Items")
	elif data.component.data_id == 1:
		current_data = database.weapons
		title = TranslationManager.tr("Weapons")
	elif data.component.data_id == 2:
		current_data = database.armors
		title = TranslationManager.tr("Armors")
	var id_selected = data.component.item_id
	var target = self
	dialog.selected.connect(_on_item_selected, CONNECT_ONE_SHOT)
	dialog.setup(current_data, id_selected, title, target)


func _on_item_selected(id: int, target: Variant) -> void:
	data.component.item_id = id
	fill_item()


func _on_data_type_item_selected(index: int) -> void:
	data.component.data_id = index
	data.component.item_id = 1
	fill_item()


func _on_quantity_value_changed(value: float) -> void:
	data.quantity = value


func _on_ok_button_pressed() -> void:
	propagate_call("apply")
	if real_data:
		real_data.component.data_id = data.component.data_id
		real_data.component.item_id = data.component.item_id
		real_data.quantity = data.quantity
		component_updated.emit(real_data)
	else:
		component_created.emit(data)
	queue_free()


func _on_cancel_button_pressed() -> void:
	queue_free()


func _on_percent_value_changed(value: float) -> void:
	data.percent = value
