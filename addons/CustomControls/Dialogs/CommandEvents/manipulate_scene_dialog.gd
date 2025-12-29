@tool
extends CommandBaseDialog


const MANIPULATE_SCENE_PARAM = preload("res://addons/CustomControls/manipulate_scene_param.tscn")


func _ready() -> void:
	super()
	parameter_code = 124
	%FuncName.grab_focus()


func set_data() -> void:
	var image_id = parameters[0].parameters.get("index", 1)
	var func_name = parameters[0].parameters.get("func_name", "")
	var params = parameters[0].parameters.get("params", [])
	var wait = parameters[0].parameters.get("wait", false)

	%SceneID.value = image_id
	%FuncName.text = func_name
	%Wait.set_pressed(wait)
	
	for param: Dictionary in params:
		_create_param(param.name, param.type, param.value)


func build_command_list() -> Array[RPGEventCommand]:
	propagate_call("apply")
	var commands: Array[RPGEventCommand] = super()
	commands[-1].parameters.index = int(%SceneID.value)
	commands[-1].parameters.func_name = %FuncName.text
	commands[-1].parameters.wait = %Wait.is_pressed()
	var params = []
	for child in %ParamsContainer.get_children():
		if not child.is_queued_for_deletion():
			params.append(child.get_data())
	commands[-1].parameters.params = params

	return commands


func _create_param(param_title: String, param_type: int, current_value: Variant = null) -> void:
	var param = MANIPULATE_SCENE_PARAM.instantiate()
	%ParamsContainer.add_child(param)
	
	param.set_data(param_title, param_type, current_value)
	param.remove_param_requested.connect(func(_param_index): param.queue_free())


func _on_create_param_pressed() -> void:
	var param_title = %ParamName.text
	var param_type = %ParameterType.get_selected_id()
	if param_title.is_empty():
		param_title = "Param #%s" % (%ParamsContainer.get_child_count() + 1)
	
	_create_param(param_title, param_type)
