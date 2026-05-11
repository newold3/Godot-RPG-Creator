@tool
extends CommandBaseDialog

#region Variables
## Style for collapsed sections
@export var section_collapse_style: StyleBox

## Style for expanded sections
@export var section_expanded_style: StyleBox

## To auto-fill the tags in the effects checkboxes based on a JSON dictionary
@export var auto_fill_tags: bool = false :
	set(value):
		if value:
			_apply_automatic_tags()

var current_data: Dictionary

var cache_data: Dictionary = {
	"item_selected": 0,
	"variable_item_selected": 0,
	"actor_item_selected": 0,
	"enemy_item_selected": 0,
	"switch_selected": 1,
	"switch_value": 0,
	"variable_selected": 1,
	"variable_condition": 0,
	"variable_constant": 0,
	"variable_variable_selected": 1,
	"self_switch_selected": 0,
	"self_switch_value": 0,
	"timer_condition": 0,
	"timer_minutes": 0,
	"timer_seconds": 0,
	"timer_id": 0,
	"actor_selected": 1,
	"actor_name": "",
	"actor_class_selected": 1,
	"actor_skill_selected": 1,
	"actor_weapon_selected": 1,
	"actor_armor_selected": 1,
	"actor_state_selected": 1,
	"enemy_selected": 0,
	"enemy_state_selected": 1,
	"character_selected": 0,
	"character_direction": 0,
	"vehicle_selected": 0,
	"gold_condition": 0,
	"gold_value": 0,
	"has_item_selected": 1,
	"has_weapon_selected": 1,
	"has_weapon_equipped": false,
	"has_armor_selected": 1,
	"has_armor_equipped": false,
	"button_selected": 0,
	"button_action": 0,
	"script": "",
	"create_else_branch": false,
	"text_variable_selected": 1,
	"text_variable_condition": 0,
	"text_variable_item_selected": 0,
	"text_variable_constant": "",
	"text_variable_variable": 1,
	"profession_selected": 1,
	"profession_condition": 0,
	"profession_value": 0,
	"relationship_condition": 0,
	"relationship_value": 0,
	"actor_parameter_selected": false,
	"actor_parameter_id": 0,
	"actor_parameter_condition": 0,
	"actor_parameter_value": 0,
	"global_user_parameter_selected": false,
	"global_user_parameter_id": 0,
	"global_user_parameter_condition": 0,
	"global_user_parameter_item_selected": 0,
	"global_user_parameter_constant": 0.0,
	"global_user_parameter_variable": 0,
	"global_user_parameter_value": 0,
}

var insert_commands: Dictionary
var filter_update_timer: float = 0.0
var last_filter_used: String
var force_filter_update: bool = false

var _collapse_buttons_map: Dictionary = {}
var show_favorites_only: bool = false

const FAVORITE_BUTTON = preload("uid://dsmo7ri8d6djp")
#endregion



#region Lifecycle
## Called when the node enters the scene tree for the first time
func _ready() -> void:
	super()
	parameter_code = 21
	fill_characters()
	
	if not FileCache.options.has("category_states"):
		FileCache.options["category_states"] = {}
	
	show_favorites_only = FileCache.options.get("conditions_show_favorites_only", false)
	
	if has_node("%FavoritesOnlyButton"):
		%FavoritesOnlyButton.set_pressed_no_signal(show_favorites_only)
		if not %FavoritesOnlyButton.toggled.is_connected(_on_favorites_only_button_toggled):
			%FavoritesOnlyButton.toggled.connect(_on_favorites_only_button_toggled)
		%FavoritesOnlyButton.modulate.a = 0.6 if not show_favorites_only else 1.0
		
	_setup_collapse_buttons()
	_setup_favorite_buttons()
	
	if has_node("%FilterSmoothContainer"):
		var scroll = %FilterSmoothContainer
		if scroll.get_child_count() > 0:
			scroll.get_child(0).resized.connect(_update_window_size_by_filter_container)



## Processes the filter timer updates
func _process(delta: float) -> void:
	if filter_update_timer > 0.0:
		filter_update_timer -= delta
		if filter_update_timer <= 0:
			filter_update_timer = 0.0
			_update_filter()
#endregion



#region TagSystem
## Applies the search tags to the checkboxes based on a JSON dictionary
func _apply_automatic_tags() -> void:
	var dict_path = "res://addons/CustomControls/Dialogs/conditions_tags.tags"
	if not FileAccess.file_exists(dict_path):
		return
		
	var tags_dict = JSON.parse_string(FileAccess.get_file_as_string(dict_path))
	var checkboxes = _get_condition_checkboxes()
	
	for cb in checkboxes:
		var matched: bool = false
		var cb_text_lower = cb.text.to_lower()
		
		for key in tags_dict.keys():
			if key.to_lower() in cb_text_lower:
				cb.set_meta("custom_search_tags", tags_dict[key])
				matched = true
				break
				
		if not matched:
			cb.set_meta("custom_search_tags", "condition")
			
	print("All tags assigned successfully! Please save the scene (Ctrl + S).")



## Retrieves all valid checkboxes dynamically using the core ButtonGroup
func _get_condition_checkboxes() -> Array:
	var master_checkbox = get_node_or_null("%SwitchSelection")
	if master_checkbox and master_checkbox.button_group:
		return master_checkbox.button_group.get_buttons()
	return []
#endregion



#region UIUtilities
## Prepares the collapse buttons and restores their saved states
func _setup_collapse_buttons() -> void:
	var nodes = get_tree().get_nodes_in_group("collapse_button")
	
	for btn in nodes:
		if is_ancestor_of(btn):
			btn.toggle_mode = true 
			var category_id = "condition_" + btn.get_parent().name
			_collapse_buttons_map[btn] = category_id
			
			if not btn.toggled.is_connected(_on_collapse_button_user_toggled):
				btn.toggled.connect(_on_collapse_button_user_toggled.bind(category_id, btn))
			
			var is_collapsed = FileCache.options["category_states"].get(category_id, false)
			btn.set_pressed_no_signal(is_collapsed)
			_set_category_visual_state(btn, is_collapsed)



