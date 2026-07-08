extends Node


@export var scene_parent: Control
@export var back_button: Control
@export var main_scene: Control
@export var title_scene: Control

const manipulator: String = "LIBRARY_MANIPULATOR"
var started: bool = false
var book_opened: bool = false
var _last_manipulator: Variant
var _current_book: String = ""
var busy: bool = false
var _current_active_control: Control

@onready var go_to_page_left: TextureButton = $"../SceneMainContainer/MainContainer/ContentsContainer/MainSceneContainer/Encyclopedia/Book/BookExtraControls/GoToPageLeft"
@onready var go_to_page_right: TextureButton = $"../SceneMainContainer/MainContainer/ContentsContainer/MainSceneContainer/Encyclopedia/Book/BookExtraControls/GoToPageRight"
@onready var back: TextureButton = $"../SceneMainContainer/MainContainer/ContentsContainer/MainSceneContainer/Encyclopedia/Book/BookExtraControls/Back"



func _ready() -> void:
	_last_manipulator = GameManager.get_cursor_manipulator()
	
	if GameManager.cursor_manager and GameManager.cursor_manager.hand_cursor:
		GameManager.cursor_manager.hand_cursor.hide_hand_when_mouse_over_focused = false
	
	BookAPI.disable_book(BookAPI.get_current_book())
	
	if main_scene:
		if not main_scene.book_opened.is_connected(_on_book_opened):
			main_scene.book_opened.connect(_on_book_opened)
		if not main_scene.book_closed.is_connected(_on_book_closed):
			main_scene.book_closed.connect(_on_book_closed)
		if not main_scene.book_selected.is_connected(_on_book_selected):
			main_scene.book_selected.connect(_on_book_selected, CONNECT_DEFERRED)
		
			
		var books: Array = main_scene.get_books()
		if not books.is_empty():
			for book: Control in books:
				if not book.focus_entered.is_connected(_config_hand_in_selectable_books):
					book.focus_entered.connect(_config_hand_in_selectable_books)
			
			books[0].grab_focus()
			GameManager.force_hand_position_over_node(manipulator)
		
		_config_hand_in_selectable_books.call_deferred()
	
		if scene_parent and scene_parent.running_starting_animation:
			await scene_parent.animation_in_finished
		
		GameManager.force_show_cursor()
		
		go_to_page_left.focus_entered.connect(_select_external_control.bind(go_to_page_left), CONNECT_DEFERRED)
		go_to_page_right.focus_entered.connect(_select_external_control.bind(go_to_page_right), CONNECT_DEFERRED)
		back.focus_entered.connect(_select_external_control.bind(back), CONNECT_DEFERRED)
		
		for btn in [go_to_page_left, go_to_page_right, back]:
			if btn:
				btn.focus_neighbor_left = btn.get_path()
				btn.focus_neighbor_right = btn.get_path()
				btn.focus_neighbor_top = btn.get_path()
				btn.focus_neighbor_bottom = btn.get_path()
		
		started = true


func _select_external_control(control: Control) -> void:
	GameManager.clear_manual_cursor_override()
	_current_active_control = control


func _on_book_opened() -> void:
	book_opened = true
	if back_button: back_button.set_disabled(true)
	GameManager.enable_cursor_outline(Color("cbc1b692"))
	GameManager.set_cursor_manipulator(manipulator)
	GameManager.force_show_cursor()


func _on_book_closed() -> void:
	book_opened = false
	if back_button: back_button.set_disabled(false)
	_config_hand_in_selectable_books()
	GameManager.clear_manual_cursor_override()
	GameManager.force_show_cursor()


func _on_book_selected(_book_id: String) -> void:
	_current_book = _book_id
	busy = false


func _process(_delta: float) -> void:
	if not started or busy or (main_scene and main_scene.busy) or BookAPI.is_busy():
		return

	if not book_opened:
		var direction = ControllerManager.get_pressed_direction()
		
		if main_scene and direction:
			var books: Array = main_scene.get_books()
			var current_book = get_viewport().gui_get_focus_owner()
			
			if not current_book in books and current_book != back_button:
				current_book = main_scene.get_selected_book()
				
			if not current_book:
				current_book = books[0]
				
			if current_book:
				var search_list = books + [back_button]
				var next_control = ControllerManager.find_closest_control_in_list_by_direction(current_book, search_list, direction)
				
				if next_control:
					if next_control == back_button:
						back_button.select()
					else:
						main_scene.select(next_control)
						
					GameManager.play_fx("cursor")
					
		elif ControllerManager.is_cancel_just_pressed():
			_on_back_button_pressed()
		
		elif ControllerManager.is_key_just_pressed(KEY_ENTER):
			if main_scene and _current_book:
				if _current_book == "main_book" or _current_book == main_scene.current_book:
					GameManager.set_cursor_manipulator(GameManager.MANIPULATOR_MODES.NONE)
					GameManager.force_hide_cursor()
					
					if back_button:
						back_button.set_disabled(true)
						
					GameManager.force_hide_cursor()
					main_scene.open_book()
				else:
					GameManager.set_cursor_manipulator(GameManager.MANIPULATOR_MODES.NONE)
					GameManager.force_hide_cursor()
					
					if back_button:
						back_button.set_disabled(true)
						
					if main_scene.update_book(_current_book, false, true):
						busy = true
		
		elif ControllerManager.is_confirm_pressed(false, [], true, []):
			if main_scene and _current_book:
				if _current_book == "main_book" or _current_book == main_scene.current_book:
					GameManager.set_cursor_manipulator(GameManager.MANIPULATOR_MODES.NONE)
					GameManager.force_hide_cursor()
					
					if back_button:
						back_button.set_disabled(true)
						
					main_scene.open_book()
				else:
					if main_scene.update_book(_current_book):
						busy = true
	
	elif main_scene:
		if book_opened:
			_process_open_book_navigation()


