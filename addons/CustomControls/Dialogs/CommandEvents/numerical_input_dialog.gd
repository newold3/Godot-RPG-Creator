@tool
extends CommandBaseDialog


var current_variable_id = 1
var current_text_variable_id = 1

var current_config: Dictionary = {}
var current_number_scene_path: String = ""
var current_text_scene_path: String = ""
var current_max_digits: int = 1
var current_max_letters: int = 8

var current_cursor_move_fx: Dictionary = {}
var current_selection_fx: Dictionary = {}
var current_remove_fx: Dictionary = {}


func _ready() -> void:
	super()
	parameter_code = 8
	populate_nodes()


func set_data() -> void:
	var type = parameters[0].parameters.get("type", 0)
	%Type.select(type)
	var variable_id = parameters[0].parameters.get("variable_id", current_variable_id)
	var digits = parameters[0].parameters.get("digits", current_max_digits if type == 0 else current_max_letters)
	if type == 0:
		current_max_digits = digits
		%Digits.max_value = 9
	else:
		current_max_letters = digits
		%Digits.max_value = 64
	current_config = parameters[0].parameters.get("text_format", {})
	populate_nodes(variable_id, digits)


func populate_nodes(variable_id: int = 1, digits: int = 1) -> void:
	%Title.text = current_config.get("title", "")
	%EmptyPlace.text = current_config.get("empty_place", "·")
	if %Type.get_selected_id() == 0:
		current_variable_id = variable_id
		if %Title.text.length() == 0:
			%Title.text = tr("Enter Number")
	else:
		current_text_variable_id = variable_id
		if %Title.text.length() == 0:
			%Title.text = tr("Enter Text")
	_set_variable_name()
	%Digits.value = digits
	
	var config = {} if parameters.size() == 0 else parameters[0].parameters

	
	if !"scene_path" in config:
		if %Type.get_selected_id() == 0:
			current_number_scene_path = "res://Scenes/DialogTemplates/select_digits_scene.tscn"
		else:
			current_text_scene_path = "res://Scenes/DialogTemplates/select_text_scene.tscn"
	else:
		if %Type.get_selected_id() == 0:
			current_number_scene_path = config.get("scene_path", "")
		else:
			current_text_scene_path = config.get("scene_path", "")
	if !"move_fx" in config:
		current_cursor_move_fx = {"path": "res://Assets/Sounds/SE/button_hover_se.wav", "volume": 0, "pitch": 1}
	else:
		current_cursor_move_fx = config.get("move_fx", {})
	if !"select_fx" in config:
		current_selection_fx = {"path": "res://Assets/Sounds/SE/button_click_se.wav", "volume": 0, "pitch": 1}
	else:
		current_selection_fx = config.get("select_fx", {})
	if !"remove_fx" in config:
		current_remove_fx = {"path": "res://Assets/Sounds/SE/cancel1.ogg", "volume": 0, "pitch": 1}
	else:
		current_remove_fx = config.get("remove_fx", {})
	
	var box_offset = config.get("offset", Vector2.ZERO)
	%OffsetX.value = box_offset.x
	%OffsetY.value = box_offset.y
	
	%UseMessageBounds.set_pressed(config.get("use_message_bounds", true))
	
	%Position.select(max(0, min(%Position.get_item_count(), config.get("position", 5))))
	
	if %Type.get_selected_id() == 0:
		%ScenePath.text = current_number_scene_path.get_file()
	else:
		%ScenePath.text = current_text_scene_path.get_file()


func build_command_list() -> Array[RPGEventCommand]:
	var commands: Array[RPGEventCommand] = super()

	commands[-1].parameters.tittle = %Title.text
	commands[-1].parameters.empty_place = %EmptyPlace.text
	if %Type.get_selected_id() == 0:
		commands[-1].parameters.scene_path = current_number_scene_path
	else:
		commands[-1].parameters.scene_path = current_text_scene_path
	commands[-1].parameters.type = %Type.get_selected_id()
	commands[-1].parameters.variable_id = current_variable_id if commands[-1].parameters.type == 0 else current_text_variable_id
	commands[-1].parameters.digits = %Digits.value
	commands[-1].parameters.position = %Position.get_selected_id()
	commands[-1].parameters.use_message_bounds = %UseMessageBounds.is_pressed()
	commands[-1].parameters.offset = Vector2(%OffsetX.value, %OffsetY.value)
	commands[-1].parameters.text_format = current_config
	commands[-1].parameters.move_fx = current_cursor_move_fx
	commands[-1].parameters.select_fx = current_selection_fx
	commands[-1].parameters.remove_fx = current_remove_fx
	
	return commands


