@tool
extends Button


@export var button_name: String = "":
	set(value):
		button_name = value
		var node = get_node_or_null("%ButtonName")
		if node:
			node.set_text(button_name)
		var node2 = get_node_or_null("%Outline")
		if node2:
			node2.set_text(button_name)


@export var use_custom_scale_and_rotation: bool  = true
@export var force_rotation: float
@export var force_scale: Vector2 = Vector2.ONE
@export var force_text_size: int = -1 : 
	set(value):
		force_text_size = value
		var node = get_node_or_null("%ButtonName")
		if node:
			node.force_text_size = force_text_size
@export var min_font_size: int = 8 : 
	set(value):
		min_font_size = value
		var node = get_node_or_null("%ButtonName")
		if node:
			node.min_font_size = min_font_size
@export var max_font_size: int = 32 : 
	set(value):
		max_font_size = value
		var node = get_node_or_null("%ButtonName")
		if node:
			node.max_font_size = max_font_size

@export var max_scale_on_hover: Vector2 = Vector2(1.1, 1.1)


@export var ninepatch_texture_normal: Texture :
	set(value):
		ninepatch_texture_normal = value
		_update_button_texture()


@export var ninepatch_texture_selected: Texture :
	set(value):
		ninepatch_texture_selected = value
		_update_button_texture()


@export var ninepatch_texture_disabled: Texture :
	set(value):
		ninepatch_texture_disabled = value
		_update_button_texture()


@export var hover_effect_texture: Texture :
	set(value):
		hover_effect_texture = value
		if is_node_ready():
			%HoverImage.texture = hover_effect_texture

@export var current_manipulator: String

var tween_animation: Tween
var error_tween_animation: Tween
var can_action: bool = true
var busy: bool = false
var is_selected: bool = false
var can_emit_sound: bool = true
var fake_disabled: bool = false


signal begin_click()
signal end_click()
signal selected(obj: Button)
signal direction_pressed(direction: String)


func _ready() -> void:
	if hover_effect_texture:
		%HoverImage.texture = hover_effect_texture
	%ButtonName.text = button_name
	pivot_offset = size * 0.5
	mouse_entered.connect(_on_mouse_entered)
	mouse_entered.connect(_show_cursor.bind(true))
	mouse_exited.connect(_on_mouse_exited)
	mouse_exited.connect(_show_cursor.bind(false))
	pressed.connect(_on_pressed)
	
	if use_custom_scale_and_rotation:
		rotation = force_rotation
	
	focus_neighbor_left = get_path()
	focus_neighbor_top = get_path()
	focus_neighbor_right = get_path()
	focus_neighbor_bottom = get_path()
	focus_next = get_path()
	focus_previous = get_path()
	
	update()
	
	var s = %ButtonName.get("theme_override_font_sizes/font_size")
	_on_game_title_font_size_changed(s)
	
	animate_cursor()
	_update_button_texture()
	%HoverImage.visible = false


func set_label_material(mat: ShaderMaterial) -> void:
	%ButtonName.material = mat


func get_label_material() -> ShaderMaterial:
	return %ButtonName.material


func animate_cursor() -> void:
	var node = %HoverImage
	var t = create_tween()
	t.set_loops()
	t.tween_property(node, "modulate:a", 0.2, 0.2)
	t.tween_property(node, "modulate:a", 1.5, 0.2)
	t.tween_property(node, "modulate:a", 1.0, 0.2)


func _process(_delta: float) -> void:
	if use_custom_scale_and_rotation:
		if force_rotation != rotation:
			rotation = force_rotation
			
		if force_scale != scale:
			scale = force_scale


func set_fake_disabled(value: bool) -> void:
	fake_disabled = value
	var mat = %ButtonName.get_material()
	if mat is ShaderMaterial:
		var gradient = preload("uid://dxv5c7g41ixbk") if not value else preload("uid://j3rp5dr0lh12")
		mat.set_shader_parameter("gradient_texture", gradient)
	update()


func  is_fake_disabled() -> bool:
	return fake_disabled


func update() -> void:
	_update_button_texture()


func _update_button_texture() -> void:
	var background = get_node_or_null("%Background")
	if not background:
		return
	
	if (is_disabled() or is_fake_disabled()) and ninepatch_texture_disabled:
		background.texture = ninepatch_texture_disabled
	elif is_pressed() and ninepatch_texture_selected:
		background.texture = ninepatch_texture_selected
	elif ninepatch_texture_normal:
		background.texture = ninepatch_texture_normal


