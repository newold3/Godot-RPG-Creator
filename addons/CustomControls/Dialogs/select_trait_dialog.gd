@tool
extends Window


var last_tab_index = -1
var data: RPGTrait
var target: int
var database: RPGDATA : set = _set_database
var target_callable: Callable
var need_fix_size_timer: float = 0.0

var selected_id_mode: bool = false

var default_data = RPGTrait.new()

var select_any_data_dialog

var filter_update_timer: float = 0.0
var filter_nodes: Array = []
var last_filter_used: String

var data_id_cache = {
	2: 1,
	3: 1,
	4: 1,
	8: 1,
	11: 1,
	14: 1,
	15: 1,
	27: 1
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


func _set_database(_database: RPGDATA) -> void:
	database = _database
	fill_user_parameters()


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
			#await get_tree().create_timer(0.35).timeout
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
	#var container = %FlowContainer
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


func _get_node_parent(node: Node) -> void:
	if node is CheckBox:
		return node.get_parent()


func set_inital_panels_visibility() -> void:
	var targets = [%Combat, %Statistics, %Equipment, %Abilities]
	for target in targets:
		target.visible = false


func set_data(_data: RPGTrait, _target: int) -> void:
	if _data:
		data = _data.clone(true)
	else:
		data = default_data.clone(true)
	
	set_tab_and_selected_data()
	
	target = _target


func add_tabs() -> void:
	var tab_container = %TabsContainer
	tab_container.clear()
	var tabs = ["Combat", "Statistics", "Equipment", "Abilities"]
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
		
	if !selected_id_mode:
		node.get_parent().propagate_call("set_disabled", [!value])
		var value_extra = ["C0-1", "C1-1", "C2-1", "C4-1", "C5-1", "C100-1", "C6-1", "C8-1", "C25-1", "C26-1"].has(node.name)
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
			 1 if data.code in [4, 101, 5, 6] \
		else 2 if data.code in [16, 17, 18, 19, 20] \
		else 3 if data.code in [12, 13, 14, 15, 25, 22, 23, 24] \
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
	if [1, 2, 5, 101, 6, 7, 8, 13, 14, 17, 18, 19, 20, 21, 23, 24, 25, 26, 27].has(data.code):
		node_name = "%" + "C%s-2" % str(data.code - 1)
		node = get_node(node_name)
		if node.get_item_count() > data.data_id:
			node.select(data.data_id)
		else:
			node.select(-1)
		#elif node.get_item_count() > 0:
			#node.select(0)

	# Set value
	if [1, 2, 3, 5, 101, 6, 7, 9, 26, 27].has(data.code):
		node_name = "%" + "C%s-3" % str(data.code - 1)
		node = get_node(node_name)
		node.set_value(data.value)
	elif [10, 11, 22].has(data.code):
		node_name = "%" + "C%s-2" % str(data.code - 1)
		node = get_node(node_name)
		node.set_value(data.value)
	
	# set other selection
	if [3, 4, 9, 12, 15, 16, 28].has(data.code):
		node_name = "%" + "C%s-2" % str(data.code - 1)
		node = get_node(node_name)
		var current_data
		if [3, 4, 9, 28].has(data.code):
			current_data = database.states
		elif [12, 15, 16]:
			current_data = database.skills
		
		data_id_cache[data.code - 1] = data.data_id
		
		if current_data.size() > data.data_id:
			node.set_text(str(data.data_id).pad_zeros(str(current_data.size()).length()) + ": " + current_data[data.data_id].name)
		elif current_data.size() > 1:
			node.set_text(str(1).pad_zeros(str(current_data.size()).length()) + ": " + current_data[1].name)
			

func fill_all() -> void:
	fill_elements_types()
	fill_skill_types()
	fill_weapon_types()
	fill_armor_types()
	fill_equipment_types()
	fill_other()


func fill_user_parameters() -> void:
	var node = %"C100-2"
	node.clear()
	
	if database:
		for param in database.types.user_parameters:
			node.add_item("User Parameter " + param.name)
	
	if node.get_item_count() == 0:
		node.add_item("No User Parameter Added")


func fill_elements_types() -> void:
	var node1 = %"C0-2"
	var node2 = %"C7-2"
	var node3 = %"C26-2"
	node1.clear()
	node2.clear()
	node3.clear()
	if database:
		var elements = database.types.element_types
		for element in elements:
			node1.add_item(element)
			node2.add_item(element)
			node3.add_item(element)


func fill_skill_types() -> void:
	var node1 = %"C12-2"
	var node2 = %"C13-2"
	node1.clear()
	node2.clear()
	if database:
		var skills = database.types.skill_types
		for skill in skills:
			node1.add_item(skill)
			node2.add_item(skill)


func fill_equipment_types() -> void:
	var node1 = %"C18-2"
	var node2 = %"C19-2"
	node1.clear()
	node2.clear()
	if database:
		var equipment = database.types.equipment_types
		for equip in equipment:
			node1.add_item(equip)
			node2.add_item(equip)


func fill_weapon_types() -> void:
	var node = %"C16-2"
	node.clear()
	if database:
		var weapons = database.types.weapon_types
		node.add_item("Add All Weapon Types")
		for weapon in weapons:
			node.add_item(weapon)


func fill_armor_types() -> void:
	var node = %"C17-2"
	node.clear()
	if database:
		var armors = database.types.armor_types
		node.add_item("Add All Armor Types")
		for armor in armors:
			node.add_item(armor)


func fill_other() -> void:
	var node_name
	var node
	var current_data
	
	if database:
		current_data = database.states
		for i in [2, 3, 8, 27]:
			node_name = "%" + "C%s-2" % str(i)
			node = get_node(node_name)
			if current_data.size() > 1:
				node.set_text(str(1).pad_zeros(str(current_data.size()).length()) + ": " + current_data[1].name)
			else:
				node.set_text("")
		
		current_data = database.skills
		for i in [11, 14, 15]:
			node_name = "%" + "C%s-2" % str(i)
			node = get_node(node_name)
			if current_data.size() > 1:
				node.set_text(str(1).pad_zeros(str(current_data.size()).length()) + ": " + current_data[1].name)
			else:
				node.set_text("")
	else:
		for i in [2, 3, 8, 11, 14, 15, 27]:
			node_name = "%" + "C%s-2" % str(i)
			node = get_node(node_name)
			node.set_text("")


func _on_tabs_container_tab_changed(index: int) -> void:
	var targets = [%Combat, %Statistics, %Equipment, %Abilities]
	if last_tab_index != -1:
		targets[last_tab_index].set_visible(false)
	targets[index].set_visible(true)
	last_tab_index = index
	size.y = 0
	
	#wrap_controls = true
	#await get_tree().create_timer(0.35).timeout
	#wrap_controls = false


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
		if [2, 3, 8, 27].has(target):
			current_data = database.states
		elif [11, 14, 15].has(target):
			current_data = database.skills
		if current_data:
			node.set_text(str(id).pad_zeros(str(current_data.size()).length()) + ": " + current_data[id].name)


func _on_visibility_changed() -> void:
	%TargetContainer.visible = true
	%FilterContainer.visible = false
	%TabsContainer.get_parent().visible = true
	
	if visible:
		fill_all()
		size.y = 0
		#wrap_controls = true
		#await get_tree().create_timer(0.35).timeout
		#wrap_controls = false
		var filter = %Filter.text.to_lower()
		if not filter.is_empty():
			var nodes = _get_filter_controls(%TargetContainer, filter)
			if not nodes.is_empty():
				_filter_controls(nodes)
	else:
		if %Filter.text.length() > 0:
			_restore_node_parents()


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
			data.value = node2.get_value()
		elif node2 is Button:
			data.data_id = data_id_cache[data.code - 1]
	
	if node3:
		if node3 is SpinBox:
			data.value = node3.get_value()
	
	target_callable.call(data, target)
	default_data = data.clone(true)
	hide()


func _on_cancel_button_pressed() -> void:
	hide()


func _on_c_22_pressed() -> void:
	if !database: return
	_open_select_any_data_dialog(database.states, data_id_cache[2], "States", 2)


func _on_c_32_pressed() -> void:
	if !database: return
	_open_select_any_data_dialog(database.states, data_id_cache[3], "States", 3)


func _on_c_82_pressed() -> void:
	if !database: return
	_open_select_any_data_dialog(database.states, data_id_cache[8], "States", 8)


func _on_c_282_pressed() -> void:
	if !database: return
	_open_select_any_data_dialog(database.states, data_id_cache[27], "States", 27)


func _on_c_112_pressed() -> void:
	if !database: return
	_open_select_any_data_dialog(database.skills, data_id_cache[11], "Skills", 11)


func _on_c_142_pressed() -> void:
	if !database: return
	_open_select_any_data_dialog(database.skills, data_id_cache[14], "Skills", 14)


func _on_c_152_pressed() -> void:
	if !database: return
	_open_select_any_data_dialog(database.skills, data_id_cache[15], "Skills", 15)


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


func _on_filter_container_item_rect_changed() -> void:
	pass # Replace with function body.


func _on_flow_container_item_rect_changed() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	call_deferred("_update_window_size_by_filter_container")
