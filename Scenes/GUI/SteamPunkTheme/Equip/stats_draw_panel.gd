extends Control

#region ExportedVariables
@export var increase_color: Color = Color.GREEN
@export var decrease_color: Color = Color.RED
@export var no_change_color: Color = Color.WHITE
@export var text_color: Color = Color.WHITE
@export var title_color: Color = Color.YELLOW
@export var outline_color: Color = Color.BLACK

@export var outline_size: int = 2

@export var arrow_symbol: String = " → "
@export var margin_left: int = 10
@export var margin_right: int = 10
@export var margin_vertical: int = 5
@export var icon_size: Vector2 = Vector2(16, 16)
@export var font_size: int = 14
@export var title_font_size: int = 16
@export var spacing: int = 5
@export var line_spacing: int = 2
@export var section_spacing: int = 10

@export var custom_font: Font
@export var title_background_style: StyleBox
@export var stat_separator_style: StyleBox

@export var upgrade_icon: TextureRect
#endregion



#region InternalVariables
var current_actor: GameActor
var _comparison_actor: GameActor
var current_stats: Dictionary = {}
var stats_data: Array[Dictionary] = []
var hovered_stat: Dictionary = {}
var comparison_item: Dictionary = {}
var comparison_result: int
var show_comparison: bool = true

var stats_structure = {
	"Main Stats": [],
	"Secondary Stats": [],
	"Other Stats": []
}
var stat_key_map: Dictionary = {}
#endregion



#region Initialization
func _ready() -> void:
	if Engine.is_editor_hint(): return
	draw.connect(_on_stats_draw)
	gui_input.connect(_on_stats_gui_input)
	mouse_exited.connect(_on_mouse_exited)
	create_stats_data()
	_calculate_minimum_size()
	queue_redraw()
#endregion



#region InputHandling
func _on_stats_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var mouse_pos = event.position
		var current_y: float = 0
		var found_stat = {}
		
		for data in stats_data:
			var item_height = data.height + line_spacing
			
			if data.type == "stat":
				var stat_rect = Rect2(0, current_y, size.x, data.height)
				if stat_rect.has_point(mouse_pos):
					found_stat = data
					break
			
			current_y += item_height
		
		if found_stat != hovered_stat:
			hovered_stat = found_stat
			_on_hover_stat_changed()



func _on_mouse_exited() -> void:
	hovered_stat = {}
	_on_hover_stat_changed()



func _on_hover_stat_changed() -> void:
	pass
#endregion



#region DataCreation
func create_stats_data() -> void:
	stat_key_map.clear()
	
	for key in stats_structure:
		stats_structure[key].clear()
		
	var internal_keys = RPGActor.get_parameter_list(true)
	var display_names = RPGSYSTEM.database.types.main_parameters
	var main_count = 0
	
	for i in range(min(internal_keys.size(), display_names.size())):
		if internal_keys[i] == "" or internal_keys[i].begins_with("USER_PARAMETER"):
			continue
			
		var display_name = display_names[i]
		stat_key_map[display_name] = internal_keys[i]
		
		if main_count < 8:
			stats_structure["Main Stats"].append(display_name)
			main_count += 1
		else:
			stats_structure["Other Stats"].append(display_name)
			
	if not RPGSYSTEM.database.types.user_parameters.is_empty():
		var user_parameters = RPGSYSTEM.database.types.user_parameters
		for i in user_parameters.size():
			var user_name = user_parameters[i].name
			stats_structure["Secondary Stats"].append(user_name)
			stat_key_map[user_name] = "USER_PARAMETER_%s" % i
	else:
		stats_structure.erase("Secondary Stats")
		
	stats_data.clear()
	var is_first_section = true
	
	for section_name in stats_structure:
		if not is_first_section:
			stats_data.append({
				"type": "spacer",
				"height": section_spacing
			})
			
		is_first_section = false
		
		stats_data.append({
			"type": "title",
			"text": section_name,
			"height": title_font_size + margin_vertical * 2
		})
		
		stats_data.append({
			"type": "spacer",
			"height": 4
		})
		
		var icons = RPGSYSTEM.database.types.icons.main_parameters_icons if section_name == "Main Stats" \
			else RPGSYSTEM.database.types.icons.user_parameters_icons if section_name == "Secondary Stats" \
			else RPGSYSTEM.database.types.icons.main_parameters_icons if section_name == "Other Stats" \
			else null
			
		for stat in stats_structure[section_name]:
			var is_percent = stat in stats_structure["Other Stats"]
			var tex = null
			
			if icons:
				var index = stats_structure[section_name].find(stat)
				if section_name == "Other Stats":
					index += stats_structure["Main Stats"].size()
				var current_icon: RPGIcon = icons[index] if index < icons.size() else null
				if current_icon and AssetManager.exists(current_icon.path):
					var t = ResourceLoader.load(current_icon.path)
					if current_icon.region:
						tex = ImageTexture.create_from_image(t.get_image().get_region(current_icon.region))
					else:
						tex = t
						
			stats_data.append({
				"type": "stat",
				"parent": RPGSYSTEM.database.terms.search_message(section_name),
				"name": stat,
				"key": stat,
				"icon": tex,
				"is_percent": is_percent,
				"height": max(font_size + margin_vertical * 2, icon_size.y + margin_vertical * 2)
			})
			
	_add_element_stats()
	_add_debuff_stats()
	_add_state_stats()
	_calculate_minimum_size()



