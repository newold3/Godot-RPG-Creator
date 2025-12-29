@tool
class_name RPGItem
extends  Resource


func get_class(): return "RPGItem"


@export var id: int = 0
@export var name: String = ""
@export var icon: RPGIcon = RPGIcon.new()
@export var description: String = ""
@export var item_type: int = 1
@export var rarity_type: int = 0
@export var item_category: int = 0
@export var price: int = 0
@export var consumable: bool = true
@export var scope: RPGScope = RPGScope.new()
@export var occasion: int = 0
@export var invocation: RPGInvocation = RPGInvocation.new()
@export var damage: RPGDamage = RPGDamage.new()
@export var effects: Array[RPGEffect] = []
@export var perishable: RPGPerishable = RPGPerishable.new()
@export var battle_message: String = ""
@export var notes: String = ""


func clear():
	for v in ["name", "description", "battle_message", "notes"]: set(v, "")
	for v in [scope, invocation, damage, effects, perishable]: v.clear()
	item_type = 1
	rarity_type = 0
	item_category = 0
	price = 0
	consumable = false
	occasion = 0
	icon.clear()


func clone(value: bool = true) -> RPGItem:
	var new_item = duplicate(value)
	
	for i in new_item.effects.size():
		new_item.effects[i] = new_item.effects[i].clone(value)
	new_item.damage = new_item.damage.clone(value)
	new_item.scope = new_item.scope.clone(value)
	new_item.invocation = new_item.invocation.clone(value)
	new_item.perishable = new_item.perishable.clone(value)
	
	new_item.icon = icon.clone(value)
	
	return new_item
