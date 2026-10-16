class_name GuiCorePartyMenu
extends Control

#region ExportsAndVariables
@export var hero_panel_scene: PackedScene

var current_panel_selected: int = -1
var order_mode: bool = false
var busy: bool = false
var is_enabled: bool = false

signal item_selected(id: int)
signal clicked(id: int)
signal panels_switched()
signal cancel()
#endregion

#region Lifecycle
func _ready() -> void:
	_initialize_hero_panels()


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
#endregion

#region VirtualHooks
## Override in themes to return the container where hero panels are placed
func get_panel_container() -> Container:
	return null


## Override in themes to return the scroll container or main container
func get_main_container() -> Control:
	return null


## Hook for themes to position visual cursors/hands
func config_hand() -> void:
	pass


## Virtual hook to perform visual animations when two panels swap positions
func animate_panels_switch(_child1: Control, _child2: Control, _panel_a: int, _panel_b: int, on_complete: Callable) -> void:
	on_complete.call()


## Virtual hook for click transitions on panels
func on_panel_clicked_visual(_panel_id: int) -> void:
	pass


## Virtual hook when all panels are shown again
func show_all_visual(on_complete: Callable) -> void:
	on_complete.call()
#endregion

#region CoreLogicAndSelection
func set_multi_cursor_mode(value: bool) -> void:
	for panel in get_panels():
		if panel.has_method("set_multi_cursor_mode"):
			panel.set_multi_cursor_mode(value)


func force_selection(id: int) -> void:
	var container = get_panel_container()
	if container and container.get_child_count() > id and id >= 0:
		var panel = container.get_child(id)
		if panel.has_method("force_selection"):
			panel.force_selection()


func clear_force_selection(id: int) -> void:
	var container = get_panel_container()
	if container and container.get_child_count() > id and id >= 0:
		var panel = container.get_child(id)
		if panel.has_method("clear_force_selection"):
			panel.clear_force_selection()


func set_order_mode(value: bool) -> void:
	order_mode = value
	var container = get_panel_container()
	if container:
		for child in container.get_children():
			if child.has_method("set_order_mode"):
				child.set_order_mode(value)


func execute_cancel() -> void:
	var focus_owner = get_viewport().gui_get_focus_owner()
	if focus_owner:
		focus_owner.release_focus()
	cancel.emit()


func _change_selected_hero(direction: String) -> void:
	var container = get_panel_container()
	if not container: return
	var child_count = container.get_child_count()
	if child_count == 0: return
	
	var next_idx = wrapi(current_panel_selected + (1 if direction == "down" else -1), 0, child_count)
	var new_control = container.get_child(next_idx)
	if new_control and new_control.has_method("select"):
		new_control.select()
		GameManager.play_fx("cursor")


func select() -> void:
	if not is_inside_tree(): return
	var container = get_panel_container()
	if not container: return
	
	if current_panel_selected < 0 and container.get_child_count() > 0:
		current_panel_selected = 0
		
	if current_panel_selected >= 0 and container.get_child_count() > current_panel_selected:
		busy = true
		config_hand()
		enabled()
		var p = container.get_child(current_panel_selected)
		if p.has_method("select"):
			p.select()
		await get_tree().process_frame
		await get_tree().process_frame
		if not is_inside_tree(): return
		busy = false
	else:
		disabled()


func hightlight_selected() -> void:
	var container = get_panel_container()
	if not container: return
	for child in container.get_children():
		if "is_selected" in child and child.is_selected:
			if child.has_method("hightlight"):
				child.hightlight()
#endregion

#region FormationAndSwitching
func change_panels(panel_a: int, panel_b: int) -> void:
	var container = get_panel_container()
	if not container: return
	var count = container.get_child_count()
	if panel_a < 0 or panel_a >= count or panel_b < 0 or panel_b >= count: return
	
	var panel1 = container.get_child(panel_a)
	var panel2 = container.get_child(panel_b)
	if not "current_actor" in panel1 or not "current_actor" in panel2: return
	if not panel1.current_actor or not panel2.current_actor: return
	
	GameManager.change_formation(panel1.current_actor.id, panel2.current_actor.id)
	
	var old_manipulator = GameManager.get_cursor_manipulator()
	GameManager.set_cursor_manipulator(GameManager.MANIPULATOR_MODES.NONE)
	busy = true
	
	if panel1.has_method("clear"): panel1.clear()
	if panel2.has_method("clear"): panel2.clear()
	
	var focus = get_viewport().gui_get_focus_owner()
	if focus: focus.release_focus()
	disabled()
	
	animate_panels_switch(panel1, panel2, panel_a, panel_b, func():
		container.move_child(panel1, panel_b)
		container.move_child(panel2, panel_a)
		current_panel_selected = panel_b
		if panel1.has_method("set_party_icon"): panel1.set_party_icon(panel_b)
		if panel2.has_method("set_party_icon"): panel2.set_party_icon(panel_a)
		GameManager.set_cursor_manipulator(old_manipulator)
		enabled()
		if panel1.has_method("select"): panel1.select(true)
		_fix_panels_after_switch(panel2, panel1)
		GameManager.force_hand_position_over_node(old_manipulator)
		busy = false
		panels_switched.emit()
	)


