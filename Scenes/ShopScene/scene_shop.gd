@tool
extends Control

@export_enum("Instant", "Move from Left", "Move from right", "Move from top", "Move from bottom") var start_animation: int = 1
@export_enum("Instant", "Fade Out", "Move to Left", "Move to right", "Move to top", "Move to bottom") var end_animation: int = 3

@export var earn_money_color: Color = Color("43793f")
@export var spend_money_color: Color = Color("c6003f")
@export var preview_equipment_animation_curve: Curve

enum Manipulators {shop_item_panel, shop_filter_tabs, shop_main_tabs, shop_page_buttons, shop_confirm_message, confirm_transaction}

func get_class() -> String:
	return "GeneralShopScene"


enum ShopMode { BUY, SELL }
enum ShopContainers { TOP, CATEGORIES, PANELS, BUTTONS_PNAEL, NAVIGATION, TRANSCATION}

var shop_id: String = ""

var batch_size: int = 10 # load items in batch
var items: Dictionary
var categories: Array
var current_enabled_controls_parent: Node
var busy: bool = false
var busy2: bool = false

var current_page: int = 0
var current_pages: int = 0
var max_items_by_page: int = 10
var current_page_item: int = 0
var current_buy_filter = 0
var current_sell_filter = 0
var current_category_selected: String

var queue_items_to_show: Array
var current_from_item_index: int = 0
var current_to_item_index: int = 0

var current_container: ShopContainers = ShopContainers.PANELS

var current_mode: ShopMode = ShopMode.BUY

var animation_tween: Tween

var config: Dictionary

var items_in_cache: Dictionary = {}

var transaction_list: Dictionary = {}
var target_transaction_amount: float = 0
var current_transaction_amount: float = 0

var transaction_tween: Tween
var transaction_button_tween: Tween
var current_gold_tween: Tween

var initialized: bool = true
var is_enabled: bool = false
var exiting_enabled: bool = false
var transaction_confirm_enabled: bool = false

static var current_quantity_step: int = 1
var current_quantity_text: String

var can_restock: bool = false
var restock_max_time: int = 0 # time in seconds
var current_restock_timer: float = 0
var restock_timer_enabled: bool = false
var reselect_enabled: bool # Allow reselect main tabs (buy/sell)

var last_buy_panel_selected: PanelContainer
var last_sell_panel_selected: PanelContainer

var equipment_preview_tween: Tween

var restock_buy_list: Callable # Interpreter function to fill in the list of items sold
var restock_sell_list: Callable # Interpreter function to fill in the list of purchased items

var ITEM_PANEL = preload("res://Scenes/ShopScene/item_panel.tscn")

@onready var tabs: CustomTabsControl = %Tabs
@onready var filter_tabs: HBoxContainer = %TabsWithScroll
@onready var item_container: GridContainer = %ItemContainer
@onready var current_gold_transation: Label = %CurrentGoldTransation
@onready var transaction_container: MarginContainer = %TransactionContainer
@onready var complete_transaction: Button = %CompleteTransaction
@onready var transaction_confirm: Control = %TransactionConfirm
@onready var cancel_confirm_message: Control = %CancelConfirmMessage
@onready var bottom_help: Label = %BottomHelp
@onready var shop_navigation_container: VBoxContainer = %ShopNavigationContainer
@onready var move_page_to_left: TextureButton = %MovePageToLeft
@onready var move_page_to_right: TextureButton = %MovePageToRight
@onready var current_quantity: Label = %CurrentQuantity
@onready var sold_out_container: Control = %SoldOutContainer
@onready var inventory_empty_container: Control = %InventoryEmptyContainer
@onready var equipment_preview: PanelContainer = %EquipmentPreview


signal shop_initialized()


func _ready() -> void:
	if not Engine.is_editor_hint():
		call_deferred("_setup_all")


func _setup_all() -> void:
	filter_tabs.tabs_focused.connect(_config_hand_in_filter_tabs)
	ControllerManager.clear()
	ControllerManager.controller_changed.connect(_update_bottom_help_text)
	GameManager.set_text_config(self, false)
	_update_bottom_help_text(ControllerManager.current_controller)
	_set_initial_gold()
	_update_quantity_label()
	shop_initialized.emit()


func set_config(p_config: Dictionary) -> void:
	if is_queued_for_deletion() or tabs == null: return
	
	var terms: RPGTerms = RPGSYSTEM.database.terms
	
	var t1 = terms.get_message("Shop Buy")
	var t2 = terms.get_message("Shop Sell")
	var t3 = terms.get_message("Shop Cancel")
	tabs.set_tab_names([t1, t2, t3])
	
	complete_transaction.text = terms.get_message("Shop Complete Transaction")
	
	items = {}
	config = p_config
	%ShopNameLabel.text = config.get("shop_name", terms.get_message("Shop Default Title"))
	if ResourceLoader.exists(config.shop_keeper):
		var shop_keeper_texture: Texture = load(config.shop_keeper)
		$ShopKeeper.texture = shop_keeper_texture
	
	current_quantity_text = terms.get_message("Shop Quantity text")
	
	_update_quantity_label()
	
	_create_panels()
	
	can_restock = config.get("can_restock", false)
	restock_max_time = config.get("restock_timer", 0)
	
	%ResctockContainer.visible = false
	if not shop_id.is_empty() and can_restock and GameManager.game_state:
		# check for not unlimited items and set restock timer
		var result = _check_if_need_set_restock_timer()
		if result:
			restock_timer_enabled = true
			%ResctockContainer.visible = true
			var shop_timer: RPGShopTimer = GameManager.get_shop_timer(shop_id)
			if shop_timer:
				var elapsed_time = GameManager.game_state.stats.play_time - shop_timer.timestamp
				var completed_updates: int = elapsed_time / restock_max_time
				var time_since_last_restock = fmod(elapsed_time, restock_max_time)
				current_restock_timer = restock_max_time - time_since_last_restock
				_initial_restock(shop_timer, completed_updates)
			else:
				current_restock_timer = restock_max_time
				GameManager.add_shop_timer(shop_id, restock_max_time, _get_restock_data_from_config())

			%RestockTimer.text = tr("Restock in") + " " + GameManager.format_time(current_restock_timer)
		else:
			restock_timer_enabled = false
			can_restock = false
	
	match config.sell_mode:
		"all": %InventoryEmptyLabel.text = tr("Empty inventory")
		"nothing": %InventoryEmptyLabel.text = tr("You don't have\nanything this shop wants")
		"items": %InventoryEmptyLabel.text = tr("You don't have\nany item this shop wants")
		"weapons": %InventoryEmptyLabel.text = tr("You don't have\nany weapon this shop wants")
		"armors": %InventoryEmptyLabel.text = tr("You don't have\nany armor this shop wants")
		"specific_items": %InventoryEmptyLabel.text = tr("")


func _on_restock_timer_updated(p_shop_id: String, timer: float) -> void:
	if not shop_id.is_empty() and p_shop_id == shop_id:
		%RestockTimer.text = tr("Restock in") + " " + GameManager.format_time(timer)


