@tool
extends Window


## Rename all the buttons so that their IDs are consecutive without any gaps. (This option is disabled in the script by default to prevent accidental activation, which could change the current button names. These names have already been added to other scripts that use them as references.)
@export var set_button_names: bool = false :
	set(value):
		if value:
			# Disabled to prevent accidentally pressing this button and renaming all 
			# the buttons, which could overwrite the commands currently added.
			#rename_all_buttons(self, [1])
			pass

## To add a new button, activate this variable in the inspector and it will tell a valid button name to use
@export var get_available_button_name: bool = false :
	set(value):
		if value:
			print("Available Button Name: " + _get_button_name_available(self, [])[0])
			print("Available Codes: " + _get_available_codes())


## Variable used in the editor to quickly change the selected page in the tab container.
@export_range(0, 2, 1) var show_buttons_page: int = 0 :
	set(value):
		show_buttons_page = value
		if is_node_ready():
			%CustomTabContainer.select(show_buttons_page, true)


var battle_buttons_is_enabled: bool = false
var filter_update_timer: float = 0.0

var favorite_buttons_need_refresh: bool = false

var current_button_hovered: CustomSimpleButton

const FAVORITE_BUTTON = preload("uid://dsmo7ri8d6djp")


var wrap_control_tween: Tween

static var last_page_selected : int = 0
static var _last_filter_used: String

signal request_command_created(command_code: int, from_dialog: Window)
signal request_update_favorite_buttons()


func _ready() -> void:
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
	%CustomTabContainer.update_tabs(3, last_page_selected, true)
	_connect_all_buttons(self)
	close_requested.connect(hide)
	enable_battle_buttons(battle_buttons_is_enabled, false)
	if not _last_filter_used.is_empty():
		%Filter.text = _last_filter_used
		_on_filter_text_changed(_last_filter_used)
		filter_update_timer = 0.01

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
	reset_button_parents(self)
	fix_buttons_order(self)
	for container in [%GroupButtons1, %GroupButtons2, %GroupButtons3, %FilterButtons]:
		container.visible = false
	%CustomTabContainer.visible = false
	%FilterButtonsContainer.size.y = 0
	%FilterButtonsContainer.get_parent().size.y = 0
	
	var filter = %Filter.text.to_lower()
	if filter.length() > 0:
		show_filter_buttons(self, filter)
		%FilterButtons.visible = true
		await get_tree().process_frame
		size.y = min(%FilterButtonsContainerMargin.size.y + 110, 840)
	else:
		%CustomTabContainer.visible = true
		var index = %CustomTabContainer.selected_tab
		[%GroupButtons1, %GroupButtons2, %GroupButtons3][index].visible = true
		size.y = %ButtonsContainer.get_child(index).get_child(0).get_child(0).size.y + 170


func reset_button_parents(node: Node) -> void:
	if node is CustomSimpleButton:
		var node_parent = node.get_meta("real_parent")
		if node.get_parent() != node_parent:
			node.reparent(node_parent)

	for child in node.get_children():
		reset_button_parents(child)


func fix_buttons_order(node: Node) -> void:
	if node is CustomSimpleButton:
		var original_position_in_tree = node.get_meta("original_position_in_tree")
		if node.get_index() != original_position_in_tree:
			node.get_parent().move_child(node, original_position_in_tree)

	for child in node.get_children():
		fix_buttons_order(child)


func show_filter_buttons(node: Node, filter: String, add_nodes_to_end: Array = [], step: int = 0) -> void:
	if node is CustomSimpleButton:
		if node.text.to_lower().find(filter) != -1:
			node.reparent(%FilterButtonsContainer)
		elif node.has_meta("current_tooltip"):
			var node_tooltip = node.get_meta("current_tooltip").to_lower()
			if filter in node_tooltip:
				add_nodes_to_end.append(node)
	
	for child in node.get_children():
		show_filter_buttons(child, filter, add_nodes_to_end, 1)
	
	if step == 0:
		if not add_nodes_to_end.is_empty():
			for n in add_nodes_to_end:
				n.reparent(%FilterButtonsContainer)


func _get_button_name_available(node: Node, current_ids: Array) -> Array:
	if node is CustomSimpleButton and not node.name == "CancelButton":
		current_ids.append(int(str(node.name)))
	
	for child in node.get_children():
		_get_button_name_available(child, current_ids)
	
	if node == self:
		var current_id: int
		# Max Buttons = INT16_MAX
		for id in range(1, (1 << 15) - 1, 1):
			if !id in current_ids:
				current_id = id
				break
		return ["Button%s" % current_id]
	else:
		return current_ids


func get_buttons() -> Array:
	var buttons = _get_buttons(self)
	return buttons


func _get_buttons(node: Node, current_buttons: Array = []) ->  Array:
	if node is CustomSimpleButton and not node.name == "CancelButton":
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
		node.set_meta("real_parent", node.get_parent())
		node.set_meta("original_position_in_tree", node.get_index())
		
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


func _on_custom_tab_container_tab_changed(index: int) -> void:
	if %Filter.text.length() > 0: return
	
	last_page_selected = index
	
	for child in %ButtonsContainer.get_children():
		child.visible = false
	
	%FilterButtons.visible = false
	
	if %Filter.text.length() == 0:
		if %ButtonsContainer.get_child_count() > index:
			%ButtonsContainer.get_child(index).visible = true
			size.y = %ButtonsContainer.get_child(index).get_child(0).get_child(0).size.y + 80
	else:
		%FilterButtons.visible = true
	
	if wrap_control_tween:
		wrap_control_tween.kill()
	
	wrap_control_tween = create_tween()
	for i in 6:
		wrap_control_tween.tween_callback(set.bind("wrap_controls", true))
		wrap_control_tween.tween_interval(0.03)
		wrap_control_tween.tween_callback(set.bind("wrap_controls", false))
		wrap_control_tween.tween_interval(0.03)


func enable_start_battle_button(value: bool) -> void:
	var container = %BattleButtonContainer
	container.get_child(1).set_disabled(!value)


func enable_battle_buttons(value: bool, affect_to_start_battle_button: bool = false) -> void:
	value = true
	var container = %BattleButtonContainer
	var start_index = 2 if !affect_to_start_battle_button else 1
	for i in range(start_index, container.get_child_count()):
		container.get_child(i).set_disabled(!value)
	
	battle_buttons_is_enabled = value


# region Action for buttons
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
