@tool
class_name EventRegion
extends Resource

enum EventMode { COMMON_EVENTS, CALLER_EVENTS }
enum ActivationMode { ALWAYS_ACTIVE, SWITCH}

## The display name of this event region.
@export var name : String = ""

## The database identifier for this region.
@export var id : int = 0

## Defines how this region is activated.
@export var activation_mode: ActivationMode = ActivationMode.ALWAYS_ACTIVE

## The ID of the switch required to activate this region, if applicable.
@export var activation_switch_id: int = 1

## The color used to represent this region in the editor.
@export var color: Color = Color(0.578, 0.138, 0.138, 0.455)

## The rectangular area defining where this region exists.
@export var rect: Rect2i = Rect2i()

## Amount of damage dealt to entities within the region.
@export var damage_amount: int = 0

## How frequently damage is applied, in seconds.
@export var damage_frequency: float = 0.15

## Defines whether this region triggers common events or caller events.
@export var event_mode: EventMode = EventMode.COMMON_EVENTS

## The common event ID to execute when entering the region.
@export var entry_common_event: int = 0

## The common event ID to execute when exiting the region.
@export var exit_common_event: int = 0

## The caller event ID to trigger when entering the region.
@export var trigger_caller_event_on_entry: int = 0

## The caller event ID to trigger when exiting the region.
@export var trigger_caller_event_on_exit: int = 0

## Determines if entities can enter this region.
@export var can_entry: bool = true

## Determine whether entities can pass through this region without taking the tilemap's passability into account.
@export var always_passable: bool = false

## List of specific triggers that can interact with this region.
@export var triggers: PackedInt32Array = [-1]


## Hides the real exported variables from the inspector while keeping them serialized.
func _validate_property(property: Dictionary) -> void:
	if property.name == "id":
		property.usage = PROPERTY_USAGE_NO_EDITOR | PROPERTY_USAGE_STORAGE


## Injects ghost read-only string properties into the inspector.
func _get_property_list() -> Array[Dictionary]:
	var props: Array[Dictionary] = []
	
	props.append({
		"name": "Region ID",
		"type": TYPE_STRING,
		"usage": PROPERTY_USAGE_EDITOR
	})
	
	return props


## Returns the string values for the ghost properties.
func _get(property: StringName):
	if property == &"Region ID":
		return str(id)
		
	return null


## Prevents inspector crashes by safely ignoring edits to ghost properties.
func _set(property: StringName, value: Variant) -> bool:
	if property == &"Region ID":
		return true
		
	return false


## Creates a deep copy of the event region.
func clone(value: bool = true) -> EventRegion:
	var new_event_region: EventRegion = duplicate(value)
	
	return new_event_region


## Returns a string representation of the event region for debugging.
func _to_string() -> String:
	return "<EventRegion %s: %s>" % [id, name]