func _refresh_stock(is_initial_restock: bool = false, update_count: int = 1) -> void:
	var stock_data = _get_restock_data_from_config(true)
	var items_restocked = {}
	for key in stock_data.keys():
		for item: Dictionary in config.items:
			if item.source == "stock":
				var item_id = "%s_%s_%s" % [item.type, item.id, item.index]
				if item_id == key and item.quantity != item.max_quantity:
					var item_stock: RPGShopItemStock = stock_data[key]
					var old_quantity = item.quantity
					if item_stock.restock_amount == -1:
						item.quantity = item.max_quantity
					elif item_stock.restock_amount > 0:
						var total_restock = item_stock.restock_amount * update_count
						item.quantity = min(item.quantity + total_restock, item.max_quantity)
					if old_quantity != item.quantity:
						items_restocked[item.uniq_id] = item
					break

	#  update stock in current panels
	for panel in item_container.get_children():
		var item_id = panel.current_item.uniq_id
		if item_id in items_restocked:
			if  panel.current_item.quantity != items_restocked[item_id].quantity:
				panel.current_item = items_restocked[item_id]
			if not is_initial_restock:
				panel.show_restock_animation()
		panel.update_all()

	# play fx
	if not is_initial_restock and not items_restocked.is_empty():
		GameManager.play_fx("restock")


func _initial_restock(_timer: RPGShopTimer, completed_updates: int) -> void:
	_refresh_stock(true, completed_updates)


func _get_restock_data_from_config(use_special_condition: bool = false) -> Dictionary:
	# RPGShopItemStock
	var restock_data = {}
	
	var no_unlimited_items: Array = config.items.filter(
		func(item: Dictionary):
			var c1 = item.source == "stock"
			var c2 = item.max_quantity > 0
			var c3 = item.restock_amount != 0
			var c4 = true
			if use_special_condition:
				c4 = item.quantity != item.max_quantity
			return c1 and c2 and c3 and c4
	)
	for i in no_unlimited_items.size():
		var item: Dictionary = no_unlimited_items[i]
		var shop_item_id = "%s_%s_%s" % [item.type, item.id, item.index]
		var shop_item = RPGShopItemStock.new(item.uniq_id, item.id, item.type, item.max_quantity, item.quantity, item.restock_amount)
		restock_data[shop_item_id] = shop_item
	
	# set sold out items
	var sold_out_items: Array = config.items.filter(
		func(item: Dictionary):
			var c1 = item.source == "stock"
			var c2 = item.max_quantity > 0
			var c3 = item.restock_amount == 0
			return c1 and c2 and c3
	)
	for i in sold_out_items.size():
		var item: Dictionary = sold_out_items[i]
		var shop_item_id = "%s_%s_%s" % [item.type, item.id, item.index]
		var shop_item = RPGShopItemStock.new(item.uniq_id, item.id, item.type, item.max_quantity, item.quantity, 0)
		restock_data[shop_item_id] = shop_item

	return restock_data


func _check_if_need_set_restock_timer() -> bool:
	var no_unlimited_items: Array = config.items.filter(
		func(item: Dictionary):
			var c1 = item.source == "stock"
			var c2 = item.quantity > 0
			return c1 and c2
	)

	return not no_unlimited_items.is_empty()


func _update_quantity_label() -> void:
	current_quantity.text = current_quantity_text + ":x" + str(current_quantity_step)


func _update_quantity_amount(direction: int) -> void:
	var values = [1, 5, 10, 50, 100]
	var current_index = values.find(current_quantity_step)
	var next_index = wrapi(current_index + direction, 0, values.size())
	current_quantity_step = values[next_index]
	GameManager.play_fx("ok")
	_update_quantity_label()
	
	for panel in item_container.get_children():
		panel.current_amount = current_quantity_step


func start() -> void:
	if is_queued_for_deletion() or not is_inside_tree(): return
	
	_repopulate_items()
	
	if animation_tween:
		animation_tween.kill()
		
	if start_animation == 0:
		$Fader.modulate.a = 0
		position = Vector2.ZERO
	else:
		busy = true
		$Fader.modulate.a = 0.5
		animation_tween = create_tween()
		animation_tween.set_parallel(true)
		animation_tween.tween_property($Fader, "modulate:a", 0.0, 0.37).set_trans(Tween.TRANS_CIRC)
		position = Vector2.ZERO
		match start_animation:
			1: # Move from left
				position.x = -size.x
			2: # Move from right
				position.x = size.x
			3: # Move from top
				position.y = -size.y
			4: # Move from bottom
				position.y = size.y
		if position != Vector2.ZERO:
			animation_tween.tween_property(self, "position", Vector2.ZERO, 0.5).set_trans(Tween.TRANS_SINE)
	
	var mat: ShaderMaterial = %PostProcessEffects.get_material()
	animation_tween.tween_property(mat, "shader_parameter/warp_amount", 0.04, 0.35)
	
	await get_tree().create_timer(0.15).timeout
	
	%AnimationPlayer.play("Start")
	_update_page(0)
	
	await shop_initialized
	
	busy = false
	is_enabled = true
	for item in items_in_cache.values():
		item.is_enabled = true
	
	if last_buy_panel_selected and current_mode == ShopMode.BUY:
		_panel_hovered(last_buy_panel_selected)
	elif last_sell_panel_selected and current_mode == ShopMode.SELL:
		_panel_hovered(last_sell_panel_selected)
	
	if GameManager.get_cursor_manipulator() == str(Manipulators.shop_item_panel):
		_config_hand_in_item_panels()
	
	GameManager.force_show_cursor()


func end() -> void:
	if animation_tween:
		animation_tween.kill()
		
	propagate_call("set", ["is_enabled", false])
	propagate_call("set", ["busy", true])
	
	GameManager.set_cursor_manipulator("")
	GameManager.hide_cursor(false, Manipulators.shop_item_panel)
	
	_set_shop_timer()
		
	if end_animation == 0:
		#queue_free()
		_remove_scene()
	else:
		var target_position = Vector2.ZERO
		animation_tween = create_tween()
		animation_tween.set_parallel(true)
		animation_tween.tween_property($Fader, "modulate:a", 0.5, 0.37).set_trans(Tween.TRANS_CIRC).set_delay(0.7)
		match end_animation:
			1: 
				animation_tween.tween_property(self, "modulate:a", 0.0, 0.3).set_trans(Tween.TRANS_CIRC)
			2: # Move to left 
				target_position.x = -size.x
			3: # Move to right
				target_position.x = size.x
			4: # Move to top
				target_position.y = -size.y
			5: # Move to bottom
				target_position.y = size.y
		if target_position != Vector2.ZERO:
			animation_tween.tween_property(self, "position", target_position, 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN).set_delay(0.7)
	
	var mat: ShaderMaterial = $PostProcessEffects.get_material()
	animation_tween.tween_property(mat, "shader_parameter/warp_amount", 0.0, 0.35).set_delay(0.7)
	
	%AnimationPlayer.play("End")


func _remove_scene() -> void:
	queue_free()


