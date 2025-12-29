@tool
class_name RPGShopItemStock
extends Resource


func get_class(): return "RPGShopItemStock"


@export var item_uniq_id: String = ""
@export var item_id: int = 1
@export var item_type: int = 0 # 0 = item, 1 = weapon, 2 = armor
@export var max_stock: int = 0
@export var current_stock: int = 0
@export var restock_amount: int = 0


func _init(p_item_uniq_id: String = "", p_item_id: int = 1, p_item_type: int = 0, p_max_stock : int = 0, p_current_stock : int = 0, p_restock_amount : int = 0) -> void:
	item_uniq_id = p_item_uniq_id
	item_id = p_item_id
	item_type = p_item_type
	max_stock = p_max_stock
	current_stock = p_current_stock
	restock_amount = p_restock_amount


func clear() -> void:
	max_stock = 0
	current_stock = 0
	restock_amount = 0


func clone(value: bool = true) -> RPGShopItemStock:
	var new_shop_item_stock = duplicate(value)
	
	return new_shop_item_stock


func _to_string() -> String:
	return "<RPGShopItemStock uniq_id= %s, id=%s, type=%s, restock_amount=%s, current_stock=%s, max_stock=%s>" % [item_uniq_id, item_id, item_type, restock_amount, current_stock, max_stock]
