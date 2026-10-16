@tool
class_name GuiCoreMainMenuDirector
extends Node

#region ExportsAndVariables
## Reference to the main menu scene
@export var main_scene: Node

## Reference to the left buttons menu scene
@export var left_buttons_scene: Node

## Reference to the party characters scene
@export var party_scene: Node

## Reference to the items and skills list scene
@export var items_menu_scene: Node

## Enumerator defining the logical states for menu navigation
enum MenuState {
	ITEMS = 0,
	SKILLS = 1,
	EQUIPMENT = 2,
	STATUS = 3,
	FORMATION = 4,
	QUESTS = 5,
	SAVE = 6,
	OPTIONS = 7,
	GAME_END = 8,
	SKILLS_LIST = 11,
	ITEM_TARGET = 20,
	SKILL_TARGET = 21
}

var current_button_selected: int = 0
var current_party_selected: int = 0
var previous_active_item: MenuState = MenuState.ITEMS
var pending_item_id: int = -1
var pending_item_type: int = -1
var pending_skill_id: int = -1
var current_skill_user: Variant
var pending_item_data: Dictionary = {}
var pending_skill_data: Dictionary = {}
#endregion

#region Signals
signal help_text_changed(text: String)
#endregion

#region VirtualHooks
## Override in themes to play item menu opening animation
func play_show_item_menu_animation() -> void:
	pass


## Override in themes to play item menu closing animation
func play_hide_item_menu_animation() -> void:
	pass


## Override in themes to animate party panel (e.g. glow or shake on item/skill use)
func animate_party_panel(_actor: GameActor) -> void:
	pass


## Sets the current help / tooltip text, emitting signal and calling theme hook
func set_help_text(text: String) -> void:
	help_text_changed.emit(text)
	update_help_text(text)


## Override in themes to update the help label or tooltip display
func update_help_text(_text: String) -> void:
	pass


## Override in themes to provide theme-specific library scene
func get_library_scene() -> PackedScene:
	return null


## Override in themes to provide theme-specific status scene
func get_status_scene() -> PackedScene:
	return null


## Override in themes to provide theme-specific quests scene
func get_quests_scene() -> PackedScene:
	return null


## Override in themes to provide theme-specific professions scene
func get_professions_scene() -> PackedScene:
	return null


## Override in themes to provide theme-specific options scene
func get_options_scene() -> PackedScene:
	return null


## Override in themes to provide theme-specific extra slot scene
func get_extra_slot_scene() -> PackedScene:
	return null


## Override in themes for extra components when menu becomes visible
func on_parent_became_visible() -> void:
	if main_scene and main_scene.has_method("restart"):
		main_scene.restart()
#endregion

#region LifecycleAndSetup
func _ready() -> void:
	if GameManager.inventory_manager and not GameManager.inventory_manager.perishable_item_rotted.is_connected(_on_global_item_rotted):
		GameManager.inventory_manager.perishable_item_rotted.connect(_on_global_item_rotted)


func _exit_tree() -> void:
	if GameManager.inventory_manager and GameManager.inventory_manager.perishable_item_rotted.is_connected(_on_global_item_rotted):
		GameManager.inventory_manager.perishable_item_rotted.disconnect(_on_global_item_rotted)


## Initializes core menu components when the parent becomes visible
func _on_parent_visibility_changed() -> void:
	if Engine.is_editor_hint(): return
	var p = get_parent()
	if p and p.visible:
		on_parent_became_visible()


## Cleans up cursor manipulators and destroys the menu structure
func destroy() -> void:
	GameManager.set_cursor_manipulator("")
	var p = get_parent()
	if p and p.has_method("destroy"):
		p.destroy()
#endregion

#region SubmenuTransitions
func get_submenu_container() -> Control:
	if main_scene:
		if "initial_container" in main_scene and main_scene.initial_container is Control:
			return main_scene.initial_container
		if main_scene is Control:
			return main_scene
	return null


