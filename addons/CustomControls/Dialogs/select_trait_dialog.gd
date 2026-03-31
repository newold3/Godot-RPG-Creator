@tool
extends Window

## Style for collapsed sections
@export var section_collapse_style: StyleBox

## Style for expanded sections
@export var section_expanded_style: StyleBox

## To auto-fill the tags in the traits checkboxes based on a JSON dictionary
@export var auto_fill_tags: bool = false :
	set(value):
		if value:
			_apply_automatic_tags()

var data: RPGTrait
var target: int
var database: RPGDATA : set = _set_database
var target_callable: Callable

var default_data = RPGTrait.new()

var select_any_data_dialog

var filter_update_timer: float = 0.0
var last_filter_used: String

var _collapse_buttons_map: Dictionary = {}

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

var favorite_buttons_need_refresh: bool = false
var show_favorites_only: bool = false
var current_button_hovered: Control
var selected_id_mode: bool = false

const FAVORITE_BUTTON = preload("uid://dsmo7ri8d6djp")



## Initializes the dialog and sets up the new collapsible sections
func _ready() -> void:
	if not "category_states" in FileCache.options:
		FileCache.options["category_states"] = {}
	
	show_favorites_only = FileCache.options.get("traits_show_favorites_only", false)
	
	if has_node("%FavoritesOnlyButton"):
		%FavoritesOnlyButton.set_pressed_no_signal(show_favorites_only)
		if not %FavoritesOnlyButton.toggled.is_connected(_on_favorites_only_button_toggled):
			%FavoritesOnlyButton.toggled.connect(_on_favorites_only_button_toggled)
		%FavoritesOnlyButton.modulate.a = 0.6 if not show_favorites_only else 1.0
		
	_setup_collapse_buttons()
	close_requested.connect(hide)
	visibility_changed.connect(_on_visibility_changed)
	
	if has_node("%FilterSmoothContainer"):
		%FilterSmoothContainer.get_v_scroll_bar().changed.connect(_update_window_size_by_filter_container)
		
	_set_disabled(true)
		
	_setup_checkboxes_and_favorites()
	
	%OKButton.set_disabled(false)
	%CancelButton.set_disabled(false)
	%"C0-1".set_pressed(true)
	%"C0-1".toggled.emit(true)
	fill_all()


## Sets up button groups, connections, and favorite buttons in a single native pass
func _setup_checkboxes_and_favorites() -> void:
	var all_checkboxes = find_children("*", "CheckBox", true, false)
	var btn_group = ButtonGroup.new()
	var favorite_traits = FileCache.options.get("current_favorite_traits", [])
	
	for node in all_checkboxes:
		node.set_button_group(btn_group)
		if not node.toggled.is_connected(_on_toggled):
			node.toggled.connect(_on_toggled.bind(node))
		node.set_disabled(false)
		node.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		
		if node.name.begins_with("C") and node.get_child_count() == 0:
			var b = FAVORITE_BUTTON.instantiate()
			node.get_parent().add_child(b)
			b.position = Vector2(-b.size.x - 4, node.size.y / 2 - b.size.y / 2)
			b.toggled.connect(_on_favorite_button_toggled.bind(node.name))
			
			if node.name in favorite_traits:
				b.set_pressed_no_signal(true)
				
			node.set_meta("favorite_button", b)

## Applies the search tags to the checkboxes based on a JSON dictionary
func _apply_automatic_tags() -> void:
	var dict_path = "res://addons/CustomControls/Dialogs/traits_tags.tags"
	var tags_dict = JSON.parse_string(FileAccess.get_file_as_string(dict_path))
	var checkboxes = _get_trait_checkboxes(self)
	for cb in checkboxes:
		var matched: bool = false
		var cb_text_lower = cb.text.to_lower()
		
		for key in tags_dict.keys():
			if key.to_lower() in cb_text_lower:
				cb.set_meta("custom_search_tags", tags_dict[key])
				print([key, tags_dict[key]])
				matched = true
				break
				
		if not matched:
			cb.set_meta("custom_search_tags", "rasgo, trait")
			
	print("All tags assigned successfully! Please save the scene (Ctrl + S).")



