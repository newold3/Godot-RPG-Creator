@tool
extends CommandBaseDialog

var current_audio_path: String = ""
var busy: bool = false

func _ready() -> void:
	super()

func enable_random_pitch(value: bool = true) -> void:
	%RandomPitch.visible = value

func set_data() -> void:
	current_audio_path = parameters[0].parameters.get("path", "")
	var volume = parameters[0].parameters.get("volume", 0.0)
	var pitch = parameters[0].parameters.get("pitch", 1.0)

	busy = true
	var filename = "Select Sound File" if !current_audio_path else current_audio_path.get_file()
	%Filename.text = filename
	%Pitch.value = pitch
	%Volume.value = volume

	if %RandomPitch.visible:
		var pitch2 = parameters[0].parameters.get("pitch2", 1.0)
		%Pitch2.value = pitch2

	var vehicle_id = max(0, min(parameters[0].parameters.get("vehicle_id", 0), %VehicleOptions.get_item_count() - 1))
	%VehicleOptions.select(vehicle_id)

	busy = false

func _on_filename_pressed() -> void:
	var path = "res://addons/CustomControls/Dialogs/select_file_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	await get_tree().process_frame
	dialog.destroy_on_hide = true
	dialog.auto_play_sounds = true
	dialog.target_callable = update_sound
	dialog.set_file_selected(current_audio_path)
	dialog.set_dialog_mode(0)
	dialog.fill_files("sounds")

func update_sound(path: String) -> void:
	current_audio_path = path
	%Filename.text = current_audio_path.get_file()

func build_command_list() -> Array[RPGEventCommand]:
	var commands = super()
	commands[-1].parameters.path = current_audio_path
	commands[-1].parameters.volume = %Volume.value
	commands[-1].parameters.pitch = %Pitch.value
	commands[-1].parameters.vehicle_id = %VehicleOptions.get_selected_id()
	if %RandomPitch.visible:
		commands[-1].parameters.pitch2 = %Pitch2.value
	return commands

func _on_play_button_pressed() -> void:
	if ResourceLoader.exists(current_audio_path):
		propagate_call("apply")
		var node: AudioStreamPlayer = $AudioStreamPlayer
		node.stop()
		node.stream = load(current_audio_path)
		var current_pitch: float
		if !%RandomPitch.visible:
			current_pitch = round(%Pitch.value * 100) / 100.0
		else:
			var current_value = randf_range(%Pitch.value, %Pitch2.value)
			current_pitch = round(current_value * 100) / 100.0
		node.pitch_scale = current_pitch
		node.volume_db = round(%Volume.value * 100) / 100.0
		node.play()

func _on_pitch_value_changed(value: float) -> void:
	%Pitch2.value = max(%Pitch.value, %Pitch2.value)

func _on_pitch_2_value_changed(value: float) -> void:
	%Pitch.value = min(%Pitch.value, %Pitch2.value)
