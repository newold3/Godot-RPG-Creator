@tool
class_name EditExtractionEventEditor
extends Window

var resource_previewer: EditorResourcePreview
var original_event: RPGExtractionItem
var current_event: RPGExtractionItem
var events: Array[RPGExtractionItem]

var undo_redo: EditorUndoRedoManager
var current_object: Object
var plugin: RPGMapPlugin

var busy: bool


signal changed()


func _ready() -> void:
	close_requested.connect(confirm_changes)


func setup() -> void:
	if current_event:
		_fill_professions()
		%EventName.text = current_event.name
		var scene = current_event.scene_path.get_file() if not current_event.scene_path.is_empty() else tr("Select Scene")
		%ItemScenePath.text = scene
		%MaxUses.value = current_event.max_uses
		%RespawnTime.value = current_event.respawn_time
		%ExperienceBase.value = current_event.experience_base
		%NoLevelRestrictions.set_pressed(current_event.no_level_restrictions)
		var fx = current_event.extraction_fx.filename.get_file() if not current_event.extraction_fx.filename.is_empty() else tr("Select Sound")
		%ExtractionFx.text = fx
		_fill_reward_list()


func _fill_professions() -> void:
	var list = %ProfessionList
	list.clear()
	
	var data = RPGSYSTEM.database.professions
	
	if current_event:
		for profession in data:
			if not profession: continue
			list.add_item(str(profession.id) + ": " + profession.name)
	
	var selected_profession = current_event.required_profession
	var real_profession_id = -1
	if selected_profession > 0 and list.get_item_count() > selected_profession:
		real_profession_id = selected_profession - 1
		list.select(selected_profession - 1)
	elif list.get_item_count() > 0:
		real_profession_id = 0
		list.select(0)
		current_event.required_profession = 1
	if real_profession_id > -1:
		list.select(real_profession_id)
		_update_min_and_max_levels()


func _fill_reward_list(selected_index: int = -1) -> void:
	var node = %DropList
	node.clear()
	
	var reward_list = current_event.drop_table
	var database = RPGSYSTEM.database
	for reward: RPGItemDrop in reward_list:
		var current_data
		var prefix
		if reward.item.data_id == 0: # items
			current_data = database.items
			prefix = "Item"
		elif reward.item.data_id == 1: # weapons
			current_data = database.weapons
			prefix = "Weapon"
		elif reward.item.data_id == 2: # armors
			current_data = database.armors
			prefix = "Armor"
		
		if current_data:
			var quantity: String
			var percent = str(reward.percent) + "%"
			if current_data.size() > reward.item.item_id:
				var item_name = str(reward.item.item_id).pad_zeros(str(current_data.size()).length())
				item_name += ": " + current_data[reward.item.item_id].name
				if reward.quantity != reward.quantity2:
					quantity = str(reward.quantity) + " ~ " + str(reward.quantity2)
				else:
					quantity = str(reward.quantity)
				node.add_column([prefix, item_name, quantity, percent])
			else:
				if reward.quantity != reward.quantity2:
					quantity = str(reward.quantity) + " ~ " + str(reward.quantity2)
				else:
					quantity = str(reward.quantity)
				node.add_column([prefix, "⚠ Invalid Data", quantity, percent])
	
	if selected_index >= 0:
		await node.columns_setted
		node.select(selected_index)


func _update_min_and_max_levels() -> void:
	busy = true
	var list = %ProfessionList
	if list.get_item_count() > 0:
		var selected_profession = list.get_selected_id() + 1
		var data = RPGSYSTEM.database.professions
		var profession = data[selected_profession]
		current_event.max_required_profession_level = max(1, min(current_event.max_required_profession_level, profession.levels.size() + 1))
		current_event.min_required_profession_level = max(1, min(current_event.min_required_profession_level, current_event.max_required_profession_level))
		%MaxRequiredLevel.min_value = 1
		%MaxRequiredLevel.max_value = profession.levels.size()
		%MinRequiredLevel.min_value = 1
		%MinRequiredLevel.max_value = %MaxRequiredLevel.max_value
		%MinRequiredLevel.value = current_event.min_required_profession_level
		%MaxRequiredLevel.value = current_event.max_required_profession_level
		%ProfessionMaxRanks.text = str(profession.levels.size())
		var max_levels: int = 0
		for i in profession.levels.size():
			max_levels += profession.levels[i].max_levels
		%ProfessionMaxLevels.text = str(max_levels)
		%CurrentItemLevel.min_value = 1
		%CurrentItemLevel.max_value = max_levels
		%CurrentItemLevel.value = current_event.current_level
	busy = false


