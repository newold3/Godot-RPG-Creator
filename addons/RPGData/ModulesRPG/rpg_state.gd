@tool
class_name RPGState
extends  Resource


func get_class(): return "RPGState"


## Unique identifier used for internal referencing and persistence.
@export var _uniq_id: int = -1 :
	get():
		if _uniq_id < 0: _uniq_id = RPGSYSTEM.generate_16_digit_id()
		return _uniq_id

@export var id: int = 0
@export var name: String = ""
@export var icon: RPGIcon = RPGIcon.new()
@export var description: String = ""
@export var restriction: int = 0
@export var motion_animation: int = 0
@export var overlay_animation: int = 0
@export var priority: int = 50
@export var remove_at_battle_end: bool = false
@export var remove_by_restriction: bool = false
@export var remove_by_damage: bool = false
@export var chance_by_damage: int = 100
@export var remove_by_walking: bool = false
@export var remove_by_time: bool = false
@export var is_cumulative: bool = false
@export var remove_by_stacks: bool = false
@export var is_damage_tick: bool = false
@export var steps_to_remove: int = 100
@export var auto_removal_timing: int = 0
@export var tick_interval: float = 1.0
@export var min_turns: int = 1
@export var max_turns: int = 1
@export var max_time: float = 0
@export var messages: Array[RPGMessage] = []
@export var traits: Array[RPGTrait] = []
@export var notes: String = ""

@export var separator: RPGSeparator = null


func get_icon() -> Texture:
	if icon:
		return icon.get_texture()
	
	return null


func clear() -> void:
	for v in ["name", "description", "notes"]: set(v, "")
	for v in [messages, traits]: v.clear()
	for v in ["remove_at_battle_end", "remove_by_restriction", "remove_by_damage", "remove_by_walking", "remove_by_time", "is_damage_tick", "is_cumulative", "remove_by_stacks"]: set(v, false)
	restriction = 0
	motion_animation = 0
	overlay_animation = 0
	priority = 50
	chance_by_damage = 100
	steps_to_remove = 100
	auto_removal_timing = 0
	min_turns = 1
	max_turns = 1
	icon.clear()
	separator = null


func clone(value: bool = true) -> RPGState:
	var new_state = duplicate(value)
	
	for i in new_state.messages.size():
		new_state.messages[i] = new_state.messages[i].clone(value)
	for i in new_state.traits.size():
		new_state.traits[i] = new_state.traits[i].clone(value)
	
	new_state.icon = icon.clone(value)
	
	return new_state


func _to_string() -> String:
	return "<RGPState id=%s name=%s>" % [id, name]
