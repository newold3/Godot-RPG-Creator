@tool
class_name RPGActor
extends Resource

## Handles game armors: their stats, costs, crafting materials
## and everything related to defensive equipment.

## Returns the class name of the resource.
## @return String - The class name.
func get_class():
	return "RPGActor"

## Unique identifier used for internal referencing and persistence.
@export var _uniq_id: int = -1 :
	get():
		if _uniq_id < 0: _uniq_id = RPGSYSTEM.generate_16_digit_id()
		return _uniq_id

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

## The gender with which this character identifies.
@export var gender: int = 0

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
@export var equipment: PackedInt64Array = []

## Initial level for all equipment.
@export var equipment_level: PackedInt32Array = []

## Traits associated with the actor.
@export var traits: Array[RPGTrait] = []

## Additional notes about the actor.
@export var notes: String = ""

@export var separator: RPGSeparator = null

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

## Redirects to RPGEnums
const BaseParamType = RPGEnums.BaseParamType
const ExtraParamType = RPGEnums.ExtraParamType
const SpecialParamType = RPGEnums.SpecialParamType

## Enum for new parameters
## 
## IMPORTANT: When creating arrays for these parameters, do NOT hardcode the size!
## Instead, use get_new_param_array_size() to automatically calculate the correct size
## based on unique enum values.
enum NewParamType {
	# STAMINA = 0, ENERGY = 0
	# FOCUS = 1, CONCENTRATION = 1
}

static func get_parameter_list(get_real_keys: bool = true) -> Array:
	var items: Array = []
	
	if not RPGSYSTEM.database: return items
	
	if get_real_keys:
		items = [
			"", # Base Parameters
			"HIT_POINTS", "MAGIC_POINTS", "ATTACK", "DEFENSE", "MAGIC_ATTACK", "MAGIC_DEFENSE", "AGILITY", "LUCK",
			"", # Extra Parameters
			"HIT_RATE", "EVASION_RATE", "CRITICAL_RATE", "CRITICAL_EVASION_RATE", "MAGIC_EVASION_RATE", "MAGIC_REFLECTION", "COUNTER_ATTACK", "HP_REGENERATION", "MP_REGENERATION", "TP_REGENERATION",
			"", # Special Parameters
			"TARGET_RATE", "GUARD_EFFECT", "RECOVERY_EFFECT", "HEALING_MASTERY", "MP_COST_RATE", "TP_CHARGE_RATE", "PHYSICAL_DAMAGE_RATE", "MAGIC_DAMAGE_RATE", "FLOOR_DAMAGE_RATE", "EXPERIENCE_RATE", "GOLD_RATE"
		]
		
		items.append("") # User Parameters
		
		var user_parameters = RPGSYSTEM.database.types.user_parameters
		for i in user_parameters.size():
			var item: RPGUserParameter = user_parameters[i]
			items.append("USER_PARAMETER_%s" % i)
		
	else:
		items = [
			"", # Base Parameters
			"Max HP", "Max MP", "Attack", "Defense", "Magical Attack", "Magical Defense", "Agility", "Luck",
			"", # Extra Parameters
			"Hit Rate", "Evasion Rate", "Critical Rate", "Critical Evasion Rate", "Magic Evasion Rate", "Magic Reflection", "Counter Attack", "HP Regeneration", "MP Regeneration", "TP Regeneration",
			"", # Special Parameters
			"Target Rate", "Guard Effect", "Recovery Effect", "Healing Mastery", "MP Cost Rate", "TP Charge Rate", "Physical Damage Rate", "Magic Damage Rate", "Floor Damage Rate", "Experience Rate", "Gold Rate"
		]
		
		items.append("") # User Parameters
		
		var user_parameters = RPGSYSTEM.database.types.user_parameters
		for i in user_parameters.size():
			var item: RPGUserParameter = user_parameters[i]
			items.append("User Parameter <%s: %s>" % [i + 1, item.name])
	
	
	return items


func get_icon() -> Texture:
	if icon:
		return icon.get_texture()
	
	return null


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
	separator = null
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


func _to_string() -> String:
	return("<RPGActor name=%s, id=%s>" % [name, id])
