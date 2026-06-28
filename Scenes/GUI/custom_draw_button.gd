@tool
extends Control
class_name CustomDrawButton

signal pressed()
signal selected()
signal toggled(is_pressed: bool)
signal hover_entered()
signal hover_exited()
signal animation_started(animation_type: AnimationType)
signal animation_finished(animation_type: AnimationType)

enum ButtonState { NORMAL, HOVERED, PRESSED, DISABLED }
enum ContentJustification { FULL_RECT, CENTER, TOP_LEFT, TOP_CENTER, TOP_RIGHT, CENTER_LEFT, CENTER_RIGHT, BOTTOM_LEFT, BOTTOM_CENTER, BOTTOM_RIGHT }

enum AnimationType {
	NONE,
	SHRINK_GROW,
	SHRINK_GROW_SHAKE,
	EXPAND_SHRINK,
	EXPAND_SHRINK_SHAKE,
	SHAKE,
	FADE_IN_OUT,
	PULSE,
	WOBBLE,
	BOUNCE,
	FLIP,
	JELLY
}

@export_group("Normal State")
## Style for the normal state.
@export var normal_style: StyleBox
## Texture for the normal state.
@export var normal_texture: Texture2D

@export_group("Normal Hover State")
## Style for the hovered normal state.
@export var normal_hover_style: StyleBox
## Texture for the hovered normal state.
@export var normal_hover_texture: Texture2D

@export_group("Pressed State")
## Style for the pressed state.
@export var pressed_style: StyleBox
## Texture for the pressed state.
@export var pressed_texture: Texture2D

@export_group("Pressed Hover State")
## Style for the hovered pressed state.
@export var pressed_hover_style: StyleBox
## Texture for the hovered pressed state.
@export var pressed_hover_texture: Texture2D

@export_group("Selected (Focus) State")
## Style for the selected focus state.
@export var selected_focus_style: StyleBox
## Texture for the selected focus state.
@export var selected_focus_texture: Texture2D

@export_group("Selected (Focus Hover) State")
## Style for the hovered selected focus state.
@export var selected_hover_style: StyleBox
## Texture for the hovered selected focus state.
@export var selected_hover_texture: Texture2D

@export_group("Selected Pressed (Focus) State")
## Style for the pressed selected focus state.
@export var selected_pressed_focus_style: StyleBox
## Texture for the pressed selected focus state.
@export var selected_pressed_focus_texture: Texture2D

@export_group("Selected Pressed (Focus Hover) State")
## Style for the hovered pressed selected focus state.
@export var selected_pressed_hover_style: StyleBox
## Texture for the hovered pressed selected focus state.
@export var selected_pressed_hover_texture: Texture2D

@export_group("Disabled State")
## Style for the disabled state.
@export var disabled_style: StyleBox
## Texture for the disabled state.
@export var disabled_texture: Texture2D

@export_group("Settings")
## Determines if the button acts as a toggle.
@export var toggle_mode: bool = false
## Determines if the button is disabled.
@export var is_disabled: bool = false
## Alignment of the content inside the button.
@export var content_justification: ContentJustification = ContentJustification.FULL_RECT
## Minimum texture size when not pressed.
@export var min_texture_size_no_pressed: Vector2 = Vector2.ZERO
## Minimum texture size when pressed.
@export var min_texture_size_pressed: Vector2 = Vector2.ZERO
## Determines if mouse clicks are managed.
@export var manage_mouse_click: bool = true
## Automatically grab focus when starting.
@export var auto_focus_on_start: bool = false
## Grab focus when the mouse hovers.
@export var focus_on_hover: bool = true

@export_group("Animation")
## Scale multiplier for growing animations.
@export var grow_scale: float = 1.1
## Duration for growing animations.
@export var grow_duration: float = 0.15
## Duration for shrinking animations.
@export var shrink_duration: float = 0.1
## Animation to play when selected.
@export var on_select_animation: AnimationType = AnimationType.SHRINK_GROW
## Animation to play when deselected.
@export var on_deselect_animation: AnimationType = AnimationType.EXPAND_SHRINK
## Animation to play when hovered.
@export var on_hover_animation: AnimationType = AnimationType.EXPAND_SHRINK
## Animation to play when hovered while selected.
@export var on_hover_selected_animation: AnimationType = AnimationType.NONE
## Animation to play when unhovered while selected.
@export var on_unhover_selected_animation: AnimationType = AnimationType.NONE
## Animation to play when pressed.
@export var on_pressed_animation: AnimationType = AnimationType.SHRINK_GROW

