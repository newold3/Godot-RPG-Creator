class_name InventoryManager
extends Node


var over_flow_bag: Array = []
var create_over_flow_bag: bool = false



## Helper function to count total used slots across all inventories
func _get_total_used_slots() -> int:
	var total = 0
	var game_state = GameManager.game_state
	
	for item_list in game_state.items.values():
		total += item_list.size()
	
	for weapon_list in game_state.weapons.values():
		total += weapon_list.size()
	
	for armor_list in game_state.armors.values():
		total += armor_list.size()
	
	return total


func _calculate_slots_needed(amount: int, max_per_stack: int) -> int:
	if max_per_stack <= 0:
		return 1
	return int(ceil(float(amount) / float(max_per_stack)))


func _split_into_stacks(amount: int, max_per_stack: int) -> Array:
	var stacks = []
	if max_per_stack <= 0:
		stacks.append(amount)
		return stacks
	
	while amount > 0:
		var stack_size = min(amount, max_per_stack)
		stacks.append(stack_size)
		amount -= stack_size
	
	return stacks


func _add_generic_amount(collection: Dictionary, data: Array, id: int, amount: int, level: int, item_type: int) -> int:
	amount = abs(amount)

	if id <= 0 or data.size() <= id or amount <= 0:
		return 0
	
	var real_item = data[id]
	var max_inventory = RPGSYSTEM.database.system.max_items_in_inventory
	var max_per_stack = RPGSYSTEM.database.system.max_items_per_stack
	var remaining_amount = amount
	var added_amount = 0
	
	if not collection.has(id):
		collection[id] = []
	
	var item_list = collection[id]
	
	for item in item_list:
		if remaining_amount <= 0:
			break
			
		var compatible = false
		var can_stack_more = false
		
		if item_type == 0:
			compatible = not item.is_perishable
			if compatible and max_per_stack > 0:
				can_stack_more = item.quantity < max_per_stack
			elif compatible:
				can_stack_more = true
		else:
			compatible = real_item.upgrades.max_levels == 1 and not item.equipped
			if compatible and max_per_stack > 0:
				can_stack_more = item.quantity < max_per_stack
			elif compatible:
				can_stack_more = true
		
		if compatible and can_stack_more:
			var can_add = remaining_amount
			if max_per_stack > 0:
				can_add = min(remaining_amount, max_per_stack - item.quantity)
			
			item.quantity += can_add
			remaining_amount -= can_add
			added_amount += can_add
	
	if remaining_amount > 0:
		var current_slots = _get_total_used_slots()
		var available_slots = max_inventory - current_slots if max_inventory > 0 else -1
		
		if max_inventory > 0 and available_slots <= 0:
			return added_amount
		
		var stacks = _split_into_stacks(remaining_amount, max_per_stack)
		var slots_needed = stacks.size()
		
		if max_inventory > 0 and slots_needed > available_slots:
			stacks = stacks.slice(0, available_slots)
		
		for stack_amount in stacks:
			if item_type == 0:
				if not real_item.perishable.is_enabled():
					var game_item = GameItem.new(id, stack_amount, 0)
					game_item.is_perishable = false
					item_list.append(game_item)
					added_amount += stack_amount
				else:
					var items_to_create = stack_amount
					if max_inventory > 0:
						var current_slots_check = _get_total_used_slots()
						var available_slots_check = max_inventory - current_slots_check
						items_to_create = min(stack_amount, available_slots_check)
					
					for i in items_to_create:
						var game_item = GameItem.new(id, 1, 0)
						game_item.is_perishable = true
						game_item.lifetime = real_item.perishable.duration
						item_list.append(game_item)
						added_amount += 1
			else:
				if real_item.upgrades.max_levels == 1:
					var game_item
					if item_type == 1:
						game_item = GameWeapon.new(id, stack_amount, 1)
					else:
						game_item = GameArmor.new(id, stack_amount, 2)
					game_item.current_level = max(1, min(level, real_item.upgrades.max_levels))
					item_list.append(game_item)
					added_amount += stack_amount
				else:
					var items_to_create = stack_amount
					if max_inventory > 0:
						var current_slots_check = _get_total_used_slots()
						var available_slots_check = max_inventory - current_slots_check
						items_to_create = min(stack_amount, available_slots_check)
					
					for i in items_to_create:
						var game_item
						if item_type == 1:
							game_item = GameWeapon.new(id, 1, 1)
						else:
							game_item = GameArmor.new(id, 1, 2)
						game_item.current_level = max(1, min(level, real_item.upgrades.max_levels))
						item_list.append(game_item)
						added_amount += 1

	return added_amount


