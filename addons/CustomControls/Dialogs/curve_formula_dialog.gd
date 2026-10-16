@tool
extends Window


const USER_PRESETS_PATH: String = "user://formula_presets.json"
const DEFAULT_PRESETS: Array = [
	{"name": "Lineal Básica", "formula": "min_val + (max_val - min_val) * (level / max_level)"},
	{"name": "Exponencial Suave", "formula": "min_val + (max_val - min_val) * pow(level / max_level, 2)"},
	{"name": "Exponencial Fuerte", "formula": "min_val + (max_val - min_val) * pow(level / max_level, 3)"},
	{"name": "Logarítmica", "formula": "min_val + (max_val - min_val) * (log(1 + 9 * (level / max_level)) / log(10))"},
	{"name": "Sigmoide / Curva S", "formula": "min_val + (max_val - min_val) / (1 + exp(-10 * ((level / max_level) - 0.5)))"}
]

var real_data: PackedInt32Array
var preview_data: PackedInt32Array
var min_value: int
var max_value: int
var custom_presets: Array = []


signal data_changed()


#region Callbacks del Sistema
## Configura las conexiones iniciales y carga los presets
func _ready() -> void:
	close_requested.connect(queue_free)
	if has_node("%Formula"):
		%Formula.text_changed.connect(_on_formula_text_changed)
	_load_custom_presets()
	_fill_presets()
	_setup_symbol_buttons()


## Establece los datos de la curva y sus limites
func set_data(data: PackedInt32Array, new_min_value: int, new_max_value: int) -> void:
	real_data = data
	min_value = new_min_value
	max_value = new_max_value
	preview_data = real_data.duplicate()
	if has_node("%Formula") and %Formula.text.is_empty():
		%Formula.text = DEFAULT_PRESETS[0]["formula"]
	_update_preview()
#endregion


#region Eventos de la Interfaz
## Actualiza la vista previa al cambiar el texto de la formula
func _on_formula_text_changed(_new_text: String = "") -> void:
	_update_preview()


## Aplica los cambios calculados a los datos reales y emite la señal
func _on_ok_button_pressed() -> void:
	if _evaluate_formula(real_data):
		data_changed.emit()
		queue_free()


## Cierra la ventana sin aplicar cambios
func _on_cancel_button_pressed() -> void:
	queue_free()


## Maneja la seleccion de un preset en la lista
func _on_presets_item_selected(index: int) -> void:
	if not has_node("%Presets"):
		return
	var node: OptionButton = %Presets
	if index == 0:
		if has_node("%RemovePresetButton"):
			%RemovePresetButton.set_disabled(true)
		return
	var meta: Dictionary = node.get_item_metadata(index)
	var formula: String = meta.get("formula", "")
	var is_user_preset: bool = meta.get("is_user_preset", false)
	if has_node("%Formula") and not formula.is_empty():
		%Formula.text = formula
		_update_preview()
	if has_node("%RemovePresetButton"):
		%RemovePresetButton.set_disabled(not is_user_preset)


## Guarda la formula actual como un nuevo preset de usuario
func _on_save_preset_button_pressed() -> void:
	if not has_node("%Formula"):
		return
	var current_formula: String = %Formula.text.strip_edges()
	if current_formula.is_empty():
		return
	var _name: String = %UserPresetName.text
	if _name.is_empty() or _name.to_lower().strip_edges() == "preset":
		_name = "Preset " + str(custom_presets.size() + 1)
	var preset_name: String = _name
	custom_presets.append({
		"name": preset_name,
		"formula": current_formula
	})
	_save_custom_presets()
	_fill_presets()


## Elimina el preset de usuario seleccionado
func _on_remove_preset_button_pressed() -> void:
	if not has_node("%Presets"):
		return
	var node: OptionButton = %Presets
	var selected_idx: int = node.selected
	if selected_idx <= 0:
		return
	var meta: Dictionary = node.get_item_metadata(selected_idx)
	if meta.get("is_user_preset", false):
		var user_idx: int = meta.get("user_index", -1)
		if user_idx >= 0 and user_idx < custom_presets.size():
			custom_presets.remove_at(user_idx)
			_save_custom_presets()
			_fill_presets()


## Inserta el simbolo o funcion seleccionada en el campo de texto
func _on_symbol_button_pressed(symbol_text: String) -> void:
	if not has_node("%Formula"):
		return
	var text_edit: TextEdit = %Formula
	text_edit.grab_focus()
	var token: String = symbol_text
	match token:
		"pow", "sqrt", "sin", "cos", "tan", "log", "exp", "abs", "floor", "ceil", "round", "clamp":
			token += "()"
		"lerp":
			token += "(, , )"
	text_edit.insert_text_at_caret(token)
	if token.ends_with("()"):
		text_edit.set_caret_column(text_edit.get_caret_column() - 1)
	elif token.ends_with("(, , )"):
		text_edit.set_caret_column(text_edit.get_caret_column() - 5)
	text_edit.grab_focus()
	_update_preview()
