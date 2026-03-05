@tool
extends Window

## Rename all the buttons so that their IDs are consecutive without any gaps.
@export var set_button_names: bool = false :
	set(value):
		if value:
			pass

## To add a new button, activate this variable in the inspector
@export var get_available_button_name: bool = false :
	set(value):
		if value:
			print("Available Button Name: " + _get_button_name_available(self, [])[0])
			print("Available Codes: " + _get_available_codes())

@export var auto_fill_tags: bool = false :
	set(value):
		if value:
			_apply_automatic_tags()


@export var section_collapse_style: StyleBox
@export var section_expanded_style: StyleBox

var battle_buttons_is_enabled: bool = false
var filter_update_timer: float = 0.0

var favorite_buttons_need_refresh: bool = false
var show_favorites_only: bool = false

var current_button_hovered: CustomSimpleButton

const FAVORITE_BUTTON = preload("uid://dsmo7ri8d6djp")

static var _last_filter_used: String

var _collapse_buttons_map: Dictionary = {}

signal request_command_created(command_code: int, from_dialog: Window)
signal request_update_favorite_buttons()


func _ready() -> void:
	show_favorites_only = FileCache.options.get("show_favorites_only", false)
	
	if has_node("%FavoritesOnlyButton"):
		%FavoritesOnlyButton.set_pressed_no_signal(show_favorites_only)
		if not %FavoritesOnlyButton.toggled.is_connected(_on_favorites_only_button_toggled):
			%FavoritesOnlyButton.toggled.connect(_on_favorites_only_button_toggled)
		%FavoritesOnlyButton.modulate.a = 0.6 if not show_favorites_only else 1.0

	visibility_changed.connect(
		func():
			if visible:
				for i in 6:
					await get_tree().process_frame
					grab_focus()
					
				var favorite_commands = FileCache.options.get("current_favorite_commands", [])
				var buttons = get_buttons()
				for b in buttons:
					var button_id = int(b.name)
					var favorite_button =  b.get_meta("favorite_button")
					favorite_button.set_pressed_no_signal(button_id in favorite_commands)
			else:
				if favorite_buttons_need_refresh:
					favorite_buttons_need_refresh = false
					request_update_favorite_buttons.emit()
	)
	
	_connect_all_buttons(self)
	_setup_collapse_buttons()
	
	close_requested.connect(hide)
	enable_battle_buttons(battle_buttons_is_enabled, false)
	
	if not _last_filter_used.is_empty() or show_favorites_only:
		if not _last_filter_used.is_empty():
			%Filter.text = _last_filter_used
			_on_filter_text_changed(_last_filter_used)
		
		if _last_filter_used.is_empty() and show_favorites_only:
			filter_update_timer = 0.01
		else:
			filter_update_timer = 0.01


func _setup_collapse_buttons() -> void:
	if not "category_states" in FileCache.options:
		FileCache.options["category_states"] = {}
	
	var nodes = get_tree().get_nodes_in_group("collapse_button")
	
	for btn in nodes:
		if is_ancestor_of(btn):
			var category_label = btn.get_parent()
			if category_label is Label:
				var category_id = category_label.text
				_collapse_buttons_map[btn] = category_id
				
				if not btn.toggled.is_connected(_on_collapse_button_user_toggled):
					btn.toggled.connect(_on_collapse_button_user_toggled.bind(category_id, btn))
				
				var is_collapsed = FileCache.options.category_states.get(category_id, false)
				btn.set_pressed_no_signal(is_collapsed)
				
				_set_category_visual_state(btn, is_collapsed)


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
	
	if is_action_for_toggle_all_collapse():
		%ToggleAllButton.icon = get_theme_icon("Collapse", "EditorIcons")
	else:
		%ToggleAllButton.icon = get_theme_icon("GuiTreeArrowRight", "EditorIcons") 


func is_action_for_toggle_all_collapse() -> bool:
	var should_collapse_all = false
	
	for btn in _collapse_buttons_map:
		if not btn.button_pressed: 
			should_collapse_all = true
			break
	
	return should_collapse_all


func _on_collapse_button_user_toggled(toggled_on: bool, category_id: String, btn: Button) -> void:
	FileCache.options.category_states[category_id] = toggled_on
	_set_category_visual_state(btn, toggled_on)


