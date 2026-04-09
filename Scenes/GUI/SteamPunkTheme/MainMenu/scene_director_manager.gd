@tool
extends Node

## Reference to the main menu scene
@export var main_scene: Node

## Reference to the left buttons menu scene
@export var left_buttons_scene: Node

## Reference to the party characters scene
@export var party_scene: Node

## Reference to the items and skills list scene
@export var items_menu_scene: Node

## Reference to the animation player for menu transitions
@export var animation_player: AnimationPlayer

## Reference to the label used for descriptions
@export var help_label: Label

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



#region Others
## Initializes core menu components when the parent becomes visible
func _on_parent_visibility_changed() -> void:
	if Engine.is_editor_hint(): return
	if get_parent().visible:
		%TitleContainer.start()
		%MainMenuScene.restart()
		%BottomMainMenu.restart()



## Cleans up cursor manipulators and destroys the menu structure
func destroy() -> void:
	GameManager.set_cursor_manipulator("")
	$"..".destroy()



## Handles the transition and instantiation of the save/load sub-menu
func _show_save_menu(button: MainMenuButton) -> void:
	if not left_buttons_scene or not party_scene or not main_scene: return
	left_buttons_scene.disabled()
	party_scene.disabled()
	main_scene.sub_menu_opened.emit()
	left_buttons_scene.busy = true
	GameManager.play_fx("select")
	GameManager.set_fx_busy(true)
	var initial_container = main_scene.initial_container
	var original_position = initial_container.position
	var t = create_tween()
	t.set_parallel(true)
	t.tween_property(initial_container, "modulate:a", 0.3, 0.15)
	t.tween_property(initial_container, "position:x", initial_container.position.x - initial_container.size.x - main_scene.VIEWPORT_SAFETY_MARGIN, 0.15)
	var scene_save_path = RPGSYSTEM.database.system.game_scenes.get("Scene Load Game", "")
	var s = await GameManager.get_scene_from_cache("save", scene_save_path, "", true)
	s.z_index = 10
	s.is_sub_menu = true
	s.exit_tree_when_end = true
	var main_node = s.get_main_scene()
	main_node.current_mode = 1
	var parent = initial_container.get_parent()
	if s.is_inside_tree():
		parent.remove_child(s)
	parent.add_child(s)
	s.visible = true
	await s.end
	main_scene.sub_menu_closed.emit()
	left_buttons_scene.start()
	initial_container.position.x = -100
	t = create_tween()
	t.set_parallel(true)
	t.tween_property(initial_container, "modulate:a", 1.0, 0.15)
	t.tween_property(initial_container, "position", original_position, 0.35).set_trans(Tween.TRANS_SINE)
	await t.finished
	left_buttons_scene.enabled()
	left_buttons_scene.select_button()
	button.keep_selected_state = false
	GameManager.force_hand_position_over_node(GameManager.get_cursor_manipulator())
	GameManager.force_show_cursor()
	GameManager.set_fx_busy(false)
	left_buttons_scene.busy = false


func _show_equip_menu() -> void:
	if not left_buttons_scene or not party_scene or not main_scene: return
	var actor = party_scene.get_actor_selected()
	party_scene.disabled()
	main_scene.sub_menu_opened.emit()
	left_buttons_scene.busy = true
	GameManager.play_fx("select")
	GameManager.set_fx_busy(true)
	var initial_container = main_scene.initial_container
	var original_position = initial_container.position
	var t = create_tween()
	t.set_parallel(true)
	t.tween_property(initial_container, "modulate:a", 0.3, 0.15)
	t.tween_property(initial_container, "position:x", initial_container.position.x - initial_container.size.x - main_scene.VIEWPORT_SAFETY_MARGIN, 0.15)
	var scene_equip_path = RPGSYSTEM.database.system.game_scenes.get("Scene Equipment", "")
	var s = await GameManager.get_scene_from_cache("equipment", scene_equip_path, "", true)
	if not s: return
	s.z_index = 10
	s.is_sub_menu = true
	s.exit_tree_when_end = true
	var parent = initial_container.get_parent()
	if s.is_inside_tree():
		parent.remove_child(s)
	parent.add_child(s)
	var main_node = s.get_main_scene()
	if main_node and main_node.has_method("set_actor"):
		main_node.set_actor(actor)
	s.visible = true
	await s.end
	main_scene.sub_menu_closed.emit()
	left_buttons_scene.start()
	initial_container.position.x = -100
	t = create_tween()
	t.set_parallel(true)
	t.tween_property(initial_container, "modulate:a", 1.0, 0.15)
	t.tween_property(initial_container, "position", original_position, 0.35).set_trans(Tween.TRANS_SINE)
	await t.finished
	party_scene.enabled()
	party_scene.select()
	GameManager.force_hand_position_over_node(GameManager.get_cursor_manipulator())
	GameManager.force_show_cursor()
	GameManager.set_fx_busy(false)
	left_buttons_scene.busy = false
