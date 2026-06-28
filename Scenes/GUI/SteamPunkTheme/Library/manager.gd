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


func _ready() -> void:
	_last_manipulator = GameManager.get_cursor_manipulator()
	
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
			await main_scene.animation_in_finished
		
		GameManager.force_show_cursor()
		
		started = true


func _on_book_opened() -> void:
	book_opened = true
	if back_button: back_button.set_disabled(true)


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
			if ControllerManager.is_cancel_just_pressed():
				main_scene.close_book()
		#var direction = ControllerManager.get_pressed_direction()
		#
		#if direction == "left":
			#main_scene.turn_page_to("left")
		#elif direction == "right":
			#main_scene.turn_page_to("right")
		#elif ControllerManager.is_cancel_just_pressed():
			#main_scene.close_book()


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
	
	if scene_parent:
		scene_parent.destroy()
		scene_parent.emit_signal_end()
		GameManager.set_cursor_manipulator(_last_manipulator)


func _on_back_button_selected() -> void:
	_config_hand_in_back_button()


func _on_encyclopedia_button_pressed(button_id: int) -> void:
	if BookAPI.is_busy(): return
	
	if main_scene:
		if button_id == 0:
			main_scene.turn_page_to("left")
		elif button_id == 1:
			main_scene.turn_page_to("right")
		else:
			if BookAPI.get_current_spread() == 0:
				main_scene.close_book()
			else:
				BookAPI.go_to_spread(BookAPI.get_current_book(), 0)
