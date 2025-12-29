class_name GameStatistics
extends Resource

@export var steps: int = 0 # Total steps taken (step = current map tile size = 1)
@export var play_time: float = 0 # Total playing time in seconds
@export var enemy_kills: Dictionary = {} # {Unique ID enemy: kill count}
@export var battles: GameBattleStats = GameBattleStats.new() # Battle statistics (won, lost, drawn, escaped, streaks, etc.)
@export var skills: Dictionary = {} # {Unique ID skill: total times used} (Ex: 10 = 15)
@export var items_sold: Dictionary = {} # {item type + _ + Unique ID item: total sold} (items, weapons or armors -> Ex: 0-10 = 15)
@export var items_purchased: Dictionary = {} # {item type + _ + Unique ID item total purchased} (items, weapons or armors -> Ex: 0-10 = 15)
@export var items_found: Dictionary = {} # {item type + _ + Unique ID item} (items, weapons or armors -> Ex: 0-10 = 15)
@export var extractions: GameExtractionStats = GameExtractionStats.new()
@export var save_count: int = 0 # Number of times the game has been saved
@export var game_progress: float = 0.0 # Overall game completion percentage (0.0 to 1.0)
@export var total_money_earned: int = 0 # Total money earned throughout the game
@export var total_money_spent: int = 0 # Total money spent throughout the game
@export var player_deaths: int = 0 # Number of times the player has died
@export var chests_opened: int = 0 # Total number of chests opened (* This statistic needs to be increased manually)
@export var secrets_found: int = 0 # Number of secret areas/items discovered (* This statistic needs to be increased manually)
@export var max_level_reached: int = 0 # Highest level achieved by player
@export var dialogues_completed: int = 0 # Number of dialogue conversations completed
@export var rare_items_found: int = 0 # Number of rare/unique items discovered (* This statistic needs to be increased manually)
@export var missions: GameMissionStats = GameMissionStats.new() # Mission statistics (completed, in_progress, failed, total_found)
@export var relationships: Dictionary = {} # NPC relationship data (Unique Map ID_Unique Event ID = GameRelationship) (* This statistic needs to be increased manually)
@export var achievements: Dictionary = {} # Achievement data (Achievement ID = GameAchievement)
@export var map_visited: Dictionary = {} # Array of visited map IDs
@export var interactive_events_found: Dictionary = {} # "Unique Map ID_Unique Event ID" for discovered interactive events
@export var user_stats: Dictionary = {} # Stats created by the user and updated manually (stat name -> value int)