func _process_open_book_navigation() -> void:
	if Input.is_physical_key_pressed(KEY_ESCAPE) or Input.is_key_pressed(KEY_ESCAPE):
		main_scene.close_book()
		return
	elif ControllerManager.is_cancel_just_pressed():
		if BookAPI.get_current_spread() > 0:
			BookAPI.go_to_spread(BookAPI.get_current_book(), 0)
		else:
			main_scene.close_book()
		return
	
	var external_controls: Array[Control] = [
		go_to_page_left, go_to_page_right, back
	]
	var left_controls: Array[Control] = BookAPI.get_focusable_controls(null, true)
	var right_controls: Array[Control] = BookAPI.get_focusable_controls(null, false)

	for c in left_controls + right_controls + external_controls:
		if c.has_focus():
			_current_active_control = c
			break
	
	if not _current_active_control:
		external_controls[0].grab_focus()
		_current_active_control = external_controls[0]
		return
	
	var direction = ControllerManager.get_pressed_direction()
	
	if direction:
		if _current_active_control in external_controls:
			if direction == "left":
				if _current_active_control == go_to_page_left:
					go_to_page_right.grab_focus()
					GameManager.play_fx("cursor")
				elif right_controls.size() > 0:
					right_controls[-1].grab_focus()
					_update_internal_cursor_position(right_controls[-1])
					GameManager.play_fx("cursor")
				elif left_controls.size() > 0:
					left_controls[-1].grab_focus()
					_update_internal_cursor_position(left_controls[-1])
					GameManager.play_fx("cursor")
			elif direction == "right":
				if _current_active_control == go_to_page_left:
					if left_controls.size() > 0:
						left_controls[0].grab_focus()
						_update_internal_cursor_position(left_controls[0])
						GameManager.play_fx("cursor")
					elif right_controls.size() > 0:
						right_controls[0].grab_focus()
						_update_internal_cursor_position(right_controls[0])
						GameManager.play_fx("cursor")
				else:
					go_to_page_left.grab_focus()
					GameManager.play_fx("cursor")
			elif _current_active_control == back:
				go_to_page_right.grab_focus()
				GameManager.play_fx("cursor")
			else:
				go_to_page_left.grab_focus()
				GameManager.play_fx("cursor")
		else:
			if _current_active_control is ItemList:
				GameManager.play_fx("cursor")
			elif _current_active_control is VScrollBar and direction in ["up", "down"] and _current_active_control.max_value != 0.0 and _current_active_control.max_value > _current_active_control.page:
				pass
			elif _current_active_control is HScrollBar and direction in ["right", "left"] and _current_active_control.max_value != 0.0 and _current_active_control.max_value > _current_active_control.page:
				pass
			else:
				var c = _find_next_control(_current_active_control, left_controls + right_controls, direction)
				if c:
					c.grab_focus()
					_update_internal_cursor_position(c)
					GameManager.play_fx("cursor")
				else:
					if direction == "left":
						go_to_page_left.grab_focus()
						GameManager.play_fx("cursor")
					elif direction == "right":
						go_to_page_right.grab_focus()
						GameManager.play_fx("cursor")
					else:
						go_to_page_left.grab_focus()
						GameManager.play_fx("cursor")


func _config_hand_in_selectable_books() -> void:
	GameManager.enable_cursor_outline(Color("cbc1b692"))
	GameManager.set_cursor_manipulator(manipulator)
	GameManager.set_confin_area(Rect2(), manipulator)
	GameManager.set_hand_position(MainHandCursor.HandPosition.LEFT, manipulator)
	GameManager.set_cursor_offset(Vector2(-6, 5), manipulator)


func _config_hand_in_back_button() -> void:
	GameManager.set_hand_position(MainHandCursor.HandPosition.UP, manipulator)
	GameManager.set_cursor_offset(Vector2(0, 2), manipulator)


