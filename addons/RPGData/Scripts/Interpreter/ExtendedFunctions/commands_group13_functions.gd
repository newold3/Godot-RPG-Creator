class_name CommandsGroup13
extends CommandHandlerBase


#region Shop Helpers
var items_db: Array[RPGItem]
var weapons_db: Array[RPGWeapon]
var armors_db: Array[RPGArmor]


func _format_shop_item(item: Dictionary, purchase_ratio: int) -> Dictionary:
	# Validate general type and ID range
	if item.type not in [0, 1, 2] or item.id <= 0:
		return {}
	
	var db
	match item.type:
		0:
			db = items_db
		1:
			db = weapons_db
		2:
			db = armors_db

	if item.id >= db.size():
		debug_print("Format item error: item id out of range: %s" % item)
		return {}  # ID out of range
	
	var data = db[item.id]
	
	var source = item.get("source", "stock")
	
	# For Normal Items (type 0), only those with item_type == 0 can be sold
	if item.type == 0 and data.item_type != 0 and source != "stock":
		debug_print("Format item error: Only normal items can be sold <%s>" % item)
		return {}

	var item_data = {
		"index": item.index,
		"id": item.id,
		"type": item.type,
		"quantity": item.quantity,
		"max_quantity": item.max_quantity,
		"level": item.level,
		"source": source,
		"price": 0,  # will be calculated below
		"rarity": data.rarity_type,
		"icon": data.icon,
		"name": data.name,
		"description": data.description,
		"restock_amount": item.get("restock_amount", -1)
	}
	
	# Determine category based on item type
	match item.type:
		0:
			var data_types = RPGSYSTEM.database.types.item_types
			if data_types.size() > data.item_category:
				item_data.category = data_types[data.item_category]
			else:
				item_data.category = ""
		1:
			var weapon_type = data.weapon_type - 1
			var data_types = RPGSYSTEM.database.types.weapon_types
			if data_types.size() > weapon_type and weapon_type > -1:
				item_data.category = data_types[weapon_type]
			else:
				item_data.category = "___none___"
		2:
			var armor_type = data.armor_type - 1
			var equipment_type = data.equipment_type
			var data_types = RPGSYSTEM.database.types.armor_types
			var data_equipment_types = RPGSYSTEM.database.types.equipment_types
			if data_types.size() > armor_type and armor_type > -1:
				if data_equipment_types.size() > equipment_type and equipment_type > -1:
					item_data.category = data_types[armor_type] + " - " + data_equipment_types[equipment_type]
				else:
					item_data.category = data_types[armor_type]
			else:
				item_data.category = "___none___"
	
	# Calculate base price
	var base_price = item.price if item.get("price_mode", 0) == 1 else data.price
	
	# Apply upgrade price increments if upgrades exist
	if "upgrades" in data and "level" in item_data and item_data.level > 1:
		for i in range(item_data.level):
			var upgrades = data.upgrades
			if upgrades.levels.size() > i:
				var upgrade = upgrades.levels[i]
				base_price += int(base_price * upgrade.price_increment * 0.01)
	
	item_data.price = int(base_price * purchase_ratio * 0.01)
	
	return item_data


func _allowed_items_array_to_dic(allowed_items: Array = []) -> Dictionary:
	var d = {}
	for item in allowed_items:
		var key = str(item.type) + "_" + str(item.id)
		d[key] = true
	return d


func _add_item_list(config: Dictionary, sales_ratio: int, include_equipped: bool, list: Array, allowed_items: Array) -> void:
	var has_filter = not allowed_items.is_empty()
	var filter = {} if allowed_items.is_empty() else _allowed_items_array_to_dic(allowed_items)
	
	for i: int in list.size():
		var item_arr: Array = list[i]
		if item_arr.is_empty(): continue
		var first_item: Variant = item_arr[0]
		if has_filter:
			var key = str(first_item.type) + "_" + str(first_item.id)
			if not key in filter: continue
		for item: Variant in item_arr:
			if item.type != 0 and not include_equipped and item.equipped: continue
			# Use database position (i) for generic lists, pass counter from config
			_add_inventory_item_to_config(i, config, item, sales_ratio, i)


func _add_items_in_inventory(config: Dictionary, sales_ratio: int, allowed_items: Array = []) -> void:
	_add_item_list(config, sales_ratio, true, GameManager.game_state.items.values(), allowed_items)


func _add_weapons_in_inventory(config: Dictionary, sales_ratio: int, include_equipped: bool = true, allowed_items: Array = []) -> void:
	_add_item_list(config, sales_ratio, include_equipped, GameManager.game_state.weapons.values(), allowed_items)


func _add_armors_in_inventory(config: Dictionary, sales_ratio: int, include_equipped: bool = true, allowed_items: Array = []) -> void:
	_add_item_list(config, sales_ratio, include_equipped, GameManager.game_state.armors.values(), allowed_items)


func _add_all_inventory_items(config: Dictionary, sales_ratio: int) -> void:
	_add_items_in_inventory(config, sales_ratio)
	_add_weapons_in_inventory(config, sales_ratio, false)
	_add_armors_in_inventory(config, sales_ratio, false)