## Sets the database and updates user parameters
func _set_database(_database: RPGDATA) -> void:
	database = _database



## Disables or enables necessary UI elements globally
func _set_disabled(value: bool) -> void:
	propagate_call("set_disabled", [value])
	var nodes = get_tree().get_nodes_in_group("collapse_button")
	nodes.append_array(get_tree().get_nodes_in_group("favorite_button"))
	nodes.append_array([%Filter, %ToggleAllButton, %FavoritesOnlyButton])
	for node in nodes:
		node.set_disabled(false)



## Handles the main favorite toggle logic
func _on_favorites_only_button_toggled(toggled_on: bool) -> void:
	show_favorites_only = toggled_on
	FileCache.options.traits_show_favorites_only = show_favorites_only
	filter_update_timer = 0.01
	%FavoritesOnlyButton.modulate.a = 0.6 if not toggled_on else 1.0



## Processes the filter timer updates
func _process(delta: float) -> void:
	if filter_update_timer > 0.0:
		filter_update_timer -= delta
		if filter_update_timer <= 0:
			filter_update_timer = 0.0
			_update_filter()



## Prepares the collapse buttons and restores their saved states
func _setup_collapse_buttons() -> void:
	var nodes = get_tree().get_nodes_in_group("collapse_button")
	
	for btn in nodes:
		if is_ancestor_of(btn):
			var category_label = btn.get_parent()
			if category_label is Label:
				var category_id = "trait_" + category_label.text
				_collapse_buttons_map[btn] = category_id
				
				if not btn.toggled.is_connected(_on_collapse_button_user_toggled):
					btn.toggled.connect(_on_collapse_button_user_toggled.bind(category_id, btn))
				
				var is_collapsed = FileCache.options.category_states.get(category_id, false)
				btn.set_pressed_no_signal(is_collapsed)
				_set_category_visual_state(btn, is_collapsed)


## Updates the visual state of a category based on user data
func _set_category_visual_state(btn: Button, is_collapsed: bool) -> void:
	btn.text = "►" if is_collapsed else "▼"
	
	if btn.target:
		btn.target.visible = !is_collapsed

	var label = btn.get_parent()
	
	if label is Label:
		if is_collapsed:
			if section_collapse_style:
				label.add_theme_stylebox_override("normal", section_collapse_style)
			label.set("theme_override_colors/font_color", Color("8691a6ff"))
		elif section_expanded_style:
			label.add_theme_stylebox_override("normal", section_expanded_style)
			label.set("theme_override_colors/font_color", Color("#cedeff"))
	
	if has_node("%ToggleAllButton"):
		if is_action_for_toggle_all_collapse():
			%ToggleAllButton.icon = get_theme_icon("Collapse", "EditorIcons")
		else:
			%ToggleAllButton.icon = get_theme_icon("GuiTreeArrowRight", "EditorIcons")



## Determines if the toggle all button should collapse or expand
func is_action_for_toggle_all_collapse() -> bool:
	var should_collapse_all = false
	
	for btn in _collapse_buttons_map:
		if not btn.button_pressed: 
			should_collapse_all = true
			break
	
	return should_collapse_all



## Handles the user toggling a collapse button directly
func _on_collapse_button_user_toggled(toggled_on: bool, category_id: String, btn: Button) -> void:
	FileCache.options.category_states[category_id] = toggled_on
	_set_category_visual_state(btn, toggled_on)



## Handles the toggle all button action
func _on_toggle_all_button_pressed() -> void:
	var should_collapse_all = false
	
	for btn in _collapse_buttons_map:
		if not btn.button_pressed: 
			should_collapse_all = true
			break

	for btn in _collapse_buttons_map:
		if btn.button_pressed != should_collapse_all:
			btn.set_pressed_no_signal(should_collapse_all)
			var category_id = _collapse_buttons_map[btn]
			_on_collapse_button_user_toggled(should_collapse_all, category_id, btn)
	
	if has_node("%ToggleAllButton"):
		if should_collapse_all:
			%ToggleAllButton.icon = get_theme_icon("GuiTreeArrowRight", "EditorIcons")
		else:
			%ToggleAllButton.icon = get_theme_icon("Collapse", "EditorIcons")



