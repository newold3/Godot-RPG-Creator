@tool
extends CodeEdit
class_name IntelligentCodeEdit

@export var color_dialog: CustomColorDialog


var _autoloads_cache: Dictionary = {}
var _current_script_cache: Dictionary = {}
var _last_analysis_text: String = ""
var _script_members_cache: Dictionary = {}
var _array_element_types: Dictionary = {} # Cache para tipos de elementos de arrays
var _builtin_classes_cache: Dictionary = {} # Cache para clases integradas
var auto_fill_enabled: bool = false

signal completion_applied(suggestion: String)

func _ready():
	code_completion_enabled = true
	code_completion_requested.connect(_on_code_completion_requested)
	text_changed.connect(_on_text_changed)
	caret_changed.connect(_on_caret_changed)
	setup_syntax_highlighting()
	setup_builtin_classes_from_classdb()
	call_deferred("refresh_autoloads")


func _draw() -> void:
	var regex := RegEx.new()
	regex.compile(r"Color(?:\s*\([^)]*\)|\.[A-Z_]+)?")

	var line_count := get_line_count()
	var line_h := 8

	for line in range(line_count):
		var line_text := get_line(line)
		for result in regex.search_all(line_text):
			var color_text := result.get_string()

			var color := _parse_color_from_text(color_text)
			if color == null:
				continue

			var start_col := result.get_start()

			var a = get_rect_at_line_column(line, start_col)

			# calcular X de inicio y fin
			var start_x = a.position.x + 8 if start_col != 0 else 4

			# posición Y justo debajo de la línea de texto
			var base_y = a.position.y - get_v_scroll() + 2

			# dibujar línea horizontal del color
			draw_rect(Rect2(start_x, base_y, 8, line_h), color)
			draw_rect(Rect2(start_x, base_y, 8, line_h), Color.BLACK, false, 1)



func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.is_pressed() and event.is_alt_pressed():
		if event.keycode == KEY_UP:
			move_lines_up()
		elif event.keycode == KEY_DOWN:
			move_lines_down()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var pos = get_line_column_at_pos(event.position)
		if pos.x >= 0 and pos.y >= 0:
			var line_text = get_line(pos.y)
			var word = get_word_at_pos(event.position)
			if word == "Color":
				mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			else:
				mouse_default_cursor_shape = Control.CURSOR_IBEAM
	
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
		var pos = get_line_column_at_pos(event.position)
		if pos.x >= 0 and pos.y >= 0:
			var word = get_word_at_pos(event.position)
			if word != "Color": return
			var line_text = get_line(pos.y)
			var regex := RegEx.new()
			# Detecta Color(), Color(...), Color.CONSTANT
			regex.compile(r"Color(?:\s*\([^)]*\)|\.[A-Z_]+)?")

			# Recolectar todos los matches y elegir el correcto según la columna
			var matches = regex.search_all(line_text)
			var chosen_match = null

			# 1) Preferir el match que contenga exactamente la columna pos.x
			for m in matches:
				if m.get_start() <= pos.x and pos.x <= m.get_end():
					chosen_match = m
					break

			if chosen_match:
				var color_text = chosen_match.get_string()
				var color = _parse_color_from_text(color_text)
				if color:
					# No hacemos selección visual aquí (tu requerimiento anterior),
					# pero pasamos start/end para que el picker reemplace el correcto.
					_open_color_picker(color, pos.y, chosen_match.get_start(), chosen_match.get_end(), line_text)


func _is_color_expression_at(line_text: String, column: int, word: String) -> bool:
	if word == "Color":
		var regex := RegEx.new()
		regex.compile(r"Color\s*\([^)]*\)")
		for result in regex.search_all(line_text):
			if result.get_start() <= column and result.get_start() <= result.get_end():
				return true
	return false

func _parse_color_from_text(text: String) -> Color:
	# Caso Color(r,g,b,a)
	var regex := RegEx.new()
	regex.compile(r"Color\s*\(\s*([0-9\.]+)?\s*,?\s*([0-9\.]+)?\s*,?\s*([0-9\.]+)?(?:\s*,\s*([0-9\.]+))?\s*\)")
	var match = regex.search(text)
	if match:
		var r = float(match.get_string(1)) if match.get_string(1) != "" else 1.0
		var g = float(match.get_string(2)) if match.get_string(2) != "" else 1.0
		var b = float(match.get_string(3)) if match.get_string(3) != "" else 1.0
		var a = float(match.get_string(4)) if match.get_string(4) != "" else 1.0
		return Color(r, g, b, a)
	
	# Caso Color.NAME (constantes)
	if text.begins_with("Color.") and text.length() > 6:
		var cname = text.substr(6, text.length() - 6)
		return Color.from_string(cname, Color.WHITE)
	
	# Caso Color() vacío → blanco
	if text.strip_edges() == "Color()":
		return Color(1, 1, 1, 1)
	
	return Color.WHITE

func get_word_at_pos(pos: Vector2) -> String:
	return get_word_at_pos(pos)

func _open_color_picker(initial_color: Color, line: int, start: int, end: int, original_color_text: String):
	if color_dialog:
		var picker := color_dialog
		picker.title = "Selecciona un color"
		picker.set_color(initial_color)
		picker.connect("color_selected", Callable(self, "_on_color_chosen").bind(line, start, end, original_color_text), CONNECT_ONE_SHOT)
		picker.popup_centered()

func _on_color_chosen(color: Color, line: int, start: int, end: int, original_color_text: String):
	var old_color = _parse_color_from_text(original_color_text)
	if old_color == color:
		deselect()
		return
	
	var new_text = "Color(%s, %s, %s, %s)" % [
		_format_component(color.r),
		_format_component(color.g),
		_format_component(color.b),
		_format_component(color.a)
	]

	var line_text = get_line(line)
	var updated = line_text.substr(0, start) + new_text + line_text.substr(end, line_text.length())
	set_line(line, updated)

	# Colocar el cursor justo después del nuevo Color(...)
	set_caret_line(line)
	set_caret_column(start + new_text.length())
	deselect()

func _format_component(value: float) -> String:
	# Si es entero (ejemplo 1.0 → 1), mostramos como entero
	if is_equal_approx(value, round(value)):
		return "%.1f" % value
	# Si no, lo mostramos con precisión flotante razonable
	return "%.3f" % value



func setup_syntax_highlighting():
	var highlighter = preload("uid://c7mbnjy7jf0hv")
	var keywords = ["func", "var", "const", "if", "else", "elif", "for", "while", "match", "class", "extends", "signal", "enum", "return", "break", "continue", "pass", "and", "or", "not", "in", "is", "as", "await"]
	for keyword in keywords:
		highlighter.add_keyword_color(keyword, Color(1.0, 0.4, 0.4))
	var types = ["int", "float", "String", "bool", "Array", "Dictionary", "Vector2", "Vector3", "Color", "Node", "PackedScene"]
	for type in types:
		highlighter.add_keyword_color(type, Color(0.4, 0.8, 1.0))
	syntax_highlighter = highlighter

