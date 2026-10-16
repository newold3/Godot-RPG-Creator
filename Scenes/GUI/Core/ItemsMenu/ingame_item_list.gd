class_name GuiCoreIngameItemList
extends MarginContainer

#region Exports & Signals
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
var current_items: Array

var itemlist_id: String :
	set(value):
		itemlist_id = value
		if is_node_ready():
			_update_sort_ui()
#endregion



#region Lifecycle & Initialization
func _ready() -> void:
	if has_node("%CircularTabs"): %CircularTabs.manipulator = manipulator
	if has_node("%ItemList"): %ItemList.manipulator = manipulator
	if has_node("%OrderLeft"): %OrderLeft.manipulator = manipulator
	if has_node("%OrderRight"): %OrderRight.manipulator = manipulator
	ControllerManager.controller_changed.connect(_on_controlled_changed)
	_on_controlled_changed(ControllerManager.current_controller)
	set_disabled()


func _on_controlled_changed(controller_type: ControllerManager.CONTROLLER_TYPE) -> void:
	var is_kbm = (controller_type == ControllerManager.CONTROLLER_TYPE.Keyboard or controller_type == ControllerManager.CONTROLLER_TYPE.Mouse)
	if has_node("%L2Tab"): %L2Tab.text = "⇧+Q" if is_kbm else "L2"
	if has_node("%R2Tab"): %R2Tab.text = "⇧+E" if is_kbm else "R2"
	if has_node("%L1Tab"): %L1Tab.text = "⌃+Q" if is_kbm else "L1"
	if has_node("%R1Tab"): %R1Tab.text = "^+E" if is_kbm else "R1"


func set_enabled() -> void:
	GameManager.set_cursor_manipulator(manipulator)
	modulate = Color.WHITE
	for node_name in ["%CircularTabs", "%ItemPaginator", "%OrderLeft", "%OrderRight"]:
		if has_node(node_name):
			var node = get_node(node_name)
			node.enabled = true
			node.manipulator = manipulator
			node.set_process_mode(Node.PROCESS_MODE_INHERIT)
	
	if has_node("%ItemList"):
		%ItemList.set_enabled(true)


func set_disabled() -> void:
	GameManager.set_cursor_manipulator(GameManager.MANIPULATOR_MODES.NONE)
	modulate = Color(0.85, 0.85, 0.85)
	for node_name in ["%CircularTabs", "%ItemPaginator", "%OrderLeft", "%OrderRight"]:
		if has_node(node_name):
			var node = get_node(node_name)
			node.enabled = false
			node.manipulator = GameManager.MANIPULATOR_MODES.NONE
			node.set_process_mode(Node.PROCESS_MODE_DISABLED)
	
	if has_node("%ItemList"):
		%ItemList.set_enabled(false)


func set_tabs(tabs: PackedStringArray, selected_index: int = 0) -> void:
	if has_node("%CircularTabs"):
		%CircularTabs.add_tabs(tabs, selected_index)
	var has_multiple = tabs.size() > 1
	if has_node("%PanelL2Tab"): %PanelL2Tab.visible = has_multiple
	if has_node("%PanelR2Tab"): %PanelR2Tab.visible = has_multiple
	if has_node("%DecorationTabRight"): %DecorationTabRight.visible = has_multiple
	if has_node("%DecorationTabLeft"): %DecorationTabLeft.visible = has_multiple
#endregion



#region Start / End / Animation
func start() -> void:
	if is_started: return
	is_started = true
	set_enabled()
	_animate_start()


func end() -> void:
	if not is_started: return
	is_started = false
	set_disabled()
	GameManager.play_fx("cancel")
	_animate_end()


## Virtual start animation method; overridable in themes.
func _animate_start() -> void:
	if has_node("%ItemList"):
		%ItemList.restore_selection()


## Virtual end animation method; overridable in themes.
func _animate_end() -> void:
	close_requested.emit()


## Virtual spin animation method; overridable in themes.
func _animate_spin(_direction: String) -> void:
	pass
#endregion



#region Item List Events & Sorting
func _on_item_list_item_focused(obj: Dictionary) -> void:
	if GameManager.game_state and has_node("%ItemList"):
		var cache = get_list_cache()
		var col = cache.get("collection", 0)
		cache["tabs"][col] = {
			"uid": %ItemList.target_uid,
			"index": %ItemList.target_global_index,
			"item_id": obj.get("item_id", -1),
			"item_type": obj.get("item_type", -1)
		}
	item_focused.emit(obj)


