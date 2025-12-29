@tool
extends Window


var last_tab_index = -1
var data: RPGEffect
var target: int
var database: RPGDATA
var target_callable: Callable
var need_fix_size_timer: float = 0.0

var default_data = RPGEffect.new()

var select_any_data_dialog

var filter_update_timer: float = 0.0
var filter_nodes: Array = []
var last_filter_used: String

var data_id_cache = {
	3 : 1,
	4 : 1,
	11 : 1,
	12 : 1
}


func _ready() -> void:
	_setup_filter_metas()
	close_requested.connect(hide)
	visibility_changed.connect(_on_visibility_changed)
	%FilterSmoothContainer.get_v_scroll_bar().changed.connect(_update_window_size_by_filter_container)
	propagate_call("set_disabled", [true])
	%Filter.set_disabled(false)
	set_inital_panels_visibility()
	add_tabs()
	add_button_group_and_connections(self, ButtonGroup.new())
	%OKButton.set_disabled(false)
	%CancelButton.set_disabled(false)
	%TabsContainer.select(0, true)
	%"C0-1".set_pressed(true)
	%"C0-1".toggled.emit(true)
	fill_all()
	need_fix_size_timer = 0.04


func _setup_filter_metas() -> void:
	var nodes = get_tree().get_nodes_in_group("main_trait_filter_tab")
	for node in nodes:
		node.set_meta("original_parent", {
			"parent": node.get_node(node.focus_neighbor_bottom),
			"index": node.get_index()
		})


func _process(delta: float) -> void:
	if filter_update_timer > 0.0:
		filter_update_timer -= delta
		if filter_update_timer <= 0:
			filter_update_timer = 0.0
			_update_filter()
	#if need_fix_size_timer > 0:
		#need_fix_size_timer -= delta
		#if need_fix_size_timer <= 0:
			#need_fix_size_timer = 0
			#wrap_controls = true
			#await get_tree().process_frame
			#wrap_controls = false


func _update_filter() -> void:
	if last_filter_used != %Filter.text.to_lower():
		_restore_node_parents()
		var filter = %Filter.text.to_lower()
		last_filter_used = filter
		if filter.length() > 0:
			var nodes = _get_filter_controls(%TargetContainer, filter)
			if not nodes.is_empty():
				_filter_controls(nodes)
			else:
				_restore_node_parents()
		else:
			%TargetContainer.visible = true
			%FilterContainer.visible = false
			%TabsContainer.get_parent().visible = true
			size.y = 0


func  _get_filter_controls(root: Node, filter: String) -> Array:
	var controls := []

	if "text" in root and root.text.to_lower().find(filter) != -1:
		var main_container: Container = root.get_parent()
		while main_container and not main_container.is_in_group("main_trait_filter_tab"):
			main_container = main_container.get_parent()

		if main_container and not main_container in controls:
			controls.append(main_container)
			
	elif root is OptionButton:
		for i in root.get_item_count():
			var text = root.get_item_text(i)
			if text.to_lower().find(filter) != -1:
				var main_container: Container = root.get_parent()
				while main_container and not main_container.is_in_group("main_trait_filter_tab"):
					main_container = main_container.get_parent()
				
				if main_container and not main_container in controls:
					if not root.get_parent().get_child(0).is_pressed():
						root.select(i)
					controls.append(main_container)
					break
				
	
	for child in root.get_children():
		controls += _get_filter_controls(child, filter)
	
	return controls


func _filter_controls(controls: Array) -> void:
	_restore_node_parents()
	%TargetContainer.visible = false
	%FilterContainer.visible = true
	%TabsContainer.get_parent().visible = false
	var container = %FlowContainer
	for c: Control in controls:
		if c.get_parent() != container:
			c.reparent(container)
			c.size_flags_horizontal = Control.SIZE_EXPAND_FILL


func _update_window_size_by_filter_container() -> void:
	var vbar = %FilterSmoothContainer.get_v_scroll_bar()
	var max_h = 600
	size.y = max(min_size.y, min((vbar.max_value - vbar.min_value) + vbar.page, max_h))


func _restore_node_parents() -> void:
	var container = %FlowContainer
	for node in container.get_children():
		if node.has_meta("original_parent"):
			var original_parent_data = node.get_meta("original_parent")
			if original_parent_data.parent != node.get_parent():
				node.reparent(original_parent_data.parent)
				original_parent_data.parent.move_child(node, original_parent_data.index)


func set_inital_panels_visibility() -> void:
	var targets = [%Recover, %State, %ParameterBuff, %Other]
	for target in targets:
		target.visible = false


