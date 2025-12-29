class_name GameExtractionStats
extends Resource

@export var items_found: Dictionary = {} # Profession id - {} item id -> quantity
@export var total_success: int = 0 # Total item extractions successfully completed
@export var total_failure: int = 0 # Total item extractions failurelly completed
@export var total_finished: int = 0 # Total item extractions completed
@export var total_unfinished: int = 0 # Total item extractions canceled
@export var critical_performs: int = 0 # Critical extractions performed
@export var super_critical_performs: int = 0 # Super Critical extractions performed
@export var resources_interactions: Dictionary = {} # item name -> quantity