func _update_shop_timer(delta: float) -> void:
	current_restock_timer -= delta
	if current_restock_timer <= 0:
		current_restock_timer = restock_max_time
		var timer: RPGShopTimer = GameManager.get_shop_timer(shop_id)
		if  timer:
			_refresh_stock()
	
	_on_restock_timer_updated(shop_id, current_restock_timer)


func _set_shop_timer() -> void:
	var restock_data = _get_restock_data_from_config(true)
	var timer_shop: RPGShopTimer = GameManager.add_shop_timer(shop_id, restock_max_time, restock_data)
	# Adjust timestamp so the next restock occurs at the correct time based on current countdown
	var next_restock_timestamp = GameManager.game_state.stats.play_time + current_restock_timer
	timer_shop.timestamp = next_restock_timestamp - restock_max_time


func _update_bottom_help_text(controller_type: ControllerManager.CONTROLLER_TYPE) -> void:
	var terms: RPGTerms = RPGSYSTEM.database.terms
	var term1 = terms.get_message("Shop Help Term 1")
	var term2 = terms.get_message("Shop Help Term 2")
	var term3 = terms.get_message("Shop Help Term 3")
	var term4: String
	var term5 = terms.get_message("Shop Help Term 5")
	var term6 = terms.get_message("Shop Help Term 6")
	var help: String = ""
	
	if controller_type == ControllerManager.CONTROLLER_TYPE.Keyboard or controller_type == ControllerManager.CONTROLLER_TYPE.Mouse:
		term4 = "  [↵] " + terms.get_message("Shop Help Term 4") + "  " if not transaction_list.is_empty() else "  "
		help = "[Tab] %s  [Shift+Q/E] %s  [Q/E] %s%s[Esc] %s" % [term1, term2, term3, term4, term5]
		help += "  [Z/X] %s" % term6
	elif controller_type == ControllerManager.CONTROLLER_TYPE.Joypad:
		term4 = "  [▶] " + terms.get_message("Shop Help Term 4") + "  " if not transaction_list.is_empty() else "  "
		help = "[L1/R1] %s  [L2/R2] %s  [X/Y] %s%s[⧉] %s" % [term1, term2, term3, term4, term5]
		help += "  [RS ←/→] %s" % term6
	
	%BottomHelp.text = help


func _set_initial_gold() -> void:
	var gold: int = 0
	if GameManager.game_state:
		gold = GameManager.game_state.current_gold
	
	%CurrentGold.text = GameManager.get_number_formatted(gold)


func _process(delta: float) -> void:
	if Engine.is_editor_hint(): return
	
	_update_transaction_info(delta)
	
	if restock_timer_enabled:
		_update_shop_timer(delta)
	
	if not is_enabled or transaction_confirm_enabled: return
	
	
	%MovePageToLeft.set_disabled(current_page == 0)
	%MovePageToRight.set_disabled(current_page >= current_pages - 1)
	
	if not busy:
		var current_manipulator = GameManager.get_cursor_manipulator()
		if current_manipulator == str(cancel_confirm_message.hand_manipulator):
			return

		if (ControllerManager.is_key_pressed(KEY_ESCAPE) or ControllerManager.is_joy_button_pressed(JOY_BUTTON_BACK)):
			# fast exit, show confirm message if transaction_list is not empty
			exiting_enabled = true
			if transaction_list.is_empty():
				tabs.set_selected_tab(2, true, false)
				tabs.can_draw_focusable_style = false
				tabs.queue_redraw()
				end()
			else:
				_show_confirm_message()
			
		elif (ControllerManager.is_key_pressed(KEY_ENTER) or ControllerManager.is_joy_button_pressed(JOY_BUTTON_START)) and not transaction_confirm_enabled:
			# fast perform transaction if any (confirm required)
			if not transaction_list.is_empty():
				complete_transaction.grab_focus()
				_on_complete_transaction_pressed()
			
		elif ControllerManager.is_key_pressed(KEY_TAB) or ControllerManager.is_joy_button_pressed(JOY_BUTTON_RIGHT_SHOULDER) or ControllerManager.is_joy_button_pressed(JOY_BUTTON_LEFT_SHOULDER):
			# Change Buy/Sell
			tabs.can_draw_focusable_style = false
			if tabs.selected_tab == 0:
				tabs.set_selected_tab(1, true, true)
			else:
				tabs.set_selected_tab(0, true, true)
			tabs.set_deferred("can_draw_focusable_style", true)
			
		elif ControllerManager.is_joy_button_pressed(JOY_BUTTON_X):
			# change page to left
			_on_move_page_to_left_pressed()
			
		elif ControllerManager.is_key_pressed(KEY_Q):
			if ControllerManager.is_key_pressed(KEY_SHIFT):
				# Change Filter to left
				filter_tabs.previous_tab()
			else:
				# change page to left
				_on_move_page_to_left_pressed()
				
		elif ControllerManager.is_joy_button_pressed(JOY_BUTTON_Y):
			# change page to right
			_on_move_page_to_right_pressed()
			
		elif ControllerManager.is_key_pressed(KEY_E):
			if ControllerManager.is_key_pressed(KEY_SHIFT):
				# Change Filter to right
				filter_tabs.next_tab()
			else:
				# change page to right
				_on_move_page_to_right_pressed()
			
		elif ControllerManager.is_trigger_left_pressed():
			# Change Filter to left
			filter_tabs.previous_tab()
		
		elif ControllerManager.is_trigger_right_pressed():
			# Change Filter to right
			filter_tabs.next_tab()
			
		elif ControllerManager.is_key_pressed(KEY_Z):
			# Change quantity to right
			_update_quantity_amount(-1)
		
		elif ControllerManager.is_key_pressed(KEY_X):
			# Change quantity to right
			_update_quantity_amount(1)
		
		elif ControllerManager.get_right_stick_direction() in ["left", "right"]:
			var value = ControllerManager.get_joy_axis_value(JOY_AXIS_RIGHT_X)
			if value < 0:
				# Change quantity to right
				_update_quantity_amount(-1)
			elif value > 0:
				# Change quantity to right
				_update_quantity_amount(1)
		
		else:
			if current_manipulator == str(Manipulators.shop_item_panel):
				_manage_panel_items_actions()
			elif current_manipulator == str(Manipulators.shop_filter_tabs):
				_manage_filter_tabs_actions()
			elif current_manipulator == str(Manipulators.shop_main_tabs):
				_manage_main_tabs_actions()
			elif current_manipulator == str(Manipulators.shop_page_buttons):
				_manage_page_actions()
			elif current_manipulator == str(transaction_confirm.hand_manipulator):
				_manage_confirm_transaction()


func _show_confirm_message() -> void:
	busy = true
	await cancel_confirm_message.show_message()
	busy = false


func _hide_confirm_message() -> void:
	busy = true
	await cancel_confirm_message.hide_message()
	_on_tabs_with_scroll_request_focus_bottom_control()
	var current_manipulator = GameManager.get_cursor_manipulator()
	GameManager.force_hand_position_over_node(current_manipulator)
	GameManager.show_cursor(MainHandCursor.HandPosition.NONE, current_manipulator)
	
	busy = false


