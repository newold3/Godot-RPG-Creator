extends Control

# Propiedades de configuración del menú
@export var show_comparison: bool = true: set = set_show_comparison
@export var margin_left: int = 10
@export var margin_right: int = 10
@export var margin_vertical: int = 5
@export var spacing: int = 5
@export var section_spacing: int = 10
@export var custom_font: Font

# Referencias a componentes de UI
@onready var stats_container: Control = %StatsContainer
@onready var upgrade_icon: TextureRect = %UpgradeIcon
@onready var smooth_scroll_node: Node = %BottomContainer

# Datos del actor y comparación
var current_actor: GameActor
var comparison_item: Dictionary = {}
var comparison_result: int

var started: bool = false


func _ready() -> void:
	if Engine.is_editor_hint(): return
	set_show_comparison(false)
	%StatsName.text = RPGSYSTEM.database.terms.search_message("Equip Stats")
	_set_animation_for_upgrade_icon()


func scroll_to(direction: int, strength: float) -> void:
	var scroll_delta = strength * direction
	smooth_scroll_node.smooth_scroll_by_delta(scroll_delta, 0)


func _set_animation_for_upgrade_icon() -> void:
	upgrade_icon.visible = false
	upgrade_icon.pivot_offset = upgrade_icon.size * 0.5
	var original_position = upgrade_icon.position
	var t = create_tween()
	t.set_loops()
	t.set_parallel(true)
	t.tween_property(upgrade_icon, "scale", Vector2(0.98, 0.8), 0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_property(upgrade_icon, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN).set_delay(0.25)
	t.tween_property(upgrade_icon, "position:y", original_position.y + 3 * (-1 if comparison_result == 1 else 1), 0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_property(upgrade_icon, "position:y", original_position.y - 3 * (-1 if comparison_result == 1 else 1), 0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN).set_delay(0.25)


func start() -> void:
	started = false
	%Gear1.rotation = 0
	%Gear2.rotation = 0
	var a = PI / 2.0
	
	var t = create_tween()
	t.set_parallel(true)
	t.tween_property(%Gear1, "rotation", a, 0.7).set_trans(Tween.TRANS_SINE)
	t.tween_property(%Gear2, "rotation", -a, 0.7).set_trans(Tween.TRANS_SINE)
	t.tween_interval(0.01)
	t.set_parallel(false)
	t.tween_callback(set.bind("started", [true]))


func end() -> void:
	started = false


func get_gears() -> Array:
	return [%Gear1, %Gear2]


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
	if not actor:
		return
	
	current_actor = actor
	
	# Delegar los datos al StatsContainer
	stats_container.set_actor(actor, comparison_item)


func set_equipment_compararison(slot_id: int, item: Variant) -> void:
	if current_actor:
		comparison_item = {
			"slot_id": slot_id,
			"id": item.id if item else -1,
			"level": item.current_level if item else -1,
		} 
		# Recargar el actor con la nueva comparación
		set_actor(current_actor)


func set_show_comparison(_show_comparison: bool) -> void:
	var last_show_comparison = show_comparison
	show_comparison = _show_comparison
	if not is_inside_tree(): return
	if show_comparison != last_show_comparison:
		# Notificar al contenedor que actualize
		stats_container.set_show_comparison(show_comparison)
		upgrade_icon.visible = false


func get_minimum_size() -> Vector2:
	return stats_container.get_minimum_size()


# Getter para acceder a datos del contenedor si es necesario
func get_current_stats() -> Dictionary:
	return stats_container.get_current_stats()
