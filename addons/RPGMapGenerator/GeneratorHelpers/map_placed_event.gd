@tool
class_name MapPlacedEvent
extends Resource


#region VARIABLES
## The UID of the original MapGeneratorEvent template in the library
@export var template_uid: int

## The grid coordinates where this event is placed
@export var tile: Vector2i
#endregion


func _to_string() -> String:
	return "<MapPlacedEvent template_uid=%s tile=%s>" % [template_uid, tile]
