@tool
extends Control
class_name CustomDrawButton

signal pressed
signal selected()
signal toggled(is_pressed: bool)
signal hover_entered
signal hover_exited
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
@export var normal_style: StyleBox
@export var normal_texture: Texture2D

@export_group("Normal Hover State")
@export var normal_hover_style: StyleBox
@export var normal_hover_texture: Texture2D

@export_group("Pressed State")
@export var pressed_style: StyleBox
@export var pressed_texture: Texture2D

@export_group("Pressed Hover State")
@export var pressed_hover_style: StyleBox
@export var pressed_hover_texture: Texture2D

@export_group("Selected (Focus) State")
@export var selected_focus_style: StyleBox
@export var selected_focus_texture: Texture2D

@export_group("Selected (Focus Hover) State")
@export var selected_hover_style: StyleBox
@export var selected_hover_texture: Texture2D

@export_group("Selected Pressed (Focus) State")
@export var selected_pressed_focus_style: StyleBox
@export var selected_pressed_focus_texture: Texture2D

@export_group("Selected Pressed (Focus Hover) State")
@export var selected_pressed_hover_style: StyleBox
@export var selected_pressed_hover_texture: Texture2D

@export_group("Disabled State")
@export var disabled_style: StyleBox
@export var disabled_texture: Texture2D

@export_group("Settings")
@export var toggle_mode: bool = false
@export var is_disabled: bool = false
@export var content_justification: ContentJustification = ContentJustification.FULL_RECT
@export var min_texture_size_no_pressed: Vector2 = Vector2.ZERO
@export var min_texture_size_pressed: Vector2 = Vector2.ZERO
@export var manage_mouse_click: bool = true
@export var auto_focus_on_start: bool = false
@export var focus_on_hover: bool = true

@export_group("Animation")
@export var grow_scale: float = 1.1
@export var grow_duration: float = 0.15
@export var shrink_duration: float = 0.1
@export var on_select_animation: AnimationType = AnimationType.SHRINK_GROW
@export var on_deselect_animation: AnimationType = AnimationType.EXPAND_SHRINK
@export var on_hover_animation: AnimationType = AnimationType.EXPAND_SHRINK
@export var on_hover_selected_animation: AnimationType = AnimationType.NONE
@export var on_unhover_selected_animation: AnimationType = AnimationType.NONE
@export var on_pressed_animation: AnimationType = AnimationType.SHRINK_GROW

@export_group("Preview")
@export var preview_animation: AnimationType = AnimationType.NONE
@export var preview_trigger: bool = false:
	set(value):
		if Engine.is_editor_hint() and value:
			_preview_play_animation()

var is_hovered: bool = false
var is_pressed_toggle: bool = false
var is_focused: bool = false
var current_scale: float = 1.0 : set = _set_current_scale
var animation_tween: Tween
var busy: bool = false

func _ready():
	pivot_offset = size / 2
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	focus_entered.connect(_on_focus_entered)
	focus_exited.connect(_on_focus_exited)
	
	if auto_focus_on_start:
		_focus_button()
		visibility_changed.connect(
			func():
				if visible:
					_focus_button()
		)

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
				


func _on_focus_entered():
	is_focused = true
	_play_animation(on_select_animation)
	if not busy:
		GameManager.play_fx("cursor")
	selected.emit()
	queue_redraw()

func _on_focus_exited():
	is_focused = false
	_play_animation(on_deselect_animation)
	queue_redraw()

func _set_current_scale(value: float):
	current_scale = value
	scale = Vector2(value, value)
	queue_redraw()

func _gui_input(event: InputEvent):
	if is_disabled or not manage_mouse_click:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_on_button_pressed()
		else:
			_on_button_released()

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
func _resolve_fallback_style(state_chain: Array) -> Dictionary:
	for s in state_chain:
		if (s.style and s.style != null) or (s.texture and s.texture != null):
			return s
	return {"style": normal_style, "texture": normal_texture}

func _get_texture_rect(base_rect: Rect2, texture: Texture2D) -> Rect2:
	if not texture:
		return base_rect
	if content_justification == ContentJustification.FULL_RECT:
		return base_rect
	var tex_size = texture.get_size()
	return _get_justified_rect(base_rect, tex_size)

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

# --- Mouse and toggle handling ---
func _on_mouse_entered():
	if is_disabled:
		return
	if focus_on_hover and not has_focus():
		grab_focus()
		
	is_hovered = true
	_play_animation(on_hover_selected_animation if is_focused else on_hover_animation)
	hover_entered.emit()
	queue_redraw()

func _on_mouse_exited():
	if is_disabled:
		return
	is_hovered = false
	if not is_focused:
		_reset_to_normal()
	hover_exited.emit()
	queue_redraw()

func _on_button_pressed():
	if is_disabled:
		return
	if toggle_mode:
		is_pressed_toggle = !is_pressed_toggle
		toggled.emit(is_pressed_toggle)
	pressed.emit()
	_play_animation(on_pressed_animation)
	queue_redraw()