## Updates the visual state of a category exclusively hiding the Parent node
func _set_category_visual_state(btn: Button, is_collapsed: bool) -> void:
	btn.text = "►" if is_collapsed else "▼"
	
	var header = btn.get_parent() 
	var category_root = header.get_parent() 
	var target_node = null
	
	if category_root and category_root.has_node("Parent"):
		target_node = category_root.get_node("Parent")
	
	if target_node:
		target_node.visible = !is_collapsed

	if header is Label:
		if is_collapsed:
			if section_collapse_style:
				header.add_theme_stylebox_override("normal", section_collapse_style)
			header.set("theme_override_colors/font_color", Color("8691a6ff"))
		elif section_expanded_style:
			header.add_theme_stylebox_override("normal", section_expanded_style)
			header.set("theme_override_colors/font_color", Color("#cedeff"))
	
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



## Updates the window height safely based on internal margin container
func _update_window_size_by_filter_container() -> void:
	var scroll = %FilterSmoothContainer
	if scroll.get_child_count() > 0:
		var content = scroll.get_child(0)
		var max_h = 600
		var safe_min_h = max(min_size.y, 150)
		size.y = max(safe_min_h, min(content.size.y + 40, max_h))
#endregion



#region FavoriteSystem
## Adds favorite star buttons securely to the direct parent of valid checkboxes
func _setup_favorite_buttons() -> void:
	var checkboxes = _get_condition_checkboxes()
	for cb in checkboxes:
		var b = FAVORITE_BUTTON.instantiate()
		b.add_to_group("favorite_button")
		
		var direct_parent = cb.get_parent()
		direct_parent.add_child(b)
		
		var condition_name = cb.name
		b.toggled.connect(_on_favorite_button_toggled.bind(condition_name))
		
		var favorite_conditions = FileCache.options.get("current_favorite_conditions", [])
		if condition_name in favorite_conditions:
			b.set_pressed_no_signal(true)
			
		cb.set_meta("favorite_button", b)



## Saves or removes a favorited condition
func _on_favorite_button_toggled(toggled_on: bool, condition_name: String) -> void:
	if not FileCache.options.has("current_favorite_conditions"):
		FileCache.options["current_favorite_conditions"] = []
		
	var favs: Array = FileCache.options["current_favorite_conditions"]
	
	if toggled_on and not condition_name in favs:
		favs.append(condition_name)
		force_filter_update = true
	elif not toggled_on and condition_name in favs:
		favs.erase(condition_name)
		force_filter_update = true
		
	FileCache.options["current_favorite_conditions"] = favs
	
	if show_favorites_only:
		filter_update_timer = 0.01



## Handles the main favorite toggle logic
func _on_favorites_only_button_toggled(toggled_on: bool) -> void:
	show_favorites_only = toggled_on
	FileCache.options["conditions_show_favorites_only"] = show_favorites_only
	force_filter_update = true
	filter_update_timer = 0.01
	
	if has_node("%FavoritesOnlyButton"):
		%FavoritesOnlyButton.modulate.a = 0.6 if not toggled_on else 1.0
#endregion



#region Filtering
## Triggers filter execution
func _on_filter_text_changed(new_text: String) -> void:
	if new_text.length() != 0:
		%Filter.right_icon = ResourceLoader.load("res://addons/CustomControls/Images/filter_reset.png")
	else:
		%Filter.right_icon = ResourceLoader.load("res://addons/CustomControls/Images/magnifying_glass.png")
	filter_update_timer = 0.25



## Clears filter manually
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



## Main filter logic hiding non-matching rows directly
func _update_filter() -> void:
	if last_filter_used != %Filter.text.to_lower() or force_filter_update:
		force_filter_update = false
		var filter = %Filter.text.to_lower()
		last_filter_used = filter
		var is_filtering = filter.length() > 0 or show_favorites_only
		
		var checkboxes = _get_condition_checkboxes()
		var rows_by_btn: Dictionary = {}
		var cb_by_row: Dictionary = {}
		
		for cb in checkboxes:
			var row = _get_row_for_checkbox(cb)
			var collapse_btn = _find_collapse_button_in_category(row)
			
			if collapse_btn:
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
					var current_favs = FileCache.options.get("current_favorite_conditions", [])
					if not cb.name in current_favs:
						is_visible = false
						
				if is_visible and filter.length() > 0:
					is_visible = _check_filter_match(row, filter)
				
				row.visible = is_visible
				if is_visible:
					visible_count += 1
			
			if collapse_btn:
				var category_root = collapse_btn.get_parent().get_parent() 
				if category_root:
					if is_filtering:
						category_root.visible = (visible_count > 0)
						if visible_count > 0 and collapse_btn.button_pressed:
							collapse_btn.set_pressed_no_signal(false)
							_set_category_visual_state(collapse_btn, false)
					else:
						category_root.visible = true
						var category_id = _collapse_buttons_map.get(collapse_btn, "")
						var saved_state = FileCache.options["category_states"].get(category_id, false)
						if collapse_btn.button_pressed != saved_state:
							collapse_btn.set_pressed_no_signal(saved_state)
							_set_category_visual_state(collapse_btn, saved_state)
					
		if has_node("%FilterSmoothContainer"):
			_update_window_size_by_filter_container()



## Ascends to find the main Row container (Condition1) directly below Parent
func _get_row_for_checkbox(cb: CheckBox) -> Control:
	var current = cb
	while current and current.get_parent():
		if current.get_parent().name == "Parent":
			return current
		current = current.get_parent()
	return cb.get_parent()



## Checks if a row or its children match the filter text
func _check_filter_match(node: Node, filter: String) -> bool:
	if "text" in node and typeof(node.get("text")) == TYPE_STRING and node.get("text").to_lower().find(filter) != -1:
		return true
	if "tooltip_text" in node and typeof(node.get("tooltip_text")) == TYPE_STRING and node.get("tooltip_text").to_lower().find(filter) != -1:
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



