@tool
extends CommandBaseDialog


var current_ballon_scene_path: String
var current_event: RPGEvent


func _ready() -> void:
	super()
	parameter_code = 73


func set_targets(events: Array, append_player: bool = true) -> void:
	var node = %TargetOptions
	node.clear()
	
	if append_player:
		node.add_item("Player")
	
	if current_event:
		node.add_item("This Event")
	
	for event: RPGEvent in events:
		if event.name:
			node.add_item(event.name)
		else:
			node.add_item("Event #%s" % event.id)
	
	if node.get_item_count():
		node.select(0)
	
	node.set_disabled(false)


func set_data() -> void:
	current_ballon_scene_path = parameters[0].parameters.get("path", "")
	var target_id = parameters[0].parameters.get("target_id", 0)
	var wait = parameters[0].parameters.get("wait", false)
	
	%TargetOptions.select(target_id if %TargetOptions.get_item_count() > target_id else 0)
	%Wait.set_pressed(wait)
	%BallonScene.text = current_ballon_scene_path.get_file() if current_ballon_scene_path else "Select ballon scene"


func build_command_list() -> Array[RPGEventCommand]:
	var commands: Array[RPGEventCommand] = super()

	commands[-1].parameters.target_id = %TargetOptions.get_selected_id()
	commands[-1].parameters.path = current_ballon_scene_path
	commands[-1].parameters.wait = %Wait.is_pressed()
	
	return commands


func _on_ballon_scene_pressed() -> void:
	var path = "res://addons/CustomControls/Dialogs/select_file_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	await get_tree().process_frame
	
	dialog.destroy_on_hide = true
	dialog.set_dialog_mode(0)
	dialog.target_callable = _on_ballon_scene_selected
	dialog.set_file_selected(current_ballon_scene_path)
	
	dialog.fill_files("expressive_bubbles")


func _on_ballon_scene_selected(path: String) -> void:
	current_ballon_scene_path = path
	if ResourceLoader.exists(path):
		%BallonScene.text = path.get_file()
	else:
		%BallonScene.text = "Select ballon scene"