func setup_builtin_classes_from_classdb():
	"""Configura el cache de clases integradas usando ClassDB y información del engine"""
	
	# Lista de clases builtin importantes para autocompletar
	var important_classes = [
		"Array", "Dictionary", "String", "Vector2", "Vector3", "Vector4",
		"Color", "Transform2D", "Transform3D", "Basis", "Quaternion",
		"Rect2", "Rect2i", "AABB", "Plane", "PackedStringArray",
		"PackedInt32Array", "PackedFloat32Array", "PackedVector2Array",
		"PackedVector3Array", "PackedColorArray", "Node", "Node2D", "Node3D",
		"Control", "CanvasItem", "Resource", "RefCounted"
	]
	
	for _class_name in important_classes:
		_builtin_classes_cache[_class_name] = get_class_members_from_classdb(_class_name)

func get_class_members_from_classdb(_class_name: String) -> Array:
	"""Obtiene los miembros de una clase usando ClassDB"""
	var members = []
	
	# Si la clase existe en ClassDB, obtenemos sus métodos y propiedades
	if ClassDB.class_exists(_class_name):
		# Obtener métodos
		var methods = ClassDB.class_get_method_list(_class_name, true)
		for method in methods:
			# Filtrar métodos internos (que empiezan con _)
			if not method.name.begins_with("_"):
				members.append({
					"name": method.name,
					"kind": CodeEdit.KIND_FUNCTION,
					"type": "function",
					"description": "Method from " + _class_name
				})
		
		# Obtener propiedades
		var properties = ClassDB.class_get_property_list(_class_name, true)
		for property in properties:
			# Filtrar propiedades internas y de script
			if not property.name.begins_with("_") and property.usage & PROPERTY_USAGE_EDITOR:
				members.append({
					"name": property.name,
					"kind": CodeEdit.KIND_MEMBER,
					"type": "property",
					"description": "Property from " + _class_name
				})
		
		# Obtener constantes/enums
		var constants = ClassDB.class_get_integer_constant_list(_class_name, true)
		for constant in constants:
			members.append({
				"name": constant,
				"kind": CodeEdit.KIND_CONSTANT,
				"type": "constant",
				"description": "Constant from " + _class_name
			})
	
	# Para algunos tipos builtin especiales, agregamos miembros adicionales manualmente
	# ya que ClassDB no siempre los expone correctamente
	match _class_name:
		"Array":
			members.append_array(get_array_builtin_methods())
		"Dictionary":
			members.append_array(get_dictionary_builtin_methods())
		"String":
			members.append_array(get_string_builtin_methods())
		"Vector2":
			members.append_array(get_vector2_builtin_methods())
		"Vector3":
			members.append_array(get_vector3_builtin_methods())
		"Color":
			members.append_array(get_color_builtin_methods())
			# Agregar constantes de color comunes
			members.append_array(get_color_constants())
	
	return members

func get_array_builtin_methods() -> Array:
	"""Métodos específicos de Array que pueden no estar en ClassDB"""
	return [
		{"name": "size", "kind": CodeEdit.KIND_FUNCTION, "type": "function"},
		{"name": "is_empty", "kind": CodeEdit.KIND_FUNCTION, "type": "function"},
		{"name": "clear", "kind": CodeEdit.KIND_FUNCTION, "type": "function"},
		{"name": "append", "kind": CodeEdit.KIND_FUNCTION, "type": "function"},
		{"name": "push_back", "kind": CodeEdit.KIND_FUNCTION, "type": "function"},
		{"name": "push_front", "kind": CodeEdit.KIND_FUNCTION, "type": "function"},
		{"name": "pop_back", "kind": CodeEdit.KIND_FUNCTION, "type": "function"},
		{"name": "pop_front", "kind": CodeEdit.KIND_FUNCTION, "type": "function"},
		{"name": "find", "kind": CodeEdit.KIND_FUNCTION, "type": "function"},
		{"name": "has", "kind": CodeEdit.KIND_FUNCTION, "type": "function"},
		{"name": "erase", "kind": CodeEdit.KIND_FUNCTION, "type": "function"},
		{"name": "remove_at", "kind": CodeEdit.KIND_FUNCTION, "type": "function"},
		{"name": "insert", "kind": CodeEdit.KIND_FUNCTION, "type": "function"},
		{"name": "sort", "kind": CodeEdit.KIND_FUNCTION, "type": "function"},
		{"name": "reverse", "kind": CodeEdit.KIND_FUNCTION, "type": "function"},
		{"name": "duplicate", "kind": CodeEdit.KIND_FUNCTION, "type": "function"},
		{"name": "slice", "kind": CodeEdit.KIND_FUNCTION, "type": "function"},
		{"name": "filter", "kind": CodeEdit.KIND_FUNCTION, "type": "function"},
		{"name": "map", "kind": CodeEdit.KIND_FUNCTION, "type": "function"},
		{"name": "reduce", "kind": CodeEdit.KIND_FUNCTION, "type": "function"}
	]

func get_dictionary_builtin_methods() -> Array:
	return [
		{"name": "size", "kind": CodeEdit.KIND_FUNCTION, "type": "function"},
		{"name": "is_empty", "kind": CodeEdit.KIND_FUNCTION, "type": "function"},
		{"name": "clear", "kind": CodeEdit.KIND_FUNCTION, "type": "function"},
		{"name": "has", "kind": CodeEdit.KIND_FUNCTION, "type": "function"},
		{"name": "has_all", "kind": CodeEdit.KIND_FUNCTION, "type": "function"},
		{"name": "keys", "kind": CodeEdit.KIND_FUNCTION, "type": "function"},
		{"name": "values", "kind": CodeEdit.KIND_FUNCTION, "type": "function"},
		{"name": "erase", "kind": CodeEdit.KIND_FUNCTION, "type": "function"},
		{"name": "get", "kind": CodeEdit.KIND_FUNCTION, "type": "function"},
		{"name": "merge", "kind": CodeEdit.KIND_FUNCTION, "type": "function"},
		{"name": "duplicate", "kind": CodeEdit.KIND_FUNCTION, "type": "function"}
	]

func get_string_builtin_methods() -> Array:
	return [
		{"name": "length", "kind": CodeEdit.KIND_FUNCTION, "type": "function"},
		{"name": "is_empty", "kind": CodeEdit.KIND_FUNCTION, "type": "function"},
		{"name": "substr", "kind": CodeEdit.KIND_FUNCTION, "type": "function"},
		{"name": "find", "kind": CodeEdit.KIND_FUNCTION, "type": "function"},
		{"name": "replace", "kind": CodeEdit.KIND_FUNCTION, "type": "function"},
		{"name": "split", "kind": CodeEdit.KIND_FUNCTION, "type": "function"},
		{"name": "strip_edges", "kind": CodeEdit.KIND_FUNCTION, "type": "function"},
		{"name": "to_lower", "kind": CodeEdit.KIND_FUNCTION, "type": "function"},
		{"name": "to_upper", "kind": CodeEdit.KIND_FUNCTION, "type": "function"},
		{"name": "begins_with", "kind": CodeEdit.KIND_FUNCTION, "type": "function"},
		{"name": "ends_with", "kind": CodeEdit.KIND_FUNCTION, "type": "function"},
		{"name": "contains", "kind": CodeEdit.KIND_FUNCTION, "type": "function"},
		{"name": "to_int", "kind": CodeEdit.KIND_FUNCTION, "type": "function"},
		{"name": "to_float", "kind": CodeEdit.KIND_FUNCTION, "type": "function"},
		{"name": "get_slice", "kind": CodeEdit.KIND_FUNCTION, "type": "function"}
	]

