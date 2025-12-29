@tool
extends Window

var data: Array[Dictionary]
var real_data: Array[Dictionary]
var selected_index: int = 0
var busy: bool = false


func _ready() -> void:
	close_requested.connect(hide)


func set_data(_data: Array[Dictionary]) -> void:
	data = _data.duplicate(true)
	real_data = _data


func select_data_type(id: int) -> void:
	busy = true
	%DataOptions.select(id)
	selected_index = id
	var current_data = data[selected_index]
	%LevelSpinBox.min_value = current_data.initial_level
	%LevelSpinBox.max_value = current_data.data.size() - 1
	%CurrentValueSpinBox.min_value = current_data.min_value
	%CurrentValueSpinBox.max_value = current_data.max_value
	await _on_data_options_item_selected()
	
	await get_tree().process_frame
	busy = false


func _on_data_options_item_selected() -> void:
	var current_data = data[selected_index]
	
	%MinValueSpinBox.value = current_data.min_value
	%MaxValueSpinBox.value = current_data.max_value
	%CurrentValueSpinBox.min_value = current_data.min_value
	%CurrentValueSpinBox.max_value = current_data.max_value
	
	%StatEditor.set_data(current_data.data, current_data)
	
	await get_tree().process_frame


func _on_stat_editor_value_changed(level: Variant, value: Variant) -> void:
	if %StatEditor.round_values:
		value = round(value)
	
	%LevelSpinBox.value = level
	%CurrentValueSpinBox.value = value


func _on_stat_editor_value_clicked(level: Variant, value: Variant) -> void:
	%LevelSpinBox.value = level
	%CurrentValueSpinBox.value = value


func _on_cancel_button_pressed() -> void:
	hide()


func _on_ok_button_pressed() -> void:
	for i in data.size():
		var obj: Dictionary = data[i]
		for key in obj.keys():
			if key != "data":
				real_data[i][key] = obj[key]
			else:
				real_data[i][key].clear()
				real_data[i][key].append_array(obj[key])
	hide()


func create_lineal_curve(value) -> void:
	var current_data = data[selected_index]
	for i in current_data.data.size():
		current_data.data[i] = value


func _on_custom_lineal_value_selected(value: int) -> void:
	var current_data = data[selected_index]
	
	busy = true
	
	create_lineal_curve(value)
	
	await _on_data_options_item_selected()
	%Presets.select(0)
	var level = %LevelSpinBox.value
	%CurrentValueSpinBox.value = current_data.data[level]
	
	await get_tree().process_frame
	busy = false
	


func create_simple_curve() -> void:
	var current_data = data[selected_index]
	var curve_size = current_data.data.size()
	for i in range(1, curve_size):
		current_data.data[i] = round(current_data.min_value + (current_data.max_value - current_data.min_value) * (float(i) / (curve_size-1)))
	current_data.data[1] = current_data.min_value


func show_create_line_dialog() -> void:
	var current_data = data[selected_index]
	
	var path = "res://addons/CustomControls/Dialogs/select_number_value_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	
	dialog.set_min_max_values(current_data.min_value, current_data.max_value)
	
	dialog.selected_value.connect(_on_custom_lineal_value_selected)


func get_curve(curve : Curve) -> Array:
	var current_data = data[selected_index]
	var max_level = current_data.data.size()
	var min_value = current_data.min_value
	var max_value = current_data.max_value
	var mod : float = 1.0 / max_level
	var x : float = mod
	var value : int
	var r = []
	for i in max_level:
		var _v = max_value - min_value
		value = curve.sample(x) * _v + min_value
		r.append(round(value))
		x += mod
	# Fix curve
	# Determine the curve direction based on value comparisons
	var ascending_count = 0
	var descending_count = 0

	for i in range(1, r.size()):
		if r[i] > r[i - 1]:
			ascending_count += 1
		elif r[i] < r[i - 1]:
			descending_count += 1

	var is_ascending = ascending_count > descending_count
	
	# Apply correction based on the curve direction
	if is_ascending:
		for i in range(2, r.size()):
			if r[i - 2] <= r[i - 1] and r[i] < r[i - 1]:
				r[i] = r[i - 1]
	else:
		for i in range(2, r.size()):
			if r[i - 2] >= r[i - 1] and r[i] > r[i - 1]:
				r[i] = r[i - 1]
				
	return r


func _on_presets_item_selected(index: int) -> void:
	busy = true
	
	var current_data = data[selected_index]
	if index == 9 or index == 10:
		var value = current_data.min_value if index == 9 else current_data.max_value
		create_lineal_curve(value)
	elif index == 11:
		create_simple_curve()
	elif index == 12:
		show_create_line_dialog()
	else:
		var path = [null, "default_param_curve", "exp_basic_curve", "param_basic_curve", "preset_A", "preset_B", "preset_C", "preset_D", "preset_E"][index]
		if path != null:
			path = "res://addons/CustomControls/Resources/Curves/%s.tres" % path
			var curve_preset = ResourceLoader.load(path)
			var curve = [0] + get_curve(curve_preset)
			for i in current_data.data.size():
				current_data.data[i] = curve[i]
	
	await _on_data_options_item_selected()
	%Presets.select(0)
	var level = %LevelSpinBox.value
	%CurrentValueSpinBox.value = current_data.data[level]
	
	await get_tree().process_frame
	busy = false


