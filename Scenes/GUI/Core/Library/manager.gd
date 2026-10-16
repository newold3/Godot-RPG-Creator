class_name GuiCoreLibraryManager
extends Node

#region ExportsAndVariables
@export var scene_parent: Control
@export var back_button: Control
@export var main_scene: Control
@export var title_scene: Control

@export var go_to_page_left_button: Control
@export var go_to_page_right_button: Control
@export var back_nav_button: Control

const manipulator: String = "LIBRARY_MANIPULATOR"
var started: bool = false
var book_opened: bool = false
var _last_manipulator: Variant
var _current_book: String = ""
var busy: bool = false
var _current_active_control: Control

var go_to_page_left: Control:
	get:
		if go_to_page_left_button: return go_to_page_left_button
		if has_node("%GoToPageLeft"): return get_node("%GoToPageLeft")
		return get_node_or_null("../SceneMainContainer/MainContainer/ContentsContainer/MainSceneContainer/Encyclopedia/Book/BookExtraControls/GoToPageLeft")

var go_to_page_right: Control:
	get:
		if go_to_page_right_button: return go_to_page_right_button
		if has_node("%GoToPageRight"): return get_node("%GoToPageRight")
		return get_node_or_null("../SceneMainContainer/MainContainer/ContentsContainer/MainSceneContainer/Encyclopedia/Book/BookExtraControls/GoToPageRight")

var back: Control:
	get:
		if back_nav_button: return back_nav_button
		if has_node("%Back"): return get_node("%Back")
		return get_node_or_null("../SceneMainContainer/MainContainer/ContentsContainer/MainSceneContainer/Encyclopedia/Book/BookExtraControls/Back")
#endregion



#region VirtualPresentationHooks
func _play_cursor_fx() -> void:
	pass


func _play_cancel_fx() -> void:
	pass


func _config_hand_for_books() -> void:
	pass


func _config_hand_for_back_button() -> void:
	pass


func _on_book_opened_presentation() -> void:
	pass


func _on_book_closed_presentation() -> void:
	pass
#endregion



#region Lifecycle
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
		
		var books: Array = main_scene.get_books() if main_scene.has_method("get_books") else []
		if not books.is_empty():
			for book: Control in books:
				if not book.focus_entered.is_connected(_config_hand_for_books):
					book.focus_entered.connect(_config_hand_for_books)
			
			books[0].grab_focus()
			GameManager.force_hand_position_over_node(manipulator)
		
		_config_hand_for_books.call_deferred()
	
		if scene_parent and "running_starting_animation" in scene_parent and scene_parent.running_starting_animation:
			await scene_parent.animation_in_finished
		
		GameManager.force_show_cursor()
		
		var gl = go_to_page_left
		var gr = go_to_page_right
		var b = back
		
		if gl: gl.focus_entered.connect(_select_external_control.bind(gl), CONNECT_DEFERRED)
		if gr: gr.focus_entered.connect(_select_external_control.bind(gr), CONNECT_DEFERRED)
		if b: b.focus_entered.connect(_select_external_control.bind(b), CONNECT_DEFERRED)
		
		for btn in [gl, gr, b]:
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
	if back_button and back_button.has_method("set_disabled"): back_button.set_disabled(true)
	GameManager.set_cursor_manipulator(manipulator)
	GameManager.force_show_cursor()
	_on_book_opened_presentation()


func _on_book_closed() -> void:
	book_opened = false
	if back_button and back_button.has_method("set_disabled"): back_button.set_disabled(false)
	_config_hand_for_books()
	GameManager.clear_manual_cursor_override()
	GameManager.force_show_cursor()
	_on_book_closed_presentation()


func _on_book_selected(_book_id: String) -> void:
	_current_book = _book_id
	busy = false
#endregion



