@tool
extends CommandBaseDialog


func _ready() -> void:
	super()
	parameter_code = 300
	fill_professions()


func fill_professions() -> void:
	var node = %ProfessionOptions
	var professions = RPGSYSTEM.database.professions
	node.clear()
	for i: int in range(1, professions.size(), 1):
		var profession: RPGProfession = professions[i]
		var item_name = "%s: %s" % [i, profession.name]
		node.add_item(item_name)
	node.select(0)


func set_data() -> void:
	var professions = RPGSYSTEM.database.professions
	
	var data = parameters[0].parameters
	var action = data.get("type", 1)
	%ActionOptions.select(1 if action == 1 else 0)
	var profession_id = data.get("profession_id", 1)
	if profession_id > 0 and professions.size() > profession_id:
		%ProfessionOptions.select(profession_id - 1)
		var profession = professions[profession_id]
		%Level.min_value = 1
		%Level.max_value = profession.levels.size()
		%MaxLevels.text = " / " + str(profession.levels.size())
	else:
		%ProfessionOptions.select(0)
	
	if action == 0:
		%ResetProfession.set_pressed(data.get("reset_level", 0))
	else:
		var action_type = data.get("action_type", 0)
		if action_type == 0:
			%PreserveLevel.set_pressed(true)
		else:
			%ChangeLevel.set_pressed(true)
			%Level.value = data.get("level", 1)
	
	%AddExtraContainer.set_visible(action == 1)
	%RemoveExtraContainer.set_visible(action == 0)
	size.y = 0


func build_command_list() -> Array[RPGEventCommand]:
	var commands = super()
	commands[-1].parameters.profession_id = %ProfessionOptions.get_selected_id() + 1
	commands[-1].parameters.type = %ActionOptions.get_selected_id()
	commands[-1].parameters.preserve_level = %PreserveLevel.is_pressed()
	commands[-1].parameters.reset_level = %ResetProfession.is_pressed()
	commands[-1].parameters.level = %Level.value
	commands[-1].parameters.action_type = 0 if %PreserveLevel.is_pressed() else 1
	return commands


func _on_action_options_item_selected(index: int) -> void:
	%AddExtraContainer.set_visible(index == 1)
	%RemoveExtraContainer.set_visible(index == 0)
	
	size.y = 0


func _on_change_level_toggled(toggled_on: bool) -> void:
	if toggled_on:
		%Level.set_disabled(false)


func _on_preserve_level_toggled(toggled_on: bool) -> void:
	if toggled_on:
		%Level.set_disabled(true)


func _on_profession_options_item_selected(index: int) -> void:
	var profession_id = index + 1
	var professions = RPGSYSTEM.database.professions
	if profession_id > 0 and professions.size() > profession_id:
		var profession = professions[profession_id]
		%Level.min_value = 1
		%Level.max_value = profession.levels.size()
		%MaxLevels.text = " / " + str(profession.levels.size())