## Saves or removes a favorited trait
func _on_favorite_button_toggled(toggled_on: bool, trait_name: String) -> void:
	if not "current_favorite_traits" in FileCache.options:
		FileCache.options.current_favorite_traits = []
		
	if toggled_on and not trait_name in FileCache.options.current_favorite_traits:
		FileCache.options.current_favorite_traits.append(trait_name)
		favorite_buttons_need_refresh = true
	elif !toggled_on and trait_name in FileCache.options.current_favorite_traits:
		FileCache.options.current_favorite_traits.erase(trait_name)
		favorite_buttons_need_refresh = true
		
	if show_favorites_only:
		_update_filter()



## Updates the visibility of trait rows based on the filter text
func _update_filter() -> void:
	var filter = %Filter.text.to_lower()
	last_filter_used = filter
	var is_filtering = filter.length() > 0 or show_favorites_only
	var checkboxes = _get_trait_checkboxes(self)
	var rows_by_btn: Dictionary = {}
	var cb_by_row: Dictionary = {}
	
	for cb in checkboxes:
		var row = cb.get("main_container") if "main_container" in cb and cb.get("main_container") != null else cb.get_parent()
		var collapse_btn = _find_collapse_button_in_category(row)
		
		if not collapse_btn in rows_by_btn:
			rows_by_btn[collapse_btn] = []
			
		if not row in rows_by_btn[collapse_btn]:
			rows_by_btn[collapse_btn].append(row)
			cb_by_row[row] = cb
			
	for collapse_btn in rows_by_btn:
		var visible_count = 0
		var rows = rows_by_btn[collapse_btn]
		
		for row in rows:
			var cb = cb_by_row[row]
			var is_visible = true
			
			if show_favorites_only:
				var current_favs = FileCache.options.get("current_favorite_traits", [])
				if not cb.name in current_favs:
					is_visible = false
					
			if is_visible and filter.length() > 0:
				is_visible = _check_filter_match(row, filter)
			
			row.visible = is_visible
			
			var value_extra = ["C0-1", "C1-1", "C2-1", "C4-1", "C5-1", "C100-1", "C6-1", "C8-1", "C25-1", "C26-1"].has(cb.name)
			
			if value_extra:
				var other_node = row.get_parent().get_child(row.get_index() + 1)
				if other_node:
					other_node.visible = is_visible
			
			if is_visible:
				visible_count += 1
		
		if collapse_btn:
			var category_root = collapse_btn.get_parent().get_parent()
			
			if is_filtering:
				category_root.visible = (visible_count > 0)
				if visible_count > 0 and collapse_btn.button_pressed:
					collapse_btn.set_pressed_no_signal(false)
					_set_category_visual_state(collapse_btn, false)
			else:
				category_root.visible = true
				var category_id = _collapse_buttons_map.get(collapse_btn, "")
				var saved_state = FileCache.options.category_states.get(category_id, false)
				if collapse_btn.button_pressed != saved_state:
					collapse_btn.set_pressed_no_signal(saved_state)
					_set_category_visual_state(collapse_btn, saved_state)
				
	if has_node("%FilterSmoothContainer"):
		_update_window_size_by_filter_container()



## Recursively finds all checkboxes that represent a trait row
func _get_trait_checkboxes(node: Node) -> Array:
	var result = []
	var all_checkboxes = node.find_children("*", "CheckBox", true, false)
	
	for cb in all_checkboxes:
		if cb.name.begins_with("C"):
			result.append(cb)
			
	return result



