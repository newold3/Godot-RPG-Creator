@tool
class_name RPGEventPage
extends Resource


func get_class(): return "RPGEventPage"

enum LAUNCHER_MODE {ACTION_BUTTON, PLAYER_COLLISION, EVENT_COLLISION, AUTOMATIC, PARALLEL, CALLER, ANY_CONTACT}


@export var id : int
@export var page_id : int
@export var name: String
@export var list : Array[RPGEventCommand]
@export var condition: RPGEventPageCondition
@export var movement_type: int = 0
@export var movement_route: RPGMovementRoute
@export var movement_to_target: int = -1
@export var options: RPGEventPageOptions
@export var speed: int = 80
@export var frequency: int = 1
@export var z_index: int = 1
@export var launcher: LAUNCHER_MODE = LAUNCHER_MODE.ACTION_BUTTON
@export var event_trigger_list: PackedInt32Array = []
@export var character_path: String
@export var direction: LPCCharacter.DIRECTIONS = LPCCharacter.DIRECTIONS.DOWN
@export var modulate: Color = Color.WHITE
@export var is_quest_page: bool = false


func _init(_id: int = 0) -> void:
	id = _id
	if list.size() == 0:
		var command = RPGEventCommand.new()
		list.append(command)
	if !condition:
		condition = RPGEventPageCondition.new()
	if !movement_route:
		movement_route = RPGMovementRoute.new()
	if !options:
		options = RPGEventPageOptions.new()


func clone(value: bool = true) -> RPGEventPage:
	var new_event_page = duplicate(value)
	
	new_event_page.condition = condition.clone(value)
	new_event_page.movement_route = movement_route.clone(value)
	
	return new_event_page


func _to_string() -> String:
	return "<RPGEventPage id: %s list: %s>" % [id, list]
