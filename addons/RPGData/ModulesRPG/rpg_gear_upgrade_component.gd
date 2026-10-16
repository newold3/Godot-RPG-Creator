@tool
class_name RPGGearUpgradeComponent
extends  Resource


func get_class(): return "RPGGearUpgradeComponent"


@export var component: RPGComponent = RPGComponent.new()
@export var quantity: int = 1
@export var percent: float = 100.0

## Custom data dictionary for future expansion and dynamic properties.
@export var custom_data: Dictionary = {}


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
	new_upgrade_component.custom_data = custom_data.duplicate(true) if custom_data != null else {}
	
	return(new_upgrade_component)