@export_group("Preview")
## Animation to preview in the editor.
@export var preview_animation: AnimationType = AnimationType.NONE
## Trigger to play the preview animation.
@export var preview_trigger: bool = false:
	set(value):
		if Engine.is_editor_hint() and value:
			_preview_play_animation()

var is_hovered: bool = false
var is_pressed_toggle: bool = false
var is_focused: bool = false
var current_scale: float = 1.0 : set = _set_current_scale
var animation_tween: Tween
var shake_tween: Tween
var busy: bool = false
var _is_pressing_anim_active: bool = false
var _last_focus_mode: Control.FocusMode
var _last_mouse_shape: CursorShape


#region Setup & Initialization

## Called when the node enters the scene tree for the first time.
func _ready():
	pivot_offset = size / 2
	mouse_filter = Control.MOUSE_FILTER_STOP
	
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	focus_entered.connect(_on_focus_entered)
	focus_exited.connect(_on_focus_exited)
	animation_finished.connect(_on_any_animation_finished)
	
	if auto_focus_on_start:
		_focus_button()
		visibility_changed.connect(
			func():
				if visible:
					_focus_button()
		)



## Focuses the button safely.
func _focus_button() -> void:
	if is_inside_tree():
		await get_tree().process_frame
		if is_inside_tree():
			var focus_owner = get_viewport().gui_get_focus_owner()
			if focus_owner:
				focus_owner.release_focus()
			busy = true
			grab_focus()
			GameManager.force_hand_position_over_node(GameManager.get_cursor_manipulator())
			busy = false

#endregion



#region Input Handling

## Handles focus entered event.
func _on_focus_entered():
	is_focused = true
	_play_animation(on_select_animation)
	if not busy:
		GameManager.play_fx("cursor")
	selected.emit()
	queue_redraw()



## Handles focus exited event.
func _on_focus_exited():
	is_focused = false
	_play_animation(on_deselect_animation)
	queue_redraw()



## Handles GUI input events.
func _gui_input(event: InputEvent):
	if is_disabled or not manage_mouse_click:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_on_button_pressed()
		else:
			_on_button_released()



# --- Mouse and toggle handling ---
## Handles mouse entered event.
func _on_mouse_entered():
	if is_disabled:
		return
	if focus_on_hover and not has_focus():
		grab_focus()
		
	is_hovered = true
	_play_animation(on_hover_selected_animation if is_focused else on_hover_animation)
	hover_entered.emit()
	queue_redraw()



## Handles mouse exited event.
func _on_mouse_exited():
	if is_disabled:
		return
	is_hovered = false
	if not is_focused:
		_reset_to_normal()
	hover_exited.emit()
	queue_redraw()



## Handles button pressed event.
func _on_button_pressed():
	if is_disabled:
		return
	if toggle_mode:
		is_pressed_toggle = !is_pressed_toggle
		toggled.emit(is_pressed_toggle)
	pressed.emit()
	if on_pressed_animation != AnimationType.NONE:
		_play_animation(on_pressed_animation, true)
	queue_redraw()



## Handles button released event.
func _on_button_released():
	if is_disabled:
		return
	if is_hovered and not is_focused:
		_play_animation(on_hover_animation)
	elif not is_hovered and not is_focused:
		_reset_to_normal()
	queue_redraw()

#endregion



#region Drawing & Rendering

## Sets the current scale.
func _set_current_scale(value: float):
	current_scale = value
	scale = Vector2(value, value)
	queue_redraw()



## Draws the button visually.
func _draw():
	var rect = Rect2(Vector2.ZERO, size)
	var state_chain = _get_current_state_chain()
	var state_data = _resolve_fallback_style(state_chain)
	var content_rect_texture = _get_texture_rect(rect, state_data.texture)
	
	if state_data.style:
		state_data.style.draw(get_canvas_item(), content_rect_texture)
	if state_data.texture:
		draw_texture_rect(state_data.texture, content_rect_texture, false)



