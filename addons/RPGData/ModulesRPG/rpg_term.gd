@tool
class_name RPGTerm
extends  Resource

@export var id: String = ""
@export var text: String = ""
@export var unselectable: bool = false
@export var is_user_message: bool = false



func _init(_id: String = "", _text: String = "", _unselectable: bool = false, is_user_message: bool = false) -> void:
	id = _id
	text = _text
	unselectable = _unselectable
	is_user_message = is_user_message


func clone(value: bool = true) -> RPGTerm:
	return duplicate(value)


func _to_string() -> String:
	return "< RPGTerm %s, %s, %s, %s >" % [id, text, unselectable, is_user_message]