func _open_submenu(sub_scene: Node, on_setup: Callable = Callable(), on_restore: Callable = Callable()) -> void:
	if not left_buttons_scene or not party_scene or not main_scene or not sub_scene:
		GameManager.set_fx_busy(false)
		return
		
	if left_buttons_scene.has_method("disabled"): left_buttons_scene.disabled()
	if party_scene.has_method("disabled"): party_scene.disabled()
	if main_scene.has_signal("sub_menu_opened"): main_scene.sub_menu_opened.emit()
	if "busy" in left_buttons_scene: left_buttons_scene.busy = true
	
	GameManager.play_fx("select")
	GameManager.set_fx_busy(true)
	
	var container = get_submenu_container()
	if not container:
		GameManager.set_fx_busy(false)
		return
		
	var host_parent = container.get_parent()
	if not host_parent:
		GameManager.set_fx_busy(false)
		return

	sub_scene.z_index = 10
	if "is_sub_menu" in sub_scene:
		sub_scene.is_sub_menu = true
	if "exit_tree_when_end" in sub_scene:
		sub_scene.exit_tree_when_end = true
		
	if sub_scene.is_inside_tree():
		sub_scene.get_parent().remove_child(sub_scene)
	host_parent.add_child(sub_scene)
	
	if on_setup.is_valid():
		on_setup.call(sub_scene)
		
	sub_scene.visible = true

	if main_scene.has_method("animate_submenu_open"):
		main_scene.animate_submenu_open()
	
	GameManager.set_fx_busy(false)

	var close_started: Array[bool] = [false]
	var trigger_close_animation = func():
		if close_started[0]:
			return
		close_started[0] = true
		if is_instance_valid(container):
			container.visible = true
		if main_scene and main_scene.has_signal("sub_menu_closed"):
			main_scene.sub_menu_closed.emit()
		if left_buttons_scene and left_buttons_scene.has_method("start"):
			left_buttons_scene.start()
		if main_scene and main_scene.has_method("animate_submenu_close"):
			main_scene.animate_submenu_close()

	if sub_scene.has_signal("starting_end"):
		sub_scene.starting_end.connect(trigger_close_animation, CONNECT_ONE_SHOT)
	if sub_scene.has_signal("closing_started"):
		sub_scene.closing_started.connect(trigger_close_animation, CONNECT_ONE_SHOT)

	if sub_scene.has_signal("end"):
		var end_done: Array[bool] = [false]
		var mark_done = func(): end_done[0] = true
		sub_scene.end.connect(mark_done, CONNECT_ONE_SHOT)
		if sub_scene.has_signal("tree_exited"):
			sub_scene.tree_exited.connect(mark_done, CONNECT_ONE_SHOT)
		while not end_done[0] and is_instance_valid(sub_scene) and sub_scene.is_inside_tree():
			await get_tree().process_frame

	trigger_close_animation.call()

	if main_scene and "is_closing_animating" in main_scene:
		while main_scene.is_closing_animating:
			await get_tree().process_frame
			
	GameManager.set_fx_busy(true)
			
	if on_restore.is_valid():
		await on_restore.call()
		
	GameManager.force_hand_position_over_node(GameManager.get_cursor_manipulator())
	GameManager.force_show_cursor()
	GameManager.set_fx_busy(false)
	if "busy" in left_buttons_scene: left_buttons_scene.busy = false


## Handles the transition and instantiation of the save/load sub-menu
func _show_save_menu(button: Control) -> void:
	var scene_save_path = RPGSYSTEM.database.system.game_scenes.get("Scene Load Game", "")
	var s = await GameManager.get_scene_from_cache("save", scene_save_path, "", true)
	if not s:
		return
	await _open_submenu(s, func(node):
		var main_node = node.get_main_scene() if node.has_method("get_main_scene") else null
		if main_node and "current_mode" in main_node:
			main_node.current_mode = 1
	, func():
		if left_buttons_scene.has_method("enabled"): left_buttons_scene.enabled()
		if left_buttons_scene.has_method("select_button"): left_buttons_scene.select_button()
		if button and "keep_selected_state" in button:
			button.keep_selected_state = false
	)


func _show_equip_menu() -> void:
	var actor = party_scene.get_actor_selected() if party_scene and party_scene.has_method("get_actor_selected") else null
	var scene_equip_path = RPGSYSTEM.database.system.game_scenes.get("Scene Equipment", "")
	var s = await GameManager.get_scene_from_cache("equipment", scene_equip_path, "", true)
	if not s:
		return
	await _open_submenu(s, func(node):
		var main_node = node.get_main_scene() if node.has_method("get_main_scene") else null
		if main_node and main_node.has_method("set_actor"):
			main_node.set_actor(actor)
	, func():
		if party_scene.has_method("enabled"): party_scene.enabled()
		if party_scene.has_method("select"): party_scene.select()
	)


func _show_library_menu() -> void:
	var lib_scene = get_library_scene()
	if not lib_scene:
		return
	var s = lib_scene.instantiate()
	if not s:
		return
	await _open_submenu(s, Callable(), func():
		if left_buttons_scene.has_method("enabled"): left_buttons_scene.enabled()
		if left_buttons_scene.has_method("select_button"): left_buttons_scene.select_button()
	)


func _show_status_menu() -> void:
	var actor = party_scene.get_actor_selected() if party_scene and party_scene.has_method("get_actor_selected") else null
	var status_scene = get_status_scene()
	if not status_scene:
		return
	var s = status_scene.instantiate()
	if not s:
		return
	await _open_submenu(s, func(node):
		var target = node
		if node.has_node("Manager"): target = node.get_node("Manager")
		elif node.has_method("get_main_scene"): target = node.get_main_scene()
		if target and target.has_method("set_actor"):
			target.set_actor(actor)
	, func():
		if party_scene.has_method("enabled"): party_scene.enabled()
		if party_scene.has_method("select"): party_scene.select()
	)


