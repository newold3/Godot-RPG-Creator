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


func _on_body_entered(_body: Node2D) -> void:
	hit(_body)


func _on_area_entered(_area: Area2D) -> void:
	hit(_area)


func shoot() -> void:
	if collision_shape:
		collision_shape.set_deferred("disabled", false)
	if not is_queued_for_deletion():
		set_physics_process(true)


func destroy() -> void:
	if _is_destroyed: return
	_is_destroyed = true
	queue_free()