func _on_back_button_pressed() -> void:
	if not started: return
	
	started = false
	
	GameManager.set_fx_busy(true)
	back_button.select(true)
	GameManager.set_fx_busy(false)
	
	if title_scene:
		title_scene.end()
	
	get_viewport().gui_release_focus()
	GameManager.force_hide_cursor()
	GameManager.disable_cursor_outline()
	GameManager.play_fx("cancel")
	
	if scene_parent:
		scene_parent.emit_signal_starting_end()
	
	await get_tree().create_timer(0.2).timeout
	
	if GameManager.cursor_manager and GameManager.cursor_manager.hand_cursor:
		GameManager.cursor_manager.hand_cursor.hide_hand_when_mouse_over_focused = true
	
	if scene_parent:
		scene_parent.destroy()
		GameManager.set_cursor_manipulator(_last_manipulator)


func _on_back_button_selected() -> void:
	_config_hand_in_back_button()


func _on_encyclopedia_button_pressed(button_id: int) -> void:
	if BookAPI.is_busy(): return
	
	if main_scene:
		if button_id == 0:
			main_scene.turn_page_to("left")
			go_to_page_left.grab_focus()
		elif button_id == 1:
			main_scene.turn_page_to("right")
			go_to_page_right.grab_focus()
		else:
			if BookAPI.get_current_spread() == 0:
				main_scene.close_book()
			else:
				BookAPI.go_to_spread(BookAPI.get_current_book(), 0)


func _is_internal_control(control: Control) -> bool:
	return control in [go_to_page_left, go_to_page_right, back]


func _get_control_screen_center(control: Control) -> Vector2:
	if not is_instance_valid(control):
		return Vector2.ZERO
	
	if _is_internal_control(control):
		var book = BookAPI.get_current_book()
		var sv = control.get_viewport()
		var is_left = (sv == book._slot_1)
		var viewport_center = control.global_position + control.size * 0.5
		return book.viewport_to_global_curved(viewport_center, is_left)
	else:
		return control.get_global_rect().get_center()


func _update_internal_cursor_position(control: Control) -> void:
	if not is_instance_valid(control):
		return
		
	var book = BookAPI.get_current_book()
	if not book:
		return
		
	var sv = control.get_viewport()
	var is_left = (sv == book._slot_1)
	
	if control is ItemList:
		return
		
	var cursor_manager = GameManager.cursor_manager
	if not cursor_manager or not cursor_manager.hand_cursor:
		return
		
	var hand_cursor = cursor_manager.hand_cursor
	
	var local_offset = Vector2.ZERO
	var screen_offset = Vector2.ZERO
	
	var w = 0.0
	var h = 0.0
	if is_instance_valid(hand_cursor.cursor) and hand_cursor.cursor.get_texture():
		w = hand_cursor.cursor.get_texture().get_width() * 0.5
		h = hand_cursor.cursor.get_texture().get_height() * 0.5
		
	match hand_cursor.current_hand_position:
		hand_cursor.HandPosition.LEFT:
			local_offset = Vector2(0, control.size.y * 0.5)
			screen_offset = Vector2(-w, 0)
		hand_cursor.HandPosition.RIGHT:
			local_offset = Vector2(control.size.x, control.size.y * 0.5)
			screen_offset = Vector2(w, 0)
		hand_cursor.HandPosition.UP:
			local_offset = Vector2(control.size.x * 0.5, 0)
			screen_offset = Vector2(0, -h)
		hand_cursor.HandPosition.DOWN:
			local_offset = Vector2(control.size.x * 0.5, control.size.y)
			screen_offset = Vector2(0, h)
			
	var viewport_pos = control.global_position + local_offset
	var global_pos = book.viewport_to_global_curved(viewport_pos, is_left)
	var final_pos = global_pos + screen_offset + hand_cursor.hand_offset
	
	GameManager.set_manual_cursor_override(control, final_pos)


func _find_next_control(current: Control, controls: Array, direction: String) -> Control:
	var book = BookAPI.get_current_book()
	if not book or not current or controls.is_empty():
		return null
		
	var current_center = _get_control_screen_center(current)
	var best_control: Control = null
	var min_distance = INF
	
	for control in controls:
		if control == current or not is_instance_valid(control):
			continue
		var c_center = _get_control_screen_center(control)
		var is_valid = false
		
		match direction:
			"left":
				if c_center.x < current_center.x - 2.0:
					is_valid = true
			"right":
				if c_center.x > current_center.x + 2.0:
					is_valid = true
			"up":
				if c_center.y < current_center.y - 2.0:
					is_valid = true
			"down":
				if c_center.y > current_center.y + 2.0:
					is_valid = true
					
		if is_valid:
			var diff = c_center - current_center
			var dist: float
			if direction == "left" or direction == "right":
				dist = abs(diff.x) + abs(diff.y) * 2.0
			else:
				dist = abs(diff.y) + abs(diff.x) * 2.0
				
			if dist < min_distance:
				min_distance = dist
				best_control = control
				
	return best_control
