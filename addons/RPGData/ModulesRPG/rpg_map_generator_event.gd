@tool
class_name MapGeneratorEvent
extends Resource

enum PLACEMENT {
	ANYWHERE,
	FLOOR,
	WALL
}

enum EVENT_POSITION {
	ANYWHERE = 0,
	AT_THE_TOP = 1,
	AT_THE_BOTTOM = 2,
	AT_THE_CENTER = 3,
	ON_THE_LEFT = 4,
	ON_THE_RIGHT = 5,
	TOP_LEFT = 6,
	TOP_RIGHT = 7,
	BOTTOM_LEFT = 8,
	BOTTOM_RIGHT = 9
}

@export var event: RPGEvent
@export var locked: bool = false
@export var probability: float = 10
@export var max_quantity: int = 0
@export var placement: PLACEMENT = PLACEMENT.ANYWHERE
@export var event_position: EVENT_POSITION = EVENT_POSITION.ANYWHERE
@export var ignore_environment: bool = false



func _to_string() -> String:
	return "<MapGeneratorEvent event=%s>" % event
