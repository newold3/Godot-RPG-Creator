@tool
extends Window

var real_region: EnemySpawnRegion
var current_region: EnemySpawnRegion

var undo_redo: EditorUndoRedoManager
var current_object: Object
var plugin: RPGMapPlugin

signal region_changed(region: EnemySpawnRegion)


func _ready() -> void:
	close_requested.connect(queue_free)
	%ApplyButton.set_disabled(true)
	%Name.grab_focus()


func set_region(region: EnemySpawnRegion) -> void:
	real_region = region
	current_region = region.clone(true)
	title = TranslationManager.tr("Edit Region | %s: %s") % [region.id, region.name]
	%Name.text = region.name
	%PositionX.value = region.rect.position.x
	%PositionY.value = region.rect.position.y
	%SizeX.value = region.rect.size.x
	%SizeY.value = region.rect.size.y
	%Steps.value = region.steps
	%ColorButton.set_color(region.color)
	
	fill_troop_list(0)
	
	%ApplyButton.set_disabled(true)


func fill_troop_list(selected_index: int = -1) -> void:
	var node = %TroopList
	node.clear()
	
	if !RPGSYSTEM.database:
		return

	for troop_data: TroopSpawnData in current_region.troop_list:
		var column := []
		for i: int in range(1, RPGSYSTEM.database.troops.size(), 1):
			var troop : RPGTroop = RPGSYSTEM.database.troops[i]
			if troop.id == troop_data.troop_id:
				column.append(troop.name if troop.name else str(troop.id))
				column.append("%10.2f %%" % troop_data.occasion)
				break
		if !column:
			column.append_array(["⚠ Invalid Data", "0%"])
		
		node.add_column(column)
	
	if selected_index != -1:
		await node.columns_setted
		%TroopList.select(selected_index)


func _on_ok_button_pressed() -> void:
	_create_undo_redo_action()
	queue_free()


func _create_undo_redo_action() -> void:
	propagate_call("apply")
	
	if not current_region or not real_region or not undo_redo or not current_object:
		push_error("Faltan datos para crear la acción de undo/redo")
		return
	
	# Crear copia del estado modificado
	var modified_region = current_region.clone(true)
	var original_copy = real_region.clone(true)
	
	# Encontrar el índice de la región
	var region_index: int = -1
	for i in current_object.regions.size():
		if current_object.regions[i].id == real_region.id:
			region_index = i
			break
	
	if region_index == -1:
		push_error("No se encontró la región en la lista")
		return
	
	undo_redo.create_action("Edit Spawn Region", UndoRedo.MERGE_DISABLE, current_object)
	
	# DO - aplicar los cambios
	undo_redo.add_do_method(plugin, "_force_mode_switch", plugin.current_edit_mode)
	undo_redo.add_do_method(current_object, "_update_spawn_region", region_index, modified_region)
	undo_redo.add_do_method(EditorInterface, "mark_scene_as_unsaved")
	
	# UNDO - restaurar la región original
	undo_redo.add_undo_method(plugin, "_force_mode_switch", plugin.current_edit_mode)
	undo_redo.add_undo_method(current_object, "_update_spawn_region", region_index, original_copy)
	undo_redo.add_undo_method(EditorInterface, "mark_scene_as_unsaved")
	
	undo_redo.commit_action()
	
	region_changed.emit(modified_region)
	%ApplyButton.set_disabled(true)


func _on_cancel_button_pressed() -> void:
	queue_free()


func _on_apply_button_pressed() -> void:
	_create_undo_redo_action()
	%ApplyButton.set_disabled(true)


func _on_name_text_changed(new_text: String) -> void:
	if current_region:
		%ApplyButton.set_disabled(false)
		current_region.name = new_text
		title = TranslationManager.tr("Edit Region | %s: %s") % [current_region.id, current_region.name]


func _on_position_x_value_changed(value: float) -> void:
	if current_region:
		%ApplyButton.set_disabled(false)
		current_region.rect.position.x = value


func _on_position_y_value_changed(value: float) -> void:
	if current_region:
		%ApplyButton.set_disabled(false)
		current_region.rect.position.y = value


func _on_size_x_value_changed(value: float) -> void:
	if current_region:
		%ApplyButton.set_disabled(false)
		current_region.rect.size.x = value


func _on_size_y_value_changed(value: float) -> void:
	if current_region:
		%ApplyButton.set_disabled(false)
		current_region.rect.size.y = value


func _on_color_button_pressed() -> void:
	var path = "res://addons/CustomControls/Dialogs/select_color.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	
	dialog.title = TranslationManager.tr("Select Region Color")
	dialog.color_selected.connect(_on_color_selected)
	dialog.set_color(current_region.color)


func _on_color_selected(color: Color) -> void:
	%ApplyButton.set_disabled(false)
	current_region.color = color
	%ColorButton.set_color(color)


func _on_troop_list_item_activated(index: int) -> void:
	var path = "res://addons/CustomControls/Dialogs/select_spawn_troop_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	
	dialog.troop_spawn_data_created.connect(_on_troop_spawn_data_created)
	dialog.troop_spawn_data_updated.connect(_on_troop_spawn_data_updated)
	
	if current_region.troop_list.size() > index:
		dialog.set_data(current_region.troop_list[index])
		dialog.title = TranslationManager.tr("Update Troop Spawn Data")
	else:
		dialog.set_data(TroopSpawnData.new())
		dialog.title = TranslationManager.tr("Create a new Troop Spawn Data")


func _on_troop_spawn_data_created(data: TroopSpawnData) -> void:
	current_region.troop_list.append(data)
	fill_troop_list(current_region.troop_list.size())
	%ApplyButton.set_disabled(false)


func _on_troop_spawn_data_updated(updated_data: TroopSpawnData) -> void:
	for i: int in current_region.troop_list.size():
		var data: TroopSpawnData = current_region.troop_list[i]
		if data.troop_id == updated_data.troop_id:
			fill_troop_list(i)
			%ApplyButton.set_disabled(false)
			break


func _on_troop_list_delete_pressed(indexes: PackedInt32Array) -> void:
	var to_erase := []
	
	for index: int in indexes:
		if current_region.troop_list.size() > index:
			to_erase.append(current_region.troop_list[index])
	
	for data: TroopSpawnData in to_erase:
		current_region.troop_list.erase(data)
	
	fill_troop_list(indexes[0])
	%ApplyButton.set_disabled(false)


func _on_steps_value_changed(value: float) -> void:
	if current_region:
		%ApplyButton.set_disabled(false)
		current_region.steps = value