# Builds the priority chain of states for fallback resolution
## Builds the priority chain of states for fallback resolution.
func _get_current_state_chain() -> Array:
	if is_disabled:
		return [{"style": disabled_style, "texture": disabled_texture},
				{"style": normal_style, "texture": normal_texture}]

	if is_focused:
		if is_pressed_toggle:
			if is_hovered:
				return [
					{"style": selected_pressed_hover_style, "texture": selected_pressed_hover_texture},
					{"style": selected_pressed_focus_style, "texture": selected_pressed_focus_texture},
					{"style": pressed_hover_style, "texture": pressed_hover_texture},
					{"style": pressed_style, "texture": pressed_texture},
					{"style": normal_hover_style, "texture": normal_hover_texture},
					{"style": normal_style, "texture": normal_texture},
				]
			else:
				return [
					{"style": selected_pressed_focus_style, "texture": selected_pressed_focus_texture},
					{"style": pressed_style, "texture": pressed_texture},
					{"style": normal_style, "texture": normal_texture},
				]
		else:
			if is_hovered:
				return [
					{"style": selected_hover_style, "texture": selected_hover_texture},
					{"style": selected_focus_style, "texture": selected_focus_texture},
					{"style": normal_hover_style, "texture": normal_hover_texture},
					{"style": normal_style, "texture": normal_texture},
				]
			else:
				return [
					{"style": selected_focus_style, "texture": selected_focus_texture},
					{"style": normal_style, "texture": normal_texture},
				]
	else:
		if is_pressed_toggle:
			if is_hovered:
				return [
					{"style": pressed_hover_style, "texture": pressed_hover_texture},
					{"style": pressed_style, "texture": pressed_texture},
					{"style": normal_hover_style, "texture": normal_hover_texture},
					{"style": normal_style, "texture": normal_texture},
				]
			else:
				return [
					{"style": pressed_style, "texture": pressed_texture},
					{"style": normal_style, "texture": normal_texture},
				]
		else:
			if is_hovered:
				return [
					{"style": normal_hover_style, "texture": normal_hover_texture},
					{"style": normal_style, "texture": normal_texture},
				]
			else:
				return [{"style": normal_style, "texture": normal_texture}]



# Iterates through the chain and returns the first valid style or texture
## Iterates through the chain and returns the first valid style or texture.
func _resolve_fallback_style(state_chain: Array) -> Dictionary:
	for s in state_chain:
		if (s.style and s.style != null) or (s.texture and s.texture != null):
			return s
	return {"style": normal_style, "texture": normal_texture}



## Gets the texture rectangle bounded by justification.
func _get_texture_rect(base_rect: Rect2, texture: Texture2D) -> Rect2:
	if not texture:
		return base_rect
	if content_justification == ContentJustification.FULL_RECT:
		return base_rect
	var tex_size = texture.get_size()
	return _get_justified_rect(base_rect, tex_size)



## Gets the justified rectangle position and size.
func _get_justified_rect(base_rect: Rect2, content_size: Vector2) -> Rect2:
	var pos = base_rect.position
	if is_pressed():
		if min_texture_size_pressed != Vector2.ZERO:
			content_size = min_texture_size_pressed
	else:
		if min_texture_size_no_pressed != Vector2.ZERO:
			content_size = min_texture_size_no_pressed
	match content_justification:
		ContentJustification.CENTER:
			pos += (base_rect.size - content_size) * 0.5
		ContentJustification.TOP_CENTER:
			pos += Vector2((base_rect.size.x - content_size.x) * 0.5, 0)
		ContentJustification.BOTTOM_CENTER:
			pos += Vector2((base_rect.size.x - content_size.x) * 0.5, base_rect.size.y - content_size.y)
		ContentJustification.TOP_LEFT:
			pass
		ContentJustification.TOP_RIGHT:
			pos += Vector2(base_rect.size.x - content_size.x, 0)
		ContentJustification.CENTER_LEFT:
			pos += Vector2(0, (base_rect.size.y - content_size.y) * 0.5)
		ContentJustification.CENTER_RIGHT:
			pos += Vector2(base_rect.size.x - content_size.x, (base_rect.size.y - content_size.y) * 0.5)
		ContentJustification.BOTTOM_LEFT:
			pos += Vector2(0, base_rect.size.y - content_size.y)
		ContentJustification.BOTTOM_RIGHT:
			pos += base_rect.size - content_size
	return Rect2(pos, content_size)