func get_vector2_builtin_methods() -> Array:
	return [
		{"name": "x", "kind": CodeEdit.KIND_MEMBER, "type": "property"},
		{"name": "y", "kind": CodeEdit.KIND_MEMBER, "type": "property"},
		{"name": "length", "kind": CodeEdit.KIND_FUNCTION, "type": "function"},
		{"name": "length_squared", "kind": CodeEdit.KIND_FUNCTION, "type": "function"},
		{"name": "normalized", "kind": CodeEdit.KIND_FUNCTION, "type": "function"},
		{"name": "distance_to", "kind": CodeEdit.KIND_FUNCTION, "type": "function"},
		{"name": "dot", "kind": CodeEdit.KIND_FUNCTION, "type": "function"},
		{"name": "cross", "kind": CodeEdit.KIND_FUNCTION, "type": "function"},
		{"name": "rotated", "kind": CodeEdit.KIND_FUNCTION, "type": "function"},
		{"name": "angle", "kind": CodeEdit.KIND_FUNCTION, "type": "function"},
		{"name": "angle_to", "kind": CodeEdit.KIND_FUNCTION, "type": "function"},
		{"name": "lerp", "kind": CodeEdit.KIND_FUNCTION, "type": "function"},
		{"name": "abs", "kind": CodeEdit.KIND_FUNCTION, "type": "function"},
		{"name": "floor", "kind": CodeEdit.KIND_FUNCTION, "type": "function"},
		{"name": "ceil", "kind": CodeEdit.KIND_FUNCTION, "type": "function"}
	]

func get_vector3_builtin_methods() -> Array:
	return [
		{"name": "x", "kind": CodeEdit.KIND_MEMBER, "type": "property"},
		{"name": "y", "kind": CodeEdit.KIND_MEMBER, "type": "property"},
		{"name": "z", "kind": CodeEdit.KIND_MEMBER, "type": "property"},
		{"name": "length", "kind": CodeEdit.KIND_FUNCTION, "type": "function"},
		{"name": "length_squared", "kind": CodeEdit.KIND_FUNCTION, "type": "function"},
		{"name": "normalized", "kind": CodeEdit.KIND_FUNCTION, "type": "function"},
		{"name": "distance_to", "kind": CodeEdit.KIND_FUNCTION, "type": "function"},
		{"name": "dot", "kind": CodeEdit.KIND_FUNCTION, "type": "function"},
		{"name": "cross", "kind": CodeEdit.KIND_FUNCTION, "type": "function"},
		{"name": "rotated", "kind": CodeEdit.KIND_FUNCTION, "type": "function"},
		{"name": "lerp", "kind": CodeEdit.KIND_FUNCTION, "type": "function"},
		{"name": "abs", "kind": CodeEdit.KIND_FUNCTION, "type": "function"},
		{"name": "floor", "kind": CodeEdit.KIND_FUNCTION, "type": "function"},
		{"name": "ceil", "kind": CodeEdit.KIND_FUNCTION, "type": "function"}
	]

func get_color_builtin_methods() -> Array:
	return [
		{"name": "r", "kind": CodeEdit.KIND_MEMBER, "type": "property"},
		{"name": "g", "kind": CodeEdit.KIND_MEMBER, "type": "property"},
		{"name": "b", "kind": CodeEdit.KIND_MEMBER, "type": "property"},
		{"name": "a", "kind": CodeEdit.KIND_MEMBER, "type": "property"},
		{"name": "h", "kind": CodeEdit.KIND_MEMBER, "type": "property"},
		{"name": "s", "kind": CodeEdit.KIND_MEMBER, "type": "property"},
		{"name": "v", "kind": CodeEdit.KIND_MEMBER, "type": "property"},
		{"name": "darkened", "kind": CodeEdit.KIND_FUNCTION, "type": "function"},
		{"name": "lightened", "kind": CodeEdit.KIND_FUNCTION, "type": "function"},
		{"name": "inverted", "kind": CodeEdit.KIND_FUNCTION, "type": "function"},
		{"name": "lerp", "kind": CodeEdit.KIND_FUNCTION, "type": "function"},
		{"name": "blend", "kind": CodeEdit.KIND_FUNCTION, "type": "function"},
		{"name": "to_html", "kind": CodeEdit.KIND_FUNCTION, "type": "function"},
		{"name": "contrasted", "kind": CodeEdit.KIND_FUNCTION, "type": "function"}
	]