func _on_level_spin_box_value_changed(level: float) -> void:
	if busy: return
	var current_data = data[selected_index]
	var value = current_data.data[level]
	%CurrentValueSpinBox.value = value
	%StatEditor.update_data(level, value)


func _on_current_value_spin_box_value_changed(value: float) -> void:
	if busy: return
	var current_data = data[selected_index]
	var level = %LevelSpinBox.value
	current_data.data[level] = value
	%StatEditor.update_data(level, value)


func _on_min_value_spin_box_value_changed(value: float) -> void:
	if busy: return
	var current_data = data[selected_index]
	current_data.min_value = value
	
	for i in current_data.data.size():
		if current_data.data[i] < value:
			current_data.data[i] = value

	%CurrentValueSpinBox.min_value = current_data.min_value
	%StatEditor.min_value = current_data.min_value
	_on_level_spin_box_value_changed(%LevelSpinBox.value)
	%StatEditor.refresh()


func _on_max_value_spin_box_value_changed(value: float) -> void:
	if busy: return
	var current_data = data[selected_index]
	current_data.max_value = value
	
	for i in current_data.data.size():
		if current_data.data[i] > value:
			current_data.data[i] = value
	
	%CurrentValueSpinBox.max_value = current_data.max_value
	%StatEditor.max_value = current_data.max_value
	_on_level_spin_box_value_changed(%LevelSpinBox.value)
	%StatEditor.refresh()


func _on_save_preset_button_pressed() -> void:
	var current_data = data[selected_index]
	var curve = %StatEditor
	var curve_data : Array = curve.get_data().duplicate()
	curve_data.remove_at(0)
	
	var resource_curve : Curve = Curve.new()
	var tolerance = 0.35
	var max_points : int = curve_data.size() * tolerance
	var index_mod : float = curve_data.size() / float(max_points)
	var min_value = current_data.min_value
	var max_value = current_data.max_value
	for i in range(0, max_points - 1):
		var index : int = index_mod * i
		var real_value = curve_data[index]
		var resource_curve_value : float = remap(real_value, min_value, max_value, 0.0, 1.0)
		var resource_curve_index : float = remap(index, 0, curve_data.size() - 1, 0.0, 1.0)
		var point = Vector2(resource_curve_index, resource_curve_value)
		resource_curve.add_point(point)
	
	var index : int = curve_data.size() - 1
	var real_value = curve_data[index]
	var resource_curve_value : float = remap(real_value, min_value, max_value, 0.0, 1.0)
	var resource_curve_index : float = 1.0
	var point = Vector2(resource_curve_index, resource_curve_value)
	resource_curve.add_point(point)

	open_save_curve_dialog(resource_curve)


func _on_load_preset_button_pressed() -> void:
	open_load_curve_dialog()


func open_save_curve_dialog(resource_curve: Curve) -> void:
	var path = "res://addons/CustomControls/Dialogs/select_file_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	await get_tree().process_frame
	
	dialog.target_callable = _save_preset.bind(resource_curve)
	dialog.set_dialog_mode(1)
	dialog.set_directory_filename("new_curve_preset")
	dialog.destroy_on_hide = true
	var default_path = "res://addons/CustomControls/Resources/UserCurves/"
	dialog.navigate_to_directory(default_path)


func open_load_curve_dialog() -> void:
	var path = "res://addons/CustomControls/Dialogs/select_file_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	await get_tree().process_frame
	
	dialog.target_callable = _load_preset
	dialog.set_dialog_mode(0)
	dialog.destroy_on_hide = true
	
	dialog.fill_files("curves")


func _save_preset(path: String, resource_curve: Curve) -> void:
	if path.length() > 0:
		path = path + ".tres"
		ResourceSaver.save(resource_curve, path)


func _load_preset(path: String) -> void:
	if path.length() > 0:
		if ResourceLoader.exists(path):
			var curve = ResourceLoader.load(path)
			load_curve(curve)


func load_curve(curve_preset: Curve) -> void:
	var current_data = data[selected_index]
	var curve = [0] + get_curve(curve_preset)
	current_data.data.clear()
	current_data.data.append_array(curve)

	%StatEditor.set_data(current_data.data, current_data)


func _on_fix_curve_button_pressed() -> void:
	busy = true
	
	var current_data = data[selected_index]
	var curve = current_data.data
	
	# Fix curve
	# Determine the curve direction based on value comparisons
	var ascending_count = 0
	var descending_count = 0

	for i in range(1, curve.size()):
		if curve[i] > curve[i - 1]:
			ascending_count += 1
		elif curve[i] < curve[i - 1]:
			descending_count += 1

	var is_ascending = ascending_count > descending_count
	
	# Apply correction based on the curve direction
	if is_ascending:
		for i in range(2, curve.size()):
			if curve[i - 2] <= curve[i - 1] and curve[i] < curve[i - 1]:
				curve[i] = curve[i - 1]
	else:
		for i in range(2, curve.size()):
			if curve[i - 2] >= curve[i - 1] and curve[i] > curve[i - 1]:
				curve[i] = curve[i - 1]
	
	await _on_data_options_item_selected()
	%Presets.select(0)
	var level = %LevelSpinBox.value
	%CurrentValueSpinBox.value = current_data.data[level]
	
	busy = false
