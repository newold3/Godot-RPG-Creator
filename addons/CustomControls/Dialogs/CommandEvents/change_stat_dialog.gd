@tool
extends CommandBaseDialog



func _ready() -> void:
	super()
	parameter_code = 303
	fill_stats()



## Populates the OptionButton with numeric statistics dynamically
func fill_stats() -> void:
	var node = %UserStatOptions
	node.clear()
	
	var dummy_stats = GameStatistics.new()
	
	node.add_separator("Base Stats")
	
	_extract_numeric_properties(dummy_stats, "", node)
	
	node.add_separator("User Stats")
	
	for i: int in RPGSYSTEM.database.types.user_stats.size():
		var stat: String = RPGSYSTEM.database.types.user_stats[i]
		
		node.add_item(stat.capitalize())
		
		var idx = node.get_item_count() - 1
		
		node.set_item_metadata(idx, "user_stats:" + stat)
		
	node.select(1)
	_update_option_button_text(1)



## Recursively extracts int and float properties from an object to build paths
func _extract_numeric_properties(target: Object, path_prefix: String, node: OptionButton) -> void:
	var properties = target.get_property_list()
	
	for prop in properties:
		var p_name = prop["name"]
		var p_type = prop["type"]
		var p_usage = prop["usage"]
		
		if (p_usage & PROPERTY_USAGE_SCRIPT_VARIABLE) == 0:
			continue
			
		if p_type == TYPE_INT or p_type == TYPE_FLOAT:
			node.add_item(p_name.capitalize())
			
			var idx = node.get_item_count() - 1
			var full_path = p_name if path_prefix.is_empty() else path_prefix + "." + p_name
			
			node.set_item_metadata(idx, full_path)
			
		elif p_type == TYPE_OBJECT:
			var sub_resource = target.get(p_name)
			
			if sub_resource and sub_resource is Resource:
				node.add_separator(p_name.capitalize())
				
				var new_prefix = p_name if path_prefix.is_empty() else path_prefix + "." + p_name
				
				_extract_numeric_properties(sub_resource, new_prefix, node)



## Loads the saved data into the UI using the string path instead of an integer ID
func set_data() -> void:
	var data = parameters[0].parameters
	var stat_path = data.get("stat_path", "")
	var value = data.get("value", 0)
	var target_idx = 1
	
	for i in range(%UserStatOptions.get_item_count()):
		if %UserStatOptions.get_item_metadata(i) == stat_path:
			target_idx = i
			break
			
	%UserStatOptions.select(target_idx)
	%Value.value = value
	
	_update_option_button_text(target_idx)



## Builds the final command replacing stat_id with the dynamic string path
func build_command_list() -> Array[RPGEventCommand]:
	var commands = super()
	
	commands[-1].parameters["stat_path"] = %UserStatOptions.get_selected_metadata()
	commands[-1].parameters.value = %Value.value
	
	return commands



## Focuses the value input when a new stat is selected and updates the button text
func _on_user_stat_options_item_selected(index: int) -> void:
	_update_option_button_text(index)
	
	%Value.get_line_edit().grab_focus()



## Updates the OptionButton text to show the full path context
func _update_option_button_text(index: int) -> void:
	var node = %UserStatOptions
	var metadata = node.get_item_metadata(index)
	
	if typeof(metadata) == TYPE_STRING:
		var display_text = ""
		
		if metadata.begins_with("user_stats:"):
			display_text = "User - " + metadata.trim_prefix("user_stats:").capitalize()
		else:
			var parts = metadata.split(".")
			var capitalized_parts = PackedStringArray()
			
			for part in parts:
				capitalized_parts.append(part.capitalize())
				
			display_text = " - ".join(capitalized_parts)
			
		node.text = display_text
