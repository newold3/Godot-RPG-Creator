extends Control

@export var initial_animation_delay: float = 0.0

var busy: bool = false
var animation_timer = 0.25
var current_actor: GameActor
var is_enabled: bool = false
var is_force_selected: bool = false
var order_mode_enabled: bool = false
var is_selected: bool = false


@onready var hero_panel: Control = self


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
		var max_hp: String = GameManager.get_number_formatted(current_actor.get_parameter("hp"))
		var hp: String = GameManager.get_number_formatted(current_actor.params.hp)
		var max_mp: String = GameManager.get_number_formatted(current_actor.get_parameter("mp"))
		var mp: String = GameManager.get_number_formatted(current_actor.params.mp)
		%HPLabel.text = "[center]%s / %s[/center]" % [hp,max_hp]
		%MPLabel.text = "[center]%s / %s[/center]" % [mp, max_mp]
		%HPBar.max_value = current_actor.get_parameter("hp")
		%HPBar.value = current_actor.params.hp
		%MPBar.max_value = current_actor.get_parameter("mp")
		%MPBar.value = current_actor.params.mp
		%NextExperienceLabel.text = current_actor.get_remaining_exp_to_level()
		if ResourceLoader.exists(real_actor.face_preview.path):
			%HeroFace.texture.atlas = load(real_actor.face_preview.path)
			%HeroFace.texture.region = real_actor.face_preview.region
		else:
			%HeroFace.texture.atlas = null
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
	t.tween_callback(set.bind("busy", false))


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


func set_disabled() -> void:
	is_enabled = false
	hero_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE


func select(force_focus: bool = false) -> void:
	if not is_inside_tree(): return
	if force_focus and hero_panel.has_focus():
		hero_panel.release_focus()
	hero_panel.grab_focus()
	is_selected = true
	item_selected.emit(get_index())


func _on_focus_entered() -> void:
	if not is_enabled: return
	%CursorNormal.visible = true
	if not is_force_selected:
		focus_animation()
	else:
		item_selected.emit(get_index())
	
	is_selected = true


func set_initial_position(time: float = 0.001) -> void:
	var t = create_tween()
	t.tween_property(hero_panel, "position:x", 20, time)


func set_final_position(time: float = 0.001) -> void:
	var t = create_tween()
	t.tween_property(hero_panel, "position:x", 10, time)


func focus_animation() -> void:
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

	item_selected.emit(get_index())


func _on_focus_exited() -> void:
	if not is_enabled: return
	
	%CursorNormal.visible = false
	
	var gears = {
		"left": [%Gear1, %Gear4, %Gear6, %Gear3, %Gear7],
		"right": [%Gear2, %Gear5, %Gear8]
	}
	
	if not is_force_selected:
		var t = create_tween()
		t.set_parallel(true)
		t.tween_property(hero_panel, "position:x", 20, animation_timer)
		for gear in gears.left:
			t.tween_property(gear, "rotation", 0, animation_timer * 1.5).set_trans(Tween.TRANS_CIRC).set_ease(Tween.EASE_OUT)
		for gear in gears.right:
			t.tween_property(gear, "rotation", 0, animation_timer * 1.5).set_trans(Tween.TRANS_CIRC).set_ease(Tween.EASE_OUT)
	
	is_selected = false


func _on_hero_panel_gui_input(event: InputEvent) -> void:
	if busy or not is_enabled:
		return
	
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
		clicked.emit(get_index())


func _on_hero_panel_mouse_entered() -> void:
	if not is_enabled: return
	
	if not busy and is_enabled:
		hero_panel.grab_focus()
	if not order_mode_enabled:
		select()
	%CursorHover.visible = true


func _on_hero_panel_mouse_exited() -> void:
	if not is_enabled: return
	%CursorHover.visible = false