func get_color_constants() -> Array:
	"""Obtiene las constantes de color predefinidas"""
	return [
		{"name": "RED", "kind": CodeEdit.KIND_CONSTANT, "type": "constant"},
		{"name": "GREEN", "kind": CodeEdit.KIND_CONSTANT, "type": "constant"},
		{"name": "BLUE", "kind": CodeEdit.KIND_CONSTANT, "type": "constant"},
		{"name": "WHITE", "kind": CodeEdit.KIND_CONSTANT, "type": "constant"},
		{"name": "BLACK", "kind": CodeEdit.KIND_CONSTANT, "type": "constant"},
		{"name": "YELLOW", "kind": CodeEdit.KIND_CONSTANT, "type": "constant"},
		{"name": "CYAN", "kind": CodeEdit.KIND_CONSTANT, "type": "constant"},
		{"name": "MAGENTA", "kind": CodeEdit.KIND_CONSTANT, "type": "constant"},
		{"name": "TRANSPARENT", "kind": CodeEdit.KIND_CONSTANT, "type": "constant"},
		{"name": "ALICE_BLUE", "kind": CodeEdit.KIND_CONSTANT, "type": "constant"},
		{"name": "ANTIQUE_WHITE", "kind": CodeEdit.KIND_CONSTANT, "type": "constant"},
		{"name": "AQUA", "kind": CodeEdit.KIND_CONSTANT, "type": "constant"},
		{"name": "AQUAMARINE", "kind": CodeEdit.KIND_CONSTANT, "type": "constant"},
		{"name": "AZURE", "kind": CodeEdit.KIND_CONSTANT, "type": "constant"},
		{"name": "BEIGE", "kind": CodeEdit.KIND_CONSTANT, "type": "constant"},
		{"name": "BISQUE", "kind": CodeEdit.KIND_CONSTANT, "type": "constant"},
		{"name": "BLANCHED_ALMOND", "kind": CodeEdit.KIND_CONSTANT, "type": "constant"},
		{"name": "BLUE_VIOLET", "kind": CodeEdit.KIND_CONSTANT, "type": "constant"},
		{"name": "BROWN", "kind": CodeEdit.KIND_CONSTANT, "type": "constant"},
		{"name": "BURLYWOOD", "kind": CodeEdit.KIND_CONSTANT, "type": "constant"},
		{"name": "CADET_BLUE", "kind": CodeEdit.KIND_CONSTANT, "type": "constant"},
		{"name": "CHARTREUSE", "kind": CodeEdit.KIND_CONSTANT, "type": "constant"},
		{"name": "CHOCOLATE", "kind": CodeEdit.KIND_CONSTANT, "type": "constant"},
		{"name": "CORAL", "kind": CodeEdit.KIND_CONSTANT, "type": "constant"},
		{"name": "CORNFLOWER_BLUE", "kind": CodeEdit.KIND_CONSTANT, "type": "constant"},
		{"name": "CORNSILK", "kind": CodeEdit.KIND_CONSTANT, "type": "constant"},
		{"name": "CRIMSON", "kind": CodeEdit.KIND_CONSTANT, "type": "constant"},
		{"name": "DARK_BLUE", "kind": CodeEdit.KIND_CONSTANT, "type": "constant"},
		{"name": "DARK_CYAN", "kind": CodeEdit.KIND_CONSTANT, "type": "constant"},
		{"name": "DARK_GOLDENROD", "kind": CodeEdit.KIND_CONSTANT, "type": "constant"},
		{"name": "DARK_GRAY", "kind": CodeEdit.KIND_CONSTANT, "type": "constant"},
		{"name": "DARK_GREEN", "kind": CodeEdit.KIND_CONSTANT, "type": "constant"},
		{"name": "DARK_KHAKI", "kind": CodeEdit.KIND_CONSTANT, "type": "constant"},
		{"name": "DARK_MAGENTA", "kind": CodeEdit.KIND_CONSTANT, "type": "constant"},
		{"name": "DARK_OLIVE_GREEN", "kind": CodeEdit.KIND_CONSTANT, "type": "constant"},
		{"name": "DARK_ORANGE", "kind": CodeEdit.KIND_CONSTANT, "type": "constant"},
		{"name": "DARK_ORCHID", "kind": CodeEdit.KIND_CONSTANT, "type": "constant"},
		{"name": "DARK_RED", "kind": CodeEdit.KIND_CONSTANT, "type": "constant"},
		{"name": "DARK_SALMON", "kind": CodeEdit.KIND_CONSTANT, "type": "constant"},
		{"name": "DARK_SEA_GREEN", "kind": CodeEdit.KIND_CONSTANT, "type": "constant"},
		{"name": "DARK_SLATE_BLUE", "kind": CodeEdit.KIND_CONSTANT, "type": "constant"},
		{"name": "DARK_SLATE_GRAY", "kind": CodeEdit.KIND_CONSTANT, "type": "constant"},
		{"name": "DARK_TURQUOISE", "kind": CodeEdit.KIND_CONSTANT, "type": "constant"},
		{"name": "DARK_VIOLET", "kind": CodeEdit.KIND_CONSTANT, "type": "constant"},
		{"name": "DEEP_PINK", "kind": CodeEdit.KIND_CONSTANT, "type": "constant"},
		{"name": "DEEP_SKY_BLUE", "kind": CodeEdit.KIND_CONSTANT, "type": "constant"},
		{"name": "DIM_GRAY", "kind": CodeEdit.KIND_CONSTANT, "type": "constant"},
		{"name": "DODGER_BLUE", "kind": CodeEdit.KIND_CONSTANT, "type": "constant"},
		{"name": "FIREBRICK", "kind": CodeEdit.KIND_CONSTANT, "type": "constant"},
		{"name": "FLORAL_WHITE", "kind": CodeEdit.KIND_CONSTANT, "type": "constant"},
		{"name": "FOREST_GREEN", "kind": CodeEdit.KIND_CONSTANT, "type": "constant"},
		{"name": "FUCHSIA", "kind": CodeEdit.KIND_CONSTANT, "type": "constant"},
		{"name": "GAINSBORO", "kind": CodeEdit.KIND_CONSTANT, "type": "constant"},
		{"name": "GHOST_WHITE", "kind": CodeEdit.KIND_CONSTANT, "type": "constant"},
		{"name": "GOLD", "kind": CodeEdit.KIND_CONSTANT, "type": "constant"},
		{"name": "GOLDENROD", "kind": CodeEdit.KIND_CONSTANT, "type": "constant"},
		{"name": "GRAY", "kind": CodeEdit.KIND_CONSTANT, "type": "constant"},
		{"name": "GREEN_YELLOW", "kind": CodeEdit.KIND_CONSTANT, "type": "constant"},
		{"name": "HONEYDEW", "kind": CodeEdit.KIND_CONSTANT, "type": "constant"},
		{"name": "HOT_PINK", "kind": CodeEdit.KIND_CONSTANT, "type": "constant"},
		{"name": "INDIAN_RED", "kind": CodeEdit.KIND_CONSTANT, "type": "constant"},
		{"name": "INDIGO", "kind": CodeEdit.KIND_CONSTANT, "type": "constant"},
		{"name": "IVORY", "kind": CodeEdit.KIND_CONSTANT, "type": "constant"},
		{"name": "KHAKI", "kind": CodeEdit.KIND_CONSTANT, "type": "constant"},
		{"name": "LAVENDER", "kind": CodeEdit.KIND_CONSTANT, "type": "constant"},
		{"name": "LAVENDER_BLUSH", "kind": CodeEdit.KIND_CONSTANT, "type": "constant"},
		{"name": "LAWN_GREEN", "kind": CodeEdit.KIND_CONSTANT, "type": "constant"},
		{"name": "LEMON_CHIFFON", "kind": CodeEdit.KIND_CONSTANT, "type": "constant"},
		{"name": "LIGHT_BLUE", "kind": CodeEdit.KIND_CONSTANT, "type": "constant"},
		{"name": "LIGHT_CORAL", "kind": CodeEdit.KIND_CONSTANT, "type": "constant"},
		{"name": "LIGHT_CYAN", "kind": CodeEdit.KIND_CONSTANT, "type": "constant"},
		{"name": "LIGHT_GOLDENROD", "kind": CodeEdit.KIND_CONSTANT, "type": "constant"},
		{"name": "LIGHT_GRAY", "kind": CodeEdit.KIND_CONSTANT, "type": "constant"},
		{"name": "LIGHT_GREEN", "kind": CodeEdit.KIND_CONSTANT, "type": "constant"},
		{"name": "LIGHT_PINK", "kind": CodeEdit.KIND_CONSTANT, "type": "constant"},
		{"name": "LIGHT_SALMON", "kind": CodeEdit.KIND_CONSTANT, "type": "constant"},
		{"name": "LIGHT_SEA_GREEN", "kind": CodeEdit.KIND_CONSTANT, "type": "constant"},
		{"name": "LIGHT_SKY_BLUE", "kind": CodeEdit.KIND_CONSTANT, "type": "constant"},
		{"name": "LIGHT_SLATE_GRAY", "kind": CodeEdit.KIND_CONSTANT, "type": "constant"},
		{"name": "LIGHT_STEEL_BLUE", "kind": CodeEdit.KIND_CONSTANT, "type": "constant"},
		{"name": "LIGHT_YELLOW", "kind": CodeEdit.KIND_CONSTANT, "type": "constant"},
		{"name": "LIME", "kind": CodeEdit.KIND_CONSTANT, "type": "constant"},
		{"name": "LIME_GREEN", "kind": CodeEdit.KIND_CONSTANT, "type": "constant"},
		{"name": "LINEN", "kind": CodeEdit.KIND_CONSTANT, "type": "constant"},
		{"name": "MAROON", "kind": CodeEdit.KIND_CONSTANT, "type": "constant"},
		{"name": "MEDIUM_AQUAMARINE", "kind": CodeEdit.KIND_CONSTANT, "type": "constant"},
		{"name": "MEDIUM_BLUE", "kind": CodeEdit.KIND_CONSTANT, "type": "constant"},
		{"name": "MEDIUM_ORCHID", "kind": CodeEdit.KIND_CONSTANT, "type": "constant"},
		{"name": "MEDIUM_PURPLE", "kind": CodeEdit.KIND_CONSTANT, "type": "constant"},
		{"name": "MEDIUM_SEA_GREEN", "kind": CodeEdit.KIND_CONSTANT, "type": "constant"},
		{"name": "MEDIUM_SLATE_BLUE", "kind": CodeEdit.KIND_CONSTANT, "type": "constant"},
		{"name": "MEDIUM_SPRING_GREEN", "kind": CodeEdit.KIND_CONSTANT, "type": "constant"},
		{"name": "MEDIUM_TURQUOISE", "kind": CodeEdit.KIND_CONSTANT, "type": "constant"},
		{"name": "MEDIUM_VIOLET_RED", "kind": CodeEdit.KIND_CONSTANT, "type": "constant"},
		{"name": "MIDNIGHT_BLUE", "kind": CodeEdit.KIND_CONSTANT, "type": "constant"},
		{"name": "MINT_CREAM", "kind": CodeEdit.KIND_CONSTANT, "type": "constant"},
		{"name": "MISTY_ROSE", "kind": CodeEdit.KIND_CONSTANT, "type": "constant"},
		{"name": "MOCCASIN", "kind": CodeEdit.KIND_CONSTANT, "type": "constant"},
		{"name": "NAVAJO_WHITE", "kind": CodeEdit.KIND_CONSTANT, "type": "constant"},
		{"name": "NAVY_BLUE", "kind": CodeEdit.KIND_CONSTANT, "type": "constant"},
		{"name": "OLD_LACE", "kind": CodeEdit.KIND_CONSTANT, "type": "constant"},
		{"name": "OLIVE", "kind": CodeEdit.KIND_CONSTANT, "type": "constant"},
		{"name": "OLIVE_DRAB", "kind": CodeEdit.KIND_CONSTANT, "type": "constant"},
		{"name": "ORANGE", "kind": CodeEdit.KIND_CONSTANT, "type": "constant"},
		{"name": "ORANGE_RED", "kind": CodeEdit.KIND_CONSTANT, "type": "constant"},
		{"name": "ORCHID", "kind": CodeEdit.KIND_CONSTANT, "type": "constant"},
		{"name": "PALE_GOLDENROD", "kind": CodeEdit.KIND_CONSTANT, "type": "constant"},
		{"name": "PALE_GREEN", "kind": CodeEdit.KIND_CONSTANT, "type": "constant"},
		{"name": "PALE_TURQUOISE", "kind": CodeEdit.KIND_CONSTANT, "type": "constant"},
		{"name": "PALE_VIOLET_RED", "kind": CodeEdit.KIND_CONSTANT, "type": "constant"},
		{"name": "PAPAYA_WHIP", "kind": CodeEdit.KIND_CONSTANT, "type": "constant"},
		{"name": "PEACH_PUFF", "kind": CodeEdit.KIND_CONSTANT, "type": "constant"},
		{"name": "PERU", "kind": CodeEdit.KIND_CONSTANT, "type": "constant"},
		{"name": "PINK", "kind": CodeEdit.KIND_CONSTANT, "type": "constant"},
		{"name": "PLUM", "kind": CodeEdit.KIND_CONSTANT, "type": "constant"},
		{"name": "POWDER_BLUE", "kind": CodeEdit.KIND_CONSTANT, "type": "constant"},
		{"name": "PURPLE", "kind": CodeEdit.KIND_CONSTANT, "type": "constant"},
		{"name": "REBECCA_PURPLE", "kind": CodeEdit.KIND_CONSTANT, "type": "constant"},
		{"name": "ROSY_BROWN", "kind": CodeEdit.KIND_CONSTANT, "type": "constant"},
		{"name": "ROYAL_BLUE", "kind": CodeEdit.KIND_CONSTANT, "type": "constant"},
		{"name": "SADDLE_BROWN", "kind": CodeEdit.KIND_CONSTANT, "type": "constant"},
		{"name": "SALMON", "kind": CodeEdit.KIND_CONSTANT, "type": "constant"},
		{"name": "SANDY_BROWN", "kind": CodeEdit.KIND_CONSTANT, "type": "constant"},
		{"name": "SEA_GREEN", "kind": CodeEdit.KIND_CONSTANT, "type": "constant"},
		{"name": "SEASHELL", "kind": CodeEdit.KIND_CONSTANT, "type": "constant"},
		{"name": "SIENNA", "kind": CodeEdit.KIND_CONSTANT, "type": "constant"},
		{"name": "SILVER", "kind": CodeEdit.KIND_CONSTANT, "type": "constant"},
		{"name": "SKY_BLUE", "kind": CodeEdit.KIND_CONSTANT, "type": "constant"},
		{"name": "SLATE_BLUE", "kind": CodeEdit.KIND_CONSTANT, "type": "constant"},
		{"name": "SLATE_GRAY", "kind": CodeEdit.KIND_CONSTANT, "type": "constant"},
		{"name": "SNOW", "kind": CodeEdit.KIND_CONSTANT, "type": "constant"},
		{"name": "SPRING_GREEN", "kind": CodeEdit.KIND_CONSTANT, "type": "constant"},
		{"name": "STEEL_BLUE", "kind": CodeEdit.KIND_CONSTANT, "type": "constant"},
		{"name": "TAN", "kind": CodeEdit.KIND_CONSTANT, "type": "constant"},
		{"name": "TEAL", "kind": CodeEdit.KIND_CONSTANT, "type": "constant"},
		{"name": "THISTLE", "kind": CodeEdit.KIND_CONSTANT, "type": "constant"},
		{"name": "TOMATO", "kind": CodeEdit.KIND_CONSTANT, "type": "constant"},
		{"name": "TURQUOISE", "kind": CodeEdit.KIND_CONSTANT, "type": "constant"},
		{"name": "VIOLET", "kind": CodeEdit.KIND_CONSTANT, "type": "constant"},
		{"name": "WEB_GRAY", "kind": CodeEdit.KIND_CONSTANT, "type": "constant"},
		{"name": "WEB_GREEN", "kind": CodeEdit.KIND_CONSTANT, "type": "constant"},
		{"name": "WEB_MAROON", "kind": CodeEdit.KIND_CONSTANT, "type": "constant"},
		{"name": "WEB_PURPLE", "kind": CodeEdit.KIND_CONSTANT, "type": "constant"},
		{"name": "WHEAT", "kind": CodeEdit.KIND_CONSTANT, "type": "constant"},
		{"name": "WHITE_SMOKE", "kind": CodeEdit.KIND_CONSTANT, "type": "constant"},
		{"name": "YELLOW_GREEN", "kind": CodeEdit.KIND_CONSTANT, "type": "constant"}
	]

