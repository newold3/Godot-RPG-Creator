@tool
class_name NinePatchButton
extends BaseButton

## Enum defining the available animation types for the button.
enum AnimationType {
	NONE,
	SCALE_UP,
	SCALE_DOWN,
	PULSE,
	WOBBLE,
	SHAKE
}


## The style to render when the button is in its normal state.
@export var style_normal: StyleBox:
	set(value):
		_disconnect_style(style_normal)
		style_normal = value
		_connect_style(style_normal)
		_update_visuals()


## The style to render when the button is pressed.
@export var style_pressed: StyleBox:
	set(value):
		_disconnect_style(style_pressed)
		style_pressed = value
		_connect_style(style_pressed)
		_update_visuals()


## The style to render when the mouse hovers over the button.
@export var style_hover: StyleBox:
	set(value):
		_disconnect_style(style_hover)
		style_hover = value
		_connect_style(style_hover)
		_update_visuals()


## The style to render when the button is disabled.
@export var style_disabled: StyleBox:
	set(value):
		_disconnect_style(style_disabled)
		style_disabled = value
		_connect_style(style_disabled)
		_update_visuals()


## The style to render when the button has keyboard focus.
@export var style_focus: StyleBox:
	set(value):
		_disconnect_style(style_focus)
		style_focus = value
		_connect_style(style_focus)
		_update_visuals()


## Animation to play when the mouse enters the button.
@export var anim_mouse_enter: AnimationType = AnimationType.SCALE_UP

## Animation to play when the mouse exits the button.
@export var anim_mouse_exit: AnimationType = AnimationType.NONE

## Animation to play when the button receives focus.
@export var anim_focus_enter: AnimationType = AnimationType.PULSE

## Animation to play when the button loses focus.
@export var anim_focus_exit: AnimationType = AnimationType.NONE

## Animation to play when the button is clicked (pressed down).
@export var anim_click: AnimationType = AnimationType.SCALE_DOWN

## The duration of the tween animations in seconds.
@export var animation_duration: float = 0.1

## The intensity of the scale effect (e.g., 1.1 for 10% increase).
@export var scale_intensity: Vector2 = Vector2(1.1, 1.1)


var _active_tween: Tween


func _ready() -> void:
	# Ensure the pivot is centered immediately
	pivot_offset = size / 2
	
	if not Engine.is_editor_hint():
		mouse_entered.connect(_on_mouse_entered)
		mouse_exited.connect(_on_mouse_exited)
		focus_entered.connect(_on_focus_entered)
		focus_exited.connect(_on_focus_exited)
		button_down.connect(_on_button_down)
		button_up.connect(_on_button_up)


func _get_minimum_size() -> Vector2:
	var min_size: Vector2 = Vector2.ZERO
	
	if style_normal:
		var margins: Dictionary = _get_safe_margins(style_normal)
		min_size.x += margins.left + margins.right
		min_size.y += margins.top + margins.bottom
		
		var style_min: Vector2 = style_normal.get_minimum_size()
		min_size.x = max(min_size.x, style_min.x)
		min_size.y = max(min_size.y, style_min.y)
		
	return min_size


func _draw() -> void:
	var current_style: StyleBox = style_normal
	
	if disabled:
		if style_disabled: current_style = style_disabled
	elif button_pressed:
		if style_pressed: current_style = style_pressed
	elif is_hovered():
		if style_hover: current_style = style_hover
	
	if current_style:
		draw_style_box(current_style, Rect2(Vector2.ZERO, size))
	
	if has_focus() and style_focus:
		draw_style_box(style_focus, Rect2(Vector2.ZERO, size))


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		pivot_offset = size / 2
		queue_redraw()


