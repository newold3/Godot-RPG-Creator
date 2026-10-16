extends GuiCoreHeroPanel

#region ThemeExports
@export var initial_animation_delay: float = 0.0

@export var glow_intensity: float = 1.3
@export var glow_duration: float = 0.3
@export var shake_distance: float = 8.0
@export var shake_duration: float = 0.35
@export var shake_vibrations: int = 5

@export var stat_panel_scene: PackedScene = preload("uid://ugevri8ok2ol")
#endregion

#region ThemeVisualVariables
var animation_timer: float = 0.25

var _hp_tween: Tween
var _mp_tween: Tween
var _glow_tween: Tween
var _shake_tween: Tween

var _hp_abbr: String = "HP"
var _mp_abbr: String = "MP"

@onready var hero_panel: Control = self
#endregion

#region Lifecycle
func _ready() -> void:
	offset_transform_enabled = true
	offset_transform_visual_only = false
	offset_transform_position = Vector2(550, 0)
	super._ready()
	_connect_core_signals()
	start.call_deferred()


func _connect_core_signals() -> void:
	label_texts_updated.connect(_on_label_texts_updated)
	info_updated.connect(_on_info_updated)
	level_updated.connect(_on_level_updated)
	hp_updated.connect(_on_hp_updated)
	mp_updated.connect(_on_mp_updated)
	states_updated.connect(_on_states_updated)
	party_role_updated.connect(_on_party_role_updated)
	selection_changed.connect(_on_selection_changed)
	hover_changed.connect(_on_hover_changed)
	enabled_changed.connect(_on_enabled_changed)
	gray_changed.connect(_on_gray_changed)
	highlighted.connect(_on_highlighted)
#endregion

#region VisualEventHandlers
func _on_label_texts_updated(level_text: String, hp_abbr: String, mp_abbr: String, next_text: String) -> void:
	_hp_abbr = hp_abbr
	_mp_abbr = mp_abbr
	if has_node("%LevelLabel"):
		%LevelLabel.text = level_text
	if has_node("%HPLabel"):
		%HPLabel.text = "[center]0 / 0 %s[/center]" % _hp_abbr
	if has_node("%MPLabel"):
		%MPLabel.text = "[center]0 / 0 %s[/center]" % _mp_abbr
	if has_node("%NextLabel"):
		%NextLabel.text = next_text


func _on_info_updated(actor_name: String, c_name: String, face_path: String, face_region: Rect2) -> void:
	if has_node("%Name"):
		%Name.text = actor_name
	if has_node("%Class"):
		%Class.text = c_name
	if has_node("%HeroFace"):
		if face_path != "" and AssetManager.exists(face_path):
			if %HeroFace.texture and %HeroFace.texture is AtlasTexture:
				%HeroFace.texture.atlas = load(face_path)
				%HeroFace.texture.region = face_region
			else:
				var atlas = AtlasTexture.new()
				atlas.atlas = load(face_path)
				atlas.region = face_region
				%HeroFace.texture = atlas
		else:
			%HeroFace.texture = null


func _on_level_updated(level: int, next_exp: String) -> void:
	if has_node("%LevelAmountLabel"):
		%LevelAmountLabel.text = str(level)
	if has_node("%NextExperienceLabel"):
		%NextExperienceLabel.text = next_exp


func _on_hp_updated(target_hp: float, max_hp: float, is_initial: bool) -> void:
	if has_node("%HPBar"):
		%HPBar.max_value = max_hp
	if is_initial:
		if has_node("%HPBar"): %HPBar.value = target_hp
		_update_hp_text(target_hp, max_hp)
	else:
		_animate_hp(target_hp, max_hp)


func _on_mp_updated(target_mp: float, max_mp: float, is_initial: bool) -> void:
	if has_node("%MPBar"):
		%MPBar.max_value = max_mp
	if is_initial:
		if has_node("%MPBar"): %MPBar.value = target_mp
		_update_mp_text(target_mp, max_mp)
	else:
		_animate_mp(target_mp, max_mp)


func _on_states_updated(states: Array) -> void:
	clear_stats()
	if not has_node("%StatsContainer") or not stat_panel_scene: return
	var node = %StatsContainer
	for state: GameState in states:
		var real_state: RPGState = state.get_real_state()
		var icon = stat_panel_scene.instantiate()
		node.add_child(icon)
		if real_state and AssetManager.exists(real_state.icon.path):
			if icon.has_method("set_image"):
				icon.set_image(real_state.icon.path, real_state.icon.region)


func clear_stats() -> void:
	if not has_node("%StatsContainer"): return
	for child in %StatsContainer.get_children():
		child.queue_free()


func _on_party_role_updated(_role_id: int, is_active: bool, is_leader: bool) -> void:
	if not has_node("%PartyIndicator"): return
	var node = %PartyIndicator
	if not is_active:
		node.visible = false
	else:
		node.visible = true
		if node.texture and "region" in node.texture:
			if is_leader:
				node.texture.region = Rect2(1129, 304, 97, 98)
			else:
				node.texture.region = Rect2(1129, 433, 97, 70)