func _remove_generic_amount(collection: Dictionary, id: int, amount: int, include_equipment: bool = false, use_perishable_logic: bool = false) -> void:
	amount = abs(amount)
	if not collection.has(id):
		return
	
	var item_list = collection[id]
	var remaining_to_remove = amount
	
	while remaining_to_remove > 0 and not item_list.is_empty():
		var item_found = false
		
		if use_perishable_logic:
			for i in range(item_list.size() - 1, -1, -1):
				var item = item_list[i]
				if not item.is_perishable:
					item_found = true
					
					if item.quantity >= remaining_to_remove:
						item.quantity -= remaining_to_remove
						remaining_to_remove = 0
						
						if item.quantity <= 0:
							item_list.erase(item)
					else:
						remaining_to_remove -= item.quantity
						item_list.erase(item)
					
					break
			
			if not item_found and remaining_to_remove > 0:
				var perishable_item = null
				var min_lifetime = INF
				
				for i in range(item_list.size()):
					var item = item_list[i]
					if item.is_perishable and item.lifetime < min_lifetime:
						min_lifetime = item.lifetime
						perishable_item = item
				
				if perishable_item != null:
					if perishable_item.quantity >= remaining_to_remove:
						perishable_item.quantity -= remaining_to_remove
						remaining_to_remove = 0
						
						if perishable_item.quantity <= 0:
							item_list.erase(perishable_item)
					else:
						remaining_to_remove -= perishable_item.quantity
						item_list.erase(perishable_item)
				else:
					break
		else:
			item_list.sort_custom(func(a, b):
				if a.current_level != b.current_level:
					return a.current_level < b.current_level
				return a.current_experience < b.current_experience
			)
			
			for i in range(item_list.size()):
				var item = item_list[i]
				if not item.equipped:
					item_found = true
					
					if item.quantity >= remaining_to_remove:
						item.quantity -= remaining_to_remove
						remaining_to_remove = 0
						
						if item.quantity <= 0:
							item_list.erase(item)
					else:
						remaining_to_remove -= item.quantity
						item_list.erase(item)
					
					break
			
			if not item_found and remaining_to_remove > 0 and include_equipment:
				for i in range(item_list.size()):
					var item = item_list[i]
					if item.equipped:
						item_found = true
						
						if item.quantity >= remaining_to_remove:
							item.quantity -= remaining_to_remove
							remaining_to_remove = 0
							
							if item.quantity <= 0:
								item_list.erase(item)
						else:
							remaining_to_remove -= item.quantity
							item_list.erase(item)
						
						break
		
		if not item_found:
			break
	
	if item_list.is_empty():
		collection.erase(id)


func get_item_amount(id: int) -> int:
	var quantity: int = 0
	if GameManager.game_state.items.has(id):
		for item: GameItem in GameManager.game_state.items[id]:
			quantity += item.quantity
	
	return quantity


