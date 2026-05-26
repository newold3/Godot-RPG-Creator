class_name GameGearBase
extends GameItemBase

## current equipment level.
@export var current_level: int = 0
## Current equipment experience (times used in battle for weapons and battles won for other equipment).
@export var current_experience: int = 0
## Indicate if this piece of equipment is equipped.
@export var equipped: bool = false
## Indicates how many items are being equipped.
@export var total_equipped: int = 0
