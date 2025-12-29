@tool
extends Window


var busy: bool = false
var current_path: String
var current_volume: float
var current_pitch: float


signal value_changed(path: String, volume: float, pitch: float)


func _ready() -> void:
	close_requested.connect(queue_free)


func set_data(path: String, volume: float = 0.0, pitch: float = 1.0) -> void:
	busy = true
	current_path = path
	current_volume = volume
	current_pitch = pitch
	var filename = "Select Sound File" if !path else path
	%Filename.text = filename
	%Pitch.value = pitch
	%Volume.value = volume
	busy = false


func _on_filename_pressed() -> void:
	var path = "res://addons/CustomControls/Dialogs/select_file_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	
	await get_tree().process_frame
	
	dialog.destroy_on_hide = true
	dialog.auto_play_sounds = true
	dialog.target_callable = update_sound
	dialog.set_file_selected(current_path)
	dialog.set_dialog_mode(0)
	
	dialog.fill_files("sounds")


func update_sound(path: String) -> void:
	current_path = path
	var filename = "Select Sound File" if !current_path else current_path
	%Filename.text = filename


func _on_ok_button_pressed() -> void:
	propagate_call("apply")
	value_changed.emit(current_path, current_volume, current_pitch)
	queue_free()


func _on_cancel_button_pressed() -> void:
	queue_free()


func _on_play_button_pressed() -> void:
	if ResourceLoader.exists(current_path):
		propagate_call("apply")
		var node: AudioStreamPlayer = $AudioStreamPlayer
		node.stop()
		node.stream = load(current_path)
		node.pitch_scale = round(current_pitch * 100) / 100.0
		node.volume_db = round(current_volume * 100) / 100.0
		node.play()


func _on_pitch_value_changed(value: float) -> void:
	current_pitch = round(value * 100) / 100.0
	$AudioStreamPlayer.pitch_scale = current_pitch


func _on_volume_value_changed(value: float) -> void:
	current_volume = round(value * 100) / 100.0
	$AudioStreamPlayer.volume_db = current_volume


func _on_filename_middle_click_pressed() -> void:
	current_path = ""
	var filename = "Select Sound File"
	%Filename.text = filename
