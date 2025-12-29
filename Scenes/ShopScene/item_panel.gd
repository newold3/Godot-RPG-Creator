extends PanelContainer

@export var frame_textures: Dictionary = {
	"frame1": preload("res://Assets/Images/GUI/frame1.png"),
	"frame2": preload("res://Assets/Images/GUI/frame2.png"),
	"frame3": preload("res://Assets/Images/GUI/frame3.png"),
	"frame1_disabled": preload("res://Assets/Images/GUI/frame1_disabled.png"),
	"frame2_disabled": preload("res://Assets/Images/GUI/frame2_disabled.png"),
	"frame3_disabled": preload("res://Assets/Images/GUI/frame3_disabled.png"),
}


@onready var item_name_label: Label = %ItemNameLabel
@onready var item_icon: TextureRect = %ItemIcon
@onready var quantity_label: Label = %QuantityLabel
@onready var price_label: Label = %PriceLabel
@onready var gold_icon: TextureRect = %GoldIcon
@onready var has_items_label: Label = %HasItemsLabel
@onready var items_to_take_label: Label = %ItemsToTakeLabel
@onready var description: Label = %Description
@onready var cursor_hover: NinePatchRect = %CursorHover
@onready var minus_button: TextureButton = %MinusButton
@onready var plus_button: TextureButton = %PlusButton
@onready var description_scroll_container: Container = %DescriptionAutoScrollContainer
@onready var main_item_frame: NinePatchRect = %MainItemFrame
@onready var top_frame: NinePatchRect = %TopFrame
@onready var icon_frame: NinePatchRect = %IconFrame
@onready var stock_frame: NinePatchRect = %StockFrame
@onready var buy_frame: NinePatchRect = $VBoxContainer/MarginContainer3/BuyFrame

var current_item: Dictionary
var confin_area: Control
var items_to_take: int : set = _set_items_to_take
var is_selected: bool = false
var panel_mode: int = 0 # 0 = main panel focused, 1 = + or - buttons focused
var current_button_selected: TextureButton
var unlimited_items: bool = false
var is_enabled: bool = false

# Current number of items that will be added or removed at once when pressing + or -
var current_amount: int = 1

var plus_tween: Tween
var minus_tween: Tween

var click_delay: float = 0.0

var manipulator: String = ""


signal request_transaction(item_data: Dictionary)
signal set_navigation_for_parent_requested(node: Node)
signal selected(panel: Control)
signal hovered(panel: Control)
signal back_pressed(panel: Control)
signal select_control_to_bottom_requested()
signal select_control_to_top_requested()


func _ready() -> void:
	%HiddenMeasureLabel.item_rect_changed.connect(
		func():
			items_to_take_label.custom_minimum_size.x = %HiddenMeasureLabel.size.x
	)
	GameManager.set_text_config(self, false, false)
	minus_button.focus_entered.connect(_on_minus_button_focus_entered)
	plus_button.focus_entered.connect(_on_plus_button_focus_entered)
	_update_stock()


func _process(delta: float) -> void:
	if not is_enabled: return
	
	if click_delay > 0.0: click_delay -= delta

	if is_selected and (manipulator.is_empty() or GameManager.get_cursor_manipulator() in [manipulator, "shop_item_panel_buttons"]):
		if panel_mode == 0:
			if ControllerManager.is_confirm_pressed(false, [KEY_KP_ENTER]):
				if current_item.quantity == 0 and not unlimited_items:
					return
				_change_to_mode1()
			elif ControllerManager.is_cancel_pressed([KEY_0, KEY_KP_0]):
				back_pressed.emit(self)
				GameManager.play_fx("cancel")
		else:
			var direction = ControllerManager.get_pressed_direction()
			if direction:
				if direction == "up":
					_change_to_mode0(false)
					select_control_to_top_requested.emit()
				elif direction == "down":
					_change_to_mode0(false)
					select_control_to_bottom_requested.emit()
				else:
					_change_selected_button(direction)
			elif ControllerManager.is_confirm_pressed(false, [KEY_KP_ENTER]):
				var focus_owner = get_viewport().gui_get_focus_owner()
				if focus_owner is TextureButton:
					if Input.is_action_pressed("Mouse Left") and not focus_owner.get_global_rect().has_point(get_global_mouse_position()): return
					focus_owner.pressed.emit(false)
			elif ControllerManager.is_cancel_pressed([KEY_0, KEY_KP_0]):
				_change_to_mode0()


func _change_to_mode1() -> void:
	if panel_mode > 0: return
	if Input.is_action_pressed("Mouse Left") and (
		not get_global_rect().has_point(get_global_mouse_position()) or click_delay > 0.0):
			return

	panel_mode = 1
	enable_buttons()
	GameManager.play_fx("select")


func _change_to_mode0(play_fx: bool = true) -> void:
	panel_mode = 0
	disable_buttons()
	if play_fx:
		GameManager.play_fx("cancel")


func _change_selected_button(direction: String) -> void:
	var new_control = ControllerManager.get_closest_focusable_control(current_button_selected, direction, true)
	if new_control:
		new_control.grab_focus()
		GameManager.play_fx("cursor")


