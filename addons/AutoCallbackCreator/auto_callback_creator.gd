@tool
extends EditorPlugin

var script_editor: ScriptEditor
var current_popup: PopupMenu

const CALLBACK_CODE_INDEX = 1500
const GETTER_SETTER_CODE_INDEX = 1501


func _enter_tree():
	script_editor = EditorInterface.get_script_editor()
	script_editor.connect("editor_script_changed", _on_script_changed)
	_setup_current_script()


func _exit_tree():
	if script_editor and script_editor.is_connected("editor_script_changed", _on_script_changed):
		script_editor.disconnect("editor_script_changed", _on_script_changed)
	_cleanup_current_script()


func _handles(object) -> bool:
	return object is Script


func _input(event):
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_C and event.ctrl_pressed and event.shift_pressed:
			if event.alt_pressed:
				if _handle_getter_setter_hotkey():
					get_viewport().set_input_as_handled()
			else:
				if _handle_callback_hotkey():
					get_viewport().set_input_as_handled()


func _handle_callback_hotkey() -> bool:
	var current_editor = script_editor.get_current_editor()
	if not current_editor:
		return false
		
	var code_edit = _find_code_edit(current_editor)
	if not code_edit:
		return false
		
	var selected_text = code_edit.get_selected_text().strip_edges()
	
	if selected_text.is_empty():
		return false
	
	if _should_show_create_callback(code_edit, selected_text):
		_create_callback(selected_text, code_edit, false)
		return true
	
	return false


func _handle_getter_setter_hotkey() -> bool:
	var current_editor = script_editor.get_current_editor()
	if not current_editor:
		return false
		
	var code_edit = _find_code_edit(current_editor)
	if not code_edit:
		return false
		
	var selected_text = code_edit.get_selected_text().strip_edges()
	
	if selected_text.is_empty():
		selected_text = _get_word_under_cursor(code_edit)
	
	if selected_text.is_empty():
		return false
	
	if _should_show_create_getter_setter(code_edit, selected_text):
		_create_getter_setter(selected_text, code_edit, false)
		return true
	
	return false


func _on_script_changed(_script):
	_setup_current_script()


func _setup_current_script():
	_cleanup_current_script()
	var current_editor = script_editor.get_current_editor()
	if current_editor:
		var code_edit = _find_code_edit(current_editor)
		if code_edit:
			current_popup = _find_popup_menu(current_editor)
			if current_popup:
				current_popup.connect("about_to_popup", _on_popup_about_to_show)


func _cleanup_current_script():
	if current_popup and current_popup.is_connected("about_to_popup", _on_popup_about_to_show):
		current_popup.disconnect("about_to_popup", _on_popup_about_to_show)
	current_popup = null


func _find_code_edit(node: Node) -> CodeEdit:
	if node is CodeEdit:
		return node
	for child in node.get_children():
		var result = _find_code_edit(child)
		if result:
			return result
	return null


func _find_popup_menu(node: Node) -> PopupMenu:
	if node is PopupMenu:
		return node
	for child in node.get_children():
		var result = _find_popup_menu(child)
		if result:
			return result
	return null


func _on_popup_about_to_show():
	var current_editor = script_editor.get_current_editor()
	if not current_editor:
		return
		
	var code_edit = _find_code_edit(current_editor)
	if not code_edit:
		return
		
	var selected_text = code_edit.get_selected_text().strip_edges()
	
	if selected_text.is_empty():
		selected_text = _get_word_under_cursor(code_edit)
	
	if selected_text.is_empty():
		return
	
	if _should_show_create_callback(code_edit, selected_text):
		current_popup.add_separator()
		var menu_text = "Create callback: " + selected_text
		current_popup.add_item(menu_text, CALLBACK_CODE_INDEX)
		
		if current_popup.is_connected("id_pressed", _on_menu_item_pressed):
			current_popup.disconnect("id_pressed", _on_menu_item_pressed)
		
		current_popup.connect("id_pressed", _on_menu_item_pressed.bind(selected_text, code_edit))
	
	if _should_show_create_getter_setter(code_edit, selected_text):
		if not current_popup.get_item_count() > 0 or current_popup.get_item_text(current_popup.get_item_count() - 1) != "":
			current_popup.add_separator()
		
		var getter_setter_text = "Create getter/setter: " + selected_text
		current_popup.add_item(getter_setter_text, GETTER_SETTER_CODE_INDEX)
		
		if current_popup.is_connected("id_pressed", _on_menu_item_pressed):
			current_popup.disconnect("id_pressed", _on_menu_item_pressed)
		
		current_popup.connect("id_pressed", _on_menu_item_pressed.bind(selected_text, code_edit))


