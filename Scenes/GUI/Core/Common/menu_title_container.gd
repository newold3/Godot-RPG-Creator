@tool
class_name GuiCoreMenuTitle
extends MarginContainer

#region Variables
@export var title: String = "" : set = _set_title
@export var initial_position: Vector2 = Vector2(0, -60)
@export var end_position: Vector2 = Vector2(0, 0)
@export var animation_time: float = 0.35

var main_tween: Tween
#endregion



#region Lifecycle
func _ready() -> void:
	_set_title(title)
	call_deferred("start")


func _get_title_node() -> Control:
	if has_node("%TitleLabel"):
		return get_node("%TitleLabel") as Control
	elif has_node("%MenuTitle"):
		return get_node("%MenuTitle") as Control
	return null


func _set_title(_title: String) -> void:
	title = _title
	if is_node_ready():
		var lbl = _get_title_node()
		if lbl:
			if "label_text" in lbl:
				lbl.label_text = tr(title)
			elif "text" in lbl:
				lbl.text = tr(title)


func start() -> void:
	_animate_start()


func end() -> void:
	_animate_end()


## Virtual method for start animation. Default is quad ease-out tween.
func _animate_start() -> void:
	if main_tween:
		main_tween.kill()

	main_tween = create_tween()
	main_tween.set_parallel(true)
	main_tween.tween_property(self, "position", end_position, animation_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT).from(initial_position)
	main_tween.tween_property(self, "modulate:a", 1.0, animation_time).from(0.0)


## Virtual method for end animation. Default is quad ease-in tween.
func _animate_end() -> void:
	if main_tween:
		main_tween.kill()

	main_tween = create_tween()
	main_tween.set_parallel(true)
	main_tween.tween_property(self, "position", initial_position, animation_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	main_tween.tween_property(self, "modulate:a", 0.0, animation_time)
#endregion
