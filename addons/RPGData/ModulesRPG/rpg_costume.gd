@tool
class_name RPGCostume
extends Resource

## Represents a Costume/Set. 

func get_class() -> String:
	return "RPGCostume"


## Unique identifier for the costume/set.
@export var id: int = 0

## Name of the costume/set.
@export var name: String = ""

## Part of the costume/set
@export var lpc_part: String = ""

## Description of the costume/set.
@export var description: String = ""

## Price of the costume/set.
@export var price: int = 0

@export var max_quantity: int = 0 # 0 = Infinite, + = limit

## Parameters of the costume/set.
@export var params: PackedInt32Array = PackedInt32Array([0, 0, 0, 0, 0, 0, 0, 0])

## list of user-defined parameters in [Database/Types/User Parameters]
@export var user_parameters: PackedFloat32Array = []

## Traits associated with the costume/set.
@export var traits: Array[RPGTrait] = []

## Materials required for crafting the costume/set.
@export var craft_materials: Array[RPGGearUpgradeComponent] = []

## Cost of crafting the costume/set.
@export var craft_cost: int = 0

## Materials obtained from disassembling the costume/set.
@export var disassemble_materials: Array[RPGGearUpgradeComponent] = []

## Cost of disassembling the costume/set.
@export var disassemble_cost: int = 0

## Additional notes about the costume/set.
@export var notes: String = ""


## Clears all the properties of the costume/set.
func clear() -> void:
	for v in ["name", "description", "lpc_part", "notes"]:
		set(v, "")
	for v in [traits, craft_materials, disassemble_materials]:
		v.clear()

	price = 0
	params = PackedInt32Array([0, 0, 0, 0, 0, 0, 0, 0])
	craft_cost = 0
	disassemble_cost = 0


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

	return value


## Gets the user parameter value for a specific level.
func get_user_parameter(param_id: int, _level_id: int = 1) -> float:
	var current_value = 0
	
	if user_parameters.size() > param_id and param_id >= 0:
		current_value += user_parameters[param_id]
	
	return current_value


## Clones the costume/set and its properties.
## @param value bool - Whether to perform a deep clone.
## @return RPGCostume - The cloned costume/set.
func clone(value: bool = true) -> RPGCostume:
	var new_costume = duplicate(value)

	for i in new_costume.traits.size():
		new_costume.traits[i] = new_costume.traits[i].clone(value)
	for i in new_costume.craft_materials.size():
		new_costume.craft_materials[i] = new_costume.craft_materials[i].clone(value)
	for i in new_costume.disassemble_materials.size():
		new_costume.disassemble_materials[i] = new_costume.disassemble_materials[i].clone(value)

	return new_costume


func _to_string() -> String:
	return "<RPGCostume name=%s ID=%s>" % [name, id]
