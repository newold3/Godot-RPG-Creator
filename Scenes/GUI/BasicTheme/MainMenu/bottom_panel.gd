extends Control

var game_play_colon_visible: bool = true
var game_play_colon_timer: float = 0.0
var game_play_colon_delay: float = 0.5
var main_tween: Tween


func _ready() -> void:
	restart()


func restart() -> void:
	_set_gold()
	_set_time()
	_set_map_name()
	_set_chapter_name()
	start()


func _set_gold() -> void:
	if not RPGSYSTEM.database: return
	
	var icon_path: String = RPGSYSTEM.database.system.currency_info.get("icon", "")
	var icon_name: String = RPGSYSTEM.database.system.currency_info.get("name", "")
	if has_node("%GoldIcon"):
		if AssetManager.exists(icon_path):
			%GoldIcon.texture = load(icon_path)
		else:
			%GoldIcon.texture = null
	if has_node("%GoldLabel"):
		%GoldLabel.text = icon_name
	if has_node("%GoldNumber"):
		if GameManager.game_state:
			%GoldNumber.text = GameManager.get_number_formatted(GameManager.game_state.current_gold, 2)
		else:
			%GoldNumber.text = "0"


func _set_time() -> void:
	if not has_node("%GameTimeValue"): return
	if GameManager.game_state:
		var time = GameManager.format_game_time(GameManager.game_state.stats.play_time, game_play_colon_visible)
		%GameTimeValue.text = time
	else:
		%GameTimeValue.text = "0H : 0M : 0S"


func _set_map_name() -> void:
	if not has_node("%MapName"): return
	if GameManager.current_map:
		%MapName.text = _camel_case_to_spaced(RPGMapsInfo.get_map_name_from_id(GameManager.current_map.internal_id))
	else:
		%MapName.text = ""


func _set_chapter_name() -> void:
	if not has_node("%ChapterName"): return
	if GameManager.game_state:
		%ChapterName.text = GameManager.game_state.game_chapter_name
	else:
		%ChapterName.text = ""


func _camel_case_to_spaced(text: String) -> String:
	var regex = RegEx.new()
	regex.compile("([a-z])([A-Z])")
	return regex.sub(text, "$1 $2", true)


func _process(delta: float) -> void:
	game_play_colon_timer += delta
	if game_play_colon_timer >= game_play_colon_delay:
		game_play_colon_timer = 0.0
		game_play_colon_visible = not game_play_colon_visible
		_set_time()


func start() -> void:
	if main_tween: main_tween.kill()
	main_tween = create_tween()
	main_tween.tween_property(self, "modulate:a", 1.0, 0.2).from(0.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func end() -> void:
	if main_tween: main_tween.kill()
	main_tween = create_tween()
	main_tween.tween_property(self, "modulate:a", 0.0, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