func _apply_automatic_tags() -> void:
	var dict_path = "res://addons/CustomControls/Dialogs/command_buttons_tags.tags"
	var tags_dict = JSON.parse_string(FileAccess.get_file_as_string(dict_path))
	var buttons: Array = get_buttons()
	
	for b in buttons:
		if "custom_search_tags" in b:
			var matched: bool = false
			for key in tags_dict.keys():
				if key in b.text:
					b.custom_search_tags = tags_dict[key]
					matched = true
					break
			if not matched:
				b.custom_search_tags = "evento, comando, event, command"
	print("All tags assigned successfully! Please save the scene (Ctrl + S).")


func _input(event: InputEvent) -> void:
	if current_button_hovered and event is InputEventKey and event.keycode == KEY_F and event.is_pressed():
		if current_button_hovered.has_meta("favorite_button"):
			var favorite_button =  current_button_hovered.get_meta("favorite_button")
			favorite_button.set_pressed(!favorite_button.is_pressed())


func _process(delta: float) -> void:
	if filter_update_timer > 0:
		filter_update_timer -= delta
		if filter_update_timer <= 0.0:
			filter_update_timer = 0.0
			update_filter_buttons()


func update_filter_buttons() -> void:
	var filter = %Filter.text.to_lower()
	var is_filtering = filter.length() > 0 or show_favorites_only
	var all_buttons = get_buttons()
	
	var buttons_by_parent: Dictionary = {} 
	
	for node in all_buttons:
		var parent = node.get_parent()
		if not parent in buttons_by_parent:
			buttons_by_parent[parent] = []
		buttons_by_parent[parent].append(node)
	
	for parent_container in buttons_by_parent:
		var visible_count = 0
		var buttons_list = buttons_by_parent[parent_container]
		
		for node in buttons_list:
			var is_visible = true
			
			if show_favorites_only:
				var button_id = int(str(node.name))
				var current_favs = FileCache.options.get("current_favorite_commands", [])
				if not button_id in current_favs:
					is_visible = false
			
			if is_visible and filter.length() > 0:
				var name_match = node.text.to_lower().contains(filter)
				var tooltip_match = node.has_meta("current_tooltip") and filter in node.get_meta("current_tooltip").to_lower()
				var tags_match = "custom_search_tags" in node and filter in node.custom_search_tags.to_lower()
				
				if not (name_match or tooltip_match or tags_match):
					is_visible = false
			
			node.visible = is_visible
			if is_visible:
				visible_count += 1
		
		var margin_container = parent_container.get_parent()
		if margin_container:
			var category_vbox = margin_container.get_parent()
			if category_vbox and category_vbox is VBoxContainer:
				
				if is_filtering:
					category_vbox.visible = (visible_count > 0)
				else:
					category_vbox.visible = true
				
				var collapse_btn = _find_collapse_button_in_category(category_vbox)
				
				if collapse_btn:
					if is_filtering:
						if visible_count > 0:
							if collapse_btn.button_pressed:
								collapse_btn.set_pressed_no_signal(false)
								collapse_btn.text = "▼"
								if collapse_btn.target: collapse_btn.target.visible = true
					else:
						var category_id = _collapse_buttons_map.get(collapse_btn, "")
						var saved_state = FileCache.options.category_states.get(category_id, false)
						
						if collapse_btn.button_pressed != saved_state:
							collapse_btn.set_pressed_no_signal(saved_state)
							collapse_btn.text = "◀" if saved_state else "▼"
							if collapse_btn.target: collapse_btn.target.visible = !saved_state


func _find_collapse_button_in_category(category_vbox: Node) -> Button:
	for btn in _collapse_buttons_map:
		if category_vbox.is_ancestor_of(btn):
			return btn
	return null


func _get_button_name_available(node: Node, current_ids: Array) -> Array:
	if node is CustomSimpleButton and not node.name == "CancelButton":
		current_ids.append(int(str(node.name)))
	for child in node.get_children():
		_get_button_name_available(child, current_ids)
	if node == self:
		var current_id: int
		for id in range(1, (1 << 15) - 1, 1):
			if !id in current_ids:
				current_id = id
				break
		return ["Button%s" % current_id]
	else:
		return current_ids


func get_buttons() -> Array:
	return _get_buttons(self)


func _get_buttons(node: Node, current_buttons: Array = []) ->  Array:
	if node is CustomSimpleButton and not node.name in ["CancelButton", "ToggleAllButton"]:
		current_buttons.append(node)
	for child in node.get_children():
		_get_buttons(child, current_buttons)
	return current_buttons


