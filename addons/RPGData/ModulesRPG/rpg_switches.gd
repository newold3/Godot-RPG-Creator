@tool
class_name Switches
extends Resource


func get_class(): return "Switches"


@export var data: Array[SwitchValue] = []


func set_item_name(item_id: int, name: String) -> void:
	if item_id < data.size():
		data[item_id].name = name


func get_item_name(item_id: int) -> String:
	if item_id < data.size() and item_id >= 0 and data[item_id]:
		return data[item_id].name
	else:
		return ""


func get_value(item_id: int) -> bool:
	if item_id < data.size() and item_id >= 0 and data[item_id]:
		return data[item_id].value
	else:
		return false


func get_values() -> PackedByteArray:
	var values: PackedByteArray = []
	for switch in data:
		if !switch: continue
		values.append(switch.value)
	
	return values


func set_value(item_id: int, value: bool) -> void:
	if item_id < data.size() and item_id >= 0 and data[item_id]:
		data[item_id].value = value


func resize(n: int) -> void:
	data.resize(n+1)
	for i in range(1, data.size()):
		if !data[i]:
			data[i] = SwitchValue.new()


func size() -> int:
	return data.size() - 1


func clone(value: bool = true) -> Switches:
	var new_switches = Switches.new()
	
	for switch in data:
		if switch:
			new_switches.data.append(switch.clone(value))
		else:
			new_switches.data.append(null)
	
	return new_switches
