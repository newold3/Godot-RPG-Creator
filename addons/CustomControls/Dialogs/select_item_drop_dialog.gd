@tool
extends Window

var database: RPGDATA
var data: RPGItemDrop
var real_data: RPGItemDrop

var busy: bool = false

signal item_created(item: RPGItemDrop)
signal item_updated(item: RPGItemDrop)


func _ready() -> void:
	close_requested.connect(queue_free)
	%Quantity.get_line_edit().grab_focus()


func hide_percent():
	%PercentContainer.visible = false


func set_data(_data: RPGItemDrop) -> void:
	data = _data.clone(true)
	real_data = _data
	fill_all()


func create_new_data() -> void:
	data = RPGItemDrop.new()
	fill_all()


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


func fill_item() -> void:
	if !database: return
	
	var node = %ItemType
	
	var current_data
	if data.item.data_id == 0:
		current_data = database.items
	elif data.item.data_id == 1:
		current_data = database.weapons
	elif data.item.data_id == 2:
		current_data = database.armors
	
	if current_data.size() > data.item.item_id:
		var item_name = current_data[data.item.item_id].name
		if item_name.length() == 0:
			item_name = "# %s" % (data.item.item_id)
		node.text = item_name
	elif data.item.item_id > 0:
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
	if data.item.data_id == 0:
		current_data = database.items
		title = TranslationManager.tr("Items")
	elif data.item.data_id == 1:
		current_data = database.weapons
		title = TranslationManager.tr("Weapons")
	elif data.item.data_id == 2:
		current_data = database.armors
		title = TranslationManager.tr("Armors")
	var id_selected = data.item.item_id
	var target = self
	dialog.selected.connect(_on_item_selected, CONNECT_ONE_SHOT)
	dialog.setup(current_data, id_selected, title, target)


func _on_item_selected(id: int, target: Variant) -> void:
	data.item.item_id = id
	fill_item()


func _on_data_type_item_selected(index: int) -> void:
	data.item.data_id = index
	data.item.item_id = 1
	fill_item()
	%LevelContainer.visible = index > 0
	size.y = 0


func _on_quantity_value_changed(value: float) -> void:
	if busy: return
	busy = true
	
	data.quantity = value
	
	data.quantity2 = max(value, data.quantity2)
	%Quantity2.value = data.quantity2
	
	
	busy = false


func _on_quantity_2_value_changed(value: float) -> void:
	if busy: return
	busy = true
	
	data.quantity2 = value
	
	data.quantity = min(value, data.quantity)
	%Quantity.value = data.quantity
	
	
	busy = false


func _on_drop_percent_value_changed(value: float) -> void:
	data.percent = value


func _on_min_level_value_changed(value: float) -> void:
	if busy: return
	busy = true
	
	data.min_level = value
	
	data.max_level = max(value, data.max_level)
	%MaxLevel.value = data.max_level
	
	
	busy = false


func _on_max_level_value_changed(value: float) -> void:
	if busy: return
	busy = true
	
	data.max_level = value
	
	data.min_level = min(value, data.min_level)
	%MinLevel.value = data.min_level
	
	
	busy = false


func _on_ok_button_pressed() -> void:
	%Quantity2.apply()
	%Quantity.apply()
	%DropPercent.apply()
	%MinLevel.apply()
	%MaxLevel.apply()
	if real_data:
		real_data.item.data_id = data.item.data_id
		real_data.quantity = data.quantity
		real_data.quantity2 = data.quantity2
		real_data.percent = data.percent
		real_data.min_level = data.min_level
		real_data.max_level = data.max_level
		item_updated.emit(real_data)
	else:
		item_created.emit(data)
	queue_free()


func _on_cancel_button_pressed() -> void:
	queue_free()