func _get_available_codes() -> String:
	var available_codes: Array = []
	var i = 1
	while available_codes.size() < 5:
		if not i in CustomEditItemList.EDITABLE_CODES and not i in CustomEditItemList.NO_EDITABLE_CODES and not i in CustomEditItemList.SUB_CODES:
			available_codes.append(i)
		i += 1
	available_codes.append("...")
	return ", ".join(available_codes)


func rename_all_buttons(node: Node, current_id: Array) -> void:
	if node is CustomSimpleButton and node.name != "CancelButton":
		node.name = "Button%s" % current_id[0]
		current_id[0] += 1
	for child in node.get_children():
		rename_all_buttons(child, current_id)


func _connect_all_buttons(node: Node) -> void:
	if node is CustomSimpleButton and node.name != "CancelButton":
		node.pressed.connect(_on_button_pressed.bind(node.name))
		node.set_meta("real_parent", node.get_parent()) # Legacy support if needed
		
		if node.get_child_count() == 0:
			var b = FAVORITE_BUTTON.instantiate()
			node.add_child(b)
			var button_id: int = int(node.name)
			b.position = Vector2(node.size.x - b.size.x - 2,node.size.y / 2 - b.size.y / 2)
			b.visible = false
			b.toggled.connect(_on_favorite_button_toggled.bind(button_id))
			b.mouse_exited.connect(_hide_favorite_button.bind(node))
			b.mouse_entered.connect(_show_favorite_button.bind(node))
			var favorite_commands = FileCache.options.get("current_favorite_commands", [])
			if button_id in favorite_commands:
				b.set_pressed_no_signal(true)
			node.mouse_entered.connect(_show_favorite_button.bind(node))
			node.mouse_exited.connect(_hide_favorite_button.bind(node))
			node.set_meta("favorite_button", b)
			
	for child in node.get_children():
		_connect_all_buttons(child)


func _on_favorite_button_toggled(toggled_on: bool, button_id: int) -> void:
	if not "current_favorite_commands" in FileCache.options:
		FileCache.options.current_favorite_commands = []
	if toggled_on and not button_id in FileCache.options.current_favorite_commands:
		FileCache.options.current_favorite_commands.append(button_id)
		favorite_buttons_need_refresh = true
	elif !toggled_on and button_id in FileCache.options.current_favorite_commands:
		FileCache.options.current_favorite_commands.erase(button_id)
		favorite_buttons_need_refresh = true
	if show_favorites_only:
		filter_update_timer = 0.01


func _on_favorites_only_button_toggled(toggled_on: bool) -> void:
	show_favorites_only = toggled_on
	FileCache.options.show_favorites_only = show_favorites_only
	filter_update_timer = 0.01
	%FavoritesOnlyButton.modulate.a = 0.6 if not toggled_on else 1.0


func _show_favorite_button(node: Control) -> void:
	current_button_hovered = node
	if node.get_global_rect().has_point(node.get_global_mouse_position()):
		if node.get_child_count() > 0:
			var b = node.get_child(0)
			b.position.x = node.size.x - b.size.x - 2
			b.position.y = -b.size.y / 2
			b.show()


func _hide_favorite_button(node: Control) -> void:
	if not node.get_global_rect().has_point(node.get_global_mouse_position()):
		if node.get_child_count() > 0:
			node.get_child(0).hide()


func enable_start_battle_button(value: bool) -> void:
	var container = %VBoxContainer15
	container.get_child(1).set_disabled(!value)


func enable_battle_buttons(value: bool, affect_to_start_battle_button: bool = false) -> void:
	value = true
	var container = %VBoxContainer15
	var start_index = 2 if !affect_to_start_battle_button else 1
	for i in range(start_index, container.get_child_count()):
		container.get_child(i).set_disabled(!value)
	battle_buttons_is_enabled = value


#region Action for buttons
func _on_button_pressed(button_id: String) -> void:
	var id = int(button_id)
	request_command_created.emit(id, self)


func _on_ok_button_pressed() -> void:
	hide()


func _on_cancel_button_pressed() -> void:
	hide()


func _on_filter_text_changed(new_text: String) -> void:
	_last_filter_used = new_text
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
#endregion


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
	
	if should_collapse_all:
		%ToggleAllButton.icon = get_theme_icon("GuiTreeArrowRight", "EditorIcons")
	else:
		%ToggleAllButton.icon = get_theme_icon("Collapse", "EditorIcons")
