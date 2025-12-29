@tool
class_name RPGRelationship
extends Resource

## Returns the class name of the resource.
## @return String - The class name.
func get_class():
	return "RPGRelationship"

## levels of this relationship
@export var levels: Array[RPGRelationshipLevel] = []

func _init() -> void:
	levels.append(RPGRelationshipLevel.new())

## Clones the RPGRelationship.
func clone(value: bool = true) -> RPGRelationship:
	var new_relationship = duplicate(value)
	for i: int in levels.size():
		new_relationship.levels[i] = new_relationship.levels[i].clone(value)
		
	return new_relationship

## Returns a string representation of the trait.
## @return String - The string representation.
func _to_string() -> String:
	return "<RPGRelationship levels=%s" % levels
