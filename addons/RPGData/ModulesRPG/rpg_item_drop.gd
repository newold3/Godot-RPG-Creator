@tool
class_name RPGItemDrop
extends  Resource


func get_class(): return "RPGItemDrop"


@export var item: RPGComponent = RPGComponent.new()
@export var quantity: int = 1
@export var quantity2: int = 1 # used to create a random number beetween quantity and quantity2
@export var percent: float = 100
@export var min_level: int = 1 # level of the item (only applicable to weapons and armor)
@export var max_level: int = 1 # level of the item (only applicable to weapons and armor)

func clone(value: bool = true) -> RPGItemDrop:
	var new_drop_item = duplicate(value)
	new_drop_item.item = new_drop_item.item.clone(value)
	
	return(new_drop_item)
