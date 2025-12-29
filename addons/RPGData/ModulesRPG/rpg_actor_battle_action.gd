@tool
class_name RPGActorBattleAction
extends Resource

## Returns the class name of the resource.
## @return String - The class name.
func get_class():
	return "RPGActorBattleAction"

## Occasion when the action is used.
@export var occasion: int = 0

## Type of the action.
@export var type: int = 0

## Condition for the action.
@export var condition: int = 0

## Rate of the condition.
@export var condition_rate: float = 100.0

## Sound effect associated with the action.
@export var fx: RPGSound = RPGSound.new()

## ID of the common event.
@export var common_event_id: int = 1

## ID of the skill.
@export var skill_id: int = 1

## Clones the battle action.
## @param value bool - Whether to perform a deep clone.
## @return RPGActorBattleAction - The cloned battle action.
func clone(value: bool = true) -> RPGActorBattleAction:
	var new_actor_battle_action = duplicate(value)
	new_actor_battle_action.fx = new_actor_battle_action.fx.clone()
	return new_actor_battle_action
