class_name GuiCoreLibrary
extends Control

#region StateAndSignals
var book_is_opened: bool = false
var current_book: String = ""
var current_cursor_book: String = ""
var busy: bool = false
var current_book_speed_scale: float = 1.0
var speed_scale_step: float = 40.0
var default_pages_paths: Array[String] = []
var _saved_focus: Control = null
var is_opening_book: bool = false
var _pressed_nav_button: Control = null

signal book_selected(id: String)
signal book_opened()
signal book_closed()
signal button_pressed(button_id: int)
#endregion



#region NodeGetters
func get_book_container() -> Control:
	return get_node_or_null("%Book")


func get_animate_book() -> PageFlip2D:
	return get_node_or_null("%AnimateBook")


func get_main_book() -> PageFlip2D:
	return get_animate_book()


func get_nav_left_button() -> Control:
	return get_node_or_null("%GoToPageLeft")


func get_nav_right_button() -> Control:
	return get_node_or_null("%GoToPageRight")


func get_nav_back_button() -> Control:
	return get_node_or_null("%Back")


func get_books() -> Array:
	var list: Array = []
	for cursor_name in ["%EncyclopediaCursor", "%BestiaryCursor", "%inventoryCursor", "%RecipesCursor", "%MainBookCursor"]:
		if has_node(cursor_name):
			list.append(get_node(cursor_name))
	return list


func get_selectable_books() -> Array:
	var list: Array = []
	for cursor_name in ["%EncyclopediaCursor", "%BestiaryCursor", "%inventoryCursor", "%RecipesCursor"]:
		if has_node(cursor_name):
			list.append(get_node(cursor_name))
	return list


func get_selected_book() -> Control:
	var map = {
		"encyclopedia": "%EncyclopediaCursor",
		"bestiary": "%BestiaryCursor",
		"inventory": "%inventoryCursor",
		"recipes": "%RecipesCursor",
		"main_book": "%MainBookCursor"
	}
	var node_name = map.get(current_book, "")
	if not node_name.is_empty() and has_node(node_name):
		return get_node(node_name)
	return null


func select(book: Control) -> void:
	if book in get_books():
		if book.has_focus():
			return
		book.grab_focus()
#endregion



#region VirtualPresentationHooks
func _get_bestiary_scene_path() -> String:
	return ""


func _get_recipes_scene_path() -> String:
	return ""


func _get_items_scene_path() -> String:
	return ""


func _setup_presentation() -> void:
	pass


func _apply_book_visuals(_type: String, _is_initial: bool, _open_immediately: bool, _on_finish: Callable) -> void:
	_on_finish.call()


func _on_open_book_presentation() -> void:
	pass


func _on_close_book_presentation() -> void:
	pass


func _on_turn_page_presentation(_direction: String) -> void:
	pass


func _show_tooltip_over_book(_book_id: String) -> void:
	pass


func _hide_tooltip_over_book() -> void:
	pass


func _on_book_cursor_focused(_book_id: String) -> void:
	pass


func _on_book_cursor_unfocused(_book_id: String) -> void:
	pass


func _on_main_book_cursor_focused() -> void:
	pass


func _on_main_book_cursor_unfocused() -> void:
	pass


func _on_nav_button_focused(_button_id: int) -> void:
	pass
#endregion



#region Lifecycle
func _ready() -> void:
	var animate_book = get_animate_book()
	if animate_book:
		default_pages_paths = animate_book.pages_paths.duplicate()
		BookAPI.disable_book(animate_book)
		BookAPI.set_interaction_lock(animate_book, true)
	
	_setup_presentation()
	update_book.call_deferred("encyclopedia", true)
	
	StaticSignal.connect_static_signal("target_item_list_item_hovered_local", _on_custom_target_item_list_item_hovered_local)
	StaticSignal.connect_static_signal("target_item_list_item_unhovered_local", _on_custom_target_item_list_item_unhovered_local)


