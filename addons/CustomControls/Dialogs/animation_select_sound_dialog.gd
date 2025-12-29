@tool
extends Window


var selected_index: int = -1
var sound: RPGAnimationSound
var busy: bool = false


signal value_changed(selected_index: int, sound: RPGAnimationSound)


func _ready() -> void:
	close_requested.connect(queue_free)


func set_data(_selected_index: int, _sound: RPGAnimationSound) -> void:
	busy = true
	selected_index = _selected_index
	sound = _sound.clone(true)
	%Frame.value = sound.frame
	var filename = "Select Sound File" if !sound.filename else sound.filename
	%Filename.text = filename
	%MinPitch.value = sound.pitch_min
	%MaxPitch.value = sound.pitch_max
	%Volume.value = sound.volume_db
	busy = false

	await get_tree().process_frame
	%Frame.get_line_edit().grab_focus()


func _on_filename_pressed() -> void:
	var path = "res://addons/CustomControls/Dialogs/select_file_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	
	await get_tree().process_frame
	
	dialog.destroy_on_hide = true
	dialog.auto_play_sounds = true
	dialog.target_callable = update_sound
	dialog.set_file_selected(sound.filename)
	dialog.set_dialog_mode(0)
	
	dialog.fill_files("sounds")


func update_sound(_path: String) -> void:
	sound.filename = _path
	var filename = "Select Sound File" if !sound.filename else sound.filename
	%Filename.text = filename


func _on_ok_button_pressed() -> void:
	propagate_call("apply")
	value_changed.emit(selected_index, sound)
	queue_free()


func _on_cancel_button_pressed() -> void:
	queue_free()


func _on_frame_value_changed(value: float) -> void:
	sound.frame = value


func _on_play_button_pressed() -> void:
	if ResourceLoader.exists(sound.filename):
		propagate_call("apply")
		var node: AudioStreamPlayer = $AudioStreamPlayer
		node.stop()
		node.stream = load(sound.filename)
		node.pitch_scale = randf_range(sound.pitch_min, sound.pitch_max)
		node.volume_db = sound.volume_db
		node.play()


func _on_min_pitch_value_changed(value: float) -> void:
	if busy or not sound: return
	var new_value = min(value, sound.pitch_max)
	if new_value != value:
		%MinPitch.value = new_value
		return
	sound.pitch_min = value
	$AudioStreamPlayer.pitch_scale = randf_range(sound.pitch_min, sound.pitch_max)


func _on_max_pitch_value_changed(value: float) -> void:
	if busy or not sound: return
	var new_value = max(value, sound.pitch_min)
	if new_value != value:
		%MaxPitch.value = new_value
		return
	sound.pitch_max = value
	$AudioStreamPlayer.pitch_scale = randf_range(sound.pitch_min, sound.pitch_max)


func _on_volume_value_changed(value: float) -> void:
	sound.volume_db = value
	$AudioStreamPlayer.volume_db = sound.volume_db
