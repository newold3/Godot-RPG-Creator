@tool
class_name RPGArmor
extends Resource

## This class represents armor in an RPG system. It includes properties that define the armor's unique identifier, name, icon, description, equipment type, armor type, rarity type, price, parameters, traits, upgrades, craft materials, craft cost, disassemble materials, disassemble cost, LPC part, and additional notes. These properties are essential for defining the characteristics and functionality of armor within the game.


## Returns the class name of the resource.
## @return String - The class name.
func get_class():
	return "RPGArmor"

## Unique identifier for the armor.
@export var id: int = 0

## Name of the armor.
@export var name: String = ""

## Icon associated with the armor.
@export var icon: RPGIcon = RPGIcon.new()

## Description of the armor.
@export var description: String = ""

## Type of equipment.
@export var equipment_type: int = 1

## Type of armor.
@export var armor_type: int = 1

## Rarity type of the armor.
@export var rarity_type: int = 0

## Price of the armor.
@export var price: int = 0

## Parameters of the armor.
@export var params: PackedInt32Array = PackedInt32Array([0, 0, 0, 0, 0, 0, 0, 0])

## list of user-defined parameters in [Database/Types/User Parameters]
@export var user_parameters: PackedFloat32Array = []

## Traits associated with the armor.
@export var traits: Array[RPGTrait] = []

## Upgrades for the armor.
@export var upgrades: RPGGearUpgrade = RPGGearUpgrade.new()

## Materials required for crafting the armor.
@export var craft_materials: Array[RPGGearUpgradeComponent] = []

## Cost of crafting the armor.
@export var craft_cost: int = 0

## Materials obtained from disassembling the armor.
@export var disassemble_materials: Array[RPGGearUpgradeComponent] = []

## Cost of disassembling the armor.
@export var disassemble_cost: int = 0

## Part of the armor in LPC format.
@export var lpc_part: String = ""

## Additional notes about the armor.
@export var notes: String = ""

## Minimum level required to use this armor
@export var level_restriction: int = 0

## Time between each tick (only used if ticks are enabled).
@export var tick_interval: float = 1.0

## Clears all the properties of the armor.
func clear() -> void:
	for v in ["name", "description", "lpc_part", "notes"]:
		set(v, "")
	for v in [traits, upgrades, craft_materials, disassemble_materials]:
		v.clear()
	equipment_type = 1
	armor_type = 1
	rarity_type = 0
	price = 0
	params = PackedInt32Array([0, 0, 0, 0, 0, 0, 0, 0])
	craft_cost = 0
	disassemble_cost = 0
	level_restriction = 0
	tick_interval = 1.0
	icon.clear()

## Gets the parameter value for a specific level.
## @param parameter String - The parameter to get.
## @param level int - The level to get the parameter for.
## @return int - The parameter value.
func get_parameter(parameter: String, level: int) -> int:
	var param_index: int = -1

	if RPGActor.BaseParamType.keys().has(parameter):
		param_index = RPGActor.BaseParamType[parameter]

	if param_index == -1:
		return 0

	var value = params[param_index]

	for i in range(1, level, 1):
		if upgrades.levels.size() > i:
			var level_value = upgrades.levels[i].parameters_multiplier[param_index]
			value += level_value
		else:
			break

	return value

## Gets the user parameter value for a specific level.
func get_user_parameter(param_id: int, level_id: int) -> float:
	var current_value = 0
	
	if user_parameters.size() > param_id and param_id >= 0:
		current_value += user_parameters[param_id]
		
	for i in range(1, level_id, 1):
		if i >= upgrades.max_levels: break
		var level: RPGGearUpgradeLevel = upgrades.levels[i]
		if  level.user_parameters.size() > param_id:
			current_value += level.user_parameters[param_id]
	
	return current_value


## Clones the armor and its properties.
## @param value bool - Whether to perform a deep clone.
## @return RPGArmor - The cloned armor.
func clone(value: bool = true) -> RPGArmor:
	var new_armor = duplicate(value)

	for i in new_armor.traits.size():
		new_armor.traits[i] = new_armor.traits[i].clone(value)
	for i in new_armor.craft_materials.size():
		new_armor.craft_materials[i] = new_armor.craft_materials[i].clone(value)
	for i in new_armor.disassemble_materials.size():
		new_armor.disassemble_materials[i] = new_armor.disassemble_materials[i].clone(value)

	new_armor.upgrades = new_armor.upgrades.clone(value)
	new_armor.icon = icon.clone(value)

	return new_armor


func _to_string() -> String:
	return "<RPGArmor name=%s ID=%s>" % [name, id]