#endregion



#region Items and Skills Menu
## Configures and displays the item or skill list menu
func show_item_menu(id: String) -> void:
	if items_menu_scene:
		items_menu_scene.itemlist_id = id
		var cache = items_menu_scene.get_list_cache()
		var items = []
		var collection = 0
		if id == "items":
			var tabs: PackedStringArray = [
				tr("All Itens"), tr("Items"), tr("Weapons"), tr("Armors"), tr("Costumes"), tr("key Items")
			]
			collection = cache.get("collection", 0)
			items_menu_scene.set_tabs(tabs, collection)
			items = GameManager.get_items(false, cache.get("sort_type", 0), collection)
		elif id == "skills":
			var tabs: PackedStringArray = [
				tr("Skills")
			]
			items_menu_scene.set_tabs(tabs, 0)
			if party_scene:
				var actor: GameActor = party_scene.get_actor_selected()
				items = GameManager.get_skills_for_actor(actor, cache.get("sort_type", 0))
		items_menu_scene.set_items(items)
	if animation_player and animation_player.has_animation("Show Item Menu"):
		animation_player.speed_scale = 1.7
		animation_player.play("Show Item Menu")


## Hides the item menu and restores control to the appropriate previous menu
func hide_item_menu() -> void:
	if animation_player and animation_player.has_animation("Hide Item Menu"):
		animation_player.speed_scale = 1.0
		animation_player.play_backwards("Hide Item Menu")
	if items_menu_scene:
		items_menu_scene.set_disabled()
	if previous_active_item == MenuState.ITEMS and left_buttons_scene:
		left_buttons_scene.enabled()
		left_buttons_scene.select_button()
	elif previous_active_item == MenuState.SKILLS_LIST and party_scene:
		previous_active_item = MenuState.SKILLS
		party_scene.enabled()
		party_scene.select()


## Prepares item usage and delegates target selection to the party menu
func _on_items_menu_use_item(item_data: Dictionary) -> void:
	pending_item_data = item_data
	pending_item_type = item_data.get("item_type", -1)
	pending_item_id = item_data.get("item_id", -1)
	if items_menu_scene:
		items_menu_scene.set_disabled()
	if party_scene:
		previous_active_item = MenuState.ITEM_TARGET
		party_scene.enabled()
		party_scene.select()
	var target = item_data.get("target_id", InventoryManager.SCOPE.NONE)
	if target == InventoryManager.SCOPE.ALL:
		var actor_panels = party_scene.get_panels()
		GameManager.cursor_manager.show_multi_cursors(actor_panels, GameManager.get_cursor_manipulator())
		party_scene.set_multi_cursor_mode(true)



## Prepares skill usage and delegates target selection to the party menu
func _on_items_menu_use_skill(skill_data: Dictionary) -> void:
	pending_skill_data = skill_data
	pending_skill_id = skill_data.get("item_id", -1)
	if items_menu_scene:
		items_menu_scene.set_disabled()
	if party_scene:
		previous_active_item = MenuState.SKILL_TARGET
		party_scene.enabled()
		party_scene.select()



## Updates the help label description when an item is focused
func _on_item_list_item_focused(obj: Dictionary) -> void:
	if help_label:
		help_label.text = obj.get("description", "")



## Resets the state and UI if the currently active perishable item rots
func _on_ingame_item_list_active_item_rotted() -> void:
	if previous_active_item == MenuState.ITEM_TARGET:
		var current_qty = 0
		if pending_item_type == 0:
			current_qty = GameManager.inventory_manager.get_item_amount(pending_item_id)
		if current_qty > 0 and items_menu_scene and items_menu_scene.has_method("refresh_and_get_next_perishable"):
			var next_item = await items_menu_scene.refresh_and_get_next_perishable(pending_item_id)
			if not next_item.is_empty():
				pending_item_data = next_item
				return
		previous_active_item = MenuState.ITEMS
		party_scene.disabled()
		if items_menu_scene:
			var cache = items_menu_scene.get_list_cache()
			var items_array = GameManager.get_items(false, cache.get("sort_type", 0), cache.get("collection", 0))
			items_menu_scene.set_items(items_array)
			await get_tree().process_frame
			items_menu_scene.set_enabled()
			items_menu_scene.select_current()
	GameManager.call_deferred("toast_message", tr("Oops! The item you were trying to use got consumed right in front of you!"), ToastManager.ToastPos.BOTTOM_CENTER)
#endregion



