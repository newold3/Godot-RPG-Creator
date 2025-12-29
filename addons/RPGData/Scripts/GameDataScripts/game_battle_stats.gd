class_name GameBattleStats
extends Resource

@export var won: int = 0 # Number of battles won
@export var lost: int = 0 # Number of battles lost
@export var drawn: int = 0 # Number of battles that ended in a draw
@export var escaped: int = 0 # Number of battles escaped from
@export var total_played: int = 0 # Total number of battles participated in
@export var current_win_streak: int = 0 # Current consecutive wins
@export var longest_win_streak: int = 0 # Longest consecutive win streak achieved
@export var current_lose_streak: int = 0 # Current consecutive losses
@export var longest_lose_streak: int = 0 # Longest consecutive lose streak suffered
@export var longest_battle_time: float = 0.0 # Duration of the longest battle in seconds
@export var shortest_battle_time: float = 0.0 # Duration of the shortest battle in seconds
@export var total_combat_turns: int = 0 # Total number of turns taken in all battles
@export var total_time_in_battle: float = 0.0 # Total time spent in battle (seconds)
@export var total_experience_earned: int = 0 # Total experience points earned in battle
@export var total_damage_received: int = 0 # Total damage received by player in battle
@export var total_damage_done: int = 0 # Total damage dealt by player in battle
@export var total_used_skills: int = 0 # Total number of skills used in battles
@export var total_critiques_performed: int = 0 # Total critical hits performed in battle
