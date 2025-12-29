@tool
class_name RPGSkillRequiredWeapon
extends Resource


func get_class(): return "RPGSkillRequiredWeapon"


@export var category_id: int
@export var item_id: int


func _init(_category_id = 0, _item_id = 0) -> void:
	category_id = _category_id
	item_id = _item_id


func clone(value: bool = true) -> RPGSkillRequiredWeapon:
	return(duplicate(value))
