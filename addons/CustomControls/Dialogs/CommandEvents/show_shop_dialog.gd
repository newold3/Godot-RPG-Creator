@tool
extends CommandBaseDialog

const SHOP_PANEL = preload("res://addons/CustomControls/shop_panel.tscn")

var sub_parameter_code: int = 97


@onready var item_container: VBoxContainer = %itemContainer


func _ready() -> void:
	super()
	parameter_code = 36
	%SalesRatio.get_line_edit().set_expand_to_text_length_enabled(true)
	%PurchaseRatio.get_line_edit().set_expand_to_text_length_enabled(true)


func set_parameters(_parameters: Array[RPGEventCommand]) -> void:
	parameters = []
	for param in _parameters:
		parameters.append(param.clone(true))

	set_data()


func set_data() -> void:
	var bak = min_size
	min_size = size
	for child in item_container.get_children():
		child.queue_free()
	
	if "sales_mode" in parameters[0].parameters:
		var index = clamp(parameters[0].parameters.sales_mode, 0, %SalesMode.get_item_count() - 1)
		%SalesMode.select(index)
	else:
		parameters[0].parameters.sales_mode = 0
		%SalesMode.select(0)
	
	if "purchase_ratio" in parameters[0].parameters:
		var ratio = parameters[0].parameters.purchase_ratio
		%PurchaseRatio.value = ratio
	else:
		parameters[0].parameters.purchase_ratio = 100
		%PurchaseRatio.value = 100
	
	if "sales_ratio" in parameters[0].parameters:
		var ratio = parameters[0].parameters.sales_ratio
		%SalesRatio.value = ratio
	else:
		parameters[0].parameters.sales_ratio = 30
		%SalesRatio.value = 30
	
	if not "buy_list" in parameters[0].parameters:
		parameters[0].parameters.buy_list = []
	
	# create items panels:
	for i in range(1, parameters.size(), 1):
		var panel = SHOP_PANEL.instantiate()
		item_container.add_child(panel)
		var panel_command = parameters[i]
		panel.set_data(panel_command.parameters)
		panel.remove_panel_request.connect(_remove_panel)
		panel.move_down_request.connect(_change_panel_order.bind(1))
		panel.move_up_request.connect(_change_panel_order.bind(-1))
	
	%ChooseItems.visible = parameters[0].parameters.sales_mode == 5
	%SalesRatioLabel.visible = parameters[0].parameters.sales_mode != 1
	%SalesRatio.visible = parameters[0].parameters.sales_mode != 1
	
	if not "shop_name" in parameters[0].parameters:
		parameters[0].parameters.shop_name = tr("SHOP")
		
	%ShopName.text = parameters[0].parameters.get("shop_name", "")
	
	if not "shop_scene" in parameters[0].parameters:
		parameters[0].parameters.shop_scene = "res://Scenes/ShopScene/scene_shop_1.tscn"
	
	var path = parameters[0].parameters.shop_scene.get_file()
	%DialogScene.text = path
	
	if not "shop_keeper" in parameters[0].parameters:
		parameters[0].parameters.shop_keeper = "res://Assets/Images/SceneShop/base_shopkeeper.png"
	
	path = parameters[0].parameters.shop_keeper.get_file()
	%ShopKeeper.text = path
	
	%CanRestock.set_pressed(parameters[0].parameters.get("can_restock", true))
	var restock_timer: int = int(parameters[0].parameters.get("restock_timer", 300))
	var hours: int = restock_timer / 3600
	var mminutes: int = (restock_timer % 3600) / 60
	var seconds: int = restock_timer % 60
	%RestockTimeHours.value = hours
	%RestockTimeMinutes.value = mminutes
	%RestockTimeSeconds.value = seconds
	
	min_size = bak


func _change_panel_order(index: int, direction: int) -> void:
	var node = %itemContainer.get_child(index)
	%itemContainer.move_child(node, index + direction)
	var idx1 = index + 1
	var idx2 = index + 1 + direction
	var bak = parameters[idx2]
	parameters[idx2] = parameters[idx1]
	parameters[idx1] = bak
	node.select()


func _remove_panel(panel: ShopPanel) -> void:
	var index = panel.get_index() + 1
	parameters.remove_at(index)
	panel.queue_free()


func build_command_list() -> Array[RPGEventCommand]:
	parameters.reverse()
	return parameters


func _on_add_new_item_pressed(item_type: int = 0, item_id: int = 1) -> void:
	# Create sub-command
	var command = RPGEventCommand.new()
	command.code = sub_parameter_code
	command.indent = parameters[0].indent
	command.parameters.type = item_type
	command.parameters.item_id = item_id
	command.parameters.quantity = 0
	command.parameters.price_mode = 0
	command.parameters.price = 0
	
	parameters.append(command)
	
	# Create panel
	var panel = SHOP_PANEL.instantiate()
	item_container.add_child(panel)
	panel.set_data(command.parameters)
	panel.remove_panel_request.connect(_remove_panel)
	panel.move_down_request.connect(_change_panel_order.bind(1))
	panel.move_up_request.connect(_change_panel_order.bind(-1))
	panel.select()