func _add_specific_inventory_items(config: Dictionary, sales_ratio: int, allowed_items: Array) -> void:
	_add_items_in_inventory(config, sales_ratio, allowed_items)
	_add_weapons_in_inventory(config, sales_ratio, false, allowed_items)
	_add_armors_in_inventory(config, sales_ratio, false, allowed_items)
	
	var added_items = {}
	for item in config.items:
		if item.source == "inventory":
			# Prevents the item from being deleted from the sales inventory when it is sold.
			item.fixed = true
			var key = str(item.type) + "_" + str(item.id)
			added_items[key] = true
	
	for i in range(allowed_items.size()):
		var allowed_item = allowed_items[i]
		var key = str(allowed_item.type) + "_" + str(allowed_item.id)
		if not key in added_items:
			var formatted_item = _format_shop_item({
				"index": config.items.size(),
				"id": allowed_item.id,
				"type": allowed_item.type,
				"price_mode": 0,
				"price": 0,
				"quantity": 0,
				"max_quantity": 0,
				"level": 1,
				"source": "inventory"
			}, sales_ratio)

			if not formatted_item.is_empty():
				# Initialize counter if not exists
				if not "item_counter" in config:
					config.item_counter = 0
				
				# Show the item as unavailable in the sales store.
				formatted_item.empty_item = true
				# Generate SELL uniq_id format: S_allowed_list_position_type_id_counter
				# For specific items, use position in allowed_items list
				formatted_item.uniq_id = "S_" + str(i) + "_" + str(allowed_item.type) + "_" + str(allowed_item.id) + "_" + str(config.item_counter)
				config.item_counter += 1
				config.items.append(formatted_item)


func _add_inventory_item_to_config(item_index: int, config: Dictionary, inventory_item: Variant, sales_ratio: int, db_position: int = -1) -> void:
	var formatted_item = _format_shop_item({
		"index": item_index,
		"id": inventory_item.id,
		"type": inventory_item.type,
		"price_mode": 0,
		"price": 0,
		"quantity": inventory_item.quantity,
		"max_quantity": inventory_item.quantity,
		"level": (1 if not "current_level" in inventory_item else inventory_item.current_level),
		"source": "inventory"
	}, sales_ratio)

	if not formatted_item.is_empty():
		# Initialize counter if not exists
		if not "item_counter" in config:
			config.item_counter = 0
		
		# Generate SELL uniq_id format: S_db_position_type_id_counter
		# Use database position (item_index) for the position in BD
		var position = db_position if db_position != -1 else item_index
		formatted_item.uniq_id = "S_" + str(position) + "_" + str(inventory_item.type) + "_" + str(inventory_item.id) + "_" + str(config.item_counter)
		config.item_counter += 1
		config.items.append(formatted_item)
#endregion


func add_buy_items(shop_id: String, config: Dictionary, items: Array, can_restock: bool, restock_timer: int, purchase_ratio: int) -> void:
	for i in items.size():
		var item = items[i]
		var item_id = item.get("item_id", 1)
		var item_type = item.get("type", 0)
		var quantity: int
		var max_quantity = item.get("quantity", 0)
		if not shop_id.is_empty() and shop_id in GameManager.game_state.active_shop_timers:
			var item_stock_id = "%s_%s_%s" % [item_type, item_id, i]
			var shop_timer: RPGShopTimer = GameManager.game_state.active_shop_timers[shop_id]
			var current_shop_item: RPGShopItemStock = shop_timer.current_stock.get(item_stock_id)
			if current_shop_item:
				quantity = current_shop_item.current_stock
			else:
				quantity = item.get("quantity", 0)
		else:
			quantity = item.get("quantity", 0)
			
		if can_restock and restock_timer == 0:
			max_quantity = 0
			quantity = 0
			
		var formatted_item = _format_shop_item({
			"index": i,
			"id": item_id,
			"type": item_type,
			"price_mode": item.get("price_mode", 0),
			"price": item.get("price", 0),
			"quantity": quantity,
			"max_quantity": max_quantity,
			"level": item.get("level", 1),
			"restock_amount": item.get("restock_amount", -1)
		}, purchase_ratio)
		if not formatted_item.is_empty():
			# Initialize counter if not exists
			if not "item_counter" in config:
				config.item_counter = 0
			
			# Generate BUY uniq_id format: B_position_type_id_counter
			formatted_item.uniq_id = "B_" + str(i) + "_" + str(item_type) + "_" + str(item_id) + "_" + str(config.item_counter)
			config.item_counter += 1
			formatted_item.max_quantity =  max_quantity
			config.items.append(formatted_item)


