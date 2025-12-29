@tool
extends CommandBaseDialog

var current_scene_path: String = ""
var dialog_type: int # 0 = vehicles, 1 = actors
var using_filter: String


func _ready() -> void:
	super()


func enable_vehicle() -> void:
	%VehicleContainer.visible = true
	%ActorContainer.visible = false
	dialog_type = 0
	using_filter = "vehicles"


func enable_actor() -> void:
	fill_actors()
	%VehicleContainer.visible = false
	%ActorContainer.visible = true
	dialog_type = 1
	using_filter = "characters"


func fill_actors() -> void:
	var node: OptionButton = %ActorsOptions
	node.clear()
	
	var actors = RPGSYSTEM.database.actors
	for i in range(1, actors.size(), 1):
		node.add_item("%s: %s" % [i, actors[i].name])


func set_data() -> void:
	current_scene_path = parameters[0].parameters.get("path", "")
	%Scene.text = current_scene_path.get_file() if current_scene_path else tr("Select Scene")
	
	if dialog_type == 0:
		var index = parameters[0].parameters.get("index", 0)
		if %VehicleOptions.get_item_count() > index and index >= 0:
			%VehicleOptions.select(index)
		else:
			%VehicleOptions.select(0)
	else:
		var index = parameters[0].parameters.get("index", 1)
		var real_index = index - 1
		if %ActorsOptions.get_item_count() > real_index and real_index >= 0:
			%ActorsOptions.select(real_index)
		else:
			%ActorsOptions.select(0)


func build_command_list() -> Array[RPGEventCommand]:
	var commands = super()
	commands[-1].parameters.index = %VehicleOptions.get_selected_id() if dialog_type == 0 else (%ActorsOptions.get_selected_id() + 1)
	commands[-1].parameters.path = current_scene_path
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
		dialog.fill_files_by_extension("res://", ["tscn"])


func _on_scene_selected(path: String) -> void:
	current_scene_path = path
	%Scene.text = path.get_file()


func _on_scene_middle_click_pressed() -> void:
	current_scene_path = ""
	%Scene.text = tr("Select Scene")
