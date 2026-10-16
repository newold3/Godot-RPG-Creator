extends GuiCoreBottomPanel

#region Variables
var main_tween: Tween
#endregion

#region Lifecycle
func _ready() -> void:
	gold_updated.connect(_on_gold_updated)
	time_updated.connect(_on_time_updated)
	map_name_updated.connect(_on_map_name_updated)
	chapter_name_updated.connect(_on_chapter_name_updated)
	super._ready()
#endregion

#region SignalHandlers
func _on_gold_updated(gold_number: String, currency_name: String, icon_path: String) -> void:
	if has_node("%GoldIcon"):
		if icon_path != "" and AssetManager.exists(icon_path):
			%GoldIcon.texture = load(icon_path)
		else:
			%GoldIcon.texture = null
	if has_node("%GoldLabel"):
		%GoldLabel.text = currency_name
	if has_node("%GoldNumber"):
		%GoldNumber.text = gold_number


func _on_time_updated(formatted_time: String) -> void:
	if has_node("%GameTimeValue"):
		%GameTimeValue.text = formatted_time


func _on_map_name_updated(map_name: String) -> void:
	if has_node("%MapName"):
		%MapName.text = map_name


func _on_chapter_name_updated(chapter_name: String) -> void:
	if has_node("%ChapterName"):
		%ChapterName.text = chapter_name
#endregion

#region VisualAnimations
func start() -> void:
	animate_start()


func animate_start() -> void:
	if main_tween:
		main_tween.kill()
	
	if has_node("%MainContainer"):
		var container = %MainContainer
		container.position.y = 80
		main_tween = create_tween()
		main_tween.tween_property(container, "position:y", 0, 0.45).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
#endregion