func set_event(event: RPGExtractionItem) -> void:
	original_event = event
	var new_event: RPGExtractionItem = event.clone(true)
	current_event = new_event


func set_events(_events: Array[RPGExtractionItem]) -> void:
	events = _events


func _fix_current_level() -> void:
	var profession = current_event.get_profession()
	if profession:
		var min_level: int = profession.levels[current_event.min_required_profession_level].max_levels
		var max_level: int = 0
		for i in range(current_event.min_required_profession_level - 1, current_event.max_required_profession_level):
			max_level += profession.levels[i].max_levels
		
		current_event.current_level = max(min_level, min(current_event.current_level, max_level))


func _on_ok_button_pressed() -> void:
	_create_undo_redo_action()
	changed.emit()
	queue_free()

func _create_undo_redo_action() -> void:
	propagate_call("apply")
	
	if not current_event.no_level_restrictions:
		_fix_current_level()
	
	if not current_event or not events or not original_event or not undo_redo or not current_object:
		push_error("Faltan datos para crear la acción de undo/redo")
		return
	
	# Crear copias de los eventos
	var modified_event = current_event.clone(true)
	var original_copy = original_event.clone(true)
	
	# Encontrar el índice del evento original
	var event_index: int = -1
	for i in events.size():
		if events[i].id == original_copy.id:
			event_index = i
			break
	
	if event_index == -1:
		push_error("No se encontró el evento en la lista")
		return
	
	undo_redo.create_action("Edit Extraction Event", UndoRedo.MERGE_DISABLE, current_object)
	
	# DO - reemplazar con el evento modificado
	undo_redo.add_do_method(plugin, "_force_mode_switch", plugin.current_edit_mode)
	undo_redo.add_do_method(current_object, "_update_extraction_event", event_index, modified_event)
	undo_redo.add_do_method(EditorInterface, "mark_scene_as_unsaved")
	
	# UNDO - restaurar el evento original
	undo_redo.add_undo_method(plugin, "_force_mode_switch", plugin.current_edit_mode)
	undo_redo.add_undo_method(current_object, "_update_extraction_event", event_index, original_copy)
	undo_redo.add_undo_method(EditorInterface, "mark_scene_as_unsaved")
	
	undo_redo.commit_action()


func _on_cancel_button_pressed() -> void:
	confirm_changes()


func confirm_changes() -> void:
	if current_event and not current_event.is_equal_to(original_event):
		var path = "res://addons/CustomControls/Dialogs/confirm_dialog.tscn"
		var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
		dialog.set_text("Discard the changes and exit?")
		dialog.title = TranslationManager.tr("Override File")
		dialog.OK.connect(queue_free)
	else:
		queue_free()


func _on_apply_button_pressed() -> void:
	if current_event and events:
		var event = current_event.clone(true)
		for i in events.size():
			if events[i].id == event.id:
				events[i] = event
				break
	
	%ApplyButton.set_disabled(true)


func _on_event_name_text_changed(new_text: String) -> void:
	current_event.name = new_text
	%ApplyButton.set_disabled(false)


func _open_file_dialog() -> Window:
	var path = "res://addons/CustomControls/Dialogs/select_file_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	await get_tree().process_frame
	
	dialog.set_dialog_mode(0)
	
	return dialog


func _on_item_scene_path_pressed() -> void:
	var dialog = await _open_file_dialog()

	dialog.target_callable = _update_item_scene
	dialog.set_file_selected(current_event.scene_path)
	
	dialog.fill_files("extraction_scenes")


func _update_item_scene(path: String) -> void:
	current_event.scene_path = path
	%ItemScenePath.text = current_event.scene_path.get_file()


func _on_profession_list_item_selected(index: int) -> void:
	current_event.required_profession = index + 1
	_update_min_and_max_levels()


func _on_min_required_level_value_changed(value: float) -> void:
	if busy: return
	busy = true
	
	current_event.max_required_profession_level = max(current_event.max_required_profession_level,value)
	%MaxRequiredLevel.value = current_event.max_required_profession_level
	
	current_event.min_required_profession_level = value
	
	busy = false


