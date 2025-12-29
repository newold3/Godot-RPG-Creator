@tool
class_name RPGTroop
extends  Resource


func get_class(): return "RPGTroop"


## Current Troop ID
@export var id: int = 0
## Current Troop name
@export var name: String = ""
## Current Troop background File
@export var background: String = ""
## Current Members In this battle
@export var members: Array[RPGTroopMember] = []
## Current command pages added to this troop
@export var pages: Array[RPGTroopPage] = [RPGTroopPage.new()]
## Additional notes about this common event.
@export var notes: String = ""


func _init() -> void:
	_create_initial_members()


func _create_initial_members() -> void:
	members = []
	var positions = [
		Vector2(0.727157, 0.647638), Vector2(0.727157, 0.780091),
		Vector2(0.764279, 0.501619), Vector2(0.764279, 0.920553),
		Vector2(0.854446, 0.644456), Vector2(0.854446, 0.782847),
		Vector2(0.876681, 0.511619), Vector2(0.876681, 0.917289)
	]
	for i in positions.size():
		var member = RPGTroopMember.new(0, -1, 1, positions[i])
		members.append(member)


func clear() -> void:
	name = ""
	background = ""
	_create_initial_members()
	pages = [RPGTroopPage.new()]
	notes = ""


func fix_pages_ids() -> void:
	for i in pages.size():
		pages[i].id = i


func clone(value: bool = true) -> RPGTroop:
	var new_troop = duplicate(value)
	
	for i in new_troop.members.size():
		new_troop.members[i] = new_troop.members[i].clone(value)
	for i in new_troop.pages.size():
		new_troop.pages[i] = new_troop.pages[i].clone(value)
	
	return new_troop
