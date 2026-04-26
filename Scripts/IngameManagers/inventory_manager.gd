class_name InventoryManager
extends Node


var active_perishable_items: Array[GameItem] = []
var active_overflow_bags: Array[OverflowBag] = []
var interacting_bag: OverflowBag = null
var has_new_items_pending_view: bool = false

enum SCOPE {
	NONE,
	ONE,
	ALL,
	RANDOM
}

const OVER_FLOW_BAG = preload("uid://bsnxdk683a0qq")


func _handle_overflow(type: int, id: int, amount: int, level: int, auto_popup_enabled: bool, popup_prefix: String) -> void:
	if interacting_bag != null:
		interacting_bag.add_item(type, id, amount, level, auto_popup_enabled, popup_prefix)
		return
		
	var player_pos = Vector2.ZERO
	if GameManager.current_player and is_instance_valid(GameManager.current_player):
		player_pos = GameManager.current_player.global_position
		
	var target_bag: OverflowBag = null
	
	for bag in active_overflow_bags:
		if is_instance_valid(bag) and bag.global_position.distance_to(player_pos) < 10.0:
			target_bag = bag
			break
			
	if target_bag != null:
		target_bag.add_item(type, id, amount, level, auto_popup_enabled, popup_prefix)
	else:
		var new_bag = OVER_FLOW_BAG.instantiate()
		
		new_bag.global_position = player_pos
		GameManager.current_map.add_child(new_bag)
		new_bag.add_item(type, id, amount, level, auto_popup_enabled, popup_prefix)
		active_overflow_bags.append(new_bag)


func sync_perishable_items() -> void:
	active_perishable_items.clear()
	if not GameManager.game_state:
		return
	for item_list in GameManager.game_state.items.values():
		for item in item_list:
			if item.get("is_perishable") and item.lifetime > 0:
				active_perishable_items.append(item)


func _process(delta: float) -> void:
	if active_perishable_items.is_empty():
		return
	for i in range(active_perishable_items.size() - 1, -1, -1):
		var item = active_perishable_items[i]
		item.update_lifetime(delta)
		if item.lifetime <= 0:
			active_perishable_items.remove_at(i)
			_handle_rotted_item(item)


func _handle_rotted_item(item: GameItem) -> void:
	var item_id = item.id
	if GameManager.game_state.items.has(item_id):
		var item_list = GameManager.game_state.items[item_id]
		item_list.erase(item)
		if item_list.is_empty():
			GameManager.game_state.items.erase(item_id)
	var real_data = item.get_real_data()
	if real_data and "perishable" in real_data and real_data.perishable is RPGPerishable:
		var obj: RPGPerishable = real_data.perishable
		if obj.action == 1 and obj.conversion_item_id > 0:
			add_item_amount(real_data.perishable.conversion_item_id, 1)


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
	var current_total_quantity = 0
	
	if collection.has(id):
		for item in collection[id]:
			current_total_quantity += item.quantity
			
	var remaining_amount = amount
	
	if "max_quantity" in real_item and real_item.max_quantity > 0:
		var space_left = real_item.max_quantity - current_total_quantity
		if space_left <= 0:
			return 0
		if remaining_amount > space_left:
			remaining_amount = space_left
			
	var added_amount = 0
	var current_time = int(Time.get_unix_time_from_system())
	
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
		elif item_type == 3:
			compatible = not item.get("equipped")
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
			item.newly_added = true
			if "last_added_date" in item:
				item.last_added_date = current_time
			
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
					game_item.newly_added = true
					if "last_added_date" in game_item:
						game_item.last_added_date = current_time
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
						game_item.newly_added = true
						if "last_added_date" in game_item:
							game_item.last_added_date = current_time
						item_list.append(game_item)
						added_amount += 1
			elif item_type == 3:
				var game_item = IngameCostume.new()
				game_item.id = id
				game_item.quantity = stack_amount
				game_item.type = 0 # 0 para IngameCostume según tu clase
				game_item.newly_added = true
				if "last_added_date" in game_item:
					game_item.last_added_date = current_time
				item_list.append(game_item)
				added_amount += stack_amount
			else:
				if real_item.upgrades.max_levels == 1:
					var game_item
					if item_type == 1:
						game_item = GameWeapon.new(id, stack_amount, 1)
					else:
						game_item = GameArmor.new(id, stack_amount, 2)
					game_item.current_level = max(1, min(level, real_item.upgrades.max_levels))
					game_item.newly_added = true
					if "last_added_date" in game_item:
						game_item.last_added_date = current_time
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
						game_item.newly_added = true
						if "last_added_date" in game_item:
							game_item.last_added_date = current_time
						item_list.append(game_item)
						added_amount += 1
						
	sync_perishable_items()
	
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
	
	sync_perishable_items()


func clean_inventory_pending_stacks() -> void:
	for bag in active_overflow_bags:
		if is_instance_valid(bag):
			bag.queue_free()
			
	active_overflow_bags.clear()
	interacting_bag = null


