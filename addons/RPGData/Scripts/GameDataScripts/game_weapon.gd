class_name GameWeapon
extends GameGearBase


func get_experience_to_level_up() -> int:
	if id > 0 and RPGSYSTEM.database.weapons.size() > id:
		var real_data: RPGWeapon = RPGSYSTEM.database.weapons[id]
		if current_level >= real_data.upgrades.max_levels - 1:
			return 0
		else:
			var required_experience = real_data.upgrades.levels[current_level + 1].required_experience - current_experience
			return required_experience
	
	return 0


func get_next_level_experience() -> int:
	if id > 0 and RPGSYSTEM.database.weapons.size() > id:
		var real_data: RPGWeapon = RPGSYSTEM.database.weapons[id]
		if current_level >= real_data.upgrades.max_levels - 1:
			return 0
		else:
			return real_data.upgrades.levels[current_level + 1].required_experience
	
	return 0


func _to_string() -> String:
	var data = get_real_data()
	var data_name = "" if not data else "<%s> " % data.name
	return "<Game Weapon %s%s: id=%s level=%s type=%s total_equipped=%s is_equipped=%s>" % [data_name, get_instance_id(), id, current_level, type, total_equipped, equipped]
