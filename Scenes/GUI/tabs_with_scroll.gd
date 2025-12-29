extends HBoxContainer


@export var follow_focus_enabled: bool = true

@onready var filter_parent: Control = %FilterParent
@onready var filter_tabs: CustomTabsControl = %FilterTabs
@onready var move_categories_to_left: TextureButton = %MoveCategoriesToLeft
@onready var move_categories_to_right: TextureButton = %MoveCategoriesToRight

var movement_direction: int = 0
var movement_speed: float = 100
var minimun_scroll: float = 0
var maximun_scroll: float = 0
var current_scroll: float = 0
var lerp_speed = 30

var navigation_is_enabled: bool = true


signal tab_clicked(tab_id: int)
signal request_focus_top_control()
signal request_focus_bottom_control()
signal tabs_focused()


func _ready() -> void:
	filter_tabs.tab_clicked.connect(
		func(tab_id: int):
			if follow_focus_enabled:
				ensurre_current_is_visible()
			tab_clicked.emit(tab_id)
			if tab_id == filter_tabs.get_tab_count() - 1:
				current_scroll = maximun_scroll
			elif tab_id == 0:
				current_scroll = minimun_scroll
				
	)
	filter_tabs.tab_preselected.connect(_ensure_visible)
	filter_tabs.request_focus_top_control.connect(func(): request_focus_top_control.emit())
	filter_tabs.request_focus_bottom_control.connect(func(): request_focus_bottom_control.emit())
	minimun_scroll = 0
	await get_tree().process_frame
	_setup_move_buttons()


func _setup_move_buttons() -> void:
	minimun_scroll = 0
	maximun_scroll = 0
	current_scroll = 0
	filter_tabs.position.x = 0
	var ms = size.x - move_categories_to_left.size.x - move_categories_to_right.size.x
	if filter_tabs.size.x > ms:
		var sx = 0 if not get_parent() else get_parent().size.x
		move_categories_to_left.visible = true
		move_categories_to_right.visible = true
		maximun_scroll = filter_tabs.size.x - (sx - move_categories_to_left.size.x - move_categories_to_right.size.x - 5)
		current_scroll = minimun_scroll
		navigation_is_enabled = true
	else:
		move_categories_to_left.visible = false
		move_categories_to_right.visible = false
		navigation_is_enabled = false


func set_hand_manipulator(manipulator: String) -> void:
	filter_tabs.hand_manipulator = manipulator


func clear_tabs() -> void:
	filter_tabs.clear_tabs()


func set_tab_names(value: PackedStringArray):
	filter_tabs.set_tab_names(value)
	if is_inside_tree():
		await get_tree().process_frame
		_setup_move_buttons()


func get_selected_tab() -> int:
	return filter_tabs.get_selected_tab()


func set_selected_tab(tab_id: int, animate: bool = true, emit_signal_enabled: bool = false):
	filter_tabs.set_selected_tab(tab_id, animate, emit_signal_enabled)
	ensurre_current_is_visible()


func hide_tab(tab_index: int, value: bool) -> void:
	filter_tabs.hide_tab(tab_index, value)


func _ensure_visible(current_tab_selected: int) -> void:
	if not navigation_is_enabled: return
	
	var current_tab_rect = filter_tabs.get_tab_rect(current_tab_selected)
	
	var visible_area_start = filter_parent.position.x
	var visible_area_end = filter_parent.position.x + filter_parent.size.x

	var tab_start = current_tab_rect.position.x - current_scroll
	var tab_end = tab_start + current_tab_rect.size.x

	var new_scroll = current_scroll

	if tab_start < visible_area_start:
		new_scroll = current_tab_rect.position.x - visible_area_start
	elif tab_end > visible_area_end:
		new_scroll = current_tab_rect.position.x + current_tab_rect.size.x - filter_parent.size.x

	current_scroll = max(minimun_scroll, min(maximun_scroll, new_scroll))
	
	if current_tab_selected == filter_tabs.get_tab_count() - 1:
		current_scroll = maximun_scroll
	elif current_tab_selected == 0:
		current_scroll = minimun_scroll


