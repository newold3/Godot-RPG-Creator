@tool
class_name CommandGraphNode
extends GraphNode

const GraphCommandFormatter = preload("res://addons/CustomControls/Dialogs/EventGraphEditor/graph_command_formatter.gd")

var command: RPGEventCommand
var sub_commands: Array[RPGEventCommand] = []
var command_info: Dictionary = {}

var summary_label: Label
var quick_controls_box: Container
var edit_button: Button
var collapse_btn: Button
var content_vbox: VBoxContainer
var is_collapsed: bool = false

var _quick_widgets: Dictionary = {}

signal command_modified(node: CommandGraphNode)
signal request_delete(node: CommandGraphNode)
signal request_edit_dialog(node: CommandGraphNode)
signal collapse_changed(node: CommandGraphNode, is_collapsed: bool)


func _ready() -> void:
	resizable = false
	_setup_close_button()


func _setup_close_button() -> void:
	if has_method("get_titlebar_h_box"):
		var titlebar = call("get_titlebar_h_box")
		if titlebar and titlebar is Container:
			var close_btn = Button.new()
			close_btn.name = "CloseButton"
			close_btn.text = "×"
			close_btn.tooltip_text = "[title]Eliminar Nodo[/title]\nElimina este comando del grafo."
			close_btn.flat = true
			close_btn.focus_mode = Control.FOCUS_NONE
			close_btn.pressed.connect(func(): request_delete.emit(self))
			titlebar.add_child(close_btn)
	if has_signal("delete_request"):
		delete_request.connect(func(): request_delete.emit(self))


func setup(p_command: RPGEventCommand, p_sub_commands: Array[RPGEventCommand] = []) -> void:
	command = p_command
	sub_commands = p_sub_commands
	command_info = GraphCommandData.get_info_for_code(command.code)
	
	title = command_info.get("text", "Command %d" % command.code)
	var tip_str = command_info.get("tooltip", "")
	if not tip_str.is_empty():
		tooltip_text = "[title]%s[/title]\n%s" % [title, tip_str]
	else:
		tooltip_text = ""
	
	_build_ui()
	update_visuals()


func _build_ui() -> void:
	clear_all_slots()
	for child in get_children():
		remove_child(child)
		child.queue_free()
	
	custom_minimum_size = Vector2(280, 0)
	
	# Row 0: Flow Slot (In / Out)
	var flow_row = HBoxContainer.new()
	flow_row.name = "FlowRow"
	var in_label = Label.new()
	in_label.text = "▶ In"
	in_label.modulate = Color(0.7, 0.7, 0.7)
	in_label.add_theme_font_size_override("font_size", 12)
	
	collapse_btn = Button.new()
	collapse_btn.name = "CollapseButton"
	collapse_btn.text = "▶" if is_collapsed else "▼"
	collapse_btn.flat = true
	collapse_btn.tooltip_text = "[title]Contraer / Expandir Panel[/title]\nAlterna la visualización del contenido de este comando."
	collapse_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	collapse_btn.focus_mode = Control.FOCUS_NONE
	collapse_btn.pressed.connect(_on_collapse_toggled)
	
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var out_label = Label.new()
	out_label.text = "Out ▶"
	out_label.modulate = Color(0.4, 0.7, 1.0)
	out_label.add_theme_font_size_override("font_size", 12)
	
	flow_row.add_child(in_label)
	flow_row.add_child(collapse_btn)
	flow_row.add_child(spacer)
	flow_row.add_child(out_label)
	add_child(flow_row)
	
	# Slot 0 configuration
	set_slot(0, true, 0, Color(0.8, 0.8, 0.8), true, 0, Color(0.4, 0.7, 1.0))
	
	# Row 1: Content Box
	content_vbox = VBoxContainer.new()
	content_vbox.name = "ContentBox"
	content_vbox.add_theme_constant_override("separation", 5)
	content_vbox.custom_minimum_size = Vector2(260, 0)
	
	summary_label = Label.new()
	summary_label.name = "SummaryLabel"
	summary_label.custom_minimum_size = Vector2(260, 0)
	summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary_label.max_lines_visible = 3
	summary_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	summary_label.add_theme_font_size_override("font_size", 13)
	summary_label.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95))
	content_vbox.add_child(summary_label)
	
	# Quick Controls Container
	quick_controls_box = VBoxContainer.new()
	quick_controls_box.name = "QuickControlsBox"
	quick_controls_box.add_theme_constant_override("separation", 4)
	content_vbox.add_child(quick_controls_box)
	
	# Action buttons row
	var action_row = HBoxContainer.new()
	action_row.add_theme_constant_override("separation", 6)
	
	var btn_spacer = Control.new()
	btn_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	action_row.add_child(btn_spacer)
	
	if not command_info.get("dialog", "").is_empty():
		edit_button = Button.new()
		edit_button.name = "EditCommandButton"
		edit_button.text = "✏️ Edit..."
		edit_button.tooltip_text = "[title]Configuración Avanzada[/title]\nAbre la ventana de configuración detallada del comando."
		edit_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		edit_button.focus_mode = Control.FOCUS_NONE
		edit_button.add_theme_font_size_override("font_size", 12)
		edit_button.pressed.connect(func(): request_edit_dialog.emit(self))
		action_row.add_child(edit_button)

		
	content_vbox.add_child(action_row)
	add_child(content_vbox)
	
	# Slot 1 is not a connection port
	set_slot(1, false, 0, Color.TRANSPARENT, false, 0, Color.TRANSPARENT)
	
	_build_quick_controls()
	if is_collapsed:
		set_collapsed(true, false)


func set_collapsed(p_collapsed: bool, emit_sig: bool = true) -> void:
	is_collapsed = p_collapsed
	if collapse_btn:
		collapse_btn.text = "▶" if is_collapsed else "▼"
	if content_vbox:
		content_vbox.visible = !is_collapsed
	if is_collapsed:
		custom_minimum_size = Vector2(200, 0)
	else:
		custom_minimum_size = Vector2(280, 0)
	size = Vector2.ZERO
	if emit_sig:
		collapse_changed.emit(self, is_collapsed)


func _on_collapse_toggled() -> void:
	set_collapsed(!is_collapsed, true)


func update_visuals() -> void:
	if not command:
		return
		
	var code = command.code
	
	# If code is text-based (2, 10, 31, 34), summary label displays header info to avoid duplicating text
	if code == 2:
		summary_label.text = GraphCommandFormatter.get_header_for_text_command(command)
	elif code == 10:
		summary_label.text = "Scrolling Text (Speed %s):" % command.parameters.get("scroll_speed", 2)
	elif code == 31:
		summary_label.text = "Comment Note:"
	elif code == 34:
		summary_label.text = "Instant Text Message:"
	else:
		summary_label.text = GraphCommandFormatter.get_formatted_text(command, sub_commands)
		
	_update_quick_controls_values()
	size = Vector2.ZERO


