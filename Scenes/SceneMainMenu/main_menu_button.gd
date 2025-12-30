@tool
class_name MainMenuButton
extends Control

@export var button_text: String :
	set(value):
		button_text = value
		
		if button_label:
			button_label.text = button_text


@export var initial_animation_delay: float = 0.0 :
	set(value):
		initial_animation_delay = abs(value)

@export var is_toggle_button: bool = false : set = set_toggle_mode
@export var is_untoggleable : bool = true
@export var button_group: ControlBaseItemGroup


enum ButtonState {
	NORMAL,
	HOVER,
	SELECTED,
	DISABLED,
}


@onready var button_label: Label = %ButtonLabel
@onready var animation_player: AnimationPlayer = %AnimationPlayer
@onready var cursor_selected: NinePatchRect = %CursorSelected
@onready var cursor_hover: NinePatchRect = %CursorHover
@onready var gear_1: TextureRect = %Gear1
@onready var gear_2: TextureRect = %Gear2
@onready var gear_3: TextureRect = %Gear3
@onready var gear_4: TextureRect = %Gear4


var busy: bool
var busy2: bool
var animation_timer: float = 0.25
var is_selected: bool = false
var is_enabled: bool = false
var current_state: ButtonState = ButtonState.NORMAL
var mouse_inside: bool = false
var keep_selected_state: bool = false
var main_tween: Tween
var secondary_tween: Tween
var disabled_animations: bool = false

var focus_generation: int = 0
var exit_generation: int = 0


signal selected(obj: Control)
signal begin_click(id: int)
@warning_ignore("unused_signal")
signal clicked(id: int)
signal toggled(pressed: bool)
signal animation_completed()


func _ready() -> void:
	if not Engine.is_editor_hint():
		if button_group:
			button_group.add_button(self)
		
		focus_entered.connect(_on_focus_entered)
		focus_exited.connect(_on_focus_exited)
		mouse_entered.connect(_on_mouse_entered)
		mouse_exited.connect(_on_mouse_exited)
		
		button_label.text = button_text
		
		busy = true
		
		if initial_animation_delay > 0:
			await get_tree().create_timer(initial_animation_delay).timeout
			if not is_instance_valid(self) or not is_inside_tree(): return
		
		animation_player.play("Start")
		
		await animation_player.animation_finished
		
		busy = false


func _on_focus_entered() -> void:
	if busy2: return
	
	# Incrementar generación para invalidar focus_exited anteriores
	exit_generation += 1
	
	# Incrementar generación de focus
	focus_generation += 1
	var current_generation = focus_generation
	
	# Esperar a que termine el busy anterior
	while busy:
		if not is_inside_tree():
			return
		await get_tree().process_frame
		
		# Verificar si esta llamada fue invalidada
		if current_generation != focus_generation:
			return
	
	if not is_selected:
		select()
	
	# Verificar una última vez antes de empezar la animación
	if current_generation != focus_generation:
		return
	
	busy = true
	
	# Completar tween anterior si existe
	if main_tween:
		main_tween.custom_step(999)
		if not is_inside_tree():
			return
		await get_tree().process_frame
		
		# Verificar nuevamente después del await
		if current_generation != focus_generation:
			busy = false
			return
	
	cursor_selected.visible = true
	
	if disabled_animations:
		busy = false
		is_selected = true
		queue_redraw()
		return
	
	if not is_selected:
		busy = false
		return
	
	var t = create_tween()
	t.set_parallel(true)
	t.tween_property(gear_1, "rotation", deg_to_rad(60), animation_timer * 2).set_trans(Tween.TRANS_CIRC).set_ease(Tween.EASE_OUT)
	t.tween_property(gear_2, "rotation", deg_to_rad(-60), animation_timer * 2).set_trans(Tween.TRANS_CIRC).set_ease(Tween.EASE_OUT)
	t.tween_property(gear_3, "rotation", deg_to_rad(60), animation_timer * 2).set_trans(Tween.TRANS_CIRC).set_ease(Tween.EASE_OUT)
	t.tween_property(gear_4, "rotation", deg_to_rad(60), animation_timer * 2).set_trans(Tween.TRANS_CIRC).set_ease(Tween.EASE_OUT)
	if has_meta("original_position"):
		t.tween_property(self, "position:x", get_meta("original_position").x + 10, animation_timer)
	t.set_parallel(false)
	t.tween_interval(0.0001)
	t.tween_callback(set.bind("busy", false))
	
	main_tween = t
	is_selected = true
	queue_redraw()


