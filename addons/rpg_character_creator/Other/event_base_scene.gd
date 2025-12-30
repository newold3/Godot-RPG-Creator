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


func is_passable() -> bool:
	var force_passable: bool = false
	if current_event_page and (
		current_event_page.launcher == current_event_page.LAUNCHER_MODE.CALLER
	):
		force_passable = true
	return character_options.passable or force_passable


func _process(delta: float) -> void:
	if frame_delay == 0.0:
		run_animation()
		frame_delay = frame_delay_max if !is_running else frame_delay_max_running
	else:
		frame_delay = max(0.0, frame_delay - delta)
	
	current_direction = last_direction


func start(obj: Node, launcher_mode: RPGEventPage.LAUNCHER_MODE) -> bool:
	# update interactive_events_found stat
	if GameManager.game_state and GameManager.current_map:
		var id = "%s_%s" % [GameManager.current_map.internal_id, current_event.id]
		if not id in GameManager.game_state.stats.interactive_events_found:
			GameManager.game_state.stats.interactive_events_found[id] = true
	
	if busy: return false
	var current_frame_time = Time.get_ticks_msec()
	if obj in targets_over_me:
		return false
		
	if QuestManager.manage_mission_for_event(current_event):
		return false
		
	if current_event_page:
		if current_event_page.launcher != launcher_mode:
			return false
		if not current_event_page.options.fixed_direction and "current_direction" in obj:
			last_direction = get_opposite_direction(obj.current_direction)
			current_direction = last_direction
			
		busy = true
			
		GameInterpreter.start_event(self, current_event_page.list)
		var delay = (current_frame_time - Time.get_ticks_msec()) / 1000.0
		if delay < 0.1:
			await get_tree().create_timer(0.1 - delay).timeout
			if not is_instance_valid(self) or not is_inside_tree(): return false

		busy = false
	
	targets_over_me.append(obj)
	
	return true