#endregion


#region Evaluacion y Actualizacion
## Actualiza la curva de previsualizacion temporal
func _update_preview() -> void:
	if real_data.size() <= 0:
		return
	preview_data = real_data.duplicate()
	var is_valid: bool = _evaluate_formula(preview_data)
	if is_valid:
		if has_node("%InvalidData"):
			%InvalidData.visible = false
		if has_node("%CurvePreview"):
			%CurvePreview.draw_curve(preview_data)
	else:
		if has_node("%InvalidData"):
			%InvalidData.visible = true
		if has_node("%CurvePreview"):
			%CurvePreview.draw_curve(PackedInt32Array())


## Aplica la evaluacion de la formula sobre el objetivo indicado
func _update_real_data(target_data: Variant = null) -> void:
	var data: PackedInt32Array = real_data if target_data == null else target_data
	var max_levels: int = data.size() - 1
	if max_levels <= 0:
		return
	var is_valid_formula: bool = _evaluate_formula(data)
	if is_valid_formula:
		if has_node("%InvalidData"):
			%InvalidData.visible = false
		if has_node("%CurvePreview"):
			%CurvePreview.draw_curve(data)
	else:
		if has_node("%InvalidData"):
			%InvalidData.visible = true
		if has_node("%CurvePreview"):
			%CurvePreview.draw_curve(PackedInt32Array())


## Evalua la formula matematica introducida y la aplica al array indicado
func _evaluate_formula(data: PackedInt32Array) -> bool:
	if not has_node("%Formula"):
		return false
	var formula_text: String = %Formula.text.strip_edges().replace("\n", " ")
	if formula_text.is_empty():
		return false
	var total_elements: int = data.size()
	if total_elements <= 0:
		return false
	var expression: Expression = Expression.new()
	var input_names: PackedStringArray = ["level", "max_level", "min_val", "max_val", "i", "n"]
	var error: Error = expression.parse(formula_text, input_names)
	if error != OK:
		return false
	var max_level: float = float(total_elements - 1)
	var temp_results: Array[int] = []
	for idx in range(total_elements):
		var level: float = float(idx)
		var inputs: Array = [level, max_level, float(min_value), float(max_value), level, max_level]
		var result: Variant = expression.execute(inputs, self, false)
		if expression.has_execute_failed():
			return false
		var float_val: float = float(result)
		var clamped_val: int = clampi(int(round(float_val)), min_value, max_value)
		temp_results.append(clamped_val)
	for idx in range(total_elements):
		data[idx] = temp_results[idx]
	return true
#endregion


#region Gestion de Presets
## Carga la lista de presets guardados por el usuario desde disco
func _load_custom_presets() -> void:
	custom_presets.clear()
	if not FileAccess.file_exists(USER_PRESETS_PATH):
		return
	var file: FileAccess = FileAccess.open(USER_PRESETS_PATH, FileAccess.READ)
	if file:
		var json_text: String = file.get_as_text()
		var json: JSON = JSON.new()
		if json.parse(json_text) == OK and json.data is Array:
			custom_presets = json.data


## Guarda los presets de usuario en un archivo JSON
func _save_custom_presets() -> void:
	var file: FileAccess = FileAccess.open(USER_PRESETS_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(custom_presets, "\t"))


## Rellena el OptionButton con los presets personalizados y por defecto
func _fill_presets() -> void:
	if not has_node("%Presets"):
		return
	var node: OptionButton = %Presets
	node.clear()
	node.add_item("Select Preset")
	node.set_item_metadata(0, {"formula": "", "is_user_preset": false})
	if not custom_presets.is_empty():
		for i in range(custom_presets.size()):
			var preset: Dictionary = custom_presets[i]
			node.add_item("★ " + String(preset.get("name", "Custom")))
			node.set_item_metadata(node.get_item_count() - 1, {
				"formula": preset.get("formula", ""),
				"is_user_preset": true,
				"user_index": i
			})
		node.add_separator("Default Presets")
	for preset in DEFAULT_PRESETS:
		node.add_item(preset["name"])
		node.set_item_metadata(node.get_item_count() - 1, {
			"formula": preset["formula"],
			"is_user_preset": false
		})
	node.select(0)
	if has_node("%RemovePresetButton"):
		%RemovePresetButton.set_disabled(true)
#endregion


#region Configuracion de Simbolos
## Conecta la rejilla de botones de simbolos con el campo de texto de la formula
func _setup_symbol_buttons() -> void:
	if not has_node("%SymbolGrid"):
		return
	var symbol_container: Node = %SymbolGrid
	for child in symbol_container.get_children():
		if child is Button:
			var btn: Button = child as Button
			if not btn.pressed.is_connected(_on_symbol_button_pressed):
				btn.pressed.connect(_on_symbol_button_pressed.bind(btn.text))
#endregion