func _on_focus_exited() -> void:
	if busy2: return
	
	# Incrementar generación de exit para invalidar focus_entered
	focus_generation += 1
	exit_generation += 1
	var current_generation = exit_generation
	
	if not keep_selected_state:
		cursor_selected.visible = false
		
	while busy or keep_selected_state:
		if is_inside_tree():
			await get_tree().process_frame
		else:
			return
		
		# Verificar si fue invalidada
		if current_generation != exit_generation:
			return
	
	deselect()
	
	# Completar tween anterior si existe
	if main_tween:
		main_tween.custom_step(999)
		if not is_inside_tree():
			return
		await get_tree().process_frame
		
		# Verificar nuevamente
		if current_generation != exit_generation:
			return
	
	if disabled_animations: return
	
	var t = create_tween()
	t.set_parallel(true)
	
	t.tween_property(gear_1, "rotation", 0, animation_timer * 2).set_trans(Tween.TRANS_CIRC).set_ease(Tween.EASE_OUT)
	t.tween_property(gear_2, "rotation", 0, animation_timer * 2).set_trans(Tween.TRANS_CIRC).set_ease(Tween.EASE_OUT)
	t.tween_property(gear_3, "rotation", 0, animation_timer * 2).set_trans(Tween.TRANS_CIRC).set_ease(Tween.EASE_OUT)
	t.tween_property(gear_4, "rotation", 0, animation_timer * 2).set_trans(Tween.TRANS_CIRC).set_ease(Tween.EASE_OUT)
	if has_meta("original_position"):
		t.tween_property(self, "position:x", get_meta("original_position").x, animation_timer)
	
	main_tween = t
	queue_redraw()
	
	await t.finished
	
	# Verificar si no fue invalidada antes de emitir
	if current_generation == exit_generation:
		animation_completed.emit()


func _on_mouse_entered() -> void:
	if busy2 or GameManager.get_cursor_manipulator() != GameManager.MANIPULATOR_MODES.MAIN_MENU_MAIN_BUTTONS: return
	mouse_inside = true
	select()
	cursor_hover.visible = true


func _on_mouse_exited() -> void:
	if busy2 or GameManager.get_cursor_manipulator() != GameManager.MANIPULATOR_MODES.MAIN_MENU_MAIN_BUTTONS: return
	mouse_inside = false
	cursor_hover.visible = false


func set_hovered() -> void:
	cursor_hover.visible = true


func _gui_input(event: InputEvent) -> void:
	if current_state == ButtonState.DISABLED: return
	
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			current_state = ButtonState.SELECTED
			queue_redraw()
		else:
			if mouse_inside:
				if is_toggle_button and (not is_selected or is_untoggleable):
					is_selected = !is_selected
					toggled.emit(is_selected)
				begin_click.emit(get_index())

				current_state = ButtonState.HOVER if mouse_inside else ButtonState.NORMAL
				if is_selected:
					current_state = ButtonState.SELECTED
			else:
				current_state = ButtonState.NORMAL
			queue_redraw()


func disable_animations() -> void:
	disabled_animations = true


func enable_animations() -> void:
	disabled_animations = false


func set_toggle_mode(toggle: bool) -> void:
	is_toggle_button = toggle


func set_selected(enable_selected: bool) -> void:
	if enable_selected:
		select()
	else:
		deselect()


func restart() -> void:
	cursor_selected.visible = false
	cursor_hover.visible = false
	if main_tween:
		main_tween.custom_step(animation_timer * 10)
	%AnimationPlayer.play("Start")


func set_enabled() -> void:
	busy2 = false
	is_enabled = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	if is_selected:
		_on_focus_entered()