#region ProcessAndNavigation
func _process(_delta: float) -> void:
	if not started or busy or (main_scene and "busy" in main_scene and main_scene.busy) or BookAPI.is_busy():
		return

	if not book_opened:
		var direction = ControllerManager.get_pressed_direction()
		
		if main_scene and direction:
			var books: Array = main_scene.get_books() if main_scene.has_method("get_books") else []
			var current_focused = get_viewport().gui_get_focus_owner()
			
			if not current_focused in books and current_focused != back_button:
				current_focused = main_scene.get_selected_book() if main_scene.has_method("get_selected_book") else null
				
			if not current_focused and not books.is_empty():
				current_focused = books[0]
				
			if current_focused:
				var search_list = books + ([back_button] if back_button else [])
				var next_control = ControllerManager.find_closest_control_in_list_by_direction(current_focused, search_list, direction)
				
				if next_control:
					if next_control == back_button:
						if back_button.has_method("select"): back_button.select()
					else:
						if main_scene.has_method("select"): main_scene.select(next_control)
						
					_play_cursor_fx()
					
		elif ControllerManager.is_cancel_just_pressed():
			_on_back_button_pressed()
		
		elif ControllerManager.is_key_just_pressed(KEY_ENTER):
			if main_scene and _current_book:
				if _current_book == "main_book" or (main_scene and "current_book" in main_scene and _current_book == main_scene.current_book):
					GameManager.set_cursor_manipulator(GameManager.MANIPULATOR_MODES.NONE)
					GameManager.force_hide_cursor()
					
					if back_button and back_button.has_method("set_disabled"):
						back_button.set_disabled(true)
						
					GameManager.force_hide_cursor()
					if main_scene.has_method("open_book"): main_scene.open_book()
				else:
					GameManager.set_cursor_manipulator(GameManager.MANIPULATOR_MODES.NONE)
					GameManager.force_hide_cursor()
					
					if back_button and back_button.has_method("set_disabled"):
						back_button.set_disabled(true)
						
					if main_scene.has_method("update_book") and main_scene.update_book(_current_book, false, true):
						busy = true
		
		elif ControllerManager.is_confirm_pressed(false, [], true, []):
			if main_scene and _current_book:
				if _current_book == "main_book" or (main_scene and "current_book" in main_scene and _current_book == main_scene.current_book):
					GameManager.set_cursor_manipulator(GameManager.MANIPULATOR_MODES.NONE)
					GameManager.force_hide_cursor()
					
					if back_button and back_button.has_method("set_disabled"):
						back_button.set_disabled(true)
						
					if main_scene.has_method("open_book"): main_scene.open_book()
				else:
					if main_scene.has_method("update_book") and main_scene.update_book(_current_book):
						busy = true
	
	elif main_scene:
		if book_opened:
			_process_open_book_navigation()


