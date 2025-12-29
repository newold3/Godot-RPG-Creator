@tool
class_name RPGGearUpgradeComponent
extends  Resource


func get_class(): return "RPGGearUpgradeComponent"


@export var component: RPGComponent = RPGComponent.new()
@export var quantity: int = 1


func clone(value: bool = true) -> RPGGearUpgradeComponent:
	var new_upgrade_component = duplicate(value)
	new_upgrade_component.component = new_upgrade_component.component.clone(value)
	
	return(new_upgrade_component)
