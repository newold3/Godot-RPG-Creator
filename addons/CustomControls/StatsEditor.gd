@tool
extends Panel

func get_class(): return "CurveParameter"

@export var editable : bool = true :
	set(value):
		editable = value
		set_editable(value)


@export_multiline var title : String :
	set(value):
		title = value
		set_text(value)
	get:
		return title


@export_range(8, 40) var title_size = 16 :
	set(value):
		title_size = value
		if label:
			label.set("theme_override_font_sizes/font_size", title_size)
	get: return title_size


@export var title_text_color: Color = Color.WHITE :
	set(value):
		title_text_color = value
		if label:
			label.set("theme_override_colors/font_color", title_text_color)
	get: return title_text_color


@export var background_color : Color = Color(0.00, 0.14, 0.20, 0.88) :
	set(value):
		background_color = value
		set_background_color(value)
	get:
		return background_color

@export var curve_color : Color = Color("dbe0f0") :
	set(value):
		curve_color = value
		set_curve_color(value)
	get:
		return curve_color


@export var cursor_color: Color = Color.WHITE :
	set(value):
		cursor_color = value
		var node = get_node_or_null("%ursor")
		if node:
			node.color = cursor_color
	get: return cursor_color


@export var show_extra_buttons : bool = true:
	set(value):
		show_extra_buttons = value
		set_buttons_disabled(value)
	get:
		return show_extra_buttons


@export var curve_color_auto_value : bool = false
@export var round_values : bool = true

@onready var main_control = %StatsEditor
@onready var label = %Label
@onready var cursor = %Cursor
@onready var focused_panel = %FocusedPanel

var panel_stylebox

var data = []
var color : Color = curve_color
var min_value : int = 0
var max_value : int = 9999
var initial_level : int = 0

var drawing = false
var last_level : int = -1

var current_level : int

var upgrade_button = 0
var upgrade_delay = 0

var busy : bool = false

var disabled: bool = false

var exponential_button_enabled: Callable

signal value_changed(level, value)
signal value_clicked(level, value)
signal clicked()

func _ready() -> void:
	panel_stylebox = get_theme_stylebox("panel").duplicate()
	set("theme_override_styles/panel", panel_stylebox)
	
	if !is_connected("focus_entered", enable_focus):
		focus_entered.connect(enable_focus.bind(true))
		focus_exited.connect(enable_focus.bind(false))
		visibility_changed.connect(_on_visibility_changed)

	if !main_control.is_connected("draw", _on_draw_main_control):
		main_control.draw.connect(_on_draw_main_control)
		main_control.gui_input.connect(_on_gui_input)
		main_control.mouse_entered.connect(_on_mouse_entered)
		main_control.mouse_exited.connect(_on_mouse_exited)

	label.text = title
	label.visible = !editable
	label.set("theme_override_font_sizes/font_size", title_size)
	label.set("theme_override_colors/font_color", title_text_color)
	panel_stylebox.bg_color = background_color
	cursor.color = cursor_color
	
	$MarginContainer/HBoxContainer/VBoxContainer.mouse_default_cursor_shape = Control.CURSOR_ARROW if editable else Control.CURSOR_POINTING_HAND
	
	%PasteCurve.set_disabled(not "stat_curve_preset" in StaticEditorVars.CLIPBOARD)


func clear() -> void:
	data = [0]
	main_control.queue_redraw()


func set_help(text : String) -> void:
	pass
#	main_control.set_tooltip(DataManager.translate_word(text))


func enable_focus(value : bool) -> void:
	focused_panel.visible = value


func set_editable(value: bool) -> void:
	if label:
		label.visible = !editable

	$MarginContainer/HBoxContainer/VBoxContainer.mouse_default_cursor_shape = Control.CURSOR_ARROW if editable else Control.CURSOR_POINTING_HAND
	
	%StatsEditor.mouse_filter = MOUSE_FILTER_PASS if !value else MOUSE_FILTER_STOP


func set_background_color(value : Color) -> void:
	if panel_stylebox:
		panel_stylebox.set("bg_color", value)
	if curve_color_auto_value:
		set_curve_color(background_color.inverted())


func set_curve_color(_color : Color) -> void:
	color = _color
	if main_control:
		main_control.queue_redraw()


func _on_mouse_entered() -> void:
	cursor.visible = !editable and !disabled


func _on_mouse_exited() -> void:
	cursor.visible = false