func _manage_panel_items_actions() -> void:
	var direction = ControllerManager.get_pressed_direction()
	if direction:
		_change_selected_control(direction)
	elif ControllerManager.is_cancel_pressed([KEY_0, KEY_KP_0]):
		busy = true
		item_container.propagate_call("deselect")
		GameManager.backup_hand_properties()
		_config_hand_in_filter_tabs()
		filter_tabs.set_selected_tab(filter_tabs.get_selected_tab(), false, false)
		GameManager.play_fx("cancel")

		busy = false
	elif complete_transaction.has_focus() and ControllerManager.is_confirm_pressed(false, [KEY_KP_ENTER]):
		_on_complete_transaction_pressed()


func _manage_filter_tabs_actions() -> void:
	if ControllerManager.is_cancel_pressed([KEY_0, KEY_KP_0]):
		GameManager.backup_hand_properties()
		busy = true
		_config_hand_in_main_tabs()
		tabs.set_selected_tab(tabs.get_selected_tab(), false, false)
		GameManager.play_fx("cancel")

		busy = false


func _manage_main_tabs_actions() -> void:
	if ControllerManager.is_cancel_pressed([KEY_0, KEY_KP_0]):
		exiting_enabled = true
		if transaction_list.is_empty():
			end()
		else:
			_show_confirm_message()
		tabs.set_selected_tab(2, true, false)
		tabs.can_draw_focusable_style = false
		tabs.queue_redraw()
		GameManager.play_fx("cancel")


func _manage_page_actions() -> void:
	var direction = ControllerManager.get_pressed_direction()
	if direction:
		if direction == "left" or direction == "right":
			if move_page_to_left.has_focus():
				move_page_to_right.grab_focus()
			else:
				move_page_to_left.grab_focus()
		elif direction == "up":
			_on_tabs_with_scroll_request_focus_bottom_control()
		elif direction == "down":
			_on_tabs_with_scroll_request_focus_top_control()
			
		GameManager.play_fx("cursor")

	elif ControllerManager.is_confirm_pressed(false, [KEY_KP_ENTER]):
		if move_page_to_left.has_focus():
			_on_move_page_to_left_pressed()
		elif move_page_to_right.has_focus():
			_on_move_page_to_right_pressed()
	elif ControllerManager.is_cancel_pressed([KEY_0, KEY_KP_0]):
		_on_tabs_with_scroll_request_focus_bottom_control()
		GameManager.play_fx("cancel")


func _manage_confirm_transaction() -> void:
	if ControllerManager.is_cancel_pressed([KEY_0, KEY_KP_0]):
		if exiting_enabled:
			propagate_call("set", ["busy", true])
			propagate_call("set", ["is_enabled", false])
			end()
		else:
			transaction_confirm_enabled = false
		transaction_confirm.end()

	transaction_container.modulate = transaction_container.modulate.lerp(Color.TRANSPARENT, 8.0 * get_process_delta_time())


func _update_transaction_info(delta: float) -> void:
	if not transaction_list.is_empty():
		current_gold_transation.visible = true
		var lerp_speed = 8
		current_transaction_amount = lerp(current_transaction_amount, target_transaction_amount, lerp_speed * delta)
		var current_text_color: Color = current_gold_transation.get("theme_override_colors/font_color")
		var next_color: Color = current_text_color
		var current_real_value: int = round(current_transaction_amount)
		var value_to_str = GameManager.get_number_formatted(current_real_value)
		var new_value = ""
		if current_real_value > 0:
			new_value = "+%s" % value_to_str
			next_color = current_text_color.lerp(earn_money_color, lerp_speed * delta)
		elif current_real_value < 0:
			new_value = value_to_str
			next_color = current_text_color.lerp(spend_money_color, lerp_speed * delta)
		else:
			new_value = value_to_str
			next_color = current_text_color.lerp(Color("#B0B0B0"), lerp_speed * delta)
		current_gold_transation.set("theme_override_colors/font_color", next_color)
		current_gold_transation.text = new_value
		
		if transaction_confirm_enabled:
			transaction_container.modulate = transaction_container.modulate.lerp(Color.TRANSPARENT, 8.0 * delta)
			if transaction_container.modulate.is_equal_approx(Color.TRANSPARENT):
				transaction_container.visible = false
		else:
			transaction_container.visible = true
			transaction_container.modulate = transaction_container.modulate.lerp(Color.WHITE, 8.0 * delta)
		complete_transaction.mouse_filter = Control.MOUSE_FILTER_STOP
	else:
		current_gold_transation.visible = false
		transaction_container.modulate = transaction_container.modulate.lerp(Color.TRANSPARENT, 8.0 * delta)
		complete_transaction.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if transaction_container.modulate.is_equal_approx(Color.TRANSPARENT):
			transaction_container.visible = false


func _config_hand_in_item_panels() -> void:
	var manipulator = str(Manipulators.shop_item_panel)
	GameManager.set_cursor_manipulator(manipulator)
	var rect = %SmoothScrollContainer.get_global_rect()
	var expansion = 20
	rect.position -= Vector2(expansion, expansion)
	rect.size += Vector2(expansion * 2, expansion * 2)
	GameManager.set_confin_area(rect, manipulator)
	GameManager.set_hand_position(MainHandCursor.HandPosition.LEFT, manipulator)
	GameManager.set_cursor_offset(Vector2(16, 0), manipulator)
	GameManager.force_show_cursor()


func _config_hand_in_filter_tabs() -> void:
	var manipulator = str(Manipulators.shop_filter_tabs)
	filter_tabs.set_hand_manipulator(manipulator)
	GameManager.set_confin_area(Rect2(), manipulator)
	GameManager.set_hand_position(MainHandCursor.HandPosition.LEFT, manipulator)
	GameManager.set_cursor_offset(Vector2(16, 0), manipulator)
	GameManager.force_show_cursor()


func _config_hand_in_main_tabs() -> void:
	var manipulator = str(Manipulators.shop_main_tabs)
	tabs.set_hand_manipulator(manipulator)
	GameManager.set_confin_area(Rect2(), manipulator)
	GameManager.set_hand_position(MainHandCursor.HandPosition.LEFT, manipulator)
	GameManager.set_cursor_offset(Vector2(16, 0), manipulator)
	GameManager.force_show_cursor()


func _on_cancel_pressed() -> void:
	if current_container == ShopContainers.PANELS:
		end()


func _change_selected_control(direction: String) -> void:
	var extra_controls = [] if transaction_list.is_empty() else [complete_transaction]
	if current_enabled_controls_parent == complete_transaction:
		extra_controls.append_array(item_container.get_children())
	var new_control = ControllerManager.get_closest_focusable_control(current_enabled_controls_parent, direction, true, extra_controls)
	if new_control:
		if new_control.has_method("select"):
			new_control.select()
		else:
			new_control.grab_focus()
		
		GameManager.play_fx("cursor")


func _create_panels() -> void:
	if is_queued_for_deletion() or not item_container: return

	items_in_cache.clear() 
	
	for child in item_container.get_children():
		item_container.remove_child(child)
		child.queue_free()
	%SmoothScrollContainer.scroll_vertical = 0
	
	_update_page(0)