func _add_element_stats() -> void:
	if not RPGSYSTEM or not RPGSYSTEM.database or not RPGSYSTEM.database.types:
		return
	
	var elements = RPGSYSTEM.database.types.element_types
	var icons = RPGSYSTEM.database.types.icons.element_icons
	var rates = ["Equip Stat Section 4", "Equip Stat Section 5"]
	
	for j in rates.size():
		var rate = rates[j]
		
		stats_data.append({
			"type": "spacer",
			"height": section_spacing
		})
		
		stats_data.append({
			"type": "title",
			"text": RPGSYSTEM.database.terms.search_message(rate),
			"height": title_font_size + margin_vertical * 2
		})
		
		stats_data.append({
			"type": "spacer",
			"height": 4
		})
		
		for i in elements.size():
			var current_element: String = elements[i]
			var current_icon: RPGIcon = icons[i] if i < icons.size() else null
			var tex = null
			
			if current_icon and AssetManager.exists(current_icon.path):
				var t = ResourceLoader.load(current_icon.path)
				if current_icon.region:
					tex = ImageTexture.create_from_image(t.get_image().get_region(current_icon.region))
				else:
					tex = t
			
			stats_data.append({
				"type": "stat",
				"parent": rate,
				"name": current_element,
				"key": current_element + "_" + str(j),
				"icon": tex,
				"is_percent": true,
				"element_rate": j,
				"element_index": i,
				"height": max(font_size + margin_vertical * 2, icon_size.y + margin_vertical * 2)
			})



func _add_debuff_stats() -> void:
	if not RPGSYSTEM or not RPGSYSTEM.database or not RPGSYSTEM.database.types:
		return
		
	var internal_keys = RPGActor.get_parameter_list(true)
	var main_params = RPGSYSTEM.database.types.main_parameters
	var user_params = RPGSYSTEM.database.types.user_parameters
	var icons = RPGSYSTEM.database.types.icons.main_parameters_icons
	
	var title_text = RPGSYSTEM.database.terms.search_message("Equip Stat Debuff Rates") if RPGSYSTEM.database.terms.has_method("search_message") else "Debuff Rates"
	if title_text == "":
		title_text = "Debuff Rates"
		
	stats_data.append({
		"type": "spacer",
		"height": section_spacing
	})
	
	stats_data.append({
		"type": "title",
		"text": title_text,
		"height": title_font_size + margin_vertical * 2
	})
	
	stats_data.append({
		"type": "spacer",
		"height": 4
	})
	
	for i in internal_keys.size():
		var key = internal_keys[i]
		
		if key == "":
			continue
			
		var display_name = ""
		var current_icon = null
		
		if key.begins_with("USER_PARAMETER"):
			var u_id = key.replace("USER_PARAMETER_", "").to_int()
			if u_id < user_params.size():
				display_name = user_params[u_id].name
			else:
				display_name = key
		else:
			if i < main_params.size():
				display_name = main_params[i]
				if icons and i < icons.size():
					current_icon = icons[i]
			else:
				display_name = key
				
		var tex = null
		if current_icon and AssetManager.exists(current_icon.path):
			var t = ResourceLoader.load(current_icon.path)
			if current_icon.region:
				tex = ImageTexture.create_from_image(t.get_image().get_region(current_icon.region))
			else:
				tex = t
				
		stats_data.append({
			"type": "stat",
			"parent": "Debuff Rates",
			"name": display_name,
			"key": "debuff_" + str(i),
			"icon": tex,
			"is_percent": true,
			"height": max(font_size + margin_vertical * 2, icon_size.y + margin_vertical * 2)
		})



