@tool
class_name EventRegion
extends Resource

enum EventMode { COMMON_EVENTS, CALLER_EVENTS }
enum ActivationMode { ALWAYS_ACTIVE, SWITCH}


@export var name : String = ""
@export var id : int = 0
@export var activation_mode: ActivationMode = ActivationMode.ALWAYS_ACTIVE
@export var activation_switch_id: int = 1
@export var color: Color = Color(0.578, 0.138, 0.138, 0.455)
@export var rect: Rect2i = Rect2i()
@export var damage_amount: int = 0
@export var damage_frequency: float = 0.15
@export var event_mode: EventMode = EventMode.COMMON_EVENTS
@export var entry_common_event: int = 0
@export var exit_common_event: int = 0
@export var trigger_caller_event_on_entry: int = 0
@export var trigger_caller_event_on_exit: int = 0
@export var can_entry: bool = true
@export var triggers: PackedInt32Array = [-1]



func clone(value: bool = true) -> EventRegion:
	var new_enemy_spawn_region: EventRegion = duplicate(value)
	
	return new_enemy_spawn_region


func _to_string() -> String:
	return "<EventRegion %s: %s>" % [id, name]