func _on_max_required_level_value_changed(value: float) -> void:
	if busy: return
	busy = true
	
	current_event.min_required_profession_level = min(current_event.min_required_profession_level, value)
	%MinRequiredLevel.value = current_event.min_required_profession_level
	
	current_event.max_required_profession_level = value
	
	busy = false


func _on_current_item_level_value_changed(value: float) -> void:
	if busy: return
	busy = true
	
	current_event.current_level = value
	
	busy = false


func _on_max_uses_value_changed(value: float) -> void:
	current_event.max_uses = value


func _on_respawn_time_value_changed(value: float) -> void:
	current_event.respawn_time = value


func _on_extraction_fx_pressed() -> void:
	var path = "res://addons/CustomControls/Dialogs/select_sound_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	
	var volume = current_event.extraction_fx.volume_db
	var pitch = current_event.extraction_fx.pitch_scale
	var file_selected = current_event.extraction_fx.filename
	
	var commands: Array[RPGEventCommand]
	var command = RPGEventCommand.new(0, 0, {"path": file_selected, "volume": volume, "pitch": pitch})
	commands.append(command)
	dialog.enable_random_pitch()
	dialog.set_parameters(commands)
	dialog.set_data()
	
	dialog.command_changed.connect(
		func(commands: Array[RPGEventCommand]):
			var c = commands[0].parameters
			_on_sound_selected(c.path, c.volume, c.pitch)
	)


func _on_sound_selected(current_path: String, current_volume: float, current_pitch: float):
	current_event.extraction_fx.filename = current_path
	current_event.extraction_fx.volume_db = current_volume
	current_event.extraction_fx.pitch_scale = current_pitch
	var fx = current_event.extraction_fx.filename.get_file() if not current_event.extraction_fx.filename.is_empty() else tr("Select Sound")
	%ExtractionFx.text = fx


func _show_reward_dialog(item: RPGItemDrop = null, index: int = -1) -> void:
	var path = "res://addons/CustomControls/Dialogs/select_item_drop_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	dialog.database = RPGSYSTEM.database
	if item:
		dialog.set_data(item)
		dialog.item_updated.connect(_on_reward_updated.bind(index))
	else:
		dialog.create_new_data()
		dialog.item_created.connect(_on_reward_created)


func _on_reward_created(new_item: RPGItemDrop) -> void:
	var reward_found: bool = false
	var reward_index: int = -1
	var list = current_event.drop_table
	for i in list.size():
		var reward: RPGItemDrop = list[i]
		if new_item.item.data_id == reward.item.data_id and new_item.item.item_id == reward.item.item_id:
			reward.quantity = new_item.quantity
			reward.quantity2 = new_item.quantity2
			reward.percent = new_item.percent
			reward_found = true
			reward_index = i
			break

	if !reward_found:
		list.append(new_item)
		_fill_reward_list(list.size() - 1)
	else:
		_fill_reward_list(reward_index)


func _on_reward_updated(_reward: RPGItemDrop, index: int) -> void:
	var duplicate_found: bool = false
	var list = current_event.drop_table
	for i in list.size():
		var reward1: RPGItemDrop = list[i]
		for j in range(list.size() - 1, i, -1):
			var reward2: RPGItemDrop = list[j]
			if reward1.item.data_id == reward2.item.data_id and reward1.item.item_id == reward2.item.item_id:
				reward1.quantity = reward2.quantity
				reward1.quantity2 = reward2.quantity2
				reward1.percent = reward2.percent
				list.erase(reward2)
				index = i
				duplicate_found = true
				break
		if duplicate_found: break

	_fill_reward_list(index)


func _on_drop_list_copy_requested(indexes: PackedInt32Array) -> void:
	var copy_rewards: Array[RPGItemDrop]
	var list = current_event.drop_table
	for index in indexes:
		if index > list.size() or index < 0:
			continue
		copy_rewards.append(list[index].clone(true))
		
	StaticEditorVars.CLIPBOARD["extraction_item_drops"] = copy_rewards


func _on_drop_list_cut_requested(indexes: PackedInt32Array) -> void:
	var copy_rewards: Array[RPGItemDrop]
	var remove_rewards: Array[RPGItemDrop]
	var list = current_event.drop_table
	for index in indexes:
		if index > list.size():
			continue
		if list.size() > index and index >= 0:
			copy_rewards.append(list[index].clone(true))
			remove_rewards.append(list[index])
	for item in remove_rewards:
		list.erase(item)

	StaticEditorVars.CLIPBOARD["extraction_item_drops"] = copy_rewards
	
	var item_selected = max(-1, indexes[0])
	_fill_reward_list(item_selected)


