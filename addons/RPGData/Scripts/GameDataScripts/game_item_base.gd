class_name GameItemBase
extends Resource


@export var uniq_id: int = -1 # Unique ID generated for this item
@export var id: int = 0 # real database id
@export var quantity: int = 0 # Number of items in possession of this type
@export var type: int # Indicates the type of equipment (0 = item, 1 = weapon, 2 = armor piece)
@export var newly_added: bool = false # This flag is activated when the item is created and will be deactivated when the player selects this item in a menu.


var _name: String


func _generate_15_digit_id() -> int:
	var id = str(randi_range(1, 9))
	var characters = "0123456789"
	for i in range(15):
		var random_index = randi() % characters.length()
		id += characters.substr(random_index, 1)
	
	return int(id)


func _init(_id: int = 0, _quantity: int = 0, _type: int = 0) -> void:
	id = _id
	quantity = _quantity
	type = _type
	newly_added = true
	uniq_id = _generate_15_digit_id()
	
	var data = get_real_data()
	if data:
		_name = data.name


func get_real_data() -> Variant:
	if self is GameItem:
		if id > 0 and RPGSYSTEM.database.items.size() > id:
			return RPGSYSTEM.database.items[id]
	elif self is GameWeapon:
		if id > 0 and RPGSYSTEM.database.weapons.size() > id:
			return RPGSYSTEM.database.weapons[id]
	elif self is GameArmor:
		if id > 0 and RPGSYSTEM.database.armors.size() > id:
			return RPGSYSTEM.database.armors[id]
	
	return null


func _to_string() -> String:
	var data = get_real_data()
	var data_name = "" if not data else "<%s> " % data.name
	match type:
		0: return "<Game Item %s%s: id=%s>" % [data_name, get_instance_id(), id]
		1: return "<Game Weapon %s%s: id=%s>" % [data_name, get_instance_id(), id]
		_: return "<Game Armor %s%s: id=%s>" % [data_name, get_instance_id(), id]