func refresh_autoloads():
	_autoloads_cache.clear()
	_script_members_cache.clear()
	for setting in ProjectSettings.get_property_list():
		if setting.name.begins_with("autoload/"):
			var autoload_name = setting.name.get_slice("/", 1)
			var autoload_path = ProjectSettings.get_setting(setting.name)
			if typeof(autoload_path) == TYPE_STRING:
				if autoload_path.begins_with("*"):
					autoload_path = autoload_path.substr(1)
				_autoloads_cache[autoload_name] = {"name": autoload_name, "path": autoload_path, "type": "autoload"}
				preload_script_members(autoload_path, autoload_name)

func preload_script_members(script_path: String, identifier: String):
	if _script_members_cache.has(identifier):
		return
	if ResourceLoader.exists(script_path) and FileAccess.file_exists(script_path):
		var file = FileAccess.open(script_path, FileAccess.READ)
		if file:
			var script_content = file.get_as_text()
			file.close()
			var members = analyze_script_content(script_content)
			_script_members_cache[identifier] = members
			# También cacheamos los tipos de arrays si los encontramos
			cache_array_types_from_content(script_content, identifier)

func cache_array_types_from_content(content: String, _class_name: String):
	var lines = content.split("\n")
	for line in lines:
		line = line.strip_edges()
		# Detectar arrays con tipos específicos como: var armors: Array[RPGArmor]
		var array_type_match = detect_typed_array(line)
		if array_type_match.has("var_name") and array_type_match.has("element_type"):
			var full_key = _class_name + "." + array_type_match.var_name
			_array_element_types[full_key] = array_type_match.element_type

