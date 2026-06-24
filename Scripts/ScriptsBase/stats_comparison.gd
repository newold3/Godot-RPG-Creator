@tool
class_name StatsComparison
extends Resource

#region ExportedVariables
## Color used when a stat increases.
@export var increase_color: Color = Color.GREEN

## Color used when a stat decreases.
@export var decrease_color: Color = Color.RED

## Color used when a stat does not change.
@export var no_change_color: Color = Color.WHITE

## Symbol used to indicate the transition to the new stat.
@export var arrow_symbol: String = " → "

## Path to the upgrade icon TextureRect relative to the main control.
@export var upgrade_icon_path: NodePath
#endregion



#region InternalVariables
var comparison_result: int = -1
#endregion



#region Drawing
## Calculates the extra width required for the comparison graphics.
func get_comparison_width(font: Font, font_size: int, current_value: float, new_value: float, suffix: String, key: String, show_comparison: bool) -> float:
	if not show_comparison or current_value == -1.0 or new_value == -1.0:
		return 0.0
		
	var diff = new_value - current_value
	var width = font.get_string_size(arrow_symbol, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	
	var new_text = ""
	if new_value == -1.0 and key.begins_with("state_"):
		new_text = RPGSYSTEM.database.terms.search_message("Equip Stat State Inmune") if RPGSYSTEM.database.terms.has_method("search_message") else "Immune"
	else:
		new_text = GameManager.get_number_formatted(new_value, 0, "", suffix) if GameManager else str(new_value) + suffix
		
	width += font.get_string_size(new_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	
	if diff != 0:
		var diff_text = _get_difference_text(diff, suffix)
		width += font.get_string_size(diff_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		
	return width



## Draws the comparison texts and arrows using the caller's custom string function.
func draw_comparison(control: Control, font: Font, font_size: int, start_x: float, y_center: float, current_value: float, new_value: float, suffix: String, key: String, show_comparison: bool) -> void:
	if not show_comparison or current_value == -1.0 or new_value == -1.0:
		return
		
	var current_x = start_x
	var arrow_pos = Vector2(current_x, y_center + font_size * 0.3)
	
	control.draw_custom_string(font, arrow_pos, arrow_symbol, font_size, control.text_color)
	current_x += font.get_string_size(arrow_symbol, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	
	var new_text = ""
	if new_value == -1.0 and key.begins_with("state_"):
		new_text = RPGSYSTEM.database.terms.search_message("Equip Stat State Inmune") if RPGSYSTEM.database.terms.has_method("search_message") else "Immune"
	else:
		new_text = GameManager.get_number_formatted(new_value, 0, "", suffix) if GameManager else str(new_value) + suffix
		
	var is_resistance = key.begins_with("element_") or key.begins_with("debuff_") or key.begins_with("state_")
	var new_color = _get_value_color(current_value, new_value, is_resistance)
	
	var new_pos = Vector2(current_x, y_center + font_size * 0.3)
	control.draw_custom_string(font, new_pos, new_text, font_size, new_color)
	current_x += font.get_string_size(new_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	
	var diff = new_value - current_value
	if diff != 0:
		var diff_text = _get_difference_text(diff, suffix)
		var diff_pos = Vector2(current_x, y_center + font_size * 0.3)
		control.draw_custom_string(font, diff_pos, diff_text, font_size, new_color)
#endregion



#region Evaluation
## Internal: Returns the formatted text for the difference.
func _get_difference_text(diff: float, suffix: String) -> String:
	var s = "+" if diff > 0 else "-"
	var diff_value = GameManager.get_number_formatted(abs(diff), 0, "", suffix) if GameManager else str(abs(diff)) + suffix
	return " (" + s + diff_value + ")"



## Internal: Determines the color based on the value change.
func _get_value_color(current: float, new_value: float, invert: bool = false) -> Color:
	if current == new_value:
		return no_change_color
		
	var treat_current = -9999.0 if current == -1.0 else current
	var treat_new = -9999.0 if new_value == -1.0 else new_value
	
	if invert:
		if treat_new < treat_current:
			return increase_color
		else:
			return decrease_color
	else:
		if treat_new > treat_current:
			return increase_color
		else:
			return decrease_color



## Evaluates overall equipment changes to trigger the upgrade icon.
func evaluate_equipment_comparison(control: Control, current_actor: GameActor, current_stats: Dictionary, stats_structure: Dictionary, show_comparison: bool) -> void:
	var upgrade_node: TextureRect = null
	if upgrade_icon_path != NodePath("") and control.has_node(upgrade_icon_path):
		upgrade_node = control.get_node(upgrade_icon_path) as TextureRect
		
	if not current_actor or not show_comparison:
		_apply_evaluation_result(upgrade_node, -1, show_comparison)
		return
		
	var class_id = current_actor.current_class
	var weights: Dictionary
	var current_class_data = RPGSYSTEM.get_data("classes", class_id)
	
	if current_class_data:
		weights = current_class_data.weights
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
		
	var main_stats = []
	if stats_structure.has("Main Stats"):
		main_stats = stats_structure["Main Stats"]
		
	if main_stats.is_empty() and RPGSYSTEM.database.types.main_parameters.size() >= 8:
		for i in range(0, min(8, RPGSYSTEM.database.types.main_parameters.size())):
			main_stats.append(RPGSYSTEM.database.types.main_parameters[i])
			
	var current_score = 0.0
	var new_score = 0.0
	var stats_found = 0
	
	var hp_current = 0
	var hp_new = 0
	if main_stats.size() > 0 and main_stats[0] in current_stats and current_stats[main_stats[0]] is Array:
		hp_current = current_stats[main_stats[0]][0]
		hp_new = current_stats[main_stats[0]][1]
		
	var hp_percentage = float(hp_new) / float(hp_current) if hp_current > 0 else 1.0
	var is_hp_critical = hp_percentage <= 0.1
	
	var stat_name_mapping = {
		0: "HP",
		1: "MP",
		2: "ATK",
		3: "DEF",
		4: "MATK",
		5: "MDEF",
		6: "AGI",
		7: "LUCK"
	}
	
	for i in range(main_stats.size()):
		var stat_name = main_stats[i]
		if stat_name in current_stats and current_stats[stat_name] is Array:
			var current_val = current_stats[stat_name][0]
			var new_val = current_stats[stat_name][1]
			
			var weight_key = stat_name_mapping.get(i, "HP")
			var weight = weights.get(weight_key, 1.0)
			
			var current_weighted = current_val * weight
			var new_weighted = new_val * weight
			
			if i == 0 and is_hp_critical:
				var hp_difference = new_val - current_val
				var penalty_multiplier = 1.0 + (7.0 * (0.1 - hp_percentage) / 0.1)
				penalty_multiplier = min(penalty_multiplier, 8.0)
				var critical_penalty = abs(hp_difference) * penalty_multiplier
				new_weighted -= critical_penalty
				
			current_score += current_weighted
			new_score += new_weighted
			stats_found += 1
			
	if stats_found == 0:
		_apply_evaluation_result(upgrade_node, -1, show_comparison)
		return
		
	var score_difference = new_score - current_score
	var current_is_better = 0
	var tolerance = 2.0
	
	if is_hp_critical:
		current_is_better = 1
	elif abs(score_difference) <= tolerance:
		current_is_better = -1
	elif score_difference > 0:
		current_is_better = 0
	else:
		current_is_better = 1
		
	_apply_evaluation_result(upgrade_node, current_is_better, show_comparison)



## Internal: Updates the texture rect region based on the result.
func _apply_evaluation_result(upgrade_node: TextureRect, result: int, show_comparison: bool) -> void:
	if not upgrade_node: return
	
	upgrade_node.visible = result != -1
	if show_comparison:
		upgrade_node.texture.region.position.x = 0 if result == 0 else upgrade_node.texture.region.size.x
		comparison_result = result
#endregion
