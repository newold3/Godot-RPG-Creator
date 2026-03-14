@tool
extends Node

@export var main_scene: Node
@export var left_buttons_scene: Node
@export var party_scene: Node
@export var items_menu_scene: Node
@export var animation_player: AnimationPlayer
@export var help_label: Label


func _on_parent_visibility_changed() -> void:
	if Engine.is_editor_hint(): return
	
	if get_parent().visible:
		%TitleContainer.start()
		%MainMenuScene.restart()
		%BottomMainMenu.restart()


func destroy() -> void:
	GameManager.set_cursor_manipulator("")
	$"..".destroy()


#region items/skills menu
func show_item_menu(_id: String) -> void:
	if animation_player and animation_player.has_animation("Show Item Menu"):
		animation_player.speed_scale = 1.7
		animation_player.play("Show Item Menu")


func hide_item_menu() -> void:
	if animation_player and animation_player.has_animation("Hide Item Menu"):
		animation_player.speed_scale = 1.0
		animation_player.play_backwards("Hide Item Menu")


func _on_item_list_item_activated(_item_type: int, _item_id: int) -> void:
	pass


func _on_item_list_item_focused(_item_type: int, _item_id: int) -> void:
	if help_label:
		help_label.text = "Show help for item %s with ID %s" % [_item_type, _item_id]

#endregion


#region Left Buttons
func _on_main_menu_items_button_hovered(_button: Control, _index: int, tooltip: String) -> void:
	if help_label:
		help_label.text = tooltip


func _on_main_menu_items_finish() -> void:
	if not left_buttons_scene or not party_scene or not main_scene: return
	
	left_buttons_scene.disabled()
	party_scene.disabled()
	main_scene.end.emit()
	party_scene.end()


func _on_main_menu_items_clicked(id: int) -> void:
	if not left_buttons_scene or not party_scene: return
	
	var button: MainMenuButton = left_buttons_scene.get_button(id)
	
	if not button or not button.is_enabled:
		return

	button.keep_selected_state = true
	button.perform_click()
		
	party_scene.set_order_mode(left_buttons_scene.current_button_index == 4)
	match left_buttons_scene.current_button_index:
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
			left_buttons_scene.current_party_buttons_selected.clear()
		5: # Quests
			pass
		6: # Save
			_show_save_menu(button)
		7: # Options
			pass
		8: # Game End
			GameManager.restart()


func select_party() -> void:
	if not left_buttons_scene or not party_scene: return
	
	var index = left_buttons_scene.current_button_index
	var button = left_buttons_scene.get_button(index)
	if button:
		button.keep_selected_state = true
	left_buttons_scene.disabled()
	party_scene.select()
	GameManager.play_fx("ok")


func _show_save_menu(button: MainMenuButton) -> void:
	if not left_buttons_scene or not party_scene: return
	
	left_buttons_scene.disabled()
	party_scene.disabled()
	left_buttons_scene.sub_menu_opened.emit()
	
	left_buttons_scene.busy = true
	GameManager.play_fx("select")
	GameManager.set_fx_busy(true)
	var initial_container = left_buttons_scene.initial_container
	var original_position = initial_container.position
	var t = create_tween()
	t.set_parallel(true)
	t.tween_property(initial_container, "modulate:a", 0.3, 0.15)
	t.tween_property(initial_container, "position:x", initial_container.position.x - initial_container.size.x - left_buttons_scene.VIEWPORT_SAFETY_MARGIN, 0.15)
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
	left_buttons_scene.sub_menu_closed.emit()
	left_buttons_scene.start()
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
	left_buttons_scene.enabled()
	left_buttons_scene.select_button()
	button.keep_selected_state = false

	GameManager.force_hand_position_over_node(GameManager.get_cursor_manipulator())
	GameManager.force_show_cursor()
	GameManager.set_fx_busy(false)
	
	left_buttons_scene.busy = false
#endregion