func _on_variable_id_pressed() -> void:
	var path = "res://addons/CustomControls/Dialogs/switch_variable_dialog.tscn"
	var callable = _on_variable_changed
	var type = %Type.get_selected_id()
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	dialog.data_type = 0 if type == 0 else 2
	dialog.target = %VariableID
	dialog.selected.connect(callable)
	dialog.variable_or_switch_name_changed.connect(_set_variable_name)
	dialog.setup(current_variable_id if type == 0 else current_text_variable_id)


func _on_variable_changed(index: int, target: Node) -> void:
	if %Type.get_selected_id() == 0:
		current_variable_id = index
	else:
		current_text_variable_id = index
	_set_variable_name()


func _set_variable_name() -> void:
	var type = %Type.get_selected_id()
	var variables = RPGSYSTEM.system.variables if type == 0 else RPGSYSTEM.system.text_variables
	var index = current_variable_id if type == 0 else current_text_variable_id
	var variable_name = "%s:%s" % [
		str(index).pad_zeros(4),
		variables.get_item_name(index)
	]
	%VariableID.text = variable_name


func _on_type_item_selected(index: int) -> void:
	_set_variable_name()
	if %Type.get_selected_id() == 0:
		if current_number_scene_path.is_empty():
			current_number_scene_path = "res://Scenes/DialogTemplates/select_digits_scene.tscn"
		%ScenePath.text = current_number_scene_path.get_file()
		%Digits.max_value = 9
		%Digits.value = current_max_digits
	else:
		if current_text_scene_path.is_empty():
			current_text_scene_path = "res://Scenes/DialogTemplates/select_text_scene.tscn"
		%ScenePath.text = current_text_scene_path.get_file()
		%Digits.max_value = 64
		%Digits.value = current_max_letters


func _on_text_format_pressed() -> void:
	var path = "res://addons/CustomControls/Dialogs/config_options_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	
	dialog.set_data(current_config)
	
	dialog.config_changed.connect(func(config: Dictionary) : current_config = config)


func _on_scene_path_pressed() -> void:
	var path = "res://addons/CustomControls/Dialogs/select_file_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	await get_tree().process_frame
	
	dialog.destroy_on_hide = true
	
	dialog.set_dialog_mode(0)
	
	dialog.target_callable = func(path: String):
		if %Type.get_selected_id() == 0:
			current_number_scene_path = path
			%ScenePath.text = current_number_scene_path.get_file()
		else:
			current_text_scene_path = path
			%ScenePath.text = current_text_scene_path.get_file()
		
	
	if %Type.get_selected_id() == 0:
		dialog.set_file_selected(current_number_scene_path)
		dialog.fill_files("numerical_input_scenes")
	else:
		dialog.set_file_selected(current_text_scene_path)
		dialog.fill_files("text_input_scenes")


func select_sound(target: Node, id: String) -> void:
	var path = "res://addons/CustomControls/Dialogs/select_sound_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	
	var parameters :Array[RPGEventCommand] = []
	var param = RPGEventCommand.new(0, 0, get(id))
	parameters.append(param)
	dialog.set_parameters(parameters)
	dialog.set_data()

	dialog.command_changed.connect(
		func(commands: Array[RPGEventCommand]):
			var c = commands[0].parameters
			set(id, {"path": c.get("path", ""), "volume": c.get("volume", ""), "pitch": c.get("pitch", "")})
			target.text = get(id).get("path", "").get_file()
	)


func _on_cursor_move_fx_middle_click_pressed() -> void:
	%CursorMoveFx.text = tr("Select FX")
	current_cursor_move_fx = {}


func _on_cursor_move_fx_pressed() -> void:
	select_sound(%CursorMoveFx, "current_cursor_move_fx")


func _on_selection_fx_middle_click_pressed() -> void:
	%SelectionFx.text = tr("Select FX")
	current_selection_fx = {}


func _on_selection_fx_pressed() -> void:
	select_sound(%SelectionFx, "current_selection_fx")


func _on_removel_fx_middle_click_pressed() -> void:
	%RemovelFx.text = tr("Select FX")
	current_remove_fx = {}


func _on_removel_fx_pressed() -> void:
	select_sound(%RemovelFx, "current_remove_fx")
