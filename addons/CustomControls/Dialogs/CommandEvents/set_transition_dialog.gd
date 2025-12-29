@tool
extends CommandBaseDialog


var current_data: Dictionary

var transition_path_selected: String = ""
var scene_path_selected: String


func _ready() -> void:
	super()
	parameter_code = 52


func set_data() -> void:
	var data: Dictionary = parameters[0].parameters
	current_data = data.duplicate()
	%TransitionType.select(max(0, min(%TransitionType.get_item_count(), data.get("type", 0))))
	%Duration.value = data.get("duration", 0.4)
	transition_path_selected = data.get("transition_image", "")
	if transition_path_selected:
		%SelectTransition.text = transition_path_selected.get_file()
	else:
		%SelectTransition.text = "Select an image to perfom transition"
	%SelectColor.set_color(data.get("transition_color", Color.BLACK))
	
	scene_path_selected = data.get("scene_image", "")
	if scene_path_selected:
		%SelectScene.text = scene_path_selected.get_file()
	else:
		%SelectScene.text = "Select a scene to perfom transition"
	
	var invert = data.get("invert", true)
	%InvertFadeOut.set_pressed(invert)
	
	current_data.type = %TransitionType.get_selected_id()
	current_data.duration = %Duration.value
	current_data.transition_image = transition_path_selected
	current_data.transition_color = %SelectColor.get_color()
	current_data.invert = invert
	
	%TransitionManager.set_config(current_data)

	
	%TransitionType.item_selected.emit(current_data.type)


func build_command_list() -> Array[RPGEventCommand]:
	var commands: Array[RPGEventCommand] = super()
	
	var type = current_data.get("type", 0)
	if type != 2:
		current_data.erase("transition_color")
	if type != 3:
		current_data.erase("transition_image")
		current_data.erase("invert")

	commands[-1].parameters = current_data
	
	return commands


func _on_transition_type_item_selected(index: int) -> void:
	%TransitionColorContainer.visible = (index > 1)
	%TransitionImageContainer.visible = (index == 3)
	%TransitionDurationContainer.visible = (index > 0)
	current_data.type = index
	size.y = 0
	%TransitionManager.set_config(current_data)
	%SceneContainer.visible = index == 4
	
	if current_data.type == 4:
		update_transition_scene(scene_path_selected)
	elif current_data.type == 3:
		_on_image_selected(transition_path_selected)


func _on_duration_value_changed(value: float) -> void:
	current_data.duration = value
	%TransitionManager.set_config(current_data)


func _on_select_transition_pressed() -> void:
	var path = "res://addons/CustomControls/Dialogs/select_file_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	await get_tree().process_frame
	
	dialog.destroy_on_hide = true
	dialog.set_dialog_mode(0)
	dialog.target_callable = _on_image_selected
	dialog.set_file_selected(current_data.get("transition_image", ""))
	
	dialog.fill_files("images")


func _on_image_selected(path: String) -> void:
	if path:
		%SelectTransition.text = path.get_file()
	else:
		%SelectTransition.text = "Select an image to perfom transition"
	current_data.transition_image = path
	%TransitionManager.set_config(current_data)


func _on_select_color_pressed() -> void:
	var path = "res://addons/CustomControls/Dialogs/select_color.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	
	dialog.title = TranslationManager.tr("Select Transition Color")
	dialog.color_selected.connect(_on_transition_color_selected)
	dialog.set_color(current_data.get("transition_color", Color.BLACK))


func _on_transition_color_selected(color: Color) -> void:
	%SelectColor.set_color(color)
	current_data.transition_color = color
	%TransitionManager.set_config(current_data)


func _on_select_transition_middle_click_pressed() -> void:
	transition_path_selected = ""
	current_data.transition_image = ""
	%SelectTransition.text = "Select an image to perfom transition"
	%TransitionManager.set_config(current_data)


func _on_select_scene_middle_click_pressed() -> void:
	scene_path_selected = ""
	current_data.scene_image = ""
	%SelectScene.text = "Select a scene to perfom transition"
	%TransitionManager.set_config(current_data)


func _on_select_scene_pressed() -> void:
	var path = "res://addons/CustomControls/Dialogs/select_file_dialog.tscn"
	var parent = get_tree().get_nodes_in_group("main_database")[0]
	var dialog
	var main_panel = parent.get_child(0)
	if main_panel.cache_dialog.has(path) and is_instance_valid(main_panel.cache_dialog[path]):
		dialog = main_panel.cache_dialog[path]
		RPGDialogFunctions.show_dialog(dialog, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	else:
		dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
		main_panel.cache_dialog[path] = dialog
	await get_tree().process_frame
	
	dialog.set_dialog_mode(0)
	
	dialog.target_callable = update_transition_scene
	dialog.set_file_selected(scene_path_selected)
	
	dialog.fill_files("transition_scenes")


func update_transition_scene(path: String) -> void:
	if ResourceLoader.exists(path):
		current_data.scene_image = path
	else:
		current_data.scene_image = ""
	%TransitionManager.transition_scene = current_data.scene_image
	
	scene_path_selected = current_data.scene_image
	
	if scene_path_selected:
		%SelectScene.text = scene_path_selected.get_file()
	else:
		%SelectScene.text = "Select a scene to perfom transition"


func _on_invert_fade_out_toggled(toggled_on: bool) -> void:
	current_data.invert = toggled_on
	%TransitionManager.invert_fade_out = toggled_on