func _process(_delta: float) -> void:
	if not book_is_opened: return
	
	if ControllerManager.is_direction_just_pressed("left") or ControllerManager.is_direction_just_released("right") or ControllerManager.is_confirm_just_pressed(false, [], false):
		current_book_speed_scale = 1.0
		
	_update_navigation_buttons()
#endregion



#region NavigationAndBookState
func _update_navigation_buttons() -> void:
	if not book_is_opened: return
	
	var animate_book = get_animate_book()
	if not animate_book: return
	
	var is_animating = animate_book.is_animating
	
	var max_spread: int = animate_book.total_spreads - 1
	if animate_book.limit_max_pages > 0:
		max_spread = (animate_book.limit_max_pages - 1) / 2
		
	var is_at_last = (animate_book.current_spread >= max_spread)
	var left_btn = get_nav_left_button()
	var right_btn = get_nav_right_button()
	var back_btn = get_nav_back_button()
	
	if is_animating:
		if left_btn and not left_btn.disabled: left_btn.disabled = true
		if right_btn and not right_btn.disabled: right_btn.disabled = true
		if back_btn and not back_btn.disabled: back_btn.disabled = true
	else:
		if left_btn and left_btn.disabled: left_btn.disabled = false
		if right_btn and right_btn.disabled != is_at_last:
			right_btn.disabled = is_at_last
		if back_btn and back_btn.disabled: back_btn.disabled = false


func turn_page_to(direction: String) -> void:
	if not book_is_opened: return
	
	var animate_book = get_animate_book()
	if not animate_book: return
		
	if direction == "left":
		if animate_book.current_spread == 0:
			BookAPI.set_book_speed(animate_book, 1.0)
		else:
			BookAPI.set_book_speed(animate_book, current_book_speed_scale)
			current_book_speed_scale = min(current_book_speed_scale + get_process_delta_time() * speed_scale_step, 3.0)
		_on_turn_page_presentation("left")
		BookAPI.prev_page(animate_book)
	elif direction == "right":
		current_book_speed_scale = min(current_book_speed_scale + get_process_delta_time() * speed_scale_step, 3.0)
		BookAPI.set_book_speed(animate_book, current_book_speed_scale)
		_on_turn_page_presentation("right")
		BookAPI.next_page(animate_book)
	else:
		current_book_speed_scale = 1.0
		_on_turn_page_presentation("none")


func _on_page_flip_2d_book_opened() -> void:
	book_is_opened = true
	busy = false
	book_opened.emit()


func _on_page_flip_2d_book_closed() -> void:
	book_is_opened = false
	busy = false
	var container = get_book_container()
	if container:
		container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	book_closed.emit()


func open_book() -> void:
	if busy or book_is_opened:
		return
		
	busy = true
	is_opening_book = true
	var container = get_book_container()
	if container:
		container.mouse_filter = Control.MOUSE_FILTER_STOP
	current_book_speed_scale = 1.0
	
	var animate_book = get_animate_book()
	if animate_book:
		BookAPI.set_book_speed(animate_book, current_book_speed_scale)
		if animate_book.current_spread == -1:
			BookAPI.next_page(animate_book)
		else:
			BookAPI.go_to_spread(animate_book, 0, true)
		
	_on_open_book_presentation()


func close_book() -> void:
	if busy or not book_is_opened:
		return
		
	busy = true
	is_opening_book = false
	_saved_focus = null
	_pressed_nav_button = null
	var container = get_book_container()
	if container:
		container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	current_book_speed_scale = 1.0
	
	var animate_book = get_animate_book()
	if animate_book:
		BookAPI.set_book_speed(animate_book, current_book_speed_scale)
		BookAPI.go_to_spread(animate_book, -1, true)
	
	_on_close_book_presentation()