func set_data(_data: RPGEffect, _target: int) -> void:
	if _data:
		data = _data.clone(true)
	else:
		data = default_data.clone(true)
	
	set_tab_and_selected_data()
	
	target = _target


func add_tabs() -> void:
	var tab_container = %TabsContainer
	tab_container.clear()
	var tabs = ["Recover", "State", "Buff Parameter", "Other"]
	for tab in tabs:
		tab_container.add_tab(tab)


func add_button_group_and_connections(node: Node, button_group: ButtonGroup) -> void:
	if node is CheckBox:
		node.set_button_group(button_group)
		if !node.toggled.is_connected(_on_toggled):
			node.toggled.connect(_on_toggled.bind(node))
		node.set_disabled(false)
		node.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	
	for child in node.get_children():
		add_button_group_and_connections(child, button_group)


func _on_toggled(value: bool, node: CheckBox) -> void:
	if !data:
		return
		
	node.get_parent().propagate_call("set_disabled", [!value])
	var value_extra = ["C0-1", "C1-1", "C3-1", "C4-1", "C5-1", "C6-1", "C10-1"].has(node.name)
	if value_extra:
		var other_node = node.get_parent().get_parent().get_child(node.get_parent().get_index() + 1)
		other_node.propagate_call("set_disabled", [!value])
	node.set_disabled(false)
	
	if value:
		var current_code = str(node.name).get_slice("-", 0)
		data.code = int(current_code) + 1


func set_tab_and_selected_data() -> void:
	if !data:
		return
	
	var shown_tab_index = \
			 1 if range(4, 6).has(data.code) \
		else 2 if range(6,10).has(data.code) \
		else 3 if range(10,14).has(data.code) \
		else 0
	
	%TabsContainer.select(shown_tab_index, true)
	
	if data.code == -1:
		var node = %"C0-1"
		node.set_pressed(true)
		node.toggled.emit(true)
		return
	
	var node_name = "%" + "C%s-1" % str(data.code - 1)
	var node = get_node(node_name) if data.code > 0 else %"C0-1"
	node.set_pressed(true)
	node.toggled.emit(true)
	
	# Set Selection
	if [6, 7, 8, 9, 10, 11].has(data.code):
		node_name = "%" + "C%s-2" % str(data.code - 1)
		node = get_node(node_name)
		if node.get_item_count() > data.data_id:
			node.select(data.data_id)
		else:
			node.select(-1)
		#elif node.get_item_count() > 0:
			#node.select(0)

	# Set value
	if [1, 2].has(data.code):
		node_name = "%" + "C%s-2" % str(data.code - 1)
		node = get_node(node_name)
		node.set_value(data.value1)
		node_name = "%" + "C%s-3" % str(data.code - 1)
		node = get_node(node_name)
		node.set_value(data.value2)
	elif [3].has(data.code):
		node_name = "%" + "C%s-2" % str(data.code - 1)
		node = get_node(node_name)
		node.set_value(data.value1)
	elif [3].has(data.code):
		node_name = "%" + "C%s-2" % str(data.code - 1)
		node = get_node(node_name)
		node.set_value(data.value1)
	elif [4, 5, 6, 7, 11].has(data.code):
		node_name = "%" + "C%s-3" % str(data.code - 1)
		node = get_node(node_name)
		node.set_value(data.value2)
	
	# set other selection
	if [4, 5, 12, 13].has(data.code):
		node_name = "%" + "C%s-2" % str(data.code - 1)
		node = get_node(node_name)
		var current_data
		if [4, 5].has(data.code):
			current_data = database.states
		elif [12].has(data.code):
			current_data = database.skills
		elif [13].has(data.code):
			current_data = database.common_events
		
		data_id_cache[data.code - 1] = data.data_id
		
		if current_data.size() > data.data_id:
			node.set_text(str(data.data_id).pad_zeros(str(current_data.size()).length()) + ": " + current_data[data.data_id].name)
		elif current_data.size() > 1:
			node.set_text(str(1).pad_zeros(str(current_data.size()).length()) + ": " + current_data[1].name)


func fill_all() -> void:
	fill_other()


func fill_other() -> void:
	var node_name
	var node
	var current_data
	
	if database:
		current_data = database.states
		for i in [3, 4]:
			node_name = "%" + "C%s-2" % str(i)
			node = get_node(node_name)
			if current_data.size() > 1:
				node.set_text(str(1).pad_zeros(str(current_data.size()).length()) + ": " + current_data[1].name)
			else:
				node.set_text("")
		
		current_data = database.skills
		for i in [11]:
			node_name = "%" + "C%s-2" % str(i)
			node = get_node(node_name)
			if current_data.size() > 1:
				node.set_text(str(1).pad_zeros(str(current_data.size()).length()) + ": " + current_data[1].name)
			else:
				node.set_text("")
		
		current_data = database.common_events
		for i in [12]:
			node_name = "%" + "C%s-2" % str(i)
			node = get_node(node_name)
			if current_data.size() > 1:
				node.set_text(str(1).pad_zeros(str(current_data.size()).length()) + ": " + current_data[1].name)
			else:
				node.set_text("")
	else:
		for i in [3, 4, 11, 12]:
			node_name = "%" + "C%s-2" % str(i)
			node = get_node(node_name)
			node.set_text("")


