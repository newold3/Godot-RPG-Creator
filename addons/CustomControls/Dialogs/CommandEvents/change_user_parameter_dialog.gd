@tool
extends CommandBaseDialog


func _ready() -> void:
	super()
	parameter_code = 302
	fill_targets()
	fill_params()


func _process(delta: float) -> void:
	if %ParamOptions.get_item_count() > 0:
		var param_id = %ParamOptions.get_selected_id()
		var value = RPGSYSTEM.database.types.user_parameters[param_id].default_value
		%SetDefaultButton.set_disabled(%Value.value == value)


func fill_targets() -> void:
	var node = %Targets
	node.clear()
	
	node.add_item(tr("Global Parameter"))
	
	for actor in RPGSYSTEM.database.actors:
		if not actor: continue
		node.add_item("Actor <%s: %s>" % [actor.id, actor.name])
	
	node.select(0)


func fill_params() -> void:
	var node = %ParamOptions
	node.clear()
	for i: int in RPGSYSTEM.database.types.user_parameters.size():
		var stat: RPGUserParameter = RPGSYSTEM.database.types.user_parameters[i]
		var item_name = "%s: %s" % [i + 1, stat.name]
		node.add_item(item_name)
	if RPGSYSTEM.database.types.user_parameters.size() > 0:
		node.select(0)
		node.set_disabled(false)
		%Value.set_disabled(false)
	else:
		node.set_disabled(true)
		%Value.set_disabled(true)


func set_data() -> void:
	var data = parameters[0].parameters
	var target_id = data.get("target_id", 0)
	var param_id = data.get("param_id", 0)
	if %ParamOptions.get_item_count() > 0:
		%ParamOptions.select(param_id if param_id < %ParamOptions.get_item_count() and param_id > -1 else 0)
		var value = data.get("value", RPGSYSTEM.database.types.user_parameters[param_id].default_value)
		%Value.value = value
	if %Targets.get_item_count() > 0:
		if  %Targets.get_item_count() > target_id:
			%Targets.select(target_id)
		else:
			%Targets.select(0)


func build_command_list() -> Array[RPGEventCommand]:
	var commands = super()
	commands[-1].parameters.param_id = %ParamOptions.get_selected_id()
	commands[-1].parameters.target_id = %Targets.get_selected_id()
	commands[-1].parameters.value = %Value.value
	return commands


func _on_param_options_item_selected(index: int) -> void:
	%Value.get_line_edit().grab_focus()


func _on_set_default_button_pressed() -> void:
	var param_id = %ParamOptions.get_selected_id()
	var value = RPGSYSTEM.database.types.user_parameters[param_id].default_value
	%Value.set_value(value)
	
