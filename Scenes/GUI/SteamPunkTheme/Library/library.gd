extends GuiCoreLibrary

#region SteamPunkExportsAndPreloads
@export_file("*.tscn") var bestiary_scene_path: String = "res://Scenes/GUI/SteamPunkTheme/Library/Books/bestiary.tscn"
@export_file("*.tscn") var recipes_scene_path: String = "res://Scenes/GUI/SteamPunkTheme/Library/Books/recipes.tscn"
@export_file("*.tscn") var items_scene_path: String = "res://Scenes/GUI/SteamPunkTheme/Library/Books/items.tscn"

const LIBRARY_BOOK_NAME = preload("uid://btgo3w2tyvqrj")
const SFX_BOOK_SWITCH = preload("uid://djskkuanh66hp")

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

var _last_tooltip: Control = null
#endregion



#region CoreHookOverrides
func _get_bestiary_scene_path() -> String:
	return bestiary_scene_path


func _get_recipes_scene_path() -> String:
	return recipes_scene_path


func _get_items_scene_path() -> String:
	return items_scene_path


func _setup_presentation() -> void:
	ControllerManager.controller_changed.connect(_on_controller_changed.unbind(1))
	_update_controller_icons()
	_apply_day_night_lighting()


func _on_controller_changed() -> void:
	_update_controller_icons()


func _update_controller_icons() -> void:
	var layout: Dictionary = ControllerManager.get_current_controller_mapping()
	if has_node("%ButtonL1") and layout.has("l1"):
		get_node("%ButtonL1").texture = layout.l1.icon.get_texture()
	if has_node("%ButtonR1") and layout.has("r1"):
		get_node("%ButtonR1").texture = layout.r1.icon.get_texture()
	if has_node("%ButtonCircle") and layout.has("b"):
		get_node("%ButtonCircle").texture = layout.b.icon.get_texture()


func _apply_day_night_lighting() -> void:
	var external_color = DayNightManager.get_ambient_color() if DayNightManager else Color.WHITE
	var day_phase = DayNightManager.get_day_phase() if DayNightManager else "day"
	if day_phase == "dusk":
		external_color = external_color.darkened(0.4)
	elif day_phase == "night":
		external_color = external_color.darkened(0.7)
	else:
		external_color = external_color.lightened(0.2)
		 
	if has_node("%ExternalLight"):
		get_node("%ExternalLight").color = external_color.darkened(0.15)