func add_item_amount(id: int, amount: int, auto_popup_enabled: bool = false, popup_prefix: String = "") -> int:
	var added = _add_generic_amount(GameManager.game_state.items, RPGSYSTEM.database.items, id, amount, 0, 0)
	
	if added > 0:
		if auto_popup_enabled or RPGSYSTEM.database.system.options.get("auto_popup_on_pick_up_items", false):
			GameManager.call_deferred("_create_popup_message", 0, id, added, popup_prefix)
		
		var item_id = "0" + "_" + str(id)
		if not item_id in GameManager.game_state.stats.items_found:
			GameManager.game_state.stats.items_found[item_id] = 0
		GameManager.game_state.stats.items_found[item_id] += added
	
	if added != amount:
		over_flow_bag.append(
			{
				"type": 0,
				"id": id,
				"amount": amount - added,
				"auto_popup_enabled": auto_popup_enabled,
				"popup_prefix": popup_prefix,
			}
		)
		create_over_flow_bag = true
	
	return added


func remove_item_amount(id: int, amount: int) -> void:
	_remove_generic_amount(GameManager.game_state.items, id, amount, false, true)


func get_weapon_amount(id: int) -> int:
	var quantity: int = 0
	if GameManager.game_state.weapons.has(id):
		for item: GameWeapon in GameManager.game_state.weapons[id]:
			quantity += item.quantity
	
	return quantity


func add_weapon_amount(id: int, amount: int, level: int = 1, auto_popup_enabled: bool = false, popup_prefix: String = "", _item_level: int = -1) -> int:
	var added = _add_generic_amount(GameManager.game_state.weapons, RPGSYSTEM.database.weapons, id, amount, level, 1)
	
	if added > 0:
		if auto_popup_enabled or RPGSYSTEM.database.system.options.get("auto_popup_on_pick_up_items", false):
			GameManager.call_deferred("_create_popup_message", 1, id, added, popup_prefix, level)
		
		var item_id = "1" + "_" + str(id)
		if not item_id in GameManager.game_state.stats.items_found:
			GameManager.game_state.stats.items_found[item_id] = 0
		GameManager.game_state.stats.items_found[item_id] += added
	
	if added != amount:
		over_flow_bag.append(
			{
				"type": 1,
				"id": id,
				"amount": amount - added,
				"level": level,
				"auto_popup_enabled": auto_popup_enabled,
				"popup_prefix": popup_prefix,
			}
		)
		create_over_flow_bag = true
	
	return added


func remove_weapon_amount(id: int, amount: int, include_equipment: bool) -> void:
	_remove_generic_amount(GameManager.game_state.weapons, id, amount, include_equipment, false)


func get_armor_amount(id: int) -> int:
	var quantity: int = 0
	if GameManager.game_state.armors.has(id):
		for item: GameArmor in GameManager.game_state.armors[id]:
			quantity += item.quantity
	
	return quantity


func add_armor_amount(id: int, amount: int, level: int = 1, auto_popup_enabled: bool = false, popup_prefix: String = "") -> int:
	var added = _add_generic_amount(GameManager.game_state.armors, RPGSYSTEM.database.armors, id, amount, level, 2)
	
	if added > 0:
		if auto_popup_enabled or RPGSYSTEM.database.system.options.get("auto_popup_on_pick_up_items", false):
			GameManager.call_deferred("_create_popup_message", 2, id, added, popup_prefix, level)
		
		var item_id = "2" + "_" + str(id)
		if not item_id in GameManager.game_state.stats.items_found:
			GameManager.game_state.stats.items_found[item_id] = 0
		GameManager.game_state.stats.items_found[item_id] += added
	
	if added != amount:
		over_flow_bag.append(
			{
				"type": 2,
				"id": id,
				"amount": amount - added,
				"level": level,
				"auto_popup_enabled": auto_popup_enabled,
				"popup_prefix": popup_prefix,
			}
		)
		create_over_flow_bag = true
	
	return added


func remove_armor_amount(id: int, amount: int, include_equipment: bool) -> void:
	_remove_generic_amount(GameManager.game_state.armors, id, amount, include_equipment, false)
