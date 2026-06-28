extends Control


var books_data = {
	"encyclopedia":
	{
		"cover": "res://InternalTests/newbook/cover_front.png",
		"back": "res://InternalTests/newbook/cover_back.png",
		"interior": "res://InternalTests/newbook/cover_interior.png",
		"spine": "res://InternalTests/newbook/spine.png",
		"preview": "res://InternalTests/newbook/book_encyclopedia.png"
	},
	"bestiary":
	{
		"cover": "res://InternalTests/newbook/cover_front_bestiary.png",
		"back": "res://InternalTests/newbook/cover_back_bestiary.png",
		"interior": "res://InternalTests/newbook/cover_interior_bestiary.png",
		"spine": "res://InternalTests/newbook/spine_bestiary.png",
		"preview": "res://InternalTests/newbook/book_bestiary.png"
	},
	"inventory":
	{
		"cover": "res://InternalTests/newbook/cover_front_inventory.png",
		"back": "res://InternalTests/newbook/cover_back_inventory.png",
		"interior": "res://InternalTests/newbook/cover_interior_inventory.png",
		"spine": "res://InternalTests/newbook/spine_inventory.png",
		"preview": "res://InternalTests/newbook/book_inventory.png"
	},
	"recipes":
	{
		"cover": "res://InternalTests/newbook/cover_front_recipes.png",
		"back": "res://InternalTests/newbook/cover_back_recipes.png",
		"interior": "res://InternalTests/newbook/cover_interior_recipes.png",
		"spine": "res://InternalTests/newbook/spine_recipes.png",
		"preview": "res://InternalTests/newbook/book_recipes.png"
	}
}

var book_is_opened: bool = false
var current_book: String = ""
var current_cursor_book: String = ""
var busy: bool = false
var _last_tooltip: Control
var current_book_speed_scale: float = 1.0
var speed_scale_step: float = 40.0


@onready var book_container: Control = %Book
@onready var animate_book: PageFlip2D = %AnimateBook
@onready var new_book: TextureRect = %NewBook
@onready var last_book: TextureRect = %LastBook
@onready var new_book_start_position: Control = %NewBookStartPosition
@onready var last_book_start_position: Control = %LastBookStartPosition

const LIBRARY_BOOK_NAME = preload("uid://btgo3w2tyvqrj")


signal book_selected(id: String)
signal book_opened()
signal book_closed()
signal button_pressed(button_id: int) # 0 = prev, 1 = next, 2 = back


func _ready() -> void:
	BookAPI.disable_book(animate_book)
	BookAPI.set_interaction_lock(animate_book, true)
	update_book.call_deferred("encyclopedia", true)
	
	StaticSignal.connect_static_signal("target_item_list_item_hovered_local", _on_custom_target_item_list_item_hovered_local)
	StaticSignal.connect_static_signal("target_item_list_item_unhovered_local", _on_custom_target_item_list_item_unhovered_local)
	
	ControllerManager.controller_changed.connect(_on_controller_changed.unbind(1))
	
	var external_color = DayNightManager.get_ambient_color()
	var day_phase = DayNightManager.get_day_phase()
	if day_phase == "dusk":
		external_color = external_color.darkened(0.4)
	elif day_phase == "night":
		external_color = external_color.darkened(0.7)
	else:
		external_color = external_color.lightened(0.2)
		 
	%ExternalLight.color = external_color.darkened(0.15)


func _on_controller_changed() -> void:
	var layout: Dictionary = ControllerManager.get_current_controller_mapping()
	
	%ButtonL1.texture = layout.l1.icon.get_texture()
	%ButtonR1.texture = layout.r1.icon.get_texture()
	%ButtonCircle.texture = layout.b.icon.get_texture()


func get_books() -> Array:
	return [
		%EncyclopediaCursor,
		%BestiaryCursor,
		%inventoryCursor,
		%RecipesCursor,
		%MainBookCursor
	]


func get_selectable_books() -> Array:
	return [
		%EncyclopediaCursor,
		%BestiaryCursor,
		%inventoryCursor,
		%RecipesCursor
	]


func get_selected_book() -> Control:
	var _books = {
		"encyclopedia": %EncyclopediaCursor,
		"bestiary": %BestiaryCursor,
		"inventory": %inventoryCursor,
		"recipes": %RecipesCursor,
		"main_book": %MainBookCursor
		
	}
	var _current_book = _books.get(current_book, null)
	
	return _current_book


func select(book: Control) -> void:
	if book in get_books():
		if book.has_focus():
			return
		book.grab_focus()


func get_main_book() -> PageFlip2D:
	return animate_book


