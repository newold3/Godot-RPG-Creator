@tool
class_name RPGTypes
extends Resource

## Defines the basic categories of the game: elements, weapon types, armors,
## items and their rarities. The foundation for classifying all content.


## Returns the class name of the resource.
## @return String - The class name.
func get_class():
	return "RPGTypes"

## Types of elements.
@export var element_types: PackedStringArray = []

## Types of skills.
@export var skill_types: PackedStringArray = []

## Types of weapons.
@export var weapon_types: PackedStringArray = []

## Rarity types of weapons.
@export var weapon_rarity_types: PackedStringArray = []

## Color types of weapon rarity.
@export var weapon_rarity_color_types: PackedColorArray = []

## Types of armor.
@export var armor_types: PackedStringArray = []

## Types of armor.
@export var tool_types: PackedStringArray = []

## Rarity types of armor.
@export var armor_rarity_types: PackedStringArray = []

## Color types of armor rarity.
@export var armor_rarity_color_types: PackedColorArray = []

## Rarity types of enemy.
@export var enemy_rarity_types: PackedStringArray = []

## Color types of enemy rarity.
@export var enemy_rarity_color_types: PackedColorArray = []

## Types of items.
@export var item_types: PackedStringArray = []

## Rarity types of items.
@export var item_rarity_types: PackedStringArray = []

## Rarity types of items.
@export var gender_types: PackedStringArray = []

## Color types of item rarity.
@export var item_rarity_color_types: PackedColorArray = []

## Types of equipment.
@export var equipment_types: PackedStringArray = []

## Main parameters.
@export var main_parameters: PackedStringArray = []

## User parameters.
@export var user_parameters: Array[RPGUserParameter] = []

## User stats.
@export var user_stats: PackedStringArray = []

## Color for drawing numbers in battle attacks that apply an element.
@export var element_colors: PackedColorArray = []

## Color for drawing numbers in battle attacks that apply an element.
@export var colorize_element_numbers: PackedByteArray = []

## Icons for different types.
@export var icons: RPGTypeIcons = RPGTypeIcons.new()


func _init() -> void:
	pass


func get_item_color(item_type: Variant, rarity_type: int) -> Color:
	var color = Color.WHITE
	
	var type = str(item_type).to_lower()
	
	match type:
		"0", "item", "items":
			if item_rarity_color_types.size() > rarity_type:
				color = item_rarity_color_types[rarity_type]
		"1", "weapon", "weapons":
			if weapon_rarity_color_types.size() > rarity_type:
				color = weapon_rarity_color_types[rarity_type]
		"2", "armor", "armors":
			if armor_rarity_color_types.size() > rarity_type:
				color = armor_rarity_color_types[rarity_type]
		"3", "enemy", "enemies":
			if enemy_rarity_color_types.size() > rarity_type:
				color = enemy_rarity_color_types[rarity_type]
	
	return color


func get_user_parameters_name(param_id: int) -> String:
	var result: String = ""
	if user_parameters.size() > param_id and param_id >= 0:
		result = user_parameters[param_id].name
	
	return result


## Clones the RPG types.
## @param value bool - Whether to perform a deep clone.
## @return RPGTypes - The cloned RPG types.
func clone(value: bool = true) -> RPGTypes:
	var new_type: RPGTypes = duplicate(value)
	for i in new_type.user_parameters.size():
		new_type.user_parameters[i] = new_type.user_parameters[i].clone(value)

	new_type.icons = new_type.icons.clone(value)

	return new_type
