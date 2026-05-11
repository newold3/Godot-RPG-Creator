@tool
extends CommandBaseDialog

#region Lifecycle & Setup
## Initializes the Profession Action dialog
func _ready() -> void:
	super()
	parameter_code = 301
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
	
	var uid_profession = data.get("profession_id", 1)
	var classic_id = RPGSYSTEM.uid_to_id("professions", uid_profession) if uid_profession > 0 else 1
	
	if classic_id > 0 and professions.size() > classic_id:
		%ProfessionOptions.select(classic_id - 1)
	else:
		%ProfessionOptions.select(0)



## Compiles the UI state back extracting UIDs
func build_command_list() -> Array[RPGEventCommand]:
	var commands = super()
	var idx = %ProfessionOptions.get_selected_id()
	commands[-1].parameters.profession_id = %ProfessionOptions.get_item_metadata(idx)
	return commands
#endregion