func _show_quests_menu(button: Control) -> void:
	var quests_scene = get_quests_scene()
	if not quests_scene:
		if button and "keep_selected_state" in button: button.keep_selected_state = false
		_select_buttons()
		return
	var s = quests_scene.instantiate()
	if not s:
		if button and "keep_selected_state" in button: button.keep_selected_state = false
		_select_buttons()
		return
	await _open_submenu(s, Callable(), func():
		if left_buttons_scene.has_method("enabled"): left_buttons_scene.enabled()
		if left_buttons_scene.has_method("select_button"): left_buttons_scene.select_button()
		if button and "keep_selected_state" in button:
			button.keep_selected_state = false
	)


func _show_professions_menu(button: Control) -> void:
	var prof_scene = get_professions_scene()
	if not prof_scene:
		if button and "keep_selected_state" in button: button.keep_selected_state = false
		_select_buttons()
		return
	var s = prof_scene.instantiate()
	if not s:
		if button and "keep_selected_state" in button: button.keep_selected_state = false
		_select_buttons()
		return
	await _open_submenu(s, Callable(), func():
		if left_buttons_scene.has_method("enabled"): left_buttons_scene.enabled()
		if left_buttons_scene.has_method("select_button"): left_buttons_scene.select_button()
		if button and "keep_selected_state" in button:
			button.keep_selected_state = false
	)


func _show_options_menu(button: Control) -> void:
	var options_scene = get_options_scene()
	if not options_scene:
		if button and "keep_selected_state" in button: button.keep_selected_state = false
		_select_buttons()
		return
	var s = options_scene.instantiate()
	if not s:
		if button and "keep_selected_state" in button: button.keep_selected_state = false
		_select_buttons()
		return
	await _open_submenu(s, Callable(), func():
		if left_buttons_scene.has_method("enabled"): left_buttons_scene.enabled()
		if left_buttons_scene.has_method("select_button"): left_buttons_scene.select_button()
		if button and "keep_selected_state" in button:
			button.keep_selected_state = false
	)


func _show_extra_slot_menu(button: Control) -> void:
	var extra_scene = get_extra_slot_scene()
	if not extra_scene:
		if button and "keep_selected_state" in button: button.keep_selected_state = false
		_select_buttons()
		return
	var s = extra_scene.instantiate()
	if not s:
		if button and "keep_selected_state" in button: button.keep_selected_state = false
		_select_buttons()
		return
	await _open_submenu(s, Callable(), func():
		if left_buttons_scene.has_method("enabled"): left_buttons_scene.enabled()
		if left_buttons_scene.has_method("select_button"): left_buttons_scene.select_button()
		if button and "keep_selected_state" in button:
			button.keep_selected_state = false
	)
#endregion

#region ItemsAndSkillsMenu
## Configures and displays the item or skill list menu
func show_item_menu(id: String) -> void:
	if items_menu_scene:
		if "itemlist_id" in items_menu_scene:
			items_menu_scene.itemlist_id = id
		var cache = items_menu_scene.get_list_cache() if items_menu_scene.has_method("get_list_cache") else {}
		var items = []
		var collection = 0
		if id == "items":
			var tabs: PackedStringArray = [
				tr("All Itens"), tr("Items"), tr("Weapons"), tr("Armors"), tr("Costumes"), tr("key Items")
			]
			collection = cache.get("collection", 0)
			if items_menu_scene.has_method("set_tabs"):
				items_menu_scene.set_tabs(tabs, collection)
			items = GameManager.get_items(false, cache.get("sort_type", 0), collection)
			items_menu_scene.set_meta("visual_item_cache", items)
		elif id == "skills":
			var tabs: PackedStringArray = [tr("Skills")]
			if items_menu_scene.has_method("set_tabs"):
				items_menu_scene.set_tabs(tabs, 0)
			if party_scene and party_scene.has_method("get_actor_selected"):
				var actor: GameActor = party_scene.get_actor_selected()
				items = GameManager.get_skills_for_actor(actor, cache.get("sort_type", 0))
		if items_menu_scene.has_method("set_items"):
			items_menu_scene.set_items(items)
	play_show_item_menu_animation()


## Hides the item menu and restores control to the appropriate previous menu
func hide_item_menu() -> void:
	play_hide_item_menu_animation()
	if items_menu_scene and items_menu_scene.has_method("set_disabled"):
		items_menu_scene.set_disabled()
	if previous_active_item == MenuState.ITEMS and left_buttons_scene:
		if left_buttons_scene.has_method("enabled"): left_buttons_scene.enabled()
		if left_buttons_scene.has_method("select_button"): left_buttons_scene.select_button()
	elif previous_active_item == MenuState.SKILLS_LIST and party_scene:
		previous_active_item = MenuState.SKILLS
		if party_scene.has_method("enabled"): party_scene.enabled()
		if party_scene.has_method("select"): party_scene.select()


