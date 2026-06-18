extends Control


var book_is_opened: bool = false
var current_book: String = ""
var busy: bool = false

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

var current_book_speed_scale: float = 1.0
var speed_scale_step: float = 40.0

@onready var animate_book: PageFlip2D = %AnimateBook
@onready var new_book: Sprite2D = %NewBook
@onready var last_book: Sprite2D = %LastBook
@onready var new_book_start_position: Marker2D = %NewBookStartPosition
@onready var last_book_start_position: Marker2D = %LastBookStartPosition


func _ready() -> void:
	BookAPI.disable_book(animate_book)
	BookAPI.set_interaction_lock(animate_book, true)
	#%MainBookCursor.grab_focus()
	_update_book("encyclopedia")


func _input(event: InputEvent) -> void:
	if busy: return
	
	if book_is_opened:
		if event.is_action_pressed("ui_right", true):
			current_book_speed_scale = min(current_book_speed_scale + get_process_delta_time() * speed_scale_step, 3.0)
			BookAPI.set_book_speed(animate_book, current_book_speed_scale)
			BookAPI.next_page(animate_book)
		elif event.is_action_pressed("ui_left", true):
			if animate_book.current_spread == 0:
				BookAPI.set_book_speed(animate_book, 1.0)
				_background_blur(0.0)
			else:
				BookAPI.set_book_speed(animate_book, current_book_speed_scale)
				current_book_speed_scale = min(current_book_speed_scale + get_process_delta_time() * speed_scale_step, 3.0)
			BookAPI.prev_page(animate_book)
		else:
			current_book_speed_scale = 1.0



func _on_page_flip_2d_book_opened() -> void:
	book_is_opened = true
	%MainBookParticles.speed_scale = 8.0
	%MainBookParticles.emitting = false
	%MainBookParticles.z_index = 0


func _on_page_flip_2d_book_closed() -> void:
	book_is_opened = false
	%MainBookParticles.speed_scale = 1.0
	%MainBookParticles.emitting = true
	%MainBookParticles.z_index = 115



func _on_main_book_cursor_gui_input(event: InputEvent) -> void:
	if not book_is_opened:
		if event.is_action_pressed("ui_accept") or event.is_action_pressed("Mouse Left"):
			current_book_speed_scale = 1.0
			BookAPI.set_book_speed(animate_book, current_book_speed_scale)
			if animate_book.current_spread == -1:
				BookAPI.next_page()
			else:
				BookAPI.go_to_spread(animate_book, 0, true)
			_background_blur(4.0)
	elif event.is_action_pressed("ui_accept") or event.is_action_pressed("Mouse Left") or event.is_action_pressed("ui_cancel"):
		current_book_speed_scale = 1.0
		BookAPI.set_book_speed(animate_book, current_book_speed_scale)
		BookAPI.go_to_spread(animate_book, -1, true)
		_background_blur(0.0)


func _background_blur(blur_strength: float) -> void:
	var mat: ShaderMaterial = %BackgroundBlur.get_material()
	var t = create_tween()
	t.tween_property(mat, "shader_parameter/blur_strength", blur_strength, 0.4)


func _update_book(type: String) -> void:
	busy = true
	
	var book = animate_book
	
	var next_book = load(books_data[type].preview)
	var old_book = null if current_book.is_empty() else load(books_data[current_book].preview)
	
	book.spine_texture = load(books_data[type].spine)
	book.tex_cover_front_out = load(books_data[type].cover)
	book.tex_cover_front_in = load(books_data[type].interior)
	book.tex_cover_back_in = load(books_data[type].interior)
	book.tex_cover_back_out = load(books_data[type].back)
	book.refresh()
	book.visible = false
	
	new_book.texture = next_book
	new_book.position = new_book_start_position.position
	new_book.modulate.a = 0.0
	
	last_book.texture = old_book
	last_book.position = last_book_start_position.position
	var mat: ShaderMaterial = last_book.get_material()
	mat.set_shader_parameter("dissolve_value", 1.0)
	
	new_book.visible = true
	last_book.visible = true
	
	%MainBookParticles.speed_scale = 8.0
	%MainBookParticles.emitting = false
	
	var t = create_tween()
	t.set_parallel(true)
	t.tween_property(mat, "shader_parameter/dissolve_value", 0.0, 0.5)
	t.tween_property(new_book, "modulate:a", 1.0, 0.3)
	t.tween_property(new_book, "position", last_book_start_position.position, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	
	
	t.set_parallel(false)
	
	t.tween_callback(
		func():
			book.play_sound(book.sfx_book_impact)
			book.visible = true
			new_book.visible = false
			last_book.visible = false
			busy = false
			%MainBookParticles.speed_scale = 1.0
			%MainBookParticles.emitting = true
	)
	
	current_book = type
	
	GameManager.play_se(preload("uid://b6pehk47hflex"))


func _on_encyclopedia_cursor_gui_input(event: InputEvent) -> void:
	if busy: return
	
	if event.is_action_pressed("Mouse Left"):
		_update_book("encyclopedia")


func _on_bestiary_cursor_gui_input(event: InputEvent) -> void:
	if busy: return
	
	if event.is_action_pressed("Mouse Left"):
		_update_book("bestiary")


func _on_inventory_cursor_gui_input(event: InputEvent) -> void:
	if busy: return
	
	if event.is_action_pressed("Mouse Left"):
		_update_book("inventory")


func _on_recipes_cursor_gui_input(event: InputEvent) -> void:
	if busy: return
	
	if event.is_action_pressed("Mouse Left"):
		_update_book("recipes")