func set_disabled() -> void:
	busy2 = true
	is_enabled = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not keep_selected_state:
		cursor_selected.visible = false
	cursor_hover.visible = false


func animate_gear(_direction: int, _timer: float = animation_timer, _delay: float = 0.0) -> void:
	if main_tween:
		main_tween.custom_step(999)
		if not is_inside_tree():
			return
		await get_tree().process_frame
	gear_1.rotation = 0
	gear_2.rotation = 0
	gear_3.rotation = 0
	gear_4.rotation = 0
	var t = create_tween()
	t.set_parallel(true)
	t.tween_property(gear_1, "rotation", deg_to_rad(360), animation_timer * 2).set_trans(Tween.TRANS_CIRC).set_ease(Tween.EASE_OUT)
	t.tween_property(gear_2, "rotation", deg_to_rad(-360), animation_timer * 2).set_trans(Tween.TRANS_CIRC).set_ease(Tween.EASE_OUT)
	t.tween_property(gear_3, "rotation", deg_to_rad(360), animation_timer * 2).set_trans(Tween.TRANS_CIRC).set_ease(Tween.EASE_OUT)
	t.tween_property(gear_4, "rotation", deg_to_rad(360), animation_timer * 2).set_trans(Tween.TRANS_CIRC).set_ease(Tween.EASE_OUT)
	t.tween_interval(0.01)
	t.set_parallel(false)
	t.tween_callback(
		func():
			gear_1.rotation = 0
			gear_2.rotation = 0
			gear_3.rotation = 0
			gear_4.rotation = 0
	)
	main_tween = t


func deselect() -> void:
	if has_focus():
		release_focus()
	is_selected = false
	current_state = ButtonState.NORMAL
	cursor_selected.visible = false


func select() -> void:
	if not has_focus():
		grab_focus()
	is_selected = true
	current_state = ButtonState.SELECTED if selected else ButtonState.NORMAL
	selected.emit(self)
	cursor_selected.visible = true


func perform_click() -> void:
	#if busy: return
	
	busy = true
	
	if main_tween:
		main_tween.custom_step(999)
		await get_tree().process_frame
	
	begin_click.emit(get_index())
	
	var old_x = position.x
	var t = create_tween()
	t.set_parallel(true)
	t.tween_property(self, "position:x",old_x + 10, 0.1).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(gear_1, "rotation", gear_1.rotation + deg_to_rad(360), 0.1).set_trans(Tween.TRANS_CIRC).set_ease(Tween.EASE_OUT)
	t.tween_property(gear_2, "rotation", gear_2.rotation + deg_to_rad(-360), 0.1).set_trans(Tween.TRANS_CIRC).set_ease(Tween.EASE_OUT)
	t.tween_property(gear_3, "rotation", gear_3.rotation + deg_to_rad(360), 0.1).set_trans(Tween.TRANS_CIRC).set_ease(Tween.EASE_OUT)
	t.tween_property(gear_4, "rotation", gear_4.rotation + deg_to_rad(360), 0.1).set_trans(Tween.TRANS_CIRC).set_ease(Tween.EASE_OUT)
	t.set_parallel(false)
	t.tween_interval(0.01)
	t.set_parallel(true)
	t.tween_property(self, "position:x",old_x, 0.2).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	t.tween_property(gear_1, "rotation", gear_1.rotation, 0.2).set_trans(Tween.TRANS_CIRC).set_ease(Tween.EASE_OUT)
	t.tween_property(gear_2, "rotation", gear_2.rotation, 0.2).set_trans(Tween.TRANS_CIRC).set_ease(Tween.EASE_OUT)
	t.tween_property(gear_3, "rotation", gear_3.rotation, 0.2).set_trans(Tween.TRANS_CIRC).set_ease(Tween.EASE_OUT)
	t.tween_property(gear_4, "rotation", gear_4.rotation, 0.2).set_trans(Tween.TRANS_CIRC).set_ease(Tween.EASE_OUT)
	t.set_parallel(false)
	t.tween_callback(set.bind("busy", false))
	main_tween = t