func _on_selection_changed(is_sel: bool, is_force: bool) -> void:
	if has_node("%CursorForceSelected"):
		%CursorForceSelected.visible = is_force
	
	if is_sel:
		focus_animation(!is_force)
	else:
		unfocus_animation()


func _on_hover_changed(is_hovered: bool) -> void:
	if has_node("%CursorHover"):
		%CursorHover.visible = is_hovered


func _on_enabled_changed(p_enabled: bool) -> void:
	if p_enabled:
		modulate = Color.WHITE
	else:
		modulate = Color(0.65, 0.65, 0.65)
		if _glow_tween: _glow_tween.kill()
		if _shake_tween: _shake_tween.kill()


func _on_gray_changed(is_gray: bool) -> void:
	if has_node("%GreyScaleContainer"):
		%GreyScaleContainer.visible = is_gray


func _on_highlighted() -> void:
	modulate = Color(1.2, 1.2, 1.2)
#endregion

#region VisualTweensAndGears
func _animate_hp(target_val: float, max_val: float) -> void:
	if not has_node("%HPBar"): return
	if _hp_tween: _hp_tween.kill()
	_hp_tween = create_tween().set_parallel(true)
	_hp_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_hp_tween.tween_property(%HPBar, "value", target_val, 0.4)
	_hp_tween.tween_method(func(v): _update_hp_text(v, max_val), %HPBar.value, target_val, 0.4)


func _animate_mp(target_val: float, max_val: float) -> void:
	if not has_node("%MPBar"): return
	if _mp_tween: _mp_tween.kill()
	_mp_tween = create_tween().set_parallel(true)
	_mp_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_mp_tween.tween_property(%MPBar, "value", target_val, 0.4)
	_mp_tween.tween_method(func(v): _update_mp_text(v, max_val), %MPBar.value, target_val, 0.4)


func _update_hp_text(current: float, total: float) -> void:
	if not has_node("%HPLabel"): return
	var hp_str = GameManager.get_number_formatted(current)
	var max_hp_str = GameManager.get_number_formatted(total)
	%HPLabel.text = "[center]%s / %s[/center]" % [hp_str, max_hp_str]


func _update_mp_text(current: float, total: float) -> void:
	if not has_node("%MPLabel"): return
	var mp_str = GameManager.get_number_formatted(current)
	var max_mp_str = GameManager.get_number_formatted(total)
	%MPLabel.text = "[center]%s / %s[/center]" % [mp_str, max_mp_str]


func glow_animation() -> void:
	if _glow_tween: _glow_tween.kill()
	_glow_tween = create_tween().set_parallel(true)
	_glow_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_glow_tween.tween_property(hero_panel, "modulate", Color(glow_intensity, glow_intensity, glow_intensity), glow_duration * 0.5)
	_glow_tween.tween_property(hero_panel, "modulate", Color.WHITE, glow_duration * 0.5).set_delay(glow_duration * 0.5)


func shake_animation() -> void:
	if _shake_tween: _shake_tween.kill()
	_shake_tween = create_tween()
	_shake_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	
	var base_x = offset_transform_position.x
	var step_time = shake_duration / float(shake_vibrations * 2)
	var current_distance = shake_distance
	
	for i in range(shake_vibrations):
		_shake_tween.tween_property(self, "offset_transform_position:x", base_x + current_distance, step_time)
		_shake_tween.tween_property(self, "offset_transform_position:x", base_x - current_distance, step_time)
		current_distance *= 0.8
		
	_shake_tween.tween_property(self, "offset_transform_position:x", base_x, step_time)


func _get_theme_gears() -> Dictionary:
	if has_node("%Gear1"):
		return {
			"left": [%Gear1, %Gear4, %Gear6, %Gear3, %Gear7],
			"right": [%Gear2, %Gear5, %Gear8]
		}
	return {}


func tween_gear(rot: float) -> void:
	var gears = _get_theme_gears()
	if gears.is_empty(): return
	var t = create_tween()
	t.set_parallel(true)
	for gear in gears.left:
		t.tween_property(gear, "rotation", gear.rotation + rot, animation_timer)
	for gear in gears.right:
		t.tween_property(gear, "rotation", gear.rotation - rot, animation_timer)


func start() -> void:
	busy = true
	var gears = _get_theme_gears()
	offset_transform_position.x = 550.0

	var panel_delay = calculate_dynamic_delay()
	var t = create_tween()
	t.tween_interval(panel_delay)
	t.tween_interval(0.01)
	t.set_parallel(true)
	t.tween_property(self, "offset_transform_position:x", 40.0, 0.25).from(550.0)
	t.tween_property(self, "offset_transform_position:x", 20.0, 0.3).set_delay(0.25).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT).from(40.0)
	if not gears.is_empty():
		for gear in gears.left:
			gear.rotation = 0
			t.tween_property(gear, "rotation", deg_to_rad(-90), 0.85).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		for gear in gears.right:
			gear.rotation = 0
			t.tween_property(gear, "rotation", deg_to_rad(90), 0.85).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_interval(0.01)
	t.set_parallel(false)
	t.tween_callback(
		func():
			busy = false
			_is_initialized = true
	)