func _get_safe_margins(style: StyleBox) -> Dictionary:
	var m: Dictionary = {"left": 0.0, "right": 0.0, "top": 0.0, "bottom": 0.0}
	
	if style == null:
		return m
		
	m.left = style.content_margin_left
	m.right = style.content_margin_right
	m.top = style.content_margin_top
	m.bottom = style.content_margin_bottom
	
	if style is StyleBoxTexture:
		var tex_style: StyleBoxTexture = style as StyleBoxTexture
		m.left += tex_style.texture_margin_left
		m.right += tex_style.texture_margin_right
		
	return m


func _connect_style(style: StyleBox) -> void:
	if style and not style.changed.is_connected(_update_visuals):
		style.changed.connect(_update_visuals)


func _disconnect_style(style: StyleBox) -> void:
	if style and style.changed.is_connected(_update_visuals):
		style.changed.disconnect(_update_visuals)


func _update_visuals() -> void:
	update_minimum_size()
	queue_redraw()
	
	var required_min: Vector2 = get_minimum_size()
	if size.x < required_min.x or size.y < required_min.y:
		size = required_min


func _apply_animation(type: AnimationType) -> void:
	if _active_tween:
		_active_tween.custom_step(999)
		_active_tween.kill()
	
	_active_tween = create_tween()
	_active_tween.set_parallel(true)
	_active_tween.set_ease(Tween.EASE_OUT)
	_active_tween.set_trans(Tween.TRANS_CUBIC)
	
	match type:
		AnimationType.NONE:
			_active_tween.tween_property(self, "scale", Vector2.ONE, animation_duration)
			_active_tween.tween_property(self, "rotation_degrees", 0.0, animation_duration)
			
		AnimationType.SCALE_UP:
			_active_tween.tween_property(self, "scale", scale_intensity, animation_duration)
			_active_tween.tween_property(self, "rotation_degrees", 0.0, animation_duration)
			
		AnimationType.SCALE_DOWN:
			var target_scale = Vector2(1.0, 1.0) / scale_intensity
			_active_tween.tween_property(self, "scale", target_scale, animation_duration)
			_active_tween.tween_property(self, "rotation_degrees", 0.0, animation_duration)
			
		AnimationType.PULSE:
			_active_tween.set_parallel(false)
			_active_tween.tween_property(self, "scale", scale_intensity, animation_duration * 0.5)
			_active_tween.tween_property(self, "scale", Vector2.ONE, animation_duration * 0.5)
			
		AnimationType.WOBBLE:
			_active_tween.set_parallel(false)
			var t = animation_duration * 0.25
			_active_tween.tween_property(self, "rotation_degrees", -5.0, t)
			_active_tween.tween_property(self, "rotation_degrees", 5.0, t)
			_active_tween.tween_property(self, "rotation_degrees", -3.0, t)
			_active_tween.tween_property(self, "rotation_degrees", 0.0, t)
			_active_tween.tween_property(self, "scale", Vector2.ONE, animation_duration)
			
		AnimationType.SHAKE:
			_active_tween.set_parallel(false)
			for i in range(3):
				var offset = 3.0 if i % 2 == 0 else -3.0
				_active_tween.tween_property(self, "position:x", position.x + offset, animation_duration * 0.1)
			_active_tween.tween_property(self, "position:x", position.x, animation_duration * 0.1)


func _on_mouse_entered() -> void:
	_apply_animation(anim_mouse_enter)


func _on_mouse_exited() -> void:
	if has_focus():
		return # Avoid conflict if focused
	_apply_animation(anim_mouse_exit)


func _on_focus_entered() -> void:
	_apply_animation(anim_focus_enter)


func _on_focus_exited() -> void:
	_apply_animation(anim_focus_exit)


func _on_button_down() -> void:
	_apply_animation(anim_click)


func _on_button_up() -> void:
	# Return to hover state if mouse is still over, otherwise reset
	if is_hovered():
		_apply_animation(anim_mouse_enter)
	elif has_focus():
		_apply_animation(anim_focus_enter)
	else:
		_apply_animation(anim_mouse_exit)