func turn_page_to(direction: String) -> void:
	if not book_is_opened: return
	
	if ControllerManager.is_direction_just_pressed(direction) or ControllerManager.is_direction_just_released(direction):
		current_book_speed_scale = 1.0
		
	if direction == "left":
		if animate_book.current_spread == 0:
			BookAPI.set_book_speed(animate_book, 1.0)
			_background_blur(0.0)
		else:
			BookAPI.set_book_speed(animate_book, current_book_speed_scale)
			current_book_speed_scale = min(current_book_speed_scale + get_process_delta_time() * speed_scale_step, 3.0)
		BookAPI.prev_page(animate_book)
	elif direction == "right":
		current_book_speed_scale = min(current_book_speed_scale + get_process_delta_time() * speed_scale_step, 3.0)
		
		BookAPI.set_book_speed(animate_book, current_book_speed_scale)
		BookAPI.next_page(animate_book)
	else:
		current_book_speed_scale = 1.0


## Called when the book has fully opened.
func _on_page_flip_2d_book_opened() -> void:
	book_is_opened = true
	busy = false
	
	%MainBookParticles.speed_scale = 8.0
	%MainBookParticles.emitting = false
	%MainBookParticles.z_index = 0
	book_opened.emit()


## Called when the book has fully closed.
func _on_page_flip_2d_book_closed() -> void:
	book_is_opened = false
	busy = false
	book_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	%MainBookParticles.speed_scale = 1.0
	%MainBookParticles.emitting = true
	%MainBookParticles.z_index = 115
	book_closed.emit()
	
	_disable_extra_controls()


func open_book() -> void:
	if busy or book_is_opened:
		return
		
	busy = true
	book_container.mouse_filter = Control.MOUSE_FILTER_STOP
	current_book_speed_scale = 1.0
	BookAPI.set_book_speed(animate_book, current_book_speed_scale)
	
	if animate_book.current_spread == -1:
		BookAPI.next_page()
	else:
		BookAPI.go_to_spread(animate_book, 0, true)
		
	_background_blur(4.0)
	_enable_extra_controls()


func close_book() -> void:
	if busy or not book_is_opened:
		return
		
	busy = true
	book_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	current_book_speed_scale = 1.0
	BookAPI.set_book_speed(animate_book, current_book_speed_scale)
	BookAPI.go_to_spread(animate_book, -1, true)
	
	_background_blur(0.0)
	_disable_extra_controls()


func _background_blur(blur_strength: float) -> void:
	var mat = %BackgroundBlur.get_material()
	var t = create_tween()
	t.tween_property(mat, "shader_parameter/blur_strength", blur_strength, 0.4)


