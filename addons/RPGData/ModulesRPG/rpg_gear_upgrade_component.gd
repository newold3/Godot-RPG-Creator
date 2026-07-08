@tool
class_name RPGGearUpgradeComponent
extends  Resource


func get_class(): return "RPGGearUpgradeComponent"


@export var component: RPGComponent = RPGComponent.new()
@export var quantity: int = 1
@export var percent: float = 100.0


func get_component() -> Dictionary:
	var obj = {}
	obj.percent = percent
	obj.quantity = quantity
	obj.item = component.get_item()
	if obj.item:
		obj.unlocked = GameManager.is_item_unlocked(obj.item, obj.item._uniq_id)
	else:
		obj.unlocked = false
	
	return obj


func clone(value: bool = true) -> RPGGearUpgradeComponent:
	var new_upgrade_component = duplicate(value)
	new_upgrade_component.component = new_upgrade_component.component.clone(value)
	
	return(new_upgrade_component)