## Prepares item usage and delegates target selection to the party menu
func _on_items_menu_use_item(item_data: Dictionary) -> void:
	pending_item_data = item_data
	pending_item_type = item_data.get("item_type", -1)
	pending_item_id = item_data.get("item_id", -1)
	if items_menu_scene and items_menu_scene.has_method("set_disabled"):
		items_menu_scene.set_disabled()
	if party_scene:
		previous_active_item = MenuState.ITEM_TARGET
		if party_scene.has_method("enabled"): party_scene.enabled()
		if party_scene.has_method("select"): party_scene.select()
	var target = item_data.get("target_id", InventoryManager.SCOPE.NONE)
	if target == InventoryManager.SCOPE.ALL and party_scene:
		var actor_panels = party_scene.get_panels() if party_scene.has_method("get_panels") else []
		GameManager.cursor_manager.show_multi_cursors(actor_panels, GameManager.get_cursor_manipulator())
		if party_scene.has_method("set_multi_cursor_mode"):
			party_scene.set_multi_cursor_mode(true)


## Prepares skill usage and delegates target selection to the party menu
func _on_items_menu_use_skill(skill_data: Dictionary) -> void:
	pending_skill_data = skill_data
	pending_skill_id = skill_data.get("item_id", -1)
	if items_menu_scene and items_menu_scene.has_method("set_disabled"):
		items_menu_scene.set_disabled()
	if party_scene:
		previous_active_item = MenuState.SKILL_TARGET
		if party_scene.has_method("enabled"): party_scene.enabled()
		if party_scene.has_method("select"): party_scene.select()


## Updates the help label description when an item is focused
func _on_item_list_item_focused(obj: Dictionary) -> void:
	set_help_text(obj.get("description", ""))
	
	if GameManager.game_state:
		GameManager.game_state.last_item_used = {
			"id": obj.get("item_id", -1),
			"type": obj.get("item_type", -1)
		}
	
	var actors = []
	for id: int in GameManager.game_state.current_party:
		var actor: GameActor = GameManager.get_actor(id)
		actors.append(actor)
	
	evaluate_item_for_actors(obj, actors)


## Resets the state and UI if the currently active perishable item rots
func _on_ingame_item_list_active_item_rotted() -> void:
	var holding_item_rotted: bool = false
	if previous_active_item == MenuState.ITEM_TARGET:
		var current_qty: int = 0
		if pending_item_type == 0:
			current_qty = GameManager.inventory_manager.get_item_amount(pending_item_id)
		if current_qty > 0:
			if items_menu_scene and items_menu_scene.has_method("get_list_cache"):
				var cache = items_menu_scene.get_list_cache()
				var previous_items = items_menu_scene.get_items() if items_menu_scene.has_method("get_items") else []
				var items_array = GameManager.inventory_manager.get_items(false, cache.get("sort_type", 0), cache.get("collection", 0), previous_items)
				if items_menu_scene.has_method("set_items"):
					items_menu_scene.set_items(items_array)
			return
		holding_item_rotted = true
		if items_menu_scene and items_menu_scene.has_method("refresh_and_get_next_perishable"):
			var next_item = await items_menu_scene.refresh_and_get_next_perishable(pending_item_id)
			if not next_item.is_empty():
				pending_item_data = next_item
				return
		previous_active_item = MenuState.ITEMS
		if party_scene and party_scene.has_method("disabled"): party_scene.disabled()
		GameManager.play_fx("cancel")
	if previous_active_item == MenuState.ITEMS:
		if items_menu_scene:
			var cache = items_menu_scene.get_list_cache() if items_menu_scene.has_method("get_list_cache") else {}
			var previous_items = items_menu_scene.get_items() if items_menu_scene.has_method("get_items") else []
			var items_array = GameManager.inventory_manager.get_items(false, cache.get("sort_type", 0), cache.get("collection", 0), previous_items)
			if items_menu_scene.has_method("set_items"): items_menu_scene.set_items(items_array)
			await get_tree().process_frame
			if items_menu_scene.has_method("set_enabled"): items_menu_scene.set_enabled()
			if items_menu_scene.has_method("select_current"): items_menu_scene.select_current()
	if holding_item_rotted:
		GameManager.call_deferred("toast_message", tr("Oops!\nThe item you were trying to use got consumed right in front of you!"), ToastManager.ToastPos.BOTTOM_CENTER)
#endregion

#region MainMenuButtons
## Updates the help label description when a main menu button is hovered
func _on_main_menu_items_button_hovered(_button: Control, _index: int, tooltip: String) -> void:
	set_help_text(tooltip)


## Cleans up active states and emits the final end signal for the menu
func _on_main_menu_items_finish() -> void:
	if not left_buttons_scene or not party_scene or not main_scene: return
	if left_buttons_scene.has_method("disabled"): left_buttons_scene.disabled()
	if party_scene.has_method("disabled"): party_scene.disabled()
	if main_scene.has_signal("end"): main_scene.end.emit()
	if party_scene.has_method("end"): party_scene.end()


