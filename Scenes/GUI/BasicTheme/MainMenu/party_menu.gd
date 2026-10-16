extends Control

const HERO_PANEL = preload("res://Scenes/GUI/BasicTheme/MainMenu/hero_panel.tscn")

@onready var hero_panel_container: VBoxContainer = %HeroPanelContainer
@onready var main_container: ScrollContainer = %MainContainer

signal item_selected(id: int)
signal clicked(id: int)
signal panels_switched()
signal cancel()

var current_panel_selected: int = -1
var last_vertical_scroll: int = -1
var order_mode: bool = false
var busy: bool = false


func _ready() -> void:
	_initialize_hero_panels()


func set_multi_cursor_mode(value: bool) -> void:
	for panel in get_panels():
		panel.set_multi_cursor_mode(value)


func force_selection(id: int) -> void:
	if hero_panel_container.get_child_count() > id and id >= 0:
		hero_panel_container.get_child(id).force_selection()


func clear_force_selection(id: int) -> void:
	if hero_panel_container.get_child_count() > id and id >= 0:
		hero_panel_container.get_child(id).clear_force_selection()


func set_order_mode(value: bool) -> void:
	order_mode = value
	for child in hero_panel_container.get_children():
		child.set_order_mode(value)


func change_panels(panel_a: int, panel_b: int) -> void:
	var count = hero_panel_container.get_child_count()
	if count > panel_a and panel_a >= 0 and count > panel_b and panel_b >= 0:
		var panel1 = hero_panel_container.get_child(panel_a)
		var panel2 = hero_panel_container.get_child(panel_b)
		GameManager.change_formation(panel1.current_actor.id, panel2.current_actor.id)
		
		var old_manipulator = GameManager.get_cursor_manipulator()
		GameManager.set_cursor_manipulator(GameManager.MANIPULATOR_MODES.NONE)
		
		busy = true
		panel1.clear()
		panel2.clear()
		disabled()
		
		var timer = 0.2
		var t = create_tween()
		t.set_parallel(true)
		t.tween_property(panel2, "position:y", panel1.position.y, timer)
		t.tween_property(panel1, "position:y", panel2.position.y, timer)
		
		t.tween_callback(
			func():
				hero_panel_container.move_child(panel1, panel_b)
				hero_panel_container.move_child(panel2, panel_a)
				current_panel_selected = panel_a
				panel1.set_party_icon(panel_b)
				panel2.set_party_icon(panel_a)
				GameManager.set_cursor_manipulator(old_manipulator)
				enabled()
				panel2.select(true)
				_fix_panels_after_switch(panel1, panel2)
				GameManager.force_hand_position_over_node(old_manipulator)
				busy = false
				panels_switched.emit()
		).set_delay(timer)
		
		GameManager.play_fx("switch_hero_panels")


func _fix_panels_after_switch(panel_moved: Control, panel_selected: Control) -> void:
	for i in hero_panel_container.get_child_count():
		var panel = hero_panel_container.get_child(i)
		panel.to_gray(i >= RPGSYSTEM.database.system.party_active_members)
		if panel == panel_selected:
			panel.position.x = 0
		elif panel == panel_moved:
			panel.position.x = 0


func fix_panel_position(panel_id: int) -> void:
	var count = hero_panel_container.get_child_count()
	if count > panel_id and panel_id >= 0:
		hero_panel_container.get_child(panel_id)._on_focus_exited()


func _process(_delta: float) -> void:
	if busy: return
	if GameManager.get_cursor_manipulator() == GameManager.MANIPULATOR_MODES.PARTY_MENU:
		var direction = ControllerManager.get_pressed_direction()
		if direction and direction in ["up", "down"]:
			_change_selected_hero(direction)
		elif ControllerManager.is_cancel_just_pressed([KEY_0, KEY_KP_0]):
			execute_cancel()
		elif ControllerManager.is_confirm_just_pressed(true, [KEY_KP_ENTER]):
			clicked.emit(current_panel_selected)


func execute_cancel() -> void:
	var focus_owner = get_viewport().gui_get_focus_owner()
	if focus_owner:
		focus_owner.release_focus()
	cancel.emit()


func _change_selected_hero(direction: String) -> void:
	var child_count = hero_panel_container.get_child_count()
	if child_count == 0: return
	var current_hero_panel = wrapi(current_panel_selected + (1 if direction == "down" else -1), 0, child_count)
	var new_control = hero_panel_container.get_child(current_hero_panel)
	if new_control:
		new_control.select()
		GameManager.play_fx("cursor")


func _initialize_hero_panels() -> void:
	if GameManager.game_state:
		create_panels()
		setup_panels()


func restart() -> void:
	_initialize_hero_panels.call_deferred()
	disabled.call_deferred()


