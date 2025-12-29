@tool
class_name RPGTypeIcons
extends Resource

## Manages the icons that visually represent each type of element in the game.
## Essential for the user interface.


## Returns the class name of the resource.
## @return String - The class name.
func get_class():
	return "RPGTypeIcons"

## Icons for equipment types.
@export var equipment_icons: Array[RPGIcon] = []

## Icons for element types.
@export var element_icons: Array[RPGIcon] = []

## Icons for weapon types.
@export var weapon_icons: Array[RPGIcon] = []

## Icons for armor types.
@export var armor_icons: Array[RPGIcon] = []

## Icons for item types.
@export var item_icons: Array[RPGIcon] = []

## Icons for skill types.
@export var skill_icons: Array[RPGIcon] = []

## Icons for skill types.
@export var user_parameters_icons: Array[RPGIcon] = []

## Icons for skill types.
@export var main_parameters_icons: Array[RPGIcon] = []


## Clones the RPG type icons.
## @param value bool - Whether to perform a deep clone.
## @return RPGTypeIcons - The cloned RPG type icons.
func clone(value: bool = true) -> RPGTypeIcons:
	var new_type_icons = duplicate(value)
	for i in new_type_icons.equipment_icons.size():
		new_type_icons.equipment_icons[i] = new_type_icons.equipment_icons[i].clone(value)
	for i in new_type_icons.element_icons.size():
		new_type_icons.element_icons[i] = new_type_icons.element_icons[i].clone(value)
	for i in new_type_icons.weapon_icons.size():
		new_type_icons.weapon_icons[i] = new_type_icons.weapon_icons[i].clone(value)
	for i in new_type_icons.armor_icons.size():
		new_type_icons.armor_icons[i] = new_type_icons.armor_icons[i].clone(value)
	for i in new_type_icons.item_icons.size():
		new_type_icons.item_icons[i] = new_type_icons.item_icons[i].clone(value)
	for i in new_type_icons.skill_icons.size():
		new_type_icons.skill_icons[i] = new_type_icons.skill_icons[i].clone(value)
	for i in new_type_icons.user_parameters_icons.size():
		new_type_icons.user_parameters_icons[i] = new_type_icons.user_parameters_icons[i].clone(value)
	for i in new_type_icons.main_parameters_icons.size():
		new_type_icons.main_parameters_icons[i] = new_type_icons.main_parameters_icons[i].clone(value)

	return new_type_icons
