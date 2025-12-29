@tool
extends CommandBaseDialog

var current_scene_path: String = ""

var using_filter: String


func _ready() -> void:
	super()
	parameter_code = 81


func set_data() -> void:
	current_scene_path = parameters[0].parameters.get("path", "")
	var scene_id = parameters[0].parameters.get("index", 1)
	var wait = parameters[0].parameters.get("wait", false)
	var is_map_scene = parameters[0].parameters.get("is_map_scene", false)
	
	%SceneID.value = scene_id
	%Scene.text = current_scene_path.get_file() if current_scene_path else "Select Scene"
	%Wait.set_pressed(wait)
	%IsMapScene.set_pressed(is_map_scene)


func build_command_list() -> Array[RPGEventCommand]:
	var commands: Array[RPGEventCommand] = super()
	
	commands[-1].parameters.index = %SceneID.value
	commands[-1].parameters.path = current_scene_path
	commands[-1].parameters.wait = %Wait.is_pressed()
	commands[-1].parameters.is_map_scene = %IsMapScene.is_pressed()
	
	return commands


func _on_scene_pressed() -> void:
	var path = "res://addons/CustomControls/Dialogs/select_file_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	await get_tree().process_frame
	
	dialog.destroy_on_hide = true
	dialog.set_dialog_mode(0)
	dialog.target_callable = _on_scene_selected
	
	if using_filter:
		dialog.fill_files(using_filter)
	else:
		var file_path = "res://" if current_scene_path.is_empty() else current_scene_path
		dialog.fill_files_by_extension(file_path, ["tscn"])


func _on_scene_selected(path: String) -> void:
	current_scene_path = path
	%Scene.text = path.get_file()
