@tool
class_name StatsDisplay
extends Control

#region ExportedVariables
@export_group("Configuration")
## Resource containing the comparison logic and configuration.
@export var comparison_module: StatsComparison

## Toggles the display of the comparison graphics.
@export var show_comparison: bool = true

## If true, parameter names will be abbreviated using the standard internal map.
@export var use_abbreviations: bool = false


@export_group("Outlines")
## Array of sizes for the text outlines. This array dictates the size of the others.
@export var outline_sizes: Array[int] = [2] :
	set(value):
		outline_sizes = value
		_sync_outline_arrays()

## Array of colors for the text outlines.
@export var outline_colors: Array[Color] = [Color.BLACK] :
	set(value):
		outline_colors = value
		_sync_outline_arrays()

## Array of offsets for the text outlines.
@export var outline_offsets: Array[Vector2i] = [Vector2i.ZERO] :
	set(value):
		outline_offsets = value
		_sync_outline_arrays()


@export_group("Typography & Colors")
## Color used for the main text.
@export var text_color: Color = Color.WHITE

## Color used for section titles.
@export var title_color: Color = Color.YELLOW

## Custom font to use instead of the default theme font.
@export var custom_font: Font

## Font size for standard text.
@export var font_size: int = 14

## Font size for section titles.
@export var title_font_size: int = 16


@export_group("Layout & Margins")
## Left margin for the stats list.
@export var margin_left: int = 10

## Right margin for the stats list.
@export var margin_right: int = 10

## Vertical margin for each stat item.
@export var margin_vertical: int = 5

## Size of the icons drawn next to stats.
@export var icon_size: Vector2 = Vector2(16, 16)

## Spacing between elements horizontally.
@export var spacing: int = 5

## Vertical spacing between lines.
@export var line_spacing: int = 2

## Vertical spacing between different sections.
@export var section_spacing: int = 10

## Vertical margin/separation between items.
@export var item_separator: int = 4

## Spacing above and below section titles.
@export var title_separator: int = 10


@export_group("Styles")
## StyleBox used for the background of titles.
@export var title_background_style: StyleBox

## StyleBox used for separating stats lines.
@export var stat_separator_style: StyleBox

## StyleBox used for separating titles.
@export var title_separator_style: StyleBox
#endregion



#region InternalVariables
var current_battler: GameBattler
var _comparison_actor: GameActor
var current_stats: Dictionary = {}
var stats_data: Array[Dictionary] = []
var hovered_stat: Dictionary = {}

var stats_structure = {
	"Main Stats": [],
	"Secondary Stats": [],
	"Other Stats": []
}

var stat_key_map: Dictionary = {}

var standard_abbreviations: Dictionary = {
	"HIT_POINTS": "HP",
	"MAGIC_POINTS": "MP",
	"ATTACK": "ATK",
	"DEFENSE": "DEF",
	"MAGIC_ATTACK": "MAT",
	"MAGIC_DEFENSE": "MDF",
	"AGILITY": "AGI",
	"LUCK": "LUK",
	"HIT_RATE": "HIT",
	"EVASION_RATE": "EVA",
	"CRITICAL_RATE": "CRI",
	"CRITICAL_EVASION_RATE": "CEV",
	"MAGIC_EVASION_RATE": "MEV",
	"MAGIC_REFLECTION": "MRF",
	"COUNTER_ATTACK": "CNT",
	"HP_REGENERATION": "HRG",
	"MP_REGENERATION": "MRG",
	"TP_REGENERATION": "TRG",
	"TARGET_RATE": "TGR",
	"GUARD_EFFECT": "GRD",
	"RECOVERY_EFFECT": "REC",
	"HEALING_MASTERY": "HM",
	"MP_COST_RATE": "MCR",
	"TP_CHARGE_RATE": "TCR",
	"PHYSICAL_DAMAGE_RATE": "PDR",
	"MAGIC_DAMAGE_RATE": "MDR",
	"FLOOR_DAMAGE_RATE": "FDR",
	"EXPERIENCE_RATE": "EXR",
	"GOLD_RATE": "GDR"
}

var _is_syncing: bool = false

var _hide_mode_enabled: bool = false
#endregion



#region Initialization
var _last_calculated_width: float = 0.0

