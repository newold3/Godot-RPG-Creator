extends Control

@export var initial_animation_delay: float = 0.0

@export var glow_intensity: float = 1.3
@export var glow_duration: float = 0.3
@export var shake_distance: float = 8.0
@export var shake_duration: float = 0.35
@export var shake_vibrations: int = 5

var busy: bool = false
var animation_timer = 0.25
var current_actor: GameActor
var is_enabled: bool = false
var is_force_selected: bool = false
var order_mode_enabled: bool = false
var is_selected: bool = false

var is_multi_cursor_active: bool = false

var _is_initialized: bool = false
var _hp_tween: Tween
var _mp_tween: Tween
var _glow_tween: Tween
var _shake_tween: Tween

@onready var hero_panel: Control = self

const PARTY_STAT_PANEL = preload("uid://ugevri8ok2ol")


signal clicked(id: int)
signal item_selected(id: int)


func _ready() -> void:
	hero_panel.focus_entered.connect(_on_focus_entered)
	hero_panel.focus_exited.connect(_on_focus_exited)
	hero_panel.mouse_entered.connect(_on_hero_panel_mouse_entered)
	hero_panel.mouse_exited.connect(_on_hero_panel_mouse_exited)
	hero_panel.gui_input.connect(_on_hero_panel_gui_input)
	
	hero_panel.focus_neighbor_left = hero_panel.get_path()
	hero_panel.focus_neighbor_top = hero_panel.get_path()
	hero_panel.focus_neighbor_right = hero_panel.get_path()
	hero_panel.focus_neighbor_bottom = hero_panel.get_path()
	hero_panel.focus_next = hero_panel.get_path()
	hero_panel.focus_previous = hero_panel.get_path()
	
	set_label_texts()
	start.call_deferred()


func set_multi_cursor_mode(active: bool) -> void:
	is_multi_cursor_active = active
	
	if active:
		hero_panel.focus_mode = Control.FOCUS_NONE
		focus_animation(false)
	else:
		hero_panel.focus_mode = Control.FOCUS_ALL
		if not hero_panel.has_focus() and not is_force_selected:
			unfocus_animation()


func set_order_mode(value: bool) -> void:
	order_mode_enabled = value


func set_party_icon(party_id: int) -> void:
	var node = %PartyIndicator
	if party_id >= RPGSYSTEM.database.system.party_active_members:
		node.visible = false
	else:
		node.visible = true
		if party_id == 0:
			node.texture.region = Rect2(1129, 304, 97, 98)
		else:
			node.texture.region = Rect2(1129, 433, 97, 70)


func force_selection(animate: bool = true) -> void:
	hero_panel.grab_focus()
	is_force_selected = true
	%CursorForceSelected.visible = true
	if animate: focus_animation()


func clear_force_selection(clear_cursors: bool = false) -> void:
	is_force_selected = false
	%CursorForceSelected.visible = false
	
	if clear_cursors:
		%CursorNormal.visible = false


func clear() -> void:
	is_selected = false
	clear_force_selection(true)


func set_label_texts() -> void:
	%LevelLabel.text = RPGSYSTEM.database.terms.search_message("Level") + ":"
	var hp = "0 / 0 " + RPGSYSTEM.database.terms.search_message("Hit Points (abbr)")
	var mp = "0 / 0 " + RPGSYSTEM.database.terms.search_message("Magic Points (abbr)")
	%HPLabel.text = "[center]%s[/center]" % hp
	%MPLabel.text = "[center]%s[/center]" % mp
	%NextLabel.text = RPGSYSTEM.database.terms.search_message("Next Level") + ":"


func setup(actor: GameActor, _is_in_party: bool = false) -> void:
	current_actor = actor
	_is_initialized = false
	if not current_actor.is_connected("parameter_changed", refresh):
		current_actor.parameter_changed.connect(refresh)
	
	refresh()


