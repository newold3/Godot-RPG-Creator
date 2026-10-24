@tool
class_name BranchGraphNodes
extends RefCounted

const GraphCommandFormatter = preload("res://addons/CustomControls/Dialogs/EventGraphEditor/graph_command_formatter.gd")


#region Helper
static func setup_node_close_button(node: GraphNode, on_close: Callable) -> void:
	if node.has_method("get_titlebar_h_box"):
		var titlebar = node.call("get_titlebar_h_box")
		if titlebar and titlebar is Container:
			var close_btn = Button.new()
			close_btn.name = "CloseButton"
			close_btn.text = "×"
			close_btn.tooltip_text = "[title]Eliminar Nodo[/title]\nElimina este nodo de bloque del grafo."
			close_btn.flat = true
			close_btn.focus_mode = Control.FOCUS_NONE
			close_btn.pressed.connect(on_close)
			titlebar.add_child(close_btn)
	if node.has_signal("delete_request"):
		node.connect("delete_request", on_close)


static func configure_option_button(opt: OptionButton) -> OptionButton:
	if not opt:
		return opt
	opt.add_theme_font_size_override("font_size", 16)
	var popup = opt.get_popup()
	if popup:
		popup.add_theme_font_size_override("font_size", 16)
		popup.add_theme_font_size_override("font_separator_size", 16)
		var cb = func():
			popup.add_theme_font_size_override("font_size", 16)
			popup.add_theme_font_size_override("font_separator_size", 16)
		if not popup.about_to_popup.is_connected(cb):
			popup.about_to_popup.connect(cb)
	return opt
#endregion


#region Start Node
class EventStartGraphNode extends GraphNode:
	func _ready() -> void:
		title = "▶️ Event Start"
		resizable = false
		add_theme_font_size_override("title_font_size", 16)
		custom_minimum_size = Vector2(190, 0)
		
		if get_child_count() == 0:
			var row = HBoxContainer.new()
			var lbl = Label.new()
			lbl.text = "Entry Point"
			lbl.modulate = Color(0.7, 0.7, 0.7)
			lbl.add_theme_font_size_override("font_size", 16)
			
			var spacer = Control.new()
			spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			
			var out_lbl = Label.new()
			out_lbl.text = "Start ▶"
			out_lbl.modulate = Color(0.2, 0.9, 0.4)
			out_lbl.add_theme_font_size_override("font_size", 16)
			
			row.add_child(lbl)
			row.add_child(spacer)
			row.add_child(out_lbl)
			add_child(row)
			
		set_slot(0, false, 0, Color.TRANSPARENT, true, 0, Color(0.2, 0.9, 0.4))
#endregion