#region Main Menu Buttons
## Updates the help label description when a main menu button is hovered
func _on_main_menu_items_button_hovered(_button: Control, _index: int, tooltip: String) -> void:
	if help_label:
		help_label.text = tooltip



## Cleans up active states and emits the final end signal for the menu
func _on_main_menu_items_finish() -> void:
	if not left_buttons_scene or not party_scene or not main_scene: return
	left_buttons_scene.disabled()
	party_scene.disabled()
	main_scene.end.emit()
	party_scene.end()



## Handles navigation routing when a main left button is clicked
func _on_main_menu_items_clicked(id: int) -> void:
	if not left_buttons_scene or not party_scene: return
	var button: MainMenuButton = left_buttons_scene.get_button(id)
	if not button or not button.is_enabled:
		return
	button.keep_selected_state = true
	button.perform_click()
	GameManager.set_cursor_manipulator(GameManager.MANIPULATOR_MODES.NONE)
	GameManager.force_hide_cursor()
	left_buttons_scene.disabled()
	party_scene.set_order_mode(left_buttons_scene.current_button_index == 4)
	previous_active_item = id as MenuState
	match left_buttons_scene.current_button_index:
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
			main_scene.current_party_buttons_selected.clear()
		5:  # Quests
			print("⚠️ This function is under construction.")
			button.keep_selected_state = false
			_select_buttons()
		6: # Save / Load
			_show_save_menu(button)
		7: # Options
			print("⚠️ This function is under construction.")
			button.keep_selected_state = false
			_select_buttons()
		8: # Quit game
			GameManager.restart()


func _select_buttons() -> void:
	left_buttons_scene.enabled()
	left_buttons_scene.select_button()
#endregion



#region Party Menu
## Shifts focus and control to the party selection scene
func select_party() -> void:
	if not left_buttons_scene or not party_scene: return
	var index = left_buttons_scene.current_button_index
	var button = left_buttons_scene.get_button(index)
	if button:
		button.keep_selected_state = true
	left_buttons_scene.disabled()
	party_scene.select()
	GameManager.play_fx("ok")



## Evaluates actions to perform when a party member is clicked based on state
func _on_party_menu_clicked(id: int) -> void:
	if not left_buttons_scene: return
	
	var result: bool = false
	if previous_active_item == MenuState.ITEM_TARGET and pending_item_data:
		var target_id = pending_item_data.get("target_id", InventoryManager.SCOPE.NONE)
		if target_id == InventoryManager.SCOPE.ONE:
			var actor: GameActor = party_scene.get_actor_selected()
			result = await _execute_item_use(actor)
			_animate_party_panel(actor)
		elif target_id == InventoryManager.SCOPE.ALL:
			var actors = party_scene.get_actors()
			for actor: GameActor in actors:
				result = await _execute_item_use(actor, actor == actors[-1])
				_animate_party_panel(actor)
		elif target_id == InventoryManager.SCOPE.RANDOM:
			var number = pending_item_data.get("targets_amount", 0)
			if number > 0:
				var new_actors: Array[GameActor] = []
				var actors = party_scene.get_actors()
				if actors.size <= number:
					new_actors = actors
				else:
					while new_actors.size() < number:
						var actor: GameActor = actors.pick_random()
						if not actor in new_actors:
							new_actors.append(actor)
					
				for actor: GameActor in new_actors:
					if not result:
						result = await _execute_item_use(actor, actor == new_actors[-1])
					else:
						await _execute_item_use(actor, actor == new_actors[-1])
					_animate_party_panel(actor)
		
		if result:
			GameManager.play_fx("ok")
		else:
			GameManager.play_fx("error")
		return
	elif previous_active_item == MenuState.SKILL_TARGET:
		_execute_skill_use(id)
		return
	match left_buttons_scene.current_button_index:
		0: # items
			pass
		1: # Skills
			if party_scene:
				current_skill_user = party_scene.get_actor_selected()
				party_scene.disabled()
				party_scene.hightlight_selected()
			previous_active_item = MenuState.SKILLS_LIST
			show_item_menu("skills")
		2: # Equipment
			_show_equip_menu()
		3: # Status
			print("⚠️ This function is under construction.")
		4: # Formation
			_on_party_formation_request(id)
		5: # Quests
			pass
		6: # Save / Load
			pass
		7: # Options
			pass
		8: # Quit Game
			pass


func _animate_party_panel(actor: GameActor) -> void:
	if party_scene and party_scene.has_method("get_panel_for_actor"):
		var panel = party_scene.get_panel_for_actor(actor)
		if panel:
			if panel.has_method("glow_animation"):
				panel.glow_animation()
			if panel.has_method("shake_animation"):
				panel.shake_animation()



