class_name GameRelationship
extends Resource

@export var map_id: int # Unique ID of the map where this npc lives
@export var character_id: int = 0 # Unique ID of the character
@export var max_level: int = 0 # Maximum relationship level possible
@export var level_names: PackedStringArray # Name given to each level of relationship with this character
@export var current_level: int = 0 # Current relationship level
@export var exp_next_level: float = 0.0 # Experience points needed for next level
