@tool
class_name RPGWeapon
extends Resource

## This class represents weapon in an RPG system. It includes properties that define the armor's unique identifier, name, icon, description, equipment type, armor type, rarity type, price, parameters, traits, upgrades, craft materials, craft cost, disassemble materials, disassemble cost, LPC part, and additional notes. These properties are essential for defining the characteristics and functionality of armor within the game.


## Returns the class name of the resource.
## @return String - The class name.
func get_class(): return "RPGWeapon"


## Unique identifier used for internal referencing and persistence.
@export var _uniq_id: int = -1 :
	get():
		if _uniq_id < 0: _uniq_id = RPGSYSTEM.generate_16_digit_id()
		return _uniq_id

## Unique identifier for the weapon.
@export var id: int = 0

## Name of the weapon.
@export var name: String = ""

## Icon associated with the weapon.
@export var icon: RPGIcon = RPGIcon.new()

## Description of the weapon.
@export var description: String = ""

## List of usage restrictions for this equipment.
@export var equipment_restriction: RPGEquipRestrictions = RPGEquipRestrictions.new()

## Type of equipment.
@export var weapon_type: int = 1

## Rarity type of the weapon.
@export var rarity_type: int = 0

## Price of the weapon.
@export var price: int = 0

@export var max_quantity: int = 0 # 0 = Infinite, + = limit

## Animation when attacking with this weapon.
@export var animation: int = 0

## Parameters of the weapon.
@export var params: PackedInt32Array = PackedInt32Array([0, 0, 0, 0, 0, 0, 0, 0])

## list of user-defined parameters in [Database/Types/User Parameters]
@export var user_parameters: PackedFloat32Array = []

## Traits associated with the weapon.
@export var traits: Array[RPGTrait] = []

## Upgrades for the weapon.
@export var upgrades: RPGGearUpgrade = RPGGearUpgrade.new()

## Materials required for crafting the weapon.
@export var craft_materials : Array[RPGGearUpgradeComponent] = []

## Cost of crafting the weapon.
@export var craft_cost: int = 0

## Materials obtained from disassembling the weapon.
@export var disassemble_materials : Array[RPGGearUpgradeComponent] = []

## Cost of disassembling the weapon.
@export var disassemble_cost: int = 0

## Part of the weapon in LPC format.
@export var lpc_part: String = ""

## Script of type "CombatActionBase" used by this weapon to load different
## animations when starting an attack, when hitting something, or when being destroyed.
@export var lpc_part_custom_script: String = ""

## Attack power used by this weapon when it is not used in battle.
@export var map_damage: int = 1

## Add this weapon to one or more tools to trigger events in-game.
@export var tools_family: PackedInt32Array = []

## Additional notes about the weapon.
@export var notes: String = ""

## Time between each tick (only used if ticks are enabled).
@export var tick_interval: float = 1.0

@export var separator: RPGSeparator = null


func get_icon() -> Texture:
	if icon:
		return icon.get_texture()
	
	return null


func get_craft_materials() -> Array[Dictionary]:
	var objs: Array[Dictionary] = []
	for obj: RPGGearUpgradeComponent in craft_materials:
		objs.append(obj.get_component())
	
	return objs


func get_disassemble_materials() -> Array[Dictionary]:
	var objs: Array[Dictionary] = []
	for obj: RPGGearUpgradeComponent in disassemble_materials:
		objs.append(obj.get_component())
	
	return objs


func clear() -> void:
	for v in ["name", "description", "lpc_part", "notes", "equipment_restriction"]: set(v, "")
	for v in [traits, upgrades, craft_materials, disassemble_materials]: v.clear()
	weapon_type = 1
	rarity_type = 0
	price = 0
	animation = 0
	params = PackedInt32Array([0, 0, 0, 0, 0, 0, 0, 0])
	craft_cost = 0
	disassemble_cost = 0
	tick_interval = 1.0
	icon.clear()
	separator = null
	
	var database = RPGSYSTEM.database
	if database:
		user_parameters.resize(database.types.user_parameters.size())
		for i in database.types.user_parameters.size():
			user_parameters[i] = database.types.user_parameters[i].default_value


func get_parameter(parameter: String, level: int) -> float:
	if parameter.begins_with("USER_PARAMETER_"):
		var param_id = parameter.replace("USER_PARAMETER_", "").to_int()
		return get_user_parameter(param_id, level)

	var param_index: int = -1

	if RPGEnums.BaseParamType.keys().has(parameter):
		param_index = RPGEnums.BaseParamType[parameter]

	if param_index == -1:
		return 0.0

	var value = float(params[param_index])

	for i in range(1, level, 1):
		if upgrades.levels.size() > i:
			var level_value = upgrades.levels[i].parameters_multiplier[param_index]
			value += float(level_value)
		else:
			break

	return value


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


func clone(value: bool = true) -> RPGWeapon:
	var new_weapon = duplicate(value)
	
	for i in new_weapon.traits.size():
		new_weapon.traits[i] = new_weapon.traits[i].clone(value)
	for i in new_weapon.craft_materials.size():
		new_weapon.craft_materials[i] = new_weapon.craft_materials[i].clone(value)
	for i in new_weapon.disassemble_materials.size():
		new_weapon.disassemble_materials[i] = new_weapon.disassemble_materials[i].clone(value)
	
	new_weapon.tools_family = tools_family.duplicate()
		
	new_weapon.upgrades = new_weapon.upgrades.clone(value)
	
	new_weapon.icon = icon.clone(value)
	
	if equipment_restriction:
		new_weapon.equipment_restriction = equipment_restriction.clone(value)
	else:
		new_weapon.equipment_restriction = RPGEquipRestrictions.new()
	
	return new_weapon


func _to_string() -> String:
	return "<RPGWeapon name=%s ID=%s>" % [name, id]