#region Condition Node
class EventConditionGraphNode extends GraphNode:
	var command: RPGEventCommand
	var sub_commands: Array[RPGEventCommand] = []
	var conditions: Array[Dictionary] = []
	var summary_label: Label
	var quick_controls_box: VBoxContainer
	var edit_button: Button
	var else_toggle_button: Button
	var add_condition_button: Button
	var has_else_branch: bool = false
	var collapse_btn: Button
	var content_vbox: VBoxContainer
	var is_collapsed: bool = false
	
	var _quick_widgets: Array[Dictionary] = []
	
	signal command_modified(node: GraphNode)
	signal request_delete(node: GraphNode)
	signal request_edit_dialog(node: GraphNode)
	signal collapse_changed(node: GraphNode, is_collapsed: bool)
	
	func _ready() -> void:
		resizable = false
		BranchGraphNodes.setup_node_close_button(self, func(): request_delete.emit(self))

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			if event.double_click and event.is_pressed():
				accept_event()
				request_edit_dialog.emit(self)
		
	func setup(p_command: RPGEventCommand, p_sub_commands: Array[RPGEventCommand] = []) -> void:
		command = p_command
		sub_commands = p_sub_commands
		title = "⚖️ Conditional Branch"
		custom_minimum_size = Vector2(310, 0)
		
		_normalize_parameters()
		if conditions.is_empty():
			conditions.append(command.parameters.duplicate())
		if command.parameters.has("else_branch"):
			has_else_branch = bool(command.parameters["else_branch"])
			
		_build_ui()
		update_visuals()

	func _normalize_parameters() -> void:
		if not command: return
		var p = command.parameters
		# Convert legacy graph keys if present
		if p.has("switch_selected") and not p.has("value1"):
			p["value1"] = p["switch_selected"]
			p["value2"] = p.get("switch_value", 0)
			p.erase("switch_selected")
			p.erase("switch_value")
		if not p.has("item_selected"):
			p["item_selected"] = 0
		if not p.has("value1"):
			p["value1"] = 1
		if not p.has("value2"):
			p["value2"] = 0

	func _build_ui() -> void:
		clear_all_slots()
		var existing_content = get_node_or_null("ContentBox")
		var existing_row0 = get_node_or_null("Row0")
		var existing_row1 = get_node_or_null("Row1")
		var existing_row2 = get_node_or_null("Row2")
		
		if not existing_content or not existing_row0 or not existing_row1 or not existing_row2:
			for child in get_children():
				remove_child(child)
				child.queue_free()
				
			# Slot 0: In / True Branch
			var row0 = HBoxContainer.new()
			row0.name = "Row0"
			var in_lbl = Label.new()
			in_lbl.name = "InLabel"
			in_lbl.text = "▶ In"
			in_lbl.add_theme_font_size_override("font_size", 16)
			
			collapse_btn = Button.new()
			collapse_btn.name = "CollapseButton"
			collapse_btn.text = "▶" if is_collapsed else "▼"
			collapse_btn.flat = true
			collapse_btn.tooltip_text = "[title]Contraer / Expandir Condición[/title]\nAlterna la visualización de los controles de la condición."
			collapse_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			collapse_btn.focus_mode = Control.FOCUS_NONE
			collapse_btn.pressed.connect(_on_collapse_toggled)
			
			var sp0 = Control.new()
			sp0.name = "Spacer"
			sp0.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var true_lbl = Label.new()
			true_lbl.name = "TrueLabel"
			true_lbl.text = "True ▶ (Si)"
			true_lbl.modulate = Color(0.2, 0.9, 0.4)
			true_lbl.add_theme_font_size_override("font_size", 16)
			row0.add_child(in_lbl)
			row0.add_child(collapse_btn)
			row0.add_child(sp0)
			row0.add_child(true_lbl)
			add_child(row0)
			
			# Slot 1: False Branch (Else)
			var row1 = HBoxContainer.new()
			row1.name = "Row1"
			var sp1 = Control.new()
			sp1.name = "Spacer"
			sp1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var false_lbl = Label.new()
			false_lbl.name = "FalseLabel"
			if has_else_branch:
				false_lbl.text = "False ▶ (No / Else)"
				false_lbl.modulate = Color(1.0, 0.4, 0.3)
				row1.add_child(sp1)
				row1.add_child(false_lbl)
				add_child(row1)
			else:
				false_lbl.text = "Sin Rama Else (Desactivada)"
				false_lbl.modulate = Color(0.5, 0.5, 0.5, 0.6)
				row1.add_child(sp1)
				row1.add_child(false_lbl)
				add_child(row1)
			false_lbl.add_theme_font_size_override("font_size", 16)
			
			# Slot 2: Continuation / Merge
			var row2 = HBoxContainer.new()
			row2.name = "Row2"
			var sp2 = Control.new()
			sp2.name = "Spacer"
			sp2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var cont_lbl = Label.new()
			cont_lbl.name = "ContinueLabel"
			cont_lbl.text = "Continue ▶ (Unión)"
			cont_lbl.modulate = Color(0.95, 0.85, 0.2)
			cont_lbl.add_theme_font_size_override("font_size", 16)
			row2.add_child(sp2)
			row2.add_child(cont_lbl)
			add_child(row2)
			
			# Slot 3: Info, Quick Inline Controls & Action Buttons
			content_vbox = VBoxContainer.new()
			content_vbox.name = "ContentBox"
			content_vbox.add_theme_constant_override("separation", 5)
			content_vbox.custom_minimum_size = Vector2(290, 0)
			
			summary_label = Label.new()
			summary_label.name = "SummaryLabel"
			summary_label.custom_minimum_size = Vector2(290, 0)
			summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			summary_label.max_lines_visible = 4
			summary_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			summary_label.add_theme_font_size_override("font_size", 16)
			summary_label.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95))
			content_vbox.add_child(summary_label)
			
			quick_controls_box = VBoxContainer.new()
			quick_controls_box.name = "QuickControlsBox"
			quick_controls_box.add_theme_constant_override("separation", 4)
			content_vbox.add_child(quick_controls_box)
			
			# Buttons row 1: Add Condition & Toggle Else
			var btn_row1 = HBoxContainer.new()
			btn_row1.name = "ButtonRow1"
			btn_row1.add_theme_constant_override("separation", 6)
			
			add_condition_button = Button.new()
			add_condition_button.name = "AddConditionButton"
			add_condition_button.text = "➕ Add Condition"
			add_condition_button.tooltip_text = "[title]Añadir Condición[/title]\nAñade una nueva condición a este bloque condicional."
			add_condition_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			add_condition_button.focus_mode = Control.FOCUS_NONE
			add_condition_button.add_theme_font_size_override("font_size", 16)
			add_condition_button.pressed.connect(_on_add_condition_pressed)
			btn_row1.add_child(add_condition_button)
			
			else_toggle_button = Button.new()
			else_toggle_button.name = "ToggleElseButton"
			else_toggle_button.text = "➖ Remove Else" if has_else_branch else "➕ Add Else"
			else_toggle_button.tooltip_text = "[title]Alternar Rama Else[/title]\nActiva o desactiva la rama 'Si no' (Else)."
			else_toggle_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			else_toggle_button.focus_mode = Control.FOCUS_NONE
			else_toggle_button.add_theme_font_size_override("font_size", 16)
			else_toggle_button.pressed.connect(_on_toggle_else_pressed)
			btn_row1.add_child(else_toggle_button)
			
			content_vbox.add_child(btn_row1)
			
			# Buttons row 2: Advanced Dialog
			var btn_row2 = HBoxContainer.new()
			btn_row2.name = "ButtonRow2"
			var btn_sp = Control.new()
			btn_sp.name = "Spacer"
			btn_sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			btn_row2.add_child(btn_sp)
			
			edit_button = Button.new()
			edit_button.name = "EditConditionButton"
			edit_button.text = "✏️ Advanced Condition..."
			edit_button.tooltip_text = "[title]Editor de Condiciones[/title]\nAbre la ventana de configuración avanzada de condiciones."
			edit_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			edit_button.focus_mode = Control.FOCUS_NONE
			edit_button.add_theme_font_size_override("font_size", 16)
			edit_button.pressed.connect(func(): request_edit_dialog.emit(self))
			btn_row2.add_child(edit_button)
			
			content_vbox.add_child(btn_row2)
			add_child(content_vbox)
		else:
			collapse_btn = existing_row0.get_node_or_null("CollapseButton")
			if collapse_btn and not collapse_btn.pressed.is_connected(_on_collapse_toggled):
				collapse_btn.pressed.connect(_on_collapse_toggled)
			
			var false_lbl = existing_row1.get_node_or_null("FalseLabel")
			if false_lbl:
				if has_else_branch:
					false_lbl.text = "False ▶ (No / Else)"
					false_lbl.modulate = Color(1.0, 0.4, 0.3)
				else:
					false_lbl.text = "Sin Rama Else (Desactivada)"
					false_lbl.modulate = Color(0.5, 0.5, 0.5, 0.6)
			
			content_vbox = existing_content
			summary_label = content_vbox.get_node_or_null("SummaryLabel")
			quick_controls_box = content_vbox.get_node_or_null("QuickControlsBox")
			var btn_row1 = content_vbox.get_node_or_null("ButtonRow1")
			if btn_row1:
				add_condition_button = btn_row1.get_node_or_null("AddConditionButton")
				if add_condition_button and not add_condition_button.pressed.is_connected(_on_add_condition_pressed):
					add_condition_button.pressed.connect(_on_add_condition_pressed)
				else_toggle_button = btn_row1.get_node_or_null("ToggleElseButton")
				if else_toggle_button:
					else_toggle_button.text = "➖ Remove Else" if has_else_branch else "➕ Add Else"
					if not else_toggle_button.pressed.is_connected(_on_toggle_else_pressed):
						else_toggle_button.pressed.connect(_on_toggle_else_pressed)
			var btn_row2 = content_vbox.get_node_or_null("ButtonRow2")
			if btn_row2:
				edit_button = btn_row2.get_node_or_null("EditConditionButton")
				if edit_button:
					var cb = func(): request_edit_dialog.emit(self)
					if not edit_button.pressed.is_connected(cb):
						edit_button.pressed.connect(cb)

		set_slot(0, true, 0, Color(0.8, 0.8, 0.8), true, 0, Color(0.2, 0.9, 0.4))
		if has_else_branch:
			set_slot(1, false, 0, Color.TRANSPARENT, true, 0, Color(1.0, 0.4, 0.3))
		else:
			set_slot(1, false, 0, Color.TRANSPARENT, false, 0, Color.TRANSPARENT)
		set_slot(2, false, 0, Color.TRANSPARENT, true, 0, Color(0.95, 0.85, 0.2))
		set_slot(3, false, 0, Color.TRANSPARENT, false, 0, Color.TRANSPARENT)
		
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
			custom_minimum_size = Vector2(220, 0)
		else:
			custom_minimum_size = Vector2(310, 0)
		size = Vector2.ZERO
		if emit_sig:
			collapse_changed.emit(self, is_collapsed)


	func _on_collapse_toggled() -> void:
		set_collapsed(!is_collapsed, true)
		
	func _on_add_condition_pressed() -> void:
		conditions.append({
			"item_selected": 0,
			"value1": 1,
			"value2": 0,
			"value3": null,
			"value4": null,
			"value5": null,
			"value6": null
		})
		_build_quick_controls()
		update_visuals()
		command_modified.emit(self)

	func _on_toggle_else_pressed() -> void:
		has_else_branch = !has_else_branch
		command.parameters["else_branch"] = has_else_branch
		_build_ui()
		update_visuals()
		command_modified.emit(self)

	func update_visuals() -> void:
		if not command: return
		_normalize_parameters()
		if conditions.is_empty():
			conditions.append(command.parameters.duplicate())
		
		if conditions.size() <= 1:
			summary_label.text = GraphCommandFormatter.get_formatted_text(command, sub_commands)
		else:
			var lines: Array[String] = []
			for k in range(conditions.size()):
				var dummy_cmd = RPGEventCommand.new(21, 0, conditions[k])
				var prefix = "IF: " if k == 0 else "AND: "
				lines.append(prefix + GraphCommandFormatter.get_formatted_text(dummy_cmd, []))
			summary_label.text = "\n".join(lines)
			
		size = Vector2.ZERO

	func _build_quick_controls() -> void:
		_quick_widgets.clear()
		for c in quick_controls_box.get_children():
			c.queue_free()
			
		if conditions.is_empty():
			conditions.append(command.parameters.duplicate())
			
		for k in range(conditions.size()):
			var cond_data = conditions[k]
			var cond_container = VBoxContainer.new()
			cond_container.add_theme_constant_override("separation", 2)
			
			# Header row
			var header_row = HBoxContainer.new()
			var lbl_prefix = Label.new()
			lbl_prefix.text = "Si (IF):" if k == 0 else "Y (AND):"
			lbl_prefix.modulate = Color(0.3, 0.8, 1.0) if k == 0 else Color(1.0, 0.8, 0.2)
			lbl_prefix.add_theme_font_size_override("font_size", 16)
			header_row.add_child(lbl_prefix)
			
			var type_opt = BranchGraphNodes.configure_option_button(OptionButton.new())
			type_opt.add_item("Switch", 0)
			type_opt.add_item("Variable", 1)
			type_opt.add_item("Self Switch", 2)
			type_opt.add_item("Gold", 8)
			type_opt.add_item("Has Item", 9)
			type_opt.add_item("Has Weapon", 10)
			type_opt.add_item("Has Armor", 11)
			
			var item_sel = cond_data.get("item_selected", 0)
			var sel_idx = 0
			match item_sel:
				0: sel_idx = 0
				1: sel_idx = 1
				2: sel_idx = 2
				8: sel_idx = 3
				9: sel_idx = 4
				10: sel_idx = 5
				11: sel_idx = 6
				_: sel_idx = 0
			type_opt.select(sel_idx)
			
			var captured_k = k
			type_opt.item_selected.connect(func(idx):
				var actual_type = 0
				match idx:
					0: actual_type = 0
					1: actual_type = 1
					2: actual_type = 2
					3: actual_type = 8
					4: actual_type = 9
					5: actual_type = 10
					6: actual_type = 11
				conditions[captured_k]["item_selected"] = actual_type
				if captured_k == 0:
					command.parameters["item_selected"] = actual_type
				_build_quick_controls()
				update_visuals()
				command_modified.emit(self)
			)
			header_row.add_child(type_opt)
			
			var h_sp = Control.new()
			h_sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			header_row.add_child(h_sp)
			
			# Delete condition button (available when more than 1 condition exists)
			if conditions.size() > 1:
				var del_btn = Button.new()
				del_btn.name = "DeleteConditionButton"
				del_btn.text = "×"
				del_btn.flat = true
				del_btn.tooltip_text = "[title]Eliminar Condición[/title]\nElimina esta condición de la lista."
				del_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
				del_btn.focus_mode = Control.FOCUS_NONE
				del_btn.pressed.connect(func():
					conditions.remove_at(captured_k)
					if captured_k == 0 and not conditions.is_empty():
						command.parameters = conditions[0]
					_build_quick_controls()
					update_visuals()
					command_modified.emit(self)
				)
				header_row.add_child(del_btn)
				
			cond_container.add_child(header_row)
			
			# Input controls row
			var sub_row = HBoxContainer.new()
			sub_row.add_theme_constant_override("separation", 3)
			
			if item_sel == 0: # Switch
				var sw_spin = SpinBox.new()
				sw_spin.min_value = 1
				sw_spin.max_value = 9999
				sw_spin.value = cond_data.get("value1", 1)
				sw_spin.value_changed.connect(func(val):
					conditions[captured_k]["value1"] = int(val)
					if captured_k == 0: command.parameters["value1"] = int(val)
					update_visuals()
					command_modified.emit(self)
				)
				var state_opt = BranchGraphNodes.configure_option_button(OptionButton.new())
				state_opt.add_item("ON", 0)
				state_opt.add_item("OFF", 1)
				state_opt.select(1 if cond_data.get("value2", 0) == 1 else 0)
				state_opt.item_selected.connect(func(val):
					conditions[captured_k]["value2"] = val
					if captured_k == 0: command.parameters["value2"] = val
					update_visuals()
					command_modified.emit(self)
				)
				sub_row.add_child(sw_spin)
				sub_row.add_child(state_opt)
				
			elif item_sel == 1: # Variable
				var var_spin = SpinBox.new()
				var_spin.min_value = 1
				var_spin.max_value = 9999
				var_spin.value = cond_data.get("value1", 1)
				var_spin.value_changed.connect(func(val):
					conditions[captured_k]["value1"] = int(val)
					if captured_k == 0: command.parameters["value1"] = int(val)
					update_visuals()
					command_modified.emit(self)
				)
				var cond_opt = BranchGraphNodes.configure_option_button(OptionButton.new())
				var conds = ["==", ">=", "<=", ">", "<", "!="]
				for idx in range(conds.size()):
					cond_opt.add_item(conds[idx], idx)
				cond_opt.select(min(cond_data.get("value2", 0), 5))
				cond_opt.item_selected.connect(func(val):
					conditions[captured_k]["value2"] = val
					if captured_k == 0: command.parameters["value2"] = val
					update_visuals()
					command_modified.emit(self)
				)
				var val_spin = SpinBox.new()
				val_spin.min_value = -9999999
				val_spin.max_value = 9999999
				val_spin.value = cond_data.get("value4", 0)
				val_spin.value_changed.connect(func(val):
					conditions[captured_k]["value3"] = 0 # Constant
					conditions[captured_k]["value4"] = int(val)
					if captured_k == 0:
						command.parameters["value3"] = 0
						command.parameters["value4"] = int(val)
					update_visuals()
					command_modified.emit(self)
				)
				sub_row.add_child(var_spin)
				sub_row.add_child(cond_opt)
				sub_row.add_child(val_spin)
				
			elif item_sel == 2: # Self Switch
				var sw_opt = BranchGraphNodes.configure_option_button(OptionButton.new())
				sw_opt.add_item("A", 0)
				sw_opt.add_item("B", 1)
				sw_opt.add_item("C", 2)
				sw_opt.add_item("D", 3)
				sw_opt.select(min(cond_data.get("value1", 0), 3))
				sw_opt.item_selected.connect(func(val):
					conditions[captured_k]["value1"] = val
					if captured_k == 0: command.parameters["value1"] = val
					update_visuals()
					command_modified.emit(self)
				)
				var state_opt = BranchGraphNodes.configure_option_button(OptionButton.new())
				state_opt.add_item("ON", 0)
				state_opt.add_item("OFF", 1)
				state_opt.select(1 if cond_data.get("value2", 0) == 1 else 0)
				state_opt.item_selected.connect(func(val):
					conditions[captured_k]["value2"] = val
					if captured_k == 0: command.parameters["value2"] = val
					update_visuals()
					command_modified.emit(self)
				)
				sub_row.add_child(sw_opt)
				sub_row.add_child(state_opt)
				
			elif item_sel == 8: # Gold
				var cond_opt = BranchGraphNodes.configure_option_button(OptionButton.new())
				cond_opt.add_item(">=", 0)
				cond_opt.add_item("<=", 1)
				cond_opt.add_item("<", 2)
				cond_opt.select(min(cond_data.get("value1", 0), 2))
				cond_opt.item_selected.connect(func(val):
					conditions[captured_k]["value1"] = val
					if captured_k == 0: command.parameters["value1"] = val
					update_visuals()
					command_modified.emit(self)
				)
				var gold_spin = SpinBox.new()
				gold_spin.min_value = 0
				gold_spin.max_value = 99999999
				gold_spin.value = cond_data.get("value2", 0)
				gold_spin.value_changed.connect(func(val):
					conditions[captured_k]["value2"] = int(val)
					if captured_k == 0: command.parameters["value2"] = int(val)
					update_visuals()
					command_modified.emit(self)
				)
				sub_row.add_child(cond_opt)
				sub_row.add_child(gold_spin)
				
			elif item_sel in [9, 10, 11]: # Has Item / Weapon / Armor
				var id_lbl = Label.new()
				id_lbl.text = "ID:"
				id_lbl.add_theme_font_size_override("font_size", 16)
				var item_spin = SpinBox.new()
				item_spin.min_value = 1
				item_spin.max_value = 9999
				item_spin.value = cond_data.get("value1", 1)
				item_spin.value_changed.connect(func(val):
					conditions[captured_k]["value1"] = int(val)
					if captured_k == 0: command.parameters["value1"] = int(val)
					update_visuals()
					command_modified.emit(self)
				)
				sub_row.add_child(id_lbl)
				sub_row.add_child(item_spin)
				
			cond_container.add_child(sub_row)
			quick_controls_box.add_child(cond_container)