## Locates the collapse button by analyzing your specific tree structure
func _find_collapse_button_in_category(row: Node) -> Button:
	var parent_container = row.get_parent()
	if parent_container and parent_container.name == "Parent":
		var category_root = parent_container.get_parent()
		if category_root and category_root.has_node("Label"):
			var label = category_root.get_node("Label")
			for child in label.get_children():
				if child is Button and child.is_in_group("collapse_button"):
					return child
	return null
#endregion



#region DataManagement
## Populates the characters list from the current map events
func fill_characters() -> void:
	var node: EditEventEditor = get_tree().get_first_node_in_group("event_editor")
	var list = %CharacterID
	list.clear()
	
	list.add_item("Player")
	list.set_item_metadata(-1, -1)
	
	if node:
		list.add_item("This Event")
		list.set_item_metadata(-1, 0)
		
		for ev: RPGEvent in node.events.get_events():
			list.add_item("%s: %s" % [ev.id, ev.name])
			list.set_item_metadata(-1, ev._uniq_id)



## Sets up the dialog data from the command parameters
func set_data() -> void:
	var config = parameters[0].parameters
	insert_commands = {}
	var i = "parameters"
	insert_commands[i] = []
	var else_branch = false
	var indent = parameters[0].indent
	
	for j in range(1, parameters.size()):
		var current_command = parameters[j]
		if current_command.code == 22 and current_command.indent == indent:
			i = "else"
			insert_commands[i] = []
			else_branch = true
		elif current_command.code != 23 or (current_command.code == 23 and current_command.indent != indent):
			insert_commands[i].append(current_command)
			
	var item_selected = config.get("item_selected", 0)
	var value1 = config.get("value1", 1)
	var value2 = config.get("value2", 0)
	var value3 = config.get("value3", null)
	var value4 = config.get("value4", null)
	var value5 = config.get("value5", null)
	var value6 = config.get("value6", null)

	cache_data.item_selected = item_selected

	match item_selected:
		0:
			cache_data.switch_selected = value1
			cache_data.switch_value = value2
		1:
			cache_data.variable_selected = value1
			cache_data.variable_condition = value2
			cache_data.variable_item_selected = value3
			if value3 == 0:
				cache_data.variable_constant = value4
			else:
				cache_data.variable_variable_selected = value4
		2:
			cache_data.self_switch_selected = value1
			cache_data.self_switch_value = value2
		3:
			cache_data.timer_condition = value1
			cache_data.timer_minutes = value2
			cache_data.timer_seconds = value3
		4:
			cache_data.actor_selected = value1
			cache_data.actor_item_selected = value2
			match value2:
				1: cache_data.actor_name = value3
				2: cache_data.actor_class_selected = value3
				3: cache_data.actor_skill_selected = value3
				4: cache_data.actor_weapon_selected = value3
				5: cache_data.actor_armor_selected = value3
				6: cache_data.actor_state_selected = value3
				7:
					cache_data.actor_parameter_selected = value3
					cache_data.actor_parameter_id = value4
					cache_data.actor_parameter_condition = value5
					cache_data.actor_parameter_value = value6
		5:
			cache_data.enemy_selected = value1
			cache_data.enemy_item_selected = value2
			if value2 == 1:
				cache_data.enemy_state_selected = value3
		6:
			cache_data.character_selected = value1
			cache_data.character_direction = value2
		7:
			cache_data.vehicle_selected = value1
		8:
			cache_data.gold_condition = value1
			cache_data.gold_value = value2
		9:
			cache_data.has_item_selected = value1
		10:
			cache_data.has_weapon_selected = value1
			cache_data.has_weapon_equipped = value2
		11:
			cache_data.has_armor_selected = value1
			cache_data.has_armor_equipped = value2
		12:
			cache_data.button_selected = value1
			cache_data.button_action = value2
		13:
			cache_data.script = value1
		14:
			cache_data.text_variable_selected = value1
			cache_data.text_variable_condition = value2
			cache_data.text_variable_item_selected = value3
			if value3 == 0:
				cache_data.text_variable_constant = value4
			else:
				cache_data.text_variable_variable = value4
		15:
			cache_data.profession_selected = value1
			cache_data.profession_condition = value2
			cache_data.profession_value = value3
		16:
			cache_data.relationship_condition = value2
			cache_data.relationship_value = value3
		17:
			cache_data.global_user_parameter_selected = value1
			cache_data.global_user_parameter_condition = value2
			cache_data.global_user_parameter_item_selected = value3
			if value3 == 0:
				cache_data.global_user_parameter_constant = value4
			else:
				cache_data.global_user_parameter_variable = value4
	
	cache_data.create_else_branch = else_branch
	update_controls()
	
	# Llamada diferida para enfocar el comando cargado y expandir si hace falta
	call_deferred("_focus_selected_condition")



