extends Control

@export var initial_animation_delay: float = 0.0

@export var glow_intensity: float = 1.2
@export var glow_duration: float = 0.3
@export var shake_distance: float = 8.0
@export var shake_duration: float = 0.35
@export var shake_vibrations: int = 5

var busy: bool = false
var animation_timer: float = 0.25
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
	if not has_node("%PartyIndicator"): return
	var node = %PartyIndicator
	if party_id >= RPGSYSTEM.database.system.party_active_members:
		node.visible = false
	else:
		node.visible = true


func force_selection(animate: bool = true) -> void:
	hero_panel.grab_focus()
	is_force_selected = true
	if has_node("%CursorForceSelected"):
		%CursorForceSelected.visible = true
	if animate: focus_animation()


func clear_force_selection(clear_cursors: bool = false) -> void:
	is_force_selected = false
	if has_node("%CursorForceSelected"):
		%CursorForceSelected.visible = false
	if clear_cursors and has_node("%CursorNormal"):
		%CursorNormal.visible = false


func clear() -> void:
	is_selected = false
	clear_force_selection(true)


func set_label_texts() -> void:
	if has_node("%LevelLabel"):
		%LevelLabel.text = "Lv"
	if has_node("%HPLabel"):
		%HPLabel.text = " [b]HP[/b]  0 / 0"
	if has_node("%MPLabel"):
		%MPLabel.text = " [b]MP[/b]  0 / 0"
	if has_node("%NextLabel"):
		%NextLabel.text = "Sig:"


func setup(actor: GameActor, _is_in_party: bool = false) -> void:
	current_actor = actor
	_is_initialized = false
	if not current_actor.is_connected("parameter_changed", refresh):
		current_actor.parameter_changed.connect(refresh)
	refresh()


func refresh() -> void:
	if not current_actor: return
	var real_actor: RPGActor = RPGSYSTEM.get_data("actors", current_actor.id) if current_actor.id > 0 else null
	
	if real_actor:
		if has_node("%Name"):
			%Name.text = current_actor.current_name if current_actor.current_name else real_actor.name
		
		var actor_class = RPGSYSTEM.get_data("classes", current_actor.current_class) if current_actor.current_class > 0 else null
		if has_node("%Class"):
			%Class.text = actor_class.name if actor_class else ""
			
		if has_node("%LevelAmountLabel"):
			%LevelAmountLabel.text = str(current_actor.current_level)
		if has_node("%NextExperienceLabel"):
			%NextExperienceLabel.text = current_actor.get_remaining_exp_to_level()
		
		var target_hp = current_actor.params.hp
		var max_hp = current_actor.get_parameter("hp")
		var target_mp = current_actor.params.mp
		var max_mp = current_actor.get_parameter("mp")

		if has_node("%HPBar"):
			%HPBar.max_value = max_hp
		if has_node("%MPBar"):
			%MPBar.max_value = max_mp

		if not _is_initialized:
			if has_node("%HPBar"): %HPBar.value = target_hp
			if has_node("%MPBar"): %MPBar.value = target_mp
			_update_hp_text(target_hp, max_hp)
			_update_mp_text(target_mp, max_mp)
		else:
			_animate_hp(target_hp, max_hp)
			_animate_mp(target_mp, max_mp)
		
		if has_node("%HeroFace"):
			if AssetManager.exists(real_actor.face_preview.path):
				var at = AtlasTexture.new()
				at.atlas = load(real_actor.face_preview.path)
				at.region = real_actor.face_preview.region
				%HeroFace.texture = at
			else:
				%HeroFace.texture = null
		
		refresh_stats()
	else:
		if has_node("%Name"): %Name.text = ""
		if has_node("%Class"): %Class.text = ""
		if has_node("%LevelAmountLabel"): %LevelAmountLabel.text = "1"
		if has_node("%HPBar"):
			%HPBar.max_value = 0
			%HPBar.value = 0
		if has_node("%MPBar"):
			%MPBar.max_value = 0
			%MPBar.value = 0
		clear_stats()