func _fix_panels_after_switch(_panel_moved: Control, _panel_selected: Control) -> void:
	var container = get_panel_container()
	if not container: return
	for i in container.get_child_count():
		var panel = container.get_child(i)
		if panel.has_method("to_gray"):
			panel.to_gray(i >= RPGSYSTEM.database.system.party_active_members)


func fix_panel_position(panel_id: int) -> void:
	var container = get_panel_container()
	if container and container.get_child_count() > panel_id and panel_id >= 0:
		var panel = container.get_child(panel_id)
		if panel.has_method("_on_focus_exited"):
			panel._on_focus_exited()
#endregion

#region PanelManagement
func _initialize_hero_panels() -> void:
	if GameManager.game_state:
		create_panels()
		setup_panels()


func restart() -> void:
	_initialize_hero_panels.call_deferred()
	disabled.call_deferred()


func setup_panels() -> void:
	var container = get_panel_container()
	var main_c = get_main_container()
	if not container: return
	
	for i in container.get_child_count():
		var panel = container.get_child(i)
		if panel.has_signal("item_selected"):
			panel.item_selected.connect(
				func(id: int):
					if is_enabled and current_panel_selected != id:
						GameManager.play_fx("cursor")
					current_panel_selected = id
					item_selected.emit(id)
					config_hand()
			)
		panel.mouse_entered.connect(
			func():
				if is_enabled and current_panel_selected != i:
					GameManager.play_fx("cursor")
		)
		if panel.has_signal("clicked"):
			panel.clicked.connect(func(id: int): 
				if not busy:
					current_panel_selected = id
					clicked.emit(id)
			)
		if main_c and main_c.has_method("bring_focus_target_into_view"):
			panel.focus_entered.connect(main_c.bring_focus_target_into_view.bind(true, true))
		if panel.has_method("to_gray"):
			panel.to_gray(i >= RPGSYSTEM.database.system.party_active_members)
		if panel.has_method("set_party_icon"):
			panel.set_party_icon(i)


func end() -> void:
	var container = get_panel_container()
	if not container: return
	for panel in container.get_children():
		if panel.has_method("end"):
			panel.end()


func has_actors() -> bool:
	var container = get_panel_container()
	return container.get_child_count() > 0 if container else false


func get_actor_selected() -> GameActor:
	var container = get_panel_container()
	if container and current_panel_selected >= 0 and container.get_child_count() > current_panel_selected:
		var p = container.get_child(current_panel_selected)
		if "current_actor" in p:
			return p.current_actor
	return null


func get_actors() -> Array[GameActor]:
	var actors: Array[GameActor] = []
	for panel in get_panels():
		if "current_actor" in panel and panel.current_actor:
			actors.append(panel.current_actor)
	return actors


func get_panel_for_actor(actor: GameActor) -> Control:
	for panel in get_panels():
		if "current_actor" in panel and panel.current_actor == actor:
			return panel
	return null


func create_panels() -> void:
	var container = get_panel_container()
	if not container or not hero_panel_scene: return
	
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()
	
	var last_current_panel_selected = current_panel_selected
	current_panel_selected = -1
	
	for id: int in GameManager.game_state.current_party:
		var actor: GameActor = GameManager.get_actor(id)
		var panel = hero_panel_scene.instantiate()
		panel.name = "HeroPanel" + actor.current_name.capitalize()
		var is_in_party = actor.id in GameManager.game_state.current_party
		container.add_child(panel)
		if panel.has_method("setup"):
			panel.setup(actor, is_in_party)
	
	var panels_count = container.get_child_count()
	if last_current_panel_selected != -1 and panels_count > last_current_panel_selected:
		current_panel_selected = last_current_panel_selected
	elif panels_count > 0:
		current_panel_selected = 0
	
	if current_panel_selected != -1:
		var node = container.get_child(current_panel_selected)
		while not node.is_node_ready() or not node.is_inside_tree():
			await RenderingServer.frame_post_draw
		if node.has_method("select"):
			node.select.call_deferred(true)


func get_panel_count() -> int:
	var container = get_panel_container()
	return container.get_child_count() if container else 0


func get_panels() -> Array:
	var container = get_panel_container()
	return container.get_children() if container else []


func show_single_panel(index: int) -> void:
	var container = get_panel_container()
	if not container: return
	for child in container.get_children():
		child.visible = (child.get_index() == index)


func enabled() -> void:
	is_enabled = true
	for child in get_panels():
		if child.has_method("set_enabled"):
			child.set_enabled()


func disabled() -> void:
	is_enabled = false
	for child in get_panels():
		if child.has_method("set_disabled"):
			child.set_disabled()


func show_all() -> void:
	disabled()
	busy = true
	show_all_visual(func():
		busy = false
		enabled()
	)


func _on_panel_clicked(panel_id: int) -> void:
	on_panel_clicked_visual(panel_id)


func start_hit_animation() -> void:
	pass


func end_hit_animation() -> void:
	pass
#endregion
