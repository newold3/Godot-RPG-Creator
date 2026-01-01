extends PanelContainer

@export var upgrade_color: Color = Color.LIME_GREEN
@export var downgrade_color: Color = Color.RED
@export var normal_color: Color = Color.WHITE

var actor: GameActor

@onready var actor_image: TextureRect = %ActorImage
@onready var main_arrow: TextureRect = %MainArrow


func _ready() -> void:
	_set_label_texts()


func _set_label_texts() -> void:
	%HPLabel.text = RPGSYSTEM.database.terms.search_message("Hit Points (abbr)") + ":"
	%MPLabel.text = RPGSYSTEM.database.terms.search_message("Magic Points (abbr)") + ":"
	%ATKLabel.text = RPGSYSTEM.database.terms.search_message("Attack (abbr)") + ":"
	%DEFLabel.text = RPGSYSTEM.database.terms.search_message("Defense (abbr)") + ":"
	%AGILabel.text = RPGSYSTEM.database.terms.search_message("Agility (abbr)") + ":"
	%MATKLabel.text = RPGSYSTEM.database.terms.search_message("Magical Attack (abbr)") + ":"
	%MDEFLabel.text = RPGSYSTEM.database.terms.search_message("Magical Defense (abbr)") + ":"
	%LuckLabel.text = RPGSYSTEM.database.terms.search_message("Luck (abbr)") + ":"


func animate_modulation_alpha(alpha: float) -> void:
	%ActorImage.get_material().set_shader_parameter("opacity", alpha)


func set_actor(p_actor: GameActor) -> void:
	actor = p_actor.duplicate_deep(Resource.DEEP_DUPLICATE_ALL)
	%ActorImage.texture.atlas = preload("uid://c73240mifi8i")
	%ActorImage.texture.region = Rect2()
	%ActorName.text = ""
	var real_actor: RPGActor = GameManager.get_real_actor(actor.id)
	if real_actor:
		%ActorName.text = real_actor.name
		if ResourceLoader.exists(real_actor.face_preview.path):
			%ActorImage.texture.atlas = load(real_actor.face_preview.path)
			%ActorImage.texture.region = real_actor.face_preview.region


func format_number_with_sign(number: int) -> String:
	var number_sign: String = ""
	
	if number > 0:
		number_sign = "+"
	elif number < 0:
		number_sign = ""
	else:
		return "0"
	
	return GameManager.get_number_formatted(number, 0, number_sign)


func _show_stats() -> void:
	%StatsContainer.visible = true


func _hide_stats() -> void:
	%StatsContainer.visible = false


func set_item_to_compare(item_type: int, item_id, item_level: int) -> void:
	if not actor:
		return
		
	var real_object: Variant
	var data: Variant
	
	match item_type:
		1: data = RPGSYSTEM.database.weapons
		2: data = RPGSYSTEM.database.armors
	
	if item_id > 0 and data and data.size() > item_id:
		real_object = data[item_id]

	if real_object:
		var type = 0 if item_type == 1 else 1
		if not actor.can_equip(type, item_id):
			actor_image.get_material().set_shader_parameter("grayscale", true)
			modulate = Color(0.733, 0.733, 0.733, 0.565)
			_set_disabled_label_text()
			main_arrow.visible = false
		else:
			actor_image.get_material().set_shader_parameter("grayscale", false)
			modulate = Color.WHITE
		
			# 1. Current stats
			var current_stats = _get_current_actor_stats()
			
			# 2. Simulate equipment change
			var new_stats = _simulate_equipment_change(item_type, item_id, item_level)
			
			# 3. Update labels with differences
			_update_preview_labels(current_stats, new_stats)

func _get_current_actor_stats() -> Dictionary:
	var stats = {}
	var stat_names = ["HP", "MP", "ATK", "DEF", "AGI", "MATK", "MDEF", "LUCK"]
	
	for stat in stat_names:
		stats[stat] = int(actor.get_parameter(stat))
	
	return stats

