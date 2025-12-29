@tool
class_name TextVariables
extends Resource


func get_class(): return "TextVariables"


@export var data: Array[VariableTextValue] = []


func set_item_name(item_id: int, name: String) -> void:
	if item_id < data.size():
		data[item_id].name = name


func get_item_name(item_id: int) -> String:
	if item_id < data.size() and item_id >= 0 and data[item_id]:
		return data[item_id].name
	else:
		return ""


func get_value(item_id: int) -> String:
	if item_id < data.size() and item_id >= 0 and data[item_id]:
		return data[item_id].value
	else:
		return ""


func get_values() -> PackedStringArray:
	var values: PackedStringArray = []
	for variable in data:
		if !variable: continue
		values.append(variable.value)
	
	return values


func set_value(item_id: int, value: String) -> void:
	if item_id < data.size() and item_id >= 0 and data[item_id]:
		data[item_id].value = value


func resize(n: int) -> void:
	data.resize(n+1)
	for i in range(1, data.size()):
		if !data[i]:
			data[i] = VariableTextValue.new()


func size() -> int:
	return data.size() - 1


func clone(value: bool = true) -> TextVariables:
	var new_variables = TextVariables.new()
	
	for variable in data:
		if variable:
			new_variables.data.append(variable.clone(value))
		else:
			new_variables.data.append(null)
	
	return new_variables