## Syncs the cache data back to the interface visually
func update_controls() -> void:
	_fill_actor_parameters()
	_fill_global_user_parameters()
	
	var node = %SelfSwitchID
	node.clear()

	for switch_name in RPGSYSTEM.system.self_switches.keys:
		node.add_item(switch_name)

	_set_switch_name(cache_data.switch_selected, %SwitchID)
	%SwitchValue.select(cache_data.switch_value)
	_set_variable_name(cache_data.variable_selected, %VariableID)
	%VariableCondition.select(cache_data.variable_condition)
	%VariableConstantValue.value = cache_data.variable_constant
	_set_variable_name(cache_data.variable_variable_selected, %VariableVariableValue)
	_set_data_name(null, cache_data.text_variable_selected, %TextVariableID)
	%TextVariableCondition.select(cache_data.text_variable_condition)
	%TextVariableConstantValue.set_deferred("text", cache_data.text_variable_constant)
	_set_data_name(null, cache_data.text_variable_variable, %TextVariableVariableValue)
	_set_data_name("professions", cache_data.profession_selected, %ProfessionID)
	
	%ProfessionCondition.select(cache_data.profession_condition)
	%ProfessionValue.value = cache_data.profession_value
	%RelationshipCondition.select(cache_data.relationship_condition)
	%RelationshipValue.value = cache_data.relationship_value
	
	if %ActorParameters.get_item_count() > cache_data.actor_parameter_id and cache_data.actor_parameter_id >= 0:
		%ActorParameters.select(cache_data.actor_parameter_id)
	else:
		%ActorParameters.select(0)
		cache_data.actor_parameter_id = 0
	
	%ActorParametersCondition.select(cache_data.actor_parameter_condition)
	%ActorParametersValue.value =  cache_data.actor_parameter_value
	
	var var_buttons = [%VariableConstantSelection, %VariableVariableSelection]
	var_buttons[cache_data.variable_item_selected].set_pressed(false)
	var_buttons[cache_data.variable_item_selected].set_pressed(true)
	
	var text_buttons = [%TextVariableConstantSelection, %TextVariableVariableSelection]
	text_buttons[cache_data.text_variable_item_selected].set_pressed(false)
	text_buttons[cache_data.text_variable_item_selected].set_pressed(true)
	
	var global_user_parameter_buttons = [%GlobalParameterConstantSelection, %GlobalParameterVariableSelection]
	global_user_parameter_buttons[cache_data.global_user_parameter_item_selected].set_pressed(false)
	global_user_parameter_buttons[cache_data.global_user_parameter_item_selected].set_pressed(true)
	
	var main_buttons = [
		%SwitchSelection, %VariableSelection, %SelfSwitchSelection, %TimerSelection,
		%ActorSelection, %EnemySelection, %CharacterSelection, %VehicleSelection,
		%GoldSelection, %ItemSelection, %WeaponSelection, %HasArmorEquipment,
		%ButtonSelection, %ScriptSelection, %VariableTextSelection,
		%ProfessionSelection, %RelationshipSelection, %GlobalUserParametersSelection
	]

	%SelfSwitchID.select(cache_data.self_switch_selected)
	%SelfSwitchValue.select(cache_data.self_switch_value)
	%TimerCondition.select(cache_data.timer_condition)
	%TimerMin.value = cache_data.timer_minutes
	%TimerSec.value = cache_data.timer_seconds
	%TimerID.value = cache_data.timer_id
	
	_set_data_name("actors", cache_data.actor_selected, %ActorID)
	%ActorNameValue.text = cache_data.actor_name
	_set_data_name("classes", cache_data.actor_class_selected, %ActorClassID)
	_set_data_name("skills", cache_data.actor_skill_selected, %ActorSkillID)
	_set_data_name("weapons", cache_data.actor_weapon_selected, %ActorWeaponID)
	_set_data_name("armors", cache_data.actor_armor_selected, %ActorArmorID)
	_set_data_name("states", cache_data.actor_state_selected, %ActorStateID)
	
	var buttons = %ActorIsInPartySelection.button_group.get_buttons()
	buttons[cache_data.actor_item_selected].set_pressed(false)
	buttons[cache_data.actor_item_selected].set_pressed(true)
	
	%EnemyID.select(cache_data.enemy_selected)
	_set_data_name("states", cache_data.enemy_state_selected, %EnemyStateID)
	buttons = %EnemyAppearedSelection.button_group.get_buttons()
	buttons[cache_data.enemy_item_selected].set_pressed(false)
	buttons[cache_data.enemy_item_selected].set_pressed(true)

	var items = %CharacterID.get_item_count()
	if items > 0:
		%CharacterID.select(0)
		for i in %CharacterID.get_item_count():
			var real_index = %CharacterID.get_item_metadata(i)
			if real_index == cache_data.character_selected:
				%CharacterID.select(i)
				break
	
	%CharacterState.select(cache_data.character_direction)
	%CharacterState.set_item_disabled(-2, %CharacterID.get_selected_id() != 0)
	%CharacterState.set_item_disabled(-1, %CharacterID.get_selected_id() == 0)
	%VehicleID.select(cache_data.vehicle_selected)
	
	%GoldCondition.select(cache_data.gold_condition)
	%GoldValue.value = cache_data.gold_value

	_set_data_name("items", cache_data.has_item_selected, %ItemID)
	_set_data_name("weapons", cache_data.has_weapon_selected, %WeaponID)
	%WeaponIncludeEquipment.set_pressed(cache_data.has_weapon_equipped)
	_set_data_name("armors", cache_data.has_armor_selected, %ArmorID)
	%ArmorIncludeEquipment.set_pressed(cache_data.has_armor_equipped)

	%ButtonID.select(cache_data.button_selected)
	%ButtonAction.select(cache_data.button_action)
	%ScriptContents.text = cache_data.script
	%CreateElseBranch.set_pressed(cache_data.create_else_branch)
	
	if %GlobalUserParameters.get_item_count() > cache_data.global_user_parameter_id:
		%GlobalUserParameters.select(cache_data.global_user_parameter_id)
	elif %GlobalUserParameters.get_item_count() > 0:
		%GlobalUserParameters.select(0)
	
	%GlobalUserParametersCondition.select(cache_data.global_user_parameter_condition)
	%GlobalParameterConstantValue.value = cache_data.global_user_parameter_constant
	
	if %GlobalParameterVariableValue.get_item_count() > cache_data.global_user_parameter_variable:
		%GlobalParameterVariableValue.select(cache_data.global_user_parameter_variable)
	elif %GlobalParameterVariableValue.get_item_count() > 0:
		%GlobalParameterVariableValue.select(0)

	main_buttons[cache_data.item_selected].set_pressed(false)
	main_buttons[cache_data.item_selected].set_pressed(true)



## Populates the actor parameters dropdown
func _fill_actor_parameters() -> void:
	var items = PackedStringArray(["Level", "Experience"]) + RPGSYSTEM.database.types.main_parameters
	var node = %ActorParameters
	node.clear()
	
	for item in items:
		node.add_item(item)
	
	var user_parameters = RPGSYSTEM.database.types.user_parameters
	
	if user_parameters.size() > 0:
		node.add_separator()
		
		for param in user_parameters:
			node.add_item("User Parameter: " + param.name)



