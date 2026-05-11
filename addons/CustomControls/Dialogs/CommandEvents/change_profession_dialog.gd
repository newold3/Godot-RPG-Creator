@tool
extends CommandBaseDialog

#region Lifecycle & Setup
## Initializes the Profession configuration dialog
func _ready() -> void:
	super()
	parameter_code = 300
	fill_professions()



## Populates Profession dropdown injecting UID metadata
func fill_professions() -> void:
	var node = %ProfessionOptions
	var professions = RPGSYSTEM.database.professions
	node.clear()
	
	for i: int in range(1, professions.size(), 1):
		var profession: RPGProfession = professions[i]
		var item_name = "%s: %s" % [i, profession.name]
		node.add_item(item_name)
		node.set_item_metadata(node.get_item_count() - 1, RPGSYSTEM.id_to_uid("professions", i))
		
	node.select(0)



## Parses the raw command securely
func set_data() -> void:
	var professions = RPGSYSTEM.database.professions
	
	var data = parameters[0].parameters
	var action = data.get("type", 1)
	%ActionOptions.select(1 if action == 1 else 0)
	
	var uid_profession = data.get("profession_id", 1)
	var classic_id = RPGSYSTEM.uid_to_id("professions", uid_profession) if uid_profession > 0 else 1
	
	if classic_id > 0 and professions.size() > classic_id:
		%ProfessionOptions.select(classic_id - 1)
		var profession = professions[classic_id]
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



## Compiles the UI state back extracting UIDs
func build_command_list() -> Array[RPGEventCommand]:
	var commands = super()
	var idx = %ProfessionOptions.get_selected_id()
	commands[-1].parameters.profession_id = %ProfessionOptions.get_item_metadata(idx)
	commands[-1].parameters.type = %ActionOptions.get_selected_id()
	commands[-1].parameters.preserve_level = %PreserveLevel.is_pressed()
	commands[-1].parameters.reset_level = %ResetProfession.is_pressed()
	commands[-1].parameters.level = %Level.value
	commands[-1].parameters.action_type = 0 if %PreserveLevel.is_pressed() else 1
	return commands
#endregion



#region UI Interaction
## Adjusts visible layout based on Action Mode
func _on_action_options_item_selected(index: int) -> void:
	%AddExtraContainer.set_visible(index == 1)
	%RemoveExtraContainer.set_visible(index == 0)
	size.y = 0



## Enables level picker
func _on_change_level_toggled(toggled_on: bool) -> void:
	if toggled_on:
		%Level.set_disabled(false)



## Disables level picker
func _on_preserve_level_toggled(toggled_on: bool) -> void:
	if toggled_on:
		%Level.set_disabled(true)



## Re-evaluates max level cap if profession changes
func _on_profession_options_item_selected(index: int) -> void:
	var uid_profession = %ProfessionOptions.get_item_metadata(index)
	var classic_id = RPGSYSTEM.uid_to_id("professions", uid_profession)
	var professions = RPGSYSTEM.database.professions
	
	if classic_id > 0 and professions.size() > classic_id:
		var profession = professions[classic_id]
		%Level.min_value = 1
		%Level.max_value = profession.levels.size()
		%MaxLevels.text = " / " + str(profession.levels.size())
#endregion
