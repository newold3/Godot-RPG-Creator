@tool
class_name RPGRelationshipLevel
extends Resource

## Returns the class name of the resource.
## @return String - The class name.
func get_class():
	return "RPGRelationshipLevel"

## Name of this relationship
@export var name: String = ""
## Experience needed to complete this level.
@export var experience: int = 1

## Clones the RPGRelationshipLevel.
func clone(value: bool = true) -> RPGRelationshipLevel:
	return duplicate(value)

## Returns a string representation of the trait.
## @return String - The string representation.
func _to_string() -> String:
	return "<RPGRelationshipLevel name=%s experience=%s>" % [name, experience]