## Populates the global user parameters dropdown
func _fill_global_user_parameters() -> void:
	var node1 = %GlobalUserParameters
	node1.clear()
	var node2 = %GlobalParameterVariableValue
	node2.clear()
	
	var user_parameters = RPGSYSTEM.database.types.user_parameters
	
	if user_parameters.size() > 0:
		for param in user_parameters:
			node1.add_item("User Parameter: " + param.name)
			node2.add_item("User Parameter: " + param.name)
	else:
		node1.add_item("No User parameters")
		node2.add_item("No User parameters")



## Prepares a database selector button's display name using UIDs
func _set_data_name(data_key: Variant, id: int, target: Node) -> void:
	if target == %TextVariableID or target == %TextVariableVariableValue:
		var data = RPGSYSTEM.system.text_variables.data
		var data_name = "%s:%s" % [
			str(id).pad_zeros(4),
			data[id].name if data.size() > id else "⚠ Invalid Data"
		]
		target.text = data_name
	else:
		var item = RPGSYSTEM.get_data(data_key, id)
		if item:
			var classic_id = RPGSYSTEM.uid_to_id(data_key, id)
			var items_size = RPGSYSTEM.database[data_key].size()
			var data_name = "%s:%s" % [
				str(classic_id).pad_zeros(str(items_size).length()),
				item.name
			]
			target.text = data_name
		else:
			target.text = "⚠ Invalid Data"



## Prepares a variable selector button's display name using classic IDs
func _set_variable_name(id: int, target: Node) -> void:
	var variables = RPGSYSTEM.system.variables
	var index = id
	var variable_name = "%s:%s" % [
		str(index).pad_zeros(4),
		variables.get_item_name(index)
	]
	target.text = variable_name



## Prepares a switch selector button's display name using classic IDs
func _set_switch_name(id: int, target: Node) -> void:
	var variables = RPGSYSTEM.system.switches
	var index = id
	var variable_name = "%s:%s" % [
		str(index).pad_zeros(4),
		variables.get_item_name(index)
	]
	target.text = variable_name
#endregion



#region Logic
## Generates the command list based on the configured branch
func build_command_list() -> Array[RPGEventCommand]:
	var commands: Array[RPGEventCommand] = []

	var item_selected = cache_data.item_selected
	var value1; var value2; var value3; var value4; var value5; var value6;
	
	match item_selected:
		0:
			value1 = cache_data.switch_selected
			value2 = cache_data.switch_value
		1:
			value1 = cache_data.variable_selected
			value2 = cache_data.variable_condition
			value3 = cache_data.variable_item_selected
			if value3 == 0:
				value4 = cache_data.variable_constant
			else:
				value4 = cache_data.variable_variable_selected
		2:
			value1 = cache_data.self_switch_selected
			value2 = cache_data.self_switch_value
		3:
			value1 = cache_data.timer_condition
			value2 = cache_data.timer_minutes
			value3 = cache_data.timer_seconds
			value4 = cache_data.timer_id
		4:
			value1 = cache_data.actor_selected
			value2 = cache_data.actor_item_selected
			match value2:
				1: value3 = cache_data.actor_name
				2: value3 = cache_data.actor_class_selected
				3: value3 = cache_data.actor_skill_selected
				4: value3 = cache_data.actor_weapon_selected
				5: value3 = cache_data.actor_armor_selected
				6: value3 = cache_data.actor_state_selected
				7:
					value3 = cache_data.actor_parameter_selected
					value4 = cache_data.actor_parameter_id
					value5 = cache_data.actor_parameter_condition
					value6 = cache_data.actor_parameter_value
		5:
			value1 = cache_data.enemy_selected
			value2 = cache_data.enemy_item_selected
			if value2 == 1:
				value3 = cache_data.enemy_state_selected
		6:
			value1 = cache_data.character_selected
			value2 = cache_data.character_direction
		7:
			value1 = cache_data.vehicle_selected
		8:
			value1 = cache_data.gold_condition
			value2 = cache_data.gold_value
		9:
			value1 = cache_data.has_item_selected
		10:
			value1 = cache_data.has_weapon_selected
			value2 = cache_data.has_weapon_equipped
		11:
			value1 = cache_data.has_armor_selected
			value2 = cache_data.has_armor_equipped
		12:
			value1 = cache_data.button_selected
			value2 = cache_data.button_action
		13:
			value1 = cache_data.script
		14:
			value1 = cache_data.text_variable_selected
			value2 = cache_data.text_variable_condition
			value3 = cache_data.text_variable_item_selected
			if value3 == 0:
				value4 = cache_data.text_variable_constant
			else:
				value4 = cache_data.text_variable_variable
		15:
			value1 = cache_data.profession_selected
			value2 = cache_data.profession_condition
			value3 = cache_data.profession_value
		16:
			value2 = cache_data.relationship_condition
			value3 = cache_data.relationship_value
		17:
			value1 = cache_data.global_user_parameter_id
			value2 = cache_data.global_user_parameter_condition
			value3 = cache_data.global_user_parameter_item_selected
			if value3 == 0:
				value4 = cache_data.global_user_parameter_constant
			else:
				value4 = cache_data.global_user_parameter_variable

	var config = {
		"item_selected": item_selected,
		"value1": value1,
		"value2": value2,
		"value3": value3,
		"value4": value4,
		"value5": value5,
		"value6": value6,
		"else_branch": %CreateElseBranch.is_pressed()
	}
	
	var current_indent = parameters[0].indent
	
	var command = RPGEventCommand.new()
	command.code = 23
	command.indent = current_indent
	commands.append(command)
	
	if config.else_branch:
		var index = "else"
		var extra_commands = insert_commands.get(index, [])
		if extra_commands.size() > 0:
			for i in range(extra_commands.size() - 1, -1, -1):
				command = extra_commands[i]
				commands.append(command)
		else:
			command = RPGEventCommand.new()
			command.code = 0
			command.indent = current_indent + 1
			commands.append(command)
			
		command = RPGEventCommand.new()
		command.code = 22
		command.indent = current_indent
		commands.append(command)
		
	var index = "parameters"
	var extra_commands = insert_commands.get(index, [])
	
	if extra_commands.size() > 0:
		for i in range(extra_commands.size() - 1, -1, -1):
			command = extra_commands[i]
			commands.append(command)
	else:
		command = RPGEventCommand.new()
		command.code = 0
		command.indent = current_indent + 1
		commands.append(command)
	
	config.erase("else_branch")
	var command_parent = super()
	command_parent[-1].parameters = config
	commands.append(command_parent[-1])
	
	return commands