func _update_page(page_id: int, refresh_categories: bool = true) -> void:
	item_container.position = Vector2.ZERO
	%SmoothScrollContainer.scroll_vertical = 0
	
	_prepare_items_to_show(refresh_categories)
	current_page = max(0, min(current_pages - 1, page_id))
	
	if current_pages == 0:
		%ShopNavigationContainer.visible = false
		current_from_item_index = 0
		current_to_item_index = queue_items_to_show.size()
		_update_label_text()
	else:
		%ShopNavigationContainer.visible = true
		current_from_item_index = current_page * max_items_by_page
		current_to_item_index = min(queue_items_to_show.size(), current_from_item_index + max_items_by_page)
		_update_label_text()

	queue_items_to_show = queue_items_to_show.slice(current_from_item_index, current_to_item_index)
	
	for child in item_container.get_children():
		item_container.remove_child(child)

	if not queue_items_to_show.is_empty():
		_load_items()
	else:
		current_container = ShopContainers.TOP
		_config_hand_in_main_tabs()
		tabs.set_selected_tab(tabs.get_selected_tab(), false, false)
		GameManager.show_cursor(MainHandCursor.HandPosition.LEFT, Manipulators.shop_main_tabs, Vector2(16, 0))
		categories = []
		_create_filter_tabs()


func _set_page_from_item_uniq_id(uniq_id: String) -> void:
	var old_current_page = current_page
	_prepare_items_to_show(false)
	if current_pages > 1:
		for i in current_pages:
			var from_item_index = i * max_items_by_page
			var to_item_index = min(queue_items_to_show.size(), from_item_index + max_items_by_page)
			var page_items = queue_items_to_show.slice(from_item_index, to_item_index)
			for item in page_items:
				if item.uniq_id == uniq_id:
					_update_page(i, false)
					return
	
	_update_page(old_current_page, false)


func _prepare_items_to_show(refresh_categories: bool = true) -> void:
	queue_items_to_show = config.items.filter(
		func(item: Dictionary):
			var c1 = item.source == ("stock" if current_mode == ShopMode.BUY else "inventory")
			var c2 = current_category_selected.is_empty() or \
				current_category_selected == item.category

			return c1 and c2
	)
	
	sold_out_container.visible = false
	inventory_empty_container.visible = false
	
	if queue_items_to_show.is_empty():
		current_pages = 0
		if current_mode == ShopMode.BUY:
			sold_out_container.visible = true
			return
		else:
			inventory_empty_container.visible = true
			return

	current_pages = ceil(queue_items_to_show.size() / float(max_items_by_page))

	if refresh_categories:
		categories = []
		for i in range(queue_items_to_show.size() - 1, -1, -1):
			var item_data = queue_items_to_show[i]
			var category_id = item_data.category
			if not category_id in categories:
				categories.append(category_id)
		categories.sort_custom(
			func(a: String, b: String) -> bool:
				var term1 = "1_" + a \
					if a != "___none___" \
					else "0_" + tr("Others")

				var term2 = "1_" + b \
					if b != "___none___" \
					else "0_" + tr("Others")
					
				return term1 < term2

		)
		_create_filter_tabs()


func _update_label_text() -> void:
	var t = tr("Current page \\1 / \\2")
	t = t.replace("\\1", str(current_page + 1))
	t = t.replace("\\2", str(current_pages))
	%PageLabel.text = t
	
	shop_navigation_container.visible = current_pages > 1


func _create_filter_tabs() -> void:
	var names = []
	for i in categories.size():
		var text = categories[i] if categories[i] != "___none___" else tr("Others")
		names.append(text)
	
	var all_items_label = tr("All Items")
	if names.size() <= 1:
		names = [all_items_label]
	else:
		names.insert(0, all_items_label)

	filter_tabs.set_tab_names(names)


func _load_items() -> void:
	for i in queue_items_to_show.size():
		var item_data = queue_items_to_show[i]
		current_page_item += 1
		var id = [item_data.id, item_data.type, item_data.uniq_id]
		var item
		
		if id in items_in_cache and is_instance_valid(items_in_cache[id]):
			item = items_in_cache[id]
			if item.get_parent() == item_container:
				item_container.move_child(item, -1)
			else:
				item_container.add_child(item)
				
			item.current_amount = current_quantity_step
			item.update_all()
		else:
			item = ITEM_PANEL.instantiate()
			item.name = "Item %s" % (item_data.uniq_id)
			item.selected.connect(_panel_selected)
			item.hovered.connect(_panel_hovered)
			item.request_transaction.connect(_update_transaction_list)
			item.select_control_to_bottom_requested.connect(_change_selected_control.bind("down"))
			item.select_control_to_top_requested.connect(_change_selected_control.bind("up"))
			item_container.add_child(item)
			initialized = item_container.get_child_count() == 1
			item.set_item(item_data)
			item.is_enabled = is_enabled
			item.manipulator = str(Manipulators.shop_item_panel)
			item.current_amount = current_quantity_step
			item.confin_area = %SmoothScrollContainer
			items_in_cache[id] = item
			complete_transaction.focus_neighbor_top = item.get_path()
		
		if initialized and item_container.get_child_count() == 1:
			initialized = false
			item.call_deferred("select")
			current_enabled_controls_parent = item
	
	%SmoothScrollContainer.set_deferred("scroll_vertical", 0)


func _update_transaction_list(item_data: Dictionary) -> void:
	if item_data.quantity <= 0:
		if item_data.uniq_id in transaction_list:
			transaction_list.erase(item_data.uniq_id)
		_update_bottom_help_text(ControllerManager.current_controller)
		return
		
	transaction_list[item_data.uniq_id] = item_data
	target_transaction_amount = 0
	for item in transaction_list.values():
		target_transaction_amount += item.quantity * item.unit_price
	
	_animate_transaction()
	
	_update_bottom_help_text(ControllerManager.current_controller)


func _animate_transaction() -> void:
	if transaction_tween:
		transaction_tween.kill()
	
	var obj = current_gold_transation
	if not obj.has_meta("original_position"):
		obj.set_meta("original_position", obj.position)
	obj.pivot_offset = obj.size * 0.5
	var shake_intensity: float = 10.0
	var rotation_intensity = deg_to_rad(5)
	var p: Vector2 = obj.get_meta("original_position")
	
	transaction_tween = create_tween()
	transaction_tween.set_parallel(true)
	transaction_tween.tween_property(obj, "position:x", p.x + shake_intensity, 0.05)
	transaction_tween.tween_property(obj, "position:x", p.x - shake_intensity, 0.05).set_delay(0.05)
	transaction_tween.tween_property(obj, "position:x", p.x + shake_intensity/2, 0.05).set_delay(0.10)
	transaction_tween.tween_property(obj, "position:x", p.x - shake_intensity/2, 0.05).set_delay(0.15)
	transaction_tween.tween_property(obj, "position:x", p.x, 0.05).set_delay(0.20)
	transaction_tween.tween_property(obj, "rotation", rotation_intensity, 0.05)
	transaction_tween.tween_property(obj, "rotation", -rotation_intensity, 0.05).set_delay(0.05)
	transaction_tween.tween_property(obj, "rotation", rotation_intensity/2, 0.05).set_delay(0.10)
	transaction_tween.tween_property(obj, "rotation", -rotation_intensity/2, 0.05).set_delay(0.15)
	transaction_tween.tween_property(obj, "rotation", 0.0, 0.05).set_delay(0.20)


