class_name GuiCoreBottomPanel
extends Control

#region Signals
signal gold_updated(gold_number: String, currency_name: String, icon_path: String)
signal time_updated(formatted_time: String)
signal map_name_updated(map_name: String)
signal chapter_name_updated(chapter_name: String)
#endregion

#region Variables
var game_play_colon_visible: bool = true
var game_play_colon_timer: float = 0.0
var game_play_colon_delay: float = 0.5
#endregion

#region Lifecycle
func _ready() -> void:
	restart()


func _process(delta: float) -> void:
	game_play_colon_timer += delta
	if game_play_colon_timer >= game_play_colon_delay:
		game_play_colon_timer = 0.0
		game_play_colon_visible = !game_play_colon_visible
	_set_time()
#endregion

#region VirtualHooks
## Override in themes to implement entry animations
func animate_start() -> void:
	pass
#endregion

#region LogicAndData
func restart() -> void:
	_set_gold()
	_set_time()
	_set_map_name()
	_set_chapter_name()
	animate_start()


func _set_gold() -> void:
	if not RPGSYSTEM.database: return
	var icon_path: String = RPGSYSTEM.database.system.currency_info.get("icon", "")
	var icon_name: String = RPGSYSTEM.database.system.currency_info.get("name", "")
	var gold_str = "0"
	if GameManager.game_state:
		gold_str = GameManager.get_number_formatted(GameManager.game_state.current_gold, 2)
	gold_updated.emit(gold_str, icon_name, icon_path)


func _set_time() -> void:
	var time_str = "0H : 0M : 0S"
	if GameManager.game_state:
		time_str = GameManager.format_game_time(GameManager.game_state.stats.play_time, game_play_colon_visible)
	time_updated.emit(time_str)


func _set_map_name() -> void:
	var map_name = ""
	if GameManager.current_map:
		map_name = _camel_case_to_spaced(RPGMapsInfo.get_map_name_from_id(GameManager.current_map.internal_id))
	map_name_updated.emit(map_name)


func _set_chapter_name() -> void:
	var chapter = ""
	if GameManager.game_state:
		chapter = GameManager.game_state.game_chapter_name
	chapter_name_updated.emit(chapter)


func _camel_case_to_spaced(text: String) -> String:
	var regex = RegEx.new()
	regex.compile("([a-z])([A-Z])")
	return regex.sub(text, "$1 $2", true)
#endregion
