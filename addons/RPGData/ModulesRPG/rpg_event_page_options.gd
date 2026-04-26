@tool
class_name RPGEventPageOptions
extends Resource


func get_class(): return "RPGEventPageOptions"

@export_group("General Config")
## If enabled, the NPC's name will be displayed above their head.
## If the active NPC page has a name assigned, that name will be used;
## otherwise, the event's name will be used.
@export var show_name_in_map: bool = false
## LabelSettings used to draw the character name.
@export var name_config_path: String = ""

@export_group("Visuals & Collision")
## If enabled, the sprite will cycle through its walking frames while moving.
@export var walking_animation: bool = true

## If enabled, the sprite will continue its animation cycle even while standing still.
@export var idle_animation: bool = true

## If true, the event's sprite direction will not change regardless of movement or interaction.
@export var fixed_direction: bool = false

## If true, the player and other events can move through this event's collision area.
@export var passable: bool = false


@export_group("Event Type")
@export_enum("NORMAL", "PICKABLE", "MOVEABLE") var event_type = 0
@export var type_params: Dictionary = {}


@export_group("Extra Interaction Config")
## Enables HP and hit/death switches for this page.
@export var use_extra_config: bool = false

## If true, the event ignores damage but can still trigger 'on_hit' switches.
@export var is_inmortal: bool = true

## Health points for this event page.
@export var hp: int = 1

## ID of the Self Switch to activate on any hit (-1 to disable).
@export var enable_self_switch_on_hit_id: int = -1

## ID of the Self Switch to activate when HP reaches 0 (-1 to disable).
@export var enable_self_switch_on_dead_id: int = -1


func _init(is_new: bool = false) -> void:
	if is_new:
		if FileCache and FileCache.options:
			var _config = FileCache.options.get("event_general_options", {})
			show_name_in_map = _config.get("show_name_in_map", false)
			name_config_path = _config.get("name_config_path", "")
			
			_config = FileCache.options.get("event_extra_options", {})
			use_extra_config = _config.get("use_extra_config", false)
			is_inmortal = _config.get("is_inmortal", false)
			hp = _config.get("hp", 1)
			enable_self_switch_on_hit_id = _config.get("enable_self_switch_on_hit_id", -1)
			enable_self_switch_on_dead_id = _config.get("enable_self_switch_on_dead_id", -1)


func clone(value: bool = true) -> RPGEventPageOptions:
	return duplicate(value)
