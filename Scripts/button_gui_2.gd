@tool
extends TextureButton


@export var button_name: String = "":
	set(value):
		button_name = value
		var node = get_node_or_null("%ButtonName")
		if node:
			node.set_text(button_name)

@export var displacement_animation: Vector2
@export var curve_animation: Curve


var tween_animation: Tween
var original_position_setted: bool = false
var original_position: Vector2

var can_action: bool = true
var busy: bool = false

signal begin_click()
signal end_click()


func _ready() -> void:
	pivot_offset = size * 0.5
	mouse_entered.connect(_on_mouse_entered)
	mouse_entered.connect(_show_cursor.bind(true))
	mouse_exited.connect(_on_mouse_exited)
	mouse_exited.connect(_show_cursor.bind(false))
	pressed.connect(_on_pressed)



func _on_mouse_entered() -> void:
	if !can_action:
		return
		
	if tween_animation:
		tween_animation.kill()
	
	GameManager.play_fx("cursor")
	
	if !original_position_setted:
		original_position_setted = true
		original_position = position
		
	tween_animation = create_tween()
	tween_animation.tween_property(self, "position", original_position + displacement_animation, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _on_mouse_exited() -> void:
	if !can_action or is_pressed():
		return
		
	if tween_animation:
		tween_animation.kill()
		
	tween_animation = create_tween()
	tween_animation.tween_property(self, "position", original_position, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)


func _on_pressed() -> void:
	if !can_action or busy:
		return
	
	begin_click.emit()
	
	GameManager.play_fx("ok")
	
	can_action = false
	if tween_animation:
		tween_animation.kill()
	
	tween_animation = create_tween()
	tween_animation.tween_property(self, "position", original_position, 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween_animation.tween_method(animate_ease.bind(original_position, displacement_animation), 0.0, 1.0, 0.4)
	tween_animation.tween_callback(set.bind("can_action", true))
	tween_animation.tween_callback(end_click.emit)


func select(with_signal: bool = false) -> void:
	if !with_signal:
		set_pressed_no_signal(true)
		_on_mouse_entered()
	else:
		set_pressed_no_signal(true)
		pressed.emit()
	
	if !has_focus() and is_inside_tree():
		grab_focus()


func deselect(reset: bool = false) -> void:
	if reset:
		set_pressed_no_signal(false)
	if !is_pressed():
		_on_mouse_exited()


func _show_cursor(value: bool) -> void:
	if !is_disabled():
		%HoverImage.visible = value
	else:
		%HoverImage.visible = false


func animate_ease(progress: float, _original_position: Vector2, target_position: Vector2) -> void:
	var current_ease = curve_animation.sample(progress)
	position = _original_position + target_position * current_ease
