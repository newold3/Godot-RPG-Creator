extends Control

# Propiedades de configuración
@export var increase_color: Color = Color.GREEN
@export var decrease_color: Color = Color.RED
@export var no_change_color: Color = Color.WHITE
@export var text_color: Color = Color.WHITE
@export var title_color: Color = Color.YELLOW

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
@export var show_comparison: bool = true: set = set_show_comparison
@export var title_background_style: StyleBox
@export var stat_separator_style: StyleBox

@onready var stats_container: Control = %StatsContainer
@onready var upgrade_icon: TextureRect = %UpgradeIcon


# Datos del actor y estadísticas
var current_actor: GameActor
var current_stats: Dictionary = {}
var stats_data: Array[Dictionary] = []
var hovered_stat: Dictionary = {}
var comparison_item: Dictionary = {}
var comparison_result: int

var started: bool = false

var stats_structure = {
	"Main Stats": [
		
	],
	"Secondary Stats" : [
		
	],
	"Other Stats": [
		
	]
}

func _ready() -> void:
	if Engine.is_editor_hint(): return
	%StatsName.text = RPGSYSTEM.database.terms.search_message("Equip Stats")
	stats_container.draw.connect(_on_stats_draw)
	stats_container.gui_input.connect(_on_stats_gui_input) 
	stats_container.mouse_exited.connect(_on_mouse_exited)
	create_stats_data()
	_calculate_minimum_size()
	stats_container.queue_redraw()
	_set_animation_for_upgrade_icon()


func scroll_to(direction: int, strength: float) -> void:
	var node = %SmoothScrollContainer
	var scroll_delta = strength * direction
	node.smooth_scroll_by_delta(scroll_delta, 0)


