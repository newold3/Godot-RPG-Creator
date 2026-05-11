@tool
class_name MapGeneratorEvents
extends Resource

@export var events: Array[MapGeneratorEvent] = []


func _to_string() -> String:
	return "<MapGeneratorEvents %s>" % get_instance_id()