func _panel_selected(node: Control) -> void:
	if not busy2:
		if current_mode == ShopMode.BUY:
			last_buy_panel_selected = node
		elif current_mode == ShopMode.SELL:
			last_sell_panel_selected = node
	current_container = ShopContainers.PANELS
	current_enabled_controls_parent = node
	# Deselect others
	for child in %ItemContainer.get_children():
		if node != child:
			child.deselect()
	_config_hand_in_item_panels()
	if current_mode == ShopMode.BUY:
		call_deferred("_panel_hovered", last_buy_panel_selected)
	elif current_mode == ShopMode.SELL:
		call_deferred("_panel_hovered", last_sell_panel_selected)

	await get_tree().process_frame
	if is_inside_tree():
		await get_tree().process_frame
		%SmoothScrollContainer.call_deferred("bring_focus_target_into_view")


func _panel_hovered(node: Control) -> void:
	var item: Dictionary = node.current_item
	if  current_mode == ShopMode.BUY:
		if not item.is_empty() and item.type > 0:
			equipment_preview.set_item_to_compare(item.type, item.id, item.level)
			_show_equipment_preview_panel()
		else:
			_hide_equipment_preview_panel()


func _on_tabs_tab_clicked(tab_id: int) -> void:
	current_container = ShopContainers.TOP
	if busy: return

	busy = true
	var select_items: bool = false
	
	match tab_id:
		0: # BUY
			if current_mode != ShopMode.BUY or reselect_enabled:
				_repopulate_items()
				
				current_buy_filter = -1
				current_category_selected = ""
				current_mode = ShopMode.BUY
				filter_tabs.set_selected_tab(0, true)
				_update_page(0)
				select_items = true
				
		1: # SELL
			if current_mode != ShopMode.SELL or reselect_enabled:
				_hide_equipment_preview_panel()

				_repopulate_items()
				
				current_sell_filter = -1
				current_category_selected = ""
				current_mode = ShopMode.SELL
				filter_tabs.set_selected_tab(0, true)
				_update_page(0)
				select_items = true
				
		2: # EXIT
			_hide_equipment_preview_panel()
			exiting_enabled = true
			if transaction_list.is_empty():
				tabs.set_selected_tab(2, true, false)
				tabs.can_draw_focusable_style = false
				tabs.queue_redraw()
				end()
			else:
				_show_confirm_message()
				return
	
	await get_tree().process_frame
	
	if select_items:
		GameManager.play_fx("ok")
		_reselect_last_item()
	
	busy = false


func _on_tabs_with_scroll_tab_clicked(tab_id: int) -> void:
	if busy: return
	busy = true
	busy2 = true
	current_container = ShopContainers.CATEGORIES
	var update_page_enabled: bool = true
	
	if (current_mode == ShopMode.BUY and current_buy_filter == tab_id) or (current_mode == ShopMode.SELL and current_sell_filter == tab_id):
		update_page_enabled = false

	current_category_selected = "" if tab_id == 0 else categories[tab_id - 1]
	
	if update_page_enabled:
		_update_page(current_page, false)
		var current_item_panel_uniq_id = ""
		if current_mode == ShopMode.BUY and last_buy_panel_selected:
			current_item_panel_uniq_id = last_buy_panel_selected.current_item.uniq_id
		elif current_mode == ShopMode.SELL and last_sell_panel_selected:
			current_item_panel_uniq_id = last_sell_panel_selected.current_item.uniq_id
		if not current_item_panel_uniq_id.is_empty():
			_set_page_from_item_uniq_id(current_item_panel_uniq_id)

	var category_changed: bool = false
	if current_mode == ShopMode.BUY:
		if current_buy_filter != tab_id:
			category_changed = true
			current_buy_filter = tab_id
	else:
		if current_sell_filter != tab_id:
			category_changed = true
			current_sell_filter = tab_id
	
	await get_tree().process_frame
	
	busy2 = false
	
	if item_container.get_child_count() > 0:
		_reselect_last_item()
		
	if category_changed:
		GameManager.play_fx("ok")
		
	busy = false


func _reselect_last_item() -> void:
	var current_item = -1
	if item_container.get_child_count() > 0:
		current_item = 0
		var current_item_panel_uniq_id = ""
		if current_mode == ShopMode.BUY and last_buy_panel_selected:
			current_item_panel_uniq_id = last_buy_panel_selected.current_item.uniq_id
		elif current_mode == ShopMode.SELL and last_sell_panel_selected:
			current_item_panel_uniq_id = last_sell_panel_selected.current_item.uniq_id
		if not current_item_panel_uniq_id.is_empty():
			for i in item_container.get_child_count():
				var child = item_container.get_child(i)
				if child.current_item.uniq_id == current_item_panel_uniq_id:
					current_item = i
					break
					
	if current_item > -1:
		item_container.get_child(current_item).call_deferred("select")


func _on_move_page_to_left_pressed() -> void:
	if current_pages <= 1: return
	tabs.can_draw_focusable_style = false
	var page = max(0, current_page - 1)
	if current_page != page:
		current_category_selected = ""
		_update_page(page)
		GameManager.play_fx("ok")
	tabs.set_deferred("can_draw_focusable_style", true)
	if item_container.get_child_count() > 0:
		item_container.get_child(0).select()


func _on_move_page_to_right_pressed() -> void:
	if current_pages <= 1: return
	tabs.can_draw_focusable_style = false
	var page = min(current_page + 1, current_pages - 1)
	if current_page != page:
		current_category_selected = ""
		_update_page(page)
		GameManager.play_fx("ok")
	tabs.set_deferred("can_draw_focusable_style", true)
	if item_container.get_child_count() > 0:
		item_container.get_child(0).select()


func _on_complete_transaction_focus_entered() -> void:
	if transaction_list.is_empty():
		return
		
	current_enabled_controls_parent = complete_transaction
	var manipulator = Manipulators.shop_item_panel
	GameManager.set_cursor_manipulator(manipulator)
	GameManager.set_confin_area(Rect2(), manipulator)
	GameManager.set_hand_position(MainHandCursor.HandPosition.LEFT, manipulator)
	GameManager.set_cursor_offset(Vector2(16, 0), manipulator)


func _on_complete_transaction_focus_exited() -> void:
	if not is_enabled: return
	if GameManager.get_cursor_manipulator() == Manipulators.shop_item_panel:
		GameManager.set_confin_area(%ItemsContainer.get_rect())


