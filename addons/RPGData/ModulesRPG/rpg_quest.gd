@tool
class_name RPGQuest
extends  Resource

## Handles game quest.

## Returns the class name of the resource.
## @return String - The class name.
func get_class(): return "RPGQuest"


## List of available quest types:
enum QuestMode {
	TALK_TO_NPC, ## Talk to a specific npc
	GATHER_ITEM, ## Gather a set number of items throughout the world
	BOUNTY_HUNTS, ## Track down and eliminate specific targets
	FIND_LOCATION, ## Enter a specific location.
	USER_QUEST ## User quests are only completed when indicated by a command in a common event/event.[br]This type of mission can also be completed based on progress set by a command in a common event.
}

## List of item type used in variable [item_type]
enum ItemType {
	ITEM, ## The type of object searched is of type [b]Item ID[/b].
	WEAPON, ## The type of object searched is of type [b]Weapon ID[/b].
	ARMOR, ## The type of object searched is of type [b]Armor ID[/b].
	ENEMY ## The type of object searched is of type [b]Kill Enemy ID[/b].
}

# General Settings
## Unique identifier for the quest.
@export var id: int = 0

## Name of the quest.
@export var name: String = ""

## Name of the category of the quest.
@export var category: String = ""

## Flag to indicate that this quest is unlocked from the beginning.
@export var default_unlocked: bool = false

## Flag to indicate that this quest is repeatable.
@export var is_repeatable: bool = false

## displays a detailed description of this quest to the player.
@export var description: String = ""

## Icon that will be displayed on the npc when this quest is available
@export var icon_available: RPGIcon = RPGIcon.new("res://Scenes/QuestMarkers/quest_available.tscn")

## Icon that will be displayed on the npc when this quest is in progress but not yet completed.
@export var icon_progress: RPGIcon = RPGIcon.new("res://Scenes/QuestMarkers/quest_in_progress.tscn")

## Icon that will be displayed on the npc when this quest is ready to be delivered.
@export var icon_completed: RPGIcon = RPGIcon.new("res://Scenes/QuestMarkers/quest_completed.tscn")

## Minimum party level required to start this quest
@export var min_level: int = 0

## Type of quest
@export var type: QuestMode = QuestMode.TALK_TO_NPC

## List of quest IDs that must be completed first.
@export var prerequisites: PackedInt32Array = []

## List of missions that auto-start together with this mission.
## This mission will not be completed until all the missions in the list, including this one, are finished.
@export var multi_quests: PackedInt32Array = []

## Quest that will auto-start when this quest is completed (ideal for quests with several sequential steps)
@export var chain_quest: int = -1

## Time limit to complete the quest. A value of 0 means there is no time limit to complete the quest.
## This time is used to automatically finish the quest (terminating it as failed).
@export var time_limit: float = 0.0


# Rewards

## Reward of money, experience and items received by the player upon completion of this quest.
@export var reward: RPGQuestReward = RPGQuestReward.new()

## List of quests that will be unlocked upon completion of this quest.
@export var quests_unlocked: PackedInt32Array = []

## Start the chain mission immediately
## after completing this (useful for making a quest chain).
@export var chain_mission_id: int = -1


# Objetive

## item_type indicates the quest type [enum ItemType].
@export var item_type: ItemType = ItemType.ITEM

## ID of the selected item/map.
@export var item_id: int = -1

## ID of the selected enemy.
@export var enemy_id: int = -1

## When type is [b]GATHER_ITEM[/b] or [b]BOUNTY_HUNTS[/b],
## [b]quantity[/b] refers to the quantity of that item searched for or enemy killed.
## When type is [b]FIND_LOCATION[/b], [b]quantity[/b] > 0 completed this quest.
@export var quantity: int = 0

## When type is [b]BOUNTY_HUNTS[/b], this option ensures that when the materials
## are delivered to complete the mission, they are not removed from the player's inventory.
@export var keep_materials: bool = false

## Used by mission type [b]USER_QUEST[/b] to track progress (form 0.0 to 1.0)
@export var progress: float = 0.0

## Used by mission type [b]TALK_TO_NPC[/b] to track progress
@export var target_event: RPGMapEventID = RPGMapEventID.new()

## Used by mission type [b]FIND_LOCATION[/b] to run a global event when quest is finished
@export var global_event: int = -1

## Additional notes about this common event.
@export var notes: String = ""


func clear():
	var vars = ["name", "category", "description"]
	for v in vars:
		set(v, "")
	vars = ["min_level", "time_limit", "quantity", "progress"]
	for v in vars:
		set(v, 0)
	vars = ["chain_quest", "chain_mission_id", "item_id", "enemy_id"]
	for v in vars:
		set(v, -1)
	vars = ["is_repeatable", "default_unlocked", "keep_materials"]
	for v in vars:
		set(v, false)
	for v in [icon_available, icon_progress, icon_completed, prerequisites, quests_unlocked, reward, multi_quests, target_event]:
		v.clear()
	type = QuestMode.TALK_TO_NPC
	item_type = ItemType.ITEM
	
	icon_available.path = "res://Scenes/QuestMarkers/quest_available.tscn"
	icon_progress.path = "res://Scenes/QuestMarkers/quest_in_progress.tscn"
	icon_completed.path = "res://Scenes/QuestMarkers/quest_completed.tscn"


func clear_objetive() -> void:
	item_type = ItemType.ITEM
	item_id = -1
	enemy_id = -1
	quantity = 0
	keep_materials = false
	progress = 0.0
	target_event.clear()


## Clones the quest and its properties.
## @param value bool - Whether to perform a deep clone.
## @return RPGQuest - The cloned actor.
func clone(value: bool = true) -> RPGQuest:
	var new_quest = duplicate(value)
	if new_quest.reward:
		new_quest.reward = new_quest.reward.clone(value)
	new_quest.target_event = new_quest.target_event.clone(value)
	return new_quest