#endregion



#region Animation Logic

# --- Animations ---
## Plays the specified animation type safely overriding existing tweens.
func _play_animation(anim_type: AnimationType, is_press_event: bool = false):
	if anim_type == AnimationType.NONE:
		return
		
	if _is_pressing_anim_active and not is_press_event:
		return
		
	if is_press_event:
		_is_pressing_anim_active = true
		
	if animation_tween:
		animation_tween.kill()
		
	if shake_tween:
		shake_tween.kill()
		rotation = 0.0
		
	animation_started.emit(anim_type)
	match anim_type:
		AnimationType.NONE: animation_finished.emit(anim_type)
		AnimationType.SHRINK_GROW: _animate_shrink_grow(anim_type)
		AnimationType.SHRINK_GROW_SHAKE: _animate_shrink_grow_shake(anim_type)
		AnimationType.EXPAND_SHRINK: _animate_expand_shrink(anim_type)
		AnimationType.EXPAND_SHRINK_SHAKE: _animate_expand_shrink_shake(anim_type)
		AnimationType.SHAKE: _animate_shake(anim_type)
		AnimationType.FADE_IN_OUT: _animate_fade_in_out(anim_type)
		AnimationType.PULSE: _animate_pulse(anim_type)
		AnimationType.WOBBLE: _animate_wobble(anim_type)
		AnimationType.BOUNCE: _animate_bounce(anim_type)
		AnimationType.FLIP: _animate_flip(anim_type)
		AnimationType.JELLY: _animate_jelly(anim_type)



## Resets the button to its normal visual state.
func _reset_to_normal():
	_is_pressing_anim_active = false
	if animation_tween:
		animation_tween.kill()
	if shake_tween:
		shake_tween.kill()
	animation_tween = create_tween().set_parallel(true)
	animation_tween.tween_property(self, "scale", Vector2.ONE, shrink_duration)
	animation_tween.tween_property(self, "rotation", 0.0, shrink_duration)
	modulate.a = 1.0



# --- Animation implementations ---
## Animates a shrink and grow effect.
func _animate_shrink_grow(anim_type): _chain_anim(anim_type, [Vector2(0.9,0.9), Vector2(grow_scale,grow_scale)])



## Animates an expand and shrink effect.
func _animate_expand_shrink(anim_type): _chain_anim(anim_type, [Vector2(grow_scale,grow_scale), Vector2(1.05,1.05)])



## Animates a shake effect.
func _animate_shake(anim_type): _shake(anim_type, 8, 4)



## Animates a shrink, grow, and shake effect.
func _animate_shrink_grow_shake(anim_type): _chain_anim(anim_type,[Vector2(0.9,0.9),Vector2(grow_scale,grow_scale)],true)



## Animates an expand, shrink, and shake effect.
func _animate_expand_shrink_shake(anim_type): _chain_anim(anim_type,[Vector2(grow_scale,grow_scale),Vector2(1.05,1.05)],true)



## Animates a fade in and out effect.
func _animate_fade_in_out(anim_type):
	modulate.a = 1.0
	animation_tween = create_tween()
	animation_tween.tween_property(self,"modulate:a",0.5,0.1)
	animation_tween.tween_property(self,"modulate:a",1.0,0.1)
	animation_tween.finished.connect(func(): animation_finished.emit(anim_type))



## Animates a pulse effect.
func _animate_pulse(anim_type):
	animation_tween = create_tween().set_loops(3)
	animation_tween.tween_property(self,"scale",Vector2(1.05,1.05),0.2)
	animation_tween.tween_property(self,"scale",Vector2.ONE,0.2)
	animation_tween.finished.connect(func(): animation_finished.emit(anim_type))