func _on_complete_transaction_pressed(enable_ignored: bool = false) -> void:
	if enable_ignored: return
	
	transaction_confirm_enabled = true
	GameManager.hide_cursor(true, GameManager.get_cursor_manipulator())
	GameManager.backup_hand_properties()
	GameManager.set_cursor_manipulator(Manipulators.confirm_transaction)
	transaction_confirm.add_items(transaction_list.values())
	transaction_confirm.visible = true
	transaction_confirm.start()
	GameManager.play_fx("ok")
	
	if transaction_button_tween:
		transaction_button_tween.kill()
	
	complete_transaction.pivot_offset = complete_transaction.size / 2
	transaction_button_tween = create_tween()
	transaction_button_tween.tween_property(complete_transaction, "scale", Vector2(0.9, 0.9), 0.1)
	transaction_button_tween.tween_property(complete_transaction, "scale", Vector2.ONE, 0.2)


func _on_transaction_confirm_cancel_pressed() -> void:
	if exiting_enabled:
		end()
	else:
		transaction_confirm_enabled = false
		GameManager.restore_hand_properties()
		complete_transaction.grab_focus()
		GameManager.force_hand_position_over_node(GameManager.get_cursor_manipulator())


func _on_transaction_confirm_ok_pressed() -> void:
	# update player and shop items
	# if exiting enabled, finish, else update shop and continue
	_finish_transaction()
	if exiting_enabled:
		end()
	else:
		reselect_enabled = true
		transaction_confirm_enabled = false
		tabs.can_draw_focusable_style = false
		tabs.set_selected_tab(tabs.selected_tab, true, true)
		tabs.set_deferred("can_draw_focusable_style", true)
		reselect_enabled = false


func _update_stock() -> void:
	var items_erased := [] # Erased items from player inventory
	var items_restocked := [] # Animate current panels with stock changed
	var restocking_items := [] # Replenish items sold by the store
	
	# 1º) update all items stock
	for item: Dictionary in transaction_list.values():
		for real_item: Dictionary in config.items:
			if real_item.uniq_id == item.uniq_id:
				real_item.quantity -= item.quantity
				if real_item.source == "stock": # items to buy in the shop
					items_restocked.append(real_item)
				elif real_item.source == "inventory": # items to sell in the shop
					restocking_items.append({"type": item.type, "id": item.id, "quantity": item.quantity})
					# erase item from player inventory
					if real_item.quantity == 0 and not real_item.get("fixed", false): # erase item from the list
						config.items.erase(real_item)
						items_erased.append(real_item)
					elif not real_item.quantity == 0:
						items_restocked.append(real_item)
				break
	
	# Replenish items sold by the store
	for restock_data in restocking_items:
		while restock_data.quantity > 0:
			var success_restock: bool = false
			for real_item: Dictionary in config.items:
				if real_item.source == "stock" and real_item.type == restock_data.type and real_item.id == restock_data.id and real_item.quantity != real_item.max_quantity:
					var space_available = real_item.max_quantity - real_item.quantity
					var items_to_add = min(restock_data.quantity, space_available)
					real_item.quantity += items_to_add
					restock_data.quantity -= items_to_add
					success_restock = true
					break
			if not success_restock:
				break
			
	
	# Refresh shop items
	_refresh_shop()
	
	# 2º) update stock in current panels
	for panel in item_container.get_children():
		if panel.current_item in items_erased:
			item_container.remove_child(panel)
			panel.queue_free()
		else:
			panel.items_to_take = 0
			panel.update_all()
			if panel.current_item in items_restocked:
				panel.flash_panel()
	
	if item_container.get_child_count() == 0:
		if tabs.get_selected_tab() == 0: # buy
			sold_out_container.visible = true
		elif tabs.get_selected_tab() == 1: # sell
			inventory_empty_container.visible = true
			
	# 3º) clean transaction_list and play sound
	if not transaction_list.is_empty():
		GameManager.play_fx("complete_transaction")
	transaction_list.clear()
	# 4º) Animate gold
	if GameManager.game_state:
		var transaction_gold = round(current_transaction_amount)
		var player_gold = GameManager.game_state.current_gold
		var target_gold = player_gold + transaction_gold
		GameManager.game_state.current_gold = target_gold
		var t = create_tween()
		t.tween_method(
			func(value: int):
				%CurrentGold.text = GameManager.get_number_formatted(value)
		, player_gold, target_gold, 0.6)


func _refresh_shop() -> void:
	_set_shop_timer()
	_reload_shop_data()
	config.items.clear()
	config.item_counter = 0
	for panel: Node in items_in_cache.values():
		if panel.get_parent():
			panel.get_parent().remove_child(panel)
		panel.queue_free()
	items_in_cache.clear()
	restock_buy_list.call()
	restock_sell_list.call()
	var node: PanelContainer
	if current_mode == ShopMode.BUY:
		node = last_buy_panel_selected
	elif current_mode == ShopMode.SELL:
		node = last_sell_panel_selected
	if node:
		var uniq_id = node.current_item.uniq_id
		reselect_enabled = true
		tabs.set_selected_tab(tabs.get_selected_tab(), true, true)
		reselect_enabled = false
		for panel in item_container.get_children():
			if panel.current_item.uniq_id == uniq_id:
				panel.select()
				%SmoothScrollContainer.fast_scrolling()
				break


func _reload_shop_data() -> void:
	if not config or not config.has("items"): return

	config.items.clear()

	if "item_counter" in config:
		config.item_counter = 0

	if restock_buy_list.is_valid():
		restock_buy_list.call()
	if restock_sell_list.is_valid():
		restock_sell_list.call()


func _repopulate_items() -> void:
	config.items.clear()
	
	if "item_counter" in config:
		config.item_counter = 0
	
	if restock_buy_list.is_valid():
		restock_buy_list.call()
	if restock_sell_list.is_valid():
		restock_sell_list.call()
		
	items_in_cache.clear()
	for child in item_container.get_children():
		child.queue_free()
		item_container.remove_child(child)


func _finish_transaction() -> void:
	var total = int(GameManager.game_state.current_gold + current_transaction_amount)
	if total < 0:
		_animate_insufficient_gold()
		return
	
	for item in transaction_list.values():
		if item.source == "stock": # buy item
			match item.type:
				0: # Items
					GameManager.add_item_amount(item.id, item.quantity)
				1: # Weapons
					GameManager.add_weapon_amount(item.id, item.quantity, item.level)
				2: # Armors
					GameManager.add_armor_amount(item.id, item.quantity, item.level)
		else: # sell item
			match item.type:
				0: # Items
					GameManager.remove_item_amount(item.id, item.quantity)
				1: # Weapons
					GameManager.remove_weapon_amount(item.id, item.quantity, false)
				2: # Armors
					GameManager.remove_armor_amount(item.id, item.quantity, false)

	_update_stock()
	

