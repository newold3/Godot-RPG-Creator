@tool
extends Window


var command: RPGMovementCommand

var start_fx = {}
var end_fx = {}

static var default_fxs = {
	"start_fx": {},
	"end_fx": {}
}


func _ready() -> void:
	close_requested.connect(queue_free)
	%X.get_line_edit().grab_focus()


func set_command(_command: RPGMovementCommand, updated: bool) -> void:
	command = _command
	if updated:
		%X.value = command.parameters[0].x
		%Y.value = command.parameters[0].y
		if command.parameters.size() >= 2:
			start_fx = command.parameters[1]
		else:
			start_fx = default_fxs.start_fx.duplicate()
		if command.parameters.size() >= 3:
			end_fx = command.parameters[2]
		else:
			end_fx = default_fxs.end_fx.duplicate()
	else:
		start_fx = default_fxs.start_fx.duplicate()
		end_fx = default_fxs.end_fx.duplicate()
	
	if start_fx:
		var sound_name = "%s, vol %s, pitch %s" % [start_fx.path.get_file(), start_fx.volume, start_fx.pitch]
		%StartFx.text = sound_name
	else:
		%StartFx.text = tr("Select an fx")
	
	if end_fx:
		var sound_name = "%s, vol %s, pitch %s" % [end_fx.path.get_file(), end_fx.volume, end_fx.pitch]
		%EndFx.text = sound_name
	else:
		%EndFx.text = tr("Select an fx")
	
	if default_fxs.start_fx == start_fx and default_fxs.end_fx == end_fx and start_fx and end_fx:
		%MakeDefaultJumpFxs.set_pressed_no_signal(true)


func _on_ok_button_pressed() -> void:
	propagate_call("apply")
	if %X.value != 0 or %Y.value != 0:
		command.parameters.clear()
		command.parameters.append(Vector2i(%X.value, %Y.value))
		command.parameters.append(start_fx)
		command.parameters.append(end_fx)
	queue_free()


func _on_cancel_button_pressed() -> void:
	queue_free()


func _show_select_audio_dialog(old_value: Dictionary, id: int) -> void:
	var path = "res://addons/CustomControls/Dialogs/select_sound_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	dialog.enable_random_pitch(false)
	
	var volume = old_value.get("volume", 0.0)
	var pitch = old_value.get("pitch", 1.0)
	var file_selected = old_value.get("path", "")
	
	var commands: Array[RPGEventCommand]
	var command = RPGEventCommand.new(0, 0, {"path": file_selected, "volume": volume, "pitch": pitch})
	commands.append(command)
	dialog.enable_random_pitch()
	dialog.set_parameters(commands)
	dialog.set_data()
	
	dialog.command_changed.connect(
		func(commands: Array[RPGEventCommand]):
			var new_value = commands[0].parameters
			_on_sound_selected(new_value, old_value, id)
	)


func _on_sound_selected(new_value: Dictionary, old_value: Dictionary, id: int):
	if new_value:
		old_value.volume = new_value.volume
		old_value.pitch = new_value.pitch
		old_value.path = new_value.path
	else:
		old_value.clear()
	
	if old_value:
		var sound_name = "%s, vol %s, pitch %s" % [old_value.path.get_file(), old_value.volume, old_value.pitch]
		if id == 0:
			%StartFx.text = sound_name
		else:
			%EndFx.text = sound_name
	else:
		if id == 0:
			%StartFx.text = "Select an fx"
		else:
			%EndFx.text = "Select an fx"
	
	if default_fxs.start_fx == start_fx and default_fxs.end_fx == end_fx and start_fx and end_fx:
		%MakeDefaultJumpFxs.set_pressed_no_signal(true)
	else:
		%MakeDefaultJumpFxs.set_pressed_no_signal(false)


func _on_start_fx_pressed() -> void:
	_show_select_audio_dialog(start_fx, 0)


func _on_end_fx_pressed() -> void:
	_show_select_audio_dialog(end_fx, 1)


func _on_play_button_pressed(id: int) -> void:
	var node: AudioStreamPlayer = %AudioStreamPlayer
	node.stop()
	var data = start_fx if id == 0 else end_fx
	if ResourceLoader.exists(data.path):
		var res = load(data.path)
		node.stream = res
		node.pitch_scale = data.pitch
		node.volume_db = data.volume
		node.play()


func _on_make_default_jump_fxs_toggled(toggled_on: bool) -> void:
	if toggled_on:
		default_fxs.start_fx = start_fx.duplicate()
		default_fxs.end_fx = end_fx.duplicate()
	else:
		default_fxs.start_fx = {}
		default_fxs.end_fx = {}


func _on_start_fx_middle_click_pressed() -> void:
	_on_sound_selected({}, start_fx, 0)


func _on_end_fx_middle_click_pressed() -> void:
	_on_sound_selected({}, end_fx, 1)