func detect_typed_array(line: String) -> Dictionary:
	var result = {}
	# Patrón para detectar: var nombre: Array[Tipo] o var nombre: Array[Tipo] = ...
	var regex = RegEx.new()
	regex.compile(r"var\s+([a-zA-Z_][a-zA-Z0-9_]*)\s*:\s*Array\s*\[\s*([a-zA-Z_][a-zA-Z0-9_]*)\s*\]")
	var match_result = regex.search(line)
	if match_result:
		result["var_name"] = match_result.get_string(1)
		result["element_type"] = match_result.get_string(2)
	return result

func refresh_current_script():
	_current_script_cache.clear()
	var text_lines = text.split("\n")
	for i in range(text_lines.size()):
		var line = text_lines[i].strip_edges()
		if line.begins_with("var ") or line.begins_with("@export var ") or line.begins_with("@onready var "):
			var var_info = extract_variable_info(line)
			if var_info.name != "":
				_current_script_cache[var_info.name] = {
					"name": var_info.name,
					"type": "variable",
					"line": i,
					"variable_type": var_info.var_type,
					"element_type": var_info.element_type,
					"value_type": var_info.value_type,
					"is_typed_array": var_info.is_typed_array
				}
				if var_info.var_type != "":
					var path = resolve_class_to_path(var_info.var_type)
					if path != "":
						preload_script_members(path, var_info.var_type)
		elif line.begins_with("func "):
			var func_name = extract_function_name(line)
			if func_name != "":
				_current_script_cache[func_name] = {
					"name": func_name,
					"type": "function",
					"line": i,
					"signature": line
				}
		elif line.begins_with("signal "):
			var signal_name = extract_signal_name(line)
			if signal_name != "":
				_current_script_cache[signal_name] = {"name": signal_name, "type": "signal", "line": i}

func extract_variable_info(line: String) -> Dictionary:
	var result = {"name": "", "var_type": "", "element_type": "", "value_type": "", "is_typed_array": false}
	
	# Primero intentamos detectar arrays tipados: Array[Tipo]
	var typed_array_regex = RegEx.new()
	typed_array_regex.compile(r"var\s+([a-zA-Z_][a-zA-Z0-9_]*)\s*:\s*Array\s*\[\s*([a-zA-Z_][a-zA-Z0-9_]*)\s*\]")
	var typed_match = typed_array_regex.search(line)
	if typed_match:
		result.name = typed_match.get_string(1)
		result.var_type = "Array"
		result.element_type = typed_match.get_string(2)
		result.is_typed_array = true
		return result
	
	# Si no es un array tipado, usamos la lógica original
	var regex = RegEx.new()
	regex.compile(r"var\s+([a-zA-Z_][a-zA-Z0-9_]*)\s*(?::\s*([a-zA-Z_][a-zA-Z0-9_]*))?\s*(?:=|:=)?")
	var match_result = regex.search(line)
	if match_result:
		result.name = match_result.get_string(1)
		if match_result.get_group_count() >= 2:
			result.var_type = match_result.get_string(2)
		
		# Detectar inicialización con new() en arrays
		if line.find("[") != -1 and line.find("]") != -1 and line.find("new") != -1:
			var element_regex = RegEx.new()
			element_regex.compile(r"\[\s*([a-zA-Z_][a-zA-Z0-9_]*)\.new")
			var element_match = element_regex.search(line)
			if element_match:
				result.element_type = element_match.get_string(1)
		
		if result.var_type == "Array":
			var array_regex = RegEx.new()
			array_regex.compile(r"Array\s*=\s*\[.*\]")
			if array_regex.search(line):
				result.element_type = "Unknown"
		
		if result.var_type == "Dictionary":
			result.value_type = "Unknown"
	return result

func resolve_class_to_path(_class_name: String) -> String:
	# Mapa básico de clases conocidas
	var class_map = {
		"GameState": "res://scripts/game_state.gd",
		"Player": "res://scripts/player.gd", 
		"Enemy": "res://scripts/enemy.gd",
		"RPGData": "res://scripts/rpg_data.gd",
		"RPGArmor": "res://scripts/rpg_armor.gd",
		"RPGWeapon": "res://scripts/rpg_weapon.gd",
		"RPGItem": "res://scripts/rpg_item.gd"
	}
	
	if class_map.has(_class_name):
		return class_map[_class_name]
	
	# También intentamos buscar en las clases globales del proyecto
	var global_classes = ProjectSettings.get_global_class_list()
	for class_data in global_classes:
		if class_data.class == _class_name:
			return class_data.path
	
	return ""