func select(with_signal: bool = false) -> void:
	if not is_inside_tree():
		return
		
	is_selected = true
	if !with_signal:
		set_pressed_no_signal(true)
		_on_mouse_entered()
	else:
		set_pressed_no_signal(true)
		pressed.emit()
	selected.emit(self)
	
	_update_button_texture()
	
	if !has_focus() and is_inside_tree():
		grab_focus()


func deselect(reset: bool = false) -> void:
	is_selected = false
	if reset:
		set_pressed_no_signal(false)
	if !is_pressed():
		_on_mouse_exited()
	
	_update_button_texture()
	
	if has_focus():
		release_focus()


func _show_cursor(value: bool) -> void:
	if !is_disabled():
		%HoverImage.visible = value
	else:
		self_modulate.a = 1.0


func _on_mouse_entered() -> void:
	if !can_action or is_disabled():
		return
	
	%HoverImage.visible = true
	_update_button_texture()
	
	if can_emit_sound:
		GameManager.play_fx("cursor")
	
	if tween_animation:
		tween_animation.kill()
		
	tween_animation = create_tween()
	tween_animation.tween_property(self, "force_scale", max_scale_on_hover, 0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func play_click_fx() -> void:
	if is_inside_tree():
		if can_emit_sound:
			GameManager.play_fx("ok")


func _on_mouse_exited() -> void:
	if !can_action or is_pressed() or is_disabled():
		return
	
	%HoverImage.visible = false
	_update_button_texture()
	
	if tween_animation:
		tween_animation.kill()
		
	tween_animation = create_tween()
	tween_animation.tween_property(self, "force_scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)


func _on_pressed() -> void:
	if !can_action or busy or is_disabled() or is_fake_disabled():
		if is_fake_disabled():
			play_error_animation()
		return
	
	play_click_fx()
	
	_update_button_texture()
		
	begin_click.emit()
	

	can_action = false
	if tween_animation:
		tween_animation.kill()

	pivot_offset = size / 2
	tween_animation = create_tween()
	tween_animation.set_speed_scale(1.5)
	tween_animation.set_parallel(true)
	tween_animation.tween_property(self, "force_scale", Vector2(0.8, 0.8), 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween_animation.tween_property(self, "force_rotation", rotation + 0.1, 0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween_animation.tween_property(self, "force_rotation", rotation - 0.1, 0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(0.08)
	tween_animation.tween_property(self, "force_rotation", rotation - 0.2, 0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(0.16)
	tween_animation.tween_property(self, "force_scale", Vector2(1.1, 1.1), 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(0.25)
	tween_animation.tween_property(self, "force_rotation", rotation - 0.1, 0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(0.25)
	tween_animation.tween_property(self, "force_rotation", rotation, 0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(0.33)
	tween_animation.tween_callback(set.bind("can_action", true)).set_delay(0.5)
	tween_animation.tween_callback(_update_button_texture).set_delay(0.5)
	tween_animation.tween_callback(end_click.emit).set_delay(0.5)


func play_error_animation() -> void:
	if not has_meta("original_position"):
		set_meta("original_position", position)
	GameManager.play_fx("error")
	if error_tween_animation:
		error_tween_animation.custom_step(999)
	error_tween_animation = create_tween()
	for i in 12:
		error_tween_animation.tween_property(self, "position:x", [-1, 1].pick_random() + position.x, 0.05)
	error_tween_animation.tween_property(self, "position:x", get_meta("original_position"), 0.1)


func _check_button_pressed() -> void:
	if not has_focus() or (current_manipulator and current_manipulator != GameManager.get_cursor_manipulator()):
		return
	var direction = ControllerManager.get_pressed_direction()
	if direction:
		direction_pressed.emit(direction)
	elif ControllerManager.is_confirm_just_pressed():
		ControllerManager.remove_last_action_registered()
		pressed.emit()


func _on_game_title_font_size_changed(new_size: int) -> void:
	var mat = %ButtonName.get_material()
	mat.set_shader_parameter("size", %ButtonName.size)
	%Outline.set("theme_override_font_sizes/font_size", new_size)
	if %Outline.label_settings:
		%Outline.label_settings.font_size = new_size


func _on_button_name_item_rect_changed() -> void:
	var s = %ButtonName.get("theme_override_font_sizes/font_size")
	_on_game_title_font_size_changed(s)
