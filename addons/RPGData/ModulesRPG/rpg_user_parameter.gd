@tool
class_name RPGUserParameter
extends  Resource


@export var name: String = ""
@export var abbreviation_name: String = ""
@export var default_value: int = 0


func get_abbr() -> String:
	if not abbreviation_name.is_empty():
		return abbreviation_name
	
	return name


func clone(value: bool) -> RPGUserParameter:
	return duplicate(value)


func _to_string() -> String:
	return "<UserParameter name=%s, abbr=%s, default_value=%s>" % [name, abbreviation_name, default_value]
