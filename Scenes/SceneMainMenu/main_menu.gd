class_name MainGameMenu
extends WindowBase


var main_left_buttons_tween: Tween
var other_tweens: Array = []

var is_enabled: bool = false

var last_party_button_selected: int = -1
var current_party_buttons_selected: PackedInt32Array = []

var game_play_colon_visible: bool = true
var game_play_colon_timer: float = 0.0
var game_play_colon_delay: float = 0.5


@onready var help_label: Label = %HelpLabel
@onready var party_menu: Control = %PartyMenu
@onready var main_menu_items: MarginContainer = %MainMenuItems
@onready var initial_container: Control = %InitialContainer


func _ready() -> void:
	visibility_changed.connect(_on_visibility_changed)
	free_when_end = false

	config_title()
	_set_gold()
	_set_time()
	_set_map_name()
	_set_chapter_name()
	
	
	GameManager.set_text_config(self, false)
	GameManager.set_text_config(%HelpLabel)
	
	start()


func _set_gold() -> void:
	var icon_path: String = RPGSYSTEM.database.system.currency_info.get("icon", "")
	var icon_name: String = RPGSYSTEM.database.system.currency_info.get("name", "")
	if ResourceLoader.exists(icon_path):
		%GoldIcon.texture = load(icon_path)
	else:
		%GoldIcon.texture = null
	%GoldLabel.text = icon_name
	if GameManager.game_state:
		%GoldNumber.text = GameManager.get_number_formatted(GameManager.game_state.current_gold, 2)
	else:
		%GoldNumber.text = "0"


func _set_time() -> void:
	if GameManager.game_state:
		var time = GameManager.format_game_time(GameManager.game_state.stats.play_time, game_play_colon_visible)
		%GameTimeValue.text = time
	else:
		%GameTimeValue.text = "0H : 0M : 0S"


func _camel_case_to_spaced(text: String) -> String:
	var regex = RegEx.new()
	regex.compile("([a-z])([A-Z])")
	return regex.sub(text, "$1 $2", true)


func _set_map_name() -> void:
	if GameManager.current_map:
		%MapName.text = _camel_case_to_spaced(RPGMapsInfo.get_map_name_from_id(GameManager.current_map.internal_id))
	else:
		%MapName.text = ""


func _set_chapter_name() -> void:
	if GameManager.game_state:
		%ChapterName.text = GameManager.game_state.game_chapter_name
	else:
		%ChapterName.text = ""


func start() -> void:
	%MainMenuItems.set_starting()
	await get_tree().process_frame
	%MainMenuAnimationPlayer.play("Start")
	
	super()
	
	ControllerManager.set_focusable_control_threshold(500, 500)
	
	main_menu_items.start()
	party_menu.restart()
	
	if party_menu.get_panel_count() > last_party_button_selected and last_party_button_selected >= 0:
		party_menu.current_panel_selected = last_party_button_selected
	
	var mat: ShaderMaterial = %PostProcessEffects.get_material()
	mat.set_shader_parameter("shader_parameter/warp_amount", 0.0)
	var t = create_tween()
	t.set_parallel(true)
	t.tween_property(mat, "shader_parameter/warp_amount", 0.04, 0.35)
	t.finished.connect(other_tweens.erase.bind(t))
	other_tweens.append(t)
	
	await main_menu_items.started_animation_finished
	
	main_menu_items.select_button()
		
	var manipulator = GameManager.get_cursor_manipulator()
	GameManager.force_hand_position_over_node(manipulator)
	GameManager.force_show_cursor()
	
	is_enabled = true


func end() -> void:
	if not scene_started:
		return
		
	super()
	
	ControllerManager.set_focusable_control_threshold()
	
	is_enabled = false
	
	
	var focus_owner = get_viewport().gui_get_focus_owner()
	if focus_owner:
		focus_owner.release_focus()
	
	GameManager.set_cursor_manipulator("")
	
	for t: Tween in other_tweens:
		if t.is_valid():
			t.kill()
	other_tweens.clear()
	
	GameManager.hide_cursor(true, self)
	
	var mat: ShaderMaterial = $PostProcessEffects.get_material()
	var t = create_tween()
	t.tween_property(mat, "shader_parameter/warp_amount", 0.0, 0.35)
	
	GameManager.play_fx("cancel")


