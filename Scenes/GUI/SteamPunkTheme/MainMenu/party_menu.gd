extends GuiCorePartyMenu

#region ThemeExportsAndNodes
@onready var hero_panel_container: VBoxContainer = %HeroPanelContainer
@onready var main_container: Control = %MainContainer

var last_vertical_scroll: int = -1
#endregion

#region Lifecycle
func _ready() -> void:
	if not hero_panel_scene:
		hero_panel_scene = preload("res://Scenes/GUI/SteamPunkTheme/MainMenu/hero_panel.tscn")
	super._ready()
#endregion

#region CoreHookOverrides
func get_panel_container() -> VBoxContainer:
	if not hero_panel_container and has_node("%HeroPanelContainer"):
		hero_panel_container = %HeroPanelContainer
	return hero_panel_container


func get_main_container() -> Control:
	if not main_container and has_node("%MainContainer"):
		main_container = %MainContainer
	return main_container


func config_hand() -> void:
	_config_hand_in_party_actor()


func _config_hand_in_party_actor() -> void:
	if not main_container: return
	var manipulator = str(GameManager.MANIPULATOR_MODES.PARTY_MENU)
	GameManager.set_cursor_manipulator(manipulator)
	var rect = Rect2(0, main_container.global_position.y + 16, get_viewport().size.x, main_container.size.y - 16)
	GameManager.set_confin_area(rect, manipulator)
	GameManager.set_hand_position(MainHandCursor.HandPosition.LEFT, manipulator)
	GameManager.set_cursor_offset(Vector2(16, 0), manipulator)
	GameManager.force_show_cursor()


func animate_panels_switch(child1: Control, child2: Control, _panel_a: int, _panel_b: int, on_complete: Callable) -> void:
	child1.z_index = 10
	child2.z_index = 5
	
	var pos_y1 = child1.position.y
	var pos_y2 = child2.position.y
	var timer = 0.25
	
	if main_container and main_container.has_method("bring_target_into_view"):
		var prev_duration = main_container.instant_scroll_duration
		main_container.instant_scroll_duration = timer
		main_container.bring_target_into_view(child2, true, true)
		main_container.instant_scroll_duration = prev_duration
	
	var t = create_tween()
	t.set_parallel(true)
	t.tween_property(child1, "position:y", pos_y2, timer).from(pos_y1)
	var c1_target = child1.hero_panel if ("hero_panel" in child1 and child1.hero_panel) else child1
	if "offset_transform_enabled" in c1_target and c1_target.offset_transform_enabled:
		t.tween_property(c1_target, "offset_transform_position:x", 0.0, timer)
	else:
		t.tween_property(c1_target, "position:x", 0, timer)
		
	t.tween_property(child2, "position:y", pos_y1, timer - 0.1).set_delay(0.1).from(pos_y2)
	var c2_target = child2.hero_panel if ("hero_panel" in child2 and child2.hero_panel) else child2
	if "offset_transform_enabled" in c2_target and c2_target.offset_transform_enabled:
		t.tween_property(c2_target, "offset_transform_position:x", 20.0, timer - 0.1).set_delay(0.1)
	else:
		t.tween_property(c2_target, "position:x", 20, timer - 0.1).set_delay(0.1)
	
	t.tween_callback(
		func():
			child1.z_index = 0
			child2.z_index = 0
			on_complete.call()
	).set_delay(timer)
	
	GameManager.play_fx("switch_hero_panels")


func _fix_panels_after_switch(panel_moved: Control, panel_selected: Control) -> void:
	super._fix_panels_after_switch(panel_moved, panel_selected)
	if not hero_panel_container: return
	for i in hero_panel_container.get_child_count():
		var panel = hero_panel_container.get_child(i)
		var p_target = panel.hero_panel if ("hero_panel" in panel and panel.hero_panel) else panel
		if "offset_transform_enabled" in p_target and p_target.offset_transform_enabled:
			if panel == panel_selected:
				p_target.offset_transform_position.x = 0.0
			elif panel == panel_moved:
				p_target.offset_transform_position.x = 20.0
		else:
			if panel == panel_selected:
				p_target.position.x = 0
			elif panel == panel_moved:
				p_target.position.x = 20


func show_all_visual(on_complete: Callable) -> void:
	if not hero_panel_container or hero_panel_container.get_child_count() == 0:
		on_complete.call()
		return
		
	var panel = hero_panel_container.get_child(current_panel_selected) if current_panel_selected != -1 else hero_panel_container.get_child(0)
	var t = create_tween()
	t.set_parallel(true)
	for child in hero_panel_container.get_children():
		t.tween_callback(child.set.bind("visible", true))
		if child.has_meta("backup_current_position"):
			var p = child.get_meta("backup_current_position")
			t.tween_method(_set_panel_selected_on_position.bind(child), panel.position, p, 0.25)
			child.remove_meta("backup_current_position")
	if main_container and "vertical_scroll_mode" in main_container:
		main_container.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_ALWAYS
	if last_vertical_scroll and main_container and main_container.has_method("get_v_scroll_bar"):
		t.tween_method(main_container.get_v_scroll_bar().set_value, 0, last_vertical_scroll, 0.25)
	if current_panel_selected != -1:
		await get_tree().process_frame
		await get_tree().process_frame
		await get_tree().process_frame
		if hero_panel_container and hero_panel_container.get_child_count() > current_panel_selected:
			var sel_node = hero_panel_container.get_child(current_panel_selected)
			if sel_node and sel_node.has_method("select"):
				sel_node.select()
	
	await t.finished
	on_complete.call()


func on_panel_clicked_visual(panel_id: int) -> void:
	if not hero_panel_container or not main_container: return
	if main_container.has_method("get_v_scroll_bar"):
		last_vertical_scroll = int(main_container.get_v_scroll_bar().value)
	if "vertical_scroll_mode" in main_container:
		main_container.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	
	var panel = hero_panel_container.get_child(panel_id)
	for other in hero_panel_container.get_children():
		other.set_meta("backup_current_position", other.position)
		if other == panel: continue
		other.hide()

	if panel.has_method("tween_gear"):
		panel.tween_gear(90)
	if panel.has_method("set_final_position"):
		panel.set_final_position(0.25)
	var t = create_tween()
	t.tween_method(_set_panel_selected_on_position.bind(panel), panel.position, Vector2(0, 0), 0.25)


func _set_panel_selected_on_position(value: Vector2, panel: Control) -> void:
	panel.position = value
#endregion
