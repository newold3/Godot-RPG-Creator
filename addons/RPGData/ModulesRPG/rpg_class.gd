@tool
class_name RPGClass
extends Resource

## Defines character classes or professions, including their progression,
## skills and evolution throughout the game.


## Returns the class name of the resource.
## @return String - The class name.
func get_class():
	return "RPGClass"

## Unique identifier for the class.
@export var id: int = 0

## Name of the class.
@export var name: String = ""

## Icon associated with the class.
@export var icon: RPGIcon = RPGIcon.new()

## Maximum level for the class.
@export var max_level: int = 99

## Description of the class.
@export var description: String = ""

## Experience curve parameters for the class.
@export var experience: RPGCurveParams = RPGCurveParams.new()

## Parameter curves for the class.
@export var params: Array[RPGCurveParams] = []

## Weights used when compare equipment
@export var weights: Dictionary = {}

## Learnable skills for the class.
@export var learnable_skills: Array[RPGLearnableSkill] = []

## Traits associated with the class.
@export var traits: Array[RPGTrait] = []

## Additional notes about the class.
@export var notes: String = ""

## ID of the class to upgrade to.
@export var upgrade_to_class: int = 0

## Whether the upgrade is automatic.
@export var automatic_upgrade: bool = false

## Time between each tick (only used if ticks are enabled).
@export var tick_interval: float = 1.0

## Clears all the properties of the class.
func clear():
	for v in ["name", "icon", "description", "notes"]:
		set(v, "")
	for v in [learnable_skills, traits]:
		v.clear()
	max_level = 99
	_set_experience()
	_set_param_curves()
	upgrade_to_class = 0
	tick_interval = 1.0
	automatic_upgrade = false
	icon.clear()

## Initializes the class.
func _init() -> void:
	if experience.data.size() == 0:
		_set_experience()
		_set_param_curves()
		set_param_weights()

## Sets the experience curve parameters.
func _set_experience() -> void:
	experience = RPGCurveParams.new()
	experience.data.resize(max_level + 1)
	experience.background_color = Color("#ffffff")
	experience.min_value = 0
	experience.max_value = 1500000

	var basis = 30
	var extra = 20
	var acc_a = 30
	var acc_b = 30
	for i in range(1, max_level + 1, 1):
		experience.data[i] = round(basis * pow((i - 1), (0.9 + acc_a / 250)) * i * (i + 1) / (6 + pow(i, 2) / 50 / acc_b) + (i - 1) * extra)


## Sets the parameter curves using a Curve resource.
func _set_param_curves() -> void:
	var colors = [Color("#fb3b3b"), Color("#11c40b"), Color("#0b5cc4"), Color("#d0db0a"), Color("#7d0cee"), Color("#44f2ff"), Color("#e88e0e"), Color("#dd9aff")]
	var max_values = [9999, 2000, 250, 250, 250, 250, 450, 450]
	var min_values = [400, 80, 15, 15, 15, 15, 30, 30]
	
	for i in 8:
		var curve_parameter = RPGCurveParams.new()
		curve_parameter.data.resize(max_level + 1)
		curve_parameter.background_color = colors[i]
		curve_parameter.max_value = max_values[i]
		params.append(curve_parameter)
	
	var curve = preload("res://addons/CustomControls/Resources/Curves/param_basic_curve.tres")
	
	for i in range(1, max_level + 1):
		var level_ratio = float(i-1) / float(max_level)
		var curve_value = curve.sample(level_ratio)
		
		for param_idx in range(8):
			var value = min_values[param_idx] + (max_values[param_idx] - min_values[param_idx]) * curve_value
			params[param_idx].data[i] = int(value)


## Sets weights for the parameter.
func set_param_weights() -> void:
	weights.clear()
	var param_names = ["HP", "MP", "ATK", "DEF", "MATK", "MDEF", "AGI", "LUCK"]
	var param_weights = [1.5, 1.0, 2.0, 1.8, 1.5, 1.2, 1.3, 0.8]
	for i in param_names.size():
		weights[param_names[i]] = param_weights[i]


## Retrieve the weights for this class.
func get_weights() -> Dictionary:
	return weights


## Gets the parameter value for a specific level.
## @param parameter String - The parameter to get.
## @param level int - The level to get the parameter for.
## @return int - The parameter value.
func get_parameter(parameter: String, level: int) -> int:
	var current_data: Array
	match parameter.to_lower():
		"hp": current_data = params[0].data
		"mp": current_data = params[1].data
		"attack", "atk": current_data = params[2].data
		"defense", "def": current_data = params[3].data
		"magical_attack", "matk": current_data = params[4].data
		"magical_defense", "mdef": current_data = params[5].data
		"agility", "agi": current_data = params[6].data
		"luck", "lck": current_data = params[7].data
		"experience", "exp": current_data = experience.data

	if current_data and current_data.size() > level:
		return current_data[level]

	return 0

## Clones the class and its properties.
## @param value bool - Whether to perform a deep clone.
## @return RPGClass - The cloned class.
func clone(value: bool = true) -> RPGClass:
	var new_class = duplicate(value)

	for i in new_class.params.size():
		new_class.params[i] = new_class.params[i].clone(value)
	for i in new_class.traits.size():
		new_class.traits[i] = new_class.traits[i].clone(value)
	for i in new_class.learnable_skills.size():
		new_class.learnable_skills[i] = new_class.learnable_skills[i].clone(value)

	new_class.experience = experience.clone(value)
	new_class.icon = icon.clone(value)

	return new_class
