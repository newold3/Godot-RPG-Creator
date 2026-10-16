class_name GuiCoreStatsContainer
extends Control

#region Configuration
@export var show_comparison: bool = true: set = set_show_comparison
@export var margin_left: int = 10
@export var margin_right: int = 10
@export var margin_vertical: int = 5
@export var spacing: int = 5
@export var section_spacing: int = 10
@export var custom_font: Font

var current_actor: GameActor
var comparison_item: Dictionary = {}

var comparison_result: int = 0: set = _set_comparison_result
var started: bool = false
#endregion

#region Hooks
func get_stats_draw_panel() -> Control:
	if has_node("%StatsContainer"):
		return get_node("%StatsContainer")
	return get_node_or_null("MarginContainer/VBoxContainer/MarginContainer/BottomContainer/StatsContainer")


func get_bottom_scroll_container() -> Node:
	if has_node("%BottomContainer"):
		return get_node("%BottomContainer")
	return get_node_or_null("MarginContainer/VBoxContainer/MarginContainer/BottomContainer")


func get_gears() -> Array:
	return []


func _animate_start(on_complete: Callable = Callable()) -> void:
	started = true
	if on_complete:
		on_complete.call()


func _animate_end(on_complete: Callable = Callable()) -> void:
	if on_complete:
		on_complete.call()


func _on_comparison_result_changed(_value: int) -> void:
	pass


func _on_show_comparison_changed(_show: bool) -> void:
	pass
#endregion

#region Lifecycle & Setup
func _ready() -> void:
	if Engine.is_editor_hint(): return
	set_show_comparison(false)


func _set_comparison_result(value: int) -> void:
	if comparison_result != value:
		comparison_result = value
		_on_comparison_result_changed(value)


func scroll_to(direction: int, strength: float) -> void:
	var scroll_node = get_bottom_scroll_container()
	if scroll_node and scroll_node.has_method("smooth_scroll_by_delta"):
		var scroll_delta = strength * direction
		scroll_node.smooth_scroll_by_delta(scroll_delta, 0)


func start() -> void:
	_animate_start()


func end() -> void:
	started = false
	_animate_end()


func _process(_delta: float) -> void:
	if not started: return
	var manipulator = GameManager.get_cursor_manipulator()
	if manipulator in [GameManager.MANIPULATOR_MODES.EQUIP_MENU, GameManager.MANIPULATOR_MODES.EQUIP_MENU_SUB_MENU, GameManager.MANIPULATOR_MODES.EQUIP_ACTORS_MENU]:
		if ControllerManager.current_controller == ControllerManager.CONTROLLER_TYPE.Joypad:
			var direction = ControllerManager.get_right_stick_direction()
			if direction in ["up", "down"]:
				var scroll = -1 if direction == "up" else 1
				var strength = remap(abs(ControllerManager.get_right_stick_vector().y), 0.0, 1.0, 10, 250)
				scroll_to(scroll, strength)


func set_actor(actor: GameActor) -> void:
	if not actor: return
	current_actor = actor
	var panel = get_stats_draw_panel()
	if panel and panel.has_method("set_actor"):
		panel.set_actor(actor, comparison_item)


func set_equipment_compararison(slot_id: int, item: Variant) -> void:
	if current_actor:
		var level = item.current_level if item and "current_level" in item else 1
		comparison_item = {
			"slot_id": slot_id,
			"id": item.id if item else -1,
			"level": level,
		}
		set_actor(current_actor)


func set_show_comparison(_show_comparison: bool) -> void:
	var last_show_comparison = show_comparison
	show_comparison = _show_comparison
	if not is_inside_tree(): return
	if show_comparison != last_show_comparison:
		var panel = get_stats_draw_panel()
		if panel and panel.has_method("set_show_comparison"):
			panel.set_show_comparison(show_comparison)
		_on_show_comparison_changed(show_comparison)


func get_minimum_size() -> Vector2:
	var panel = get_stats_draw_panel()
	if panel and panel.has_method("get_minimum_size"):
		return panel.get_minimum_size()
	return custom_minimum_size


func get_current_stats() -> Dictionary:
	var panel = get_stats_draw_panel()
	if panel and panel.has_method("get_current_stats"):
		return panel.get_current_stats()
	return {}
#endregion
