extends Control


const HERO_PANEL = preload("res://Scenes/GUI/SteamPunkTheme/MainMenu/hero_panel.tscn")

@onready var hero_panel_container: VBoxContainer = %HeroPanelContainer
@onready var main_container: SmoothScrollContainer = %MainContainer

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
	var panel1 = hero_panel_container.get_child(panel_a)
	var panel2 = hero_panel_container.get_child(panel_b)
	if count > panel_a and panel_a >= 0 and count > panel_b and panel_b >= 0:
		GameManager.change_formation(panel1.current_actor.id, panel2.current_actor.id)
		var child1 = hero_panel_container.get_child(panel_a)
		var child2 = hero_panel_container.get_child(panel_b)
		
		var old_manipulator = GameManager.get_cursor_manipulator()
		GameManager.set_cursor_manipulator(GameManager.MANIPULATOR_MODES.NONE)
		
		
		busy = true
		child1.z_index = 5
		child2.z_index = 10
		
		child1.clear()
		child2.clear()
		child2.select(true)
		
		get_viewport().gui_get_focus_owner().release_focus()

		disabled()
		
		var timer = 0.25
		var t = create_tween()
		t.set_parallel(true)
		t.tween_property(child2, "position:y", child1.position.y, timer).from(child2.position.y)
		t.tween_property(child2.hero_panel, "position:x", 0, timer)
		t.tween_property(child1, "position:y", child2.position.y, timer - 0.1).set_delay(0.1).from(child1.position.y)
		t.tween_property(child1.hero_panel, "position:x", 20, timer - 0.1).set_delay(0.1)
		
		var update_interval = 0.016  # ~60 FPS
		var steps = int(timer / update_interval)
		for i in steps:
			t.tween_callback(main_container.bring_target_into_view.bind(child2, true, false)).set_delay(i * update_interval)
		
		t.tween_callback(
			func():
				hero_panel_container.move_child(child1, panel_b)
				hero_panel_container.move_child(child2, panel_a)
				current_panel_selected = panel_a  # El panel B (child2) ahora está en la posición panel_a
				child1.z_index = 0
				child2.z_index = 0
				child1.set_party_icon(panel_b)
				child2.set_party_icon(panel_a)
				GameManager.set_cursor_manipulator(old_manipulator)
				enabled()
				child2.select(true)
				_fix_panels_after_switch(child1, child2)
				GameManager.force_hand_position_over_node(old_manipulator)
				busy = false
				panels_switched.emit()
		).set_delay(timer)
		t.tween_callback(main_container.bring_focus_target_into_view).set_delay(timer + 0.2)
		
		GameManager.play_fx("switch_hero_panels")


func _fix_panels_after_switch(panel_moved: Control, panel_selected: Control) -> void:
	for i in hero_panel_container.get_child_count():
		var panel = hero_panel_container.get_child(i)
		panel.to_gray(i >= RPGSYSTEM.database.system.party_active_members)
		# No hacer tween de posición aquí, ya que se hizo durante el intercambio
		# Solo asegurar que los valores finales estén correctos
		if panel == panel_selected:
			panel.hero_panel.position.x = 0
		elif panel == panel_moved:
			panel.hero_panel.position.x = 20


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
			var focus_owner = get_viewport().gui_get_focus_owner()
			if focus_owner:
				focus_owner.release_focus()
			cancel.emit()
		elif ControllerManager.is_confirm_just_pressed(true, [KEY_KP_ENTER]):
			clicked.emit(current_panel_selected)

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


func setup_panels() -> void:
	for i in hero_panel_container.get_child_count():
		var panel = hero_panel_container.get_child(i)
		panel.item_selected.connect(
			func(id: int):
				current_panel_selected = id
				item_selected.emit(id)
				_config_hand_in_party_actor()
		)
		panel.clicked.connect(func(id: int): clicked.emit(id))
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


func select() -> void:
	if current_panel_selected >= 0 and hero_panel_container.get_child_count() > current_panel_selected:
		_config_hand_in_party_actor()
		enabled()
		hero_panel_container.get_child(current_panel_selected).select()
	else:
		disabled()


func has_actors() -> bool:
	return hero_panel_container.get_child_count() > 0


func get_actor_selected() -> GameActor:
	if current_panel_selected >= 0 and hero_panel_container.get_child_count() > current_panel_selected:
		return hero_panel_container.get_child(current_panel_selected).current_actor
	
	return null


func create_panels() -> void:
	for child in hero_panel_container.get_children():
		hero_panel_container.remove_child(child)
		child.queue_free()
	
	var last_current_panel_selected = current_panel_selected
	current_panel_selected = -1
	
	for id: int in GameManager.game_state.current_party:
		var actor: GameActor = GameManager.get_actor(id)
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


func show_single_panel(index: int) -> void:
	for child in hero_panel_container.get_children():
		child.visible = child.get_index() == index


func enabled() -> void:
	for child in hero_panel_container.get_children():
		child.set_enabled()


func disabled() -> void:
	for child in hero_panel_container.get_children():
		child.set_disabled()


func show_all() -> void:
	disabled()
	
	busy = true
	if hero_panel_container.get_child_count() > 0:
		var panel = hero_panel_container.get_child(current_panel_selected) if current_panel_selected != -1 else hero_panel_container.get_child(0)
		var t = create_tween()
		t.set_parallel(true)
		for child in hero_panel_container.get_children():
			t.tween_callback(child.set.bind("visible", true))
			if child.has_meta("backup_current_position"):
				var p = child.get_meta("backup_current_position")
				t.tween_method(_set_panel_selected_on_position.bind(child), panel.position, p, 0.25)
				child.remove_meta("backup_current_position")
		main_container.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_ALWAYS
		if last_vertical_scroll:
			t.tween_method(main_container.get_v_scroll_bar().set_value, 0, last_vertical_scroll, 0.25)
		if current_panel_selected != -1:
			await get_tree().process_frame
			await get_tree().process_frame
			await get_tree().process_frame
			hero_panel_container.get_child(current_panel_selected).select()
		
		await t.finished
		
	busy = false
	enabled()


func _on_panel_clicked(panel_id: int) -> void:
	last_vertical_scroll = int(main_container.get_v_scroll_bar().value)
	main_container.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var panel = hero_panel_container.get_child(panel_id)
	
	for other in hero_panel_container.get_children():
		other.set_meta("backup_current_position", other.position)
		if other == panel: continue
		other.hide()

	panel.tween_gear(90)
	var t = create_tween()
	t.tween_method(_set_panel_selected_on_position.bind(panel), panel.position, Vector2(10, 0), 0.25)

func _set_panel_selected_on_position(value: Vector2, panel: Control) -> void:
	panel.position = value
