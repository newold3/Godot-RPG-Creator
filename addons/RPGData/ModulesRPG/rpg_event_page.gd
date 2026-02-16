@tool
class_name RPGEventPage
extends Resource


func get_class(): return "RPGEventPage"

enum LAUNCHER_MODE {ACTION_BUTTON, PLAYER_COLLISION, EVENT_COLLISION, AUTOMATIC, PARALLEL, CALLER, ANY_CONTACT}

@export var _uniq_id: int = -1 :
	get():
		if _uniq_id == -1: _uniq_id = _generate_16_digit_id()
		return _uniq_id

@export var id : int = 1
@export var page_id : int = 0
@export var name: String = ""
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
@export var event_trigger_list: PackedInt64Array = []
@export var event_tool_list: PackedInt32Array = []
@export var event_signal_list: PackedInt32Array = []
@export var character_type: int = 0 # 0 = LPC Events, 1 = Images, 2 = Custom Scenes
@export var character_path: String
@export var direction: LPCCharacter.DIRECTIONS = LPCCharacter.DIRECTIONS.DOWN
@export var modulate: Color = Color.WHITE
@export var is_quest_page: bool = false


func _generate_16_digit_id() -> int:
	var id = str(randi_range(1, 9))
	var characters = "0123456789"
	for i in range(15):
		var random_index = randi() % characters.length()
		id += characters.substr(random_index, 1)
	
	return int(id)


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
	new_event_page._uniq_id = _generate_16_digit_id()
	
	return new_event_page


func _to_string() -> String:
	return "<RPGEventPage id: %s character_path = %s, list: %s>" % [id, character_path, list]