func _animate_insufficient_gold() -> void:
	if current_gold_tween:
		current_gold_tween.kill()
	
	var shake_duration: float = 0.5
	var shake_intensity: float = 5
	var shake_frequency: int = 50
	var rotation_intensity: float = 2.0

	var step_duration = shake_duration / shake_frequency
		
	var node = %CurrentGold
	var node2 = %InsufficientGold
	var node3 = %GoldIcon
	if not node.has_meta("original_size_and_rotation"):
		node.set_meta("original_size_and_rotation", [node.position, node.rotation])
	
	var original_position = node.get_meta("original_size_and_rotation")[0]
	var original_rotation = node.get_meta("original_size_and_rotation")[1]
	node.pivot_offset = node.size / 2
	
	node2.global_position = Vector2(
		node3.global_position.x + node3.size.x + 2,
		node3.global_position.y + node3.size.y / 2 - node2.size.y / 2
	)
	
	current_gold_tween = create_tween()
	
	current_gold_tween.set_parallel(true)
	current_gold_tween.tween_property(
		node, 
		"modulate", 
		Color.RED, 
		0.2
	)
	current_gold_tween.tween_property(
		node2, 
		"modulate", 
		Color.WHITE, 
		0.2
	)
	
	for i in range(shake_frequency):
		current_gold_tween.set_parallel(true)
		var random_offset = Vector2(
			randf_range(-shake_intensity, shake_intensity),
			randf_range(-shake_intensity, shake_intensity)
		)
		var random_rotation = randf_range(-rotation_intensity, rotation_intensity)
		current_gold_tween.tween_property(
			node, 
			"position", 
			original_position + random_offset, 
			step_duration
		)
		current_gold_tween.tween_property(
			node, 
			"rotation_degrees", 
			original_rotation + random_rotation, 
			step_duration
		)
		current_gold_tween.set_parallel(false)
		current_gold_tween.tween_interval(step_duration)
		current_gold_tween.tween_interval(0.001)
	
	current_gold_tween.tween_interval(0.001)
	current_gold_tween.set_parallel(true)
	current_gold_tween.tween_property(
		node, 
		"modulate", 
		Color.WHITE, 
		0.1
	)
	current_gold_tween.tween_property(
		node2, 
		"modulate", 
		Color.TRANSPARENT, 
		0.25
	)
	current_gold_tween.tween_property(node, "position", original_position, 0.1)
	current_gold_tween.tween_property(node, "rotation_degrees", original_rotation, 0.1)
	
	GameManager.play_fx("no money error")


func _on_tabs_request_focus_bottom_control() -> void:
	GameManager.restore_hand_properties()
	_config_hand_in_filter_tabs()
	filter_tabs.set_selected_tab(filter_tabs.get_selected_tab(), false, false)
	GameManager.play_fx("cursor")


func _on_tabs_with_scroll_request_focus_bottom_control() -> void:
	GameManager.restore_hand_properties()
	_config_hand_in_item_panels()
	
	_reselect_last_item()
		
	GameManager.play_fx("cursor")


func _on_tabs_with_scroll_request_focus_top_control() -> void:
	GameManager.backup_hand_properties()
	_config_hand_in_main_tabs()
	tabs.set_selected_tab(tabs.get_selected_tab(), false, false)
	GameManager.play_fx("cursor")


func _on_move_page_to_left_focus_entered() -> void:
	var manipulator = Manipulators.shop_page_buttons
	GameManager.set_cursor_manipulator(manipulator)
	GameManager.set_confin_area(Rect2(), manipulator)
	GameManager.set_hand_position(MainHandCursor.HandPosition.LEFT, manipulator)
	GameManager.set_cursor_offset(Vector2(10, 0), manipulator)


func _on_move_page_to_right_focus_entered() -> void:
	var manipulator = Manipulators.shop_page_buttons
	GameManager.set_cursor_manipulator(manipulator)
	GameManager.set_confin_area(Rect2(), manipulator)
	GameManager.set_hand_position(MainHandCursor.HandPosition.RIGHT, manipulator)
	GameManager.set_cursor_offset(Vector2(-10, 0), manipulator)


func _on_cancel_confirm_cancel_focus_entered() -> void:
	var manipulator = Manipulators.shop_confirm_message
	GameManager.set_cursor_manipulator(manipulator)
	GameManager.set_confin_area(Rect2(), manipulator)
	GameManager.set_hand_position(MainHandCursor.HandPosition.LEFT, manipulator)
	GameManager.set_cursor_offset(Vector2(10, 0), manipulator)


func _on_cancel_confirm_ok_focus_entered() -> void:
	var manipulator = Manipulators.shop_confirm_message
	GameManager.set_cursor_manipulator(manipulator)
	GameManager.set_confin_area(Rect2(), manipulator)
	GameManager.set_hand_position(MainHandCursor.HandPosition.LEFT, manipulator)
	GameManager.set_cursor_offset(Vector2(10, 0), manipulator)


func _on_cancel_confirm_message_cancel_requested() -> void:
	await _hide_confirm_message()
	
	exiting_enabled = false
	
	if transaction_confirm_enabled:
		transaction_confirm.focus()
	else:
		GameManager.restore_hand_properties()
		if item_container.get_child_count() == 0:
			_config_hand_in_main_tabs()
			tabs.set_selected_tab(tabs.get_selected_tab(), false, false)
		else:
			_config_hand_in_item_panels()

		_reselect_last_item()


func _on_cancel_confirm_message_ok_requested() -> void:
	await _hide_confirm_message()
	tabs.set_selected_tab(2, true, false)
	tabs.can_draw_focusable_style = false
	tabs.queue_redraw()
	end()


func _show_equipment_preview_panel() -> void:
	if busy: return
	if equipment_preview_tween:
		equipment_preview_tween.kill()
	
	if not equipment_preview.has_meta("original_position"):
		equipment_preview.set_meta("original_position", equipment_preview.global_position)
		equipment_preview.global_position = equipment_preview.global_position + Vector2(equipment_preview.size.x + 40, 0)
		equipment_preview.set_meta("hidden_position", equipment_preview.global_position)
	
	equipment_preview.visible = true
	equipment_preview_tween = create_tween()
	equipment_preview_tween.set_parallel(true)
	var current_x = equipment_preview.global_position.x
	var target_x = equipment_preview.get_meta("original_position").x
	var displacement = target_x - current_x
	preview_equipment_animation_curve.max_value = 1.02
	equipment_preview_tween.tween_method(
		func(value: float):
			var sample = preview_equipment_animation_curve.sample(value)
			equipment_preview.global_position.x = current_x + displacement * sample
	, 0.0, 1.0, 0.35)
	equipment_preview_tween.tween_method(
		func(value: float):
			equipment_preview.animate_modulation_alpha(value)
	, equipment_preview.modulate.a, 1.0, 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _hide_equipment_preview_panel() -> void:
	if equipment_preview_tween:
		equipment_preview_tween.kill()
	
	if not equipment_preview.has_meta("original_position"):
		return
		
	equipment_preview_tween = create_tween()
	equipment_preview_tween.set_parallel(true)
	var x = equipment_preview.get_meta("hidden_position").x
	equipment_preview_tween.tween_property(equipment_preview, "global_position:x", x, 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	equipment_preview_tween.tween_method(
		func(value: float):
			equipment_preview.animate_modulation_alpha(value)
	, equipment_preview.modulate.a, 0.3, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)


func _update_restock_timer() -> void:
	var timer = %RestockTimer
	if not shop_id.is_empty():
		timer.visible = true
	else:
		timer.visible = false
		