## Handles navigation routing when a main left button is clicked
func _on_main_menu_items_clicked(id: int) -> void:
	if not left_buttons_scene or not party_scene: return
	var button: Control = left_buttons_scene.get_button(id) if left_buttons_scene.has_method("get_button") else null
	if not button or ("is_enabled" in button and not button.is_enabled):
		return
	if "keep_selected_state" in button: button.keep_selected_state = true
	if button.has_method("perform_click"): button.perform_click()
	GameManager.set_cursor_manipulator(GameManager.MANIPULATOR_MODES.NONE)
	GameManager.force_hide_cursor()
	if left_buttons_scene.has_method("disabled"): left_buttons_scene.disabled()
	var current_idx = left_buttons_scene.current_button_index if "current_button_index" in left_buttons_scene else id
	if party_scene.has_method("set_order_mode"):
		party_scene.set_order_mode(current_idx == 4)
	previous_active_item = id as MenuState

	match current_idx:
		0: # Items
			show_item_menu("items")
		1: # Skills
			select_party()
		2: # Equipment
			select_party()
		3: # Status
			select_party()
		4: # Formation
			select_party()
			if main_scene and "current_party_buttons_selected" in main_scene:
				main_scene.current_party_buttons_selected.clear()
		5:  # Quests
			_show_quests_menu(button)
		6: # Save / Load
			_show_save_menu(button)
		7: # Options
			_show_options_menu(button)
		8: # Quit game
			GameManager.restart()
		9: # Professions
			_show_professions_menu(button)
		10: # Library
			_show_library_menu()
		11: # ???????????
			_show_extra_slot_menu(button)


func _select_buttons() -> void:
	if left_buttons_scene:
		if left_buttons_scene.has_method("enabled"): left_buttons_scene.enabled()
		if left_buttons_scene.has_method("select_button"): left_buttons_scene.select_button()
#endregion

#region PartyMenuEvents
## Shifts focus and control to the party selection scene
func select_party() -> void:
	if not left_buttons_scene or not party_scene: return
	var index = left_buttons_scene.current_button_index if "current_button_index" in left_buttons_scene else 0
	var button = left_buttons_scene.get_button(index) if left_buttons_scene.has_method("get_button") else null
	if button and "keep_selected_state" in button:
		button.keep_selected_state = true
	if left_buttons_scene.has_method("disabled"): left_buttons_scene.disabled()
	if party_scene.has_method("select"): party_scene.select()
	GameManager.play_fx("ok")


## Evaluates actions to perform when a party member is clicked based on state
func _on_party_menu_clicked(id: int) -> void:
	if not left_buttons_scene: return
	
	var result: bool = false
	if previous_active_item == MenuState.ITEM_TARGET and pending_item_data:
		var target_id = pending_item_data.get("target_id", InventoryManager.SCOPE.NONE)
		var targets: Array = []
		
		if target_id == InventoryManager.SCOPE.ONE:
			var actor: GameActor = party_scene.get_actor_selected() if party_scene.has_method("get_actor_selected") else null
			if actor: targets.append(actor)
			
		elif target_id == InventoryManager.SCOPE.ALL:
			targets = party_scene.get_actors() if party_scene.has_method("get_actors") else []
			
		elif target_id == InventoryManager.SCOPE.RANDOM:
			var number = pending_item_data.get("targets_amount", 0)
			if number > 0:
				var actors = party_scene.get_actors() if party_scene.has_method("get_actors") else []
				if actors.size() <= number:
					GameManager.is_simulation = true
					targets = actors.duplicate()
					GameManager.is_simulation = false
				else:
					while targets.size() < number:
						var actor: GameActor = actors.pick_random()
						if not actor in targets:
							targets.append(actor)
							
		if not targets.is_empty():
			result = await _execute_item_use(targets)
			for actor in targets:
				_animate_party_panel(actor)
		
		if result:
			GameManager.play_fx("ok")
		else:
			GameManager.play_fx("error")
		return
		
	elif previous_active_item == MenuState.SKILL_TARGET:
		var target_id = pending_skill_data.get("target_id", InventoryManager.SCOPE.NONE)
		var targets: Array = []
		
		if target_id == InventoryManager.SCOPE.ONE:
			var actor: GameActor = party_scene.get_actor_selected() if party_scene.has_method("get_actor_selected") else null
			if actor: targets.append(actor)
			
		elif target_id == InventoryManager.SCOPE.ALL:
			targets = party_scene.get_actors() if party_scene.has_method("get_actors") else []
			
		elif target_id == InventoryManager.SCOPE.RANDOM:
			var number = pending_skill_data.get("targets_amount", 0)
			if number > 0:
				var actors = party_scene.get_actors() if party_scene.has_method("get_actors") else []
				if actors.size() <= number:
					GameManager.is_simulation = true
					targets = actors.duplicate()
					GameManager.is_simulation = false
				else:
					while targets.size() < number:
						var actor: GameActor = actors.pick_random()
						if not actor in targets:
							targets.append(actor)
							
		if not targets.is_empty():
			result = _execute_skill_use(targets)
			for actor in targets:
				_animate_party_panel(actor)
				
		if result:
			GameManager.play_fx("ok")
		else:
			GameManager.play_fx("error")
		return
		
	var current_idx = left_buttons_scene.current_button_index if "current_button_index" in left_buttons_scene else 0
	match current_idx:
		0:
			pass
		1:
			if party_scene:
				current_skill_user = party_scene.get_actor_selected() if party_scene.has_method("get_actor_selected") else null
				if party_scene.has_method("disabled"): party_scene.disabled()
				if party_scene.has_method("hightlight_selected"): party_scene.hightlight_selected()
			previous_active_item = MenuState.SKILLS_LIST
			show_item_menu("skills")
		2:
			_show_equip_menu()
		3:
			_show_status_menu()
		4:
			_on_party_formation_request(id)
		5, 6, 7, 8, 9, 10, 11:
			pass