#endregion


#region Choice Node
class EventChoiceGraphNode extends GraphNode:
	var command: RPGEventCommand
	var sub_commands: Array[RPGEventCommand] = []
	var choice_labels: Array[String] = []
	var edit_button: Button
	
	signal command_modified(node: GraphNode)
	signal request_delete(node: GraphNode)
	signal request_edit_dialog(node: GraphNode)
	
	func _ready() -> void:
		resizable = false
		BranchGraphNodes.setup_node_close_button(self, func(): request_delete.emit(self))

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			if event.double_click and event.is_pressed():
				accept_event()
				request_edit_dialog.emit(self)
		
	func setup(p_command: RPGEventCommand, p_sub_commands: Array[RPGEventCommand] = []) -> void:
		command = p_command
		sub_commands = p_sub_commands
		title = "❓ Show Choices"
		add_theme_font_size_override("title_font_size", 16)
		custom_minimum_size = Vector2(300, 0)
		_extract_choices_from_subs()
		_build_ui()

	func _extract_choices_from_subs() -> void:
		choice_labels.clear()
		for sub in sub_commands:
			if sub.code == 5:
				var cname = sub.parameters.get("name", "")
				if not cname.is_empty():
					choice_labels.append(cname)
		if choice_labels.is_empty():
			choice_labels = ["Option 1", "Option 2"]

	func update_visuals() -> void:
		_extract_choices_from_subs()
		_build_ui()
			
	func _build_ui() -> void:
		clear_all_slots()
		for child in get_children():
			remove_child(child)
			child.queue_free()
			
		var slot_idx = 0
		
		# Slot 0: In / First Choice (with inline LineEdit for quick choice renaming)
		var row0 = HBoxContainer.new()
		var in_lbl = Label.new()
		in_lbl.text = "▶ In"
		in_lbl.add_theme_font_size_override("font_size", 16)
		
		var c0_edit = LineEdit.new()
		c0_edit.text = choice_labels[0]
		c0_edit.custom_minimum_size = Vector2(130, 26)
		c0_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		c0_edit.add_theme_font_size_override("font_size", 16)
		c0_edit.text_changed.connect(func(new_text):
			_update_choice_text(0, new_text)
		)
		
		var c0_out = Label.new()
		c0_out.text = "[1] ▶"
		c0_out.modulate = Color(0.3, 0.75, 1.0)
		c0_out.add_theme_font_size_override("font_size", 16)
		
		row0.add_child(in_lbl)
		row0.add_child(c0_edit)
		row0.add_child(c0_out)
		add_child(row0)
		set_slot(slot_idx, true, 0, Color(0.8, 0.8, 0.8), true, 0, Color(0.3, 0.75, 1.0))
		slot_idx += 1
		
		# Remaining Choices (with inline LineEdits)
		for i in range(1, choice_labels.size()):
			var row = HBoxContainer.new()
			var c_edit = LineEdit.new()
			c_edit.text = choice_labels[i]
			c_edit.custom_minimum_size = Vector2(130, 26)
			c_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			c_edit.add_theme_font_size_override("font_size", 16)
			var captured_idx = i
			c_edit.text_changed.connect(func(new_text):
				_update_choice_text(captured_idx, new_text)
			)
			
			var c_out = Label.new()
			c_out.text = "[%d] ▶" % (i + 1)
			c_out.modulate = Color(0.3, 0.75, 1.0)
			c_out.add_theme_font_size_override("font_size", 16)
			
			row.add_child(c_edit)
			row.add_child(c_out)
			add_child(row)
			set_slot(slot_idx, false, 0, Color.TRANSPARENT, true, 0, Color(0.3, 0.75, 1.0))
			slot_idx += 1
			
		# Cancel Slot
		var cancel_row = HBoxContainer.new()
		var cancel_sp = Control.new()
		cancel_sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var cancel_lbl = Label.new()
		cancel_lbl.text = "When Cancel ▶"
		cancel_lbl.modulate = Color(1.0, 0.5, 0.2)
		cancel_lbl.add_theme_font_size_override("font_size", 16)
		cancel_row.add_child(cancel_sp)
		cancel_row.add_child(cancel_lbl)
		add_child(cancel_row)
		set_slot(slot_idx, false, 0, Color.TRANSPARENT, true, 0, Color(1.0, 0.5, 0.2))
		slot_idx += 1
		
		# Continuation / Merge Slot
		var merge_row = HBoxContainer.new()
		var merge_sp = Control.new()
		merge_sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var merge_lbl = Label.new()
		merge_lbl.text = "Continue ▶ (Unión)"
		merge_lbl.modulate = Color(0.95, 0.85, 0.2)
		merge_lbl.add_theme_font_size_override("font_size", 16)
		merge_row.add_child(merge_sp)
		merge_row.add_child(merge_lbl)
		add_child(merge_row)
		set_slot(slot_idx, false, 0, Color.TRANSPARENT, true, 0, Color(0.95, 0.85, 0.2))
		slot_idx += 1
		
		# Bottom Action Row
		var action_row = HBoxContainer.new()
		var btn_sp = Control.new()
		btn_sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		action_row.add_child(btn_sp)
		
		edit_button = Button.new()
		edit_button.name = "EditChoicesButton"
		edit_button.text = "✏️ Advanced Choices..."
		edit_button.tooltip_text = "[title]Editor de Opciones[/title]\nAbre la ventana de configuración avanzada de opciones."
		edit_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		edit_button.focus_mode = Control.FOCUS_NONE
		edit_button.add_theme_font_size_override("font_size", 16)
		edit_button.pressed.connect(func(): request_edit_dialog.emit(self))
		action_row.add_child(edit_button)
		
		add_child(action_row)
		set_slot(slot_idx, false, 0, Color.TRANSPARENT, false, 0, Color.TRANSPARENT)
		size = Vector2.ZERO

	func _update_choice_text(idx: int, new_text: String) -> void:
		if idx < choice_labels.size():
			choice_labels[idx] = new_text
		# Update sub_command code 5
		var count = 0
		for sub in sub_commands:
			if sub.code == 5:
				if count == idx:
					sub.parameters["name"] = new_text
					break
				count += 1
		command_modified.emit(self)
