class_name GameUserData
extends Resource


@export var actors: Dictionary = {} # {"actor ID": GameActor} Dictionary[int, GameActor] can be serialized but fail to load!
@export var current_party: PackedInt32Array = [] # [actor id]
@export var party_member_locked: PackedInt32Array = [] # [actor id]
@export var items: Dictionary = {} # {"item_id": Array[GameItem]}
@export var weapons: Dictionary = {} # {"item_id": Array[GameWeapon]}
@export var armors: Dictionary = {} # {"item_id": Array[GameArmor]}
@export var active_misions: Array[GameQuest] = []
@export var extraction_items: Dictionary = {} # {"map_id": {"item_id": GameExtractionItem}}
@export var profession_levels: Dictionary = {} # Profession ID -> {Level, sub_level, available, experience}
@export var current_gold: int = 0
@export var game_variables: PackedFloat32Array = []
@export var game_text_variables: PackedStringArray = []
@export var game_switches: PackedByteArray = []
@export var game_self_switches: Dictionary = {}
@export var game_user_parameters: PackedFloat32Array = []
@export var game_chapter_name: String = ""
@export var active_timers: Dictionary = {}
@export var active_shop_timers: Dictionary = {} # shop_id = RPGShopTimer
@export var current_map_id: int = -1
@export var current_map_position: Vector2i
@export var current_direction: LPCCharacter.DIRECTIONS = LPCCharacter.DIRECTIONS.DOWN
@export var land_transport_start_position: RPGMapPosition = RPGMapPosition.new()
@export var sea_transport_start_position: RPGMapPosition = RPGMapPosition.new()
@export var air_transport_start_position: RPGMapPosition = RPGMapPosition.new()
@export var stats: GameStatistics = GameStatistics.new()
@export var current_message_config: Dictionary = {}
@export var menu_scene_prohibited: bool = false
@export var save_scene_prohibited: bool = false
@export var formation_scene_prohibited: bool = false
@export var auto_save: bool = false
@export var post_battle_summary: bool = true
@export var active_time_battle: bool = false
@export var current_transition: Dictionary
@export var experience_mode: int = 0
@export var followers_enabled: bool = false
@export var followers_tracking_enabled: bool = true
@export var current_day_night_component: RPGDayNightComponent
@export var bgm_saved: Dictionary
@export var plugin_data: Dictionary = {} # used by user plugins to store any data
@export var current_day_time: float = 0.0
# Stores event IDs that were erased via "Erase Event" command on the CURRENT map.
# This list must be cleared whenever the player changes maps (transfer),
# but MUST be saved/loaded to persist within the same map session.
@export var erased_events: Array[int] = []


# When load this variable is populated and events used it to determine active page and position
var current_events: Dictionary = {}
