extends PanelContainer

var busy: bool = false
var is_selected: bool = false


@onready var main_cursor: ColorRect = %MainCursor
@export var hover_se: AudioStream
@export var click_se: AudioStream


signal selected(obj: PanelContainer, index: int)
signal direction_pressed(direction: String)


func _ready() -> void:
	disable_neighbor()
	main_cursor.self_modulate = Color.TRANSPARENT
	main_cursor.mouse_entered.connect(func(): %MouseHover.visible = true)
	main_cursor.mouse_exited.connect(func(): %MouseHover.visible = false)
	main_cursor.focus_entered.connect(select)
	
	var t = create_tween()
	t.set_loops(0)
	t.tween_property(main_cursor, "modulate:a", 0.2, 0.3)
	t.tween_property(main_cursor, "modulate:a", 1.0, 0.5)


func set_no_data_label(new_text: String) -> void:
	%NoDataLabel.text = new_text


func disable_neighbor() -> void:
	var main_node = %MainCursor
	main_node.focus_neighbor_left = main_node.get_path()
	main_node.focus_neighbor_top = main_node.get_path()
	main_node.focus_neighbor_right = main_node.get_path()
	main_node.focus_neighbor_bottom = main_node.get_path()
	main_node.focus_next = main_node.get_path()
	main_node.focus_previous = main_node.get_path()


func select(play_sound:bool = true) -> void:
	if busy: return
	busy = true
	if play_sound:
		%AudioStreamPlayer.stream = hover_se
		%AudioStreamPlayer.play()
	is_selected = true
	selected.emit(self, get_index())
	main_cursor.self_modulate = Color.WHITE
	await get_tree().process_frame
	if !main_cursor.has_focus():
		main_cursor.grab_focus()
	busy = false


func deselect() -> void:
	is_selected = false
	if !main_cursor.has_focus():
		main_cursor.release_focus()
	main_cursor.self_modulate = Color.TRANSPARENT


func _process(_delta: float) -> void:
	_check_button_pressed()


func _check_button_pressed() -> void:
	if not main_cursor.has_focus():
		return
		
	var direction = ControllerManager.get_pressed_direction()
	if direction:
		direction_pressed.emit(direction)
