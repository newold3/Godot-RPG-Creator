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
signal item_menu_requested(id: String)


func _ready() -> void:
	pass


func restart():
	if  party_menu:
		party_menu.restart()
		main_menu_items.restart()


func select_party() -> void:
	var button = main_menu_items.get_button(main_menu_items.current_button_index)
	if button:
		button.keep_selected_state = true
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


func _on_main_menu_items_finish() -> void:
	main_menu_items.disabled()
	party_menu.disabled()
	end.emit()
	party_menu.end()


func _show_item_menu(id: String) -> void:
	item_menu_requested.emit(id)