#endregion



#region Dialog_Callbacks
## Helper to open the generic data selector converting UID to index first
func _open_select_any_data_dialog(key: String, id_selected: int, title: String, target: int) -> void:
	var path = "res://addons/CustomControls/Dialogs/select_any_data_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	dialog.database = RPGSYSTEM.database
	
	var data: Variant
	var classic_id = id_selected
	
	if target == 14 or target == 141:
		data = RPGSYSTEM.system.text_variables.data
	else:
		data = RPGSYSTEM.database[key]
		classic_id = RPGSYSTEM.uid_to_id(key, id_selected)
		classic_id = max(1, min(classic_id, data.size() - 1))
	
	dialog.destroy_on_hide = true
	dialog.selected.connect(_on_any_data_selected.bind(key))
	
	dialog.setup(data, classic_id, title, target)



## Callback when a generic data item is selected to convert back to UID
func _on_any_data_selected(id: int, target: int, key: String) -> void:
	var final_id = id
	if target != 14 and target != 141:
		final_id = RPGSYSTEM.id_to_uid(key, id)
		
	match target:
		0:
			cache_data.actor_selected = final_id
			_set_data_name(key, final_id, %ActorID)
		1:
			cache_data.actor_class_selected = final_id
			_set_data_name(key, final_id, %ActorClassID)
		2:
			cache_data.actor_skill_selected = final_id
			_set_data_name(key, final_id, %ActorSkillID)
		3:
			cache_data.actor_weapon_selected = final_id
			_set_data_name(key, final_id, %ActorWeaponID)
		4:
			cache_data.actor_armor_selected = final_id
			_set_data_name(key, final_id, %ActorArmorID)
		5:
			cache_data.actor_state_selected = final_id
			_set_data_name(key, final_id, %ActorStateID)
		6:
			cache_data.enemy_state_selected = final_id
			_set_data_name(key, final_id, %EnemyStateID)
		7:
			cache_data.has_item_selected = final_id
			_set_data_name(key, final_id, %ItemID)
		8:
			cache_data.has_weapon_selected = final_id
			_set_data_name(key, final_id, %WeaponID)
		9:
			cache_data.has_armor_selected = final_id
			_set_data_name(key, final_id, %ArmorID)
		14:
			cache_data.text_variable_selected = final_id
			_set_data_name(key, final_id, %TextVariableID)
		141:
			cache_data.text_variable_variable = final_id
			_set_data_name(key, final_id, %TextVariableVariableValue)
		15:
			cache_data.profession_selected = final_id
			_set_data_name(key, final_id, %ProfessionID)



## Opens the generic switch or variable dialog
func open_switch_variable(type: int, id: int, target: Node, selected: Callable, name_changed: Callable) -> void:
	var path = "res://addons/CustomControls/Dialogs/switch_variable_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	dialog.data_type = type
	dialog.target = target
	dialog.selected.connect(selected)
	dialog.variable_or_switch_name_changed.connect(name_changed)
	dialog.setup(id)



## Handles the user toggling a collapse button directly
func _on_collapse_button_user_toggled(toggled_on: bool, category_id: String, btn: Button) -> void:
	FileCache.options["category_states"][category_id] = toggled_on
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
#endregion



#region UI_Handlers
## Disables unused controls when switching main modes but keeps utilities alive
func disable_all() -> void:
	propagate_call("set_disabled", [true])
	
	if has_node("%Filter"): %Filter.set_disabled(false)
	if has_node("%ToggleAllButton"): %ToggleAllButton.set_disabled(false)
	if has_node("%FavoritesOnlyButton"): %FavoritesOnlyButton.set_disabled(false)
		
	var collapse_buttons = get_tree().get_nodes_in_group("collapse_button")
	for btn in collapse_buttons:
		if is_ancestor_of(btn):
			btn.set_disabled(false)
			
	var favorite_buttons = get_tree().get_nodes_in_group("favorite_button")
	for btn in favorite_buttons:
		if is_ancestor_of(btn):
			btn.set_disabled(false)
			
	var checkboxes = _get_condition_checkboxes()
	for cb in checkboxes:
		cb.set_disabled(false)
	
	if has_node("%CreateElseBranch"): %CreateElseBranch.set_disabled(false)
	if has_node("%OKButton"): %OKButton.set_disabled(false)
	if has_node("%CancelButton"): %CancelButton.set_disabled(false)