#endregion


#region Loop Node
class EventLoopGraphNode extends GraphNode:
	var command: RPGEventCommand
	var sub_commands: Array[RPGEventCommand] = []
	
	signal command_modified(node: GraphNode)
	signal request_delete(node: GraphNode)
	
	func _ready() -> void:
		title = "🔁 Loop"
		resizable = false
		add_theme_font_size_override("title_font_size", 16)
		custom_minimum_size = Vector2(250, 0)
		BranchGraphNodes.setup_node_close_button(self, func(): request_delete.emit(self))
		
	func setup(p_command: RPGEventCommand, p_sub_commands: Array[RPGEventCommand] = []) -> void:
		command = p_command
		sub_commands = p_sub_commands
		
		clear_all_slots()
		var existing_row0 = get_node_or_null("Row0")
		if not existing_row0:
			for child in get_children():
				remove_child(child)
				child.queue_free()
				
			# Slot 0: In / Loop Body
			var row0 = HBoxContainer.new()
			row0.name = "Row0"
			var in_lbl = Label.new()
			in_lbl.name = "InLabel"
			in_lbl.text = "▶ In"
			in_lbl.add_theme_font_size_override("font_size", 16)
			var sp0 = Control.new()
			sp0.name = "Spacer"
			sp0.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var body_lbl = Label.new()
			body_lbl.name = "BodyLabel"
			body_lbl.text = "Body ▶ (Repetir)"
			body_lbl.modulate = Color(0.3, 0.85, 0.95)
			body_lbl.add_theme_font_size_override("font_size", 16)
			row0.add_child(in_lbl)
			row0.add_child(sp0)
			row0.add_child(body_lbl)
			add_child(row0)
			
			# Slot 1: Break Loop Exit
			var row1 = HBoxContainer.new()
			row1.name = "Row1"
			var sp1 = Control.new()
			sp1.name = "Spacer"
			sp1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var exit_lbl = Label.new()
			exit_lbl.name = "ExitLabel"
			exit_lbl.text = "After Break ▶ (Salida)"
			exit_lbl.modulate = Color(1.0, 0.4, 0.3)
			exit_lbl.add_theme_font_size_override("font_size", 16)
			row1.add_child(sp1)
			row1.add_child(exit_lbl)
			add_child(row1)

		set_slot(0, true, 0, Color(0.8, 0.8, 0.8), true, 0, Color(0.3, 0.85, 0.95))
		set_slot(1, false, 0, Color.TRANSPARENT, true, 0, Color(1.0, 0.4, 0.3))
		size = Vector2.ZERO
