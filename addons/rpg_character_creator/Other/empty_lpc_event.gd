@tool
class_name EmptyLPCEvent
extends CharacterBase


func get_class() -> String: return "EmptyLPCEvent"
func get_custom_class() -> String: return "EmptyLPCEvent"


@export var current_event: RPGEvent
@export var current_event_page: RPGEventPage :
	set(value):
		current_event_page = value
		if value:
			idle_animation_enabled = value.options.idle_animation
			walking_animation_enabled = value.options.walking_animation
			fixed_direction = value.options.fixed_direction
			passable = value.options.passable

var idle_animation_enabled: bool = false
var walking_animation_enabled: bool = false
var fixed_direction: bool = false
var passable: bool = false


func _ready() -> void:
	super()
	if not is_in_group("event"):
		add_to_group("event")
	
	set_collision_layer_value(1, false)
	set_collision_layer_value(3, true)
	set_collision_mask_value(1, true)
	set_collision_mask_value(2, true)
	set_collision_mask_value(3, true)
	set_collision_mask_value(4, true)


#region event's functions
## Returns whether this event can be passed through.
func is_passable() -> bool:
	return EventManager.is_passable(self)


## Returns whether this event can be lifted.
func is_liftable() -> bool:
	return EventManager.is_liftable(self)


## Returns whether this event can be moved.
func is_moveable() -> bool:
	return EventManager.is_moveable(self)


## Returns whether this event is currently pressed.
func is_pressed() -> bool:
	return EventManager.is_pressed(self)


## Calculates the next tile coordinate to move toward the target event.
func _get_next_move_toward_event() -> Vector2i:
	return EventManager.get_next_move_toward_event(self)


## Starts the lifting animation logic.
func _start_lift_animation() -> void:
	EventManager.start_lift_animation(self)


## Starts the event interaction.
func start(obj: Node, launcher_mode: RPGEnums.LauncherMode) -> bool:
	return EventManager.start_event(self, obj, launcher_mode)
#endregion