func _on_item_list_close_requested() -> void:
	end()


func _on_circular_tabs_tab_selected(tab_index: int, direction: String) -> void:
	if has_node("%CircularTabs") and %CircularTabs.get_tab_count() <= 1: return
	_animate_spin(direction)
	if GameManager.game_state:
		var cache = get_list_cache()
		cache["collection"] = tab_index
		var items = GameManager.get_items(false, cache.get("sort_type", 0), tab_index)
		set_items(items)


func _input(_event: InputEvent) -> void:
	if GameManager.get_cursor_manipulator() == manipulator and has_node("%SortContainer") and %SortContainer.visible:
		if ControllerManager.is_action_just_pressed("Button R1"):
			if has_node("%OrderRight"): %OrderRight._on_pressed()
			_on_sort_selected(1)
		elif ControllerManager.is_action_just_pressed("Button L1"):
			if has_node("%OrderLeft"): %OrderLeft._on_pressed()
			_on_sort_selected(-1)


func _update_sort_ui() -> void:
	var is_skills = (itemlist_id == "skills")
	if has_node("%OrderLeft"): %OrderLeft.visible = not is_skills
	if has_node("%OrderRight"): %OrderRight.visible = not is_skills
	if has_node("%SortContainer") and has_node("%OrderTab"):
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


func _on_sort_selected(mod: int) -> void:
	if has_node("%SortContainer") and not %SortContainer.visible: return
	
	if GameManager.game_state and itemlist_id != "skills":
		var cache = get_list_cache()
		var sort_type = wrapi(cache.get("sort_type", 0) + mod, 0, 6)
		cache["sort_type"] = sort_type
		var items = GameManager.get_items(false, sort_type, cache.get("collection", 0))
		set_items(items)
		_update_sort_ui()


func set_items(items: Array) -> void:
	current_items = items
	if not has_node("%ItemList"): return
	var cache = get_list_cache()
	%ItemList.itemlist_id = itemlist_id
	var col = cache.get("collection", 0)
	
	var tab_data = cache["tabs"].get(col, {})
	var target_item_id = tab_data.get("item_id", -1)
	var target_item_type = tab_data.get("item_type", -1)
	var target_uid = tab_data.get("uid", "")
	
	if itemlist_id == "items" and GameManager.inventory_manager.get("has_new_items_pending_view"):
		if cache.get("sort_type", 0) == 0:
			cache["tabs"].clear()
		GameManager.inventory_manager.has_new_items_pending_view = false
	
	if target_item_id != -1 and target_item_type != -1:
		for i in range(items.size()):
			if items[i].get("item_id") == target_item_id and items[i].get("item_type") == target_item_type:
				if not cache["tabs"].has(col):
					cache["tabs"][col] = {"uid": target_uid, "index": i, "item_id": target_item_id, "item_type": target_item_type}
				else:
					cache["tabs"][col]["index"] = i
					cache["tabs"][col]["item_id"] = target_item_id
					cache["tabs"][col]["item_type"] = target_item_type
				break
				
	var updated_tab_data = cache["tabs"].get(col, {})
	%ItemList.target_uid = updated_tab_data.get("uid", "")
	%ItemList.target_global_index = updated_tab_data.get("index", 0)
	%ItemList.add_items(items)
	_update_sort_ui()


func get_items() -> Array:
	return current_items


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


func select_current() -> void:
	if has_node("%ItemList"):
		%ItemList.select_current()


func _on_item_list_active_item_rotted() -> void:
	if not is_started:
		return
	active_item_rotted.emit()


func refresh_and_get_next_perishable(target_item_id: int) -> Dictionary:
	var cache = get_list_cache()
	var sort_type = cache.get("sort_type", 0)
	var previous_items = get_items()
	var items_array = GameManager.inventory_manager.get_items(false, sort_type, cache.get("collection", 0), previous_items)
	set_items(items_array)
	if has_node("%ItemList"):
		return await %ItemList.select_next_perishable(target_item_id)
	return {}


func _on_item_list_use_item(obj: Dictionary) -> void:
	use_item.emit(obj)


func _on_item_list_use_skill(obj: Dictionary) -> void:
	use_skill.emit(obj)


func _on_item_list_item_activated(obj: Dictionary) -> void:
	item_activated.emit(obj)
#endregion