func _set_animation_for_upgrade_icon() -> void:
	upgrade_icon.visible = false
	upgrade_icon.pivot_offset = upgrade_icon.size * 0.5
	var original_position = upgrade_icon.position
	var t = create_tween()
	t.set_loops()
	t.set_parallel(true)
	t.tween_property(upgrade_icon, "scale", Vector2(0.98, 0.8), 0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_property(upgrade_icon, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN).set_delay(0.25)
	t.tween_property(upgrade_icon, "position:y", original_position.y + 3 * (-1 if comparison_result == 1 else 1), 0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_property(upgrade_icon, "position:y", original_position.y - 3 * (-1 if comparison_result == 1 else 1), 0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN).set_delay(0.25)


func start() -> void:
	started = false
	%Gear1.rotation = 0
	%Gear2.rotation = 0
	%StatsPanel.scale.y = 0.01
	var a = PI / 2.0
	
	var t = create_tween()
	t.set_parallel(true)
	t.tween_property(%StatsPanel, "scale:y", 1.0, 0.20).set_delay(0.15).set_trans(Tween.TRANS_SINE)
	t.tween_property(%Gear1, "rotation", a, 0.7).set_trans(Tween.TRANS_SINE)
	t.tween_property(%Gear2, "rotation", -a, 0.7).set_trans(Tween.TRANS_SINE)
	t.tween_interval(0.01)
	t.set_parallel(false)
	t.tween_callback(set.bind("started", [true]))


func end() -> void:
	started = false


func get_gears() -> Array:
	return [%Gear1, %Gear2]


func _process(_delta: float) -> void:
	if not started: return


func _on_stats_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var mouse_pos = event.position
		var current_y: float = 0
		var found_stat = {}
		
		# Buscar en qué estadística está el ratón
		for data in stats_data:
			var item_height = data.height + line_spacing
			
			if data.type == "stat":
				var stat_rect = Rect2(0, current_y, stats_container.size.x, data.height)
				if stat_rect.has_point(mouse_pos):
					found_stat = data
					break
			
			current_y += item_height
		
		# Actualizar el stat hover solo si cambió
		if found_stat != hovered_stat:
			hovered_stat = found_stat
			_on_hover_stat_changed()

func _on_mouse_exited() -> void:
	hovered_stat = {}
	_on_hover_stat_changed()


func _on_hover_stat_changed() -> void:
	# add effects, cursor or tooltips
	pass


func create_stats_data() -> void:
	for key in stats_structure:
		stats_structure[key].clear()
	
	# Add Main Stats
	var items = RPGSYSTEM.database.types.main_parameters
	for i in range(0, 8, 1):
		stats_structure["Main Stats"].append(items[i])
	
	# Add Secondary Stats
	for i in range(8, items.size(), 1):
		stats_structure["Other Stats"].append(items[i])
	
	# Add user Stats
	if not RPGSYSTEM.database.types.user_parameters.is_empty():
		for user_parameter in RPGSYSTEM.database.types.user_parameters:
			stats_structure["Secondary Stats"].append(user_parameter.name)
	else:
		stats_structure.erase("Secondary Stats")
		
	stats_data.clear()
	
	# Crear datos para las estadísticas principales y secundarias
	var is_first_section = true
	for section_name in stats_structure:
		# Agregar espaciado entre secciones (excepto la primera)
		if not is_first_section:
			stats_data.append({
				"type": "spacer",
				"height": section_spacing
			})
		is_first_section = false
		
		# Agregar título de sección
		stats_data.append({
			"type": "title",
			"text": section_name,
			"height": title_font_size + margin_vertical * 2
		})
		
		# Agregar pequeño espaciado después del título
		stats_data.append({
			"type": "spacer",
			"height": 4
		})
		
		@warning_ignore("incompatible_ternary")
		var icons = RPGSYSTEM.database.types.icons.main_parameters_icons if section_name == "Main Stats" \
			else RPGSYSTEM.database.types.icons.user_parameters_icons if section_name == "Secondary Stats" \
			else RPGSYSTEM.database.types.icons.main_parameters_icons if section_name == "Other Stats" \
			else null

		# Agregar estadísticas de la sección
		for stat in stats_structure[section_name]:
			var is_percent = stat in stats_structure["Other Stats"]
			var tex = null
			if icons:
				var index = stats_structure[section_name].find(stat)
				if section_name == "Other Stats": index += stats_structure["Main Stats"].size()
				var current_icon: RPGIcon = icons[index] if index < icons.size() else null
				
				if current_icon and ResourceLoader.exists(current_icon.path):
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
	
	# Crear datos para las estadísticas de elementos
	if RPGSYSTEM and RPGSYSTEM.database and RPGSYSTEM.database.types:
		var elements = RPGSYSTEM.database.types.element_types
		var icons = RPGSYSTEM.database.types.icons.element_icons
		var rates = ["Equip Stat Section 4", "Equip Stat Section 5"]
		
		for j in rates.size():
			var rate = rates[j]
			
			# Espaciado entre secciones
			stats_data.append({
				"type": "spacer",
				"height": section_spacing
			})
			
			# Título de la sección de elementos
			stats_data.append({
				"type": "title",
				"text": RPGSYSTEM.database.terms.search_message(rate),
				"height": title_font_size + margin_vertical * 2
			})
			
			# Espaciado después del título
			stats_data.append({
				"type": "spacer",
				"height": 4
			})
			
			# Estadísticas de elementos
			for i in elements.size():
				var current_element: String = elements[i]
				var current_icon: RPGIcon = icons[i] if i < icons.size() else null
				var tex = null
				
				if current_icon and ResourceLoader.exists(current_icon.path):
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
	
	# Recalcular tamaño mínimo
	_calculate_minimum_size()

func _calculate_minimum_size() -> void:
	if not stats_container: return
	
	var font: Font = custom_font if custom_font else ThemeDB.fallback_font
	var total_height: float = 0
	var max_width: float = 200
	
	for data in stats_data:
		total_height += data.height + line_spacing
		
		if data.type == "stat":
			var width = _calculate_stat_width(font, data)
			max_width = max(max_width, width)
	
	stats_container.custom_minimum_size = Vector2(max_width, total_height)

func _calculate_stat_width(font: Font, data: Dictionary) -> float:
	var width: float = margin_left + margin_right
	
	# Icono
	if data.icon:
		width += icon_size.x + spacing
	
	# Nombre de la estadística
	if data.name != "":
		width += font.get_string_size(data.name, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + spacing
	
	# Valores (simulamos valores típicos para el cálculo)
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
	var title_font: Font = custom_font if custom_font else ThemeDB.fallback_font
	var current_y: float = 0
	
	for data in stats_data:
		match data.type:
			"spacer":
				current_y += data.height
			
			"title":
				_draw_title(title_font, data.text, current_y, data.height)
				current_y += data.height
			
			"stat":
				_draw_stat(font, data, current_y, data.height)
				current_y += data.height
		
		current_y += line_spacing

func _draw_title(font: Font, title_text: String, y_pos: float, height: float) -> void:
	# Dibujar fondo del título si hay StyleBox
	if title_background_style:
		var title_rect = Rect2(0, y_pos, stats_container.size.x - 4, height)
		title_background_style.draw(stats_container.get_canvas_item(), title_rect)
	
	var text_pos = Vector2(margin_left, y_pos + height * 0.5 + title_font_size * 0.3)
	stats_container.draw_string(font, text_pos, title_text, HORIZONTAL_ALIGNMENT_LEFT, -1, title_font_size, title_color)

func _draw_stat(font: Font, data: Dictionary, y_pos: float, height: float) -> void:
	# Dibujar separador entre estadísticas si hay StyleBox
	if stat_separator_style:
		var separator_rect = Rect2(margin_left, y_pos + height, stats_container.size.x - margin_left - margin_right, 1)
		stat_separator_style.draw(stats_container.get_canvas_item(), separator_rect)
	
	var current_x: float = margin_left
	var y_center: float = y_pos + height * 0.5
	
	# Dibujar icono
	if data.icon:
		var icon_rect = Rect2(
			Vector2(current_x, y_center - icon_size.y * 0.5),
			icon_size
		)
		stats_container.draw_texture_rect(data.icon, icon_rect, false)
		current_x += icon_size.x + spacing
	
	# Dibujar nombre de la estadística
	if data.name != "":
		var text_pos = Vector2(current_x, y_center + font_size * 0.3)
		stats_container.draw_string(font, text_pos, data.name, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, text_color)
		
		var text_width = font.get_string_size(data.name, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		current_x += text_width + spacing
	
	# Obtener valores actuales
	var current_value = 0
	var new_value = 0
	
	if data.key in current_stats:
		current_value = current_stats[data.key][0]
		new_value = current_stats[data.key][1]
	
	# Formatear valores
	var suffix = "%" if data.is_percent else ""
	var current_text = GameManager.get_number_formatted(current_value, 0, "", suffix) if GameManager else str(current_value) + suffix
	var new_text = GameManager.get_number_formatted(new_value, 0, "", suffix) if GameManager else str(new_value) + suffix
	
	# Calcular diferencia y texto de diferencia
	var difference = new_value - current_value
	var difference_text = ""
	if show_comparison and difference != 0:
		var s = "+" if difference > 0 else "-"
		var diff_value = GameManager.get_number_formatted(difference, 0, "", suffix) if GameManager else str(difference) + suffix
		difference_text = " (" + s + diff_value + ")"
	
	# Calcular ancho de valores
	var values_width = font.get_string_size(current_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	if show_comparison:
		values_width += font.get_string_size(arrow_symbol, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		values_width += font.get_string_size(new_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		# Añadir ancho del texto de diferencia si existe
		if difference_text != "":
			values_width += font.get_string_size(difference_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	
	# Posicionar valores (alineados a la derecha)
	var values_start_x = stats_container.size.x - margin_right - values_width
	if values_start_x < current_x:
		values_start_x = current_x
	
	# Dibujar valor actual
	var current_value_pos = Vector2(values_start_x, y_center + font_size * 0.3)
	stats_container.draw_string(font, current_value_pos, current_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, text_color)
	
	# Dibujar comparación si está habilitada
	if show_comparison:
		values_start_x += font.get_string_size(current_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		
		# Dibujar flecha
		var arrow_pos = Vector2(values_start_x, y_center + font_size * 0.3)
		stats_container.draw_string(font, arrow_pos, arrow_symbol, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, text_color)
		
		values_start_x += font.get_string_size(arrow_symbol, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		
		# Dibujar nuevo valor con color apropiado
		var new_value_color = _get_value_color(current_value, new_value)
		var new_value_pos = Vector2(values_start_x, y_center + font_size * 0.3)
		stats_container.draw_string(font, new_value_pos, new_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, new_value_color)
		
		# Dibujar diferencia si existe
		if difference_text != "":
			values_start_x += font.get_string_size(new_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
			var difference_pos = Vector2(values_start_x, y_center + font_size * 0.3)
			stats_container.draw_string(font, difference_pos, difference_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, new_value_color)


func _get_value_color(current: int, new: int) -> Color:
	if new > current:
		return increase_color
	elif new < current:
		return decrease_color
	else:
		return no_change_color


func _evaluate_equipment_comparison() -> void:
	if not current_actor or not show_comparison:
		_on_equipment_evaluation_result(-1)  # No comparison
		return
	
	# Obtener pesos para la clase actual
	var class_id = current_actor.current_class
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
	
	# Usar las estadísticas principales reales del sistema
	var main_stats = []
	if stats_structure.has("Main Stats"):
		main_stats = stats_structure["Main Stats"]
	
	# Si no hay stats principales, usar las primeras 8 de main_parameters
	if main_stats.is_empty() and RPGSYSTEM.database.types.main_parameters.size() >= 8:
		for i in range(0, min(8, RPGSYSTEM.database.types.main_parameters.size())):
			main_stats.append(RPGSYSTEM.database.types.main_parameters[i])
	
	var current_score = 0.0
	var new_score = 0.0
	var stats_found = 0
	
	# Verificar HP crítico - usar el primer stat como HP
	var hp_current = 0
	var hp_new = 0
	if main_stats.size() > 0 and main_stats[0] in current_stats:
		hp_current = current_stats[main_stats[0]][0]
		hp_new = current_stats[main_stats[0]][1]
	
	var hp_percentage = float(hp_new) / float(hp_current) if hp_current > 0 else 1.0
	var is_hp_critical = hp_percentage <= 0.1
	
	# Mapeo de nombres de stats a pesos
	var stat_name_mapping = {
		# Posibles variaciones de nombres
		0: "HP",    # Primera stat es HP
		1: "MP",    # Segunda stat es MP  
		2: "ATK",   # Tercera stat es ATK
		3: "DEF",   # etc...
		4: "MATK",
		5: "MDEF", 
		6: "AGI",
		7: "LUCK"
	}
	
	# Calcular puntuaciones
	for i in range(main_stats.size()):
		var stat_name = main_stats[i]
		if stat_name in current_stats:
			var current_value = current_stats[stat_name][0]
			var new_value = current_stats[stat_name][1]
			
			# Obtener peso usando el mapeo por índice
			var weight_key = stat_name_mapping.get(i, "HP")
			var weight = weights.get(weight_key, 1.0)
			
			var current_weighted = current_value * weight
			var new_weighted = new_value * weight
			
			# Penalización por HP crítico (solo para el primer stat)
			if i == 0 and is_hp_critical:
				var hp_difference = new_value - current_value
				var penalty_multiplier = 1.0 + (7.0 * (0.1 - hp_percentage) / 0.1)
				penalty_multiplier = min(penalty_multiplier, 8.0)
				var critical_penalty = abs(hp_difference) * penalty_multiplier
				new_weighted -= critical_penalty
			
			current_score += current_weighted
			new_score += new_weighted
			stats_found += 1
	
	# Si no se encontraron estadísticas, devolver -1
	if stats_found == 0:
		_on_equipment_evaluation_result(-1)
		return
	
	# Determinar resultado
	var score_difference = new_score - current_score
	var current_is_better = 0
	var tolerance = 2.0
	
	if is_hp_critical:
		current_is_better = 1  # Actual es mejor (HP crítico)
	elif abs(score_difference) <= tolerance:
		current_is_better = -1  # Igual
	elif score_difference > 0:
		current_is_better = 0   # Nuevo es mejor
	else:
		current_is_better = 1   # Actual es mejor
	
	_on_equipment_evaluation_result(current_is_better)


func _on_equipment_evaluation_result(result: int) -> void:
	# result: -1 = equal, 0 = new better, 1 = current better
	upgrade_icon.visible = result != -1
	if show_comparison:
		upgrade_icon.texture.region.position.x = 0 if result == 0 else upgrade_icon.texture.region.size.x
		comparison_result = result


func set_actor(actor: GameActor) -> void:
	if not actor:
		return
	
	current_actor = actor
	current_stats.clear()
	
	var copy_actor: GameActor = actor.duplicate_deep(Resource.DEEP_DUPLICATE_NONE)
	if comparison_item:
		if comparison_item.id != -1:
			copy_actor._set_equip(comparison_item.slot_id, comparison_item.id, comparison_item.level)
		else:
			copy_actor._set_equip(comparison_item.slot_id, -1, 0)
	
	# Cargar estadísticas principales y secundarias
	for section_name in stats_structure:
		for i in stats_structure[section_name].size():
			var stat = stats_structure[section_name][i]
			var real_stat = stat.replace(" ", "_")
			if section_name != "Secondary Stats":
				var value1 = actor.get_parameter(real_stat)
				var value2 = copy_actor.get_parameter(real_stat)
				current_stats[stat] = [value1, value2]
			else:
				var value1 = actor.get_user_parameter(i)
				var value2 = copy_actor.get_user_parameter(i)
				current_stats[stat] = [value1, value2]
	
	# Cargar estadísticas de elementos
	if RPGSYSTEM and RPGSYSTEM.database and RPGSYSTEM.database.types:
		var elements = RPGSYSTEM.database.types.element_types
		for element in elements:
			var attack_rate_value = actor.get_element_attack_rate(element)
			var defense_rate_value = actor.get_element_defense_rate(element)
			var copy_attack_rate_value = copy_actor.get_element_attack_rate(element)
			var copy_defense_rate_value = copy_actor.get_element_defense_rate(element)
			current_stats[element + "_0"] = [attack_rate_value, copy_attack_rate_value]
			current_stats[element + "_1"] = [defense_rate_value, copy_defense_rate_value]
	
	# Evaluar comparación de equipo
	_evaluate_equipment_comparison()
	
	stats_container.queue_redraw()


func set_equipment_compararison(slot_id: int, item: Variant) -> void:
	if current_actor:
		comparison_item = {
			"slot_id": slot_id,
			"id": item.id if item else -1,
			"level": item.current_level if item else -1,
		} 
		set_actor(current_actor)


func update_stat_value(stat_key: String, new_value: int) -> void:
	if stat_key in current_stats:
		current_stats[stat_key][1] = new_value
		_evaluate_equipment_comparison()
		stats_container.queue_redraw()


func reset_all_comparisons() -> void:
	for stat_key in current_stats:
		current_stats[stat_key][1] = current_stats[stat_key][0]
	_evaluate_equipment_comparison()
	stats_container.queue_redraw()


func set_show_comparison(_show_comparison: bool) -> void:
	var last_show_comparison = show_comparison
	show_comparison = _show_comparison
	if not is_inside_tree(): return
	if show_comparison != last_show_comparison:
		_calculate_minimum_size()
		_evaluate_equipment_comparison()
		stats_container.queue_redraw()
	if not show_comparison:
		upgrade_icon.visible = false


func get_minimum_size() -> Vector2:
	return stats_container.custom_minimum_size
