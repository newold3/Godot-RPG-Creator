@tool
class_name RPGExtractionItem
extends Resource

## Item id in the current map (autocalculate by the editor)
@export var id: int = 0
## The name shown for this item in the  maps
@export var name: String = ""
## The name shown for this item in the  maps
@export var icon: RPGIcon = RPGIcon.new()
## [RPGExtractionScene] scene that will be used to display
## this item on the map and interact with it.
@export var scene_path: String = ""
## Profession required in order to attempt to extract this resource
@export var required_profession: int = 1
#required_level
## Minimun level required of the chosen profession in order to attempt to extract this resource
@export var min_required_profession_level: int = 1
## Maximun level required of the chosen profession in order to attempt to extract this resource
@export var max_required_profession_level: int = 1
## By enabling this option, this item can be extracted at any level (as long as
## the item's level is no more than 10 levels higher than the player's).
@export var no_level_restrictions: bool = true
## Current level for this resource
## The level can never be lower than the minimum level required or higher than the maximum level required for the profession.
@export var current_level: int = 1
## Number of times that can be extracted until the resource
## is depleted and enters recharge time.
@export var max_uses: int = 3
## Actual time it will take for this item to recharge once depleted (in seconds)
@export var respawn_time: int = 3600
## List of items that can be extracted from this node
@export var drop_table: Array[RPGItemDrop] = []
## Sound played on loop while this item is being extracted
@export var extraction_fx: RPGSound = RPGSound.new()
## Location X of the tile where this item will be positioned on the map
@export var x : int = 0
## Location Y of the tile where this item will be positioned on the map
@export var y : int = 0
## Base experience that this item will give when extracted 
## with the same profession level as the player's level for this item.
##
## [b]Note: This value will change by a higher or lower percentage depending
## on the item's level relative to the character's level.[/b]
@export var experience_base: int = 1


func _init(p_id: int = 1, px: int = 0, py: int = 0) -> void:
	id = p_id
	x = px
	y = py


func get_profession() -> RPGProfession:
	if required_profession > 0 and RPGSYSTEM.database.professions.size() > required_profession:
		return RPGSYSTEM.database.professions[required_profession]
	
	return null


func is_deep_equal(a: Variant, b: Variant) -> bool:
	if a == b:
		return true

	if typeof(a) != typeof(b):
		return false

	if a is Array:
		if a.size() != b.size():
			return false
		for i in range(a.size()):
			if not is_deep_equal(a[i], b[i]):
				return false
		return true

	elif a is Dictionary:
		if a.size() != b.size():
			return false
		if not a.has_all(b.keys()):
			return false
		for key in a:
			if not is_deep_equal(a[key], b[key]):
				return false
		return true

	elif a is Resource:
		if a.get_script() != b.get_script():
			return false
			
		for property in a.get_property_list():
			var usage = property.usage
			if (usage & PROPERTY_USAGE_SCRIPT_VARIABLE) or (usage & PROPERTY_USAGE_STORAGE):
				var val_a = a.get(property.name)
				var val_b = b.get(property.name)

				if not is_deep_equal(val_a, val_b):
					return false
		return true

	return false


func is_equal_to(other: RPGExtractionItem) -> bool:
	return is_deep_equal(self, other)


func clone(value: bool) -> RPGExtractionItem:
	var new_item = duplicate(true)
	
	for i in new_item.drop_table.size():
		new_item.drop_table[i] = new_item.drop_table[i].duplicate(value)
	
	new_item.extraction_fx = new_item.extraction_fx.clone(value)
	
	return new_item


func _to_string() -> String:
	return "<RPGExtractionItem id=%s name=%s tile=%sx%s>" % [id, name, x, y]