func _ready() -> void:
	if Engine.is_editor_hint(): return
	focus_mode = Control.FOCUS_NONE
	set_notify_transform(true)
	draw.connect(_on_stats_draw)
	gui_input.connect(_on_stats_gui_input)
	mouse_exited.connect(_on_mouse_exited)
	item_rect_changed.connect(_on_item_rect_changed)
	create_stats_data()
	recalculate_layout()
	queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED:
		queue_redraw()


func _on_item_rect_changed() -> void:
	if abs(size.x - _last_calculated_width) > 0.01:
		recalculate_layout()
		queue_redraw()



## Internal synchronizer to ensure outline arrays match the master sizes array.
func _sync_outline_arrays() -> void:
	if _is_syncing:
		return
		
	_is_syncing = true
	
	var target_size = outline_sizes.size()
	
	if outline_colors.size() != target_size:
		outline_colors.resize(target_size)
		
	if outline_offsets.size() != target_size:
		outline_offsets.resize(target_size)
			
	_is_syncing = false
	
	if is_inside_tree():
		queue_redraw()
#endregion



#region InputHandling
## Handles mouse input over the stats.
func _on_stats_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var font: Font = custom_font if custom_font else ThemeDB.fallback_font
		var mouse_pos = event.position
		var current_y: float = 0
		var found_stat = {}
		
		var effective_width = size.x
		if effective_width < 10:
			effective_width = 10
			
		var right_col_width = _get_global_right_width(font, effective_width)
			
		var left_col_width = effective_width - margin_left - margin_right - spacing - right_col_width
		
		if left_col_width < 10:
			left_col_width = 10
			
		for data in stats_data:
			var item_height = data.height
			
			if data.type == "stat":
				item_height = _calculate_dynamic_stat_height(font, data, left_col_width)
				
			var total_item_height = item_height + item_separator
			
			if data.type == "stat":
				var stat_rect = Rect2(0, current_y, size.x, item_height)
				if stat_rect.has_point(mouse_pos):
					found_stat = data
					break
					
			current_y += total_item_height
			
		if found_stat != hovered_stat:
			hovered_stat = found_stat
			_on_hover_stat_changed()



## Clears the hovered state when the mouse exits the control.
func _on_mouse_exited() -> void:
	hovered_stat = {}
	_on_hover_stat_changed()



## Virtual method called when the hovered stat changes.
func _on_hover_stat_changed() -> void:
	pass
#endregion



#region DataCreation
## Enable or disable the hide mode (when hide mode is enabled, stats are showns as ???)
func set_hide_mode(value: bool) -> void:
	_hide_mode_enabled = value



## Builds the structure and arrays of stats to display.
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
				"height": title_separator
			})
			
		is_first_section = false
		
		stats_data.append({
			"type": "title",
			"text": section_name,
			"height": title_font_size + margin_vertical * 2
		})
		
		stats_data.append({
			"type": "spacer",
			"height": title_separator
		})
		
		@warning_ignore("incompatible_ternary")
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
	recalculate_layout()



