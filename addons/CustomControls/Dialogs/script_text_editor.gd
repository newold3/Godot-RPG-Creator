@tool
extends Window

var presets: Array = []
var preset_need_saved: bool = false

signal text_changed(text: String)


func _ready() -> void:
	%SelectColor.destroy_on_hide = false
	focus_entered.connect(
		func():
			if %SelectColor.visible:
				%SelectColor._on_cancel_button_pressed()
	)
	close_requested.connect(queue_free)
	_set_presets()
	%CodeEdit.grab_focus()


func _set_presets(reload_presets: bool = true) -> void:
	if reload_presets:
		var f = FileAccess.open("res://addons/CustomControls/Resources/Other/script_presets.txt", FileAccess.READ)
		presets = JSON.parse_string(f.get_as_text())
		f.close()
	
	var node = %PresetButton
	node.clear()
	
	for preset in presets:
		node.add_item(tr(preset.name))
		node.set_item_metadata(-1, preset.contents)
	
	if presets.size() > 0:
		node.select(0)
		node.item_selected.emit(0)


func set_text(text: String) -> void:
	%CodeEdit.text = text


func _on_ok_button_pressed() -> void:
	text_changed.emit(%CodeEdit.text)
	queue_free()


func _on_cancel_button_pressed() -> void:
	queue_free()


func _apply_script_preset_pressed(index: int) -> void:
	%CodeEdit.text = %PresetButton.get_item_metadata(index)
	%CodeEdit.grab_focus()
	%CodeEdit.select_all()


func _on_apply_script_preset_pressed() -> void:
	var index = %PresetButton.get_selected_id()
	_apply_script_preset_pressed(index)


func _on_remove_script_preset_pressed() -> void:
	var index = %PresetButton.get_selected_id()
	if not presets[index].get("default", false):
		presets.remove_at(index)
		_set_presets(false)
		preset_need_saved = true


func _on_save_script_preset_pressed() -> void:
	var path = "res://addons/CustomControls/Dialogs/select_text_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	dialog.title = "Set Preset name"
	dialog.text_selected.connect(
		func(preset_name: String):
			var preset_exists = presets.filter(func(preset): return(preset.name.to_lower() == preset_name.to_lower()))
			if preset_exists.size() > 0:
				var index = presets.find(preset_exists[0])
				%PresetButton.select(index)
				%PresetButton.item_selected.emit(index)
			else:
				var new_preset = {
					"contents": %CodeEdit.get_text(),
					"name": preset_name,
					"default": false
				  }
				presets.append(new_preset)
				_set_presets(false)
				var index = presets.size() - 1
				%PresetButton.select(index)
				%PresetButton.item_selected.emit(index)
				preset_need_saved = true
	)


func _on_preset_button_item_selected(index: int) -> void:
	if presets[index].get("default", false):
		%RemoveScriptPreset.set_disabled(true)
	else:
		%RemoveScriptPreset.set_disabled(false)