## Checks if a row or its children match the filter text
func _check_filter_match(node: Node, filter: String) -> bool:
	if "text" in node and typeof(node.get("text")) == TYPE_STRING and node.get("text").to_lower().find(filter) != -1:
		return true
		
	if node.has_meta("custom_search_tags"):
		if str(node.get_meta("custom_search_tags")).to_lower().find(filter) != -1:
			return true
			
	if node is OptionButton:
		for i in node.get_item_count():
			if node.get_item_text(i).to_lower().find(filter) != -1:
				return true
				
	for child in node.get_children():
		if _check_filter_match(child, filter):
			return true
			
	return false



## Finds the collapse button traversing up to parents and then down to children
func _find_collapse_button_in_category(start_node: Node) -> Button:
	var current = start_node
	
	while current and current != self:
		var parent = current.get_parent()
		if not parent:
			break
			
		var btn = _search_button_recursive(parent, current)
		if btn:
			return btn
			
		current = parent
		
	return null



## Helper to search the collapse button recursively in children branches
func _search_button_recursive(node: Node, exclude_node: Node) -> Button:
	if node is Button and node.is_in_group("collapse_button"):
		return node
		
	for child in node.get_children():
		if child == exclude_node:
			continue
			
		var found = _search_button_recursive(child, null)
		if found:
			return found
			
	return null



## Updates the window height when filtering changes the scroll container size
func _update_window_size_by_filter_container() -> void:
	var vbar = %FilterSmoothContainer.get_v_scroll_bar()
	var max_h = 600
	size.y = max(min_size.y, min((vbar.max_value - vbar.min_value) + vbar.page, max_h))



## Sets the initial data and target for the dialog
func set_data(_data: RPGTrait, _target: int) -> void:
	if _data:
		data = _data.clone(true)
	else:
		data = default_data.clone(true)
	
	set_selected_data()
	target = _target


## Handles a checkbox toggle to enable or disable associated controls
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
		var base_name = str(node.name).get_slice("-", 0)
		var current_code = base_name.replace("C", "")
		data.code = int(current_code) + 1



## Configures the UI elements to reflect the currently selected data
func set_selected_data() -> void:
	if !data:
		return

	if data.code == -1:
		var node = %"C0-1"
		node.set_pressed(true)
		node.toggled.emit(true)
		return
	
	var node_name = "%" + "C%s-1" % str(data.code - 1)
	var node = get_node(node_name) if data.code > 0 else %"C0-1"
	node.set_pressed(true)
	node.toggled.emit(true)
	
	if [1, 2, 5, 101, 6, 7, 8, 13, 14, 17, 18, 19, 20, 21, 23, 24, 25, 26, 27].has(data.code):
		node_name = "%" + "C%s-2" % str(data.code - 1)
		node = get_node(node_name)
		if node.get_item_count() > data.data_id:
			node.select(data.data_id)
		else:
			node.select(-1)

	if [1, 2, 3, 5, 101, 6, 7, 9, 26, 27].has(data.code):
		node_name = "%" + "C%s-3" % str(data.code - 1)
		node = get_node(node_name)
		node.set_value(data.value)
	elif [10, 11, 22].has(data.code):
		node_name = "%" + "C%s-2" % str(data.code - 1)
		node = get_node(node_name)
		node.set_value(data.value)
	
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



## Refreshes all fill data operations
func fill_all() -> void:
	_fill_parameters()
	fill_elements_types()
	fill_skill_types()
	fill_weapon_types()
	fill_armor_types()
	fill_equipment_types()
	fill_other()



func _fill_parameters() -> void:
	var nodes = [%"C1-2", %"C4-2"]
	
	for node in nodes: node.clear()
	
	var items = RPGActor.get_parameter_list(false)
	var headers = [tr("Base Parameters"), tr("Extra Parameters"), tr("Special Parameters"), tr("User Parameters")]
	var header_index = 0
	
	for item in items:
		if not item.is_empty():
			for node in nodes: node.add_item(item)
		else:
			var header = headers[header_index] if headers.size() > header_index else ""
			for node in nodes: node.add_separator(header)
			header_index += 1



## Populates elements types
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



## Populates skill types
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



## Populates equipment types
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



## Populates weapon types
func fill_weapon_types() -> void:
	var node = %"C16-2"
	node.clear()
	if database:
		var weapons = database.types.weapon_types
		node.add_item("Add All Weapon Types")
		for weapon in weapons:
			node.add_item(weapon)