func refresh_stats() -> void:
	clear_stats()
	if not current_actor or not has_node("%StatsContainer"): return
	var node = %StatsContainer
	for state: GameState in current_actor.current_states:
		var real_state: RPGState = state.get_real_state()
		var icon = PARTY_STAT_PANEL.instantiate()
		node.add_child(icon)
		if real_state and AssetManager.exists(real_state.icon.path):
			icon.set_image(real_state.icon.path, real_state.icon.region)


func clear_stats() -> void:
	if not has_node("%StatsContainer"): return
	for child in %StatsContainer.get_children():
		child.queue_free()


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
	%HPLabel.text = " [b]HP[/b]  %s/%s" % [hp_str, max_hp_str]


func _update_mp_text(current: float, total: float) -> void:
	if not has_node("%MPLabel"): return
	var mp_str = GameManager.get_number_formatted(current)
	var max_mp_str = GameManager.get_number_formatted(total)
	%MPLabel.text = " [b]MP[/b]  %s/%s" % [mp_str, max_mp_str]


func restart() -> void:
	refresh()
	start()


func start() -> void:
	busy = true
	hero_panel.modulate.a = 0.0
	
	var panel_delay = get_index() * 0.04 + initial_animation_delay
	var t = create_tween()
	t.tween_interval(panel_delay)
	t.tween_property(hero_panel, "modulate:a", 1.0, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_callback(func():
		busy = false
		_is_initialized = true
	)


func end() -> void:
	busy = true
	var panel_delay = get_index() * 0.03
	var t = create_tween()
	t.tween_interval(panel_delay)
	t.tween_property(hero_panel, "modulate:a", 0.0, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_callback(func(): busy = false)


func to_gray(value: bool) -> void:
	if has_node("%GreyScaleContainer"):
		%GreyScaleContainer.visible = value
	else:
		modulate = Color(0.6, 0.6, 0.6, 0.8) if value else Color.WHITE


func hightlight() -> void:
	focus_animation()


func set_enabled() -> void:
	is_enabled = true
	hero_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	modulate = Color.WHITE
	focus_mode = Control.FOCUS_ALL


func set_disabled() -> void:
	is_enabled = false
	hero_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	modulate = Color(0.6, 0.6, 0.6, 0.8)
	focus_mode = Control.FOCUS_NONE
	if _glow_tween: _glow_tween.kill()
	if _shake_tween: _shake_tween.kill()


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
	if has_node("%CursorNormal"): %CursorNormal.visible = true
	if not is_force_selected and not is_multi_cursor_active:
		focus_animation()
	elif is_force_selected:
		item_selected.emit(get_index())
	is_selected = true


func focus_animation(_emit_signal: bool = true) -> void:
	if has_node("%CursorNormal"): %CursorNormal.visible = true
	if _emit_signal:
		item_selected.emit(get_index())


func unfocus_animation() -> void:
	if has_node("%CursorNormal"): %CursorNormal.visible = false


func _on_focus_exited() -> void:
	if not is_enabled or is_multi_cursor_active: return
	if not is_force_selected:
		unfocus_animation()
	is_selected = false


func _on_hero_panel_gui_input(event: InputEvent) -> void:
	if busy or not is_enabled: return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
		clicked.emit(get_index())


func _on_hero_panel_mouse_entered() -> void:
	if not is_enabled: return
	if not busy and is_enabled and hero_panel.focus_mode != Control.FOCUS_NONE:
		hero_panel.grab_focus()
	if not order_mode_enabled:
		select()
	if has_node("%CursorHover"): %CursorHover.visible = true


func _on_hero_panel_mouse_exited() -> void:
	if not is_enabled: return
	if has_node("%CursorHover"): %CursorHover.visible = false