## Triggers when a main item category is selected
func _on_item_selected_toggled(toggled_on: bool, index: int) -> void:
	if toggled_on:
		cache_data.item_selected = index
		disable_all()
	
	var nodes: Array
	match index:
		0:
			nodes = [%SwitchID, %SwitchValue]
		1:
			nodes = [%VariableID, %VariableCondition, %VariableConstantSelection, %VariableVariableSelection]
		2:
			nodes = [%SelfSwitchID, %SelfSwitchValue]
		3:
			nodes = [%TimerCondition, %TimerMin, %TimerSec, %TimerID]
		4:
			nodes = [%ActorID, %ActorIsInPartySelection, %ActorNameSelection, %ActorClassSelection, %ActorSkillSelection, %ActorWeaponSelection, %ActorArmorSelection, %ActorStateSelection, %ActorParametersSelection]
		5:
			nodes = [%EnemyID, %EnemyAppearedSelection, %EnemyStateSelection]
		6:
			nodes = [%CharacterID, %CharacterState]
		7:
			nodes = [%VehicleID]
		8:
			nodes = [%GoldCondition, %GoldValue]
		9:
			nodes = [%ItemID]
		10:
			nodes = [%WeaponID, %WeaponIncludeEquipment]
		11:
			nodes = [%ArmorID, %ArmorIncludeEquipment]
		12:
			nodes = [%ButtonID, %ButtonAction]
		13:
			nodes = [%ScriptContents]
		14:
			nodes = [%TextVariableID, %TextVariableCondition, %TextVariableConstantSelection, %TextVariableVariableSelection]
		15:
			nodes = [%ProfessionID, %ProfessionCondition, %ProfessionValue]
		16:
			nodes = [%RelationshipCondition, %RelationshipValue]
		17:
			nodes = [%GlobalUserParameters, %GlobalUserParametersCondition, %GlobalParameterConstantSelection, %GlobalParameterVariableSelection]
	
	for node in nodes:
		node.set_disabled(false)
	
	var button
	if index == 1:
		button = %VariableConstantSelection.button_group.get_pressed_button()
	elif index == 3:
		%TimerMin.get_line_edit().call_deferred("grab_focus")
	elif index == 4:
		button = %ActorIsInPartySelection.button_group.get_pressed_button()
	elif index == 5:
		button = %EnemyAppearedSelection.button_group.get_pressed_button()
	elif index == 8:
		%GoldValue.get_line_edit().call_deferred("grab_focus")
	elif index == 13:
		%ScriptContents.call_deferred("grab_focus")
	elif index == 14:
		button = %TextVariableConstantSelection.button_group.get_pressed_button()
	elif index == 15:
		%ProfessionValue.get_line_edit().call_deferred("grab_focus")
	elif index == 16:
		%RelationshipValue.get_line_edit().call_deferred("grab_focus")
	elif index == 17:
		button = %GlobalParameterConstantSelection.button_group.get_pressed_button()
		
	if button:
		button.set_pressed(false)
		button.set_pressed(true)



func _on_actor_item_selected(toggled_on: bool, index: int) -> void:
	if toggled_on:
		cache_data.actor_item_selected = index
	if index != 0:
		var buttons = %ActorIsInPartySelection.button_group.get_buttons()
		buttons[index].get_parent().propagate_call("set_disabled", [!toggled_on])
		buttons[index].set_disabled(false)
		
	if index == 1:
		%ActorNameValue.grab_focus()



func _on_variable_item_selected(toggled_on: bool, index: int) -> void:
	if toggled_on:
		cache_data.variable_item_selected = index

	if index == 0:
		%VariableConstantValue.set_disabled(false)
		%VariableVariableValue.set_disabled(true)
	else:
		%VariableConstantValue.set_disabled(true)
		%VariableVariableValue.set_disabled(false)



func _on_enemy_item_selected(toggled_on: bool, index: int) -> void:
	if toggled_on:
		cache_data.enemy_item_selected = index
	if index != 0:
		var buttons = %EnemyAppearedSelection.button_group.get_buttons()
		buttons[index].get_parent().get_child(2).set_disabled(!toggled_on)



func _on_switch_id_pressed() -> void:
	open_switch_variable(1, cache_data.switch_selected, %SwitchID, _on_switch_changed, _on_switch_name_changed)



func _on_switch_changed(index: int, target: Node) -> void:
	cache_data.switch_selected = index
	_set_switch_name(index, target)



func _on_switch_name_changed() -> void:
	_set_switch_name(cache_data.switch_selected, %SwitchID)



func _on_switch_value_item_selected(index: int) -> void:
	cache_data.switch_value = index



func _on_variable_id_pressed() -> void:
	open_switch_variable(0, cache_data.variable_selected, %VariableID, _on_variable_changed, _on_variable_name_changed)



func _on_variable_changed(index: int, target: Node) -> void:
	cache_data.variable_selected = index
	_set_variable_name(index, target)



func _on_variable_name_changed() -> void:
	_set_variable_name(cache_data.variable_selected, %VariableID)
	_set_variable_name(cache_data.variable_variable_selected, %VariableVariableValue)



func _on_variable_condition_item_selected(index: int) -> void:
	cache_data.variable_condition = index



func _on_variable_constant_value_value_changed(value: float) -> void:
	cache_data.variable_constant = value



func _on_variable_variable_value_pressed() -> void:
	open_switch_variable(0, cache_data.variable_variable_selected, %VariableVariableValue, _on_variable_variable_changed, _on_variable_name_changed)



func _on_variable_variable_changed(index: int, target: Node) -> void:
	cache_data.variable_variable_selected = index
	_set_variable_name(index, target)



func _on_self_switch_id_item_selected(index: int) -> void:
	cache_data.self_switch_selected = index



func _on_self_switch_value_item_selected(index: int) -> void:
	cache_data.self_switch_value = index



func _on_timer_condition_item_selected(index: int) -> void:
	cache_data.timer_condition = index



func _on_timer_min_value_changed(value: float) -> void:
	cache_data.timer_minutes = value



func _on_timer_sec_value_changed(value: float) -> void:
	cache_data.timer_seconds = value



func _on_actor_id_pressed() -> void:
	_open_select_any_data_dialog("actors", cache_data.actor_selected, "Actors", 0)



func _on_actor_name_value_text_changed(new_text: String) -> void:
	cache_data.actor_name = new_text



func _on_actor_class_id_pressed() -> void:
	_open_select_any_data_dialog("classes", cache_data.actor_class_selected, "Classes", 1)



func _on_actor_skill_id_pressed() -> void:
	_open_select_any_data_dialog("skills", cache_data.actor_skill_selected, "Skills", 2)



func _on_actor_weapon_id_pressed() -> void:
	_open_select_any_data_dialog("weapons", cache_data.actor_weapon_selected, "Weapons", 3)



func _on_actor_armor_id_pressed() -> void:
	_open_select_any_data_dialog("armors", cache_data.actor_armor_selected, "Armors", 4)



