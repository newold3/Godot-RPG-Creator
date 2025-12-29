@tool
class_name RPGActor
extends Resource

## Handles game armors: their stats, costs, crafting materials
## and everything related to defensive equipment.

## Returns the class name of the resource.
## @return String - The class name.
func get_class():
	return "RPGActor"

## Unique identifier for the actor.
@export var id: int = 0

## Name of the actor.
@export var name: String = ""

## Icon associated with the actor.
@export var icon: RPGIcon = RPGIcon.new()

## Nickname of the actor.
@export var nickname: String = ""

## Profile description of the actor.
@export var profile: String = ""

## Class identifier for the actor.
@export var class_id: int = 1

## Initial level of the actor.
@export var initial_level: int = 1

## Maximum level the actor can reach.
@export var max_level: int = 99

## Preview image for the actor's face.
@export var face_preview: RPGIcon = RPGIcon.new()

## Preview image for the actor's character.
@export var character_preview: String = ""

## Preview image for the actor's battler.
@export var battler_preview: String = ""

## Equipment items the actor has.
@export var equipment: PackedInt32Array = []

## Initial level for all equipment.
@export var equipment_level: PackedInt32Array = []

## Traits associated with the actor.
@export var traits: Array[RPGTrait] = []

## Additional notes about the actor.
@export var notes: String = ""

## Scene associated with the actor.
@export var character_scene: String = ""

## Data file associated with the actor.
@export var character_data_file: String = ""

## Battle actions the actor can perform.
@export var battle_actions: Array[RPGActorBattleAction] = []

## Time between each tick (only used if ticks are enabled).
@export var tick_interval: float = 1.0

## If you use poses for the character that include a weapon, the head may appear
## lower than the top edge in order to keep the full character visible.
## This offset can be useful and will be used by some menus to position the image.
@export var pose_vertical_offset: int = 0

## Enum for base parameters.
enum BaseParamType {
	HP = 0,    ## Hit Points
	HIT_POINTS = 0,    ## Hit Points
	MP = 1,    ## Magic Points
	MAGIC_POINTS = 1,    ## Magic Points
	ATK = 2,    ## Attack
	ATTACK = 2,    ## Attack
	DEF = 3,    ## Defense
	DEFENSE = 3,    ## Defense
	MAT = 4,    ## Magic Attack
	MATK = 4,    ## Magic Attack
	MAGIC_ATTACK = 4,    ## Magic Attack
	MDF = 5,    ## Magic Defense
	MDEF = 5,    ## Magic Defense
	MAGIC_DEFENSE = 5,    ## Magic Defense
	AGI = 6,    ## Agility
	AGILITY = 6,    ## Agility
	LUK = 7,    ## Luck
	LUCK = 7    ## Luck
}

## Enum for extra parameters.
enum ExtraParamType {
	HIT = 0,    ## Hit Rate
	HIT_RATE = 0,    ## Hit Rate
	EVA = 1,    ## Evasion Rate
	EVASION = 1,    ## Evasion Rate
	EVASION_RATE = 1,    ## Evasion Rate
	CRI = 2,    ## Critical Rate
	CRITICAL = 2,    ## Critical Rate
	CRITICAL_RATE = 2,    ## Critical Rate
	CEV = 3,    ## Critical Evasion
	CRITICAL_EVASION = 3,    ## Critical Evasion
	CRITICAL_EVASION_RATE = 3,    ## Critical Evasion
	MEV = 4,    ## Magic Evasion
	MAGIC_EVASION = 4,    ## Magic Evasion
	MAGIC_EVASION_RATE = 4,    ## Magic Evasion
	MRF = 5,    ## Magic Reflection
	MAGIC_REFLECTION = 5,    ## Magic Reflection
	CNT = 6,    ## Counter Attack
	COUNTER_ATTACK = 6,    ## Counter Attack
	HRG = 7,    ## HP Regeneration
	HP_REGENERATION = 7,    ## HP Regeneration
	MRG = 8,    ## MP Regeneration
	MP_REGENERATION = 8,    ## MP Regeneration
	TRG = 9,    ## TP Regeneration
	TP_REGENERATION = 9    ## TP Regeneration
}

## Enum for special parameters.
enum SpecialParamType {
	TGR = 0,    ## Target Rate
	TARGET_RATE = 0,    ## Target Rate
	GRD = 1,    ## Guard Effect
	GUARD_EFFECT = 1,    ## Guard Effect
	REC = 2,    ## Recovery Effect
	RECOVERY_EFFECT = 2,    ## Recovery Effect
	HM = 3,    ## Healing Mastery
	HEALING_MASTERY = 3,    ## Healing Mastery
	MCR = 4,    ## MP Cost Rate
	MP_COST_RATE = 4,    ## MP Cost Rate
	TCR = 5,    ## TP Charge Rate
	TP_CHARGE_RATE = 5,    ## TP Charge Rate
	PDR = 6,    ## Physical Damage Rate
	PHYSICAL_DAMAGE_RATE = 6,    ## Physical Damage Rate
	MDR = 7,    ## Magic Damage Rate
	MAGIC_DAMAGE_RATE = 7,    ## Magic Damage Rate
	FDR = 8,    ## Floor Damage Rate
	FLOOR_DAMAGE_RATE = 8,    ## Floor Damage Rate
	EXR = 9,    ## Experience Rate
	EXPERIENCE_RATE = 9,    ## Experience Rate
	GDR = 10,    ## Gold Rate
	GOLD_RATE = 10    ## Gold Rate
}

## Enum for new parameters
## 
## IMPORTANT: When creating arrays for these parameters, do NOT hardcode the size!
## Instead, use get_new_param_array_size() to automatically calculate the correct size
## based on unique enum values.
enum NewParamType {
	# STAMINA = 0, ENERGY = 0
	# FOCUS = 1, CONCENTRATION = 1
}

## Returns the number of unique parameters in NewParamType enum.
## Use this to size arrays instead of hardcoding values.
func get_new_param_array_size() -> int:
	var unique_values = {}
	for key in NewParamType:
		unique_values[NewParamType[key]] = true
	return unique_values.size()


## Clears all the properties of the actor.
func clear():
	var vars = ["name", "nickname", "profile", "face_preview", "character_preview", "battler_preview", "notes", "character_scene", "character_data_file"]
	for v in vars:
		set(v, "")
	for v in [equipment, traits, battle_actions, equipment_level]:
		v.clear()
	class_id = 1
	initial_level = 1
	max_level = 99
	tick_interval = 1.0
	icon.clear()

## Clones the actor and its properties.
## @param value bool - Whether to perform a deep clone.
## @return RPGActor - The cloned actor.
func clone(value: bool = true) -> RPGActor:
	var new_actor = duplicate(value)

	for i in new_actor.traits.size():
		new_actor.traits[i] = new_actor.traits[i].clone(value)
	for i in new_actor.battle_actions.size():
		new_actor.battle_actions[i] = new_actor.battle_actions[i].clone(value)

	new_actor.icon = icon.clone(value)

	return new_actor