func refresh() -> void:
	if not current_actor: return
	
	if current_actor.id > 0 and RPGSYSTEM.database.actors.size() > current_actor.id:
		var real_actor: RPGActor = RPGSYSTEM.database.actors[current_actor.id]
		%Name.text = current_actor.current_name if current_actor.current_name else real_actor.name
		
		if current_actor.current_class > 0 and RPGSYSTEM.database.classes.size() > current_actor.current_class:
			%Class.text = RPGSYSTEM.database.classes[current_actor.current_class].name
		else:
			%Class.text = ""
			
		%LevelAmountLabel.text = str(current_actor.current_level)
		%NextExperienceLabel.text = current_actor.get_remaining_exp_to_level()
		
		var target_hp = current_actor.params.hp
		var max_hp = current_actor.get_parameter("hp")
		var target_mp = current_actor.params.mp
		var max_mp = current_actor.get_parameter("mp")

		%HPBar.max_value = max_hp
		%MPBar.max_value = max_mp

		if not _is_initialized:
			%HPBar.value = target_hp
			%MPBar.value = target_mp
			_update_hp_text(target_hp, max_hp)
			_update_mp_text(target_mp, max_mp)
		else:
			_animate_hp(target_hp, max_hp)
			_animate_mp(target_mp, max_mp)
		
		if AssetManager.exists(real_actor.face_preview.path):
			%HeroFace.texture.atlas = load(real_actor.face_preview.path)
			%HeroFace.texture.region = real_actor.face_preview.region
		else:
			%HeroFace.texture.atlas = null
		
		refresh_stats()
	else:
		%Name.text = ""
		%Class.text = ""
		%LevelAmountLabel.text = 1
		var hp = "0 / 0 " + RPGSYSTEM.database.terms.search_message("Hit Points (abbr)")
		var mp = "0 / 0 " + RPGSYSTEM.database.terms.search_message("Magic Points (abbr)")
		%HPLabel.text = "[center]%s[/center]" % hp
		%MPLabel.text = "[center]%s[/center]" % mp
		%NextExperienceLabel.text = "0"
		%HeroFace.texture = null
		%HPBar.max_value = 0
		%HPBar.value = 0
		%MPBar.max_value = 0
		%MPBar.value = 0
		clear_stats()


func refresh_stats() -> void:
	clear_stats()
	
	if not current_actor: return
	
	var node = %StatsContainer
	
	for state: GameState in current_actor.current_states:
		var real_state: RPGState = state.get_real_state()
		var icon = PARTY_STAT_PANEL.instantiate()
		node.add_child(icon)
		if real_state and AssetManager.exists(real_state.icon.path):
			icon.set_image(real_state.icon.path, real_state.icon.region)


func clear_stats() -> void:
	var node = %StatsContainer
	for child in node.get_children():
		child.queue_free()


func _animate_hp(target_val: float, max_val: float) -> void:
	if _hp_tween: _hp_tween.kill()
	_hp_tween = create_tween().set_parallel(true)
	_hp_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	
	_hp_tween.tween_property(%HPBar, "value", target_val, 0.4)
	_hp_tween.tween_method(func(v): _update_hp_text(v, max_val), %HPBar.value, target_val, 0.4)

func _animate_mp(target_val: float, max_val: float) -> void:
	if _mp_tween: _mp_tween.kill()
	_mp_tween = create_tween().set_parallel(true)
	_mp_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	
	_mp_tween.tween_property(%MPBar, "value", target_val, 0.4)
	_mp_tween.tween_method(func(v): _update_mp_text(v, max_val), %MPBar.value, target_val, 0.4)

func _update_hp_text(current: float, total: float) -> void:
	var hp_str = GameManager.get_number_formatted(current)
	var max_hp_str = GameManager.get_number_formatted(total)
	%HPLabel.text = "[center]%s / %s[/center]" % [hp_str, max_hp_str]

func _update_mp_text(current: float, total: float) -> void:
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
	
	var base_x = hero_panel.position.x
	
	var step_time = shake_duration / float(shake_vibrations * 2)
	var current_distance = shake_distance
	
	for i in range(shake_vibrations):
		_shake_tween.tween_property(hero_panel, "position:x", base_x + current_distance, step_time)

		_shake_tween.tween_property(hero_panel, "position:x", base_x - current_distance, step_time)
		
		current_distance *= 0.8
		
	_shake_tween.tween_property(hero_panel, "position:x", base_x, step_time)


func restart() -> void:
	refresh()
	start()


func tween_gear(rot: float) -> void:
	var gears = {
		"left": [%Gear1, %Gear4, %Gear6, %Gear3, %Gear7],
		"right": [%Gear2, %Gear5, %Gear8]
	}
	var t = create_tween()
	t.set_parallel(true)
	for gear in gears.left:
		t.tween_property(gear, "rotation", gear.rotation + rot, animation_timer)
	for gear in gears.right:
		t.tween_property(gear, "rotation", gear.rotation - rot, animation_timer)