func _apply_book_visuals(type: String, _is_initial: bool, _open_immediately: bool, on_finish: Callable) -> void:
	var book = get_animate_book()
	if not book:
		on_finish.call()
		return
	
	if books_data.has(type):
		book.spine_texture = load(books_data[type].spine)
		book.tex_cover_front_out = load(books_data[type].cover)
		book.tex_cover_front_in = load(books_data[type].interior)
		book.tex_cover_back_in = load(books_data[type].interior)
		book.tex_cover_back_out = load(books_data[type].back)
	book.refresh()
	book.visible = false
	
	var new_book = get_node_or_null("%NewBook") as TextureRect
	var last_book = get_node_or_null("%LastBook") as TextureRect
	var new_book_start_pos = get_node_or_null("%NewBookStartPosition") as Control
	var last_book_start_pos = get_node_or_null("%LastBookStartPosition") as Control
	
	if not new_book or not last_book or not new_book_start_pos or not last_book_start_pos:
		book.visible = true
		on_finish.call()
		return
	
	var next_book = load(books_data[type].preview) if books_data.has(type) else null
	var old_book = next_book if current_book.is_empty() else (load(books_data[current_book].preview) if books_data.has(current_book) else null)
	
	var new_book_offset = next_book.get_size() * 0.5 if next_book else Vector2.ZERO
	new_book.texture = next_book
	new_book.position = new_book_start_pos.position - new_book_offset
	new_book.modulate.a = 0.0
	
	var old_book_offset = old_book.get_size() * 0.5 if old_book else Vector2.ZERO
	last_book.texture = old_book
	last_book.position = last_book_start_pos.position - old_book_offset
	var mat: ShaderMaterial = last_book.get_material()
	if mat:
		mat.set_shader_parameter("dissolve_value", 1.0)
	
	new_book.visible = true
	last_book.visible = true
	
	var t = create_tween()
	t.set_parallel(true)
	if mat:
		t.tween_property(mat, "shader_parameter/dissolve_value", 0.0, 0.5)
	t.tween_property(new_book, "modulate:a", 1.0, 0.3)
	t.tween_property(new_book, "position", last_book_start_pos.position - old_book_offset, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	
	t.set_parallel(false)
	t.tween_callback(
		func():
			book.play_sound(book.sfx_book_impact)
			book._snap_book_to_exact_state()
			book.visible = true
			new_book.visible = false
			last_book.visible = false
			on_finish.call()
	)
	
	GameManager.play_se(SFX_BOOK_SWITCH, -10, randf_range(0.9, 1.1))


func _on_open_book_presentation() -> void:
	_background_blur(4.0)
	_enable_extra_controls()


func _on_close_book_presentation() -> void:
	_background_blur(0.0)
	_disable_extra_controls()


func _on_turn_page_presentation(direction: String) -> void:
	if direction == "left":
		var book = get_animate_book()
		if book and book.current_spread == 0:
			_background_blur(0.0)


func _on_page_flip_2d_book_opened() -> void:
	super._on_page_flip_2d_book_opened()
	if has_node("%MainBookParticles"):
		var p = get_node("%MainBookParticles")
		p.speed_scale = 8.0
		p.emitting = false
		p.z_index = 0


func _on_page_flip_2d_book_closed() -> void:
	super._on_page_flip_2d_book_closed()
	if has_node("%MainBookParticles"):
		var p = get_node("%MainBookParticles")
		p.speed_scale = 1.0
		p.emitting = true
		p.z_index = 115
	_disable_extra_controls()


func _background_blur(blur_strength: float) -> void:
	if has_node("%BackgroundBlur"):
		var node = get_node("%BackgroundBlur")
		var mat = node.get_material()
		if mat:
			if blur_strength > 0.001:
				node.visible = true
			var t = create_tween()
			t.tween_property(mat, "shader_parameter/blur_strength", blur_strength, 0.4)
			if blur_strength <= 0.001:
				t.tween_callback(func(): if is_instance_valid(node): node.visible = false)


func _enable_extra_controls() -> void:
	if has_node("%GoToPageLeft"): get_node("%GoToPageLeft").set_disabled(true)
	if has_node("%GoToPageRight"): get_node("%GoToPageRight").set_disabled(true)
	if has_node("%Back"): get_node("%Back").set_disabled(true)
	
	if has_node("%BookExtraControls"):
		var c = get_node("%BookExtraControls")
		c.modulate.a = 0.0
		c.visible = true
		var t = create_tween()
		t.tween_property(c, "modulate:a", 1.0, 0.5)
		t.tween_callback(_update_navigation_buttons)


func _disable_extra_controls() -> void:
	if has_node("%GoToPageLeft"): get_node("%GoToPageLeft").set_disabled(true)
	if has_node("%GoToPageRight"): get_node("%GoToPageRight").set_disabled(true)
	if has_node("%Back"): get_node("%Back").set_disabled(true)
	
	if has_node("%BookExtraControls"):
		var c = get_node("%BookExtraControls")
		var t = create_tween()
		t.tween_property(c, "modulate:a", 0.0, 0.5)
		t.tween_callback(c.set_visible.bind(false))


func _show_tooltip_over_book(book_id: String) -> void:
	var node = LIBRARY_BOOK_NAME.instantiate()
	if has_node("%Book"):
		get_node("%Book").add_child(node)
	node.start(book_id)
	_last_tooltip = node


func _hide_tooltip_over_book() -> void:
	if _last_tooltip and is_instance_valid(_last_tooltip):
		_last_tooltip.end()
		_last_tooltip = null


func _on_book_cursor_focused(book_id: String) -> void:
	var cursor_map = {
		"encyclopedia": "%Book1Cursor",
		"bestiary": "%Book2Cursor",
		"inventory": "%Book3Cursor",
		"recipes": "%Book4Cursor"
	}
	var node_name = cursor_map.get(book_id, "")
	if not node_name.is_empty() and has_node(node_name):
		get_node(node_name).modulate = Color.YELLOW


func _on_book_cursor_unfocused(book_id: String) -> void:
	var cursor_map = {
		"encyclopedia": "%Book1Cursor",
		"bestiary": "%Book2Cursor",
		"inventory": "%Book3Cursor",
		"recipes": "%Book4Cursor"
	}
	var node_name = cursor_map.get(book_id, "")
	if not node_name.is_empty() and has_node(node_name):
		get_node(node_name).modulate = Color.WHITE


func _on_main_book_cursor_focused() -> void:
	if has_node("%MainBookParticles"):
		var p = get_node("%MainBookParticles")
		p.speed_scale = 1.0
		p.emitting = true


func _on_main_book_cursor_unfocused() -> void:
	if has_node("%MainBookParticles"):
		var p = get_node("%MainBookParticles")
		p.speed_scale = 1.2
		p.emitting = false


func _on_nav_button_focused(button_id: int) -> void:
	var manipulator = GameManager.get_cursor_manipulator()
	match button_id:
		0: # Left
			GameManager.set_hand_position(MainHandCursor.HandPosition.RIGHT, manipulator)
			GameManager.set_cursor_offset(Vector2(0, 0), manipulator)
		1: # Right
			GameManager.set_hand_position(MainHandCursor.HandPosition.LEFT, manipulator)
			GameManager.set_cursor_offset(Vector2(0, 0), manipulator)
		2: # Back
			GameManager.set_hand_position(MainHandCursor.HandPosition.UP, manipulator)
			GameManager.set_cursor_offset(Vector2(0, 0), manipulator)
	GameManager.force_show_cursor()
#endregion