func _get_word_under_cursor(code_edit: CodeEdit) -> String:
	var caret_line = code_edit.get_caret_line()
	var caret_column = code_edit.get_caret_column()
	var line_text = code_edit.get_line(caret_line)
	
	var start = caret_column
	while start > 0 and line_text[start - 1].is_subsequence_of("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_"):
		start -= 1
	
	var end = caret_column
	while end < line_text.length() and line_text[end].is_subsequence_of("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_"):
		end += 1
	
	return line_text.substr(start, end - start)


func _get_indentation_settings() -> Dictionary:
	var editor_settings = EditorInterface.get_editor_settings()
	var indent_type = editor_settings.get_setting("text_editor/behavior/indent/type")
	var indent_size = editor_settings.get_setting("text_editor/behavior/indent/size")
	
	if indent_type == 0:
		return {"type": "tabs", "count": 1}
	else:
		return {"type": "spaces", "count": indent_size}


func _should_show_create_callback(code_edit: CodeEdit, text: String) -> bool:
	var script_text = code_edit.text
	
	var regex = RegEx.new()
	regex.compile("^[a-zA-Z_][a-zA-Z0-9_]*$")
	if not regex.search(text):
		return false
	
	if _function_exists_anywhere(script_text, text):
		return false
	
	if _global_variable_exists(script_text, text):
		return false
	
	if _local_variable_exists_in_current_function(code_edit, text):
		return false
	
	if _is_in_comment(code_edit, text):
		return false
	
	return true


func _should_show_create_getter_setter(code_edit: CodeEdit, text: String) -> bool:
	var script_text = code_edit.text
	
	var regex = RegEx.new()
	regex.compile("^[a-zA-Z_][a-zA-Z0-9_]*$")
	if not regex.search(text):
		return false
	
	if not _global_variable_exists(script_text, text):
		return false
	
	if _variable_has_getter_setter(script_text, text):
		return false
	
	if _is_in_comment(code_edit, text):
		return false
	
	return true


func _variable_has_getter_setter(script_text: String, var_name: String) -> bool:
	var regex = RegEx.new()
	regex.compile("var\\s+" + var_name + "\\s*:.*\\b(set|get)\\b")
	return regex.search(script_text) != null


func _function_exists_anywhere(script_text: String, func_name: String) -> bool:
	var regex = RegEx.new()
	regex.compile("func\\s+" + func_name + "\\s*\\(")
	return regex.search(script_text) != null


func _global_variable_exists(script_text: String, var_name: String) -> bool:
	var lines = script_text.split("\n")
	var inside_function = false
	
	for i in range(lines.size()):
		var line = lines[i]
		var trimmed = line.strip_edges()
		
		if trimmed.begins_with("func "):
			inside_function = true
			continue
		
		if not inside_function:
			var regex = RegEx.new()
			regex.compile("^var\\s+" + var_name + "\\b")
			if regex.search(trimmed):
				return true
		else:
			if trimmed.is_empty():
				continue
			elif not line.begins_with("\t") and not line.begins_with(" ") and trimmed != "":
				inside_function = false
				var regex = RegEx.new()
				regex.compile("^var\\s+" + var_name + "\\b")
				if regex.search(trimmed):
					return true
	
	return false


func _local_variable_exists_in_current_function(code_edit: CodeEdit, var_name: String) -> bool:
	var script_text = code_edit.text
	var current_line = code_edit.get_caret_line()
	
	var function_start = -1
	var function_end = -1
	var lines = script_text.split("\n")
	
	for i in range(current_line, -1, -1):
		if i < lines.size():
			var line = lines[i].strip_edges()
			if line.begins_with("func "):
				function_start = i
				break
	
	if function_start == -1:
		return false
	
	for i in range(function_start + 1, lines.size()):
		var line = lines[i].strip_edges()
		if line.begins_with("func ") or (line != "" and not lines[i].begins_with("\t") and not lines[i].begins_with(" ")):
			function_end = i - 1
			break
	
	if function_end == -1:
		function_end = lines.size() - 1
	
	for i in range(function_start, function_end + 1):
		if i < lines.size():
			var line = lines[i].strip_edges()
			
			var regex = RegEx.new()
			regex.compile("^var\\s+" + var_name + "\\b")
			if regex.search(line):
				return true
			
			if i == function_start:
				var param_regex = RegEx.new()
				param_regex.compile("func\\s+\\w+\\s*\\([^)]*\\b" + var_name + "\\b")
				if param_regex.search(line):
					return true
	
	return false


func _is_in_comment(code_edit: CodeEdit, selected_text: String) -> bool:
	var caret_line = code_edit.get_caret_line()
	var line_text = code_edit.get_line(caret_line)
	var selection_start = code_edit.get_selection_from_column()
	
	var comment_pos = line_text.find("#")
	if comment_pos != -1 and comment_pos < selection_start:
		return true
	
	return false


