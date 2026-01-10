extends CanvasLayer

@export var window_focused_style: StyleBox
@export var window_unfocused_style: StyleBox
@export var fill_texture: Texture


const TAB_BUTTON = preload("res://addons/CustomControls/custom_button.tscn")

var is_enabled: bool = false
var current_tab: String
var busy: bool = false
var backup_mouse_position: Vector2

var current_data: Array = []

@onready var data_list: VBoxContainer = %DataList


func _ready() -> void:
	%DataList.get_item_list().focus_mode = Control.FOCUS_CLICK
	%DataList.get_item_list().gui_input.connect(_on_data_list_gui_input)
	%DataList.get_v_scroll_bar().value_changed.connect(func(_value): update_function_button())
	%DataList.get_item_list().mouse_exited.connect(func(): %FunctionButtonContainer.visible = false)
	%DataList.get_item_list().focus_entered.connect(_on_item_list_focus_entered)
	create_tabs()
	%FunctionButtonContainer.visible = false
	hide()


func _process(_delta: float) -> void:
	if not visible or not is_enabled: return
	
	if data_list and not data_list.get_item_list().has_focus():
		var direction = ControllerManager.get_pressed_direction()
		if direction:
			if ["up", "down"].has(direction):
				var current_button = get_viewport().gui_get_focus_owner()
				#var next_control = GameManager.controller.get_closest_focusable_control(current_button, direction)
				var next_control = ControllerManager.get_closest_focusable_control(current_button, direction)
				if next_control:
					next_control.grab_focus()


func _on_item_list_focus_entered() -> void:
	if current_data.size() == 0:
		var button = %TabContainer.get_child(0).button_group.get_pressed_button()
		button.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if busy:
		return
		
	if event.is_action_pressed("DebugKey") and not GameManager.busy and not GameInterpreter.is_busy():
		if !is_enabled:
			%TabContainer.get_child(0).button_group.get_pressed_button().toggled.emit(true)
			start()
		else:
			end()
	elif is_enabled and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("DebugKey")):
		end()


func start() -> void:
	GameManager.manage_cursor(self, Vector2(-20, 0))
	GameManager.busy = true
	busy = true
	get_viewport().set_input_as_handled()
	$MainContainer.modulate.a = 0
	show()
	var t = create_tween()
	t.tween_property($MainContainer, "modulate:a", 1.0, 0.35)
	t.tween_callback(
		func():
			set("is_enabled", true)
			set("busy", false)
			GameManager.force_hand_position_over_node(self)
			GameManager.show_cursor(MainHandCursor.HandPosition.LEFT, self)
	)


func end() -> void:
	busy = true
	var focus_owner = get_viewport().gui_get_focus_owner()
	if focus_owner:
		focus_owner.release_focus()
	get_viewport().set_input_as_handled()
	
	GameManager.hide_cursor(false, self)

	if GameManager.current_map:
		GameManager.current_map.refresh_events()
	var t = create_tween()
	t.tween_property($MainContainer, "modulate:a", 0.0, 0.35)
	t.tween_callback(set.bind("is_enabled", false))
	t.tween_callback(set.bind("busy", false))
	t.tween_callback(GameManager.set.bind("busy", false))
	t.tween_callback(hide)


func create_tabs() -> void:
	var node = %TabContainer
	var tabs = ["Switches", "Variables", "Text Variables", "Self Switches"]
	var tabs_singular = ["Switch", "Variable", "Text Variable", "Self Switch"]
	var button_group = ButtonGroup.new()
	for i in tabs.size():
		var button = TAB_BUTTON.instantiate()
		button.text = tabs[i]
		button.button_group = button_group
		button.toggle_mode = true
		button.focus_mode = Control.FOCUS_CLICK
		button.set("theme_override_colors/font_hover_color", Color(25, 25, 25, 1))
		button.set("theme_override_colors/font_color", Color(25, 25, 25, 1))
		button.set("theme_override_colors/font_pressed_color", Color(25, 25, 25, 1))
		button.modulate = Color("#d19b7e")
		button.toggled.connect(_load_data.bind(tabs_singular[i]))
		node.add_child(button)
	
	node.get_child(0).set_pressed(true)


func _set_label_info(text: String) -> void:
	%BottomLabelInfo.text = text