## Appends elemental resistances to the list.
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
			"height": title_separator
		})
		
		stats_data.append({
			"type": "title",
			"text": RPGSYSTEM.database.terms.search_message(rate),
			"height": title_font_size + margin_vertical * 2
		})
		
		stats_data.append({
			"type": "spacer",
			"height": title_separator
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



## Appends debuff resistance rates to the list.
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
		"height": title_separator
	})
	
	stats_data.append({
		"type": "title",
		"text": title_text,
		"height": title_font_size + margin_vertical * 2
	})
	
	stats_data.append({
		"type": "spacer",
		"height": title_separator
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



## Appends state resistance rates to the list.
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
		"height": title_separator
	})
	
	stats_data.append({
		"type": "title",
		"text": title_text,
		"height": title_font_size + margin_vertical * 2
	})
	
	stats_data.append({
		"type": "spacer",
		"height": title_separator
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



#region LazyEvaluation
## Internal: Fetches the parameter dynamically only when requested.
func _fetch_stat_value(data: Dictionary) -> Variant:
	if current_battler is GameActor:
		return [_get_battler_stat(current_battler, data), _get_battler_stat(_comparison_actor, data)]
	else:
		return _get_battler_stat(current_battler, data)



## Internal: Extracts a specific stat based on the node's configuration dictionary.
func _get_battler_stat(battler: GameBattler, data: Dictionary) -> float:
	var key: String = data.key
	
	if key.begins_with("element_") or data.has("element_index"):
		if data.element_rate == 0:
			return battler.get_element_attack_rate(data.element_index)
		else:
			return battler.get_element_defense_rate(data.element_index)
			
	elif key.begins_with("debuff_"):
		var i = key.trim_prefix("debuff_").to_int()
		return battler.get_debuff_rate(i) * 100.0 if battler.has_method("get_debuff_rate") else 100.0
		
	elif key.begins_with("state_"):
		var id = key.trim_prefix("state_").to_int()
		if _is_state_immune(battler, id):
			return -1.0
		return battler.get_state_rate(id) * 100.0 if battler.has_method("get_state_rate") else 100.0
		
	else:
		var internal_key = stat_key_map.get(data.name, "")
		if internal_key == "": 
			return 0.0
		
		if internal_key.begins_with("USER_PARAMETER_"):
			var u_id = internal_key.replace("USER_PARAMETER_", "").to_int()
			return battler.get_user_parameter(u_id)
		else:
			return battler.get_parameter(internal_key)



## Determines if the battler is entirely immune to a state.
func _is_state_immune(battler: GameBattler, state_id: int) -> bool:
	if not battler or not battler.has_method("_get_trait_list"):
		return false
		
	var traits = battler._get_trait_list()
	for t in traits:
		if t.code == 4 and t.data_id == state_id:
			return true
			
	return false
#endregion



#region Drawing
## Calculates the required width for the numerical values of a single stat line.
func _calculate_single_value_width(font: Font, data: Dictionary, effective_width: float) -> float:
	var current_value = 0.0
	var new_value = 0.0
	var has_comparison = false
	
	if data.key in current_stats:
		if current_stats[data.key] is Array:
			current_value = current_stats[data.key][0]
			new_value = current_stats[data.key][1]
			has_comparison = true
		else:
			current_value = current_stats[data.key]
			
	var suffix = "%" if data.is_percent else ""
	var current_text = ""
	var w1 = 0.0
	var w2 = 0.0
	
	if not _hide_mode_enabled:
		if current_value == -1.0 and data.key.begins_with("state_"):
			current_text = RPGSYSTEM.database.terms.search_message("Equip Stat State Inmune") if RPGSYSTEM.database.terms.has_method("search_message") else "Immune"
		else:
			current_text = GameManager.get_number_formatted(current_value, 0, "", suffix) if GameManager else str(current_value) + suffix
			
		w1 = font.get_string_size(current_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		
		if has_comparison and comparison_module and comparison_module.has_method("get_comparison_width") and show_comparison:
			w2 = comparison_module.get_comparison_width(font, font_size, current_value, new_value, suffix, data.key, show_comparison)
	else:
		current_text = "???"
		w1 = font.get_string_size(current_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		
	if has_comparison and show_comparison and not _hide_mode_enabled:
		var display_name = _get_display_name(data)
		var left_width = font.get_string_size(display_name, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		if data.icon:
			left_width += icon_size.x + spacing
			
		var req_w = left_width + spacing + w1 + w2
		if req_w <= effective_width:
			data.is_single_line_comparison = true
			return w1 + w2
			
	data.is_single_line_comparison = false
	return max(w1, w2)



## Calculates the maximum width required for the right column across all visible stats.
func _get_global_right_width(font: Font, effective_width: float) -> float:
	var max_w = 0.0
	for data in stats_data:
		if data.type == "stat":
			var rw = _calculate_single_value_width(font, data, effective_width)
			if rw > max_w:
				max_w = rw
	return max_w



## Gets the width of the vertical scrollbar if this control is inside a ScrollContainer.
func _get_v_scrollbar_width() -> float:
	var scroll_container: ScrollContainer = null
	var parent_node = get_parent()
	while parent_node:
		if parent_node is ScrollContainer:
			scroll_container = parent_node
			break
		parent_node = parent_node.get_parent()
		
	if scroll_container:
		var v_scroll = scroll_container.get_v_scroll_bar()
		if v_scroll and v_scroll.visible:
			return v_scroll.size.x
	return 0.0


## Calculates the dynamic height of a section title based on available width and word wrapping.
func _calculate_dynamic_title_height(font: Font, data: Dictionary, effective_width: float) -> float:
	var title_avail_width = effective_width - margin_left - margin_right
	if title_avail_width < 10:
		title_avail_width = 10
		
	var translated_title = ""
	if RPGSYSTEM and RPGSYSTEM.database and RPGSYSTEM.database.terms and RPGSYSTEM.database.terms.has_method("search_message"):
		translated_title = RPGSYSTEM.database.terms.search_message(data.text)
	if translated_title == "":
		translated_title = tr(data.text)
		
	var wrap_info = _wrap_text(font, translated_title, title_font_size, title_avail_width)
	var line_h = font.get_height(title_font_size)
	var text_height = wrap_info.lines.size() * line_h
	
	return text_height + margin_vertical * 2


## Recalculates the dynamic heights and custom minimum size for all stats.
func recalculate_layout() -> void:
	var font: Font = custom_font if custom_font else ThemeDB.fallback_font
	var total_height: float = 0
	var max_width: float = 200
	
	var scrollbar_w = _get_v_scrollbar_width()
	var effective_width = size.x - scrollbar_w
	
	if effective_width < 10:
		effective_width = 200
		
	_last_calculated_width = size.x
	
	if current_battler:
		for data in stats_data:
			if data.type == "stat" and not current_stats.has(data.key):
				current_stats[data.key] = _fetch_stat_value(data)
				
	var right_col_width = _get_global_right_width(font, effective_width)
	var left_col_width = effective_width - margin_left - margin_right - spacing - right_col_width
	
	if left_col_width < 10:
		left_col_width = 10
		
	for data in stats_data:
		var item_height = data.height
		
		if data.type == "stat":
			item_height = _calculate_dynamic_stat_height(font, data, left_col_width)
			data.height = item_height
		elif data.type == "title":
			item_height = _calculate_dynamic_title_height(font, data, effective_width)
			data.height = item_height
			
		total_height += item_height + item_separator
		
	custom_minimum_size = Vector2(max_width, total_height)



## Calculates the minimum bounding box needed to draw all stats without doing expensive calculations.
func _calculate_minimum_size() -> void:
	recalculate_layout()



## Gets the properly formatted and translated display name for a stat.
func _get_display_name(data: Dictionary) -> String:
	var display_name: String = data.name
	
	if use_abbreviations:
		var internal_key = stat_key_map.get(data.name, "")
		if standard_abbreviations.has(internal_key):
			display_name = standard_abbreviations[internal_key]
		else:
			display_name = EnglishWordAbbreviator.abbreviate_english_word(display_name)
			
	var translated_name = ""
	if RPGSYSTEM and RPGSYSTEM.database and RPGSYSTEM.database.terms and RPGSYSTEM.database.terms.has_method("search_message"):
		translated_name = RPGSYSTEM.database.terms.search_message(display_name)
	if translated_name == "":
		translated_name = tr(display_name)
		
	return translated_name



## Wraps text into lines and calculates horizontal scale if needed.
func _wrap_text(font: Font, text: String, f_size: int, max_width: float) -> Dictionary:
	var words = text.split(" ")
	var lines = PackedStringArray()
	var current_line = ""
	
	for word in words:
		var test_line = current_line + (" " if current_line != "" else "") + word
		if font.get_string_size(test_line, HORIZONTAL_ALIGNMENT_LEFT, -1, f_size).x > max_width and current_line != "":
			lines.append(current_line)
			current_line = word
		else:
			current_line = test_line
			
	if current_line != "":
		lines.append(current_line)
		
	var max_line_width = 0.0
	
	for line in lines:
		var lw = font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, f_size).x
		if lw > max_line_width:
			max_line_width = lw
			
	var h_scale = 1.0
	
	if max_line_width > max_width and max_line_width > 0:
		h_scale = max_width / max_line_width
		
	return {
		"lines": lines,
		"scale": h_scale
	}



## Calculates the dynamic height of a stat line based on available width and word wrapping.
func _calculate_dynamic_stat_height(font: Font, data: Dictionary, left_col_width: float) -> float:
	var available_name_width = left_col_width
	if data.icon:
		available_name_width -= (icon_size.x + spacing)
		
	if available_name_width < 10:
		available_name_width = 10
		
	var display_name = _get_display_name(data)
	var wrap_info = _wrap_text(font, display_name, font_size, available_name_width)
	
	var line_h = font.get_height(font_size)
	var left_text_height = wrap_info.lines.size() * line_h
	
	var right_lines_count = 1
	if data.key in current_stats and current_stats[data.key] is Array:
		if show_comparison and not _hide_mode_enabled:
			if data.get("is_single_line_comparison", false):
				right_lines_count = 1
			else:
				right_lines_count = 2
			
	var right_text_height = right_lines_count * line_h
	
	var max_text_h = max(left_text_height, right_text_height)
	var base_h = max(max_text_h, icon_size.y)
	
	return base_h + margin_vertical * 2



## Draws text with multiple layered outlines, optionally offsetting them.
func draw_custom_string(font: Font, pos: Vector2, text: String, f_size: int, default_color: Color) -> void:
	var count = outline_sizes.size()
	
	for i in range(count - 1, -1, -1):
		var current_size = 0
		for j in range(i + 1):
			current_size += outline_sizes[j]
			
		var c_color = outline_colors[i] if i < outline_colors.size() else Color.BLACK
		var c_offset = outline_offsets[i] if i < outline_offsets.size() else Vector2i.ZERO
		
		if c_offset != Vector2i.ZERO:
			draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, f_size, current_size, c_color)
			draw_string_outline(font, pos + Vector2(c_offset), text, HORIZONTAL_ALIGNMENT_LEFT, -1, f_size, current_size, c_color)
		else:
			draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, f_size, current_size, c_color)
			
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, f_size, default_color)



## Called by Godot's internal _draw process to render the stats.
func _on_stats_draw() -> void:
	if Engine.is_editor_hint() and not current_battler:
		var temp_rect = Rect2(0, 0, size.x, size.y)
		draw_rect(temp_rect, Color(0, 0, 0, 0.2))
		return
		
	if not current_battler: return
	
	var font: Font = custom_font if custom_font else ThemeDB.fallback_font
	var current_y: float = 0
	
	var scrollbar_w = _get_v_scrollbar_width()
	var effective_width = size.x - scrollbar_w
	
	if effective_width < 10:
		effective_width = 10
		
	var right_col_width = _get_global_right_width(font, effective_width)
		
	var left_col_width = effective_width - margin_left - margin_right - spacing - right_col_width
	
	if left_col_width < 10:
		left_col_width = 10
		
	var visible_top: float = -1e9
	var visible_bottom: float = 1e9
	var p = get_parent()
	while p and p is Control:
		if p.clip_contents:
			var offset_y = global_position.y - p.global_position.y
			visible_top = -offset_y
			visible_bottom = visible_top + p.size.y
			break
		p = p.get_parent()
		
	for data in stats_data:
		var item_height = data.height
		var item_full_height = item_height + item_separator
		
		if visible_top > -1e8:
			var is_visible = not ((current_y + item_full_height) < visible_top or current_y > visible_bottom)
			if not is_visible:
				current_y += item_full_height
				continue
		
		match data.type:
			"title":
				_draw_title(font, data.text, current_y, item_height)
			"stat":
				if not current_stats.has(data.key):
					current_stats[data.key] = _fetch_stat_value(data)
					
				_draw_stat(font, data, current_y, item_height, left_col_width, right_col_width)
				
		current_y += item_full_height



## Draws a section title on the control.
func _draw_title(font: Font, title_text: String, y_pos: float, height: float) -> void:
	var scrollbar_w = _get_v_scrollbar_width()
	if title_background_style:
		var title_rect = Rect2(0, y_pos, size.x - scrollbar_w - 4, height)
		title_background_style.draw(get_canvas_item(), title_rect)
	
	var translated_title = ""
	if RPGSYSTEM and RPGSYSTEM.database and RPGSYSTEM.database.terms and RPGSYSTEM.database.terms.has_method("search_message"):
		translated_title = RPGSYSTEM.database.terms.search_message(title_text)
	if translated_title == "":
		translated_title = tr(title_text)
		
	var title_avail_width = size.x - scrollbar_w - margin_left - margin_right
	if title_avail_width < 10:
		title_avail_width = 10
		
	var wrap_info = _wrap_text(font, translated_title, title_font_size, title_avail_width)
	var line_h = font.get_height(title_font_size)
	var total_text_height = wrap_info.lines.size() * line_h
	
	var start_y = y_pos + height * 0.5 - (total_text_height * 0.5) + font.get_ascent(title_font_size)
	
	for i in range(wrap_info.lines.size()):
		var line = wrap_info.lines[i]
		var line_pos = Vector2(margin_left, start_y + i * line_h)
		
		if wrap_info.scale != 1.0:
			draw_set_transform(line_pos, 0.0, Vector2(wrap_info.scale, 1.0))
			draw_custom_string(font, Vector2.ZERO, line, title_font_size, title_color)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		else:
			draw_custom_string(font, line_pos, line, title_font_size, title_color)
			
	if title_separator_style:
		var separator_rect = Rect2(0, y_pos + height, size.x - scrollbar_w, 1)
		title_separator_style.draw(get_canvas_item(), separator_rect)



## Draws a single stat line, calculating columns and word-wrapping if necessary.
func _draw_stat(font: Font, data: Dictionary, y_pos: float, height: float, left_col_width: float, right_col_width: float) -> void:
	var scrollbar_w = _get_v_scrollbar_width()
	if stat_separator_style:
		var separator_rect = Rect2(margin_left, y_pos + height, size.x - scrollbar_w - margin_left - margin_right, 1)
		stat_separator_style.draw(get_canvas_item(), separator_rect)
		
	var current_x: float = margin_left
	var y_center: float = y_pos + height * 0.5
	
	var available_name_width = left_col_width
	
	if data.icon:
		var icon_rect = Rect2(Vector2(current_x, y_center - icon_size.y * 0.5), icon_size)
		draw_texture_rect(data.icon, icon_rect, false)
		current_x += icon_size.x + spacing
		available_name_width -= (icon_size.x + spacing)
		
	if available_name_width < 10:
		available_name_width = 10
		
	var display_name = _get_display_name(data)
	var wrap_info = _wrap_text(font, display_name, font_size, available_name_width)
	
	var line_h = font.get_height(font_size)
	var total_text_height = wrap_info.lines.size() * line_h
	var start_y = y_center - (total_text_height * 0.5) + font.get_ascent(font_size)
	
	for i in range(wrap_info.lines.size()):
		var line = wrap_info.lines[i]
		var line_pos = Vector2(current_x, start_y + i * line_h)
		
		if wrap_info.scale != 1.0:
			draw_set_transform(line_pos, 0.0, Vector2(wrap_info.scale, 1.0))
			draw_custom_string(font, Vector2.ZERO, line, font_size, text_color)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		else:
			draw_custom_string(font, line_pos, line, font_size, text_color)
			
	var current_value = 0.0
	var new_value = 0.0
	var has_comparison = false
	
	if data.key in current_stats:
		if current_stats[data.key] is Array:
			current_value = current_stats[data.key][0]
			new_value = current_stats[data.key][1]
			has_comparison = true
		else:
			current_value = current_stats[data.key]
			
	var suffix = "%" if data.is_percent else ""
	var current_text = ""
	
	var right_lines_count = 1
	if has_comparison and show_comparison and not _hide_mode_enabled:
		if data.get("is_single_line_comparison", false):
			right_lines_count = 1
		else:
			right_lines_count = 2
		
	if not _hide_mode_enabled:
		if current_value == -1.0 and data.key.begins_with("state_"):
			current_text = RPGSYSTEM.database.terms.search_message("Equip Stat State Inmune") if RPGSYSTEM.database.terms.has_method("search_message") else "Immune"
		else:
			current_text = GameManager.get_number_formatted(current_value, 0, "", suffix) if GameManager else str(current_value) + suffix
	else:
		current_text = "???"
		
	var center_1 = y_center
	var center_2 = y_center
	
	if right_lines_count == 2:
		center_1 = y_center - line_h * 0.5
		center_2 = y_center + line_h * 0.5
		
	var base_1 = center_1 - (line_h * 0.5) + font.get_ascent(font_size)
	var w1 = font.get_string_size(current_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var w2 = 0.0
	if has_comparison and comparison_module and comparison_module.has_method("get_comparison_width") and show_comparison:
		w2 = comparison_module.get_comparison_width(font, font_size, current_value, new_value, suffix, data.key, show_comparison)
		
	var right_edge = size.x - scrollbar_w - margin_right
	var val_start_x = right_edge - w1
	
	if has_comparison and show_comparison and not _hide_mode_enabled:
		if right_lines_count == 1:
			val_start_x = right_edge - w1 - w2
			
	draw_custom_string(font, Vector2(val_start_x, base_1), current_text, font_size, text_color)
	
	if has_comparison and show_comparison and not _hide_mode_enabled:
		if right_lines_count == 2:
			if comparison_module and comparison_module.has_method("draw_comparison"):
				var base_2 = center_2 - (line_h * 0.5) + font.get_ascent(font_size)
				var y_comp_param = base_2 - font_size * 0.3
				var comp_x = right_edge - w2
				comparison_module.draw_comparison(self, font, font_size, comp_x, y_comp_param, current_value, new_value, suffix, data.key, show_comparison)
		else:
			if comparison_module and comparison_module.has_method("draw_comparison"):
				var comp_x = val_start_x + w1
				var y_comp_param = base_1 - font_size * 0.3
				comparison_module.draw_comparison(self, font, font_size, comp_x, y_comp_param, current_value, new_value, suffix, data.key, show_comparison)
#endregion



#region LogicAndStats
## Prepares an actor for live visualization, caching only the essential main parameters for equipment score checks.
func set_actor(actor: GameActor, _comparison_item: Dictionary = {}) -> void:
	if not actor: return
	GameManager.cancel_actors_initialize = true
	current_battler = actor
	current_stats.clear()
	
	_comparison_actor = actor.duplicate_deep(Resource.DEEP_DUPLICATE_ALL)
	
	if _comparison_item and not _comparison_item.is_empty():
		if _comparison_item.id != -1:
			_comparison_actor._set_equip(_comparison_item.slot_id, _comparison_item.id, _comparison_item.level)
		else:
			_comparison_actor._set_equip(_comparison_item.slot_id, -1, 0)
			
	var main_stats = []
	if stats_structure.has("Main Stats"):
		main_stats = stats_structure["Main Stats"]
		
	if main_stats.is_empty() and RPGSYSTEM.database.types.main_parameters.size() >= 8:
		for i in range(0, min(8, RPGSYSTEM.database.types.main_parameters.size())):
			main_stats.append(RPGSYSTEM.database.types.main_parameters[i])
			
	for stat_name in main_stats:
		var internal_key = stat_key_map.get(stat_name, "")
		if internal_key != "":
			var val1 = actor.get_parameter(internal_key)
			var val2 = _comparison_actor.get_parameter(internal_key)
			current_stats[stat_name] = [val1, val2]
			
	if comparison_module and comparison_module.has_method("evaluate_equipment_comparison"):
		comparison_module.evaluate_equipment_comparison(self, current_battler, current_stats, stats_structure, show_comparison)
		
	GameManager.cancel_actors_initialize = false
	recalculate_layout()
	queue_redraw()



## Evaluates the target enemy directly. Will only process parameters once they appear on screen.
func set_enemy(enemy: GameEnemy) -> void:
	if not enemy: return
	current_battler = enemy
	current_stats.clear()
	recalculate_layout()
	queue_redraw()
#endregion



#region SetupAndGetters
## Toggles the comparison view and triggers a redraw.
func set_show_comparison(_show_comparison: bool) -> void:
	var last_show_comparison = show_comparison
	show_comparison = _show_comparison
	if not is_inside_tree(): return
	if show_comparison != last_show_comparison:
		recalculate_layout()
		if comparison_module and comparison_module.has_method("evaluate_equipment_comparison") and current_battler is GameActor:
			comparison_module.evaluate_equipment_comparison(self, current_battler, current_stats, stats_structure, show_comparison)
		queue_redraw()



## Updates a specific stat value in the comparison array.
func update_stat_value(stat_key: String, new_value: int) -> void:
	if stat_key in current_stats and current_stats[stat_key] is Array:
		current_stats[stat_key][1] = new_value
		if comparison_module and comparison_module.has_method("evaluate_equipment_comparison") and current_battler is GameActor:
			comparison_module.evaluate_equipment_comparison(self, current_battler, current_stats, stats_structure, show_comparison)
		recalculate_layout()
		queue_redraw()



## Restores all comparisons to the original values.
func reset_all_comparisons() -> void:
	for stat_key in current_stats:
		if current_stats[stat_key] is Array:
			current_stats[stat_key][1] = current_stats[stat_key][0]
	if comparison_module and comparison_module.has_method("evaluate_equipment_comparison") and current_battler is GameActor:
		comparison_module.evaluate_equipment_comparison(self, current_battler, current_stats, stats_structure, show_comparison)
	recalculate_layout()
	queue_redraw()



## Retrieves the raw stats dictionary currently cached. Unvisited stats will not be present.
func get_current_stats() -> Dictionary:
	return current_stats



## Exposes the calculated custom minimum size.
func get_minimum_size() -> Vector2:
	return custom_minimum_size
#endregion
