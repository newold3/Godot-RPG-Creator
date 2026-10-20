extends GuiCoreStatsContainer

#region NodeReferences
@onready var stats_panel: Control = %StatsContainer if has_node("%StatsContainer") else null
@onready var upgrade_icon: TextureRect = %UpgradeIcon if has_node("%UpgradeIcon") else null
@onready var bottom_container: Node = %BottomContainer if has_node("%BottomContainer") else null
@onready var stats_name_label: Label = %StatsName if has_node("%StatsName") else null
@onready var gear1: Control = %Gear1 if has_node("%Gear1") else null
@onready var gear2: Control = %Gear2 if has_node("%Gear2") else null

var icon_tween: Tween
var gear_tween: Tween
#endregion

#region Lifecycle
func _ready() -> void:
	super._ready()
	if stats_name_label:
		stats_name_label.text = RPGSYSTEM.database.terms.search_message("Equip Stats")
	_set_animation_for_upgrade_icon()
#endregion

#region HookOverrides
func get_stats_draw_panel() -> Control:
	if not stats_panel and has_node("%StatsContainer"):
		stats_panel = %StatsContainer
	if not stats_panel:
		stats_panel = get_node_or_null("MarginContainer/VBoxContainer/MarginContainer/BottomContainer/StatsContainer")
	return stats_panel


func get_bottom_scroll_container() -> Node:
	if not bottom_container and has_node("%BottomContainer"):
		bottom_container = %BottomContainer
	if not bottom_container:
		bottom_container = get_node_or_null("MarginContainer/VBoxContainer/MarginContainer/BottomContainer")
	return bottom_container


func get_gears() -> Array:
	var gears = []
	if gear1: gears.append(gear1)
	if gear2: gears.append(gear2)
	return gears


func _animate_start(on_complete: Callable = Callable()) -> void:
	started = false
	if gear_tween:
		gear_tween.kill()

	if gear1 and gear2:
		gear1.rotation = 0
		gear2.rotation = 0
		var a = PI / 2.0
		gear_tween = create_tween()
		gear_tween.set_parallel(true)
		gear_tween.tween_property(gear1, "rotation", a, 0.7).set_trans(Tween.TRANS_SINE)
		gear_tween.tween_property(gear2, "rotation", -a, 0.7).set_trans(Tween.TRANS_SINE)
		gear_tween.tween_interval(0.01)
		gear_tween.set_parallel(false)
		gear_tween.tween_callback(func():
			started = true
			if on_complete:
				on_complete.call()
		)
	else:
		started = true
		if on_complete:
			on_complete.call()


func _animate_end(on_complete: Callable = Callable()) -> void:
	if gear_tween:
		gear_tween.kill()
	if on_complete:
		on_complete.call()


func _on_comparison_result_changed(_value: int) -> void:
	if is_inside_tree():
		_set_animation_for_upgrade_icon()


func _on_show_comparison_changed(value: bool) -> void:
	if upgrade_icon and not value:
		upgrade_icon.visible = false
#endregion

#region VisualAnimations
func _set_animation_for_upgrade_icon() -> void:
	if not upgrade_icon: return
	upgrade_icon.visible = false
	upgrade_icon.pivot_offset = upgrade_icon.size * 0.5
	var original_position = upgrade_icon.position
	
	if icon_tween:
		icon_tween.kill()
		
	icon_tween = create_tween()
	icon_tween.set_loops()
	icon_tween.set_parallel(true)
	icon_tween.tween_property(upgrade_icon, "scale", Vector2(0.98, 0.8), 0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	icon_tween.tween_property(upgrade_icon, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN).set_delay(0.25)
	
	var direction_multiplier = -1 if comparison_result == 1 else 1
	icon_tween.tween_property(upgrade_icon, "position:y", original_position.y + 3 * direction_multiplier, 0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	icon_tween.tween_property(upgrade_icon, "position:y", original_position.y - 3 * direction_multiplier, 0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN).set_delay(0.25)
#endregion