func _load_data(value: bool, tab: String, selected_id: int = 0) -> void:
	backup_mouse_position = %DataList.get_local_mouse_position()
	if value:
		current_tab = tab
	if value and GameManager.game_state:
		var data
		var real_data
		match tab:
			"Switch":
				data = GameManager.game_state.game_switches
				real_data = RPGSYSTEM.system.switches
				_set_label_info("Use 🢀 Left or 🢂 Right To change the value.")
			"Variable":
				data = GameManager.game_state.game_variables
				real_data = RPGSYSTEM.system.variables
				_set_label_info("Use 🢀 Left or 🢂 Right To change the value. Or double click to enter value manually")
			"Text Variable":
				data = GameManager.game_state.game_text_variables
				real_data = RPGSYSTEM.system.text_variables
				_set_label_info("Double click to enter value manually")
			"Self Switch":
				data = GameManager.game_state.game_self_switches
				real_data = RPGSYSTEM.system.self_switches
				_set_label_info("Use 🢀 Left or 🢂 Right To change the value.")
		
		await fill_data(tab, data, real_data, selected_id)


func fill_data(tab: String, data : Variant, real_data: Variant, selected_id: int) -> void:
	var node = %DataList
	var scroll_bar_y_value = node.get_v_scroll_bar().value
	var last_selected_index = node.get_selected_items()
	var last_item_count = node.get_item_count()
	node.clear()
	current_data.clear()
	
	GameManager.hand_cursor.pause_reposition = true
	
	if ["Switch", "Variable", "Text Variable"].has(tab):
		for i in range(1, data.size()):
			var data_name: String = ""
			var n = str(data[i]) if data[i] is String else int(data[i])
			var value = str(n if tab != "Switch" else true if data[i] == 1 else false)
			data_name = real_data.get_item_name(i)
			if !data_name:
				data_name = "%s ID %s" % [tab, i]
			node.add_column([data_name, value])
			current_data.append(data[i])
	
		await node.columns_setted
		
	elif tab == "Self Switch":
		for key: String in data:
			var map_id = int(key.get_slice("_", 0))
			var switch_id = int(key.get_slice("_", 1))
			var map_name = RPGSYSTEM.map_infos.get_map_name_from_id(map_id)
			var switch_name = RPGSYSTEM.system.self_switches.get_self_switch_name(switch_id).to_upper()
			var switch_value = data[key]
			current_data.append(key)
			node.add_column(["Map %s: Switch %s" % [map_name, switch_name], switch_value])
		
		await node.columns_setted
	
	if node.get_item_count() > selected_id:
		node.select(selected_id)
	elif node.get_item_count() > 0:
		node.select(0)
	
	if current_data.size() > 0:
		node.get_item_list().grab_focus()
	
	GameManager.hand_cursor.pause_reposition = false
	
	var new_selected_index = node.get_selected_items()
	var new_item_count = node.get_item_count()
	
	if new_item_count == last_item_count and last_selected_index and new_selected_index and last_selected_index[0] == new_selected_index[0]:
		await get_tree().process_frame
		node.get_v_scroll_bar().value = scroll_bar_y_value
		await get_tree().process_frame
		node.warp_mouse(backup_mouse_position)


func _on_close_button_pressed() -> void:
	end()


func _on_data_list_gui_input(event: InputEvent) -> void:
	if is_enabled:
		if event is InputEventMouseMotion:
			update_function_button()
		else:
			if event.is_action_pressed("ui_left", true):
				call_deferred("change_value", -1)
			elif event.is_action_pressed("ui_right", true):
				call_deferred("change_value", 1)


func update_function_button() -> void:
	var node1 = %DataList
	var node2 = %FunctionButtonContainer
	if node1.get_item_count()  == 0:
		node2.visible = false
		return
		
	var separation_width = node2.get_child(0).get("theme_override_constants/separation")
	var pos = node1.get_local_mouse_position() - Vector2(0, node1.get_item_rect(0).size.y)
	var index = node1.get_item_at_position(pos)
	node2.visible = index >= 0
	
	if index >= 0:
		var node3 = node2.get_child(0)
		%EditValue.visible = current_tab in ["Variable", "Text Variable"]
		%AddValue.visible = current_tab in ["Variable"]
		%SubtractValue.visible = current_tab in ["Variable"]
		%ToggleValue.visible = current_tab in ["Switch", "Self Switch"]
		%RemoveValue.visible = current_tab in ["Self Switch"]
		var button_width = %EditValue.size.x
		var s = 0 if !%EditValue.visible else button_width
		s += button_width + separation_width if %AddValue.visible else 0
		s += button_width + separation_width if %SubtractValue.visible else 0
		s += button_width + separation_width if %ToggleValue.visible else 0
		s += button_width if %RemoveValue.visible else 0
		node3.size.x = s
		
		var offsetx = 12
		var offsety = node1.get_v_scroll_bar().value - node1.get_item_rect(0).size.y
		var rect = node1.get_item_rect(index)
		node3.global_position = Vector2(
			node1.global_position.x + rect.position.x + rect.size.x - node3.size.x - offsetx,
			node1.global_position.y + rect.position.y + rect.size.y * 0.5 - node3.size.y * 0.5 - offsety
		)


