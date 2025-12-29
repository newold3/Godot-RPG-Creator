class_name RPGDimension
extends  Resource


func get_class(): return "RPGDimension"

## indicates how many extra tiles you have on the left
@export var grow_left: int

## indicates how many extra tiles you have on the right
@export var grow_right: int

## indicates how many extra tiles you have on the up
@export var grow_up: int

## indicates how many extra tiles you have on the down
@export var grow_down: int


func _to_string() -> String:
	return "<RPGDimension grow_left=%s grow_right=%s grow_up=%s grow_down=%s>" % [
		grow_left,
		grow_right,
		grow_up,
		grow_down
	]