func update_book(type: String, is_initial_update: bool = false, open_immediately: bool = false) -> bool:
	if current_book == type: return false
	
	busy = true
	var book = get_animate_book()
	if not book:
		busy = false
		return false
	
	match type:
		"bestiary":
			var pages = RPGSYSTEM.database.enemies.slice(1)
			var paths: Array[String] = []
			paths.resize(pages.size() * 2 + 3)
			paths.fill(_get_bestiary_scene_path())
			book.limit_max_pages = pages.size() * 2 + 1
			book.set_new_pages(paths)
		"recipes":
			var recipes_count: int = GameManager.game_state.crafting_recipes.size() if GameManager.game_state else 0
			var paths: Array[String] = []
			if recipes_count == 0:
				paths.resize(3)
			else:
				paths.resize(recipes_count * 2 + 3)
			paths.fill(_get_recipes_scene_path())
			book.limit_max_pages = max(1, recipes_count * 2 + 1)
			book.set_new_pages(paths)
		"inventory":
			var db = RPGSYSTEM.database
			var items_count: int = 0
			if db:
				items_count = db.items.size() + db.weapons.size() + db.armors.size() + db.costumes.size()
			var paths: Array[String] = []
			if items_count == 0:
				paths.resize(3)
			else:
				paths.resize(items_count * 2 + 3)
			paths.fill(_get_items_scene_path())
			book.limit_max_pages = max(1, items_count * 2 + 1)
			book.set_new_pages(paths)
		_:
			book.limit_max_pages = -1
			book.set_new_pages(default_pages_paths)
	
	current_book = type
	
	_apply_book_visuals(type, is_initial_update, open_immediately, func():
		busy = false
		book_selected.emit(type)
		if open_immediately:
			open_book()
	)
	
	return true
#endregion



#region EventHandlers
func _on_encyclopedia_cursor_gui_input(event: InputEvent) -> void:
	if busy or book_is_opened: return
	if event.is_action_pressed("Mouse Left"): update_book("encyclopedia")


func _on_bestiary_cursor_gui_input(event: InputEvent) -> void:
	if busy or book_is_opened: return
	if event.is_action_pressed("Mouse Left"): update_book("bestiary")


func _on_inventory_cursor_gui_input(event: InputEvent) -> void:
	if busy or book_is_opened: return
	if event.is_action_pressed("Mouse Left"): update_book("inventory")


func _on_recipes_cursor_gui_input(event: InputEvent) -> void:
	if busy or book_is_opened: return
	if event.is_action_pressed("Mouse Left"): update_book("recipes")


func _on_encyclopedia_cursor_focus_entered() -> void:
	_on_book_cursor_focused("encyclopedia")
	book_selected.emit("encyclopedia")
	_show_tooltip_over_book("encyclopedia")


func _on_bestiary_cursor_focus_entered() -> void:
	_on_book_cursor_focused("bestiary")
	book_selected.emit("bestiary")
	_show_tooltip_over_book("bestiary")


func _on_inventory_cursor_focus_entered() -> void:
	_on_book_cursor_focused("inventory")
	book_selected.emit("inventory")
	_show_tooltip_over_book("inventory")


func _on_recipes_cursor_focus_entered() -> void:
	_on_book_cursor_focused("recipes")
	book_selected.emit("recipes")
	_show_tooltip_over_book("recipes")


func _on_encyclopedia_cursor_focus_exited() -> void:
	_on_book_cursor_unfocused("encyclopedia")
	_hide_tooltip_over_book()


func _on_bestiary_cursor_focus_exited() -> void:
	_on_book_cursor_unfocused("bestiary")
	_hide_tooltip_over_book()


func _on_inventory_cursor_focus_exited() -> void:
	_on_book_cursor_unfocused("inventory")
	_hide_tooltip_over_book()


func _on_recipes_cursor_focus_exited() -> void:
	_on_book_cursor_unfocused("recipes")
	_hide_tooltip_over_book()


func _on_main_book_cursor_focus_entered() -> void:
	_on_main_book_cursor_focused()
	book_selected.emit("main_book")


func _on_main_book_cursor_focus_exited() -> void:
	_on_main_book_cursor_unfocused()


