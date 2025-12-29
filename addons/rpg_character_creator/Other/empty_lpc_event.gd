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


func is_passable() -> bool:
	return passable


func start(obj: Node, launcher_mode: RPGEventPage.LAUNCHER_MODE) -> bool:
	# update interactive_events_found stat
	if GameManager.game_state and GameManager.current_map:
		var id = "%s_%s" % [GameManager.current_map.internal_id, current_event.id]
		if not id in GameManager.game_state.stats.interactive_events_found:
			GameManager.game_state.stats.interactive_events_found[id] = true
			
	if obj in targets_over_me:
		return false
	
	if QuestManager.manage_mission_for_event(current_event):
		return false
		
	if current_event_page:
		if current_event_page.launcher != launcher_mode:
			return false
		GameInterpreter.start_event(self, current_event_page.list)
	
	targets_over_me.append(obj)
	
	return true
