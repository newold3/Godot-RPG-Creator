@tool
class_name RPGTroopPage
extends  Resource


func get_class(): return "RPGTroopPage"


@export var id: int
@export var condition: RPGTroopCondition
@export var list: Array[RPGEventCommand]
## By default, after evaluating the pages, only the leftmost page whose conditions are met will be processed. When this option is enabled, this page will always be processed if its conditions are met, respecting the priority order. This allows multiple pages to be processed simultaneously if their conditions are fulfilled.
@export var is_non_exclusive: bool = false


func _init(_id: int = 0) -> void:
	id = _id
	if list.size() == 0:
		var command = RPGEventCommand.new()
		list.append(command)
	if !condition:
		condition = RPGTroopCondition.new()


func clone(value: bool = true) -> RPGTroopPage:
	var new_troop_page = duplicate(value)
	
	for i in new_troop_page.list.size():
		new_troop_page.list[i] = new_troop_page.list[i].clone(value)
	new_troop_page.condition = condition.clone(value)
	
	return new_troop_page