func set_data(_data, _current_paranmeter : Dictionary) -> void:
	data = _data
	min_value = _current_paranmeter.min_value
	max_value = _current_paranmeter.max_value
	initial_level = _current_paranmeter.initial_level
	var key = "enable_decimal_values"
	var enable_decimals = _current_paranmeter.has(key) and _current_paranmeter[key]
	round_values = !enable_decimals
	if label:
		label.visible = !editable
	if current_level < initial_level or current_level > data.size() - 1:
		current_level = initial_level
	background_color = _current_paranmeter.background_color
	if !curve_color_auto_value:
		curve_color = _current_paranmeter.foreground_color
	else:
		main_control.queue_redraw()
	if data.size() > current_level:
		emit_signal("value_clicked", current_level, data[current_level])


func get_data():
	return data


func _on_draw_main_control() -> void:
	if data == null or main_control == null: return
	var x : float = 0
	var y : int
	var s = size
	var w : float = main_control.size.x / float(data.size() - initial_level)
	var h : float = main_control.size.y
	var other_color = background_color.inverted()
	var _max_value = max(min_value, max_value)
	var _min_value = min(min_value, max_value)
	for i in range(initial_level, data.size()):
		if data[i] == null: continue
#		var n : int = ceil(data[i] * h / _max_value)
		var n : int
		if min_value < max_value:
			n = remap(data[i], min_value, max_value, 2, h)
		else:
			n = remap(data[i], max_value, min_value, 2, h)
		y = h - n
		if min_value < max_value:
			if i == current_level and editable:
				main_control.draw_rect(Rect2(Vector2(x, y), Vector2(w, n)), other_color)
			else:
				main_control.draw_rect(Rect2(Vector2(x, y), Vector2(w, n)), color)
		else:
			if i == current_level and editable:
				main_control.draw_rect(Rect2(Vector2(x, n), Vector2(w, y)), other_color)
			else:
				main_control.draw_rect(Rect2(Vector2(x, n), Vector2(w, y)), color)
		x += w


func _on_gui_input(event: InputEvent) -> void:
	if busy or disabled or !visible: return
	
	if !has_focus() and event is InputEventMouseButton:
		grab_focus()
		await get_tree().process_frame
		await get_tree().process_frame
		await get_tree().process_frame
	
	if !editable:
		if (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT) or (event is InputEventKey and event.scancode == KEY_ENTER):
			if event.is_pressed():
				emit_signal("clicked")
				get_viewport().set_input_as_handled()
	else:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			drawing = event.is_pressed()
			last_level = -1
			if drawing: change_value(event.position)
		elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.is_pressed():
			_value_clicked(event.position)
		elif event is InputEventMouseMotion:
			if drawing:
				change_value(event.position)
			elif Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
				_value_clicked(event.position)


func _value_clicked(mouse_pos : Vector2) -> void:
	var w : float = main_control.size.x / float(data.size() - initial_level)
	var level : int = max(initial_level, min(data.size() - 1, mouse_pos.x / w + initial_level))
	var value = data[level]
	current_level = level
	emit_signal("value_clicked", level, value)
	main_control.queue_redraw()


func change_value(mouse_pos : Vector2) -> void:
	var w : float = main_control.size.x / float(data.size() - initial_level)
	var level : int = max(initial_level, min(data.size() - 1, mouse_pos.x / w + initial_level))
	var h : float = main_control.size.y
	var _min_value : float = min(min_value, max_value)
	var _max_value : float = max(min_value, max_value)
#	var value = range_lerp(max(0, min(1, (h - mouse_pos.y) / h)), 0, 1, min_value, max_value)
	var value : float
	if min_value < max_value:
		value = remap(max(0, min(1, (h - mouse_pos.y) / h)), 0, 1, min_value, max_value)
	else:
		value = remap(max(0, min(1, (h - mouse_pos.y) / h)), 1, 0, max_value, min_value)
	if round_values:
		value = round(value)
	current_level = level
	if last_level != -1 and last_level != level:
		var min_level = min(level, last_level)
		var max_level = max(level, last_level)
		for i in range(min_level, max_level):
			data[i] = value
	else:
		data[level] = value
	last_level = level
	main_control.queue_redraw()
	get_viewport().set_input_as_handled()
	emit_signal("value_changed", level, value)


func set_text(text : String) -> void:
	if label:
		label.text = text
		label.visible = text.length() > 0


func _on_visibility_changed() -> void:
	if visible and !editable:
		pass
#		if DataManager.database_main_node and main_control.hint_tooltip.length() == 0:
#			if has_meta("tooltip") and get_meta("tooltip").length() > 0:
#				main_control.hint_tooltip = get_meta("tooltip")
#			else:
#				main_control.hint_tooltip = DataManager.translate_word("TOOLTIP1")
#			DataManager.database_main_node.set_custom_tooltip_to(main_control)


func update_data(_level : int, _value : int) -> void:
	if _level < data.size():
		data[_level] = _value
		current_level = _level
		main_control.queue_redraw()
		


