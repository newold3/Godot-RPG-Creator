@tool
class_name RPGQuestReward
extends  Resource

## Handles game quest reward.

## Returns the class name of the resource.
## @return String - The class name.
func get_class(): return "RPGQuestReward"

## Money obtained by completing this quest
@export var gold: int = 0

## Experience obtained by completing this quest
@export var experience: int = 0

## Items obtained by completing this quest
@export var items: Array[RPGItemDrop] = []

## Custom data dictionary for future expansion and dynamic properties.
@export var custom_data: Dictionary = {}


func clear() -> void:
	gold =  0
	experience = 0
	items.clear()
	if custom_data != null:
		custom_data.clear()
	else:
		custom_data = {}

## Clones the quest and its properties.
## @param value bool - Whether to perform a deep clone.
## @return RPGQuest - The cloned actor.
func clone(value: bool = true) -> RPGQuestReward:
	var new_reward = duplicate(value)
	for i in new_reward.items.size():
		new_reward.items[i] = new_reward.items[i].clone(value)
	new_reward.custom_data = custom_data.duplicate(true) if custom_data != null else {}
	return new_reward
