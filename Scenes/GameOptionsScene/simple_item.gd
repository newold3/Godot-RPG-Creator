@tool
class_name SimpleItem
extends Resource


@export var name: String = ""
@export var value: String = ""


func _init(_name: String = "", _value: String = "") -> void:
	name = _name
	value = _value