func _animate_party_panel(actor: GameActor) -> void:
	animate_party_panel(actor)


## Handles logic for swapping party member positions
func _on_party_formation_request(id: int) -> void:
	if not main_scene or not party_scene: return
	party_scene.current_panel_selected = id
	if main_scene.has_method("_on_main_menu_items_begin_click"):
		main_scene._on_main_menu_items_begin_click(id)


## Handles cancellation inside the party menu returning to previous states
func _on_party_menu_cancel() -> void:
	if not main_scene or not party_scene or not left_buttons_scene or not items_menu_scene: return
	GameManager.play_fx("cancel")
	if GameManager.cursor_manager:
		GameManager.cursor_manager.clear_multi_cursors()
	if party_scene.has_method("set_multi_cursor_mode"):
		party_scene.set_multi_cursor_mode(false)
	if previous_active_item == MenuState.ITEM_TARGET:
		previous_active_item = MenuState.ITEMS
		if party_scene.has_method("disabled"): party_scene.disabled()
		await get_tree().process_frame
		if items_menu_scene.has_method("set_enabled"): items_menu_scene.set_enabled()
		if items_menu_scene.has_method("select_current"): items_menu_scene.select_current()
	elif previous_active_item == MenuState.SKILL_TARGET:
		previous_active_item = MenuState.SKILLS_LIST
		if party_scene.has_method("disabled"): party_scene.disabled()
		await get_tree().process_frame
		if items_menu_scene.has_method("set_enabled"): items_menu_scene.set_enabled()
		if items_menu_scene.has_method("select_current"): items_menu_scene.select_current()
	elif previous_active_item in [MenuState.SKILLS, MenuState.EQUIPMENT, MenuState.STATUS, MenuState.FORMATION]:
		if "current_party_buttons_selected" in main_scene and main_scene.current_party_buttons_selected:
			for id in main_scene.current_party_buttons_selected:
				if party_scene.has_method("clear_force_selection"):
					party_scene.clear_force_selection(id)
			main_scene.current_party_buttons_selected.clear()
		if party_scene.has_method("disabled"): party_scene.disabled()
		if left_buttons_scene.has_method("remove_any_keep_state"): left_buttons_scene.remove_any_keep_state()
		if left_buttons_scene.has_method("disable_animations"): left_buttons_scene.disable_animations()
		if left_buttons_scene.has_method("enabled"): left_buttons_scene.enabled()
		if left_buttons_scene.has_method("select_button"): await left_buttons_scene.select_button()
		if left_buttons_scene.has_method("enable_animations"): left_buttons_scene.enable_animations()
#endregion

#region ItemAndSkillExecution
## Called globally when any item rots to update the lists immediately and handle target cancellation
func _on_global_item_rotted(_item: Variant, _converted_id: int) -> void:
	if not items_menu_scene or not ("is_started" in items_menu_scene and items_menu_scene.is_started): return
	if items_menu_scene.get("itemlist_id") != "items": return
	
	var cache = items_menu_scene.get_list_cache() if items_menu_scene.has_method("get_list_cache") else {}
	var previous_items = items_menu_scene.get_items() if items_menu_scene.has_method("get_items") else []
	var items_array = GameManager.inventory_manager.get_items(false, cache.get("sort_type", 0), cache.get("collection", 0), previous_items)
	if items_menu_scene.has_method("set_items"): items_menu_scene.set_items(items_array)
	
	if items_menu_scene.has_node("%ItemList"):
		var item_list = items_menu_scene.get_node("%ItemList")
		item_list.queue_redraw()
		
	if previous_active_item == MenuState.ITEM_TARGET:
		var current_qty = 0
		if pending_item_type == 0:
			current_qty = GameManager.inventory_manager.get_item_amount(pending_item_id)
			
		if current_qty <= 0:
			if items_menu_scene.has_method("refresh_and_get_next_perishable"):
				var next_item = await items_menu_scene.refresh_and_get_next_perishable(pending_item_id)
				if not next_item.is_empty():
					pending_item_data = next_item
					return
					
			previous_active_item = MenuState.ITEMS
			if party_scene and party_scene.has_method("disabled"): party_scene.disabled()
			GameManager.play_fx("cancel")
			
			if items_menu_scene.has_node("%ItemList"):
				var item_list = items_menu_scene.get_node("%ItemList")
				if "is_restoring" in item_list:
					while item_list.is_restoring:
						await get_tree().process_frame
			else:
				await get_tree().process_frame
				
			if items_menu_scene.has_method("set_enabled"): items_menu_scene.set_enabled()
			if items_menu_scene.has_method("select_current"): items_menu_scene.select_current()
			GameManager.call_deferred("toast_message", tr("Oops!\nThe item you were trying to use got consumed right in front of you!"), ToastManager.ToastPos.BOTTOM_CENTER)


