@tool
class_name RPGMapTerrainDamage
extends  Resource


## The amount of damage (or healing if negative) received when stepping on this tile.
@export var damage_value: int = 0
## If true, damage will be applied at the interval of “damage_interval” seconds continuously.
@export var is_continuous_damage : bool = true
## Time interval between each tick of continuous damage or healing, in seconds.
@export var damage_interval : float = 0.4
## Specifies whether the damage or healing affects HP or MP.
@export_enum("HP", "MP") var damage_target: int = 0



func _to_string() -> String:
	var target = "HP" if damage_target == 0 else "MP"
	var sign = "+" if damage_value < 0 else "-"
	
	if is_continuous_damage:
		return "%s %d %s / %.2fs" % [sign, abs(damage_value), target, damage_interval]
	else:
		return "%s %d %s" % [sign, abs(damage_value), target]