func add_sell_items(config: Dictionary, sales_mode: int, sales_ratio: int, include_equipped: bool, buy_list: Array) -> void:
	match sales_mode:
		0:  # Allows Selling Everything
			_add_all_inventory_items(config, sales_ratio)
			config.sell_mode = "all"
		1:  # Does Not Allow Selling Anything
			# Do not add anything from inventory
			config.sell_mode = "nothing"
		2:  # Allows Selling Items
			_add_items_in_inventory(config, sales_ratio)
			config.sell_mode = "items"
		3:  # Allows Selling Weapons
			_add_weapons_in_inventory(config, sales_ratio, false)
			config.sell_mode = "weapons"
		4:  # Allows Selling Armor
			_add_armors_in_inventory(config, sales_ratio, false)
			config.sell_mode = "armors"
		5:  # Allows Selling Specific Objects
			_add_specific_inventory_items(config, sales_ratio, buy_list)
			config.sell_mode = "specific_items"


# Command Show Shop (Codes 96, 97), button_id = 76
# Code 96 parameters { sales_mode, purchase_ratio, sales_ratio, shop_name, shop_scene, shop_keeper, sold_items }
# Code 97 parameters { type, item_id, quantity, price_mode, price }
func _command_0096() -> void:
	debug_print("Processing command: Show Shop (code 96)")
	
	# cache database:
	if not items_db:
		items_db = RPGSYSTEM.database.items
		weapons_db = RPGSYSTEM.database.weapons
		armors_db = RPGSYSTEM.database.armors
	
	# Prepare shop config
	var purchase_ratio = current_command.parameters.get("purchase_ratio", 100)
	var sales_mode = current_command.parameters.get("sales_mode", 0)
	var sales_ratio = current_command.parameters.get("sales_ratio", 30)
	var shop_keeper = current_command.parameters.get("shop_keeper", "res://Assets/Images/SceneShop/base_shopkeeper.png")
	var shop_name = current_command.parameters.get("shop_name", tr("SHOP"))
	var buy_list = current_command.parameters.get("buy_list", [])
	var can_restock = current_command.parameters.get("can_restock", false)
	var restock_timer = current_command.parameters.get("restock_timer", 300)
	
	var shop_scene =  current_command.parameters.get("shop_scene", "")
	if not ResourceLoader.exists(shop_scene) or not GameManager.get_main_scene():
		debug_print("Shop Scene is invalid \"%s\"" % shop_scene)
		return
	
	var current_index = current_interpreter.command_index + 1
	var items = []
	
	# Collect all itens of shop items (Code 97) until an invalid command is encountered
	while true:
		var command = current_interpreter.get_command(current_index)
		if command:
			if command.code == 97:  # Shop Item
				items.append(command.parameters)
			else:  # Invalid command
				break
		else:
			break
		
		current_index += 1
	
	if items.is_empty() and sales_mode == 1:
		debug_print("The store has no items added for purchase and does not allow any items to be sold. This command will be ignored.")
		return

	# Adjust the interpreter to the last valid command index
	current_interpreter.go_to(current_index - 1)
	
	var ins = await GameManager.get_scene_from_cache("shops", shop_scene, "GeneralShopScene")
	if not ins:
		debug_print("Shop Scene is invalid \"%s\"" % shop_scene)
		return
	
	# Set shop id used in restock system
	var shop_id: String = ""
	if "shop_id" in ins and GameManager.current_map:
		var page_id: int = -1
		var event_id: int = -1
		if current_interpreter.obj:
			if "current_event_page" in current_interpreter.obj and current_interpreter.obj.current_event_page is RPGEventPage:
				page_id = current_interpreter.obj.current_event_page.id
			if "current_event" in current_interpreter.obj and current_interpreter.obj.current_event is RPGEvent:
				event_id = current_interpreter.obj.current_event.id
		if page_id != -1 and event_id != -1:
			shop_id = "[%s-%s-%s-%s]" % [
				GameManager.current_map.internal_id,
				page_id,
				event_id,
				current_interpreter.command_index
			]
			ins.shop_id = shop_id
	
	var config = {
		"purchase_ratio": purchase_ratio,
		"sales_mode": sales_mode,
		"buy_list": buy_list,
		"sales_ratio": sales_ratio,
		"shop_keeper": shop_keeper,
		"shop_name": shop_name,
		"can_restock": can_restock,
		"restock_timer": restock_timer,
		"item_counter": 0  # Initialize counter for unique IDs
	}
	
	# Add buy item list
	config.items = []
	add_buy_items(shop_id, config, items, can_restock, restock_timer, purchase_ratio)
	
	# Add sell list using sales_mode
	add_sell_items(config, sales_mode, sales_ratio, false, buy_list)
	
	GameManager.setup_gui_scene(ins)
	ins.set_config(config)
	ins.restock_buy_list = add_buy_items.bind(shop_id, config, items, can_restock, restock_timer, purchase_ratio)
	ins.restock_sell_list = add_sell_items.bind(config, sales_mode, sales_ratio, false, buy_list)
	ins.start()
	await ins.tree_exited


# Command Open Blacksmith Shop (Code 200), button_id = 118
# Code 200 parameters { }
func _command_0200() -> void:
	debug_print("Command 200 is not implemented")


# Command Open Class Upgrade Shop (Code 201), button_id = 119
# Code 201 parameters { }
func _command_0201() -> void:
	debug_print("Command 201 is not implemented")
