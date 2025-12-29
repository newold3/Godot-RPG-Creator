@tool
extends CommandBaseDialog


func _ready() -> void:
	super()
	parameter_code = 303
	fill_stats()


func fill_stats() -> void:
	var node = %UserStatOptions
	node.clear()
	
	var base_stats = [
		"", "chests_opened", "secrets_found", "rare_items_found"
	]
	
	node.add_separator("Base Stats")
	for i in range(1, base_stats.size(), 1):
		node.add_item(base_stats[i])
	
	node.add_separator("User Stats")
	for i: int in RPGSYSTEM.database.types.user_stats.size():
		var stat: String = RPGSYSTEM.database.types.user_stats[i]
		node.add_item(stat)
		
	node.select(0)


func set_data() -> void:
	var data = parameters[0].parameters
	var stat_id = data.get("stat_id", 0)
	%UserStatOptions.select(stat_id if stat_id < %UserStatOptions.get_item_count() and stat_id > -1 else 0)
	var value = data.get("value", 0)
	%Value.value = value


func build_command_list() -> Array[RPGEventCommand]:
	var commands = super()
	commands[-1].parameters.stat_id = %UserStatOptions.get_selected_id()
	commands[-1].parameters.value = %Value.value
	return commands


func _on_user_stat_options_item_selected(index: int) -> void:
	%Value.get_line_edit().grab_focus()
