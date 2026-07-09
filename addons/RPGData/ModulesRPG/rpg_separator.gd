@tool
class_name RPGSeparator
extends Resource


@export var name: String = ""
@export var background_color: Color = Color(1.0, 0.565, 0.0, 1.0)
@export var text_color: Color = Color(1.0, 1.0, 1.0, 1.0)


func _to_string() -> String:
	return "<RPGSeparator name=%s, text_color=%s, background_color=%s>" % [name, text_color, background_color]