func _simulate_equipment_change(item_type: int, item_id: int, item_level: int) -> Dictionary:
	# Backup current equipment
	var equipment_type_id = 0 if item_type == 1 else _get_armor_slot_for_item(item_id)
	var old_equipment = actor.current_gear[equipment_type_id]
	
	# Temporarily change equipment
	actor._set_equip(equipment_type_id, item_id, item_level)
	
	# Get new stats (actor recalculates automatically with all traits)
	var new_stats = _get_current_actor_stats()
	
	# Restore original equipment
	if old_equipment:
		actor._set_equip(equipment_type_id, old_equipment.id, old_equipment.current_level)
	else:
		actor._set_equip(equipment_type_id, -1, 0)
	
	return new_stats

func _get_armor_slot_for_item(armor_id: int) -> int:
	# You need to implement this function to determine which slot the armor goes into
	if armor_id > 0 and RPGSYSTEM.database.armors.size() > armor_id:
		var armor_data: RPGArmor = RPGSYSTEM.database.armors[armor_id]
		return armor_data.equipment_type # Assuming you have this field
	return 1 # Default slot


func _set_disabled_label_text() -> void:
	var labels = [%HP, %MP, %ATK, %DEF, %AGI, %MTAK, %MDEF, %Luck]
	for label in labels:
		label.text = "-"


func _update_preview_labels(current_stats: Dictionary, new_stats: Dictionary):
	var labels = [%HP, %MP, %ATK, %DEF, %MTAK, %AGI, %MDEF, %Luck]
	var stat_names = ["HP", "MP", "ATK", "DEF", "MATK", "MDEF", "AGI", "LUCK"]
	
	# weights given to each attribute to determine whether the equipment is better
	var class_id = actor.current_class
	var weights: Dictionary
	
	if class_id > 0 and RPGSYSTEM.database.classes.size() > class_id:
		weights = RPGSYSTEM.database.classes[class_id].weights
	else:
		weights = {
			"HP": 1.5,
			"MP": 1.0,
			"ATK": 2.0,
			"DEF": 1.8,
			"MATK": 1.5,
			"MDEF": 1.2,
			"AGI": 1.3,
			"LUCK": 0.8
		}
	
	var hp_percentage = float(new_stats["HP"]) / float(current_stats["HP"]) if current_stats["HP"] > 0 else 1.0
	var is_hp_critical = hp_percentage <= 0.1
	
	var current_score = 0.0
	var new_score = 0.0
	
	for stat_name in stat_names:
		var current_value = current_stats[stat_name] * weights[stat_name]
		var new_value = new_stats[stat_name] * weights[stat_name]
		
		if stat_name == "HP" and is_hp_critical:
			var hp_difference = new_stats["HP"] - current_stats["HP"]
			
			var penalty_multiplier = 1.0 + (7.0 * (0.1 - hp_percentage) / 0.1)
			penalty_multiplier = min(penalty_multiplier, 8.0)
			var critical_penalty = abs(hp_difference) * penalty_multiplier
			new_value -= critical_penalty
		
		current_score += current_value
		new_score += new_value
	
	for i in range(stat_names.size()):
		var difference = new_stats[stat_names[i]] - current_stats[stat_names[i]]
		labels[i].text = format_number_with_sign(difference)
		
		if stat_names[i] == "HP" and is_hp_critical:
			labels[i].modulate = Color.RED
		elif difference > 0:
			labels[i].modulate = upgrade_color
		elif difference < 0:
			labels[i].modulate = downgrade_color
		else:
			labels[i].modulate = normal_color
	
	main_arrow.visible = true
	
	var score_difference = new_score - current_score
	var current_is_better = 0
	
	var tolerance = 2.0
	
	if is_hp_critical:
		current_is_better = 1
	elif abs(score_difference) <= tolerance:
		current_is_better = -1 # Equal
	elif score_difference > 0:
		current_is_better = 0 # New is better
	else:
		current_is_better = 1 # Current is better
	
	match current_is_better:
		-1: main_arrow.texture.region.position = Vector2(30, 0) # Equal
		0: main_arrow.texture.region.position = Vector2(0, 0) # New is better
		1: main_arrow.texture.region.position = Vector2(15, 0) # Current is better
