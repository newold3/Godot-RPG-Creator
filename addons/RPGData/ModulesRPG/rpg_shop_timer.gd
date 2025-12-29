@tool
class_name RPGShopTimer
extends Resource


func get_class(): return "RPGShopTimer"

@export var id: String = ""
@export var timer: float = 0.0
@export var current_stock: Dictionary = {} # id (item_type_item_id_item_index) = RPGShopItemStock
@export var timestamp: float = 0.0


func _init(p_id: String = "", p_timer: float = 0.0, p_current_stock: Dictionary = {}) -> void:
	id = p_id
	timer = p_timer
	current_stock = p_current_stock
	if GameManager.game_state:
		timestamp = GameManager.game_state.stats.play_time


func clear() -> void:
	id = ""
	timer = 0.0
	current_stock.clear()


func clone(value: bool = true) -> RPGShopTimer:
	var new_shop_timer = duplicate(value)
	
	for key in new_shop_timer.current_stock.keys():
		new_shop_timer[key] = new_shop_timer[key].clone(value)
	
	return new_shop_timer