## Sort modes: 0 = Smart/Default, 1 = A-Z, 2 = Z-A, 3 = Usable first + A-Z, 4 = Rarity + A-Z, 5 = Quantity + A-Z
## collection: 0 = items + weapons + armors + sets, 1 = items, 2 = weapons, 3 = armors, 4 = sets, 5 = key items
func get_items(include_hidden_items: bool = false, sort_mode: int = 0, collection: int = 0) -> Array:
	var items: Array = []
	if GameManager.game_state:
		var raw_items: Array = []
		var state = GameManager.game_state
		match collection:
			0:
				raw_items.append_array(_extract_items_from_dict(state.items))
				raw_items.append_array(_extract_items_from_dict(state.weapons))
				raw_items.append_array(_extract_items_from_dict(state.armors))
				raw_items.append_array(_extract_items_from_dict(state.sets))
			2:
				raw_items.append_array(_extract_items_from_dict(state.weapons))
			3:
				raw_items.append_array(_extract_items_from_dict(state.armors))
			4:
				raw_items.append_array(_extract_items_from_dict(state.sets))
			_:
				raw_items.append_array(_extract_items_from_dict(state.items))
		for item in raw_items:
			var real_data = item.get_real_data()
			if not real_data or (real_data is RPGItem and real_data.item_category > 1 and not include_hidden_items) or (real_data is RPGItem and real_data.item_category != 1 and collection == 5):
				continue
			var item_type: int = 0
			if item is GameWeapon:
				item_type = 1
			elif item is GameArmor:
				item_type = 2
			elif item is IngameCostume or item is IngameGearSet:
				item_type = 3
			elif real_data is RPGItem and real_data.item_category == 1:
				item_type = 4
			var level = -1 if not "current_level" in item else item.current_level
			var equipped = " E" if "equipped" in item and item.equipped else ""
			var is_disabled = not _is_item_usable_in_menu(real_data) or (not equipped.is_empty() and not item is GameItem)
			var is_perish = false
			var life = 0.0
			var max_life = 0.0
			if real_data is RPGItem and real_data.perishable.is_perishable:
				is_perish = true
				life = item.lifetime
				max_life = real_data.perishable.duration
			var item_qty = 1 if is_perish else item.quantity
			var dict_item = {
				"item": item,
				"real_item": real_data,
				"name": real_data.name + (" ⬥" + str(level) if level != -1 else "") + equipped,
				"icon": real_data.icon,
				"item_color": _get_item_color_for_item(real_data),
				"quantity": item_qty,
				"item_type": item_type,
				"item_id": item.id,
				"is_disabled": is_disabled,
				"is_new": item.newly_added,
				"date_added": item.last_added_date,
				"is_perishable": is_perish,
				"lifetime": life,
				"max_lifetime": max_life,
				"mp_cost": real_data.mp_cost if "mp_cost" in real_data else 0,
				"description": real_data.description
			}
			if real_data is RPGItem:
				var scope: RPGScope = real_data.scope
				var target_id = SCOPE.ONE if scope.number == 0 \
					else SCOPE.ALL if scope.number == 1 \
					else SCOPE.RANDOM
				var targets_amount = scope.random
				dict_item["target_id"] = target_id
				dict_item["targets_amount"] = targets_amount
				
			items.append(dict_item)
	var sort_func: Callable
	match sort_mode:
		1:
			sort_func = func(a, b): return a.name.nocasecmp_to(b.name) < 0
		2:
			sort_func = func(a, b): return a.name.nocasecmp_to(b.name) > 0
		3:
			sort_func = func(a, b):
				if a.is_disabled != b.is_disabled: return not a.is_disabled
				return a.name.nocasecmp_to(b.name) < 0
		4:
			sort_func = func(a, b):
				var rar_a = a.real_item.rarity_type if a.real_item else 0
				var rar_b = b.real_item.rarity_type if b.real_item else 0
				if rar_a != rar_b: return rar_a > rar_b
				return a.name.nocasecmp_to(b.name) < 0
		5:
			sort_func = func(a, b):
				if a.quantity != b.quantity: return a.quantity > b.quantity
				return a.name.nocasecmp_to(b.name) < 0
		0, _:
			sort_func = func(a, b):
				# 1. Top Priority: New Items
				if a.is_new != b.is_new: return a.is_new
				if a.is_new and b.is_new and a.date_added != b.date_added: return a.date_added > b.date_added
				
				# 2. Secondary Priority: The Last Item Selected
				if has_new_items_pending_view:
					var last_item = GameManager.game_state.last_item_used
					if not last_item.is_empty():
						var a_is_last = (a.item_id == last_item.get("id", -1) and a.item_type == last_item.get("type", -1))
						var b_is_last = (b.item_id == last_item.get("id", -1) and b.item_type == last_item.get("type", -1))
						if a_is_last != b_is_last: return a_is_last
				
				# 3. Tertiary Priority: Usability First
				if a.is_disabled != b.is_disabled: return not a.is_disabled
				
				# 4.  Sort Order: Alphabetical
				return a.name.nocasecmp_to(b.name) < 0
	items.sort_custom(sort_func)
	return items