func _on_tabs_container_tab_changed(index: int) -> void:
	var targets = [%Recover, %State, %ParameterBuff, %Other]
	if last_tab_index != -1:
		targets[last_tab_index].set_visible(false)
	targets[index].set_visible(true)
	last_tab_index = index
	size.y = 0
	need_fix_size_timer = 0.04


func _open_select_any_data_dialog(current_data, id_selected: int, title: String, target: int) -> void:
	var path = "res://addons/CustomControls/Dialogs/select_any_data_dialog.tscn"
	var parent = self
	var dialog
	if select_any_data_dialog:
		dialog = select_any_data_dialog
		RPGDialogFunctions.show_dialog(dialog, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	else:
		dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
		dialog.database = database
	
	dialog.selected.connect(_on_any_data_selected, CONNECT_ONE_SHOT)
	
	dialog.setup(current_data, id_selected, title, target)


func _on_any_data_selected(id: int, target: Variant) -> void:
	if !database: return
	
	data_id_cache[target] = id
	
	var node = get_node_or_null("%" + "C%s-2" % str(target))
	if node:
		var current_data
		if [3, 4].has(target):
			current_data = database.states
		elif [11].has(target):
			current_data = database.skills
		elif [12].has(target):
			current_data = database.common_events
		if current_data:
			node.set_text(str(id).pad_zeros(str(current_data.size()).length()) + ": " + current_data[id].name)


func _on_visibility_changed() -> void:
	if visible:
		fill_all()
		size.y = 0


func _on_ok_button_pressed() -> void:
	var focus_owner = get_viewport().gui_get_focus_owner()
	if focus_owner is LineEdit and focus_owner.get_parent() is SpinBox:
		focus_owner.get_parent().apply()
		
	var button_pressed = %"C0-1".get_button_group().get_pressed_button()
	
	#var node1 = get_node_or_null("%" + "C%s-1" % str(data.code - 1))
	var node2 = get_node_or_null("%" + "C%s-2" % str(data.code - 1))
	var node3 = get_node_or_null("%" + "C%s-3" % str(data.code - 1))
	
	if node2:
		if node2 is OptionButton:
			data.data_id = node2.get_selected_id()
		elif node2 is SpinBox:
			data.value1 = node2.get_value()
		elif node2 is Button:
			data.data_id = data_id_cache[data.code - 1]
	if node3:
		if node3 is SpinBox:
			data.value2 = node3.get_value()

	target_callable.call(data, target)
	default_data = data.clone(true)
	hide()


func _on_cancel_button_pressed() -> void:
	hide()


func _on_c_32_button_up() -> void:
	if !database: return
	_open_select_any_data_dialog(database.states, data_id_cache[3], "States", 3)


func _on_c_42_pressed() -> void:
	if !database: return
	_open_select_any_data_dialog(database.states, data_id_cache[4], "States", 4)


func _on_c_112_pressed() -> void:
	if !database: return
	_open_select_any_data_dialog(database.skills, data_id_cache[11], "Skills", 11)


func _on_c_122_pressed() -> void:
	if !database: return
	_open_select_any_data_dialog(database.common_events, data_id_cache[12], "Global Events", 12)


func _on_filter_text_changed(new_text: String) -> void:
	if new_text.length() != 0:
		%Filter.right_icon = ResourceLoader.load("res://addons/CustomControls/Images/filter_reset.png")
	else:
		%Filter.right_icon = ResourceLoader.load("res://addons/CustomControls/Images/magnifying_glass.png")
	filter_update_timer = 0.25


func _on_filter_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.is_pressed():
			if event.button_index == MOUSE_BUTTON_LEFT:
				if %Filter.text.length() > 0:
					if event.position.x >= %Filter.size.x - 22:
						%Filter.text = ""
						_on_filter_text_changed("")
	elif event is InputEventMouseMotion:
		if event.position.x >= %Filter.size.x - 22:
			%Filter.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		else:
			%Filter.mouse_default_cursor_shape = Control.CURSOR_IBEAM


func _on_flow_container_item_rect_changed() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	call_deferred("_update_window_size_by_filter_container")