func end() -> void:
	busy = true
	var gears = _get_theme_gears()
	var panel_delay = calculate_reverse_dynamic_delay()
	var _animation_timer = self.animation_timer * 0.5
	
	var t = create_tween()
	t.tween_interval(panel_delay)
	t.tween_interval(0.01)
	t.set_parallel(true)
	t.tween_property(self, "offset_transform_position:x", 530.0, _animation_timer)
	t.tween_property(self, "offset_transform_position:x", 550.0, 0.3).set_delay(_animation_timer).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	if not gears.is_empty():
		for gear in gears.left:
			t.tween_property(gear, "rotation", deg_to_rad(0), 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		for gear in gears.right:
			t.tween_property(gear, "rotation", deg_to_rad(0), 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_interval(0.01)
	t.set_parallel(false)
	t.tween_callback(set.bind("busy", false))


func get_scroll_container() -> ScrollContainer:
	var current = get_parent()
	while current:
		if current is ScrollContainer:
			return current
		current = current.get_parent()
	return null


func calculate_dynamic_delay() -> float:
	var scroll_container = get_scroll_container()
	if scroll_container and not _is_in_viewport_rect(self, scroll_container):
		return initial_animation_delay * 0.1
	
	var my_y_position = get_global_rect().position.y
	if scroll_container:
		var scroll_top = scroll_container.get_global_rect().position.y
		var distance_from_top = my_y_position - scroll_top
		var panel_height = get_rect().size.y
		var visual_index = max(0, int(distance_from_top / panel_height))
		return visual_index * 0.075 + initial_animation_delay
	else:
		return get_index() * 0.075 + initial_animation_delay


func calculate_reverse_dynamic_delay() -> float:
	var scroll_container = get_scroll_container()
	if scroll_container and not _is_in_viewport_rect(self, scroll_container):
		return initial_animation_delay * 0.3 * get_index()
	
	var my_y_position = get_global_rect().position.y
	if scroll_container:
		var scroll_bottom = scroll_container.get_global_rect().position.y + scroll_container.get_global_rect().size.y
		var distance_from_bottom = scroll_bottom - my_y_position
		var panel_height = get_rect().size.y
		var visual_index = max(0, int(distance_from_bottom / panel_height))
		return visual_index * 0.04 + (initial_animation_delay * 0.3)
	else:
		var total_siblings = get_parent().get_child_count()
		var reverse_index = total_siblings - get_index() - 1
		return reverse_index * 0.04 + (initial_animation_delay * 0.3)


func _is_in_viewport_rect(node: Node, scroll_container: ScrollContainer) -> bool:
	var scroll_rect = scroll_container.get_global_rect()
	var node_rect = node.get_global_rect()
	return scroll_rect.intersects(node_rect)


func set_initial_position(time: float = 0.001) -> void:
	var t = create_tween()
	t.tween_property(self, "offset_transform_position:x", 20.0, time)


func set_final_position(time: float = 0.001) -> void:
	var t = create_tween()
	t.tween_property(self, "offset_transform_position:x", 10.0, time)


func focus_animation(_emit_signal: bool = true) -> void:
	if has_node("%CursorNormal"):
		%CursorNormal.visible = true
	
	var gears = _get_theme_gears()
	var t = create_tween()
	t.set_parallel(true)
	t.tween_property(self, "offset_transform_position:x", 0.0, animation_timer)
	
	if not gears.is_empty():
		for gear in gears.left:
			t.tween_property(gear, "rotation", gear.rotation + PI, animation_timer * 1.5).set_trans(Tween.TRANS_CIRC).set_ease(Tween.EASE_OUT)
		for gear in gears.right:
			t.tween_property(gear, "rotation", gear.rotation - PI, animation_timer * 1.5).set_trans(Tween.TRANS_CIRC).set_ease(Tween.EASE_OUT)


func unfocus_animation() -> void:
	if has_node("%CursorNormal"):
		%CursorNormal.visible = false
	
	var gears = _get_theme_gears()
	var t = create_tween()
	t.set_parallel(true)
	t.tween_property(self, "offset_transform_position:x", 20.0, animation_timer)
	
	if not gears.is_empty():
		for gear in gears.left:
			t.tween_property(gear, "rotation", 0, animation_timer * 1.5).set_trans(Tween.TRANS_CIRC).set_ease(Tween.EASE_OUT)
		for gear in gears.right:
			t.tween_property(gear, "rotation", 0, animation_timer * 1.5).set_trans(Tween.TRANS_CIRC).set_ease(Tween.EASE_OUT)
#endregion