func extract_function_name(line: String) -> String:
	var regex = RegEx.new()
	regex.compile(r"func\s+([a-zA-Z_][a-zA-Z0-9_]*)")
	var result = regex.search(line)
	return result.get_string(1) if result else ""

func extract_signal_name(line: String) -> String:
	var regex = RegEx.new()
	regex.compile(r"signal\s+([a-zA-Z_][a-zA-Z0-9_]*)")
	var result = regex.search(line)
	return result.get_string(1) if result else ""

func _on_text_changed():
	if text != _last_analysis_text:
		_last_analysis_text = text
		call_deferred("refresh_current_script")
	
	if auto_fill_enabled:
		_on_code_completion_applied()
	
	queue_redraw()

func _on_caret_changed():
	var current_line = get_line(get_caret_line())
	var cursor_column = get_caret_column()
	var text_to_cursor = current_line.substr(0, cursor_column)
	if get_selected_text().length() == 0:
		if text_to_cursor.ends_with("."):
			request_code_completion.call_deferred(true)
		else:
			if should_show_completion(text_to_cursor):
				request_code_completion.call_deferred(true)
	
	queue_redraw()

func should_show_completion(text_to_cursor: String) -> bool:
	if text_to_cursor.ends_with("."):
		return true
	var dot_pos = text_to_cursor.rfind(".")
	if dot_pos != -1 and dot_pos < text_to_cursor.length() - 1:
		return true
	var last_word = get_last_word(text_to_cursor)
	return last_word.length() >= 1

func _on_code_completion_requested():
	var current_line = get_line(get_caret_line())
	var cursor_column = get_caret_column()
	var text_to_cursor = current_line.substr(0, cursor_column)

	var suggestions = []
	var context = analyze_current_context(text_to_cursor)
	match context.type:
		"member_access":
			suggestions = get_member_suggestions_for_chain(context.chain, context.partial_member)
		"partial_match":
			suggestions = get_partial_match_suggestions(context.partial_text)
		"general":
			suggestions = get_general_suggestions()
	suggestions = remove_duplicates(suggestions)
	for suggestion in suggestions:
		add_code_completion_option(suggestion.kind, suggestion.display_text, suggestion.insert_text, suggestion.get("color", Color.WHITE))
	
	if suggestions.is_empty():
		auto_fill_enabled = false

	update_code_completion_options(true)

func remove_duplicates(suggestions: Array) -> Array:
	var seen = {}
	var unique_suggestions = []
	for suggestion in suggestions:
		var key = suggestion.display_text
		if not seen.has(key):
			seen[key] = true
			unique_suggestions.append(suggestion)
	return unique_suggestions

func analyze_current_context(text_to_cursor: String) -> Dictionary:
	var dot_pos = text_to_cursor.rfind(".")
	if dot_pos != -1:
		var before_dot = text_to_cursor.substr(0, dot_pos)
		var after_dot = text_to_cursor.substr(dot_pos + 1)
		var chain = parse_object_chain(before_dot)
		return {"type": "member_access","chain": chain,"partial_member": after_dot}
	var last_word = get_last_word(text_to_cursor)
	if last_word != "":
		return {"type": "partial_match","partial_text": last_word}
	return {"type": "general"}

func parse_object_chain(text: String) -> Array:
	var trimmed = text.strip_edges()
	var parts = []
	var regex = RegEx.new()
	# Modificado para capturar también accesos a arrays con índices
	regex.compile(r"([a-zA-Z_][a-zA-Z0-9_]*(?:\[[^\]]*\])?(?:\.[a-zA-Z_][a-zA-Z0-9_]*(?:\[[^\]]*\])?)*)$")
	var result = regex.search(trimmed)
	if result:
		var chain_text = result.get_string(1)
		# Dividimos por puntos, pero preservando los índices de array
		parts = split_chain_preserving_arrays(chain_text)
	return parts

func split_chain_preserving_arrays(chain_text: String) -> Array:
	var parts = []
	var current_part = ""
	var bracket_depth = 0
	
	for i in range(chain_text.length()):
		var char = chain_text[i]
		if char == "[":
			bracket_depth += 1
			current_part += char
		elif char == "]":
			bracket_depth -= 1
			current_part += char
		elif char == "." and bracket_depth == 0:
			if current_part != "":
				parts.append(current_part)
				current_part = ""
		else:
			current_part += char
	
	if current_part != "":
		parts.append(current_part)
	
	return parts

func get_member_suggestions_for_chain(chain: Array, partial_member: String) -> Array:
	var suggestions = []
	if chain.is_empty():
		return suggestions
		
	var current_members = get_members_for_identifier(chain[0])
	var current_type = get_type_for_identifier(chain[0])
	
	# Procesamos cada elemento de la cadena
	for i in range(1, chain.size()):
		var member_name = chain[i]
		
		# Detectar si es un acceso a array: variable[index]
		if member_name.find("[") != -1:
			var array_var_name = member_name.get_slice("[", 0)
			var element_type = get_array_element_type(current_type, array_var_name)
			
			if element_type != "":
				current_members = get_members_for_identifier(element_type)
				current_type = element_type
				continue
		
		# Buscar el miembro en la lista actual
		var found_member = null
		for member in current_members:
			if member.name == member_name:
				found_member = member
				break
		
		if found_member and found_member.has("variable_type") and found_member.variable_type != "":
			current_members = get_members_for_identifier(found_member.variable_type)
			current_type = found_member.variable_type
		else:
			# Si no encontramos el tipo específico, usar métodos genéricos
			current_members = get_generic_members()
			current_type = ""
			break
	
	# Filtrar sugerencias basadas en el texto parcial
	for member in current_members:
		if partial_member == "" or member.name.to_lower().find(partial_member.to_lower()) != -1:
			suggestions.append(create_suggestion(member))
	
	return suggestions

func get_type_for_identifier(identifier: String) -> String:
	if _autoloads_cache.has(identifier):
		return identifier
	elif _current_script_cache.has(identifier):
		var var_info = _current_script_cache[identifier]
		return var_info.get("variable_type", "")
	return ""

func get_array_element_type(parent_type: String, array_name: String) -> String:
	# Primero buscar en el cache de tipos de arrays
	var full_key = parent_type + "." + array_name
	if _array_element_types.has(full_key):
		return _array_element_types[full_key]
	
	# Si es una variable local, buscar su tipo de elemento
	if _current_script_cache.has(array_name):
		var var_info = _current_script_cache[array_name]
		if var_info.has("element_type") and var_info.element_type != "":
			return var_info.element_type
	
	# Si es de un autoload, buscar en su cache
	if _script_members_cache.has(parent_type):
		var members = _script_members_cache[parent_type]
		for member in members:
			if member.name == array_name and member.has("element_type"):
				return member.get("element_type", "")
	
	return ""

