@tool
class_name MapGeneratorEvent
extends Resource

const PLACEMENT = RPGEnums.MapPlacement
const EVENT_POSITION = RPGEnums.MapEventPosition

@export var event: RPGEvent
@export var locked: bool = false
@export var probability: float = 10
@export var max_quantity: int = 0
@export var placement: PLACEMENT = PLACEMENT.ANYWHERE
@export var event_position: EVENT_POSITION = EVENT_POSITION.ANYWHERE
@export var ignore_environment: bool = false
@export var width: int = 1
@export var height: int = 1
@export var footprint_height: int = 0
@export var wall_margins: Vector4 = Vector4.ZERO




func _to_string() -> String:
	return "<MapGeneratorEvent event=%s>" % event