## Handles logic for swapping party member positions
func _on_party_formation_request(_id: int) -> void:
	if not main_scene or not party_scene: return
	var last_party_button_selected = party_scene.current_panel_selected
	party_scene.force_selection(last_party_button_selected)
	party_scene.current_panel_selected = last_party_button_selected
	main_scene._on_main_menu_items_begin_click(last_party_button_selected)



## Handles cancellation inside the party menu returning to previous states
func _on_party_menu_cancel() -> void:
	if not main_scene or not party_scene or not left_buttons_scene or not items_menu_scene: return
	GameManager.play_fx("cancel")
	GameManager.cursor_manager.clear_multi_cursors()
	party_scene.set_multi_cursor_mode(false)
	if previous_active_item == MenuState.ITEM_TARGET:
		previous_active_item = MenuState.ITEMS
		party_scene.disabled()
		await get_tree().process_frame
		items_menu_scene.set_enabled()
		items_menu_scene.select_current()
	elif previous_active_item == MenuState.SKILL_TARGET:
		previous_active_item = MenuState.SKILLS_LIST
		party_scene.disabled()
		await get_tree().process_frame
		items_menu_scene.set_enabled()
		items_menu_scene.select_current()
	elif previous_active_item in [MenuState.SKILLS, MenuState.EQUIPMENT, MenuState.STATUS, MenuState.FORMATION]:
		if main_scene.current_party_buttons_selected:
			for id in main_scene.current_party_buttons_selected:
				party_scene.clear_force_selection(id)
			main_scene.current_party_buttons_selected.clear()
		party_scene.disabled()
		left_buttons_scene.remove_any_keep_state()
		left_buttons_scene.disable_animations()
		left_buttons_scene.enabled()
		await left_buttons_scene.select_button()
		left_buttons_scene.enable_animations()



## Consumes an item and updates lists checking if quantities have reached zero
func _execute_item_use(entity: Variant, remove_item: bool = true) -> bool:
	var simulation = GameManager.action_manager.simulate_use_item(
		null, entity, pending_item_data.item
	)
	if not simulation.callables.is_empty():
		for callable in simulation.callables:
			callable.call()
		if entity.has_signal("parameter_changed"):
			entity.parameter_changed.emit()
	else:
		return false
		
	if pending_item_type == 0 and remove_item:
		GameManager.inventory_manager.remove_item_amount(pending_item_id, 1)
	var current_qty = 1 
	if pending_item_type == 0:
		current_qty = GameManager.inventory_manager.get_item_amount(pending_item_id)
	if current_qty <= 0:
		if items_menu_scene:
			var cache = items_menu_scene.get_list_cache()
			var items_array = GameManager.get_items(false, cache.get("sort_type", 0), cache.get("collection", 0))
			items_menu_scene.set_items(items_array)
		if party_scene.has_method("execute_cancel"):
			party_scene.execute_cancel.call_deferred()
		else:
			_on_party_menu_cancel.call_deferred()
	else:
		if pending_item_data.get("is_perishable", false):
			if items_menu_scene and items_menu_scene.has_method("refresh_and_get_next_perishable"):
				var next_item = await items_menu_scene.refresh_and_get_next_perishable(pending_item_id)
				if not next_item.is_empty():
					pending_item_data = next_item
					if party_scene.has_method("config_hand"):
						party_scene.config_hand.call_deferred()
				else:
					if party_scene.has_method("execute_cancel"):
						party_scene.execute_cancel.call_deferred()
					else:
						_on_party_menu_cancel.call_deferred()
		else:
			pending_item_data["quantity"] = current_qty
			if items_menu_scene and items_menu_scene.has_node("%ItemList"):
				var item_list = items_menu_scene.get_node("%ItemList")
				item_list.queue_redraw()
				
	return true


## Consumes skill MP and updates lists checking if the actor can still cast
func _execute_skill_use(_target_id: int) -> void:
	return
	@warning_ignore("unreachable_code")
	if not current_skill_user: return
	var real_skill = current_skill_user.get_real_skill(pending_skill_id)
	if not real_skill: return
	var mp_cost = real_skill.mp_cost if "mp_cost" in real_skill else 0
	var current_mp = current_skill_user.get_parameter("mp")
	if current_mp >= mp_cost:
		current_skill_user.set_parameter("mp", current_mp - mp_cost)
	current_mp = current_skill_user.get_parameter("mp")
	if current_mp < mp_cost:
		if items_menu_scene:
			var cache = items_menu_scene.get_list_cache()
			var items = GameManager.get_skills_for_actor(current_skill_user, cache.get("sort_type", 0))
			items_menu_scene.set_items(items)
		_on_party_menu_cancel()
	else:
		if items_menu_scene and items_menu_scene.has_node("%ItemList"):
			var item_list = items_menu_scene.get_node("%ItemList")
			item_list.queue_redraw()
#endregion