func _on_sales_mode_item_selected(index: int) -> void:
	parameters[0].parameters.sales_mode = index
	%ChooseItems.visible = index == 5
	%SalesRatioLabel.visible = index != 1
	%SalesRatio.visible = index != 1


func _on_sales_ratio_value_changed(value: float) -> void:
	parameters[0].parameters.sales_ratio = value


func _on_choose_items_pressed() -> void:
	var path = "res://addons/CustomControls/Dialogs/select_items_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)

	dialog.set_data(parameters[0].parameters.buy_list)
	dialog.changed.connect(func(buy_list: Array): parameters[0].parameters.buy_list = buy_list)


func _on_add_multiple_items_pressed() -> void:
	var path = "res://addons/CustomControls/Dialogs/select_items_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)

	dialog.set_data([])
	
	dialog.changed.connect(
		func(buy_list: Array):
			for item in buy_list:
				_on_add_new_item_pressed(item.type, item.id)
	)


func _on_purchase_ratio_value_changed(value: float) -> void:
	parameters[0].parameters.purchase_ratio = value


func _on_remove_duplicates_pressed() -> void:
	var clean_commands = []
	var item_dict = {}
	
	var s = size - Vector2i(20, 0)
	
	# Primero agrupamos por type e item_id
	for cmd in parameters:
		if cmd.code == 96: continue
		var params = cmd.parameters
		var type = params.type
		var item_id = params.item_id
		var quantity = params.quantity
		var price_mode = params.price_mode
		var price = params.price
		var level = params.get("level", -1)
		
		var key = str(type) + "_" + str(item_id) + "_" + str(level)
		
		if not item_dict.has(key):
			# Primera vez que vemos este item
			item_dict[key] = {
				"type": type,
				"item_id": item_id,
				"quantity": quantity,
				"price_mode": price_mode,
				"price": price,
				"level": level
			}
		else:
			# Item duplicado, aplicamos reglas de fusión
			var existing = item_dict[key]
			
			# Usamos la cantidad mayor
			existing["quantity"] = max(existing["quantity"], quantity)
			
			# Si alguno tiene price_mode 1, usamos 1
			if price_mode == 1 or existing["price_mode"] == 1:
				existing["price_mode"] = 1
				
				# Si ambos son price_mode 1, usamos el mayor precio
				if existing["price_mode"] == 1 and price_mode == 1:
					existing["price"] = max(existing["price"], price)
				# Si el nuevo es el único con price_mode 1, usamos su precio
				elif price_mode == 1:
					existing["price"] = price
	
	# Convertimos el diccionario de vuelta a la estructura de array
	for key in item_dict:
		var item = item_dict[key]
		var command = RPGEventCommand.new()
		command.code = sub_parameter_code
		command.indent = parameters[0].indent
		command.parameters.type = item["type"]
		command.parameters.item_id = item["item_id"]
		command.parameters.quantity = item["quantity"]
		command.parameters.price_mode = item["price_mode"]
		command.parameters.price = item["price"]
		if item["level"] != -1:
			command.parameters.level = item["level"]
		clean_commands.append(command)
	
	var new_parameters: Array[RPGEventCommand] = [parameters[0]]
	
	for code in clean_commands:
		new_parameters.append(code)
	
	set_parameters(new_parameters)
	
	await get_tree().process_frame
	size = s


func _on_shop_name_text_changed(new_text: String) -> void:
	parameters[0].parameters.shop_name = new_text


func _on_dialog_scene_pressed() -> void:
	var path = "res://addons/CustomControls/Dialogs/select_file_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	
	await get_tree().process_frame
	
	dialog.destroy_on_hide = true
	dialog.target_callable = _update_shop_file
	dialog.set_file_selected(parameters[0].parameters.shop_scene)
	dialog.set_dialog_mode(0)

	dialog.fill_files("shop_scene")


func _update_shop_file(path: String) -> void:
	parameters[0].parameters.shop_scene = path


func _on_shop_keeper_pressed() -> void:
	var path = "res://addons/CustomControls/Dialogs/select_file_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	dialog.destroy_on_hide = true
	await get_tree().process_frame
	
	dialog.set_dialog_mode(0)
	
	dialog.target_callable = func(path: String):
		parameters[0].parameters.shop_keeper = path
		%ShopKeeper.text = path.get_file()
	dialog.set_file_selected(parameters[0].parameters.shop_keeper)
	
	dialog.fill_files("images")


func _on_clear_all_items_pressed() -> void:
	var new_parameters: Array[RPGEventCommand] = [parameters[0]]
	set_parameters(new_parameters)


func _on_can_restock_toggled(toggled_on: bool) -> void:
	parameters[0].parameters.can_restock = toggled_on
	%RestockTimerContainer.propagate_call("set_disabled",  [!toggled_on])


func _change_restock_timer(value: float) -> void:
	value = %RestockTimeHours.value * 3600 + %RestockTimeMinutes.value * 60 + %RestockTimeSeconds.value
	parameters[0].parameters.restock_timer = value