func _process(delta: float) -> void:
	game_play_colon_timer += delta
	if game_play_colon_timer >= game_play_colon_delay:
		game_play_colon_timer = 0.0
		game_play_colon_visible = !game_play_colon_visible
	_set_time()
	
	if not is_enabled or busy:
		return
	
	#  Main Button Actions
	if GameManager.get_cursor_manipulator() == GameManager.MANIPULATOR_MODES.MAIN_MENU_MAIN_BUTTONS:
		if ControllerManager.is_cancel_pressed([KEY_0, KEY_KP_0]):
			end()
		elif ControllerManager.is_confirm_just_pressed(false, [KEY_KP_ENTER]):
			call_deferred("_select_action_from_main_buttons")
	elif GameManager.get_cursor_manipulator() == GameManager.MANIPULATOR_MODES.PARTY_MENU:
		if ControllerManager.is_cancel_just_pressed([KEY_0, KEY_KP_0]):
			_cancel_party_menu()
		elif ControllerManager.is_confirm_just_pressed(true, [KEY_KP_ENTER]):
			_select_action_from_party_panels()


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


func _select_action_from_main_buttons() -> void:
	var button: MainMenuButton = main_menu_items.get_button(main_menu_items.current_button_index)
	if button:
		button.perform_click()
		
	party_menu.set_order_mode(main_menu_items.current_button_index == 4)
	match main_menu_items.current_button_index:
		0, 1, 2, 3, 4: # Items, Skills, Equipment, Status, Formation
			select_party()
			if main_menu_items.current_button_index == 4:
				current_party_buttons_selected.clear()
		5: # Quests
			pass
		6: # Save
			pass
		7: # Options
			pass
		8: # Game End
			pass


func _select_action_from_party_panels() -> void:
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
			party_menu.force_selection(last_party_button_selected)
			party_menu.current_panel_selected = last_party_button_selected
			_on_main_menu_items_begin_click(last_party_button_selected)
			pass
		5: # Quests
			pass
		6: # Save
			pass
		7: # Options
			pass
		8: # Game End
			pass


func _show_equip_menu() -> void:
	# Start Equip Scene
	var actor = party_menu.get_actor_selected() 
	busy = true
	var original_position = initial_container.position
	var t = create_tween()
	t.set_parallel(true)
	t.tween_property(initial_container, "modulate:a", 0.3, 0.15)
	t.tween_property(initial_container, "position:x", initial_container.position.x - initial_container.size.x, 0.15)
	var s = await GameManager.get_scene_from_cache("equipment", "res://Scenes/EquipScene/default_equip_scene.tscn", "", true)
	s.z_index = 10
	s.is_sub_menu = true
	s.exit_tree_when_end = true
	var parent = get_parent()
	if s.is_inside_tree():
		parent.remove_child(s)
	parent.add_child(s)
	s.hide_background()
	s.visible = true
	s.set_actor(actor)
	
	# Wait until Equip Scene finished
	await s.start_ended
	
	# Prepare to back to the main menu
	main_menu_items.start()
	initial_container.position.x = -100

	t = create_tween()
	t.set_parallel(true)
	t.tween_property(initial_container, "modulate:a", 1.0, 0.15)
	t.tween_property(initial_container, "position", original_position, 0.35).set_trans(Tween.TRANS_SINE)
	
	await main_menu_items.started_animation_finished
	
	# Fcous desired control
	party_menu.disabled()
	main_menu_items.select_button()
	GameManager.force_hand_position_over_node(GameManager.get_cursor_manipulator())
	GameManager.force_show_cursor()
	busy = false


func select_party() -> void:
	main_menu_items.disabled()
	party_menu.select()
	GameManager.play_fx("ok")


func config_title() -> void:
	pass
	#icon_gear_container.title = RPGSYSTEM.database.terms.search_message("Main Menu")


func _on_visibility_changed() -> void:
	if visible:
		restart()


func restart() -> void:
	_set_gold()
	_set_time()
	_set_map_name()
	_set_chapter_name()
	start()
	party_menu.restart()


func _on_main_menu_items_button_hovered(_button: Control, _index: int, tooltip: String) -> void:
	help_label.text = tooltip


func _on_main_menu_items_selected(_control: Control, _index: int) -> void:
	party_menu.disabled()


func _on_main_menu_items_begin_click(id: int) -> void:
	return
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
			
			last_party_button_selected = party_menu.current_panel_selected
			busy = false


func _on_party_menu_item_selected(id: int) -> void:
	last_party_button_selected = id