func _on_custom_target_item_list_item_hovered_local(local_position: Vector2, target_node: Control) -> void:
	var animate_book = get_animate_book()
	if not animate_book: return
	
	var is_left_page = false
	var sv = target_node.get_viewport()
	if sv and sv.name == "Slot1":
		is_left_page = true
		
	var viewport_pos: Vector2 = target_node.global_position + local_position
	var global_pos: Vector2 = animate_book.viewport_to_global_curved(viewport_pos, is_left_page)
	var sprite_offset: Vector2 = Vector2(-9.0, 2)
	
	var instant = false
	if is_opening_book:
		instant = true
		is_opening_book = false
		
	GameManager.set_manual_cursor_override(target_node, global_pos + sprite_offset, instant)


func _on_custom_target_item_list_item_unhovered_local(target_node: Control) -> void:
	if BookAPI.is_busy(): return
	GameManager.clear_manual_cursor_override(target_node)


func _on_animate_book_ended_page_flip_animation() -> void:
	_update_navigation_buttons()

	if not book_is_opened:
		GameManager.clear_manual_cursor_override()
		select(get_selected_book())
		if GameManager.cursor_manager and GameManager.cursor_manager.hand_cursor:
			GameManager.cursor_manager.hand_cursor.forced_target = null
		GameManager.force_show_cursor()
		GameManager.force_hand_position_over_node(GameManager.get_cursor_manipulator())
		_saved_focus = null
		_pressed_nav_button = null
	else:
		var left_btn = get_nav_left_button()
		var right_btn = get_nav_right_button()
		var back_btn = get_nav_back_button()
		
		if _saved_focus and is_instance_valid(_saved_focus):
			if not _saved_focus.disabled and _saved_focus.is_visible_in_tree():
				_saved_focus.grab_focus()
			else:
				if left_btn: left_btn.grab_focus()
			_saved_focus = null
			
		if GameManager.cursor_manager and GameManager.cursor_manager.hand_cursor:
			GameManager.cursor_manager.hand_cursor.forced_target = null
			
		GameManager.force_show_cursor()
		var focused = get_viewport().gui_get_focus_owner()
		if left_btn and focused == left_btn:
			_on_go_to_page_left_focus_entered()
		elif right_btn and focused == right_btn:
			_on_go_to_page_right_focus_entered()
		elif back_btn and focused == back_btn:
			_on_back_focus_entered()


func _on_animate_book_started_page_flip_animation() -> void:
	var animate_book = get_animate_book()
	var last_focus = get_viewport().gui_get_focus_owner()
	var g_left = get_nav_left_button()
	var g_right = get_nav_right_button()
	var b_back = get_nav_back_button()
	
	if animate_book and animate_book.current_spread == 0 and last_focus not in [g_left, g_right, b_back]:
		if g_left:
			g_left.grab_focus()
			last_focus = g_left
		
	if _pressed_nav_button:
		_saved_focus = _pressed_nav_button
		_pressed_nav_button = null
	elif last_focus in [g_left, g_right, b_back]:
		_saved_focus = last_focus
		
	if GameManager.cursor_manager and GameManager.cursor_manager.hand_cursor:
		GameManager.cursor_manager.hand_cursor.forced_target = _saved_focus
		GameManager.cursor_manager.hand_cursor.pause_reposition = false
		if _saved_focus:
			GameManager.cursor_manager.hand_cursor.force_show()
			
	if not book_is_opened or is_opening_book:
		GameManager.force_hide_cursor()
		
	_update_navigation_buttons()


func _on_go_to_page_left_pressed() -> void:
	_pressed_nav_button = get_nav_left_button()
	button_pressed.emit(0)


func _on_go_to_page_right_pressed() -> void:
	_pressed_nav_button = get_nav_right_button()
	button_pressed.emit(1)


func _on_back_pressed() -> void:
	_pressed_nav_button = get_nav_back_button()
	button_pressed.emit(2)


func _on_go_to_page_left_focus_entered() -> void:
	_on_nav_button_focused(0)


func _on_go_to_page_right_focus_entered() -> void:
	_on_nav_button_focused(1)


func _on_back_focus_entered() -> void:
	_on_nav_button_focused(2)


func end() -> void:
	var animate_book = get_animate_book()
	if animate_book:
		animate_book.z_index = 1
#endregion
