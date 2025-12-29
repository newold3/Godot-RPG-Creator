@tool
extends CommandBaseDialog

var current_scene_path: String = ""


func _ready() -> void:
	super()
	parameter_code = 92


func set_data() -> void:
	current_scene_path = parameters[0].parameters.get("path", "")
	var wait = parameters[0].parameters.get("wait", false)
	var loop = parameters[0].parameters.get("loop", false)
	var fadein_time = parameters[0].parameters.get("fadein", 0.0)
	var fadeout_time = parameters[0].parameters.get("fadeout", 0.0)
	var color = parameters[0].parameters.get("color", Color.WHITE)
	
	%Scene.text = current_scene_path.get_file() if current_scene_path else "Select video scene"
	%Wait.set_pressed(wait)
	%Loop.set_pressed(loop)
	
	%Fadein.value = fadein_time
	%Fadeout.value = fadeout_time
	%VideoModulate.set_color(color)
	
	%Wait.set_disabled(loop)


func build_command_list() -> Array[RPGEventCommand]:
	var commands: Array[RPGEventCommand] = super()

	commands[-1].parameters.path = current_scene_path
	commands[-1].parameters.wait = %Wait.is_pressed() if not %Loop.is_pressed() else false
	commands[-1].parameters.loop = %Loop.is_pressed()
	commands[-1].parameters.fadein = %Fadein.value
	commands[-1].parameters.fadeout = %Fadeout.value
	commands[-1].parameters.color = %VideoModulate.get_color()
	
	return commands


func _on_scene_pressed() -> void:
	var path = "res://addons/CustomControls/Dialogs/select_file_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	await get_tree().process_frame
	
	dialog.destroy_on_hide = true
	dialog.set_dialog_mode(0)
	dialog.target_callable = _on_scene_selected
	dialog.fill_files("videos")


func _on_scene_selected(path: String) -> void:
	current_scene_path = path
	%Scene.text = path.get_file()


func _on_loop_toggled(toggled_on: bool) -> void:
	%Wait.set_disabled(toggled_on)


func _on_video_modulate_pressed() -> void:
	var path = "res://addons/CustomControls/Dialogs/select_color.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	
	dialog.title = TranslationManager.tr("Select Color")
	dialog.color_selected.connect(func(color): %VideoModulate.set_color(color))
	dialog.set_color(%VideoModulate.get_color())