func _process_open_book_navigation() -> void:
	if Input.is_physical_key_pressed(KEY_ESCAPE) or Input.is_key_pressed(KEY_ESCAPE):
		if main_scene and main_scene.has_method("close_book"): main_scene.close_book()
		return
	elif ControllerManager.is_cancel_just_pressed():
		if BookAPI.get_current_spread() > 0:
			BookAPI.go_to_spread(BookAPI.get_current_book(), 0)
		else:
			if main_scene and main_scene.has_method("close_book"): main_scene.close_book()
		return
	
	var gl = go_to_page_left
	var gr = go_to_page_right
	var b = back
	
	var external_controls: Array[Control] = []
	if gl: external_controls.append(gl)
	if gr: external_controls.append(gr)
	if b: external_controls.append(b)
	
	var left_controls: Array[Control] = BookAPI.get_focusable_controls(null, true)
	var right_controls: Array[Control] = BookAPI.get_focusable_controls(null, false)

	for c in left_controls + right_controls + external_controls:
		if c.has_focus():
			_current_active_control = c
			break
	
	if not _current_active_control and not external_controls.is_empty():
		external_controls[0].grab_focus()
		_current_active_control = external_controls[0]
		return
	
	var direction = ControllerManager.get_pressed_direction()
	
	if direction:
		if _current_active_control in external_controls:
			if direction == "left":
				if _current_active_control == gl:
					if gr: gr.grab_focus()
					_play_cursor_fx()
				elif right_controls.size() > 0:
					right_controls[-1].grab_focus()
					_update_internal_cursor_position(right_controls[-1])
					_play_cursor_fx()
				elif left_controls.size() > 0:
					left_controls[-1].grab_focus()
					_update_internal_cursor_position(left_controls[-1])
					_play_cursor_fx()
			elif direction == "right":
				if _current_active_control == gl:
					if left_controls.size() > 0:
						left_controls[0].grab_focus()
						_update_internal_cursor_position(left_controls[0])
						_play_cursor_fx()
					elif right_controls.size() > 0:
						right_controls[0].grab_focus()
						_update_internal_cursor_position(right_controls[0])
						_play_cursor_fx()
				else:
					if gl: gl.grab_focus()
					_play_cursor_fx()
			elif _current_active_control == b:
				if gr: gr.grab_focus()
				_play_cursor_fx()
			else:
				if gl: gl.grab_focus()
				_play_cursor_fx()
		else:
			if _current_active_control is ItemList:
				_play_cursor_fx()
			elif _current_active_control is VScrollBar and direction in ["up", "down"] and _current_active_control.max_value != 0.0 and _current_active_control.max_value > _current_active_control.page:
				pass
			elif _current_active_control is HScrollBar and direction in ["right", "left"] and _current_active_control.max_value != 0.0 and _current_active_control.max_value > _current_active_control.page:
				pass
			else:
				var c = _find_next_control(_current_active_control, left_controls + right_controls, direction)
				if c:
					c.grab_focus()
					_update_internal_cursor_position(c)
					_play_cursor_fx()
				else:
					if direction == "left":
						if gl: gl.grab_focus()
						_play_cursor_fx()
					elif direction == "right":
						if gr: gr.grab_focus()
						_play_cursor_fx()
					else:
						if gl: gl.grab_focus()
						_play_cursor_fx()


func _on_back_button_pressed() -> void:
	if not started: return
	
	started = false
	GameManager.set_fx_busy(true)
	if back_button and back_button.has_method("select"):
		back_button.select(true)
	GameManager.set_fx_busy(false)
	
	if title_scene and title_scene.has_method("end"):
		title_scene.end()
	
	get_viewport().gui_release_focus()
	GameManager.force_hide_cursor()
	GameManager.disable_cursor_outline()
	_play_cancel_fx()
	
	if scene_parent and scene_parent.has_method("emit_signal_starting_end"):
		scene_parent.emit_signal_starting_end()
	
	await get_tree().create_timer(0.2).timeout
	
	if GameManager.cursor_manager and GameManager.cursor_manager.hand_cursor:
		GameManager.cursor_manager.hand_cursor.hide_hand_when_mouse_over_focused = true
	
	if scene_parent:
		if scene_parent.has_method("destroy"): scene_parent.destroy()
		GameManager.set_cursor_manipulator(_last_manipulator)


func _on_back_button_selected() -> void:
	_config_hand_for_back_button()


func _on_encyclopedia_button_pressed(button_id: int) -> void:
	if BookAPI.is_busy(): return
	
	var gl = go_to_page_left
	var gr = go_to_page_right
	
	if main_scene:
		if button_id == 0:
			if main_scene.has_method("turn_page_to"): main_scene.turn_page_to("left")
			if gl: gl.grab_focus()
		elif button_id == 1:
			if main_scene.has_method("turn_page_to"): main_scene.turn_page_to("right")
			if gr: gr.grab_focus()
		else:
			if BookAPI.get_current_spread() == 0:
				if main_scene.has_method("close_book"): main_scene.close_book()
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
		var is_left = (book and sv == book._slot_1)
		var viewport_center = control.global_position + control.size * 0.5
		return book.viewport_to_global_curved(viewport_center, is_left) if book else control.get_global_rect().get_center()
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
#endregion