func _build_quick_controls() -> void:
	_quick_widgets.clear()
	for child in quick_controls_box.get_children():
		child.queue_free()
		
	var code = command.code
	var p = command.parameters
	
	match code:
		2: # Dialog Text: Inline TextEdit for quick message typing
			var te = TextEdit.new()
			te.custom_minimum_size = Vector2(260, 68)
			te.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
			te.add_theme_font_size_override("font_size", 13)
			te.placeholder_text = "Escribe el texto del mensaje..."
			
			var lines: Array[String] = []
			for sub in sub_commands:
				if sub.code == 3:
					lines.append(sub.parameters.get("line", ""))
			te.text = "\n".join(lines)
			
			te.text_changed.connect(func():
				sub_commands.clear()
				for line in te.text.split("\n"):
					var sub_cmd = RPGEventCommand.new(3, command.indent, {"line": line})
					sub_commands.append(sub_cmd)
				command_modified.emit(self)
			)
			quick_controls_box.add_child(te)
			_quick_widgets["text_edit"] = te
			
		10: # Scrolling Text
			var te = TextEdit.new()
			te.custom_minimum_size = Vector2(260, 60)
			te.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
			te.add_theme_font_size_override("font_size", 13)
			te.placeholder_text = "Texto con scroll..."
			
			var lines: Array[String] = []
			for sub in sub_commands:
				if sub.code == 11:
					lines.append(sub.parameters.get("line", ""))
			te.text = "\n".join(lines)
			
			te.text_changed.connect(func():
				sub_commands.clear()
				for line in te.text.split("\n"):
					sub_commands.append(RPGEventCommand.new(11, command.indent, {"line": line}))
				command_modified.emit(self)
			)
			quick_controls_box.add_child(te)
			_quick_widgets["text_edit"] = te
			
		31: # Comment
			var te = TextEdit.new()
			te.custom_minimum_size = Vector2(260, 56)
			te.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
			te.add_theme_font_size_override("font_size", 12)
			te.placeholder_text = "Comentario / nota..."
			
			var full_lines = [p.get("first_line", "")]
			for sub in sub_commands:
				if sub.code == 32:
					full_lines.append(sub.parameters.get("line", ""))
			te.text = "\n".join(full_lines).strip_edges()
			
			te.text_changed.connect(func():
				var split_lines = te.text.split("\n")
				command.parameters["first_line"] = split_lines[0] if split_lines.size() > 0 else ""
				sub_commands.clear()
				for idx in range(1, split_lines.size()):
					sub_commands.append(RPGEventCommand.new(32, command.indent, {"line": split_lines[idx]}))
				command_modified.emit(self)
			)
			quick_controls_box.add_child(te)
			_quick_widgets["text_edit"] = te
			
		34: # Instant Text
			var te = TextEdit.new()
			te.custom_minimum_size = Vector2(260, 60)
			te.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
			te.add_theme_font_size_override("font_size", 13)
			te.placeholder_text = "Texto instantáneo..."
			
			var full_lines = [p.get("first_line", "")]
			for sub in sub_commands:
				if sub.code == 35:
					full_lines.append(sub.parameters.get("line", ""))
			te.text = "\n".join(full_lines).strip_edges()
			
			te.text_changed.connect(func():
				var split_lines = te.text.split("\n")
				command.parameters["first_line"] = split_lines[0] if split_lines.size() > 0 else ""
				sub_commands.clear()
				for idx in range(1, split_lines.size()):
					sub_commands.append(RPGEventCommand.new(35, command.indent, {"line": split_lines[idx]}))
				command_modified.emit(self)
			)
			quick_controls_box.add_child(te)
			_quick_widgets["text_edit"] = te
			
		17: # Global Switch
			var row = HBoxContainer.new()
			var lbl = Label.new()
			lbl.text = "Switch ID:"
			lbl.add_theme_font_size_override("font_size", 12)
			
			var id_spin = SpinBox.new()
			id_spin.min_value = 1
			id_spin.max_value = 9999
			id_spin.value = p.get("from", 1)
			id_spin.value_changed.connect(func(val):
				command.parameters["from"] = int(val)
				command.parameters["to"] = int(val)
				update_visuals()
				command_modified.emit(self)
			)
			
			var state_opt = OptionButton.new()
			state_opt.add_item("ON", 0)
			state_opt.add_item("OFF", 1)
			state_opt.select(p.get("operation_type", 0))
			state_opt.item_selected.connect(func(idx):
				command.parameters["operation_type"] = idx
				update_visuals()
				command_modified.emit(self)
			)
			
			row.add_child(lbl)
			row.add_child(id_spin)
			row.add_child(state_opt)
			quick_controls_box.add_child(row)
			_quick_widgets["switch_id"] = id_spin
			_quick_widgets["switch_state"] = state_opt
			
		18: # Variable
			var row1 = HBoxContainer.new()
			var lbl = Label.new()
			lbl.text = "Var ID:"
			lbl.add_theme_font_size_override("font_size", 12)
			
			var id_spin = SpinBox.new()
			id_spin.min_value = 1
			id_spin.max_value = 9999
			id_spin.value = p.get("from", 1)
			id_spin.value_changed.connect(func(val):
				command.parameters["from"] = int(val)
				command.parameters["to"] = int(val)
				update_visuals()
				command_modified.emit(self)
			)
			
			var op_opt = OptionButton.new()
			var ops = ["=", "+=", "-=", "*=", "/=", "%="]
			for idx in range(ops.size()):
				op_opt.add_item(ops[idx], idx)
			op_opt.select(min(p.get("operation_type", 0), 5))
			op_opt.item_selected.connect(func(idx):
				command.parameters["operation_type"] = idx
				update_visuals()
				command_modified.emit(self)
			)
			
			var val_spin = SpinBox.new()
			val_spin.min_value = -9999999
			val_spin.max_value = 9999999
			val_spin.value = p.get("value1", 0)
			val_spin.value_changed.connect(func(val):
				command.parameters["operand_type"] = 0
				command.parameters["value1"] = int(val)
				update_visuals()
				command_modified.emit(self)
			)
			
			row1.add_child(lbl)
			row1.add_child(id_spin)
			row1.add_child(op_opt)
			row1.add_child(val_spin)
			quick_controls_box.add_child(row1)
			_quick_widgets["var_id"] = id_spin
			_quick_widgets["var_op"] = op_opt
			_quick_widgets["var_val"] = val_spin
			
		19: # Local Switch
			var row = HBoxContainer.new()
			var lbl = Label.new()
			lbl.text = "Self Switch:"
			lbl.add_theme_font_size_override("font_size", 12)
			
			var sw_opt = OptionButton.new()
			sw_opt.add_item("A", 0)
			sw_opt.add_item("B", 1)
			sw_opt.add_item("C", 2)
			sw_opt.add_item("D", 3)
			sw_opt.select(p.get("switch_id", 0))
			sw_opt.item_selected.connect(func(idx):
				command.parameters["switch_id"] = idx
				update_visuals()
				command_modified.emit(self)
			)
			
			var state_opt = OptionButton.new()
			state_opt.add_item("ON", 0)
			state_opt.add_item("OFF", 1)
			state_opt.select(p.get("operation_type", 0))
			state_opt.item_selected.connect(func(idx):
				command.parameters["operation_type"] = idx
				update_visuals()
				command_modified.emit(self)
			)
			
			row.add_child(lbl)
			row.add_child(sw_opt)
			row.add_child(state_opt)
			quick_controls_box.add_child(row)
			_quick_widgets["self_sw"] = sw_opt
			_quick_widgets["self_state"] = state_opt
			
		33: # Wait
			var row = HBoxContainer.new()
			var lbl = Label.new()
			lbl.text = "Frames:"
			lbl.add_theme_font_size_override("font_size", 12)
			
			var spin = SpinBox.new()
			spin.min_value = 1
			spin.max_value = 3600
			spin.value = p.get("duration", 60)
			
			var sec_lbl = Label.new()
			sec_lbl.text = "(%.2fs)" % (float(spin.value) / 60.0)
			sec_lbl.add_theme_font_size_override("font_size", 12)
			sec_lbl.modulate = Color(0.7, 0.7, 0.7)
			
			spin.value_changed.connect(func(val):
				command.parameters["duration"] = int(val)
				sec_lbl.text = "(%.2fs)" % (float(val) / 60.0)
				update_visuals()
				command_modified.emit(self)
			)
			row.add_child(lbl)
			row.add_child(spin)
			row.add_child(sec_lbl)
			quick_controls_box.add_child(row)
			_quick_widgets["wait_spin"] = spin
			
		12: # Gold
			var row = HBoxContainer.new()
			var op_opt = OptionButton.new()
			op_opt.add_item("+ Add", 0)
			op_opt.add_item("- Sub", 1)
			op_opt.select(p.get("operation_type", 0))
			op_opt.item_selected.connect(func(idx):
				command.parameters["operation_type"] = idx
				update_visuals()
				command_modified.emit(self)
			)
			
			var spin = SpinBox.new()
			spin.min_value = 1
			spin.max_value = 9999999
			spin.value = p.get("value", 100)
			spin.value_changed.connect(func(val):
				command.parameters["value"] = int(val)
				update_visuals()
				command_modified.emit(self)
			)
			row.add_child(op_opt)
			row.add_child(spin)
			quick_controls_box.add_child(row)
			_quick_widgets["gold_op"] = op_opt
			_quick_widgets["gold_val"] = spin
			
		13, 14, 15: # Items / Weapons / Armors
			var row = HBoxContainer.new()
			var id_spin = SpinBox.new()
			id_spin.min_value = 1
			id_spin.max_value = 9999
			id_spin.value = p.get("item_id", 1)
			id_spin.value_changed.connect(func(val):
				command.parameters["item_id"] = int(val)
				update_visuals()
				command_modified.emit(self)
			)
			
			var op_opt = OptionButton.new()
			op_opt.add_item("+", 0)
			op_opt.add_item("-", 1)
			op_opt.select(p.get("operation_type", 0))
			op_opt.item_selected.connect(func(idx):
				command.parameters["operation_type"] = idx
				update_visuals()
				command_modified.emit(self)
			)
			
			var qty_spin = SpinBox.new()
			qty_spin.min_value = 1
			qty_spin.max_value = 999
			qty_spin.value = p.get("value", 1)
			qty_spin.value_changed.connect(func(val):
				command.parameters["value"] = int(val)
				update_visuals()
				command_modified.emit(self)
			)
			row.add_child(id_spin)
			row.add_child(op_opt)
			row.add_child(qty_spin)
			quick_controls_box.add_child(row)
			_quick_widgets["item_id"] = id_spin
			_quick_widgets["item_op"] = op_opt
			_quick_widgets["item_qty"] = qty_spin
			
		20: # Set Timer
			var row = HBoxContainer.new()
			var op_opt = OptionButton.new()
			op_opt.add_item("Start", 0)
			op_opt.add_item("Stop", 1)
			op_opt.select(p.get("operation_type", 0))
			
			var min_spin = SpinBox.new()
			min_spin.min_value = 0
			min_spin.max_value = 99
			min_spin.value = p.get("minutes", 0)
			
			var sec_spin = SpinBox.new()
			sec_spin.min_value = 0
			sec_spin.max_value = 59
			sec_spin.value = p.get("seconds", 0)
			
			var on_change = func():
				command.parameters["operation_type"] = op_opt.selected
				command.parameters["minutes"] = int(min_spin.value)
				command.parameters["seconds"] = int(sec_spin.value)
				min_spin.visible = (op_opt.selected == 0)
				sec_spin.visible = (op_opt.selected == 0)
				update_visuals()
				command_modified.emit(self)
				
			op_opt.item_selected.connect(func(_idx): on_change.call())
			min_spin.value_changed.connect(func(_v): on_change.call())
			sec_spin.value_changed.connect(func(_v): on_change.call())
			
			min_spin.visible = (op_opt.selected == 0)
			sec_spin.visible = (op_opt.selected == 0)
			
			row.add_child(op_opt)
			row.add_child(min_spin)
			row.add_child(sec_spin)
			quick_controls_box.add_child(row)
			_quick_widgets["timer_op"] = op_opt
			_quick_widgets["timer_min"] = min_spin
			_quick_widgets["timer_sec"] = sec_spin
			
		29, 30: # Label / Jump To Label
			var edit = LineEdit.new()
			edit.placeholder_text = "Label name..."
			edit.text = p.get("text", "")
			edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			edit.text_changed.connect(func(new_text):
				command.parameters["text"] = new_text
				update_visuals()
				command_modified.emit(self)
			)
			quick_controls_box.add_child(edit)
			_quick_widgets["label_edit"] = edit
			
		5000: # Script
			var te = TextEdit.new()
			te.custom_minimum_size = Vector2(260, 75)
			te.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
			te.add_theme_font_size_override("font_size", 12)
			te.placeholder_text = "# Script GDScript..."
			te.text = p.get("script", "")
			te.text_changed.connect(func():
				command.parameters["script"] = te.text
				command_modified.emit(self)
			)
			quick_controls_box.add_child(te)
			_quick_widgets["script_edit"] = te


		1: # Message Config
			var row = HBoxContainer.new()
			var lbl = Label.new()
			lbl.text = "Skip:"
			lbl.add_theme_font_size_override("font_size", 12)
			var skip_opt = OptionButton.new()
			skip_opt.add_item("Normal", 0)
			skip_opt.add_item("Instant", 1)
			skip_opt.select(p.get("skip_mode", 0))
			skip_opt.item_selected.connect(func(idx):
				command.parameters["skip_mode"] = idx
				update_visuals()
				command_modified.emit(self)
			)
			var delay_spin = SpinBox.new()
			delay_spin.step = 0.005
			delay_spin.min_value = 0.0
			delay_spin.max_value = 1.0
			delay_spin.value = p.get("character_delay", 0.03)
			delay_spin.prefix = "Delay:"
			delay_spin.value_changed.connect(func(val):
				command.parameters["character_delay"] = val
				update_visuals()
				command_modified.emit(self)
			)
			row.add_child(lbl)
			row.add_child(skip_opt)
			row.add_child(delay_spin)
			quick_controls_box.add_child(row)
			_quick_widgets["msg_skip"] = skip_opt
			_quick_widgets["msg_delay"] = delay_spin

		8: # Input Number/Text
			var row = HBoxContainer.new()
			var type_opt = OptionButton.new()
			type_opt.add_item("Number", 0)
			type_opt.add_item("Text", 1)
			type_opt.select(p.get("type", 0))
			var var_spin = SpinBox.new()
			var_spin.min_value = 1
			var_spin.max_value = 9999
			var_spin.value = p.get("variable_id", 1)
			var_spin.prefix = "Var:"
			var digits_spin = SpinBox.new()
			digits_spin.min_value = 1
			digits_spin.max_value = 64
			digits_spin.value = p.get("digits", 1)
			digits_spin.prefix = "Digits:"
			var on_change = func():
				command.parameters["type"] = type_opt.selected
				command.parameters["variable_id"] = int(var_spin.value)
				command.parameters["digits"] = int(digits_spin.value)
				update_visuals()
				command_modified.emit(self)
			type_opt.item_selected.connect(func(_x): on_change.call())
			var_spin.value_changed.connect(func(_x): on_change.call())
			digits_spin.value_changed.connect(func(_x): on_change.call())
			row.add_child(type_opt)
			row.add_child(var_spin)
			row.add_child(digits_spin)
			quick_controls_box.add_child(row)
			_quick_widgets["input_type"] = type_opt
			_quick_widgets["input_var"] = var_spin
			_quick_widgets["input_digits"] = digits_spin

		9: # Select Item
			var row = HBoxContainer.new()
			var var_spin = SpinBox.new()
			var_spin.min_value = 1
			var_spin.max_value = 9999
			var_spin.value = p.get("variable_id", 1)
			var_spin.prefix = "Save in Var:"
			var type_opt = OptionButton.new()
			type_opt.add_item("Regular", 1)
			type_opt.add_item("Key Item", 2)
			type_opt.add_item("Hidden A", 3)
			type_opt.add_item("Hidden B", 4)
			type_opt.select(clamp(p.get("item_type", 1) - 1, 0, 3))
			var on_change = func():
				command.parameters["variable_id"] = int(var_spin.value)
				command.parameters["item_type"] = type_opt.selected + 1
				update_visuals()
				command_modified.emit(self)
			var_spin.value_changed.connect(func(_x): on_change.call())
			type_opt.item_selected.connect(func(_x): on_change.call())
			row.add_child(var_spin)
			row.add_child(type_opt)
			quick_controls_box.add_child(row)
			_quick_widgets["sel_item_var"] = var_spin
			_quick_widgets["sel_item_type"] = type_opt

		16: # Party Member
			var row = HBoxContainer.new()
			var actor_spin = SpinBox.new()
			actor_spin.min_value = 1
			actor_spin.max_value = 9999
			actor_spin.value = p.get("actor_id", 1)
			actor_spin.prefix = "Actor:"
			var op_opt = OptionButton.new()
			op_opt.add_item("+ Add", 0)
			op_opt.add_item("- Remove", 1)
			op_opt.select(p.get("operation_type", 0))
			var init_chk = CheckBox.new()
			init_chk.text = "Init"
			init_chk.set_pressed_no_signal(p.get("initialize", false))
			var on_change = func():
				command.parameters["actor_id"] = int(actor_spin.value)
				command.parameters["operation_type"] = op_opt.selected
				command.parameters["initialize"] = init_chk.is_pressed()
				update_visuals()
				command_modified.emit(self)
			actor_spin.value_changed.connect(func(_x): on_change.call())
			op_opt.item_selected.connect(func(_x): on_change.call())
			init_chk.toggled.connect(func(_x): on_change.call())
			row.add_child(actor_spin)
			row.add_child(op_opt)
			row.add_child(init_chk)
			quick_controls_box.add_child(row)
			_quick_widgets["party_actor"] = actor_spin
			_quick_widgets["party_op"] = op_opt
			_quick_widgets["party_init"] = init_chk

		28: # Common Event
			var row = HBoxContainer.new()
			var spin = SpinBox.new()
			spin.min_value = 1
			spin.max_value = 9999
			spin.value = p.get("id", 1)
			spin.prefix = "Common Event ID:"
			spin.value_changed.connect(func(val):
				command.parameters["id"] = int(val)
				update_visuals()
				command_modified.emit(self)
			)
			row.add_child(spin)
			quick_controls_box.add_child(row)
			_quick_widgets["common_id"] = spin

		36: # Change Leader
			var row = HBoxContainer.new()
			var spin = SpinBox.new()
			spin.min_value = 1
			spin.max_value = 9999
			spin.value = p.get("leader_id", 1)
			spin.prefix = "Leader ID:"
			var lock_chk = CheckBox.new()
			lock_chk.text = "Lock"
			lock_chk.set_pressed_no_signal(p.get("is_locked", false))
			var on_change = func():
				command.parameters["leader_id"] = int(spin.value)
				command.parameters["is_locked"] = lock_chk.is_pressed()
				update_visuals()
				command_modified.emit(self)
			spin.value_changed.connect(func(_x): on_change.call())
			lock_chk.toggled.connect(func(_x): on_change.call())
			row.add_child(spin)
			row.add_child(lock_chk)
			quick_controls_box.add_child(row)
			_quick_widgets["leader_id"] = spin
			_quick_widgets["leader_lock"] = lock_chk

		37, 38, 39: # Actor HP / MP / TP
			var row = HBoxContainer.new()
			var actor_spin = SpinBox.new()
			actor_spin.min_value = 0
			actor_spin.max_value = 9999
			actor_spin.value = p.get("actor_id", 0)
			actor_spin.prefix = "Actor(0=All):"
			var op_opt = OptionButton.new()
			op_opt.add_item("+ Inc", 0)
			op_opt.add_item("- Dec", 1)
			op_opt.select(p.get("operand", 0))
			var val_spin = SpinBox.new()
			val_spin.min_value = 1
			val_spin.max_value = 9999999
			val_spin.value = p.get("operand_value", 1)
			var on_change = func():
				command.parameters["actor_id"] = int(actor_spin.value)
				command.parameters["actor_type"] = 0
				command.parameters["operand"] = op_opt.selected
				command.parameters["operand_type"] = 0
				command.parameters["operand_value"] = int(val_spin.value)
				update_visuals()
				command_modified.emit(self)
			actor_spin.value_changed.connect(func(_x): on_change.call())
			op_opt.item_selected.connect(func(_x): on_change.call())
			val_spin.value_changed.connect(func(_x): on_change.call())
			row.add_child(actor_spin)
			row.add_child(op_opt)
			row.add_child(val_spin)
			quick_controls_box.add_child(row)
			_quick_widgets["param_actor"] = actor_spin
			_quick_widgets["param_op"] = op_opt
			_quick_widgets["param_val"] = val_spin

		40: # State
			var row = HBoxContainer.new()
			var actor_spin = SpinBox.new()
			actor_spin.min_value = 0
			actor_spin.max_value = 9999
			actor_spin.value = p.get("actor_id", 0)
			actor_spin.prefix = "Actor:"
			var op_opt = OptionButton.new()
			op_opt.add_item("+ Add", 0)
			op_opt.add_item("- Remove", 1)
			op_opt.select(p.get("operand", 0))
			var state_spin = SpinBox.new()
			state_spin.min_value = 1
			state_spin.max_value = 9999
			state_spin.value = p.get("state_id", 1)
			state_spin.prefix = "State:"
			var on_change = func():
				command.parameters["actor_id"] = int(actor_spin.value)
				command.parameters["operand"] = op_opt.selected
				command.parameters["state_id"] = int(state_spin.value)
				update_visuals()
				command_modified.emit(self)
			actor_spin.value_changed.connect(func(_x): on_change.call())
			op_opt.item_selected.connect(func(_x): on_change.call())
			state_spin.value_changed.connect(func(_x): on_change.call())
			row.add_child(actor_spin)
			row.add_child(op_opt)
			row.add_child(state_spin)
			quick_controls_box.add_child(row)
			_quick_widgets["state_actor"] = actor_spin
			_quick_widgets["state_op"] = op_opt
			_quick_widgets["state_id"] = state_spin

		41: # Recover All
			var row = HBoxContainer.new()
			var actor_spin = SpinBox.new()
			actor_spin.min_value = 0
			actor_spin.max_value = 9999
			actor_spin.value = p.get("actor_id", 0)
			actor_spin.prefix = "Actor (0=Entire Party):"
			actor_spin.value_changed.connect(func(val):
				command.parameters["actor_id"] = int(val)
				update_visuals()
				command_modified.emit(self)
			)
			row.add_child(actor_spin)
			quick_controls_box.add_child(row)
			_quick_widgets["recover_actor"] = actor_spin

		42, 43, 44: # XP / Level / Parameter
			var row = HBoxContainer.new()
			var actor_spin = SpinBox.new()
			actor_spin.min_value = 0
			actor_spin.max_value = 9999
			actor_spin.value = p.get("actor_id", 0)
			actor_spin.prefix = "Actor:"
			var op_opt = OptionButton.new()
			op_opt.add_item("+ Inc", 0)
			op_opt.add_item("- Dec", 1)
			op_opt.select(p.get("operand", 0))
			var val_spin = SpinBox.new()
			val_spin.min_value = 1
			val_spin.max_value = 9999999
			val_spin.value = p.get("operand_value", 1)
			var on_change = func():
				command.parameters["actor_id"] = int(actor_spin.value)
				command.parameters["operand"] = op_opt.selected
				command.parameters["operand_value"] = int(val_spin.value)
				update_visuals()
				command_modified.emit(self)
			actor_spin.value_changed.connect(func(_x): on_change.call())
			op_opt.item_selected.connect(func(_x): on_change.call())
			val_spin.value_changed.connect(func(_x): on_change.call())
			row.add_child(actor_spin)
			row.add_child(op_opt)
			row.add_child(val_spin)
			quick_controls_box.add_child(row)
			_quick_widgets["stat_actor"] = actor_spin
			_quick_widgets["stat_op"] = op_opt
			_quick_widgets["stat_val"] = val_spin

		45: # Skill
			var row = HBoxContainer.new()
			var actor_spin = SpinBox.new()
			actor_spin.min_value = 0
			actor_spin.max_value = 9999
			actor_spin.value = p.get("actor_id", 0)
			actor_spin.prefix = "Actor:"
			var op_opt = OptionButton.new()
			op_opt.add_item("Learn", 0)
			op_opt.add_item("Forget", 1)
			op_opt.select(p.get("operand", 0))
			var skill_spin = SpinBox.new()
			skill_spin.min_value = 1
			skill_spin.max_value = 9999
			skill_spin.value = p.get("skill_id", 1)
			skill_spin.prefix = "Skill:"
			var on_change = func():
				command.parameters["actor_id"] = int(actor_spin.value)
				command.parameters["operand"] = op_opt.selected
				command.parameters["skill_id"] = int(skill_spin.value)
				update_visuals()
				command_modified.emit(self)
			actor_spin.value_changed.connect(func(_x): on_change.call())
			op_opt.item_selected.connect(func(_x): on_change.call())
			skill_spin.value_changed.connect(func(_x): on_change.call())
			row.add_child(actor_spin)
			row.add_child(op_opt)
			row.add_child(skill_spin)
			quick_controls_box.add_child(row)
			_quick_widgets["skill_actor"] = actor_spin
			_quick_widgets["skill_op"] = op_opt
			_quick_widgets["skill_id"] = skill_spin

		47: # Actor Name
			var row = HBoxContainer.new()
			var actor_spin = SpinBox.new()
			actor_spin.min_value = 1
			actor_spin.max_value = 9999
			actor_spin.value = p.get("actor_id", 1)
			actor_spin.prefix = "Actor:"
			var name_edit = LineEdit.new()
			name_edit.placeholder_text = "New name..."
			name_edit.text = p.get("name", "")
			name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var on_change = func():
				command.parameters["actor_id"] = int(actor_spin.value)
				command.parameters["name"] = name_edit.text
				update_visuals()
				command_modified.emit(self)
			actor_spin.value_changed.connect(func(_x): on_change.call())
			name_edit.text_changed.connect(func(_x): on_change.call())
			row.add_child(actor_spin)
			row.add_child(name_edit)
			quick_controls_box.add_child(row)
			_quick_widgets["name_actor"] = actor_spin
			_quick_widgets["name_text"] = name_edit

		48: # Class
			var row = HBoxContainer.new()
			var actor_spin = SpinBox.new()
			actor_spin.min_value = 1
			actor_spin.max_value = 9999
			actor_spin.value = p.get("actor_id", 1)
			actor_spin.prefix = "Actor:"
			var class_spin = SpinBox.new()
			class_spin.min_value = 1
			class_spin.max_value = 9999
			class_spin.value = p.get("class_id", 1)
			class_spin.prefix = "Class:"
			var keep_chk = CheckBox.new()
			keep_chk.text = "Keep Lvl"
			keep_chk.set_pressed_no_signal(p.get("keep_level", false))
			var on_change = func():
				command.parameters["actor_id"] = int(actor_spin.value)
				command.parameters["class_id"] = int(class_spin.value)
				command.parameters["keep_level"] = keep_chk.is_pressed()
				update_visuals()
				command_modified.emit(self)
			actor_spin.value_changed.connect(func(_x): on_change.call())
			class_spin.value_changed.connect(func(_x): on_change.call())
			keep_chk.toggled.connect(func(_x): on_change.call())
			row.add_child(actor_spin)
			row.add_child(class_spin)
			row.add_child(keep_chk)
			quick_controls_box.add_child(row)
			_quick_widgets["class_actor"] = actor_spin
			_quick_widgets["class_id"] = class_spin
			_quick_widgets["class_keep"] = keep_chk

		49: # Nickname
			var row = HBoxContainer.new()
			var actor_spin = SpinBox.new()
			actor_spin.min_value = 1
			actor_spin.max_value = 9999
			actor_spin.value = p.get("actor_id", 1)
			actor_spin.prefix = "Actor:"
			var nick_edit = LineEdit.new()
			nick_edit.placeholder_text = "New nickname..."
			nick_edit.text = p.get("nickname", "")
			nick_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var on_change = func():
				command.parameters["actor_id"] = int(actor_spin.value)
				command.parameters["nickname"] = nick_edit.text
				update_visuals()
				command_modified.emit(self)
			actor_spin.value_changed.connect(func(_x): on_change.call())
			nick_edit.text_changed.connect(func(_x): on_change.call())
			row.add_child(actor_spin)
			row.add_child(nick_edit)
			quick_controls_box.add_child(row)
			_quick_widgets["nick_actor"] = actor_spin
			_quick_widgets["nick_text"] = nick_edit

		53: # Transfer Player / Vehicle / Event
			var row = HBoxContainer.new()
			var target_opt = OptionButton.new()
			target_opt.add_item("Player", 0)
			target_opt.add_item("Vehicle", 1)
			target_opt.add_item("Event", 2)
			target_opt.select(p.get("target", 0))
			var dir_opt = OptionButton.new()
			var dirs = ["Retain", "Down", "Left", "Right", "Up"]
			for d in range(dirs.size()): dir_opt.add_item(dirs[d], d)
			dir_opt.select(min(p.get("direction", 0), 4))
			var val_dict = p.get("value", {})
			var map_spin = SpinBox.new()
			map_spin.min_value = 0
			map_spin.max_value = 9999
			map_spin.value = val_dict.get("assigned_map_id", 0)
			map_spin.prefix = "Map:"
			var x_spin = SpinBox.new()
			x_spin.min_value = 0
			x_spin.max_value = 9999
			x_spin.value = val_dict.get("assigned_x", 0)
			x_spin.prefix = "X:"
			var y_spin = SpinBox.new()
			y_spin.min_value = 0
			y_spin.max_value = 9999
			y_spin.value = val_dict.get("assigned_y", 0)
			y_spin.prefix = "Y:"
			var on_change = func():
				command.parameters["target"] = target_opt.selected
				command.parameters["direction"] = dir_opt.selected
				if not command.parameters.has("value"):
					command.parameters["value"] = {}
				command.parameters["value"]["assigned_map_id"] = int(map_spin.value)
				command.parameters["value"]["assigned_x"] = int(x_spin.value)
				command.parameters["value"]["assigned_y"] = int(y_spin.value)
				update_visuals()
				command_modified.emit(self)
			target_opt.item_selected.connect(func(_x): on_change.call())
			dir_opt.item_selected.connect(func(_x): on_change.call())
			map_spin.value_changed.connect(func(_x): on_change.call())
			x_spin.value_changed.connect(func(_x): on_change.call())
			y_spin.value_changed.connect(func(_x): on_change.call())
			row.add_child(target_opt)
			row.add_child(dir_opt)
			row.add_child(map_spin)
			row.add_child(x_spin)
			row.add_child(y_spin)
			quick_controls_box.add_child(row)
			_quick_widgets["transfer_target"] = target_opt
			_quick_widgets["transfer_dir"] = dir_opt
			_quick_widgets["transfer_map"] = map_spin
			_quick_widgets["transfer_x"] = x_spin
			_quick_widgets["transfer_y"] = y_spin

		61: # Text Variable
			var row = HBoxContainer.new()
			var var_spin = SpinBox.new()
			var_spin.min_value = 1
			var_spin.max_value = 9999
			var_spin.value = p.get("id", 1)
			var_spin.prefix = "TextVar:"
			var txt_edit = LineEdit.new()
			txt_edit.placeholder_text = "Value..."
			txt_edit.text = p.get("value", "")
			txt_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var on_change = func():
				command.parameters["id"] = int(var_spin.value)
				command.parameters["value"] = txt_edit.text
				update_visuals()
				command_modified.emit(self)
			var_spin.value_changed.connect(func(_x): on_change.call())
			txt_edit.text_changed.connect(func(_x): on_change.call())
			row.add_child(var_spin)
			row.add_child(txt_edit)
			quick_controls_box.add_child(row)
			_quick_widgets["text_var_id"] = var_spin
			_quick_widgets["text_var_val"] = txt_edit

		63, 64: # Fade Out / Fade In
			var row = HBoxContainer.new()
			var spin = SpinBox.new()
			spin.step = 0.05
			spin.min_value = 0.05
			spin.max_value = 60.0
			spin.value = p.get("duration", 0.5)
			spin.prefix = "Duration (s):"
			spin.value_changed.connect(func(val):
				command.parameters["duration"] = val
				update_visuals()
				command_modified.emit(self)
			)
			row.add_child(spin)
			quick_controls_box.add_child(row)
			_quick_widgets["fade_spin"] = spin

		65, 66: # Tint Screen / Flash
			var row = HBoxContainer.new()
			var color_btn = ColorPickerButton.new()
			color_btn.custom_minimum_size = Vector2(40, 20)
			color_btn.color = p.get("color", Color.WHITE)
			var dur_spin = SpinBox.new()
			dur_spin.step = 0.05
			dur_spin.min_value = 0.05
			dur_spin.max_value = 60.0
			dur_spin.value = p.get("duration", 0.5)
			dur_spin.prefix = "Sec:"
			var wait_chk = CheckBox.new()
			wait_chk.text = "Wait"
			wait_chk.set_pressed_no_signal(p.get("wait", false))
			var on_change = func():
				command.parameters["color"] = color_btn.color
				command.parameters["duration"] = dur_spin.value
				command.parameters["wait"] = wait_chk.is_pressed()
				update_visuals()
				command_modified.emit(self)
			color_btn.color_changed.connect(func(_x): on_change.call())
			dur_spin.value_changed.connect(func(_x): on_change.call())
			wait_chk.toggled.connect(func(_x): on_change.call())
			row.add_child(color_btn)
			row.add_child(dur_spin)
			row.add_child(wait_chk)
			quick_controls_box.add_child(row)
			_quick_widgets["tint_color"] = color_btn
			_quick_widgets["tint_dur"] = dur_spin
			_quick_widgets["tint_wait"] = wait_chk

		67: # Shake Screen
			var row = HBoxContainer.new()
			var pow_spin = SpinBox.new()
			pow_spin.min_value = 100
			pow_spin.max_value = 20000
			pow_spin.step = 100
			pow_spin.value = p.get("power", 4500)
			pow_spin.prefix = "Power:"
			var dur_spin = SpinBox.new()
			dur_spin.step = 0.05
			dur_spin.min_value = 0.05
			dur_spin.max_value = 60.0
			dur_spin.value = p.get("duration", 0.5)
			dur_spin.prefix = "Duration(s):"
			var on_change = func():
				command.parameters["power"] = pow_spin.value
				command.parameters["duration"] = dur_spin.value
				update_visuals()
				command_modified.emit(self)
			pow_spin.value_changed.connect(func(_x): on_change.call())
			dur_spin.value_changed.connect(func(_x): on_change.call())
			row.add_child(pow_spin)
			row.add_child(dur_spin)
			quick_controls_box.add_child(row)
			_quick_widgets["shake_pow"] = pow_spin
			_quick_widgets["shake_dur"] = dur_spin

		68: # Weather
			var row = HBoxContainer.new()
			var type_opt = OptionButton.new()
			type_opt.add_item("+ Add Weather", 0)
			type_opt.add_item("- Remove Weather", 1)
			type_opt.select(p.get("type", 0))
			var id_spin = SpinBox.new()
			id_spin.min_value = 1
			id_spin.max_value = 999
			id_spin.value = p.get("id", 1)
			id_spin.prefix = "ID:"
			var on_change = func():
				command.parameters["type"] = type_opt.selected
				command.parameters["id"] = int(id_spin.value)
				update_visuals()
				command_modified.emit(self)
			type_opt.item_selected.connect(func(_x): on_change.call())
			id_spin.value_changed.connect(func(_x): on_change.call())
			row.add_child(type_opt)
			row.add_child(id_spin)
			quick_controls_box.add_child(row)
			_quick_widgets["weather_type"] = type_opt
			_quick_widgets["weather_id"] = id_spin

		69: # Player Transparency
			var row = HBoxContainer.new()
			var lbl = Label.new()
			lbl.text = "Alpha:"
			lbl.add_theme_font_size_override("font_size", 12)
			var spin = SpinBox.new()
			spin.step = 0.05
			spin.min_value = 0.0
			spin.max_value = 1.0
			spin.value = p.get("value", 1.0)
			spin.value_changed.connect(func(val):
				command.parameters["value"] = val
				update_visuals()
				command_modified.emit(self)
			)
			row.add_child(lbl)
			row.add_child(spin)
			quick_controls_box.add_child(row)
			_quick_widgets["transp_spin"] = spin

		70, 71: # Player Followers / Gather
			var row = HBoxContainer.new()
			var opt = OptionButton.new()
			opt.add_item("Enabled", 0)
			opt.add_item("Disabled", 1)
			opt.select(0 if p.get("value", true) else 1)
			opt.item_selected.connect(func(idx):
				command.parameters["value"] = (idx == 0)
				update_visuals()
				command_modified.emit(self)
			)
			row.add_child(opt)
			quick_controls_box.add_child(row)
			_quick_widgets["followers_opt"] = opt

		72: # Show Animation
			var row = HBoxContainer.new()
			var target_spin = SpinBox.new()
			target_spin.min_value = -1
			target_spin.max_value = 9999
			target_spin.value = p.get("target_id", 0)
			target_spin.prefix = "Target(-1=Player):"
			var anim_spin = SpinBox.new()
			anim_spin.min_value = 1
			anim_spin.max_value = 9999
			anim_spin.value = p.get("animation_id", 1)
			anim_spin.prefix = "Anim ID:"
			var wait_chk = CheckBox.new()
			wait_chk.text = "Wait"
			wait_chk.set_pressed_no_signal(p.get("wait", false))
			var on_change = func():
				command.parameters["target_id"] = int(target_spin.value)
				command.parameters["animation_id"] = int(anim_spin.value)
				command.parameters["wait"] = wait_chk.is_pressed()
				update_visuals()
				command_modified.emit(self)
			target_spin.value_changed.connect(func(_x): on_change.call())
			anim_spin.value_changed.connect(func(_x): on_change.call())
			wait_chk.toggled.connect(func(_x): on_change.call())
			row.add_child(target_spin)
			row.add_child(anim_spin)
			row.add_child(wait_chk)
			quick_controls_box.add_child(row)
			_quick_widgets["anim_target"] = target_spin
			_quick_widgets["anim_id"] = anim_spin
			_quick_widgets["anim_wait"] = wait_chk

		73: # Show Balloon
			var row = HBoxContainer.new()
			var target_spin = SpinBox.new()
			target_spin.min_value = -1
			target_spin.max_value = 9999
			target_spin.value = p.get("target_id", 0)
			target_spin.prefix = "Target:"
			var wait_chk = CheckBox.new()
			wait_chk.text = "Wait"
			wait_chk.set_pressed_no_signal(p.get("wait", false))
			var on_change = func():
				command.parameters["target_id"] = int(target_spin.value)
				command.parameters["wait"] = wait_chk.is_pressed()
				update_visuals()
				command_modified.emit(self)
			target_spin.value_changed.connect(func(_x): on_change.call())
			wait_chk.toggled.connect(func(_x): on_change.call())
			row.add_child(target_spin)
			row.add_child(wait_chk)
			quick_controls_box.add_child(row)
			_quick_widgets["balloon_target"] = target_spin
			_quick_widgets["balloon_wait"] = wait_chk

		75: # Show Image
			var row = HBoxContainer.new()
			var img_spin = SpinBox.new()
			img_spin.min_value = 1
			img_spin.max_value = 100
			img_spin.value = p.get("index", 1)
			img_spin.prefix = "Image #:"
			var pos_x = SpinBox.new()
			pos_x.min_value = -9999
			pos_x.max_value = 9999
			var pos_val = p.get("position", Vector2.ZERO)
			pos_x.value = pos_val.x
			pos_x.prefix = "X:"
			var pos_y = SpinBox.new()
			pos_y.min_value = -9999
			pos_y.max_value = 9999
			pos_y.value = pos_val.y
			pos_y.prefix = "Y:"
			var on_change = func():
				command.parameters["index"] = int(img_spin.value)
				command.parameters["position"] = Vector2(pos_x.value, pos_y.value)
				update_visuals()
				command_modified.emit(self)
			img_spin.value_changed.connect(func(_x): on_change.call())
			pos_x.value_changed.connect(func(_x): on_change.call())
			pos_y.value_changed.connect(func(_x): on_change.call())
			row.add_child(img_spin)
			row.add_child(pos_x)
			row.add_child(pos_y)
			quick_controls_box.add_child(row)
			_quick_widgets["show_img_id"] = img_spin
			_quick_widgets["show_img_x"] = pos_x
			_quick_widgets["show_img_y"] = pos_y

		80: # Erase Image
			var row = HBoxContainer.new()
			var spin = SpinBox.new()
			spin.min_value = 1
			spin.max_value = 100
			spin.value = p.get("index", 1)
			spin.prefix = "Erase Image #:"
			spin.value_changed.connect(func(val):
				command.parameters["index"] = int(val)
				update_visuals()
				command_modified.emit(self)
			)
			row.add_child(spin)
			quick_controls_box.add_child(row)
			_quick_widgets["erase_img_id"] = spin

		83, 87, 89, 90: # Audio: BGM / BGS / ME / SE
			var row = HBoxContainer.new()
			var vol_spin = SpinBox.new()
			vol_spin.step = 0.5
			vol_spin.min_value = -80.0
			vol_spin.max_value = 24.0
			vol_spin.value = p.get("volume", 0.0)
			vol_spin.prefix = "Vol(dB):"
			var pitch_spin = SpinBox.new()
			pitch_spin.step = 0.05
			pitch_spin.min_value = 0.1
			pitch_spin.max_value = 4.0
			pitch_spin.value = p.get("pitch", 1.0)
			pitch_spin.prefix = "Pitch:"
			var on_change = func():
				command.parameters["volume"] = vol_spin.value
				command.parameters["pitch"] = pitch_spin.value
				update_visuals()
				command_modified.emit(self)
			vol_spin.value_changed.connect(func(_x): on_change.call())
			pitch_spin.value_changed.connect(func(_x): on_change.call())
			row.add_child(vol_spin)
			row.add_child(pitch_spin)
			quick_controls_box.add_child(row)
			_quick_widgets["audio_vol"] = vol_spin
			_quick_widgets["audio_pitch"] = pitch_spin

		84, 88, 93: # Stop BGM / Stop BGS / Stop Video
			var row = HBoxContainer.new()
			var spin = SpinBox.new()
			spin.step = 0.1
			spin.min_value = 0.0
			spin.max_value = 60.0
			spin.value = p.get("duration", 0.0)
			spin.prefix = "Fadeout (s):"
			spin.value_changed.connect(func(val):
				command.parameters["duration"] = val
				update_visuals()
				command_modified.emit(self)
			)
			row.add_child(spin)
			quick_controls_box.add_child(row)
			_quick_widgets["stop_fade"] = spin

		103, 113, 114, 116, 210, 211: # Enabled / Disabled Settings
			var row = HBoxContainer.new()
			var opt = OptionButton.new()
			opt.add_item("Enabled", 0)
			opt.add_item("Disabled", 1)
			opt.select(0 if p.get("selected", false) else 1)
			opt.item_selected.connect(func(idx):
				command.parameters["selected"] = (idx == 0)
				update_visuals()
				command_modified.emit(self)
			)
			row.add_child(opt)
			quick_controls_box.add_child(row)
			_quick_widgets["opt_selected"] = opt

		115: # Encounter Rate
			var row = HBoxContainer.new()
			var spin = SpinBox.new()
			spin.min_value = 0
			spin.max_value = 1000
			spin.value = p.get("value", 100)
			spin.suffix = "%"
			spin.prefix = "Rate:"
			spin.value_changed.connect(func(val):
				command.parameters["value"] = val
				update_visuals()
				command_modified.emit(self)
			)
			row.add_child(spin)
			quick_controls_box.add_child(row)
			_quick_widgets["enc_spin"] = spin

		117: # Game Speed
			var row = HBoxContainer.new()
			var spin = SpinBox.new()
			spin.step = 0.01
			spin.min_value = 0.1
			spin.max_value = 3.5
			spin.value = p.get("value", 1.0)
			spin.prefix = "Speed:"
			spin.suffix = "x"
			spin.value_changed.connect(func(val):
				command.parameters["value"] = val
				update_visuals()
				command_modified.emit(self)
			)
			row.add_child(spin)
			quick_controls_box.add_child(row)
			_quick_widgets["speed_spin"] = spin

		126: # Quest
			var row = HBoxContainer.new()
			var op_opt = OptionButton.new()
			var ops = ["Start", "Cancel", "Complete", "Fail", "Unlock", "Restart", "Update"]
			for idx in range(ops.size()): op_opt.add_item(ops[idx], idx)
			op_opt.select(min(p.get("operation_type", 0), 6))
			var prog_spin = SpinBox.new()
			prog_spin.step = 0.05
			prog_spin.min_value = 0.0
			prog_spin.max_value = 1.0
			prog_spin.value = p.get("progress", 0.1)
			prog_spin.prefix = "Prog:"
			var on_change = func():
				command.parameters["operation_type"] = op_opt.selected
				command.parameters["progress"] = prog_spin.value
				update_visuals()
				command_modified.emit(self)
			op_opt.item_selected.connect(func(_x): on_change.call())
			prog_spin.value_changed.connect(func(_x): on_change.call())
			row.add_child(op_opt)
			row.add_child(prog_spin)
			quick_controls_box.add_child(row)
			_quick_widgets["quest_op"] = op_opt
			_quick_widgets["quest_prog"] = prog_spin

		300: # Profession
			var row = HBoxContainer.new()
			var prof_spin = SpinBox.new()
			prof_spin.min_value = 1
			prof_spin.max_value = 9999
			prof_spin.value = p.get("profession_id", 1)
			prof_spin.prefix = "Prof ID:"
			var action_opt = OptionButton.new()
			action_opt.add_item("Add", 1)
			action_opt.add_item("Remove", 0)
			action_opt.select(0 if p.get("type", 1) == 1 else 1)
			var on_change = func():
				command.parameters["profession_id"] = int(prof_spin.value)
				command.parameters["type"] = 1 if action_opt.selected == 0 else 0
				update_visuals()
				command_modified.emit(self)
			prof_spin.value_changed.connect(func(_x): on_change.call())
			action_opt.item_selected.connect(func(_x): on_change.call())
			row.add_child(prof_spin)
			row.add_child(action_opt)
			quick_controls_box.add_child(row)
			_quick_widgets["prof_id"] = prof_spin
			_quick_widgets["prof_action"] = action_opt

		301: # Upgrade Profession
			var row = HBoxContainer.new()
			var spin = SpinBox.new()
			spin.min_value = 1
			spin.max_value = 9999
			spin.value = p.get("profession_id", 1)
			spin.prefix = "Upgrade Prof ID:"
			spin.value_changed.connect(func(val):
				command.parameters["profession_id"] = int(val)
				update_visuals()
				command_modified.emit(self)
			)
			row.add_child(spin)
			quick_controls_box.add_child(row)
			_quick_widgets["up_prof_id"] = spin

		302: # User Parameter
			var row = HBoxContainer.new()
			var param_spin = SpinBox.new()
			param_spin.min_value = 0
			param_spin.max_value = 999
			param_spin.value = p.get("param_id", 0)
			param_spin.prefix = "Param:"
			var val_spin = SpinBox.new()
			val_spin.min_value = -999999
			val_spin.max_value = 999999
			val_spin.value = p.get("value", 0.0)
			val_spin.prefix = "Val:"
			var on_change = func():
				command.parameters["param_id"] = int(param_spin.value)
				command.parameters["value"] = val_spin.value
				update_visuals()
				command_modified.emit(self)
			param_spin.value_changed.connect(func(_x): on_change.call())
			val_spin.value_changed.connect(func(_x): on_change.call())
			row.add_child(param_spin)
			row.add_child(val_spin)
			quick_controls_box.add_child(row)
			_quick_widgets["user_param_id"] = param_spin
			_quick_widgets["user_param_val"] = val_spin

		303: # Change Stat
			var row = HBoxContainer.new()
			var stat_spin = SpinBox.new()
			stat_spin.min_value = 0
			stat_spin.max_value = 999
			stat_spin.value = p.get("stat_id", 0)
			stat_spin.prefix = "Stat:"
			var val_spin = SpinBox.new()
			val_spin.min_value = -999999
			val_spin.max_value = 999999
			val_spin.value = p.get("value", 0.0)
			val_spin.prefix = "Val:"
			var on_change = func():
				command.parameters["stat_id"] = int(stat_spin.value)
				command.parameters["value"] = val_spin.value
				update_visuals()
				command_modified.emit(self)
			stat_spin.value_changed.connect(func(_x): on_change.call())
			val_spin.value_changed.connect(func(_x): on_change.call())
			row.add_child(stat_spin)
			row.add_child(val_spin)
			quick_controls_box.add_child(row)
			_quick_widgets["stat_id_spin"] = stat_spin
			_quick_widgets["stat_val_spin"] = val_spin

		500: # Battle
			var row = HBoxContainer.new()
			var spin = SpinBox.new()
			spin.min_value = 1
			spin.max_value = 9999
			spin.value = p.get("value", 1)
			spin.prefix = "Troop ID:"
			spin.value_changed.connect(func(val):
				command.parameters["value"] = int(val)
				update_visuals()
				command_modified.emit(self)
			)
			row.add_child(spin)
			quick_controls_box.add_child(row)
			_quick_widgets["battle_troop"] = spin


