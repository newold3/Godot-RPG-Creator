@tool
class_name RPGEnemy
extends  Resource


func get_class(): return "RPGEnemy"


@export var id: int = 0
@export var name: String = ""
@export var description: String = ""
@export var icon: RPGIcon = RPGIcon.new()
@export var battler: String = ""
@export var enemy_scene: String = ""
@export var params: PackedInt32Array = [0, 0, 0, 0, 0, 0, 0, 0]
@export var experience_reward: int = 0
@export var gold_reward_from: int = 0
@export var gold_reward_to: int = 0
@export var drop_items: Array[RPGItemDrop] = []
@export var action_patterns: Array[RPGEnemyAction] = []
@export var traits: Array[RPGTrait] = []
@export var notes: String = ""
@export var battle_actions: Array[RPGActorBattleAction] = []


func clear() -> void:
	for v in ["name", "description", "battler", "enemy_scene", "notes"]: set(v, "")
	for v in [drop_items, action_patterns, traits, battle_actions]: v.clear()
	params = PackedInt32Array([0, 0, 0, 0, 0, 0, 0, 0])
	experience_reward = 0
	gold_reward_from = 0
	gold_reward_to = 0
	icon.clear()


func clone(value: bool = true) -> RPGEnemy:
	var new_enemy = duplicate(value)
	
	for i in new_enemy.drop_items.size():
		new_enemy.drop_items[i] = new_enemy.drop_items[i].clone(value)
	for i in new_enemy.action_patterns.size():
		new_enemy.action_patterns[i] = new_enemy.action_patterns[i].clone(value)
	for i in new_enemy.traits.size():
		new_enemy.traits[i] = new_enemy.traits[i].clone(value)
	for i in new_enemy.battle_actions.size():
		new_enemy.battle_actions[i] = new_enemy.battle_actions[i].clone(value)
	
	new_enemy.icon = icon.clone(value)
	
	return new_enemy
