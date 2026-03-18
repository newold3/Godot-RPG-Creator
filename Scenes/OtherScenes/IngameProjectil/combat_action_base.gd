@abstract class_name CombatActionBase
extends Area2D

## Abstract base class for all combat interactions in the engine.
## Forces inheriting scripts to implement specific core methods.

## The base damage dealt to targets upon a successful hit.
## This damage only applies to the map; in battle, weapons use the damage defined in the database.
@export var damage: int = 1

## main Collision Shape
@export var collision_shape: CollisionShape2D

## Resource weapon
var weapon_database: RPGWeapon

## current player
var player: CharacterBody2D

# security flag
var _is_destroyed: bool = false

var _hit_targets: Array[Node2D] = []


func _enter_tree() -> void:
	collision_shape = get_node_or_null("%CollisionShape2D")
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)


func _ready() -> void:
	if collision_shape:
		collision_shape.set_deferred("disabled", true)
	set_physics_process(false)


## Called immediately after instantiating the action in the scene tree.
@abstract func setup(action_id: String, direction: String, start_pos: Vector2, custom_stats: Dictionary = {})


## Called when the action connects with a target or reaches its lifecycle end.
@abstract func hit(target: Node2D = null)


func _on_body_entered(target: Node2D) -> void:
	if not target or _is_destroyed or is_queued_for_deletion():
		return

	var target_parent = target.get_parent()

	if not target_parent:
		return

	if is_instance_valid(player) and player == target_parent:
		return

	if target_parent in _hit_targets:
		return

	if target_parent.is_in_group("event"):
		_manage_target_activation(target_parent)
		pass

	_hit_targets.append(target_parent)
	_play_impact_sound()
		
	hit(target_parent)


func _get_direction() -> int:
	var final_direction: int = 4
	if "direction_vector" in self:
		var direction = get("direction_vector")
		match direction:
			Vector2.LEFT: final_direction = 1
			Vector2.RIGHT: final_direction = 2
			Vector2.DOWN: final_direction = 8
			_: final_direction = 4
		
	return final_direction


func _manage_target_activation(target: Node) -> void:
	var target_is_valid = "current_event_page" in target and target.current_event_page and "current_event" in target and target.current_event

	if target_is_valid:
		var page: RPGEventPage = target.current_event_page
		
		# Try Activate event with tool
		if weapon_database:
			if page.launcher == RPGEventPage.LAUNCHER_MODE.TOOL:
				for id in page.event_tool_list:
					if id in weapon_database.tools_family:
						var interpreter_id = "event_" + str(target.current_event.id)
						if not page.options.fixed_direction and "current_direction" in target and GameManager.current_player:
							var player_dir = GameManager.current_player.current_direction if not "direction_vector" in self else _get_direction()
							target.last_direction = target.get_opposite_direction(player_dir)
							target.current_direction = target.last_direction
						GameInterpreter.start_event(self, page.list, false, interpreter_id)
						return
		
		# Try use fallback extra config
		if page.options.use_extra_config:
			if not page.options.is_inmortal:
				var map = GameManager.current_map
				if map:
					var event_id = target.current_event._uniq_id
					var page_id = page._uniq_id
					var hps = map.events_page_hp.get(event_id)
					if hps and page_id in hps:
						hps[page_id] -= weapon_database.map_damage
						if hps[page_id] <= 0 and page.options.enable_self_switch_on_dead_id:
							if page.options.enable_self_switch_on_dead_id > 0:
								GameManager.set_local_switch(page.options.enable_self_switch_on_dead_id, true, target.current_event._uniq_id)
								return
			
			if page.options.enable_self_switch_on_hit_id:
				if page.options.enable_self_switch_on_hit_id > 0:
					GameManager.set_local_switch(page.options.enable_self_switch_on_hit_id, true, target.current_event._uniq_id)


func _play_impact_sound() -> void:
	pass


func _on_area_entered(area: Area2D) -> void:
	_on_body_entered(area)


func shoot() -> void:
	if collision_shape:
		collision_shape.set_deferred("disabled", false)
	if not is_queued_for_deletion():
		set_physics_process(true)


func destroy() -> void:
	if _is_destroyed: return
	_is_destroyed = true
	queue_free()
