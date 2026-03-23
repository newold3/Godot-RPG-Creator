class_name OverflowBag
extends Sprite2D


var contents: Array = []


## Adds a new item record to the bag
func add_item(type: int, id: int, amount: int, level: int = 1, auto_popup: bool = false, popup_prefix: String = "") -> void:
	contents.append({
		"type": type,
		"id": id,
		"amount": amount,
		"level": level,
		"auto_popup_enabled": auto_popup,
		"popup_prefix": popup_prefix
	})


## Attempts to store contents in inventory, updating itself with leftovers
## Attempts to store contents in inventory, updating itself with leftovers and displaying an anchored error toast if full
func interact() -> void:
	var manager: InventoryManager = GameManager.inventory_manager
	if not manager: return
	
	manager.interacting_bag = self
	var old_contents = contents.duplicate()
	
	contents.clear()
	
	for item in old_contents:
		if item.type == 0:
			manager.add_item_amount(item.id, item.amount, item.auto_popup_enabled, item.popup_prefix)
		elif item.type == 1:
			manager.add_weapon_amount(item.id, item.amount, item.level, item.auto_popup_enabled, item.popup_prefix)
		elif item.type == 2:
			manager.add_armor_amount(item.id, item.amount, item.level, item.auto_popup_enabled, item.popup_prefix)
	
	manager.interacting_bag = null
	
	if contents.is_empty():
		manager.active_overflow_bags.erase(self)
		queue_free()
	else:
		var failed_items: Array = []
		
		for item in contents:
			var real_item = null
			
			if item.type == 0:
				real_item = RPGSYSTEM.database.items[item.id]
			elif item.type == 1:
				real_item = RPGSYSTEM.database.weapons[item.id]
			elif item.type == 2:
				real_item = RPGSYSTEM.database.armors[item.id]
			
			if real_item:
				failed_items.append({
					"name": real_item.name,
					"icon": real_item.icon,
					"amount": item.amount
				})
		
		if not failed_items.is_empty() and GameManager.get("toast_manager"):
			GameManager.toast_overflow_message(failed_items, ToastManager.ToastPos.BOTTOM_RIGHT, self, -120.0)


func _on_area_2d_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		if "interactive_event" in body:
			body.interactive_event = self


func _on_area_2d_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		if "interactive_event" in body:
			body.interactive_event = null