## Consumes an item and updates lists checking if quantities have reached zero
func _execute_item_use(entity: Variant, remove_item: bool = true) -> bool:
	var targets: Array = []
	if typeof(entity) == TYPE_ARRAY:
		targets = entity
	else:
		targets = [entity]

	var any_success: bool = false
	var all_callables: Array[Callable] = []
	var successful_targets: Array = []

	for t in targets:
		if pending_item_type == 0:
			var scope_status = pending_item_data.get("scope_status", 0)
			
			var is_dead = false
			if t.has_method("get_current_parameter"):
				is_dead = t.get_current_parameter("hp") <= 0
			elif "params" in t:
				is_dead = t.params.hp <= 0
			elif "current_states" in t:
				for s in t.current_states:
					if s.id == 1:
						is_dead = true
						break
						
			if scope_status == 0 and is_dead:
				continue
			if scope_status == 1 and not is_dead:
				continue

		var simulation = GameManager.action_manager.simulate_use_item(null, t, pending_item_data.item)

		if simulation.get("success", false):
			any_success = true
			if simulation.has("callables"):
				all_callables.append_array(simulation.callables)
			successful_targets.append(t)

	if not any_success:
		return false

	if not all_callables.is_empty():
		for callable in all_callables:
			callable.call()
			
		for t in successful_targets:
			if t.has_signal("parameter_changed"):
				t.parameter_changed.emit()

	var is_consumable: bool = pending_item_data.get("consumable", true)
	if pending_item_type == 0 and remove_item and is_consumable:
		GameManager.inventory_manager.remove_item_amount(pending_item_id, 1)

	var current_qty = 1 

	if pending_item_type == 0:
		current_qty = GameManager.inventory_manager.get_item_amount(pending_item_id) if is_consumable else pending_item_data.get("quantity", 1)

	if current_qty <= 0:
		if items_menu_scene:
			var cache = items_menu_scene.get_list_cache() if items_menu_scene.has_method("get_list_cache") else {}
			var previous_items = items_menu_scene.get_items() if items_menu_scene.has_method("get_items") else []
			var items_array = GameManager.inventory_manager.get_items(false, cache.get("sort_type", 0), cache.get("collection", 0), previous_items)
			if items_menu_scene.has_method("set_items"): items_menu_scene.set_items(items_array)
			
			if items_menu_scene.has_node("%ItemList"):
				var item_list = items_menu_scene.get_node("%ItemList")
				if "is_restoring" in item_list:
					while item_list.is_restoring:
						await get_tree().process_frame

		if party_scene and party_scene.has_method("execute_cancel"):
			party_scene.execute_cancel.call_deferred()
		else:
			_on_party_menu_cancel.call_deferred()
	else:
		if pending_item_data.get("is_perishable", false):
			if items_menu_scene and items_menu_scene.has_method("refresh_and_get_next_perishable"):
				var next_item = await items_menu_scene.refresh_and_get_next_perishable(pending_item_id)

				if not next_item.is_empty():
					pending_item_data = next_item
					if party_scene and party_scene.has_method("config_hand"):
						party_scene.config_hand.call_deferred()
				else:
					if party_scene and party_scene.has_method("execute_cancel"):
						party_scene.execute_cancel.call_deferred()
					else:
						_on_party_menu_cancel.call_deferred()
		else:
			pending_item_data["quantity"] = current_qty

			if items_menu_scene:
				var cache = items_menu_scene.get_list_cache() if items_menu_scene.has_method("get_list_cache") else {}
				var previous_items = items_menu_scene.get_items() if items_menu_scene.has_method("get_items") else []
				var items_array = GameManager.inventory_manager.get_items(false, cache.get("sort_type", 0), cache.get("collection", 0), previous_items)
				if items_menu_scene.has_method("set_items"): items_menu_scene.set_items(items_array)

				if items_menu_scene.has_node("%ItemList"):
					var item_list = items_menu_scene.get_node("%ItemList")
					item_list.queue_redraw()
					if "is_restoring" in item_list:
						while item_list.is_restoring:
							await get_tree().process_frame

	return true