func _on_menu_item_pressed(id: int, original_text: String, code_edit: CodeEdit):
	if id == CALLBACK_CODE_INDEX:
		_create_callback(original_text, code_edit)
	elif id == GETTER_SETTER_CODE_INDEX:
		_create_getter_setter(original_text, code_edit)


func _create_getter_setter(property_name: String, code_edit: CodeEdit, enable_shift_check: bool = true):
	var shift_pressed = enable_shift_check and Input.is_key_pressed(KEY_SHIFT)
	var original_selection = null
	
	if shift_pressed:
		original_selection = {
			"from_line": code_edit.get_selection_from_line(),
			"from_column": code_edit.get_selection_from_column(),
			"to_line": code_edit.get_selection_to_line(),
			"to_column": code_edit.get_selection_to_column()
		}
	
	code_edit.deselect()
	
	var script_text = code_edit.text
	var lines = script_text.split("\n")
	
	var variable_line_index = -1
	for i in range(lines.size()):
		var line = lines[i].strip_edges()
		var regex = RegEx.new()
		regex.compile("^var\\s+" + property_name + "\\b")
		if regex.search(line):
			variable_line_index = i
			break
	
	if variable_line_index == -1:
		return
	
	var setter_name = "_on_set_" + property_name
	var getter_name = "_on_get_" + property_name
	
	var original_line = lines[variable_line_index]
	var type_annotation = ""
	var clean_type = ""
	var colon_pos = original_line.find(":")
	var equals_pos = original_line.find("=")
	
	if colon_pos != -1:
		if equals_pos != -1 and equals_pos > colon_pos:
			type_annotation = original_line.substr(colon_pos, equals_pos - colon_pos).strip_edges()
		else:
			type_annotation = original_line.substr(colon_pos).strip_edges()
		
		var type_end = type_annotation.find("=")
		if type_end != -1:
			type_annotation = type_annotation.substr(0, type_end).strip_edges()
		
		clean_type = type_annotation.lstrip(":").strip_edges()
	
	var new_variable_line = "var " + property_name + type_annotation + ": set = " + setter_name + ", get = " + getter_name
	lines[variable_line_index] = new_variable_line
	
	var indentation_info = _get_indentation_settings()
	var indent_string = ""
	
	if indentation_info.type == "tabs":
		indent_string = "\t"
	else:
		indent_string = " ".repeat(indentation_info.count)
	
	var setter_signature = "func " + setter_name + "(value"
	var getter_signature = "func " + getter_name + "()"
	
	if clean_type != "":
		setter_signature += ": " + clean_type + ") -> void:"
		getter_signature += " -> " + clean_type + ":"
	else:
		setter_signature += "):"
		getter_signature += ":"
	
	var new_functions = "\n\n" + setter_signature + "\n" + indent_string + property_name + " = value"
	new_functions += "\n\n" + getter_signature + "\n" + indent_string + "return " + property_name
	
	var new_script_text = "\n".join(lines) + new_functions
	code_edit.text = new_script_text
	
	if shift_pressed and original_selection:
		code_edit.select(original_selection.from_line, original_selection.from_column, 
						original_selection.to_line, original_selection.to_column)
	else:
		var line_count = code_edit.get_line_count()
		var setter_line = line_count - 3
		var value_pos = (property_name + " = value").length() + indent_string.length()
		
		code_edit.set_caret_line(setter_line)
		code_edit.set_caret_column(value_pos)
	
	code_edit.text_changed.emit()


func _create_callback(function_name: String, code_edit: CodeEdit, enable_shift_check: bool = true):
	var shift_pressed = enable_shift_check and Input.is_key_pressed(KEY_SHIFT)
	var original_selection = null
	
	if shift_pressed:
		original_selection = {
			"from_line": code_edit.get_selection_from_line(),
			"from_column": code_edit.get_selection_from_column(),
			"to_line": code_edit.get_selection_to_line(),
			"to_column": code_edit.get_selection_to_column()
		}
	
	code_edit.deselect()
	
	var indentation_info = _get_indentation_settings()
	var indent_string = ""
	
	if indentation_info.type == "tabs":
		indent_string = "\t"
	else:
		indent_string = " ".repeat(indentation_info.count)
	
	var new_function = "\n\nfunc " + function_name + "():\n" + indent_string + "pass"
	
	code_edit.text = code_edit.text + new_function
	
	if shift_pressed and original_selection:
		code_edit.select(original_selection.from_line, original_selection.from_column, 
						original_selection.to_line, original_selection.to_column)
	else:
		var line_count = code_edit.get_line_count()
		var pass_line = line_count - 1
		var pass_start = indent_string.length()
		
		code_edit.set_caret_line(pass_line)
		code_edit.set_caret_column(pass_start)
		
		code_edit.select(pass_line, pass_start, pass_line, pass_start + 4)
	
	code_edit.text_changed.emit()