## Populates armor types
func fill_armor_types() -> void:
	var node = %"C17-2"
	node.clear()
	if database:
		var armors = database.types.armor_types
		node.add_item("Add All Armor Types")
		for armor in armors:
			node.add_item(armor)



## Populates database dynamic lists
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



## Opens a sub dialog to select database specific data
func _open_select_any_data_dialog(current_data, id_selected: int, title: String, target_id: int) -> void:
	var path = "res://addons/CustomControls/Dialogs/select_any_data_dialog.tscn"
	var dialog
	
	if select_any_data_dialog:
		dialog = select_any_data_dialog
		RPGDialogFunctions.show_dialog(dialog, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	else:
		dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
		dialog.database = database
	
	dialog.selected.connect(_on_any_data_selected, CONNECT_ONE_SHOT)
	dialog.setup(current_data, id_selected, title, target_id)



## Processes the selected data from the sub dialog
func _on_any_data_selected(id: int, dialog_target: Variant) -> void:
	if !database: return
	
	data_id_cache[dialog_target] = id
	var node = get_node_or_null("%" + "C%s-2" % str(dialog_target))
	
	if node:
		var current_data
		if [2, 3, 8, 27].has(dialog_target):
			current_data = database.states
		elif [11, 14, 15].has(dialog_target):
			current_data = database.skills
		if current_data:
			node.set_text(str(id).pad_zeros(str(current_data.size()).length()) + ": " + current_data[id].name)



## Refreshes the dialog contents when it becomes visible
func _on_visibility_changed() -> void:
	if visible:
		fill_all()
		size.y = 0



## Saves the data, runs the callback, and hides the dialog
func _on_ok_button_pressed() -> void:
	var focus_owner = get_viewport().gui_get_focus_owner()
	
	if focus_owner is LineEdit and focus_owner.get_parent() is SpinBox:
		focus_owner.get_parent().apply()
		
	var button_pressed = %"C0-1".get_button_group().get_pressed_button()
	var node2 = get_node_or_null("%" + "C%s-2" % str(data.code - 1))
	var node3 = get_node_or_null("%" + "C%s-3" % str(data.code - 1))
	
	data.data_id = 0
	data.value = 0.0
	
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



## Closes the dialog without saving
func _on_cancel_button_pressed() -> void:
	hide()



## Opens state selection
func _on_c_22_pressed() -> void:
	if !database: return
	_open_select_any_data_dialog(database.states, data_id_cache[2], "States", 2)



## Opens state selection
func _on_c_32_pressed() -> void:
	if !database: return
	_open_select_any_data_dialog(database.states, data_id_cache[3], "States", 3)



## Opens state selection
func _on_c_82_pressed() -> void:
	if !database: return
	_open_select_any_data_dialog(database.states, data_id_cache[8], "States", 8)



## Opens state selection
func _on_c_282_pressed() -> void:
	if !database: return
	_open_select_any_data_dialog(database.states, data_id_cache[27], "States", 27)



## Opens skill selection
func _on_c_112_pressed() -> void:
	if !database: return
	_open_select_any_data_dialog(database.skills, data_id_cache[11], "Skills", 11)



## Opens skill selection
func _on_c_142_pressed() -> void:
	if !database: return
	_open_select_any_data_dialog(database.skills, data_id_cache[14], "Skills", 14)



## Opens skill selection
func _on_c_152_pressed() -> void:
	if !database: return
	_open_select_any_data_dialog(database.skills, data_id_cache[15], "Skills", 15)



## Resets the filter timer and updates search icon
func _on_filter_text_changed(new_text: String) -> void:
	if new_text.length() != 0:
		%Filter.right_icon = ResourceLoader.load("res://addons/CustomControls/Images/filter_reset.png")
	else:
		%Filter.right_icon = ResourceLoader.load("res://addons/CustomControls/Images/magnifying_glass.png")
	filter_update_timer = 0.25



## Clears the filter text if the reset icon is clicked
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