## Consumes skill MP and updates lists checking if the actor can still cast
func _execute_skill_use(targets: Array) -> bool:
	if not current_skill_user: return false
	
	var real_skill = pending_skill_data.get("real_item")
	
	if not real_skill:
		if current_skill_user.has_method("get_real_skill"):
			real_skill = current_skill_user.get_real_skill(pending_skill_id)
		else:
			var uid = RPGSYSTEM.id_to_uid("skills", pending_skill_id)
			real_skill = RPGSYSTEM.get_data("skills", uid if uid != -1 else pending_skill_id)
		
	if not real_skill: return false
	
	var mp_cost = real_skill.mp_cost if "mp_cost" in real_skill else 0
	var tp_cost = real_skill.tp_cost if "tp_cost" in real_skill else 0
	
	var current_mp = current_skill_user.get_current_parameter("mp") if current_skill_user.has_method("get_current_parameter") else current_skill_user.params.mp
	var current_tp = current_skill_user.get_current_parameter("tp") if current_skill_user.has_method("get_current_parameter") else current_skill_user.params.tp
	
	if current_mp < mp_cost or current_tp < tp_cost:
		return false

	var any_success: bool = false
	var all_callables: Array[Callable] = []
	var successful_targets: Array = []

	for t in targets:
		var scope_status = real_skill.scope.status if real_skill.scope else 0
		
		var is_dead = false
		if t.has_method("get_current_parameter"):
			is_dead = t.get_current_parameter("hp") <= 0
		elif "params" in t:
			is_dead = t.params.hp <= 0
		elif "current_states" in t:
			for s in t.current_states:
				if s.id == 1:
					is_dead = true
					break
					
		if scope_status == 0 and is_dead:
			continue
		if scope_status == 1 and not is_dead:
			continue

		var simulation = GameManager.action_manager.simulate_use_skill(current_skill_user, t, pending_skill_id)

		if simulation.get("success", false):
			any_success = true
			if simulation.has("callables"):
				all_callables.append_array(simulation.callables)
			successful_targets.append(t)

	if not any_success:
		return false

	if not all_callables.is_empty():
		for callable in all_callables:
			callable.call()
			
		for t in successful_targets:
			if t.has_signal("parameter_changed"):
				t.parameter_changed.emit()

	if mp_cost > 0:
		if current_skill_user.has_method("set_current_parameter"):
			current_skill_user.set_current_parameter("mp", current_mp - mp_cost)
		else:
			current_skill_user.params.mp -= mp_cost
			
	if tp_cost > 0:
		if current_skill_user.has_method("set_current_parameter"):
			current_skill_user.set_current_parameter("tp", current_tp - tp_cost)
		else:
			current_skill_user.params.tp -= tp_cost
			
	if current_skill_user.has_signal("parameter_changed"):
		current_skill_user.parameter_changed.emit()

	current_mp = current_skill_user.get_current_parameter("mp") if current_skill_user.has_method("get_current_parameter") else current_skill_user.params.mp
	current_tp = current_skill_user.get_current_parameter("tp") if current_skill_user.has_method("get_current_parameter") else current_skill_user.params.tp
	
	if items_menu_scene:
		var cache = items_menu_scene.get_list_cache() if items_menu_scene.has_method("get_list_cache") else {}
		var items_array = GameManager.get_skills_for_actor(current_skill_user, cache.get("sort_type", 0)) if GameManager.has_method("get_skills_for_actor") else []
		if items_array.is_empty() and is_instance_valid(GameManager.get("actor_stats_manager")):
			items_array = GameManager.actor_stats_manager.get_skills_for_actor(current_skill_user, cache.get("sort_type", 0))
		if items_menu_scene.has_method("set_items"): items_menu_scene.set_items(items_array)
		
		if items_menu_scene.has_node("%ItemList"):
			var item_list = items_menu_scene.get_node("%ItemList")
			if item_list.has_method("select_current"):
				item_list.select_current.call_deferred()
			item_list.queue_redraw()
	
	if current_mp < mp_cost or current_tp < tp_cost:
		if party_scene and party_scene.has_method("execute_cancel"):
			party_scene.execute_cancel.call_deferred()
		else:
			_on_party_menu_cancel.call_deferred()

	return true
#endregion

#region ItemEvaluation
## Evaluates the selected item against a list of available actors to determine equip status and stat changes.
func evaluate_item_for_actors(item_data: Dictionary, available_actors: Array) -> Array:
	var evaluation_results: Array = []
	
	if not item_data.has("item") or not item_data.has("real_item"):
		return evaluation_results
		
	var game_item = item_data["item"]
	var item_id = item_data["item_id"]
	var slot_id = 0
	
	for actor in available_actors:
		var can_equip_item: bool = false
		
		if actor.has_method("can_equip"):
			for i in actor.current_gear.size():
				can_equip_item = actor.can_equip(i, item_id)
				if can_equip_item:
					slot_id = i
					break
			
		if not can_equip_item:
			evaluation_results.append({
				"actor": actor,
				"can_equip": false,
				"comparison_result": -1
			})
			continue
			
		GameManager.is_simulation = true
		var copy_actor = actor.duplicate_deep(Resource.DEEP_DUPLICATE_ALL)
		GameManager.is_simulation = false
		
		var level = game_item.level if "level" in game_item else 1
		copy_actor._set_equip(slot_id, game_item.id, level)
		
		var result: int = actor.compare_stats_to(copy_actor)
		
		evaluation_results.append({
			"actor": actor,
			"can_equip": true,
			"comparison_result": result,
			"slot": slot_id
		})
		
	return evaluation_results
#endregion
