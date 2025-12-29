@tool
extends Window


var current_data: TroopSpawnData
var real_data: TroopSpawnData
var creating_troop_spawn_data_enabled: bool = false


signal troop_spawn_data_created(data: TroopSpawnData)
signal troop_spawn_data_updated(data: TroopSpawnData)


func _ready() -> void:
	close_requested.connect(queue_free)


func set_data(data: TroopSpawnData) -> void:
	real_data = data
	current_data = data.duplicate(true)
	creating_troop_spawn_data_enabled = current_data.troop_id == 0
	current_data.troop_id = max(1, current_data.troop_id)
	%Occasion.value = data.occasion
	_set_item_name()


func _on_item_id_pressed() -> void:
	var path = "res://addons/CustomControls/Dialogs/select_any_data_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	
	dialog.database = RPGSYSTEM.database
	dialog.destroy_on_hide = true
	
	dialog.selected.connect(_on_item_selected)
	
	var item_id = current_data.troop_id
	dialog.setup(RPGSYSTEM.database.troops, item_id, "Toops", null)


func _on_item_selected(id: int, target: Variant) -> void:
	current_data.troop_id = id
	_set_item_name()


func _on_occasion_value_changed(value: float) -> void:
	current_data.occasion = value


func _set_item_name() -> void:
	var items = RPGSYSTEM.database.troops
	var index = current_data.troop_id
	if index == 0:
		current_data.troop_id = 1
		index = 1
	if items.size() > index:
		var item_name = "%s:%s" % [
			str(index).pad_zeros(str(items.size()).length()),
			items[index].name
		]
		%ItemID.text = item_name
	else:
		%ItemID.text = "⚠ Invalid Item"


func _on_ok_button_pressed() -> void:
	propagate_call("apply")
	
	if creating_troop_spawn_data_enabled:
		troop_spawn_data_created.emit(current_data)
	else:
		var keys = ["troop_id", "occasion"]
		for key in keys:
			real_data.set(key, current_data.get(key))
		troop_spawn_data_updated.emit(real_data)
	
	queue_free()


func _on_cancel_button_pressed() -> void:
	queue_free()
