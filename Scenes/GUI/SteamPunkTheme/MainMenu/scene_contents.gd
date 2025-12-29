extends MarginContainer


@export var initial_container: Control
@export var help_label: Label

@onready var main_menu_items: MarginContainer = %MainMenuItems
@onready var party_menu: Control = %PartyMenu


var current_party_buttons_selected: PackedInt32Array = []
var busy: bool = false

var VIEWPORT_SAFETY_MARGIN = 50 # extra margin to move nodes out of screen

signal end()
signal sub_menu_opened()
signal sub_menu_closed()


func _ready() -> void:
	pass


func restart():
	if  party_menu:
		party_menu.restart()
		main_menu_items.restart()


func _select_action_from_main_buttons(id: int) -> void:
	var button: MainMenuButton = main_menu_items.get_button(id)

	if button:
		button.keep_selected_state = true
		button.perform_click()
		
	party_menu.set_order_mode(main_menu_items.current_button_index == 4)
	match main_menu_items.current_button_index:
		0: # Items
			select_party()
		1: # Skills
			select_party()
		2: # Equipment
			select_party()
		3: # Status
			select_party()
		4: # Formation
			select_party()
			current_party_buttons_selected.clear()
		5: # Quests
			pass
		6: # Save
			_show_save_menu(button)
		7: # Options
			pass
		8: # Game End
			pass


func select_party() -> void:
	main_menu_items.disabled()
	party_menu.select()
	GameManager.play_fx("ok")


func _show_equip_menu() -> void:
	# Start Equip Scene
	var actor = party_menu.get_actor_selected() 
	
	main_menu_items.disabled()
	party_menu.disabled()
	sub_menu_opened.emit()
	
	busy = true
	var original_position = initial_container.position
	var t = create_tween()
	t.set_parallel(true)
	t.tween_property(initial_container, "modulate:a", 0.3, 0.15)
	t.tween_property(initial_container, "position:x", initial_container.position.x - initial_container.size.x - VIEWPORT_SAFETY_MARGIN, 0.15)
	var scene_equip_path = RPGSYSTEM.database.system.game_scenes.get("Scene Equipment", "")
	var s = await GameManager.get_scene_from_cache("equipment", scene_equip_path, "", true)
	s.z_index = 10
	s.is_sub_menu = true
	s.exit_tree_when_end = true
	var parent = initial_container.get_parent()
	if s.is_inside_tree():
		parent.remove_child(s)
	parent.add_child(s)
	s.visible = true
	var main_node = s.get_main_scene()
	if main_node:
		main_node.set_actor(actor)
	else:
		printerr("Error. The equip scene has not any method named set_actor")

	## Wait until Equip Scene finished
	await s.end
	#
	## Prepare to back to the main menu
	sub_menu_closed.emit()
	main_menu_items.start()
	initial_container.position.x = -100
#
	t = create_tween()
	t.set_parallel(true)
	t.tween_property(initial_container, "modulate:a", 1.0, 0.15)
	t.tween_property(initial_container, "position", original_position, 0.35).set_trans(Tween.TRANS_SINE)
	#
	await t.finished
	#
	## Fcous desired control
	party_menu.enabled()
	party_menu.select()
	#main_menu_items.select_button()
	GameManager.force_hand_position_over_node(GameManager.get_cursor_manipulator())
	GameManager.force_show_cursor()
	busy = false



func _show_save_menu(button: MainMenuButton) -> void:
	main_menu_items.disabled()
	party_menu.disabled()
	sub_menu_opened.emit()
	
	busy = true
	GameManager.play_fx("select")
	GameManager.set_fx_busy(true)
	var original_position = initial_container.position
	var t = create_tween()
	t.set_parallel(true)
	t.tween_property(initial_container, "modulate:a", 0.3, 0.15)
	t.tween_property(initial_container, "position:x", initial_container.position.x - initial_container.size.x - VIEWPORT_SAFETY_MARGIN, 0.15)
	var scene_equip_path = RPGSYSTEM.database.system.game_scenes.get("Scene Load Game", "")
	var s = await GameManager.get_scene_from_cache("equipment", scene_equip_path, "", true)
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
	
	## Wait until Equip Scene finished
	await s.end
	
	## Prepare to back to the main menu
	sub_menu_closed.emit()
	main_menu_items.start()
	initial_container.position.x = -100
#
	t = create_tween()
	t.set_parallel(true)
	t.tween_property(initial_container, "modulate:a", 1.0, 0.15)
	t.tween_property(initial_container, "position", original_position, 0.35).set_trans(Tween.TRANS_SINE)
	#
	await t.finished
	#
	## Fcous desired control
	main_menu_items.enabled()
	main_menu_items.select_button()
	button.keep_selected_state = false

	#main_menu_items.select_button()
	GameManager.force_hand_position_over_node(GameManager.get_cursor_manipulator())
	GameManager.force_show_cursor()
	GameManager.set_fx_busy(false)
	busy = false


func _on_main_menu_items_begin_click(id: int) -> void:
	if main_menu_items.current_button_index == 4:
		if not id in current_party_buttons_selected:
			current_party_buttons_selected.append(id)
			party_menu.force_selection(id)
			GameManager.play_fx("ok")
		else:
			current_party_buttons_selected.erase(id)
			party_menu.clear_force_selection(id)
			GameManager.play_fx("cancel")
			
		if current_party_buttons_selected.size() == 2:
			busy = true
			party_menu.change_panels(current_party_buttons_selected[0], current_party_buttons_selected[1])
			current_party_buttons_selected.clear()
			
			await party_menu.panels_switched
			
			busy = false


func _cancel_party_menu() -> void:
	if current_party_buttons_selected:
		for id in current_party_buttons_selected:
			party_menu.clear_force_selection(id)
		current_party_buttons_selected.clear()
	GameManager.play_fx("cancel")
	party_menu.disabled()
	main_menu_items.remove_any_keep_state()
	main_menu_items.disable_animations()
	main_menu_items.enabled()
	await main_menu_items.select_button()
	main_menu_items.enable_animations()


func _on_main_menu_items_finish() -> void:
	main_menu_items.disabled()
	party_menu.disabled()
	end.emit()
	party_menu.end()


func _on_party_formation_request(_id: int) -> void:
	var last_party_button_selected = party_menu.current_panel_selected
	party_menu.force_selection(last_party_button_selected)
	party_menu.current_panel_selected = last_party_button_selected
	_on_main_menu_items_begin_click(last_party_button_selected)


func _on_party_menu_clicked(id: int) -> void:
	GameManager.play_fx("ok")
	match main_menu_items.current_button_index:
		0: # Items
			pass
		1: # Skills
			pass
		2: # Equipment
			_show_equip_menu()
		3: # Status
			pass
		4: # Formation
			_on_party_formation_request(id)
			pass
		5: # Quests
			pass
		6: # Save
			pass
		7: # Options
			pass
		8: # Game End
			pass


func _on_main_menu_items_button_hovered(_button: Control, _index: int, tooltip: String) -> void:
	if help_label:
		help_label.text = tooltip
