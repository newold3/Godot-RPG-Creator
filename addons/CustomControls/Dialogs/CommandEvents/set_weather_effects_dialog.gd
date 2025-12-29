@tool
extends CommandBaseDialog


var current_weather_scene: String = ""


func _ready() -> void:
	super()
	parameter_code = 68


func set_data() -> void:
	var type = parameters[0].parameters.get("type", 0)
	if type == 0:
		%AddEffect.set_pressed_no_signal(true)
	else:
		%RemoveEffect.set_pressed_no_signal(true)
	%ID.value = parameters[0].parameters.get("id", 1)
	current_weather_scene = parameters[0].parameters.get("scene", "")
	%WeatherScene.text = current_weather_scene if current_weather_scene else "select wheater scene..."
	
	update_layout()


func update_layout() -> void:
	if %AddEffect.is_pressed():
		%WeatherScenePanel.visible = true
	else:
		%WeatherScenePanel.visible = false
	
	size.y = 0


func build_command_list() -> Array[RPGEventCommand]:
	var commands: Array[RPGEventCommand] = super()

	commands[-1].parameters.type = 0 if %AddEffect.is_pressed() else 1
	commands[-1].parameters.id = %ID.value
	commands[-1].parameters.scene = "" if commands[-1].parameters.type == 1 else current_weather_scene
	
	return commands


func _on_weather_scene_pressed() -> void:
	var path = "res://addons/CustomControls/Dialogs/select_file_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	await get_tree().process_frame
	
	dialog.destroy_on_hide = true
	dialog.set_dialog_mode(0)
	dialog.target_callable = _on_weather_scene_selected
	dialog.set_file_selected(current_weather_scene)
	
	dialog.fill_files("weather")


func _on_weather_scene_selected(path: String) -> void:
	current_weather_scene = path
	%WeatherScene.text = path


func _on_add_effect_toggled(_toggled_on: bool) -> void:
	update_layout()


func _on_remove_effect_toggled(_toggled_on: bool) -> void:
	update_layout()
