@tool
class_name RPGLPCPalette
extends  Resource


func get_class(): return "RPGLPCPalette"


@export var blend_color: int = 0
@export var lightness: float = 0.0
@export var colors: PackedInt64Array = []


func _to_string() -> String:
	return "<palette: blend_color: %s, lightness: %s, colors: %s>" % [blend_color, lightness, colors]


func clone(value: bool = true) -> RPGLPCPalette:
	var obj: RPGLPCPalette = duplicate(value)
	
	return obj
