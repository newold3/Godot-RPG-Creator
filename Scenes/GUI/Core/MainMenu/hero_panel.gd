class_name GuiCoreHeroPanel
extends Control

#region Signals
## Emitted when actor data is updated
signal actor_updated(actor: GameActor)
## Emitted with formatted hero information
signal info_updated(actor_name: String, c_name: String, face_path: String, face_region: Rect2)
## Emitted when level or experience changes
signal level_updated(level: int, next_exp: String)
## Emitted when HP changes (target_val, max_val, is_initial)
signal hp_updated(current_hp: float, max_hp: float, is_initial: bool)
## Emitted when MP changes (target_val, max_val, is_initial)
signal mp_updated(current_mp: float, max_mp: float, is_initial: bool)
## Emitted when states change
signal states_updated(states: Array)
## Emitted when party role/order changes
signal party_role_updated(party_id: int, is_active: bool, is_leader: bool)
## Emitted when panel selection state changes
signal selection_changed(is_selected: bool, is_force_selected: bool)
## Emitted when mouse hover changes
signal hover_changed(is_hovered: bool)
## Emitted when panel enabled state changes
signal enabled_changed(is_enabled: bool)
## Emitted when panel grayscale status changes
signal gray_changed(is_gray: bool)
## Emitted when panel should be highlighted
signal highlighted()
## Emitted when standard term labels should update
signal label_texts_updated(level_text: String, hp_abbr: String, mp_abbr: String, next_text: String)

signal clicked(id: int)
signal item_selected(id: int)
#endregion

#region Variables
var current_actor: GameActor
var party_id: int = -1

var is_enabled: bool = false
var is_selected: bool = false
var is_force_selected: bool = false
var order_mode_enabled: bool = false
var is_multi_cursor_active: bool = false
var busy: bool = false

var _is_initialized: bool = false
#endregion

#region Lifecycle
func _ready() -> void:
	focus_entered.connect(_on_focus_entered)
	focus_exited.connect(_on_focus_exited)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	gui_input.connect(_on_gui_input)
	
	focus_neighbor_left = get_path()
	focus_neighbor_top = get_path()
	focus_neighbor_right = get_path()
	focus_neighbor_bottom = get_path()
	focus_next = get_path()
	focus_previous = get_path()
	
	set_label_texts()
#endregion

#region CoreDataAndLogic
func set_label_texts() -> void:
	if not RPGSYSTEM.database or not RPGSYSTEM.database.terms: return
	var level_term = RPGSYSTEM.database.terms.search_message("Level") + ":"
	var hp_abbr = RPGSYSTEM.database.terms.search_message("Hit Points (abbr)")
	var mp_abbr = RPGSYSTEM.database.terms.search_message("Magic Points (abbr)")
	var next_term = RPGSYSTEM.database.terms.search_message("Next Level") + ":"
	label_texts_updated.emit(level_term, hp_abbr, mp_abbr, next_term)


func setup(actor: GameActor, _is_in_party: bool = false) -> void:
	current_actor = actor
	_is_initialized = false
	if current_actor and not current_actor.is_connected("parameter_changed", refresh):
		current_actor.parameter_changed.connect(refresh)
	
	refresh()


func refresh() -> void:
	if not current_actor:
		_clear_data()
		return
	
	var real_actor: RPGActor = RPGSYSTEM.get_data("actors", current_actor.id) if current_actor.id > 0 else null
	if not real_actor:
		_clear_data()
		return
	
	var actor_name = current_actor.current_name if current_actor.current_name else real_actor.name
	var actor_class = RPGSYSTEM.get_data("classes", current_actor.current_class) if current_actor.current_class > 0 else null
	var c_name = actor_class.name if actor_class else ""
	
	var face_path = ""
	var face_region = Rect2()
	if real_actor.face_preview:
		face_path = real_actor.face_preview.path
		face_region = real_actor.face_preview.region
	
	info_updated.emit(actor_name, c_name, face_path, face_region)
	level_updated.emit(current_actor.current_level, current_actor.get_remaining_exp_to_level())
	
	var target_hp = current_actor.params.hp
	var max_hp = current_actor.get_parameter("hp")
	var target_mp = current_actor.params.mp
	var max_mp = current_actor.get_parameter("mp")
	
	hp_updated.emit(target_hp, max_hp, !_is_initialized)
	mp_updated.emit(target_mp, max_mp, !_is_initialized)
	
	_is_initialized = true
	states_updated.emit(current_actor.current_states)
	actor_updated.emit(current_actor)


func _clear_data() -> void:
	info_updated.emit("", "", "", Rect2())
	level_updated.emit(1, "0")
	hp_updated.emit(0.0, 0.0, true)
	mp_updated.emit(0.0, 0.0, true)
	states_updated.emit([])


func set_party_icon(id: int) -> void:
	party_id = id
	if not RPGSYSTEM.database or not RPGSYSTEM.database.system: return
	var max_active = RPGSYSTEM.database.system.party_active_members
	var is_active = party_id < max_active
	var is_leader = (party_id == 0)
	party_role_updated.emit(party_id, is_active, is_leader)


func set_multi_cursor_mode(active: bool) -> void:
	is_multi_cursor_active = active
	if active:
		focus_mode = Control.FOCUS_NONE
		selection_changed.emit(false, false)
	else:
		focus_mode = Control.FOCUS_ALL
		if not has_focus() and not is_force_selected:
			selection_changed.emit(false, false)


func set_order_mode(value: bool) -> void:
	order_mode_enabled = value


func force_selection(_animate: bool = true) -> void:
	grab_focus()
	is_force_selected = true
	selection_changed.emit(true, true)


func clear_force_selection(_clear_cursors: bool = false) -> void:
	is_force_selected = false
	selection_changed.emit(is_selected, false)


func clear() -> void:
	is_selected = false
	clear_force_selection(true)


func to_gray(value: bool) -> void:
	gray_changed.emit(value)


func set_enabled() -> void:
	is_enabled = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	enabled_changed.emit(true)


func set_disabled() -> void:
	is_enabled = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	enabled_changed.emit(false)


func hightlight() -> void:
	highlighted.emit()


func select(force_focus: bool = false) -> void:
	if not is_inside_tree(): return
	if force_focus and has_focus():
		release_focus()
	if focus_mode != Control.FOCUS_NONE:
		grab_focus()
	is_selected = true
	item_selected.emit(get_index())
	selection_changed.emit(true, is_force_selected)


func restart() -> void:
	refresh()
#endregion

#region InputAndFocusEvents
func _on_focus_entered() -> void:
	if not is_enabled: return
	is_selected = true
	if not is_force_selected and not is_multi_cursor_active:
		selection_changed.emit(true, false)
	elif is_force_selected:
		selection_changed.emit(true, true)
		item_selected.emit(get_index())


func _on_focus_exited() -> void:
	if not is_enabled or is_multi_cursor_active: return
	if not is_force_selected:
		selection_changed.emit(false, false)
	is_selected = false


func _on_gui_input(event: InputEvent) -> void:
	if busy or not is_enabled:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
		clicked.emit(get_index())


func _on_mouse_entered() -> void:
	if not is_enabled: return
	if not busy and focus_mode != Control.FOCUS_NONE:
		grab_focus()
	if not order_mode_enabled:
		select()
	hover_changed.emit(true)


func _on_mouse_exited() -> void:
	if not is_enabled: return
	hover_changed.emit(false)
#endregion