func _add_state_stats() -> void:
	if not RPGSYSTEM or not RPGSYSTEM.database:
		return
		
	var states = RPGSYSTEM.database.states
	if states.is_empty():
		return
		
	var title_text = RPGSYSTEM.database.terms.search_message("Equip Stat State Rates") if RPGSYSTEM.database.terms.has_method("search_message") else "State Rates"
	if title_text == "":
		title_text = "State Rates"
		
	stats_data.append({
		"type": "spacer",
		"height": section_spacing
	})
	
	stats_data.append({
		"type": "title",
		"text": title_text,
		"height": title_font_size + margin_vertical * 2
	})
	
	stats_data.append({
		"type": "spacer",
		"height": 4
	})
	
	for i in states.size():
		var state = states[i]
		if not state or state.name.strip_edges() == "":
			continue
			
		var tex = null
		if state.icon and AssetManager.exists(state.icon.path):
			var t = ResourceLoader.load(state.icon.path)
			if state.icon.region:
				tex = ImageTexture.create_from_image(t.get_image().get_region(state.icon.region))
			else:
				tex = t
				
		stats_data.append({
			"type": "stat",
			"parent": "State Rates",
			"name": state.name,
			"key": "state_" + str(state._uniq_id),
			"icon": tex,
			"is_percent": true,
			"height": max(font_size + margin_vertical * 2, icon_size.y + margin_vertical * 2)
		})
#endregion



#region Drawing
func _calculate_minimum_size() -> void:
	var font: Font = custom_font if custom_font else ThemeDB.fallback_font
	var total_height: float = 0
	var max_width: float = 200
	
	for data in stats_data:
		total_height += data.height + line_spacing
		
		if data.type == "stat":
			var width = _calculate_stat_width(font, data)
			max_width = max(max_width, width)
	
	custom_minimum_size = Vector2(max_width, total_height)