func get_members_for_identifier(identifier: String) -> Array:
	# Primero verificar si es una clase builtin
	if _builtin_classes_cache.has(identifier):
		return _builtin_classes_cache[identifier]
	
	if _autoloads_cache.has(identifier):
		if _script_members_cache.has(identifier):
			return _script_members_cache[identifier]
		else:
			return get_generic_members()
	elif _current_script_cache.has(identifier):
		var var_info = _current_script_cache[identifier]
		if var_info.has("variable_type") and var_info.variable_type != "":
			# Verificar si el tipo de variable es una clase builtin
			if _builtin_classes_cache.has(var_info.variable_type):
				return _builtin_classes_cache[var_info.variable_type]
				
			if var_info.variable_type == "Array" and var_info.element_type != "":
				return get_members_for_identifier(var_info.element_type)
			if var_info.variable_type == "Dictionary" and var_info.value_type != "":
				return get_members_for_identifier(var_info.value_type)
			if _script_members_cache.has(var_info.variable_type):
				return _script_members_cache[var_info.variable_type]
			else:
				# Intentar cargar el tipo si no está en caché
				var path = _find_class_info(var_info.variable_type)
				if path != "":
					preload_script_members(path, var_info.variable_type)
					if _script_members_cache.has(var_info.variable_type):
						return _script_members_cache[var_info.variable_type]
				return get_generic_members()
		else:
			return get_generic_members()
	else:
		# Verificar si es una clase builtin primero
		if _builtin_classes_cache.has(identifier):
			return _builtin_classes_cache[identifier]
			
		# Buscar información de la clase e intentar cargarla
		var path = _find_class_info(identifier)
		if path != "":
			preload_script_members(path, identifier)
			if _script_members_cache.has(identifier):
				return _script_members_cache[identifier]
	
	return []

func _find_class_info(identifier: String) -> String:
	var class_data = ProjectSettings.get_global_class_list().filter(func(d: Dictionary): return d.class == identifier)
	if not class_data.is_empty():
		return class_data[0].path
	return ""

func get_generic_members() -> Array:
	return [
		{"name": "name", "kind": CodeEdit.KIND_MEMBER, "type": "property"},
		{"name": "get_parent", "kind": CodeEdit.KIND_FUNCTION, "type": "function"},
		{"name": "get_child", "kind": CodeEdit.KIND_FUNCTION, "type": "function"},
		{"name": "add_child", "kind": CodeEdit.KIND_FUNCTION, "type": "function"},
		{"name": "remove_child", "kind": CodeEdit.KIND_FUNCTION, "type": "function"},
		{"name": "queue_free", "kind": CodeEdit.KIND_FUNCTION, "type": "function"},
		{"name": "get_node", "kind": CodeEdit.KIND_FUNCTION, "type": "function"},
		{"name": "find_child", "kind": CodeEdit.KIND_FUNCTION, "type": "function"},
	]

func get_partial_match_suggestions(partial_text: String) -> Array:
	var suggestions = []
	for autoload_name in _autoloads_cache.keys():
		if autoload_name.to_lower().begins_with(partial_text.to_lower()):
			suggestions.append({"kind": CodeEdit.KIND_CLASS,"display_text": autoload_name,"insert_text": autoload_name,"color": Color(0.8, 1.0, 0.8)})
	for item_name in _current_script_cache.keys():
		if item_name.to_lower().begins_with(partial_text.to_lower()):
			var item = _current_script_cache[item_name]
			var kind = CodeEdit.KIND_MEMBER
			if item.type == "function":
				kind = CodeEdit.KIND_FUNCTION
			elif item.type == "signal":
				kind = CodeEdit.KIND_SIGNAL
			suggestions.append({"kind": kind,"display_text": item_name,"insert_text": item_name,"color": Color.WHITE})
	return suggestions

func get_general_suggestions() -> Array:
	var suggestions = []
	var keywords = ["func", "var", "const", "if", "else", "elif", "for", "while", "match", "class", "extends", "signal", "enum", "return", "break", "continue", "pass", "print", "await"]
	for keyword in keywords:
		suggestions.append({"kind": CodeEdit.KIND_MEMBER,"display_text": keyword,"insert_text": keyword,"color": Color(1.0, 0.4, 0.4)})
	for autoload_name in _autoloads_cache.keys():
		suggestions.append({"kind": CodeEdit.KIND_CLASS,"display_text": autoload_name,"insert_text": autoload_name,"color": Color(0.8, 1.0, 0.8)})
	return suggestions

func analyze_script_content(content: String) -> Array:
	var members = []
	var lines = content.split("\n")
	for line in lines:
		line = line.strip_edges()
		if line.begins_with("var ") or line.begins_with("@export var ") or line.begins_with("@onready var "):
			var var_info = extract_variable_info(line)
			if var_info.name != "":
				members.append({
					"name": var_info.name,
					"kind": CodeEdit.KIND_MEMBER,
					"type": "variable",
					"variable_type": var_info.var_type,
					"element_type": var_info.element_type,
					"value_type": var_info.value_type,
					"is_typed_array": var_info.is_typed_array
				})
		elif line.begins_with("func "):
			var func_name = extract_function_name(line)
			if func_name != "" and not func_name.begins_with("_"):
				members.append({"name": func_name,"kind": CodeEdit.KIND_FUNCTION,"type": "function"})
		elif line.begins_with("signal "):
			var signal_name = extract_signal_name(line)
			if signal_name != "":
				members.append({"name": signal_name,"kind": CodeEdit.KIND_SIGNAL,"type": "signal"})
	return members

func create_suggestion(member: Dictionary) -> Dictionary:
	var insert_text = member.name
	var display_text = member.name
	if member.type == "function":
		insert_text += "()"
		display_text += "()"
	var color = Color.WHITE
	match member.type:
		"function":
			color = Color(0.4, 0.8, 1.0)
		"variable", "property":
			color = Color(1.0, 1.0, 0.6)
		"signal":
			color = Color(1.0, 0.8, 0.4)
		"constant":
			color = Color(0.8, 0.4, 1.0)
	auto_fill_enabled = true
		
	return {
		"kind": member.kind,
		"display_text": display_text,
		"insert_text": insert_text,
		"color": color,
		"is_function": member.type == "function"  # Marcamos si es función
	}

func _on_code_completion_applied():
	if not auto_fill_enabled: return
	# Si el texto insertado termina con (), mover cursor entre paréntesis
	if text.ends_with("()"):
		var current_column = get_caret_column()
		call_deferred("set_caret_column", get_caret_column() - 1)
	auto_fill_enabled = false


func get_last_word(text: String) -> String:
	var regex = RegEx.new()
	regex.compile(r"[a-zA-Z_][a-zA-Z0-9_]*$")
	var result = regex.search(text)
	return result.get_string() if result else ""

func force_refresh():
	refresh_autoloads()
	refresh_current_script()
	setup_builtin_classes_from_classdb()

func add_custom_suggestion(name: String, type: String):
	_current_script_cache[name] = {"name": name,"type": type,"custom": true}
