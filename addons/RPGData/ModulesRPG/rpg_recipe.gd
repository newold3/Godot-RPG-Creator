@tool
class_name RPGRecipe
extends Resource


func get_class(): return "RPGRecipe"

## Recipe name
@export var name: String = ""
## Cost in money to create this item
@export var price: int = 0
## Number of items to be created when using this recipe
@export var quantity: int = 1
## indicates whether this recipe is available from the start of the game
@export var learned_by_default: bool = false
## List of materials needed to create this item
@export var materials: Array[RPGGearUpgradeComponent] = []


func clone(value: bool = true) -> RPGRecipe:
	var new_recipie = duplicate(value)
	for i in new_recipie.materials.size():
		new_recipie.materials[i] = new_recipie.materials[i].clone(value)
	
	return(new_recipie)


func _to_string() -> String:
	return "<RPGRecipe name=%s price=%s quantity=%s>" % [name, price, quantity]
