@tool
class_name EnemySpawnRegion
extends Resource


@export var name : String = ""
@export var id : int = 0
@export var color: Color = Color(0.578, 0.138, 0.138, 0.455)
@export var rect: Rect2i = Rect2i()
@export var troop_list: Array[TroopSpawnData]
@export var steps: int = 60
@export var use_default_transition: bool = true
@export var custom_transition: RPGEventCommand


func clone(value: bool = true) -> EnemySpawnRegion:
	var new_enemy_spawn_region: EnemySpawnRegion = duplicate(value)
	
	for i in new_enemy_spawn_region.troop_list.size():
		new_enemy_spawn_region.troop_list[i] = new_enemy_spawn_region.troop_list[i].clone(value)
	
	if new_enemy_spawn_region.custom_transition:
		new_enemy_spawn_region.custom_transition = new_enemy_spawn_region.custom_transition.clone(value)
	
	return new_enemy_spawn_region


func _to_string() -> String:
	return "<EnemySpawnRegion %s: %s>" % [id, name]