func _calculate_stat_width(font: Font, data: Dictionary) -> float:
	var width: float = margin_left + margin_right
	
	if data.icon:
		width += icon_size.x + spacing
	
	if data.name != "":
		width += font.get_string_size(data.name, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + spacing
	
	var sample_current = "999"
	var sample_new = "999"
	if data.is_percent:
		sample_current += "%"
		sample_new += "%"
	
	width += font.get_string_size(sample_current, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	
	if show_comparison:
		width += font.get_string_size(arrow_symbol, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		width += font.get_string_size(sample_new, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	
	return width



func _on_stats_draw() -> void:
	var font: Font = custom_font if custom_font else ThemeDB.fallback_font
	var current_y: float = 0
	
	for data in stats_data:
		match data.type:
			"spacer":
				current_y += data.height
			
			"title":
				_draw_title(font, tr(data.text), current_y, data.height)
				current_y += data.height
			
			"stat":
				_draw_stat(font, data, current_y, data.height)
				current_y += data.height
		
		current_y += line_spacing



func _draw_title(font: Font, title_text: String, y_pos: float, height: float) -> void:
	if title_background_style:
		var title_rect = Rect2(0, y_pos, size.x - 4, height)
		title_background_style.draw(get_canvas_item(), title_rect)
	
	var text_pos = Vector2(margin_left, y_pos + height * 0.5 + title_font_size * 0.3)
	draw_string_outline(font, text_pos, title_text, HORIZONTAL_ALIGNMENT_LEFT, -1, title_font_size, outline_size, outline_color)
	draw_string(font, text_pos, title_text, HORIZONTAL_ALIGNMENT_LEFT, -1, title_font_size, title_color)



func _draw_stat(font: Font, data: Dictionary, y_pos: float, height: float) -> void:
	if stat_separator_style:
		var separator_rect = Rect2(margin_left, y_pos + height, size.x - margin_left - margin_right, 1)
		stat_separator_style.draw(get_canvas_item(), separator_rect)
		
	var current_x: float = margin_left
	var y_center: float = y_pos + height * 0.5
	
	if data.icon:
		var icon_rect = Rect2(Vector2(current_x, y_center - icon_size.y * 0.5), icon_size)
		draw_texture_rect(data.icon, icon_rect, false)
		current_x += icon_size.x + spacing
		
	if data.name != "":
		var real_name = tr(data.name)
		var text_pos = Vector2(current_x, y_center + font_size * 0.3)
		draw_string_outline(font, text_pos, real_name, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, outline_size, outline_color)
		draw_string(font, text_pos, real_name, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, text_color)
		var text_width = font.get_string_size(real_name, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		current_x += text_width + spacing
		
	var current_value = 0.0
	var new_value = 0.0
	
	if data.key in current_stats:
		current_value = current_stats[data.key][0]
		new_value = current_stats[data.key][1]
		
	var suffix = "%" if data.is_percent else ""
	var current_text = ""
	var new_text = ""
	
	if current_value == -1.0 and data.key.begins_with("state_"):
		current_text = RPGSYSTEM.database.terms.search_message("Equip Stat State Inmune") if RPGSYSTEM.database.terms.has_method("search_message") else "Immune"
	else:
		current_text = GameManager.get_number_formatted(current_value, 0, "", suffix) if GameManager else str(current_value) + suffix
		
	if new_value == -1.0 and data.key.begins_with("state_"):
		new_text = RPGSYSTEM.database.terms.search_message("Equip Stat State Inmune") if RPGSYSTEM.database.terms.has_method("search_message") else "Immune"
	else:
		new_text = GameManager.get_number_formatted(new_value, 0, "", suffix) if GameManager else str(new_value) + suffix
		
	var difference = new_value - current_value
	var difference_text = ""
	
	if show_comparison and difference != 0 and current_value != -1.0 and new_value != -1.0:
		var s = "+" if difference > 0 else "-"
		var diff_value = GameManager.get_number_formatted(abs(difference), 0, "", suffix) if GameManager else str(abs(difference)) + suffix
		difference_text = " (" + s + diff_value + ")"
		
	var values_width = font.get_string_size(current_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	
	if show_comparison:
		values_width += font.get_string_size(arrow_symbol, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		values_width += font.get_string_size(new_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		if difference_text != "":
			values_width += font.get_string_size(difference_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
			
	var values_start_x = size.x - margin_right - values_width
	if values_start_x < current_x:
		values_start_x = current_x
		
	var current_value_pos = Vector2(values_start_x, y_center + font_size * 0.3)
	draw_string_outline(font, current_value_pos, current_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, outline_size, outline_color)
	draw_string(font, current_value_pos, current_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, text_color)
	
	if show_comparison:
		values_start_x += font.get_string_size(current_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		var arrow_pos = Vector2(values_start_x, y_center + font_size * 0.3)
		draw_string_outline(font, arrow_pos, arrow_symbol, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, outline_size, outline_color)
		draw_string(font, arrow_pos, arrow_symbol, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, text_color)
		values_start_x += font.get_string_size(arrow_symbol, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		
		var is_resistance = data.key.begins_with("element_") or data.key.begins_with("debuff_") or data.key.begins_with("state_")
		var new_value_color = _get_value_color(current_value, new_value, is_resistance)
		
		var new_value_pos = Vector2(values_start_x, y_center + font_size * 0.3)
		draw_string_outline(font, new_value_pos, new_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, outline_size, outline_color)
		draw_string(font, new_value_pos, new_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, new_value_color)
		
		if difference_text != "":
			values_start_x += font.get_string_size(new_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
			var difference_pos = Vector2(values_start_x, y_center + font_size * 0.3)
			draw_string_outline(font, difference_pos, difference_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, outline_size, outline_color)
			draw_string(font, difference_pos, difference_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, new_value_color)



func _get_value_color(current: float, new: float, invert: bool = false) -> Color:
	if current == new:
		return no_change_color
		
	var treat_current = -9999.0 if current == -1.0 else current
	var treat_new = -9999.0 if new == -1.0 else new
	
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
#endregion



#region LogicAndStats
func set_actor(actor: GameActor, _comparison_item: Dictionary = {}) -> void:
	if not actor:
		return
		
	GameManager.cancel_actors_initialize = true
	current_actor = actor
	current_stats.clear()
	
	_comparison_actor = actor.duplicate_deep(Resource.DEEP_DUPLICATE_ALL)
	
	if _comparison_item and not _comparison_item.is_empty():
		if _comparison_item.id != -1:
			_comparison_actor._set_equip(_comparison_item.slot_id, _comparison_item.id, _comparison_item.level)
		else:
			_comparison_actor._set_equip(_comparison_item.slot_id, -1, 0)
			
	for section_name in stats_structure:
		for stat_label in stats_structure[section_name]:
			var internal_key = stat_key_map.get(stat_label, "")
			if internal_key == "":
				continue
				
			var value1 = 0.0
			var value2 = 0.0
			
			if section_name == "Secondary Stats":
				var u_id = internal_key.replace("USER_PARAMETER_", "").to_int()
				value1 = actor.get_user_parameter(u_id)
				value2 = _comparison_actor.get_user_parameter(u_id)
			else:
				value1 = actor.get_parameter(internal_key)
				value2 = _comparison_actor.get_parameter(internal_key)
				
			current_stats[stat_label] = [value1, value2]
			
	if RPGSYSTEM and RPGSYSTEM.database and RPGSYSTEM.database.types:
		var elements = RPGSYSTEM.database.types.element_types
		for element in elements:
			var attack_rate_value = actor.get_element_attack_rate(element)
			var defense_rate_value = actor.get_element_defense_rate(element)
			var copy_attack_rate_value = _comparison_actor.get_element_attack_rate(element)
			var copy_defense_rate_value = _comparison_actor.get_element_defense_rate(element)
			
			current_stats[element + "_0"] = [attack_rate_value, copy_attack_rate_value]
			current_stats[element + "_1"] = [defense_rate_value, copy_defense_rate_value]
			
	var internal_keys = RPGActor.get_parameter_list(true)
	for i in internal_keys.size():
		if internal_keys[i] == "":
			continue
			
		var debuff_rate = actor.get_debuff_rate(i) * 100.0 if actor.has_method("get_debuff_rate") else 100.0
		var copy_debuff_rate = _comparison_actor.get_debuff_rate(i) * 100.0 if _comparison_actor.has_method("get_debuff_rate") else 100.0
		current_stats["debuff_" + str(i)] = [debuff_rate, copy_debuff_rate]
		
	var states = RPGSYSTEM.database.states
	for i in states.size():
		var state = states[i]
		if not state or state.name.strip_edges() == "":
			continue
			
		var is_immune_actor = _is_state_immune(actor, state._uniq_id)
		var is_immune_copy = _is_state_immune(_comparison_actor, state._uniq_id)
		
		var state_rate = 0.0 if is_immune_actor else (actor.get_state_rate(state._uniq_id) * 100.0 if actor.has_method("get_state_rate") else 100.0)
		var copy_state_rate = 0.0 if is_immune_copy else (_comparison_actor.get_state_rate(state._uniq_id) * 100.0 if _comparison_actor.has_method("get_state_rate") else 100.0)
		
		current_stats["state_" + str(state._uniq_id)] = [
			-1.0 if is_immune_actor else state_rate,
			-1.0 if is_immune_copy else copy_state_rate
		]
		
	_evaluate_equipment_comparison()
	GameManager.cancel_actors_initialize = false
	queue_redraw()



func _is_state_immune(a: GameActor, state_id: int) -> bool:
	if not a or not a.has_method("_get_trait_list"):
		return false
		
	var traits = a._get_trait_list()
	
	for t in traits:
		if t.code == 4 and t.data_id == state_id:
			return true
			
	return false



func _evaluate_equipment_comparison() -> void:
	if not current_actor or not show_comparison:
		_on_equipment_evaluation_result(-1)
		return
		
	var result: int = -1
	if _comparison_actor:
		result = current_actor.compare_stats_to(_comparison_actor)
		
	_on_equipment_evaluation_result(result)



func _on_equipment_evaluation_result(result: int) -> void:
	if not upgrade_icon: return
	
	upgrade_icon.visible = result != -1
	if show_comparison:
		upgrade_icon.texture.region.position.x = 0 if result == 0 else upgrade_icon.texture.region.size.x
		comparison_result = result
#endregion



#region SetupAndGetters
func set_show_comparison(_show_comparison: bool) -> void:
	var last_show_comparison = show_comparison
	show_comparison = _show_comparison
	if not is_inside_tree(): return
	if show_comparison != last_show_comparison:
		_calculate_minimum_size()
		_evaluate_equipment_comparison()
		queue_redraw()
	
	upgrade_icon.visible = _show_comparison



func update_stat_value(stat_key: String, new_value: int) -> void:
	if stat_key in current_stats:
		current_stats[stat_key][1] = new_value
		_evaluate_equipment_comparison()
		queue_redraw()



func reset_all_comparisons() -> void:
	for stat_key in current_stats:
		current_stats[stat_key][1] = current_stats[stat_key][0]
	_evaluate_equipment_comparison()
	queue_redraw()



func get_current_stats() -> Dictionary:
	return current_stats



func get_minimum_size() -> Vector2:
	return custom_minimum_size
#endregion