func refresh() -> void:
	main_control.queue_redraw()


func _process(delta: float) -> void:
	if upgrade_delay > 0:
		upgrade_delay -= delta
		if upgrade_delay <= 0:
			if upgrade_button != 0:
				_mod_values(upgrade_button)
			elif exponential_button_enabled:
				exponential_button_enabled.call()
				


func _mod_values(value_added) -> void:
	for i in range(1, data.size()):
		data[i] = max(min_value, min(data[i] + value_added, max_value))
		if round_values:
			data[i] = round(data[i])
	
	main_control.queue_redraw()
	get_viewport().set_input_as_handled()
	emit_signal("value_changed", current_level, data[current_level])
	
	upgrade_button = value_added
	upgrade_delay = 0.11


func _on_upgrade_values_button_up() -> void:
	upgrade_button = 0


func _on_downgrade_values_button_up() -> void:
	upgrade_button = 0


func _on_downgrade_values_button_down() -> void:
	var value_added = max(1, max_value * (1 / 100.0))
	_mod_values(-value_added)


func _on_upgrade_values_button_down() -> void:
	var value_added = max(1, max_value * (1 / 100.0))
	_mod_values(value_added)


func _modify_exponential_percent(increase: bool, amount: float, inverse: bool) -> void:
	for i in range(1, data.size()):
		var level_ratio = float(i) / float(data.size())
		
		if inverse:
			level_ratio = 1.0 - level_ratio
		
		var exp_multiplier = 0.0001 + (amount - 0.0001) * pow(level_ratio, 2)
		
		var multiplier = 1.0 + exp_multiplier if increase else 1.0 - exp_multiplier
		
		data[i] = max(min_value, min(data[i] * multiplier, max_value))
		if round_values:
			data[i] = round(data[i])
	
	main_control.queue_redraw()
	get_viewport().set_input_as_handled()
	emit_signal("value_changed", current_level, data[current_level])
	
	upgrade_delay = 0.11


func set_buttons_disabled(value: bool) -> void:
	var node = $MarginContainer/HBoxContainer/VBoxContainer
	node.set_visible(value)


func _on_invert_curve_pressed() -> void:
	data.remove_at(0)
	data.reverse()
	data.insert(0, 0)
	main_control.queue_redraw()
	emit_signal("value_changed", current_level, data[current_level])


func _on_v_box_container_mouse_entered() -> void:
	cursor.visible = !editable


func _on_v_box_container_mouse_exited() -> void:
	cursor.visible = false


func set_disabled(value: bool) -> void:
	disabled = value
	if value:
		set_process_mode(Node.PROCESS_MODE_DISABLED)
		modulate.a = 0.6
	else:
		set_process_mode(Node.PROCESS_MODE_INHERIT)
		modulate.a = 1.0
	set_process_input(!value)


func _on_copy_curve_pressed() -> void:
	var resource_curve : Curve = Curve.new()
	var tolerance = 0.35
	var max_points : int = data.size() * tolerance
	var index_mod : float = data.size() / float(max_points)
	for i in range(0, max_points - 1):
		var index : int = index_mod * i
		var real_value = data[index]
		var resource_curve_value : float = remap(real_value, min_value, max_value, 0.0, 1.0)
		var resource_curve_index : float = remap(index, 0, data.size() - 1, 0.0, 1.0)
		var point = Vector2(resource_curve_index, resource_curve_value)
		resource_curve.add_point(point)
	
	StaticEditorVars.CLIPBOARD["stat_curve_preset"] = resource_curve
	%PasteCurve.set_disabled(false)


func _on_paste_curve_pressed() -> void:
	if not "stat_curve_preset" in StaticEditorVars.CLIPBOARD:
		return
		
	var mod: float = 1.0 / data.size()
	var x: float = 0.0
	for i in data.size():
		var v = StaticEditorVars.CLIPBOARD["stat_curve_preset"].sample(x)
		data[i] = remap(v, 0.0, 1.0, min_value, max_value)
		x += mod
	
	main_control.queue_redraw()
	emit_signal("value_changed", current_level, data[current_level])


func _on_upgrade_values_percent_button_down() -> void:
	exponential_button_enabled = _modify_exponential_percent.bind(true, 0.01, false)
	exponential_button_enabled.call()


func _on_downgrade_values_percent_button_down() -> void:
	exponential_button_enabled = _modify_exponential_percent.bind(false, 0.01, false)
	exponential_button_enabled.call()


func _on_upgrade_values_percent_button_up() -> void:
	exponential_button_enabled = Callable()


func _on_downgrade_values_percent_button_up() -> void:
	exponential_button_enabled = Callable()