func _on_drop_list_delete_pressed(indexes: PackedInt32Array) -> void:
	var remove_rewards: Array[RPGItemDrop] = []
	var list = current_event.drop_table
	for index in indexes:
		if index >= 0 and list.size() > index:
			remove_rewards.append(list[index])
	for obj in remove_rewards:
		list.erase(obj)
	_fill_reward_list(indexes[0])


func _on_drop_list_item_activated(index: int) -> void:
	var list = current_event.drop_table
	if list.size() > 0 and list.size() > index: # update item
		_show_reward_dialog(list[index], index)
	else: # new item
		_show_reward_dialog()


func _on_drop_list_paste_requested(index: int) -> void:
	var reward_list = current_event.drop_table
	
	if "extraction_item_drops" in StaticEditorVars.CLIPBOARD:
		for i in StaticEditorVars.CLIPBOARD["extraction_item_drops"].size():
			var reward1: RPGItemDrop = StaticEditorVars.CLIPBOARD["extraction_item_drops"][i].clone()
			var material_setted: bool = false
			for j in reward_list.size():
				var reward2: RPGItemDrop = reward_list[j]
				if reward1.item.data_id == reward2.item.data_id and reward1.item.item_id == reward2.item.item_id:
					reward2.quantity = reward1.quantity
					reward2.percent = reward1.percent
					material_setted = true
					break
					
			if material_setted: continue
			
			var real_index = index + i
			if real_index < reward_list.size():
				reward_list.insert(real_index, reward1)
			else:
				reward_list.append(reward1)
	else:
		return
	
	_fill_reward_list(min(index, reward_list.size() - 1))
	
	var list = %DropList
	await list.columns_setted
	await get_tree().process_frame
	await get_tree().process_frame
	list.deselect_all()
	if "extraction_item_drops" in StaticEditorVars.CLIPBOARD:
		for i in StaticEditorVars.CLIPBOARD["extraction_item_drops"].size():
			for j in reward_list.size():
				var reward1: RPGItemDrop = StaticEditorVars.CLIPBOARD["extraction_item_drops"][i]
				var reward2: RPGItemDrop = reward_list[j]
				if reward1.item.data_id == reward2.item.data_id and reward1.item.item_id == reward2.item.item_id:
					list.select(j, false)
					break


func _on_experience_base_value_changed(value: float) -> void:
	current_event.experience_base = value


func _on_no_level_restrictions_toggled(toggled_on: bool) -> void:
	current_event.no_level_restrictions = toggled_on
	%RequiredLevel.propagate_call("set_disabled", [toggled_on])


func _on_save_as_preset_button_pressed() -> void:
	var path = "res://addons/CustomControls/Dialogs/select_text_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	dialog.title = TranslationManager.tr("Set Preset Name")
	dialog.text_selected.connect(_save_preset, CONNECT_DEFERRED)


# Saves the current event as a preset with the given name
func _save_preset(preset_name: String) -> void:
	await get_tree().process_frame
	
	# Get the Documents folder path and create presets folder if it doesn't exist
	var documents_path = OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS)
	var presets_folder = documents_path.path_join("GodotRPGCreatorPresets/ExtractionEventPresets/")
	if not DirAccess.dir_exists_absolute(presets_folder):
		DirAccess.make_dir_recursive_absolute(presets_folder)
	
	# Create and configure the preset resource
	var preset = ExtractionEventPreset.new()
	preset.name = preset_name
	preset.preset = current_event
	
	# Generate the file name from the preset name
	var event_file = preset_name.to_snake_case().to_lower().trim_prefix("_")
	var preset_file_path: String = presets_folder + event_file + ".res"
	
	# Check if preset already exists and ask for confirmation
	if FileAccess.file_exists(preset_file_path):
		var path = "res://addons/CustomControls/Dialogs/confirm_dialog.tscn"
		var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
		dialog.set_text(tr("There is already a preset with that name. Do you want to overwrite it?"))
		dialog.title = TranslationManager.tr("Override File")
		await dialog.tree_exiting
		if dialog.result == false: return
	
	# Save the preset file
	FileAccess.open(preset_file_path, FileAccess.WRITE).store_var(preset, true)
