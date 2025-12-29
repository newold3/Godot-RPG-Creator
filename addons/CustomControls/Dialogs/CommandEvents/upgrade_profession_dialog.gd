@tool
extends CommandBaseDialog


func _ready() -> void:
	super()
	parameter_code = 301
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
	var profession_id = data.get("profession_id", 1)
	if profession_id > 0 and professions.size() > profession_id:
		%ProfessionOptions.select(profession_id - 1)
	else:
		%ProfessionOptions.select(0)


func build_command_list() -> Array[RPGEventCommand]:
	var commands = super()
	commands[-1].parameters.profession_id = %ProfessionOptions.get_selected_id() + 1
	return commands