func _on_actor_state_id_pressed() -> void:
	_open_select_any_data_dialog("states", cache_data.actor_state_selected, "States", 5)



func _on_enemy_id_item_selected(index: int) -> void:
	cache_data.enemy_selected = index



func _on_enemy_state_pressed() -> void:
	_open_select_any_data_dialog("states", cache_data.enemy_state_selected, "States", 6)



func _on_character_id_item_selected(index: int) -> void:
	var target_id = %CharacterID.get_item_metadata(index)
	cache_data.character_selected = target_id
	%CharacterState.set_item_disabled(-2, index != 0)
	%CharacterState.set_item_disabled(-1, index == 0)
	if index == 0 and %CharacterState.get_selected_id() == %CharacterState.get_item_count() -1:
		%CharacterState.select(0)
		_on_character_direction_item_selected(0)



func _on_character_direction_item_selected(index: int) -> void:
	cache_data.character_direction = index



func _on_vehicle_id_item_selected(index: int) -> void:
	cache_data.vehicle_selected = index



func _on_gold_condition_item_selected(index: int) -> void:
	cache_data.gold_condition = index



func _on_gold_value_value_changed(value: float) -> void:
	cache_data.gold_value = value



func _on_item_id_pressed() -> void:
	_open_select_any_data_dialog("items", cache_data.has_item_selected, "Items", 7)



func _on_weapon_id_pressed() -> void:
	_open_select_any_data_dialog("weapons", cache_data.has_weapon_selected, "Weapons", 8)



func _on_weapon_include_equipment_toggled(toggled_on: bool) -> void:
	cache_data.has_weapon_equipped = toggled_on



func _on_armor_id_pressed() -> void:
	_open_select_any_data_dialog("armors", cache_data.has_armor_selected, "Armors", 9)



func _on_armor_include_equipment_toggled(toggled_on: bool) -> void:
	cache_data.has_armor_equipped = toggled_on



func _on_button_id_item_selected(index: int) -> void:
	cache_data.button_selected = index



func _on_button_action_item_selected(index: int) -> void:
	cache_data.button_action = index



func _on_custom_line_edit_text_changed(new_text: String) -> void:
	cache_data.script = new_text



func _on_create_else_branch_toggled(toggled_on: bool) -> void:
	cache_data.create_else_branch = toggled_on



func _on_timer_id_value_changed(value: float) -> void:
	cache_data.timer_id = value



func _on_text_variable_id_pressed() -> void:
	_open_select_any_data_dialog("text_variable", cache_data.text_variable_selected, "Variable", 14)



func _on_text_variable_condition_item_selected(index: int) -> void:
	cache_data.text_variable_condition = index



func _on_text_variable_item_selected(toggled_on: bool, index: int) -> void:
	if toggled_on:
		cache_data.text_variable_item_selected = index
	
	if index == 0:
		%TextVariableConstantValue.set_disabled(false)
		%TextVariableVariableValue.set_disabled(true)
	else:
		%TextVariableConstantValue.set_disabled(true)
		%TextVariableVariableValue.set_disabled(false)



func _on_text_variable_variable_value_pressed() -> void:
	_open_select_any_data_dialog("text_variable", cache_data.text_variable_variable, "Variable", 141)



func _on_text_variable_constant_value_text_changed(new_text: String) -> void:
	cache_data.text_variable_constant = new_text



func _on_profession_id_pressed() -> void:
	_open_select_any_data_dialog("professions", cache_data.profession_selected, "Profession", 15)



func _on_profession_condition_item_selected(index: int) -> void:
	cache_data.profession_condition = index



func _on_profession_value_value_changed(value: float) -> void:
	cache_data.profession_value = value



func _on_relationship_condition_item_selected(index: int) -> void:
	cache_data.relationship_condition = index



func _on_relationship_value_value_changed(value: float) -> void:
	cache_data.relationship_value = value



func _on_actor_parameters_item_selected(index: int) -> void:
	cache_data.actor_parameter_id = index



func _on_actor_parameters_condition_item_selected(index: int) -> void:
	cache_data.actor_parameter_condition = index



func _on_actor_parameters_value_value_changed(value: float) -> void:
		cache_data.actor_parameter_value = value



func _on_global_user_parameters_item_selected(index: int) -> void:
	cache_data.global_user_parameter_id = index



func _on_global_user_parameters_condition_item_selected(index: int) -> void:
	cache_data.global_user_parameter_condition = index



func _on_global_parameter_item_selected(toggled_on: bool, index: int) -> void:
	if toggled_on:
		cache_data.global_user_parameter_item_selected = index
	
	if index == 0:
		%GlobalParameterConstantValue.set_disabled(false)
		%GlobalParameterVariableValue.set_disabled(true)
	else:
		%GlobalParameterConstantValue.set_disabled(true)
		%GlobalParameterVariableValue.set_disabled(false)



func _on_global_parameter_constant_value_value_changed(value: float) -> void:
	cache_data.global_user_parameter_constant = value



func _on_global_parameter_variable_value_item_selected(index: int) -> void:
	cache_data.global_user_parameter_variable = index



## Expands and scrolls to the selected item smoothly
func _focus_selected_condition() -> void:
	var master_checkbox = get_node_or_null("%SwitchSelection")
	if not master_checkbox or not master_checkbox.button_group:
		return
		
	var pressed_btn = master_checkbox.button_group.get_pressed_button()
	if not pressed_btn:
		return
		
	var row = _get_row_for_checkbox(pressed_btn)
	if not row:
		return
		
	var collapse_btn = _find_collapse_button_in_category(row)
	if collapse_btn and collapse_btn.button_pressed:
		collapse_btn.set_pressed_no_signal(false)
		_set_category_visual_state(collapse_btn, false)
		var category_id = _collapse_buttons_map.get(collapse_btn, "")
		if category_id != "":
			FileCache.options["category_states"][category_id] = false
			
	await get_tree().process_frame
	
	var scroll = %FilterSmoothContainer
	if scroll and scroll.has_method("ensure_control_visible"):
		scroll.ensure_control_visible(row)
#endregion