func update_book(type: String, _is_initial_update: bool = false, open_immediately: bool = false) -> bool:
	if current_book == type: return false
	
	busy = true
	
	var book = animate_book
	
	match type:
		"bestiary":
			var pages = RPGSYSTEM.database.enemies.slice(1)
			var scene_path = "res://Scenes/GUI/SteamPunkTheme/Library/Books/bestiary.tscn"
			var paths: Array[String] = []
			paths.resize(pages.size() * 2 + 3)
			paths.fill(scene_path)
			book.limit_max_pages = pages.size() * 2 + 1
			book.set_new_pages(paths)
		
	
	var next_book = load(books_data[type].preview)
	var old_book = next_book if current_book.is_empty() else load(books_data[current_book].preview)
	
	book.spine_texture = load(books_data[type].spine)
	book.tex_cover_front_out = load(books_data[type].cover)
	book.tex_cover_front_in = load(books_data[type].interior)
	book.tex_cover_back_in = load(books_data[type].interior)
	book.tex_cover_back_out = load(books_data[type].back)
	book.refresh()
	book.visible = false
	
	var new_book_offset = next_book.get_size() * 0.5 if next_book else Vector2.ZERO
	new_book.texture = next_book
	new_book.position = new_book_start_position.position - new_book_offset
	new_book.modulate.a = 0.0
	
	var old_book_offset = old_book.get_size() * 0.5 if old_book else Vector2.ZERO
	last_book.texture = old_book
	last_book.position = last_book_start_position.position - old_book_offset
	var mat: ShaderMaterial = last_book.get_material()
	mat.set_shader_parameter("dissolve_value", 1.0)
	
	new_book.visible = true
	last_book.visible = true
	
	var t = create_tween()
	t.set_parallel(true)
	t.tween_property(mat, "shader_parameter/dissolve_value", 0.0, 0.5)
	t.tween_property(new_book, "modulate:a", 1.0, 0.3)
	t.tween_property(new_book, "position", last_book_start_position.position - old_book_offset, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	
	
	t.set_parallel(false)
	
	t.tween_callback(
		func():
			if _is_initial_update: book._initial_config()
			book.play_sound(book.sfx_book_impact)
			book.visible = true
			new_book.visible = false
			last_book.visible = false
			busy = false
			book_selected.emit(type)
			if open_immediately:
				open_book()
	)
	
	current_book = type
	
	GameManager.play_se(preload("uid://djskkuanh66hp"), -10, randf_range(0.9, 1.1))
	
	return true


func _on_encyclopedia_cursor_gui_input(event: InputEvent) -> void:
	if busy or book_is_opened: return
	
	if event.is_action_pressed("Mouse Left"):
		update_book("encyclopedia")


func _on_bestiary_cursor_gui_input(event: InputEvent) -> void:
	if busy or book_is_opened: return
	
	if event.is_action_pressed("Mouse Left"):
		update_book("bestiary")


func _on_inventory_cursor_gui_input(event: InputEvent) -> void:
	if busy or book_is_opened: return
	
	if event.is_action_pressed("Mouse Left"):
		update_book("inventory")


func _on_recipes_cursor_gui_input(event: InputEvent) -> void:
	if busy or book_is_opened: return
	
	if event.is_action_pressed("Mouse Left"):
		update_book("recipes")


func _show_tooltip_over_book(_book_id: String) -> void:
	var node = LIBRARY_BOOK_NAME.instantiate()
	%Book.add_child(node)
	node.start(_book_id)
	_last_tooltip = node


func _on_encyclopedia_cursor_focus_entered() -> void:
	%Book1Cursor.modulate = Color.YELLOW
	book_selected.emit("encyclopedia")
	_show_tooltip_over_book("encyclopedia")


func _on_bestiary_cursor_focus_entered() -> void:
	%Book2Cursor.modulate = Color.YELLOW
	book_selected.emit("bestiary")
	_show_tooltip_over_book("bestiary")


func _on_inventory_cursor_focus_entered() -> void:
	%Book3Cursor.modulate = Color.YELLOW
	book_selected.emit("inventory")
	_show_tooltip_over_book("inventory")


func _on_recipes_cursor_focus_entered() -> void:
	%Book4Cursor.modulate = Color.YELLOW
	book_selected.emit("recipes")
	_show_tooltip_over_book("recipes")


func _on_encyclopedia_cursor_focus_exited() -> void:
	%Book1Cursor.modulate = Color.WHITE
	if _last_tooltip: _last_tooltip.end()


func _on_bestiary_cursor_focus_exited() -> void:
	%Book2Cursor.modulate = Color.WHITE
	if _last_tooltip: _last_tooltip.end()


func _on_inventory_cursor_focus_exited() -> void:
	%Book3Cursor.modulate = Color.WHITE
	if _last_tooltip: _last_tooltip.end()


func _on_recipes_cursor_focus_exited() -> void:
	%Book4Cursor.modulate = Color.WHITE
	if _last_tooltip: _last_tooltip.end()


func _on_main_book_cursor_focus_entered() -> void:
	%MainBookParticles.speed_scale = 1.0
	%MainBookParticles.emitting = true
	book_selected.emit("main_book")


func _on_main_book_cursor_focus_exited() -> void:
	%MainBookParticles.speed_scale = 1.2
	%MainBookParticles.emitting = false


#region Cursor Translation Block
## Translates the local item position to global screen space using the container position.
func _on_custom_target_item_list_item_hovered_local(local_position: Vector2, target_node: Control) -> void:
	var is_left_page = false
	var sv = target_node.get_viewport()

	if sv and sv.name == "Slot1":
		is_left_page = true
		
	var viewport_pos: Vector2 = target_node.global_position + local_position
	var global_pos: Vector2 = %AnimateBook.viewport_to_global_curved(viewport_pos, is_left_page)
	var sprite_offset: Vector2 = Vector2(-9.0, 2)
	
	GameManager.set_manual_cursor_override(target_node, global_pos + sprite_offset)


## Clears the manual cursor override when the item is no longer hovered.
func _on_custom_target_item_list_item_unhovered_local(target_node: Control) -> void:
	GameManager.clear_manual_cursor_override(target_node)
#endregion


func _on_animate_book_ended_page_flip_animation() -> void:
	if not book_is_opened:
		GameManager.clear_manual_cursor_override()
		select(get_selected_book())
		GameManager.force_show_cursor()
		GameManager.force_hand_position_over_node(GameManager.get_cursor_manipulator())
	#else:
		#_enable_extra_controls()
		#%BookExtraControls.visible = true


func _on_animate_book_started_page_flip_animation() -> void:
	GameManager.clear_manual_cursor_override()
	GameManager.force_hide_cursor()


func _enable_extra_controls() -> void:
	%GoToPageLeft.set_disabled(true)
	%GoToPageRight.set_disabled(true)
	%Back.set_disabled(true)
	
	%BookExtraControls.modulate.a = 0.0
	%BookExtraControls.visible = true
	
	var t = create_tween()
	t.tween_property(%BookExtraControls, "modulate:a", 1.0, 0.5)
	t.tween_callback(
		func():
			%GoToPageLeft.set_disabled(false)
			%GoToPageRight.set_disabled(false)
			%Back.set_disabled(false)
	)


func _disable_extra_controls() -> void:
	%GoToPageLeft.set_disabled(true)
	%GoToPageRight.set_disabled(true)
	%Back.set_disabled(true)
	
	var t = create_tween()
	t.tween_property(%BookExtraControls, "modulate:a", 0.0, 0.5)
	t.tween_callback(%BookExtraControls.set_visible.bind(false))


func _on_go_to_page_left_pressed() -> void:
	button_pressed.emit(0)


func _on_go_to_page_right_pressed() -> void:
	button_pressed.emit(1)


func _on_back_pressed() -> void:
	button_pressed.emit(2)