func _get_item_color_for_item(item: Variant) -> Color:
	var color = Color.WHITE
	
	if item is RPGItem:
		color = RPGSYSTEM.database.types.get_item_color("item", item.rarity_type)
	elif item is RPGWeapon:
		color = RPGSYSTEM.database.types.get_item_color("weapon", item.rarity_type)
	elif item is RPGArmor:
		color = RPGSYSTEM.database.types.get_item_color("armor", item.rarity_type)
	
	return color
	


## Determines if an item can be used directly from the menu screen.
func _is_item_usable_in_menu(item_data: Variant) -> bool:
	if not item_data is RPGItem:
		return true

	var occasion = item_data.occasion
	if occasion == RPGActionManager.Ocassion.ALWAYS or occasion ==  RPGActionManager.Ocassion.MENU_SCREEN or (GameManager.is_on_battle and occasion ==  RPGActionManager.Ocassion.BATTLE_SCREEN):
		if not GameManager.is_on_battle:
			if item_data.scope.faction == RPGActionManager.ScopeSide.ALLY or item_data.scope.faction == RPGActionManager.ScopeSide.ENEMY_AND_ALLY:
				return true
		else:
			return true

	return false


## Helper to extract valid items (quantity > 0) from a state dictionary.
func _extract_items_from_dict(source_dict: Dictionary) -> Array:
	var result: Array = []
	for item_arr in source_dict.values():
		for item in item_arr:
			if item.quantity > 0:
				result.append(item)
	return result


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
		
		has_new_items_pending_view = true
	
	if added != amount:
		_handle_overflow(0, id, amount - added, 0, auto_popup_enabled, popup_prefix)
		
	if is_instance_valid(QuestManager):
		QuestManager.notify_inventory_changed()
	
	return added


func remove_item_amount(id: int, amount: int) -> void:
	_remove_generic_amount(GameManager.game_state.items, id, amount, false, true)
	if is_instance_valid(QuestManager):
		QuestManager.notify_inventory_changed()


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
		
		has_new_items_pending_view = true
	
	if added != amount:
		_handle_overflow(1, id, amount - added, level, auto_popup_enabled, popup_prefix)
		
	if is_instance_valid(QuestManager):
		QuestManager.notify_inventory_changed()
	
	return added


func remove_weapon_amount(id: int, amount: int, include_equipment: bool) -> void:
	_remove_generic_amount(GameManager.game_state.weapons, id, amount, include_equipment, false)
	if is_instance_valid(QuestManager):
		QuestManager.notify_inventory_changed()


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
		
		has_new_items_pending_view = true
	
	if added != amount:
		_handle_overflow(2, id, amount - added, level, auto_popup_enabled, popup_prefix)
		
	if is_instance_valid(QuestManager):
		QuestManager.notify_inventory_changed()
	
	return added


func remove_armor_amount(id: int, amount: int, include_equipment: bool) -> void:
	_remove_generic_amount(GameManager.game_state.armors, id, amount, include_equipment, false)
	if is_instance_valid(QuestManager):
		QuestManager.notify_inventory_changed()


func get_costume_amount(id: int) -> int:
	var quantity: int = 0
	if GameManager.game_state.sets.has(id):
		for item in GameManager.game_state.sets[id]:
			quantity += item.quantity
			
	return quantity


func add_costume_amount(id: int, amount: int, auto_popup_enabled: bool = false, popup_prefix: String = "") -> int:
	var added = _add_generic_amount(GameManager.game_state.sets, RPGSYSTEM.database.costumes, id, amount, 1, 3)
	
	if added > 0:
		if auto_popup_enabled or RPGSYSTEM.database.system.options.get("auto_popup_on_pick_up_items", false):
			GameManager.call_deferred("_create_popup_message", 3, id, added, popup_prefix)
			
		var item_id = "3" + "_" + str(id)
		if not item_id in GameManager.game_state.stats.items_found:
			GameManager.game_state.stats.items_found[item_id] = 0
		GameManager.game_state.stats.items_found[item_id] += added
		
		has_new_items_pending_view = true
		
	if added != amount:
		_handle_overflow(3, id, amount - added, 1, auto_popup_enabled, popup_prefix)
		
	if is_instance_valid(QuestManager):
		QuestManager.notify_inventory_changed()
		
	return added


func remove_costume_amount(id: int, amount: int, include_equipment: bool) -> void:
	_remove_generic_amount(GameManager.game_state.sets, id, amount, include_equipment, false)
	if is_instance_valid(QuestManager):
		QuestManager.notify_inventory_changed()