func set_item(item: Dictionary) -> void:
	current_item = item
	item_name_label.text = item.name + ("" if item.level <= 1 else " +%s" % int(item.level))
	description.text = item.description
	price_label.text = GameManager.get_number_formatted(int(item.price))
	var icon: RPGIcon = item.icon
	if ResourceLoader.exists(icon.path):
		item_icon.texture.atlas = load(icon.path)
		item_icon.texture.region = icon.region
	else:
		item_icon.texture.atlas = null

	if item.max_quantity == 0 and not item.get("empty_item", false):
		unlimited_items = true
	
	var player_inventory_stock : int = 0
	var data: PackedColorArray
	if item.type == 0:
		data = RPGSYSTEM.database.types.item_rarity_color_types
		player_inventory_stock = GameManager.get_item_amount(item.id)
	elif item.type == 1:
		data = RPGSYSTEM.database.types.weapon_rarity_color_types
		player_inventory_stock = GameManager.get_weapon_amount(item.id)
	else:
		data = RPGSYSTEM.database.types.armor_rarity_color_types
		player_inventory_stock = GameManager.get_armor_amount(item.id)
	
	if item.rarity >= 0 and item.rarity < data.size():
		%ItemNameLabel.set("theme_override_colors/font_color", data[item.rarity])
	else:
		%ItemNameLabel.set("theme_override_colors/font_color", Color.WHITE)
	
	var name_outline_color: Color = %ItemNameLabel.get("theme_override_colors/font_color")
	%ItemNameLabel.set("theme_override_colors/font_outline_color", name_outline_color.darkened(0.8))
	
	var current_player_stock = RPGSYSTEM.database.terms.get_message("Shop Player Items Stock")
	current_player_stock = current_player_stock.replace("\\n", str(player_inventory_stock))
	%HasItemsLabel.text = current_player_stock

	if item.max_quantity == 0:
		%HiddenMeasureLabel.text = str(99999)
	else:
		%HiddenMeasureLabel.text = str(int(item.max_quantity))
	
	_update_stock()

func enable_buttons() -> void:
	if not is_selected: select()
	GameManager.backup_hand_properties()
	GameManager.set_hand_properties(
		MainHandCursor.HandPosition.RIGHT,
		Vector2(-3, 0),
		Rect2() if not confin_area else confin_area.get_global_rect(),
		"shop_item_panel_buttons"
	)
	plus_button.grab_focus()

	mouse_filter = MOUSE_FILTER_IGNORE
	minus_button.mouse_filter = MOUSE_FILTER_STOP
	plus_button.mouse_filter = MOUSE_FILTER_STOP
	set_navigation_for_parent_requested.emit(minus_button.get_parent())


func disable_buttons(perform_select: bool = true) -> void:
	GameManager.restore_hand_properties()
	if perform_select:
		select()

	mouse_filter = MOUSE_FILTER_STOP
	minus_button.mouse_filter = MOUSE_FILTER_IGNORE
	plus_button.mouse_filter = MOUSE_FILTER_IGNORE
	set_navigation_for_parent_requested.emit(get_parent())


func enable_panel() -> void:
	disable_buttons()


func select() -> void:
	if not is_inside_tree(): return
	click_delay = 0.1
	is_selected = true
	disable_buttons(false)
	grab_focus()
	panel_mode = 0
	cursor_hover.visible = true
	mouse_filter = MOUSE_FILTER_STOP
	minus_button.mouse_filter = MOUSE_FILTER_IGNORE
	plus_button.mouse_filter = MOUSE_FILTER_IGNORE
	selected.emit(self)
	hovered.emit(self)


func deselect() -> void:
	is_selected = false
	panel_mode = 0
	disable_buttons(false)
	if has_focus():
		release_focus()
	elif minus_button.has_focus():
		minus_button.release_focus()
	elif plus_button.has_focus():
		plus_button.release_focus()
	cursor_hover.visible = false


func _set_items_to_take(amount: int) -> void:
	items_to_take = amount
	_update_stock()
	_update_items_to_take()


func _update_stock() -> void:
	if current_item.is_empty(): return

	if unlimited_items:
		quantity_label.set("theme_override_font_sizes/font_size", 23)
		quantity_label.text = "∞"
		_show_panel_enabled()
	else:
		quantity_label.set("theme_override_font_sizes/font_size", 16)
		if quantity_label.has_meta("quantity_label_tween"):
			var t: Tween = quantity_label.get_meta("quantity_label_tween")
			if t.is_valid():
				t.kill()
		var current_stock = current_item.get("quantity", 0) - items_to_take
		if current_stock > 999:
			quantity_label.text = "999+"
		else:
			var t = create_tween()
			t.tween_method(
				func(value: int):
					quantity_label.text = str(value)
			, int(quantity_label.text), current_stock, 0.1)
			quantity_label.set_meta("quantity_label_tween", t)
			#quantity_label.text = str(int(current_stock))
		
		if current_stock > 0 or unlimited_items:
			_show_panel_enabled()
		else:
			_show_panel_disabled()