func setup_panels() -> void:
	for i in hero_panel_container.get_child_count():
		var panel = hero_panel_container.get_child(i)
		panel.item_selected.connect(
			func(id: int):
				current_panel_selected = id
				item_selected.emit(id)
				_config_hand_in_party_actor()
		)
		panel.clicked.connect(func(id: int): 
			if not busy:
				clicked.emit(id)
		)
		if main_container.has_method("bring_focus_target_into_view"):
			panel.focus_entered.connect(main_container.bring_focus_target_into_view.bind(false))
		panel.to_gray(i >= RPGSYSTEM.database.system.party_active_members)
		panel.set_party_icon(i)


func end() -> void:
	for i in hero_panel_container.get_child_count():
		var panel = hero_panel_container.get_child(i)
		panel.end()


func _config_hand_in_party_actor() -> void:
	var manipulator = str(GameManager.MANIPULATOR_MODES.PARTY_MENU)
	GameManager.set_cursor_manipulator(manipulator)
	var rect = Rect2(0, main_container.global_position.y + 16, get_viewport().size.x, main_container.size.y - 16)
	GameManager.set_confin_area(rect, manipulator)
	GameManager.set_hand_position(MainHandCursor.HandPosition.LEFT, manipulator)
	GameManager.set_cursor_offset(Vector2(16, 0), manipulator)
	GameManager.force_show_cursor()


func config_hand() -> void:
	_config_hand_in_party_actor()


func select() -> void:
	if not is_inside_tree(): return
	if current_panel_selected < 0 and hero_panel_container.get_child_count() > 0:
		current_panel_selected = 0
	if current_panel_selected >= 0 and hero_panel_container.get_child_count() > current_panel_selected:
		busy = true
		_config_hand_in_party_actor()
		enabled()
		var p = hero_panel_container.get_child(current_panel_selected)
		if p.has_method("select"):
			p.select()
		await get_tree().process_frame
		await get_tree().process_frame
		if not is_inside_tree(): return
		busy = false
	else:
		disabled()


func has_actors() -> bool:
	return hero_panel_container.get_child_count() > 0


func get_actor_selected() -> GameActor:
	if current_panel_selected >= 0 and hero_panel_container.get_child_count() > current_panel_selected:
		return hero_panel_container.get_child(current_panel_selected).current_actor
	return null


func get_actors() -> Array[GameActor]:
	var actors: Array[GameActor] = []
	for panel in get_panels():
		actors.append(panel.current_actor)
	return actors


func get_panel_for_actor(actor: GameActor) -> Control:
	for panel in get_panels():
		if panel.current_actor == actor:
			return panel
	return null


func create_panels() -> void:
	for child in hero_panel_container.get_children():
		hero_panel_container.remove_child(child)
		child.queue_free()
	
	var last_current_panel_selected = current_panel_selected
	current_panel_selected = -1
	
	for id: int in GameManager.game_state.current_party:
		var actor: GameActor = GameManager.get_actor(id)
		if not actor: continue
		var panel = HERO_PANEL.instantiate()
		panel.name = "HeroPanel" + actor.current_name.capitalize()
		var is_in_party = actor.id in GameManager.game_state.current_party
		hero_panel_container.add_child(panel)
		panel.setup(actor, is_in_party)
	
	var panels_count = hero_panel_container.get_child_count()
	if last_current_panel_selected != -1 and panels_count > last_current_panel_selected:
		current_panel_selected = last_current_panel_selected
	elif panels_count > 0:
		current_panel_selected = 0
	
	if current_panel_selected != -1:
		var node = hero_panel_container.get_child(current_panel_selected)
		while not node.is_node_ready() or not node.is_inside_tree():
			await RenderingServer.frame_post_draw
		node.select.call_deferred(true)


func get_panel_count() -> int:
	return hero_panel_container.get_child_count()


func get_panel_container() -> VBoxContainer:
	return hero_panel_container


func get_panels() -> Array:
	return hero_panel_container.get_children()


func show_single_panel(index: int) -> void:
	for child in hero_panel_container.get_children():
		child.visible = child.get_index() == index


func enabled() -> void:
	for child in hero_panel_container.get_children():
		child.set_enabled()


func disabled() -> void:
	for child in hero_panel_container.get_children():
		child.set_disabled()


func hightlight_selected():
	for child in hero_panel_container.get_children():
		if child.is_selected:
			child.hightlight()


func show_all() -> void:
	disabled()
	busy = true
	if hero_panel_container.get_child_count() > 0:
		for child in hero_panel_container.get_children():
			child.visible = true
		main_container.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_ALWAYS
		if current_panel_selected != -1:
			await get_tree().process_frame
			hero_panel_container.get_child(current_panel_selected).select()
	busy = false
	enabled()


func start_hit_animation() -> void:
	pass


func end_hit_animation() -> void:
	pass
