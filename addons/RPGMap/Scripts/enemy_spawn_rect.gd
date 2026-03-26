@tool
class_name EnemySpawnRegion
extends Resource


## The display name of this spawn region.
@export var name : String = ""

## The database identifier for this region.
@export var id : int = 0

## The color used to represent this region in the editor.
@export var color: Color = Color(0.578, 0.138, 0.138, 0.455)

## The rectangular area defining where this region exists.
@export var rect: Rect2i = Rect2i()

## A list of enemy troops that can spawn in this region.
@export var troop_list: Array[TroopSpawnData]

## Average number of steps required before a battle encounter triggers.
@export var steps: int = 60

## If true, uses the system's default battle transition effect.
@export var use_default_transition: bool = true

## Custom event command sequence to execute as a battle transition if the default is disabled.
@export var custom_transition: RPGEventCommand


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


## Creates a deep copy of the spawn region, including its troop list and transition data.
func clone(value: bool = true) -> EnemySpawnRegion:
	var new_enemy_spawn_region: EnemySpawnRegion = duplicate(value)
	
	for i in new_enemy_spawn_region.troop_list.size():
		new_enemy_spawn_region.troop_list[i] = new_enemy_spawn_region.troop_list[i].clone(value)
	
	if new_enemy_spawn_region.custom_transition:
		new_enemy_spawn_region.custom_transition = new_enemy_spawn_region.custom_transition.clone(value)
	
	return new_enemy_spawn_region


## Returns a string representation of the spawn region for debugging.
func _to_string() -> String:
	return "<EnemySpawnRegion %s: %s>" % [id, name]