## Animates a wobble effect.
func _animate_wobble(anim_type): _shake(anim_type,10,3)



## Animates a bounce effect.
func _animate_bounce(anim_type):
	var start_y = position.y
	animation_tween = create_tween()
	animation_tween.tween_property(self,"position:y",start_y-10,0.1)
	animation_tween.tween_property(self,"position:y",start_y,0.15).set_trans(Tween.TRANS_BOUNCE)
	animation_tween.finished.connect(func(): animation_finished.emit(anim_type))



## Animates a flip effect.
func _animate_flip(anim_type):
	animation_tween = create_tween()
	animation_tween.tween_property(self,"scale:x",0.0,0.1)
	animation_tween.tween_callback(func(): queue_redraw())
	animation_tween.tween_property(self,"scale:x",1.0,0.1)
	animation_tween.finished.connect(func(): animation_finished.emit(anim_type))



## Animates a jelly effect.
func _animate_jelly(anim_type):
	animation_tween = create_tween()
	animation_tween.tween_property(self,"scale",Vector2(1.2,0.8),0.1)
	animation_tween.tween_property(self,"scale",Vector2(0.9,1.1),0.1)
	animation_tween.tween_property(self,"scale",Vector2.ONE,0.1)
	animation_tween.finished.connect(func(): animation_finished.emit(anim_type))



## Chains scale animations with an optional shake.
func _chain_anim(anim_type, scales:Array, with_shake:bool=false):
	animation_tween = create_tween()
	for s in scales:
		animation_tween.tween_property(self,"scale",s,grow_duration*0.5)
	if with_shake:
		_shake(anim_type,5,3)
	else:
		animation_tween.finished.connect(func(): animation_finished.emit(anim_type))



## Executes a shaking tween.
func _shake(anim_type, degrees:int, loops:int):
	shake_tween = create_tween().set_loops(loops)
	shake_tween.tween_property(self,"rotation",deg_to_rad(degrees),0.05)
	shake_tween.tween_property(self,"rotation",deg_to_rad(-degrees),0.05)
	shake_tween.finished.connect(func():
		rotation = 0
		animation_finished.emit(anim_type)
	)



## Internal callback to track when animations finish.
func _on_any_animation_finished(_anim_type: AnimationType):
	_is_pressing_anim_active = false



## Previews the selected animation in the editor.
func _preview_play_animation():
	if not Engine.is_editor_hint():
		return
	_play_animation(preview_animation)
	await get_tree().create_timer(1.0).timeout
	if not is_instance_valid(self) or not is_inside_tree(): return
	_reset_to_normal()

#endregion



#region Public API

# Public API
## Sets the value of the toggle.
func set_value(value: bool) -> void: set_pressed(value)



## Selects the button and optionally emits signals.
func select(with_signal: bool = false) -> void:
	grab_focus()
	if with_signal:
		_on_button_pressed()



## Sets the pressed state and redraws.
func set_pressed(value: bool):
	if toggle_mode:
		is_pressed_toggle = value
		toggled.emit(is_pressed_toggle)
		queue_redraw()
	elif value:
		pressed.emit()
		queue_redraw()



## Sets the pressed state without emitting signals.
func set_pressed_no_signal(value: bool):
	if toggle_mode:
		is_pressed_toggle = value
		queue_redraw()



## Returns whether the button is currently pressed.
func is_pressed() -> bool: return is_pressed_toggle



## Sets the disabled state.
func set_disabled(value: bool):
	is_disabled = value
	if value:
		if not _last_focus_mode: _last_focus_mode = focus_mode
		if not _last_mouse_shape: _last_mouse_shape = mouse_default_cursor_shape
		focus_mode = Control.FOCUS_NONE
		mouse_default_cursor_shape = Control.CURSOR_ARROW
	else:
		if _last_focus_mode: focus_mode = _last_focus_mode
		if _last_mouse_shape: mouse_default_cursor_shape = _last_mouse_shape
		_last_focus_mode = Control.FOCUS_NONE
		_last_mouse_shape = Control.CURSOR_ARROW
		
	queue_redraw()

#endregion