func _show_panel_enabled() -> void:
	#var disabled_color = Color.WHITE
	#quantity_label.set("theme_override_colors/font_color", disabled_color)
	#item_icon.set("modulate", disabled_color)
	main_item_frame.texture = frame_textures.frame1
	top_frame.texture = frame_textures.frame2
	icon_frame.texture = top_frame.texture
	stock_frame.texture = frame_textures.frame3
	buy_frame.texture = stock_frame.texture
	modulate.a = 1.0
	
	%SoldOutContainer.visible = false
	%HasItemsLabel.visible = true


func _show_panel_disabled() -> void:
	if items_to_take > 0: return
	#var disabled_color = Color("#505050")
	#quantity_label.set("theme_override_colors/font_color", disabled_color)
	#item_icon.set("modulate", disabled_color)
	main_item_frame.texture = frame_textures.frame1_disabled
	top_frame.texture = frame_textures.frame2_disabled
	icon_frame.texture = top_frame.texture 
	stock_frame.texture = frame_textures.frame3_disabled
	buy_frame.texture = stock_frame.texture
	modulate.a = 0.95
	
	if current_item and current_item.quantity == 0 and not unlimited_items and (current_item.get("empty_item", false) or current_item.restock_amount < 1):
		if current_item.source == "stock":
			%SoldOutLabel.text = tr("SOLD OUT")
		else:
			%SoldOutLabel.text = tr("UNAVAILABLE")
		%SoldOutContainer.visible = true
		%HasItemsLabel.visible = false


func _update_items_to_take() -> void:
	items_to_take_label.text = str(items_to_take)


func update_all() -> void:
	_update_stock()
	_update_items_to_take()


func show_restock_animation() -> void:
	%RestockParticles.restart()
	flash_panel()
	_show_panel_enabled()


func flash_panel() -> void:
	var t = create_tween()
	t.tween_property(self, "modulate", Color(1.6, 1.6, 1.0), 0.1)
	t.tween_property(self, "modulate", Color.WHITE, 0.2)


func _get_item_formatted(amount) -> Dictionary:
	var max_items = current_item.get("quantity", 0) if not unlimited_items else 99999999999
	items_to_take = clamp(items_to_take + amount, 0, max_items)
	var price = current_item.price * (-1 if current_item.source == "stock" else 1)
	var item = {
		"index": current_item.index,
		"uniq_id": current_item.uniq_id,
		"type": current_item.type,
		"id": current_item.id,
		"quantity": items_to_take,
		"unit_price": price,
		"name": item_name_label.get_text(),
		"color": item_name_label.get("theme_override_colors/font_color"),
		"icon": item_icon.get_texture(),
		"source": current_item.source,
		"level": current_item.get("level", 1)
	}
	return item


func _complete_action(item: Dictionary, tween: Tween, button: TextureButton) -> void:
	request_transaction.emit(item)
	
	if item.unit_price < 0:
		GameManager.play_fx("buy")
	else:
		GameManager.play_fx("sell")

	if tween:
		tween.kill()
	
	button.pivot_offset = button.size
	button.scale = Vector2.ONE
	tween = create_tween()
	tween.tween_property(button, "scale", Vector2(0.9, 0.9), 0.1)
	tween.tween_property(button, "scale", Vector2.ONE, 0.25)


func _on_minus_button_pressed(ignore_action: bool = true) -> void:
	if not is_selected:
		return

	if not minus_button.has_focus(): minus_button.grab_focus()
	if ignore_action: return # Early return (ignore signal when button is clicked. Controlled by process)
	if items_to_take > 0:
		var item = _get_item_formatted(-current_amount)
		_complete_action(item, minus_tween, minus_button)


func _on_plus_button_pressed(ignore_action: bool = true) -> void:
	if not is_selected:
		select()
		return
	if not plus_button.has_focus(): plus_button.grab_focus()
	if ignore_action: return # Early return (ignore signal when button is clicked. Controlled by process)
	if unlimited_items or items_to_take < current_item.get("quantity", 0):
		var item = _get_item_formatted(current_amount)
		_complete_action(item, plus_tween, plus_button)


func _on_main_item_panel_mouse_entered() -> void:
	cursor_hover.visible = true
	hovered.emit(self)


func _on_main_item_panel_mouse_exited() -> void:
	if not is_selected:
		cursor_hover.visible = false


func _on_main_item_panel_focus_entered() -> void:
	if not is_selected:
		select()


func _on_minus_button_focus_entered() -> void:
	GameManager.set_hand_position(MainHandCursor.HandPosition.LEFT, "shop_item_panel_buttons")
	GameManager.set_cursor_offset(Vector2(3, 0), "shop_item_panel_buttons")
	current_button_selected = minus_button


func _on_plus_button_focus_entered() -> void:
	GameManager.set_hand_position(MainHandCursor.HandPosition.RIGHT, "shop_item_panel_buttons")
	GameManager.set_cursor_offset(Vector2(-3, 0), "shop_item_panel_buttons")
	current_button_selected = plus_button
