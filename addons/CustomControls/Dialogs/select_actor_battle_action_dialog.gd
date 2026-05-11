@tool
extends Window

#region Variables & Signals
var data: RPGActorBattleAction = RPGActorBattleAction.new()
var target_id: int = -1
var busy: bool

signal battle_action_updated(data, target_id)
#endregion



#region Lifecycle & Setup
## Initializes the dialog and connects the close request
func _ready() -> void:
	close_requested.connect(queue_free)



## Populates the dialog with the provided data and handles legacy ID conversion
func set_data(_data: RPGActorBattleAction) -> void:
	busy = true
	data = _data
	
	if data.common_event_id > 0 and data.common_event_id < 1000000:
		data.common_event_id = RPGSYSTEM.id_to_uid("common_events", data.common_event_id)
		
	if data.skill_id > 0 and data.skill_id < 1000000:
		data.skill_id = RPGSYSTEM.id_to_uid("skills", data.skill_id)
	
	var v = clamp(data.occasion, 0, %Occasion.get_item_count() - 1)
	%Occasion.select(v)
	%Occasion.item_selected.emit(v)
	
	v = clamp(data.type, 0, %Type.get_item_count() - 1)
	%Type.select(v)
	%Type.item_selected.emit(v)
	
	_on_sound_selected(data.fx.filename, data.fx.volume_db, data.fx.pitch_scale)
	_fill_common_event_text(data.common_event_id)
	_fill_skill_text(data.skill_id)
	
	v = clamp(data.condition, 0, %Condition.get_item_count() - 1)
	%Condition.select(v)
	%Condition.item_selected.emit(v)
	
	%ConditionRate.value = data.condition_rate
	%ConditionRate2.value = data.condition_rate
	busy = false
#endregion



#region UI Event Handlers
## Commits the changes and closes the dialog
func _on_ok_button_pressed() -> void:
	propagate_call("apply")
	battle_action_updated.emit(data, target_id)
	queue_free()



## Cancels the operation and closes the dialog
func _on_cancel_button_pressed() -> void:
	queue_free()



## Handles occasion dropdown changes and toggles visibility of related containers
func _on_occasion_item_selected(index: int) -> void:
	data.occasion = index
	%SkillIDContainer.visible = [6, 7].has(index)
	%ConditionContainer.visible = [2, 3, 4, 6, 7].has(index)
	%Condition2Container.visible = [0, 1, 5, 8, 9, 10, 11, 12, 13, 14, 15, 16].has(index)
	size.y = min_size.y



## Handles action type dropdown changes (Sound vs Event)
func _on_type_item_selected(index: int) -> void:
	data.type = index
	%FXContainer.visible = index == 0
	%EventIDContainer.visible = index == 1
	size.y = min_size.y



## Handles condition type selection
func _on_condition_item_selected(index: int) -> void:
	data.condition = index



## Synchronizes primary condition rate with the secondary one
func _on_condition_rate_value_changed(value: float) -> void:
	if busy: return
	data.condition_rate = value
	busy = true
	%ConditionRate2.value = value
	busy = false



## Synchronizes secondary condition rate with the primary one
func _on_condition2_rate_value_changed(value: float) -> void:
	if busy: return
	data.condition_rate = value
	busy = true
	%ConditionRate.value = value
	busy = false
#endregion



#region Dialog Callbacks & Audio
## Opens the sound selection dialog
func _on_select_fx_pressed() -> void:
	var path = "res://addons/CustomControls/Dialogs/select_sound_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	
	var volume = data.fx.volume_db
	var pitch = data.fx.pitch_scale
	var file_selected = data.fx.filename
	
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



## Updates data when a sound is selected
func _on_sound_selected(current_path: String, current_volume: float, current_pitch: float) -> void:
	data.fx.volume_db = current_volume
	data.fx.pitch_scale = current_pitch
	data.fx.filename = current_path
	var sound_name = "%s, vol %s, pitch %s" % [current_path.get_file(), current_volume, current_pitch]
	%SelectFx.text = sound_name



## Opens the dialog to select a common event passing the classic ID
func _on_common_event_pressed() -> void:
	var path = "res://addons/CustomControls/Dialogs/select_any_data_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	dialog.database = RPGSYSTEM.database
	
	dialog.destroy_on_hide = true
	dialog.selected.connect(_on_common_event_selected)
	
	var classic_id = RPGSYSTEM.uid_to_id("common_events", data.common_event_id) if data.common_event_id > 0 else 1
	classic_id = max(1, min(classic_id, RPGSYSTEM.database.common_events.size() - 1))
	
	dialog.setup(RPGSYSTEM.database.common_events, classic_id, TranslationManager.tr("Select Common Event"), null)



## Receives the classic ID, converts it to UID and sets it
func _on_common_event_selected(id: int, _target = null) -> void:
	data.common_event_id = RPGSYSTEM.id_to_uid("common_events", id)
	_fill_common_event_text(data.common_event_id)



## Updates the common event button text
func _fill_common_event_text(uid: int) -> void:
	if uid > 0:
		var ce_data = RPGSYSTEM.get_data("common_events", uid)
		if ce_data:
			var classic_id = RPGSYSTEM.uid_to_id("common_events", uid)
			var id_padded = str(classic_id).pad_zeros(str(RPGSYSTEM.database.common_events.size()).length())
			var n = ce_data.name if not ce_data.name.is_empty() else "Common Event %s" % classic_id
			%CommonEvent.text = "%s: %s" % [id_padded, n]
		else:
			%CommonEvent.text = "⚠ Invalid Data"
	else:
		%CommonEvent.text = TranslationManager.tr("None")



## Opens the dialog to select a skill passing the classic ID
func _on_skill_id_pressed() -> void:
	var path = "res://addons/CustomControls/Dialogs/select_any_data_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	dialog.database = RPGSYSTEM.database
	
	dialog.destroy_on_hide = true
	dialog.selected.connect(_on_skill_selected)
	
	var classic_id = RPGSYSTEM.uid_to_id("skills", data.skill_id) if data.skill_id > 0 else 1
	classic_id = max(1, min(classic_id, RPGSYSTEM.database.skills.size() - 1))
	
	dialog.setup(RPGSYSTEM.database.skills, classic_id, TranslationManager.tr("Select Skill"), null)



## Receives the classic ID, converts it to UID and sets it
func _on_skill_selected(id: int, _target = null) -> void:
	data.skill_id = RPGSYSTEM.id_to_uid("skills", id)
	_fill_skill_text(data.skill_id)



## Updates the skill button text
func _fill_skill_text(uid: int) -> void:
	if uid > 0:
		var sk_data = RPGSYSTEM.get_data("skills", uid)
		if sk_data:
			var classic_id = RPGSYSTEM.uid_to_id("skills", uid)
			var id_padded = str(classic_id).pad_zeros(str(RPGSYSTEM.database.skills.size()).length())
			var n = sk_data.name if not sk_data.name.is_empty() else "Skill %s" % classic_id
			%SkillID.text = "%s: %s" % [id_padded, n]
		else:
			%SkillID.text = "⚠ Invalid Data"
	else:
		%SkillID.text = TranslationManager.tr("None")



## Previews the selected sound effect
func _on_play_button_pressed() -> void:
	var node: AudioStreamPlayer = %AudioStreamPlayer
	node.stop()
	
	if ResourceLoader.exists(data.fx.filename):
		var res = load(data.fx.filename)
		node.stream = res
		node.pitch_scale = data.fx.pitch_scale
		node.volume_db = data.fx.volume_db
		node.play()
#endregion