func _update_quick_controls_values() -> void:
	if not command: return
	var p = command.parameters
	var code = command.code
	
	if code in [2, 10, 31, 34] and _quick_widgets.has("text_edit"):
		var te: TextEdit = _quick_widgets.text_edit
		if not te.has_focus():
			var lines: Array[String] = []
			if code in [31, 34]:
				lines.append(p.get("first_line", ""))
				var sub_code = 32 if code == 31 else 35
				for sub in sub_commands:
					if sub.code == sub_code:
						lines.append(sub.parameters.get("line", ""))
			else:
				var sub_code = 3 if code == 2 else 11
				for sub in sub_commands:
					if sub.code == sub_code:
						lines.append(sub.parameters.get("line", ""))
			te.text = "\n".join(lines).strip_edges()
			
	elif code == 17 and _quick_widgets.has("switch_id"):
		_quick_widgets.switch_id.set_value_no_signal(p.get("from", 1))
		_quick_widgets.switch_state.select(p.get("operation_type", 0))
	elif code == 18 and _quick_widgets.has("var_id"):
		_quick_widgets.var_id.set_value_no_signal(p.get("from", 1))
		_quick_widgets.var_op.select(min(p.get("operation_type", 0), 5))
		_quick_widgets.var_val.set_value_no_signal(p.get("value1", 0))
	elif code == 19 and _quick_widgets.has("self_sw"):
		_quick_widgets.self_sw.select(p.get("switch_id", 0))
		_quick_widgets.self_state.select(p.get("operation_type", 0))
	elif code == 33 and _quick_widgets.has("wait_spin"):
		_quick_widgets.wait_spin.set_value_no_signal(p.get("duration", 1.0))
	elif code == 12 and _quick_widgets.has("gold_val"):
		_quick_widgets.gold_op.select(p.get("operation_type", 0))
		_quick_widgets.gold_val.set_value_no_signal(p.get("value", 1))
	elif code in [13, 14, 15] and _quick_widgets.has("item_id"):
		_quick_widgets.item_id.set_value_no_signal(p.get("item_id", 1))
		_quick_widgets.item_op.select(p.get("operation_type", 0))
		_quick_widgets.item_qty.set_value_no_signal(p.get("value", 1))
	elif code in [29, 30] and _quick_widgets.has("label_edit"):
		if not _quick_widgets.label_edit.has_focus():
			_quick_widgets.label_edit.text = p.get("text", "")
	elif code == 5000 and _quick_widgets.has("script_edit"):
		if not _quick_widgets.script_edit.has_focus():
			_quick_widgets.script_edit.text = p.get("script", "")