func _on_button_released():
	if is_disabled:
		return
	if is_hovered and not is_focused:
		_play_animation(on_hover_animation)
	elif not is_hovered and not is_focused:
		_reset_to_normal()
	queue_redraw()

# --- Animations ---
func _play_animation(anim_type: AnimationType):
	if animation_tween:
		animation_tween.kill()
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

func _reset_to_normal():
	if animation_tween:
		animation_tween.kill()
	animation_tween = create_tween().set_parallel(true)
	animation_tween.tween_property(self, "scale", Vector2.ONE, shrink_duration)
	animation_tween.tween_property(self, "rotation", 0.0, shrink_duration)
	modulate.a = 1.0

# --- Animation implementations ---
func _animate_shrink_grow(anim_type): _chain_anim(anim_type, [Vector2(0.9,0.9), Vector2(grow_scale,grow_scale)])
func _animate_expand_shrink(anim_type): _chain_anim(anim_type, [Vector2(grow_scale,grow_scale), Vector2(1.05,1.05)])
func _animate_shake(anim_type): _shake(anim_type, 8, 4)
func _animate_shrink_grow_shake(anim_type): _chain_anim(anim_type,[Vector2(0.9,0.9),Vector2(grow_scale,grow_scale)],true)
func _animate_expand_shrink_shake(anim_type): _chain_anim(anim_type,[Vector2(grow_scale,grow_scale),Vector2(1.05,1.05)],true)
func _animate_fade_in_out(anim_type):
	modulate.a = 1.0
	animation_tween = create_tween()
	animation_tween.tween_property(self,"modulate:a",0.5,0.1)
	animation_tween.tween_property(self,"modulate:a",1.0,0.1)
	animation_tween.finished.connect(func(): animation_finished.emit(anim_type))
func _animate_pulse(anim_type):
	animation_tween = create_tween().set_loops(3)
	animation_tween.tween_property(self,"scale",Vector2(1.05,1.05),0.2)
	animation_tween.tween_property(self,"scale",Vector2.ONE,0.2)
	animation_tween.finished.connect(func(): animation_finished.emit(anim_type))
func _animate_wobble(anim_type): _shake(anim_type,10,3)
func _animate_bounce(anim_type):
	var start_y = position.y
	animation_tween = create_tween()
	animation_tween.tween_property(self,"position:y",start_y-10,0.1)
	animation_tween.tween_property(self,"position:y",start_y,0.15).set_trans(Tween.TRANS_BOUNCE)
	animation_tween.finished.connect(func(): animation_finished.emit(anim_type))
func _animate_flip(anim_type):
	animation_tween = create_tween()
	animation_tween.tween_property(self,"scale:x",0.0,0.1)
	animation_tween.tween_callback(func(): queue_redraw())
	animation_tween.tween_property(self,"scale:x",1.0,0.1)
	animation_tween.finished.connect(func(): animation_finished.emit(anim_type))
func _animate_jelly(anim_type):
	animation_tween = create_tween()
	animation_tween.tween_property(self,"scale",Vector2(1.2,0.8),0.1)
	animation_tween.tween_property(self,"scale",Vector2(0.9,1.1),0.1)
	animation_tween.tween_property(self,"scale",Vector2.ONE,0.1)
	animation_tween.finished.connect(func(): animation_finished.emit(anim_type))

func _chain_anim(anim_type, scales:Array, with_shake:bool=false):
	animation_tween = create_tween()
	for s in scales:
		animation_tween.tween_property(self,"scale",s,grow_duration*0.5)
	if with_shake:
		_shake(anim_type,5,3)
	else:
		animation_tween.finished.connect(func(): animation_finished.emit(anim_type))

func _shake(anim_type, degrees:int, loops:int):
	var shake_tween = create_tween().set_loops(loops)
	shake_tween.tween_property(self,"rotation",deg_to_rad(degrees),0.05)
	shake_tween.tween_property(self,"rotation",deg_to_rad(-degrees),0.05)
	shake_tween.finished.connect(func():
		rotation = 0
		animation_finished.emit(anim_type)
	)

func _preview_play_animation():
	if not Engine.is_editor_hint():
		return
	_play_animation(preview_animation)
	await get_tree().create_timer(1.0).timeout
	if not is_instance_valid(self) or not is_inside_tree(): return
	_reset_to_normal()

# Public API
func set_value(value: bool) -> void: set_pressed(value)
func select(with_signal: bool = false) -> void:
	if with_signal:
		_on_button_pressed()
	grab_focus()
func set_pressed(value: bool):
	if toggle_mode:
		is_pressed_toggle = value
		toggled.emit(is_pressed_toggle)
		queue_redraw()
	elif value:
		pressed.emit()
		queue_redraw()
func set_pressed_no_signal(value: bool):
	if toggle_mode:
		is_pressed_toggle = value
		queue_redraw()
func is_pressed() -> bool: return is_pressed_toggle
func set_disabled(value: bool):
	is_disabled = value
	queue_redraw()