func ensurre_current_is_visible() -> void:
	var current_tab_selected = filter_tabs.selected_tab
	_ensure_visible(current_tab_selected)


func next_tab() -> void:
	filter_tabs.next_tab()


func previous_tab() -> void:
	filter_tabs.previous_tab()


func _process(delta: float) -> void:
	#move_categories_to_left.set_disabled(current_scroll == minimun_scroll)
	#move_categories_to_right.set_disabled(current_scroll == maximun_scroll)
	move_categories_to_left.set_disabled(filter_tabs.selected_tab == 0)
	move_categories_to_right.set_disabled(filter_tabs.selected_tab == filter_tabs.get_max_tabs() - 1)

	filter_tabs.position.x = lerp(filter_tabs.position.x, -current_scroll, lerp_speed * delta)
	
	if GameManager.get_cursor_manipulator() == "tab_with_scroll_buttons":
		_update_movement_buttons()


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.is_pressed():
			if event.button_index == MOUSE_BUTTON_LEFT:
				if movement_direction == 0:
					if move_categories_to_left.get_global_rect().has_point(move_categories_to_left.get_global_mouse_position()):
						_update_target_position(-1)
					elif move_categories_to_right.get_global_rect().has_point(move_categories_to_right.get_global_mouse_position()):
						_update_target_position(1)
			elif get_global_rect().has_point(get_global_mouse_position()):
				if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
					_update_target_position(1)
				elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
					_update_target_position(-1)


func _update_movement_buttons() -> void:
	var direction = ControllerManager.get_pressed_direction()
	if direction:
		if direction == "left" or direction == "right":
			if move_categories_to_left.has_focus():
				move_categories_to_right.grab_focus()
			else:
				move_categories_to_left.grab_focus()
		elif direction == "up":
			request_focus_top_control.emit()
		elif direction == "down":
			request_focus_bottom_control.emit()
		
		GameManager.play_fx("cursor")
	elif ControllerManager.is_confirm_pressed(false, [KEY_KP_ENTER]):
		if move_categories_to_left.has_focus():
			_on_move_categories_to_left_pressed()
		elif move_categories_to_right.has_focus():
			_on_move_categories_to_right_pressed()
	elif ControllerManager.is_cancel_pressed([KEY_0, KEY_KP_0]):
		var current_tab = filter_tabs.get_selected_tab()
		filter_tabs.pre_select_tab(current_tab)
		filter_tabs._select_control(current_tab)
		tabs_focused.emit()
		GameManager.play_fx("cancel")


func _update_target_position(direction: int) -> void:
	current_scroll = max(minimun_scroll, min(maximun_scroll, current_scroll + direction * movement_speed))


func _on_move_categories_to_left_pressed() -> void:
	_update_target_position(-1)


func _on_move_categories_to_right_pressed() -> void:
	_update_target_position(1)


func _on_move_categories_to_left_focus_entered() -> void:
	var manipulator = "tab_with_scroll_buttons"
	GameManager.set_cursor_manipulator(manipulator)
	GameManager.set_confin_area(Rect2(), manipulator)
	GameManager.set_hand_position(MainHandCursor.HandPosition.LEFT, manipulator)
	GameManager.set_cursor_offset(Vector2(10, 0), manipulator)


func _on_move_categories_to_right_focus_entered() -> void:
	var manipulator = "tab_with_scroll_buttons"
	GameManager.set_cursor_manipulator(manipulator)
	GameManager.set_confin_area(Rect2(), manipulator)
	GameManager.set_hand_position(MainHandCursor.HandPosition.RIGHT, manipulator)
	GameManager.set_cursor_offset(Vector2(-10, 0), manipulator)
