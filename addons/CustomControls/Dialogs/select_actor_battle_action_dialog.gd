@tool
extends Window


var data: RPGActorBattleAction = RPGActorBattleAction.new()
var target_id: int = -1
var busy: bool


signal battle_action_updated(data, target_id)


func _ready() -> void:
	close_requested.connect(queue_free)


func set_data(_data: RPGActorBattleAction) -> void:
	busy = true
	data = _data
	var v = clamp(data.occasion, 0, %Occasion.get_item_count() - 1)
	%Occasion.select(v)
	%Occasion.item_selected.emit(v)
	v = clamp(data.type, 0, %Type.get_item_count() - 1)
	%Type.select(v)
	%Type.item_selected.emit(v)
	_on_sound_selected(data.fx.filename, data.fx.volume_db, data.fx.pitch_scale)
	_on_common_event_selected(data.common_event_id)
	_on_skill_selected(data.skill_id)
	v = clamp(data.condition, 0, %Condition.get_item_count() - 1)
	%Condition.select(v)
	%Condition.item_selected.emit(v)
	%ConditionRate.value = data.condition_rate
	%ConditionRate2.value = data.condition_rate
	busy = false


func _on_ok_button_pressed() -> void:
	propagate_call("apply")
	battle_action_updated.emit(data, target_id)
	queue_free()


func _on_cancel_button_pressed() -> void:
	queue_free()


func _on_occasion_item_selected(index: int) -> void:
	data.occasion = index
	%SkillIDContainer.visible = [6, 7].has(index)
	%ConditionContainer.visible = [2, 3, 4, 6, 7].has(index)
	%Condition2Container.visible = [0, 1, 5, 8, 9, 10, 11, 12, 13, 14, 15, 16].has(index)
	size.y = min_size.y


func _on_type_item_selected(index: int) -> void:
	data.type = index
	%FXContainer.visible = index == 0
	%EventIDContainer.visible = index == 1
	size.y = min_size.y


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


func _on_sound_selected(current_path: String, current_volume: float, current_pitch: float):
	data.fx.volume_db = current_volume
	data.fx.pitch_scale = current_pitch
	data.fx.filename = current_path
	var sound_name = "%s, vol %s, pitch %s" % [current_path.get_file(), current_volume, current_pitch]
	%SelectFx.text = sound_name


func _on_common_event_pressed() -> void:
	var path = "res://addons/CustomControls/Dialogs/select_any_data_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	dialog.database = RPGSYSTEM.database
	
	dialog.destroy_on_hide = true
	dialog.selected.connect(_on_common_event_selected)
	
	dialog.setup(RPGSYSTEM.database.common_events, data.common_event_id, "Select Common Event", null)


func _on_common_event_selected(id: int, _target = null) -> void:
	data.common_event_id = id
	if id >= 1:
		var n = RPGSYSTEM.database.common_events[id].name
		if !n:
			n = "Common Event %s" % id
		else:
			n = str(id) + ": " + n
		%CommonEvent.text = n


func _on_skill_id_pressed() -> void:
	var path = "res://addons/CustomControls/Dialogs/select_any_data_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	dialog.database = RPGSYSTEM.database
	
	dialog.destroy_on_hide = true
	dialog.selected.connect(_on_skill_selected)
	
	dialog.setup(RPGSYSTEM.database.skills, data.skill_id, "Select Skill", null)


func _on_skill_selected(id: int, _target = null) -> void:
	data.skill_id = id
	if id >= 1:
		var n = RPGSYSTEM.database.skills[id].name
		if !n:
			n = "Skill %s" % id
		else:
			n = str(id) + ": " + n
		%SkillID.text = n


func _on_condition_item_selected(index: int) -> void:
	data.condition = index


func _on_condition_rate_value_changed(value: float) -> void:
	if busy: return
	data.condition_rate = value
	busy = true
	%ConditionRate2.value = value
	busy = false


func _on_condition2_rate_value_changed(value: float) -> void:
	if busy: return
	data.condition_rate = value
	busy = true
	%ConditionRate.value = value
	busy = false


func _on_play_button_pressed() -> void:
	var node: AudioStreamPlayer = %AudioStreamPlayer
	node.stop()
	if ResourceLoader.exists(data.fx.filename):
		var res = load(data.fx.filename)
		node.stream = res
		node.pitch_scale = data.fx.pitch_scale
		node.volume_db = data.fx.volume_db
		node.play()
