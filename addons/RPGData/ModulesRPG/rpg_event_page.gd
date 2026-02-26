@tool
class_name RPGEventPage
extends Resource


## Returns the class name as a string for identification.
func get_class(): return "RPGEventPage"


## Defines the possible execution triggers for the event page.
enum LAUNCHER_MODE {ACTION_BUTTON, PLAYER_COLLISION, EVENT_COLLISION, AUTOMATIC, PARALLEL, CALLER, ANY_CONTACT, TOOL, SIGNAL}


## Unique 16-digit identifier generated once for this resource.
@export var _uniq_id: int = -1 :
	get():
		if _uniq_id == -1: _uniq_id = _generate_16_digit_id()
		return _uniq_id

## Main event ID in the database.
@export var id : int = 1

## Index of the page within the event's collection.
@export var page_id : int = 0

## Optional name to identify the page.
@export var name: String = ""

## Array of command resources to be executed.
@export var list : Array[RPGEventCommand]

## Conditions that must be met for this page to become active.
@export var condition: RPGEventPageCondition

## Movement pattern behavior (e.g., Fixed, Random, Follow).
@export var movement_type: int = 0

## Set of movement steps if the movement type is custom.
@export var movement_route: RPGMovementRoute

## ID of the target to follow or move towards.
@export var movement_to_target: int = -1

## Visual and interaction flags (animations, directions, passability).
@export var options: RPGEventPageOptions

## Travel speed in pixels per second.
@export var speed: int = 80

## Delay between movement steps.
@export var frequency: int = 1

## Visual rendering order in the scene.
@export var z_index: int = 1

## Interaction type required to start the event execution.
@export var launcher: LAUNCHER_MODE = LAUNCHER_MODE.ACTION_BUTTON

## List of specific event IDs that can trigger this page.
@export var event_trigger_list: PackedInt64Array = []

## List of weapon or tool categories that can activate this page.
@export var event_tool_list: PackedInt32Array = []

## Signals that are emitted or listened to by this page.
@export var event_signal_list: PackedInt32Array = []

## Defines the asset type used for the sprite (0: LPC, 1: Image, 2: Scene).
@export var character_type: int = 0 

## Path to the graphic or scene resource.
@export var character_path: String

## Starting orientation for the event's sprite.
@export var direction: LPCCharacter.DIRECTIONS = LPCCharacter.DIRECTIONS.DOWN

## Color tint applied to the event's graphic.
@export var modulate: Color = Color.WHITE

## If true, this page belongs to a quest logic branch.
@export var is_quest_page: bool = false

var _event_owner: int = -1


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