#endregion


#region Battle Node
class EventBattleGraphNode extends GraphNode:
	var command: RPGEventCommand
	var sub_commands: Array[RPGEventCommand] = []
	var summary_label: Label
	var edit_button: Button
	var collapse_btn: Button
	var content_vbox: VBoxContainer
	var is_collapsed: bool = false
	
	signal command_modified(node: GraphNode)
	signal request_delete(node: GraphNode)
	signal request_edit_dialog(node: GraphNode)
	signal collapse_changed(node: GraphNode, is_collapsed: bool)
	
	func _ready() -> void:
		title = "⚔️ Start Battle"
		resizable = false
		add_theme_font_size_override("title_font_size", 16)
		custom_minimum_size = Vector2(290, 0)
		BranchGraphNodes.setup_node_close_button(self, func(): request_delete.emit(self))

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			if event.double_click and event.is_pressed():
				accept_event()
				request_edit_dialog.emit(self)
		
	func setup(p_command: RPGEventCommand, p_sub_commands: Array[RPGEventCommand] = []) -> void:
		command = p_command
		sub_commands = p_sub_commands
		
		clear_all_slots()
		var existing_content = get_node_or_null("ContentBox")
		var existing_row0 = get_node_or_null("Row0")
		if not existing_content or not existing_row0:
			for child in get_children():
				remove_child(child)
				child.queue_free()
				
			# Slot 0: In / Win
			var row0 = HBoxContainer.new()
			row0.name = "Row0"
			var in_lbl = Label.new()
			in_lbl.name = "InLabel"
			in_lbl.text = "▶ In"
			in_lbl.add_theme_font_size_override("font_size", 16)
			
			collapse_btn = Button.new()
			collapse_btn.name = "CollapseButton"
			collapse_btn.text = "▶" if is_collapsed else "▼"
			collapse_btn.flat = true
			collapse_btn.tooltip_text = "[title]Contraer / Expandir Batalla[/title]\nAlterna la visualización del panel de batalla."
			collapse_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			collapse_btn.focus_mode = Control.FOCUS_NONE
			collapse_btn.pressed.connect(_on_collapse_toggled)
			
			var sp0 = Control.new()
			sp0.name = "Spacer"
			sp0.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var win_lbl = Label.new()
			win_lbl.name = "WinLabel"
			win_lbl.text = "Win ▶ (Victoria)"
			win_lbl.modulate = Color(0.2, 0.9, 0.4)
			win_lbl.add_theme_font_size_override("font_size", 16)
			row0.add_child(in_lbl)
			row0.add_child(collapse_btn)
			row0.add_child(sp0)
			row0.add_child(win_lbl)
			add_child(row0)
			
			# Slot 1: Escape
			var row1 = HBoxContainer.new()
			row1.name = "Row1"
			var sp1 = Control.new()
			sp1.name = "Spacer"
			sp1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var esc_lbl = Label.new()
			esc_lbl.name = "EscapeLabel"
			esc_lbl.text = "Escape ▶ (Huida)"
			esc_lbl.modulate = Color(0.3, 0.75, 1.0)
			esc_lbl.add_theme_font_size_override("font_size", 16)
			row1.add_child(sp1)
			row1.add_child(esc_lbl)
			add_child(row1)
			
			# Slot 2: Defeat
			var row2 = HBoxContainer.new()
			row2.name = "Row2"
			var sp2 = Control.new()
			sp2.name = "Spacer"
			sp2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var def_lbl = Label.new()
			def_lbl.name = "DefeatLabel"
			def_lbl.text = "Defeat ▶ (Derrota)"
			def_lbl.modulate = Color(1.0, 0.4, 0.3)
			def_lbl.add_theme_font_size_override("font_size", 16)
			row2.add_child(sp2)
			row2.add_child(def_lbl)
			add_child(row2)
			
			# Slot 3: Continue / Merge
			var row3 = HBoxContainer.new()
			row3.name = "Row3"
			var sp3 = Control.new()
			sp3.name = "Spacer"
			sp3.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var merge_lbl = Label.new()
			merge_lbl.name = "MergeLabel"
			merge_lbl.text = "Continue ▶ (Unión)"
			merge_lbl.modulate = Color(0.95, 0.85, 0.2)
			merge_lbl.add_theme_font_size_override("font_size", 16)
			row3.add_child(sp3)
			row3.add_child(merge_lbl)
			add_child(row3)
			
			# Slot 4: Info & Button
			content_vbox = VBoxContainer.new()
			content_vbox.name = "ContentBox"
			summary_label = Label.new()
			summary_label.name = "SummaryLabel"
			summary_label.text = "Troop #%s" % command.parameters.get("troop_id", 1)
			summary_label.add_theme_font_size_override("font_size", 16)
			content_vbox.add_child(summary_label)
			
			var action_row = HBoxContainer.new()
			action_row.name = "ActionRow"
			var btn_sp = Control.new()
			btn_sp.name = "Spacer"
			btn_sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			action_row.add_child(btn_sp)
			
			edit_button = Button.new()
			edit_button.name = "EditBattleButton"
			edit_button.text = "✏️ Edit Battle..."
			edit_button.tooltip_text = "[title]Editor de Batalla[/title]\nAbre el diálogo de configuración de batalla."
			edit_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			edit_button.focus_mode = Control.FOCUS_NONE
			edit_button.add_theme_font_size_override("font_size", 16)
			edit_button.pressed.connect(func(): request_edit_dialog.emit(self))
			action_row.add_child(edit_button)
			
			content_vbox.add_child(action_row)
			add_child(content_vbox)
		else:
			collapse_btn = existing_row0.get_node_or_null("CollapseButton")
			if collapse_btn and not collapse_btn.pressed.is_connected(_on_collapse_toggled):
				collapse_btn.pressed.connect(_on_collapse_toggled)
			content_vbox = existing_content
			summary_label = content_vbox.get_node_or_null("SummaryLabel")
			var action_row = content_vbox.get_node_or_null("ActionRow")
			if action_row:
				edit_button = action_row.get_node_or_null("EditBattleButton")
				if edit_button:
					var cb = func(): request_edit_dialog.emit(self)
					if not edit_button.pressed.is_connected(cb):
						edit_button.pressed.connect(cb)

		set_slot(0, true, 0, Color(0.8, 0.8, 0.8), true, 0, Color(0.2, 0.9, 0.4))
		set_slot(1, false, 0, Color.TRANSPARENT, true, 0, Color(0.3, 0.75, 1.0))
		set_slot(2, false, 0, Color.TRANSPARENT, true, 0, Color(1.0, 0.4, 0.3))
		set_slot(3, false, 0, Color.TRANSPARENT, true, 0, Color(0.95, 0.85, 0.2))
		set_slot(4, false, 0, Color.TRANSPARENT, false, 0, Color.TRANSPARENT)
		update_visuals()
		size = Vector2.ZERO
		if is_collapsed:
			set_collapsed(true, false)
		
	func set_collapsed(p_collapsed: bool, emit_sig: bool = true) -> void:
		is_collapsed = p_collapsed
		if collapse_btn:
			collapse_btn.text = "▶" if is_collapsed else "▼"
		if content_vbox:
			content_vbox.visible = !is_collapsed
		if is_collapsed:
			custom_minimum_size = Vector2(220, 0)
		else:
			custom_minimum_size = Vector2(290, 0)
		size = Vector2.ZERO
		if emit_sig:
			collapse_changed.emit(self, is_collapsed)

	func _on_collapse_toggled() -> void:
		set_collapsed(!is_collapsed, true)
		
	func update_visuals() -> void:
		if summary_label and command:
			summary_label.text = "Troop #%s" % command.parameters.get("troop_id", 1)
		size = Vector2.ZERO
#endregion


# Backward compatibility aliases
const StartGraphNode = EventStartGraphNode
const ConditionGraphNode = EventConditionGraphNode
const ChoiceGraphNode = EventChoiceGraphNode
const LoopGraphNode = EventLoopGraphNode
const BattleGraphNode = EventBattleGraphNode
