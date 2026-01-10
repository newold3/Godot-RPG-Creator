@tool
class_name RPGSystem
extends Resource


@export var game_title: String
@export var options: Dictionary
@export var party_active_members: int = 4
@export var start_party: PackedInt32Array = []
@export var player_start_position: RPGMapPosition = RPGMapPosition.new()
@export var land_transport_start_position: RPGMapPosition = RPGMapPosition.new()
@export var sea_transport_start_position: RPGMapPosition = RPGMapPosition.new()
@export var air_transport_start_position: RPGMapPosition = RPGMapPosition.new()
@export var currency_info: Dictionary # {"name": String, "icon": String}
@export var game_musics: Array = [] # {"path": String, "volume": float, "pitch": float}
@export var game_fxs: Array = [] # {"path": String, "volume": float, "pitch": float}
@export var default_message_config: Dictionary
@export var land_transport: String
@export var sea_transport: String
@export var air_transport: String
@export var default_map_transition: RPGEventCommand = RPGEventCommand.new(52,  0, {"type": 1, "duration": 0.5})
@export var default_battle_transition: RPGEventCommand = RPGEventCommand.new(52,  0, {"type": 1, "duration": 0.5})
@export var max_items_per_stack: int = 99
@export var max_items_in_inventory: int = 2500
@export var initial_chapter_name: String = "Prologue"
@export var movement_mode: CharacterBase.MOVEMENTMODE = CharacterBase.MOVEMENTMODE.GRID
@export var preload_scenes: PackedStringArray = []
@export var day_night_config: GameDayNight = GameDayNight.new()
@export var custom_signal_list: PackedStringArray = []
@export var game_scenes: Dictionary = {}
@export var pause_day_night_in_menu: bool = true
@export var followers_enabled: bool = false
@export var message_image_positions: Dictionary = {} # "path" = Dictionary Config
## Emulates the behavior of other RPG Makers (when an event activates its page,
## if a command changes the active page, only the active page’s graphic is updated,
## but the current page continues executing all of its commands).
## [br]When disabled, any command that changes the active page will interrupt
## the current page’s commands and immediately jump to the active page.
@export var legacy_mode: bool = true
## When an event command changes the active page for that event, the graph
## for the next active page will appear instantly if this parameter is disabled
## (legacy mode) or via a fade out/fade in when this parameter is enabled.
@export var fade_page_swap_enabled: bool = false


func get_class(): return "RPGSystem"


func clone(value: bool = true) -> RPGSystem:
	var new_system = duplicate(value)
	
	for i in new_system.game_musics.size():
		new_system.game_musics[i] = new_system.game_musics[i].duplicate(value)
		
	for i in new_system.game_fxs.size():
		new_system.game_fxs[i] = new_system.game_fxs[i].duplicate(value)
	
	new_system.default_map_transition = default_map_transition.clone(value)
	new_system.default_battle_transition = default_battle_transition.clone(value)
	
	if day_night_config:
		new_system.day_night_config = day_night_config.clone(value)
	else:
		new_system.day_night_config = GameDayNight.new()
	
	return new_system
