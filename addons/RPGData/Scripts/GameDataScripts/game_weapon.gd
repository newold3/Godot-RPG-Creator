class_name GameWeapon
extends GameGearBase


func get_experience_to_level_up() -> int:
	var weapon = get_real_data()
	if weapon:
		if current_level >= weapon.upgrades.max_levels - 1:
			return 0
		else:
			var required_experience = weapon.upgrades.levels[current_level + 1].required_experience - current_experience
			return required_experience
	
	return 0


func get_next_level_experience() -> int:
	var weapon = get_real_data()
	if weapon:
		if current_level >= weapon.upgrades.max_levels - 1:
			return 0
		else:
			return weapon.upgrades.levels[current_level + 1].required_experience
	
	return 0


func _to_string() -> String:
	var data = get_real_data()
	var data_name = "" if not data else "<%s> " % data.name
	return "<Game Weapon %s%s: id=%s level=%s type=%s total_equipped=%s is_equipped=%s>" % [data_name, get_instance_id(), id, current_level, type, total_equipped, equipped]