func start() -> void:
	busy = true
	
	var gears = {
		"left": [%Gear1, %Gear4, %Gear6, %Gear3, %Gear7],
		"right": [%Gear2, %Gear5, %Gear8]
	}
	
	hero_panel.position.x = 550

	var panel_delay = calculate_dynamic_delay()

	var t = create_tween()
	t.tween_interval(panel_delay)
	t.tween_interval(0.01)
	t.set_parallel(true)
	t.tween_property(hero_panel, "position:x", 40, 0.25).from(550)
	t.tween_property(hero_panel, "position:x", 20, 0.3).set_delay(0.25).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT).from(20)
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
	
	var gears = {
		"left": [%Gear1, %Gear4, %Gear6, %Gear3, %Gear7],
		"right": [%Gear2, %Gear5, %Gear8]
	}
	
	var panel_delay = calculate_reverse_dynamic_delay()
	var _animation_timer = self.animation_timer * 0.5
	
	var t = create_tween()
	t.tween_interval(panel_delay)
	t.tween_interval(0.01)
	t.set_parallel(true)
	t.tween_property(hero_panel, "position:x", 530, _animation_timer)
	t.tween_property(hero_panel, "position:x", 550, 0.3).set_delay(_animation_timer).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
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


func to_gray(value: bool) -> void:
	%GreyScaleContainer.visible = value


func set_enabled() -> void:
	is_enabled = true
	hero_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	modulate = Color.WHITE
	focus_mode = Control.FOCUS_ALL


func set_disabled() -> void:
	is_enabled = false
	hero_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	modulate = Color(0.65, 0.65, 0.65)
	focus_mode = Control.FOCUS_NONE
	if _glow_tween: _glow_tween.kill()
	if _shake_tween: _shake_tween.kill()


func hightlight() -> void:
	modulate = Color(1.2, 1.2, 1.2)
	


func select(force_focus: bool = false) -> void:
	if not is_inside_tree(): return
	if force_focus and hero_panel.has_focus():
		hero_panel.release_focus()
	if hero_panel.focus_mode != Control.FOCUS_NONE:
		hero_panel.grab_focus()
	is_selected = true
	item_selected.emit(get_index())


func _on_focus_entered() -> void:
	if not is_enabled: return
	
	%CursorNormal.visible = true
	
	if not is_force_selected and not is_multi_cursor_active:
		focus_animation()
	elif is_force_selected:
		item_selected.emit(get_index())
	
	is_selected = true


func set_initial_position(time: float = 0.001) -> void:
	var t = create_tween()
	t.tween_property(hero_panel, "position:x", 20, time)


func set_final_position(time: float = 0.001) -> void:
	var t = create_tween()
	t.tween_property(hero_panel, "position:x", 10, time)


func focus_animation(emit_signal: bool = true) -> void:
	%CursorNormal.visible = true
	
	var gears = {
		"left": [%Gear1, %Gear4, %Gear6, %Gear3, %Gear7],
		"right": [%Gear2, %Gear5, %Gear8]
	}
	
	var t = create_tween()
	t.set_parallel(true)
	t.tween_property(hero_panel, "position:x", 0, animation_timer)
	
	for gear in gears.left:
		t.tween_property(gear, "rotation", gear.rotation + PI, animation_timer * 1.5).set_trans(Tween.TRANS_CIRC).set_ease(Tween.EASE_OUT)
	for gear in gears.right:
		t.tween_property(gear, "rotation", gear.rotation - PI, animation_timer * 1.5).set_trans(Tween.TRANS_CIRC).set_ease(Tween.EASE_OUT)

	if emit_signal:
		item_selected.emit(get_index())


func unfocus_animation() -> void:
	%CursorNormal.visible = false
	
	var gears = {
		"left": [%Gear1, %Gear4, %Gear6, %Gear3, %Gear7],
		"right": [%Gear2, %Gear5, %Gear8]
	}
	
	var t = create_tween()
	t.set_parallel(true)
	t.tween_property(hero_panel, "position:x", 20, animation_timer)
	
	for gear in gears.left:
		t.tween_property(gear, "rotation", 0, animation_timer * 1.5).set_trans(Tween.TRANS_CIRC).set_ease(Tween.EASE_OUT)
	for gear in gears.right:
		t.tween_property(gear, "rotation", 0, animation_timer * 1.5).set_trans(Tween.TRANS_CIRC).set_ease(Tween.EASE_OUT)


func _on_focus_exited() -> void:
	if not is_enabled or is_multi_cursor_active: return
	
	if not is_force_selected:
		unfocus_animation()
	
	is_selected = false


func _on_hero_panel_gui_input(event: InputEvent) -> void:
	if busy or not is_enabled:
		return
	
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
		clicked.emit(get_index())


func _on_hero_panel_mouse_entered() -> void:
	if not is_enabled: return
	
	if not busy and is_enabled and hero_panel.focus_mode != Control.FOCUS_NONE:
		hero_panel.grab_focus()
	if not order_mode_enabled:
		select()
	%CursorHover.visible = true


func _on_hero_panel_mouse_exited() -> void:
	if not is_enabled: return
	%CursorHover.visible = false
