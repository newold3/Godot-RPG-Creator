@tool
class_name RPGUserParameter
extends  Resource


@export var name: String = ""
@export var abbreviation_name: String = ""
@export var default_value: int = 0

## Custom data dictionary for future expansion and dynamic properties.
@export var custom_data: Dictionary = {}


func get_abbr() -> String:
	if not abbreviation_name.is_empty():
		return abbreviation_name
	
	return name


func clone(value: bool = true) -> RPGUserParameter:
	var copy = duplicate(value)
	copy.custom_data = custom_data.duplicate(true) if custom_data != null else {}
	return copy


func _to_string() -> String:
	return "<UserParameter name=%s, abbr=%s, default_value=%s>" % [name, abbreviation_name, default_value]