func change_value(target_value: Variant) -> void:
	var selected_items = %DataList.get_selected_items()
	if selected_items:
		var item_id = selected_items[0] + 1
		match current_tab:
			"Switch":
				var current_value = GameManager.game_state.game_switches[item_id]
				GameManager.game_state.game_switches[item_id] = 0 if current_value == 1 else 1
			"Variable":
				GameManager.game_state.game_variables[item_id] += int(target_value)
	
		await _load_data(true, current_tab, item_id - 1)
	
	get_viewport().set_input_as_handled()


func _on_data_list_item_activated(index: int) -> void:
	# tabs = "Switches", "Variables", "Text Variables", "Self Switches"
	backup_mouse_position = %DataList.get_local_mouse_position()
	var real_index = index
	match current_tab:
		"Switch": change_value(null)
		"Variable": _edit_value(real_index)
		"Text Variable": _edit_value(real_index)
		"Self Switch": change_self_switch(real_index)


func change_text_variable(_index: int) -> void:
	pass


func change_self_switch(index: int) -> void:
	if current_data:
		GameManager.game_state.game_self_switches[current_data[index]] = !GameManager.game_state.game_self_switches[current_data[index]]
		
		var data = GameManager.game_state.game_self_switches
		var real_data = RPGSYSTEM.system.self_switches
		fill_data("Self Switch", data, real_data, index)


func select_item_under_mouse() -> int:
	var node = %DataList
	var pos = node.get_local_mouse_position() - Vector2(0, node.get_item_rect(0).size.y)
	var index = node.get_item_at_position(pos)
	if index >= 0:
		node.select(index)
	
	backup_mouse_position = node.get_local_mouse_position()
	
	return index


func _on_add_value_pressed() -> void:
	if select_item_under_mouse() != -1:
		change_value(1)


func _on_subtract_value_pressed() -> void:
	if select_item_under_mouse() != -1:
		change_value(-1)


func _on_toggle_value_pressed() -> void:
	var index = select_item_under_mouse()
	if index != -1:
		_on_data_list_item_activated(index)


func _on_edit_value_pressed() -> void:
	var index = select_item_under_mouse()
	if index != -1:
		_edit_value(index)


func _edit_value(index: int) -> void:
	backup_mouse_position = %DataList.get_local_mouse_position()
	match current_tab:
		"Variable":
			_open_number_dialog(index)
		"Text Variable":
			_open_text_dialog(index)


func stylize_dialog(dialog: Window) -> void:
	dialog.set("theme_override_styles/embedded_border", window_focused_style)
	dialog.set("theme_override_styles/embedded_unfocused_border", window_unfocused_style)
	var background: TextureRect = dialog.get_node_or_null("Background")
	if background:
		background.texture = fill_texture
	
	stylize_buttons_in_dialog(dialog)


func stylize_buttons_in_dialog(node: Node) -> void:
	if node is Button:
		node.modulate = Color("#d19b7e")
		node.set("theme_override_colors/font_hover_color", Color(20, 20, 20))
		node.set("theme_override_colors/font_pressed_color", Color(20, 20, 20))
		node.set("theme_override_colors/font_color", Color(20, 20, 20))
	
	for child in node.get_children():
		stylize_buttons_in_dialog(child)


func _open_number_dialog(index: int) -> void:
	var path = "res://addons/CustomControls/Dialogs/select_number_value_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED)
	stylize_dialog(dialog)
	
	dialog.title = tr("Select Variable" + " #" + str([index + 1])) + " " + tr("value")
	dialog.set_min_max_values(0, 0)
	
	dialog.set_value(GameManager.game_state.game_variables[index + 1])
	dialog.selected_value.connect(
		func(value: int):
			GameManager.game_state.game_variables[index + 1] = value
			var data = GameManager.game_state.game_variables
			var real_data = RPGSYSTEM.system.variables
			fill_data(current_tab, data, real_data, index)
	)


func _open_text_dialog(index: int) -> void:
	var path = "res://addons/CustomControls/Dialogs/select_text_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED)
	stylize_dialog(dialog)
	dialog.title =  tr("Select Variable" + " #" + str([index + 1])) + " " + tr("value")
	dialog.force_emit = true
	dialog.set_text(GameManager.game_state.game_text_variables[index + 1])
	dialog.text_selected.connect(
		func(value: String):
			GameManager.game_state.game_text_variables[index + 1] = value
			var data = GameManager.game_state.game_text_variables
			var real_data = RPGSYSTEM.system.text_variables
			fill_data(current_tab, data, real_data, index)
	)


func _on_remove_value_pressed() -> void:
	var index = select_item_under_mouse()
	if current_data and index != -1:
		GameManager.game_state.game_self_switches.erase(current_data[index])
		var data = GameManager.game_state.game_self_switches
		var real_data = RPGSYSTEM.system.self_switches
		fill_data("Self Switch", data, real_data, index)
