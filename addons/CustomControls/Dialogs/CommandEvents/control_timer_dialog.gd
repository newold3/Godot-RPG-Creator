@tool
extends CommandBaseDialog


var current_data: Dictionary

var default_timer_scene: String = "res://Scenes/TimerScenes/default_timer_scene.tscn"
var current_timer_scene: String


func _ready() -> void:
	super()
	parameter_code = 20


func set_data() -> void:
	var data: Dictionary = parameters[0].parameters
	current_data = data.duplicate()
	var operation = data.get("operation_type", 0)
	current_data.operation_type = operation
	if operation == 0:
		%Start.set_pressed(false)
		%Start.set_pressed(true)
	elif operation == 1:
		%Stop.set_pressed(false)
		%Stop.set_pressed(true)
	elif operation == 2:
		%Pause.set_pressed(false)
		%Pause.set_pressed(true)
	elif operation == 3:
		%Resume.set_pressed(false)
		%Resume.set_pressed(true)
	elif operation == 4:
		%AddTimer.set_pressed(false)
		%AddTimer.set_pressed(true)
	elif operation == 5:
		%SubtractsTimer.set_pressed(false)
		%SubtractsTimer.set_pressed(true)
	%Minutes.value = data.get("minutes", 0)
	current_data.minutes = %Minutes.value
	%Seconds.value = data.get("seconds", 30)
	%TimerID.value = data.get("timer_id", 0)
	current_data.seconds = %Seconds.value
	%TimerTitle.text = data.get("timer_title", "")
	
	_update_timer_scene(data.get("timer_scene", default_timer_scene))


func build_command_list() -> Array[RPGEventCommand]:
	var commands: Array[RPGEventCommand] = super()
	commands[-1].parameters = current_data
	return commands


func _on_minutes_value_changed(value: float) -> void:
	current_data.minutes = value


func _on_seconds_value_changed(value: float) -> void:
	current_data.seconds = value


func _on_start_toggled(toggled_on: bool) -> void:
	if toggled_on:
		current_data.operation_type = 0
		%Minutes.set_disabled(false)
		%Seconds.set_disabled(false)
		%TimerScene.set_disabled(false)
		%TimerTitle.set_disabled(false)
		%ExtraConfig.set_disabled(false)


func _on_stop_toggled(toggled_on: bool) -> void:
	if toggled_on:
		current_data.operation_type = 1
		%Minutes.set_disabled(true)
		%Seconds.set_disabled(true)
		%TimerScene.set_disabled(true)
		%TimerTitle.set_disabled(true)
		%ExtraConfig.set_disabled(true)


func _on_pause_toggled(toggled_on: bool) -> void:
	if toggled_on:
		current_data.operation_type = 2
		%Minutes.set_disabled(true)
		%Seconds.set_disabled(true)
		%TimerScene.set_disabled(true)
		%TimerTitle.set_disabled(true)
		%ExtraConfig.set_disabled(true)


func _on_resume_toggled(toggled_on: bool) -> void:
	if toggled_on:
		current_data.operation_type = 3
		%Minutes.set_disabled(true)
		%Seconds.set_disabled(true)
		%TimerScene.set_disabled(true)
		%TimerTitle.set_disabled(true)
		%ExtraConfig.set_disabled(true)


func _on_add_toggled(toggled_on: bool) -> void:
	if toggled_on:
		current_data.operation_type = 4
		%Minutes.set_disabled(false)
		%Seconds.set_disabled(false)
		%TimerScene.set_disabled(true)
		%TimerTitle.set_disabled(true)
		%ExtraConfig.set_disabled(true)


func _on_remove_toggled(toggled_on: bool) -> void:
	if toggled_on:
		current_data.operation_type = 5
		%Minutes.set_disabled(false)
		%Seconds.set_disabled(false)
		%TimerScene.set_disabled(true)
		%TimerTitle.set_disabled(true)
		%ExtraConfig.set_disabled(true)


func _on_timer_scene_pressed() -> void:
	var path = "res://addons/CustomControls/Dialogs/select_file_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	
	await get_tree().process_frame
	
	dialog.destroy_on_hide = true
	dialog.target_callable = _update_timer_scene
	dialog.set_file_selected(current_timer_scene)
	dialog.set_dialog_mode(0)
	
	dialog.fill_mix_files(["timer_scenes"])


func _update_timer_scene(path: String) -> void:
	current_timer_scene = path
	current_data.timer_scene = current_timer_scene
	%TimerScene.text = current_timer_scene.get_file()


func _on_timer_id_value_changed(value: float) -> void:
	current_data.timer_id = value


func _on_timer_title_text_changed(new_text: String) -> void:
	current_data.timer_title = new_text


func _on_extra_config_pressed() -> void:
	var path = "res://addons/CustomControls/Dialogs/timer_extra_config_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	
	dialog.config_changed.connect(
		func(config: Dictionary):
			current_data.extra_config = config
	)
	
	var config: Dictionary = current_data.get("extra_config", {})

	dialog.set_config(config)
