@tool
extends Control

@export var button_text: String = "":
	set(value):
		button_text = value
		if is_node_ready() and has_node("%ButtonLabel"):
			%ButtonLabel.text = button_text

@export var is_toggle_button: bool = false
@export var is_untoggleable: bool = true
@export var button_group: Variant = null

var busy: bool = false
var busy2: bool = false
var is_selected: bool = false
var is_enabled: bool = true
var mouse_inside: bool = false
var keep_selected_state: bool = false

signal selected(obj: Control)
signal begin_click(id: int)
signal clicked(id: int)
signal pressed()
signal toggled(pressed: bool)


func _ready() -> void:
	if has_node("%ButtonLabel"):
		%ButtonLabel.text = button_text
	
	if has_node("%CursorSelected"):
		%CursorSelected.visible = false
		
	focus_entered.connect(_on_focus_entered)
	focus_exited.connect(_on_focus_exited)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	gui_input.connect(_on_gui_input)


func _on_focus_entered() -> void:
	if not is_enabled: return
	is_selected = true
	if has_node("%CursorSelected"):
		%CursorSelected.visible = true
	selected.emit(self)
	GameManager.play_fx("cursor")


func _on_focus_exited() -> void:
	if not keep_selected_state:
		is_selected = false
		if has_node("%CursorSelected"):
			%CursorSelected.visible = false


func _on_mouse_entered() -> void:
	mouse_inside = true
	if is_enabled and not is_selected and focus_mode != FOCUS_NONE:
		grab_focus()


func _on_mouse_exited() -> void:
	mouse_inside = false


func _on_gui_input(event: InputEvent) -> void:
	if not is_enabled or busy: return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
		perform_click()


func perform_click() -> void:
	if busy: return
	busy = true
	begin_click.emit(get_index())
	pressed.emit()
	clicked.emit(get_index())
	if is_toggle_button:
		is_selected = not is_selected
		toggled.emit(is_selected)
	busy = false


func select() -> void:
	if focus_mode != FOCUS_NONE:
		grab_focus()
	is_selected = true
	if has_node("%CursorSelected"):
		%CursorSelected.visible = true
	selected.emit(self)


func deselect() -> void:
	if has_focus():
		release_focus()
	is_selected = false
	if has_node("%CursorSelected"):
		%CursorSelected.visible = false


func set_enabled() -> void:
	is_enabled = true
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP
	if has_node("%ButtonLabel"):
		%ButtonLabel.modulate = Color.WHITE


func set_disabled() -> void:
	is_enabled = false
	focus_mode = Control.FOCUS_NONE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not keep_selected_state and has_node("%CursorSelected"):
		%CursorSelected.visible = false
	if has_node("%ButtonLabel"):
		%ButtonLabel.modulate = Color(0.6, 0.6, 0.6, 0.7)


func disable_animations() -> void:
	pass


func enable_animations() -> void:
	pass


func animate_gear(_dir: int = 1, _dur: float = 0.25, _delay: float = 0.0) -> void:
	pass
