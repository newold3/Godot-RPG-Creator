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


func get_next_level_experience() -> int:
	return 0


func add_experience(amount: int) -> bool:
	var real = get_real_data()
	if not real or "upgrades" not in real or not real.upgrades or real.upgrades.max_levels <= 1:
		return false
	if current_level >= real.upgrades.max_levels:
		return false
	
	current_experience += amount
	var leveled_up = false
	while current_level < real.upgrades.max_levels:
		var next_req = get_next_level_experience() if has_method("get_next_level_experience") else 0
		if next_req > 0 and current_experience >= next_req:
			current_experience -= next_req
			current_level += 1
			leveled_up = true
		else:
			break
			
	if GameManager and GameManager.has_method("is_stacking_mode_enabled") and GameManager.is_stacking_mode_enabled():
		var item_type = 1 if type == 1 else 2
		if GameManager.inventory_manager and GameManager.inventory_manager.has_method("sync_equipment_level_and_exp"):
			GameManager.inventory_manager.sync_equipment_level_and_exp(item_type, id, current_level, current_experience)
			
	return leveled_up


func set_level(new_level: int) -> void:
	var real = get_real_data()
	var max_lvl = real.upgrades.max_levels if real and "upgrades" in real and real.upgrades else 99
	current_level = clamp(new_level, 1, max_lvl)
	if GameManager and GameManager.has_method("is_stacking_mode_enabled") and GameManager.is_stacking_mode_enabled():
		var item_type = 1 if type == 1 else 2
		if GameManager.inventory_manager and GameManager.inventory_manager.has_method("sync_equipment_level_and_exp"):
			GameManager.inventory_manager.sync_equipment_level_and_exp(item_type, id, current_level, current_experience)
