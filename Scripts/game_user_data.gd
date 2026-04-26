class_name GameUserData
extends Resource


## Dictionary containing game actors data by their ID.
@export var actors: Dictionary = {}

## Array of actor IDs currently in the active party.
@export var current_party: PackedInt32Array = []

## Array of actor IDs that are locked in the party and cannot be removed.
@export var party_member_locked: PackedInt32Array = []

## Dictionary of inventory items sorted by item ID.
@export var items: Dictionary = {}

## Dictionary of inventory weapons sorted by item ID.
@export var weapons: Dictionary = {}

## Dictionary of inventory armors sorted by item ID.
@export var armors: Dictionary = {}

## Dictionary of gear sets or costumes sorted by item ID.
@export var sets: Dictionary = {}

## Dictionary mapping actor IDs to their skill evolution usage data.
@export var skill_evolves: Dictionary = {}

## Current state and progression of the player's active and unlocked quests.
@export var quest_progress: GameQuestProgress = GameQuestProgress.new()

## Dictionary of extraction items sorted by map ID and item ID.
@export var extraction_items: Dictionary = {}

## Dictionary mapping profession IDs to their current levels and experience.
@export var profession_levels: Dictionary = {}

## Current amount of gold the player has.
@export var current_gold: int = 0

## Array of float variables used for custom game logic.
@export var game_variables: PackedFloat32Array = []

## Array of string variables used for custom game text.
@export var game_text_variables: PackedStringArray = []

## Array of byte flags used as game switches.
@export var game_switches: PackedByteArray = []

## Dictionary of self switches for specific map events.
@export var game_self_switches: Dictionary = {}

## Array of float parameters defined by the user.
@export var game_user_parameters: PackedFloat32Array = []

## Name of the current chapter of the game.
@export var game_chapter_name: String = ""

## Dictionary of active game timers.
@export var active_timers: Dictionary = {}

## Dictionary of active shop timers sorted by shop ID.
@export var active_shop_timers: Dictionary = {}

## ID of the map the player is currently exploring.
@export var current_map_id: int = -1

## Current grid coordinates of the player on the map.
@export var current_map_position: Vector2i

## Current facing direction of the player character.
@export var current_direction: LPCCharacter.DIRECTIONS = LPCCharacter.DIRECTIONS.DOWN

## Starting position coordinates for the land transport vehicle.
@export var land_transport_start_position: RPGMapPosition = RPGMapPosition.new()

## Starting position coordinates for the sea transport vehicle.
@export var sea_transport_start_position: RPGMapPosition = RPGMapPosition.new()

## Starting position coordinates for the air transport vehicle.
@export var air_transport_start_position: RPGMapPosition = RPGMapPosition.new()

## General statistics and history of the current playthrough.
@export var stats: GameStatistics = GameStatistics.new()

## Configuration settings for the current message window UI.
@export var current_message_config: Dictionary = {}

## Flag to determine if accessing the main menu scene is prohibited.
@export var menu_scene_prohibited: bool = false

## Flag to determine if saving the game is currently prohibited.
@export var save_scene_prohibited: bool = false

## Flag to determine if changing party formation is prohibited.
@export var formation_scene_prohibited: bool = false

## Flag to enable or disable automatic saving functionality.
@export var auto_save: bool = false

## Flag to determine if the post-battle summary screen should be shown.
@export var post_battle_summary: bool = true

## Flag to enable active time battle system mechanics.
@export var active_time_battle: bool = false

## Dictionary containing data for the current screen transition effect.
@export var current_transition: Dictionary

## Current mode of experience point distribution among party members.
@export var experience_mode: int = 0

## Flag to enable or disable party followers visible on the map.
@export var followers_enabled: bool = false

## Flag to determine if followers track the player's movements strictly.
@export var followers_tracking_enabled: bool = true

## Component handling the day and night cycle visual effects.
@export var current_day_night_component: RPGDayNightComponent

## Dictionary storing the currently playing background music data.
@export var bgm_saved: Dictionary

## Dictionary for user plugins to store custom persistent data.
@export var plugin_data: Dictionary = {}

## Dictionary tracking which map names have been already shown to the player.
@export var map_names_shown: Dictionary = {}

## Current time of day in the game world.
@export var current_day_time: float = 0.0

## Array of event IDs that were temporarily erased via commands on the current map.
@export var erased_events: Array[int] = []

## Dictionary containing user configured in-game options.
@export var in_game_options: Dictionary = {}

## Dictionary storing data about the last item used by the player.
@export var last_item_used: Dictionary = {}

## Dictionary mapping actor IDs to the last skill they used.
@export var last_skill_used: Dictionary = {}

## Dictionary tracking events that have migrated between different maps.
@export var migrated_events: Dictionary = {}

## Path to a custom UI scene used for displaying the map name.
@export var custom_map_name_scene_path: String = ""

## Dictionary of active weather effects currently applied to the map.
@export var active_weathers: Dictionary = {}

## variable used to re-trigger events when a game is loaded
var current_events: Dictionary = {}
