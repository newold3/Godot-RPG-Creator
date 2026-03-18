extends MarginContainer


@export var manipulator: String = GameManager.MANIPULATOR_MODES.ITEM_MENU3


## Emitted when the player confirms or clicks an item
signal item_activated(obj: Dictionary)
## Emitted when an item receives focus
signal item_focused(obj: Dictionary)
## Signal emitted when the dialog requests to be closed
signal close_requested()
## Signal emitted when the dialog is closed
@warning_ignore("unused_signal")
signal finished()
## Signal emitted when an item is confirmed for use
signal use_item(item_data: Dictionary)
## Signal emitted when a skill is confirmed for use
signal use_skill(skill_data: Dictionary)

## Signal emitted when an item being actively used rots
signal active_item_rotted()

var is_started: bool = false

var right_decoration_spin: Tween

var itemlist_id: String :
	set(value):
		itemlist_id = value
		if is_node_ready():
			_update_sort_ui()


func _ready() -> void:
	%CircularTabs.manipulator = manipulator
	%ItemList.manipulator = manipulator
	%OrderLeft.manipulator = manipulator
	%OrderRight.manipulator = manipulator
	set_disabled()


func set_enabled() -> void:
	GameManager.set_cursor_manipulator(manipulator)
	modulate = Color.WHITE
	for node in [%CircularTabs, %ItemPaginator, %OrderLeft, %OrderRight]:
		node.enabled = true
		node.manipulator = manipulator
		node.set_process_mode(Node.PROCESS_MODE_INHERIT)
	
	%ItemList.set_enabled(true)


func set_disabled() -> void:
	GameManager.set_cursor_manipulator(GameManager.MANIPULATOR_MODES.NONE)
	modulate = Color(0.85, 0.85, 0.85)
	for node in [%CircularTabs, %ItemPaginator, %OrderLeft, %OrderRight]:
		node.enabled = false
		node.manipulator = GameManager.MANIPULATOR_MODES.NONE
		node.set_process_mode(Node.PROCESS_MODE_DISABLED)
	
	%ItemList.set_enabled(false)


func set_tabs(tabs: PackedStringArray, selected_index: int = 0) -> void:
	%CircularTabs.add_tabs(tabs, selected_index)
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
	t.tween_callback(%ItemList.restore_selection)
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


func _on_item_list_item_focused(obj: Dictionary) -> void:
	if GameManager.game_state:
		var cache = get_list_cache()
		var col = cache.get("collection", 0)
		cache["tabs"][col] = {
			"uid": %ItemList.target_uid,
			"index": %ItemList.target_global_index
		}
	item_focused.emit(obj)


func _on_item_list_close_requested() -> void:
	end()


func _on_circular_tabs_tab_selected(tab_index: int, direction: String) -> void:
	if %CircularTabs.get_tab_count() <= 1: return
	_animate_spin(direction)
	if GameManager.game_state:
		var cache = get_list_cache()
		cache["collection"] = tab_index
		var items = GameManager.get_items(false, cache.get("sort_type", 0), tab_index)
		set_items(items)



func _input(_event: InputEvent) -> void:
	if GameManager.get_cursor_manipulator() == manipulator:
		if ControllerManager.is_action_just_pressed("Button R1"):
			%OrderRight._on_pressed()
			_on_sort_selected(1)
		elif ControllerManager.is_action_just_pressed("Button L1"):
			%OrderLeft._on_pressed()
			_on_sort_selected(-1)


func _update_sort_ui() -> void:
	var is_skills = (itemlist_id == "skills")
	if %OrderLeft: %OrderLeft.visible = not is_skills
	if %OrderRight: %OrderRight.visible = not is_skills
	if %OrderTab:
		%SortContainer.visible = not is_skills
		if not is_skills:
			var cache = get_list_cache()
			var sort_type = cache.get("sort_type", 0)
			match sort_type:
				0: %OrderTab.text = "Order Smart"
				1: %OrderTab.text = "Order A-Z"
				2: %OrderTab.text = "Order Z-A"
				3: %OrderTab.text = "Order Usable First"
				4: %OrderTab.text = "Order Rarity"
				5: %OrderTab.text = "Order Quantity"


# 0 = Smart/Default,	1 = A-Z,		2 = Z-A,		3 = Usable first + A-Z,
# 4 = Rarity + A-Z,		5 = Quantity + A-Z
func _on_sort_selected(mod: int) -> void:
	if GameManager.game_state and itemlist_id != "skills":
		var cache = get_list_cache()
		var sort_type = wrapi(cache.get("sort_type", 0) + mod, 0, 6)
		cache["sort_type"] = sort_type
		var items = GameManager.get_items(false, sort_type, cache.get("collection", 0))
		set_items(items)
		_update_sort_ui()


func set_items(items: Array) -> void:
	var cache = get_list_cache()
	%ItemList.itemlist_id = itemlist_id
	var col = cache.get("collection", 0)
	var tab_data = cache["tabs"].get(col, {})
	%ItemList.target_uid = tab_data.get("uid", "")
	%ItemList.target_global_index = tab_data.get("index", 0)
	%ItemList.add_items(items)
	_update_sort_ui()


func get_list_cache() -> Dictionary:
	if not GameManager.game_state.in_game_options.has("lists_cache"):
		GameManager.game_state.in_game_options["lists_cache"] = {}
	if not GameManager.game_state.in_game_options["lists_cache"].has(itemlist_id):
		GameManager.game_state.in_game_options["lists_cache"][itemlist_id] = {
			"collection": 0,
			"sort_type": 0,
			"tabs": {}
		}
	var cache = GameManager.game_state.in_game_options["lists_cache"][itemlist_id]
	if not cache.has("tabs"):
		cache["tabs"] = {}
	return cache


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


func _on_item_list_active_item_rotted() -> void:
	active_item_rotted.emit()


## Refreshes the list and commands the ItemList to find the next available perishable item
func refresh_and_get_next_perishable(target_item_id: int) -> Dictionary:
	var cache = get_list_cache()
	var items_array = GameManager.get_items(false, cache.get("sort_type", 0), cache.get("collection", 0))
	set_items(items_array)
	return %ItemList.select_next_perishable(target_item_id)


func _on_item_list_use_item(obj: Dictionary) -> void:
	print("USE ITEM: ")
	use_item.emit(obj)


func _on_item_list_use_skill(obj: Dictionary) -> void:
	print("USE SKILL: ")
	use_skill.emit(obj)


func _on_item_list_item_activated(obj: Dictionary) -> void:
	item_activated.emit(obj)
