extends MarginContainer


@export var manipulator: String = GameManager.MANIPULATOR_MODES.ITEM_MENU3


## Emitted when the player confirms or clicks an item
signal item_activated(obj: Dictionary)
## Emitted when an item receives focus
signal item_focused(obj: Dictionary)
## Signal emitted when the dialog requests to be closed
signal close_requested()
## Signal emitted when the dialog is closed
signal finished()

var is_started: bool = false

var right_decoration_spin: Tween


func _ready() -> void:
	%CircularTabs.manipulator = manipulator
	%ItemList.manipulator = manipulator
	%OrderLeft.manipulator = manipulator
	%OrderRight.manipulator = manipulator
	set_disabled()


func set_enabled() -> void:
	GameManager.set_cursor_manipulator(manipulator)
	modulate = Color.WHITE
	for node in [%CircularTabs, %ItemList, %ItemPaginator, %OrderLeft, %OrderRight]:
		node.enabled = true
		node.manipulator = manipulator
		node.set_process_mode(Node.PROCESS_MODE_INHERIT)


func set_disabled() -> void:
	GameManager.set_cursor_manipulator(GameManager.MANIPULATOR_MODES.NONE)
	modulate = Color(0.85, 0.85, 0.85)
	for node in [%CircularTabs, %ItemList, %ItemPaginator, %OrderLeft, %OrderRight]:
		node.enabled = false
		node.manipulator = GameManager.MANIPULATOR_MODES.NONE
		node.set_process_mode(Node.PROCESS_MODE_DISABLED)


func set_tabs(tabs: PackedStringArray) -> void:
	%CircularTabs.add_tabs(tabs)
	if tabs.size() <= 1:
		%PanelL2Tab.modulate = Color(0.65, 0.65, 0.65)
		%PanelR2Tab.modulate = Color(0.65, 0.65, 0.65)
	else:
		%PanelL2Tab.modulate = Color.WHITE
		%PanelR2Tab.modulate = Color.WHITE


func start() -> void:
	if is_started: return
	
	is_started = true
	
	set_enabled()
	
	var stream = preload("uid://cegbob6fb11g2")
	GameManager.play_se(stream)
	
	var node = %MainAnimator
	var t = create_tween()
	t.tween_property(node, "speed_scale", 1.5, 0.2).from(0.0)
	t.tween_callback(%ItemList.select_item.bind(0))
	t.tween_property(node, "speed_scale", 0.0, 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)


func end() -> void:
	if not is_started: return
	
	is_started = false
	
	set_disabled()
	
	GameManager.play_fx("cancel")
	
	if right_decoration_spin:
		right_decoration_spin.kill()
	
	var node = %MainAnimator
	var t = create_tween()
	t.tween_property(node, "speed_scale", 1.5, 0.1).from(0.0).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_EXPO)
	t.tween_callback(func(): close_requested.emit())
	t.tween_property(node, "speed_scale", 0.0, 0.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)

func _on_item_list_item_activated(obj: Dictionary) -> void:
	item_activated.emit(obj)


func _on_item_list_item_focused(obj: Dictionary) -> void:
	item_focused.emit(obj)


func _on_item_list_close_requested() -> void:
	end()


func _on_circular_tabs_tab_selected(tab_index: int, direction: String) -> void:
	if %CircularTabs.get_tab_count() <= 1: return
	
	_animate_spin(direction)
	if GameManager.game_state:
		GameManager.game_state.in_game_options.collection = tab_index
		var sort_type = GameManager.game_state.in_game_options.get("sort_type", 0)
		var collection = tab_index
		GameManager.game_state.in_game_options.collection = tab_index
		var items = GameManager.get_items(false, sort_type, collection)
		set_items(items)


func _on_sort_selected(mod: int) -> void:
	#0 = Smart/Default, 1 = A-Z, 2 = Z-A, 3 = Usable first + A-Z, 4 = Rarity + A-Z, 5 = Quantity + A-Z
	if GameManager.game_state:
		var sort_type = wrapi(GameManager.game_state.in_game_options.get("sort_type", 0) + mod, 0, 5)
		var collection = GameManager.game_state.in_game_options.get("collection", 0)
		GameManager.game_state.in_game_options.sort_type = sort_type
		var items = GameManager.get_items(false, sort_type, collection)
		set_items(items)
	
		match sort_type:
			0: %OrderTab.text = "Order " +  "Smart"
			1: %OrderTab.text = "Order " +  "A-Z"
			2: %OrderTab.text = "Order " +  "Z-A"
			3: %OrderTab.text = "Order " +  "Usable First"
			4: %OrderTab.text = "Order " +  "Rarity"
			5: %OrderTab.text = "Order " +  "Quantity"


func set_items(items: Array) -> void:
	%ItemList.add_items(items)


func _animate_spin(direction: String) -> void:
	if right_decoration_spin:
		right_decoration_spin.kill()
	
	var node = %MainAnimator
	
	if direction == "right":
		node.play("gears_on")
	else:
		node.play_backwards("gears_on")
		
	right_decoration_spin = create_tween()
	right_decoration_spin.tween_property(node, "speed_scale", 0.8, 0.2).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)
	right_decoration_spin.tween_property(node, "speed_scale", 0.0, 0.35).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)
	
	var panel: Node
	if direction == "left":
		panel = %PanelL2Tab
		panel.pivot_offset = Vector2(panel.size.x, panel.size.y * 0.5)
	else:
		panel = %PanelR2Tab
		panel.pivot_offset = Vector2(0, panel.size.y * 0.5)
	var t = create_tween()
	t.tween_property(panel, "scale:x", 1.1, 0.1)
	t.tween_property(panel, "scale:x", 1.0, 0.2)


func select_current() -> void:
	%ItemList.select_current()
