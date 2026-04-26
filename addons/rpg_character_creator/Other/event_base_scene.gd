@tool
class_name LPCEvent
extends LPCBase


func get_class() -> String: return "LPCEvent"
func get_custom_class() -> String: return "LPCEvent"


#region Constants, Signals and Variables
@export var event_data: RPGLPCCharacter
@export var current_event: RPGEvent
@export var current_event_page: RPGEventPage :
	set(value):
		current_event_page = value
		if value:
			if is_node_ready():
				#%FinalCharacter.get_material().set_shader_parameter("force_disable_breathing", !character_options.idle_animation)
				#%FinalCharacter.get_material().set_shader_parameter("blend_color", current_event_page.modulate)
				force_disable_breathing = !character_options.idle_animation
				%FinalCharacter.modulate = current_event_page.modulate

#endregion


# call only when character creator editor create it
func _build() -> void:
	add_to_group("event")
	super()


func _ready() -> void:
	current_data = event_data
	#%FinalCharacter.get_material().set_shader_parameter("random_offset", randf_range(0, 800.0))
	super()


func set_modulate(color: Color) -> void:
	%FinalCharacter.modulate = color


func _process(delta: float) -> void:
	if frame_delay == 0.0:
		run_animation()
		frame_delay = frame_delay_max if !is_running else frame_delay_max_running
	else:
		frame_delay = max(0.0, frame_delay - delta)
	
	current_direction = last_direction


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
func start(obj: Node, launcher_mode: RPGEventPage.LAUNCHER_MODE) -> bool:
	return EventManager.start_event(self, obj, launcher_mode)
#endregion
