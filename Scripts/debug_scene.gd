extends CanvasLayer


#region Variables

## Style for the window when focused
@export var window_focused_style: StyleBox

## Style for the window when unfocused
@export var window_unfocused_style: StyleBox

## Texture used to fill the background
@export var fill_texture: Texture


const TAB_BUTTON = preload("res://addons/CustomControls/custom_button.tscn")

var is_enabled: bool = false
var current_tab: String
var busy: bool = false
var backup_mouse_position: Vector2
var search_filter: String = ""
var pending_search_text: String = ""
var search_timer: Timer

var current_data: Array = []

var backup_indexes = {
	"Switch": 0,
	"Variable": 0,
	"Text Variable": 0,
	"Self Switch": 0,
	"Item": 0,
	"Weapon": 0,
	"Armor": 0,
	"Costume/Set": 0,
	"Quest": 0,
	"Actor": 0
}

var current_actors: PackedInt64Array

@onready var data_list: VBoxContainer = %DataList

#endregion



#region Lifecycle

func _ready() -> void:
	%DataList.get_item_list().focus_mode = Control.FOCUS_CLICK
	%DataList.get_item_list().gui_input.connect(_on_data_list_gui_input)
	%DataList.get_v_scroll_bar().value_changed.connect(func(_value): update_function_button())
	%DataList.get_item_list().mouse_exited.connect(func(): %FunctionButtonContainer.visible = false)
	%DataList.get_item_list().focus_entered.connect(_on_item_list_focus_entered)
	
	%SearchLineEdit.text_changed.connect(_on_search_line_edit_text_changed)
	%SearchLineEdit.focus_entered.connect(_config_hand_over_menu_main_buttons)
	%SearchLineEdit.focus_mode = Control.FOCUS_CLICK
	
	%GoldNumber.focus_mode = Control.FOCUS_CLICK
	%GoldNumber.get_line_edit().focus_mode = Control.FOCUS_CLICK
	
	search_timer = Timer.new()
	search_timer.wait_time = 0.4
	search_timer.one_shot = true
	search_timer.timeout.connect(_apply_search_filter)
	add_child(search_timer)
	
	create_tabs()
	%FunctionButtonContainer.visible = false
	visibility_changed.connect(
		func(): 
			GameManager.set_cursor_manipulator(GameManager.MANIPULATOR_MODES.NONE)
			%SearchLineEdit.focus_mode = Control.FOCUS_CLICK
			%GoldNumber.focus_mode = Control.FOCUS_CLICK
			%GoldNumber.get_line_edit().focus_mode = Control.FOCUS_CLICK
			
			if visible:
				_set_gold()
				current_actors = GameManager.game_state.current_party.duplicate()
			else:
				if current_actors != GameManager.game_state.current_party:
					_update_map_actors()
				%GoldNumber.apply()
	)
	hide()


func _update_map_actors()-> void:
	var party_manager = GameManager.main_scene.get_node_or_null("%PartyManager")
	if party_manager:
		if GameManager.game_state.followers_enabled:
			await party_manager.show_followers(true, false)
		else:
			await party_manager.update_party_visuals(true)



## Manages cursor manipulation and focus switching based on controller input
func _process(_delta: float) -> void:
	if not visible or not is_enabled: return
	
	var manipulator = GameManager.get_cursor_manipulator()
	var direction = ControllerManager.get_pressed_direction()
	
	if manipulator == GameManager.MANIPULATOR_MODES.MAIN_MENU_MAIN_BUTTONS:
		if direction:
			if ["up", "down"].has(direction):
				var current_button = get_viewport().gui_get_focus_owner()
				var handled = false
				
				if current_button == %SearchLineEdit:
					if direction == "down":
						%DataList.get_item_list().grab_focus()
					handled = true
					get_viewport().set_input_as_handled()
					
				elif current_button.get_parent() == %TabContainer:
					var idx = current_button.get_index()
					if direction == "up":
						if idx > 0:
							%TabContainer.get_child(idx - 1).grab_focus()
						else:
							%SearchLineEdit.grab_focus()
					elif direction == "down" and idx < %TabContainer.get_child_count() - 1:
						%TabContainer.get_child(idx + 1).grab_focus()
					handled = true
					get_viewport().set_input_as_handled()
					
				if not handled:
					var next_control = GameManager.controller.get_closest_focusable_control(current_button, direction)
					if next_control and next_control != current_button:
						next_control.grab_focus()
						get_viewport().set_input_as_handled()
			if ["left", "right"].has(direction):
				%DataList.select_current()
				get_viewport().set_input_as_handled()
		elif ControllerManager.is_action_just_pressed("Button R1 Extra"):
				%DataList.select_current()
				get_viewport().set_input_as_handled()
		elif ControllerManager.is_confirm_just_pressed(false, [KEY_KP_ENTER, KEY_SPACE]):
			var button = get_viewport().gui_get_focus_owner()
			if button and button is Button:
				if button == %CloseButton:
					end()
				else:
					button.set_pressed(true)
	elif manipulator == GameManager.MANIPULATOR_MODES.ITEM_MENU4:
		if data_list:
			if ControllerManager.is_action_just_pressed("Button R1 Extra"):
				var button = %TabContainer.get_child(0).button_group.get_pressed_button()
				if button:
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

#endregion



#region Core

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

#endregion



#region UI

func create_tabs() -> void:
	var node = %TabContainer
	var tabs = ["Switches", "Variables", "Text Variables", "Self Switches", "Items", "Weapons", "Armors", "Costumes/Sets", "Quests", "Actors"]
	var tabs_singular = ["Switch", "Variable", "Text Variable", "Self Switch", "Item", "Weapon", "Armor", "Costume/Set", "Quest", "Actor"]
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
		button.focus_entered.connect(_config_hand_over_menu_main_buttons)
	
	%CloseButton.reparent(%TabContainer)
	node.get_child(0).set_pressed(true)



func _config_hand_over_menu_main_buttons() -> void:
	var hand_manipulator = GameManager.MANIPULATOR_MODES.MAIN_MENU_MAIN_BUTTONS
	GameManager.set_cursor_manipulator(hand_manipulator)
	GameManager.set_confin_area(Rect2(), hand_manipulator)
	GameManager.set_hand_position(MainHandCursor.HandPosition.LEFT, hand_manipulator)
	GameManager.set_cursor_offset(Vector2(8, 0), hand_manipulator)
	ControllerManager.set_focusable_control_threshold(150, 150)
	GameManager.force_show_cursor()
	
	var text = "Enter to view data selected"
	text += " " + tr("Use Tab to change between left buttons or list.")
	_set_label_info(text)



func _config_hand_over_list() -> void:
	var hand_manipulator = GameManager.MANIPULATOR_MODES.ITEM_MENU4
	GameManager.set_cursor_manipulator(hand_manipulator)
	var rect = data_list.get_parent().get_global_rect()
	rect.size.y -= 22
	GameManager.set_confin_area(rect, hand_manipulator)
	GameManager.set_hand_position(MainHandCursor.HandPosition.LEFT, hand_manipulator)
	GameManager.set_cursor_offset(Vector2(8, 0), hand_manipulator)
	ControllerManager.set_focusable_control_threshold(150, 150)
	GameManager.force_show_cursor()



func _set_label_info(text: String) -> void:
	%BottomLabelInfo.text = text



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

#endregion



#region Data Manipulation

## Loads data for the selected tab and sets column headers
func _load_data(value: bool, tab: String, skip_selection: bool = false) -> void:
	backup_mouse_position = %DataList.get_local_mouse_position()
	if value:
		current_tab = tab
	
	%IncreasesLabel.text = tr("Increases by") + " :"
		
	if value and GameManager.game_state:
		var data = null
		var real_data = null
		var text = ""
		var col_name = ""
		
		match tab:
			"Switch":
				data = GameManager.game_state.game_switches
				real_data = RPGSYSTEM.system.switches
				text = tr("Use 🢀 Left or 🢂 Right To change the value.")
				col_name = tr("Current value")
			"Variable":
				data = GameManager.game_state.game_variables
				real_data = RPGSYSTEM.system.variables
				text = tr("Use 🢀 Left or 🢂 Right To change the value. Or double click to enter value manually")
				col_name = tr("Current value")
				%IncreasesLabel.text = tr("Set value/s to") + " :"
			"Text Variable":
				data = GameManager.game_state.game_text_variables
				real_data = RPGSYSTEM.system.text_variables
				text = tr("Double click to enter value manually")
				col_name = tr("Current value")
			"Self Switch":
				data = GameManager.game_state.game_self_switches
				real_data = RPGSYSTEM.system.self_switches
				text = tr("Use 🢀 Left or 🢂 Right To change the value.")
				col_name = tr("Current value")
			"Item":
				real_data = RPGSYSTEM.database.items
				text = tr("Use 🢀 Left or 🢂 Right To change the amount. Or double click to enter value manually")
				col_name = tr("Items in Stock")
			"Weapon":
				real_data = RPGSYSTEM.database.weapons
				text = tr("Use 🢀 Left or 🢂 Right To change the amount. Or double click to enter value manually")
				col_name = tr("Weapons in Stock")
			"Armor":
				real_data = RPGSYSTEM.database.armors
				text = tr("Use 🢀 Left or 🢂 Right To change the amount. Or double click to enter value manually")
				col_name = tr("Armors in Stock")
			"Costume/Set":
				real_data = RPGSYSTEM.database.costumes
				text = tr("Use 🢀 Left or 🢂 Right To change the amount. Or double click to enter value manually")
				col_name = tr("Costumes/Sets in Stock")
			"Quest":
				real_data = RPGSYSTEM.database.quests
				text = tr("Use 🢀 Left or 🢂 Right To change unlock status.")
				col_name = tr("Is Unlocked?")
			"Actor":
				real_data = RPGSYSTEM.database.actors
				text = tr("Use 🢀 Left or 🢂 Right To add or remove actor from party.")
				col_name = tr("Is In Party?")
		
		text += " " + tr("Use Tab to change between left buttons or list.")
		_set_label_info(text)
		data_list.set_column_name(1, col_name)
		
		%ValuesExtra.visible = tab in ["Variable", "Item", "Weapon", "Armor", "Costume/Set"]
		
		var selected_id = backup_indexes[current_tab]
		await fill_data(tab, data, real_data, selected_id, skip_selection)



## Fills the list with the current tab data, applies search filters, and manages cursor repositioning
func fill_data(tab: String, data: Variant, real_data: Variant, selected_id: int, skip_selection: bool = false) -> void:
	var node = %DataList
	var scroll_bar_y_value = node.get_v_scroll_bar().value
	var last_selected_index = node.get_selected_items()
	var last_item_count = node.get_item_count()
	GameManager.hand_cursor.pause_reposition = true
	node.clear()
	current_data.clear()
	
	if ["Switch", "Variable", "Text Variable"].has(tab):
		for i in range(1, data.size()):
			var data_name: String = real_data.get_item_name(i)
			if !data_name:
				data_name = "%s ID %s" % [tab, i]
				
			if search_filter != "" and not data_name.to_lower().contains(search_filter) and str(i) != search_filter:
				continue
				
			@warning_ignore("incompatible_ternary")
			var n = str(data[i]) if data[i] is String else int(data[i])
			var value = str(n if tab != "Switch" else true if data[i] == 1 else false)
			
			node.add_column([data_name, value])
			current_data.append(i)
		await node.columns_setted
		
	elif tab == "Self Switch":
		for key: String in data:
			var map_id = int(key.get_slice("_", 0))
			var event_id = int(key.get_slice("_", 1))
			var switch_id = int(key.get_slice("_", 2))
			var map_name = RPGSYSTEM.map_infos.get_map_name_from_id(map_id)
			var switch_name = RPGSYSTEM.system.self_switches.get_self_switch_name(switch_id).to_upper()
			var event_name = RPGSYSTEM.map_infos.get_event_name(map_id, event_id)
			var full_name = "Map %s: <Event %s> Switch %s" % [map_name, event_name, switch_name]
			
			if search_filter != "" and not full_name.to_lower().contains(search_filter):
				continue
				
			var switch_value = data[key]
			node.add_column([full_name, switch_value])
			current_data.append(key)
		await node.columns_setted
		
	elif ["Item", "Weapon", "Armor", "Costume/Set"].has(tab):
		for i in range(1, real_data.size()):
			var db_item = real_data[i]
			if db_item == null:
				continue
				
			var data_name: String = db_item.name
			if search_filter != "" and not data_name.to_lower().contains(search_filter) and str(i) != search_filter:
				continue
				
			var amount = 0
			match tab:
				"Item": amount = GameManager.get_item_amount(i)
				"Weapon": amount = GameManager.get_weapon_amount(i)
				"Armor": amount = GameManager.get_armor_amount(i)
				"Costume/Set": amount = GameManager.get_costume_amount(i)

			if db_item.max_quantity != 0 and amount >= db_item.max_quantity:
				amount = str(amount) + " (" + tr("max quantity") + ")"

			node.add_column(["[%s] %s" % [i, data_name], str(amount)])
			current_data.append(i)
		await node.columns_setted
		
	elif tab == "Quest":
		for i in range(1, real_data.size()):
			var quest = real_data[i]
			if quest == null:
				continue
				
			var data_name: String = quest.name
			if search_filter != "" and not data_name.to_lower().contains(search_filter) and str(i) != search_filter:
				continue
				
			var uid = quest._uniq_id
			var is_unlocked = GameManager.game_state.quest_progress.unlocked_quests.get(uid, false)
			
			node.add_column(["[%s] %s" % [i, data_name], str(is_unlocked)])
			current_data.append(i)
		await node.columns_setted
	
	elif tab == "Actor":
		for i in range(1, real_data.size()):
			var actor = real_data[i]
			if actor == null: continue
				
			var uid = actor._uniq_id
			var data_name: String = actor.name
			if search_filter != "" and not data_name.to_lower().contains(search_filter) and str(i) != search_filter:
				continue
				
			var is_in_party = GameManager.game_state.current_party.has(uid)
			node.add_column(["[%s] %s" % [i, data_name], str(is_in_party)])
			current_data.append(i)
		await node.columns_setted

	if not skip_selection:
		if node.get_item_count() > selected_id:
			node.select(selected_id)
			node.item_selected.emit(selected_id)
		elif node.get_item_count() > 0:
			node.select(0)
			node.item_selected.emit(0)
			
		if current_data.size() > 0:
			node.get_item_list().grab_focus()
		
	var new_selected_index = node.get_selected_items()
	var new_item_count = node.get_item_count()
	
	if new_item_count == last_item_count and last_selected_index and new_selected_index and last_selected_index[0] == new_selected_index[0]:
		await get_tree().process_frame
		node.get_v_scroll_bar().value = scroll_bar_y_value
		await get_tree().process_frame
		node.warp_mouse(backup_mouse_position)
		
	GameManager.hand_cursor.pause_reposition = false



func _on_search_line_edit_text_changed(new_text: String) -> void:
	pending_search_text = new_text.to_lower()
	search_timer.start()


func _apply_search_filter() -> void:
	search_filter = pending_search_text
	_load_data(true, current_tab, true)


## Updates visibility and position of the contextual function buttons
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
		%EditValue.visible = current_tab in ["Variable", "Text Variable", "Item", "Weapon", "Armor", "Costume/Set"]
		%AddValue.visible = current_tab in ["Variable", "Item", "Weapon", "Armor", "Costume/Set"]
		%SubtractValue.visible = current_tab in ["Variable", "Item", "Weapon", "Armor", "Costume/Set"]
		%ToggleValue.visible = current_tab in ["Switch", "Self Switch", "Quest", "Actor"]
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
		var visual_index = selected_items[0]
		var real_id = current_data[visual_index]
		
		match current_tab:
			"Switch":
				var current_value = GameManager.game_state.game_switches[real_id]
				GameManager.game_state.game_switches[real_id] = 0 if current_value == 1 else 1
			"Variable":
				GameManager.game_state.game_variables[real_id] += int(target_value)
			"Item":
				if int(target_value) > 0: GameManager.add_item_amount(real_id, int(target_value))
				else: GameManager.remove_item_amount(real_id, abs(int(target_value)))
			"Weapon":
				if int(target_value) > 0: GameManager.add_weapon_amount(real_id, int(target_value))
				else: GameManager.remove_weapon_amount(real_id, abs(int(target_value)), false)
			"Armor":
				if int(target_value) > 0: GameManager.add_armor_amount(real_id, int(target_value))
				else: GameManager.remove_armor_amount(real_id, abs(int(target_value)), false)
			"Costume/Set":
				if int(target_value) > 0: GameManager.add_costumes_amount(real_id, int(target_value))
				else: GameManager.remove_costumes_amount(real_id, abs(int(target_value)))
			"Quest":
				var quest = RPGSYSTEM.database.quests[real_id]
				var uid = quest._uniq_id
				var current = GameManager.game_state.quest_progress.unlocked_quests.get(uid, false)
				GameManager.game_state.quest_progress.unlocked_quests[uid] = !current
			"Actor":
				var uid = RPGSYSTEM.id_to_uid("actors", real_id)
				var is_in_party = GameManager.game_state.current_party.has(uid)
				if is_in_party:
					GameManager.remove_party_member(uid)
				else:
					GameManager.add_party_member(uid)
	
		await _load_data(true, current_tab)
	
	get_viewport().set_input_as_handled()



func change_self_switch(index: int) -> void:
	if current_data:
		var key = current_data[index]
		GameManager.game_state.game_self_switches[key] = !GameManager.game_state.game_self_switches[key]
		var data = GameManager.game_state.game_self_switches
		var real_data = RPGSYSTEM.system.self_switches
		fill_data("Self Switch", data, real_data, index)



## Opens the appropriate dialog for editing a value manually
func _edit_value(index: int) -> void:
	backup_mouse_position = %DataList.get_local_mouse_position()
	match current_tab:
		"Variable", "Item", "Weapon", "Armor", "Costume/Set":
			_open_number_dialog(index)
		"Text Variable":
			_open_text_dialog(index)



## Opens a numeric input dialog for variables and inventory items
func _open_number_dialog(index: int) -> void:
	var path = "res://addons/CustomControls/Dialogs/select_number_value_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED)
	stylize_dialog(dialog)
	
	var real_id = current_data[index]
	var current_val = 0
	var title_prefix = ""
	
	match current_tab:
		"Variable":
			current_val = GameManager.game_state.game_variables[real_id]
			title_prefix = "Variable"
		"Item":
			current_val = GameManager.get_item_amount(real_id)
			title_prefix = "Item"
			dialog.set_min_max_values(1, 99)
		"Weapon":
			current_val = GameManager.get_weapon_amount(real_id)
			title_prefix = "Weapon"
			dialog.set_min_max_values(1, 99)
		"Armor":
			current_val = GameManager.get_armor_amount(real_id)
			title_prefix = "Armor"
			dialog.set_min_max_values(1, 99)
		"Costume/Set":
			current_val = GameManager.get_costume_amount(real_id)
			title_prefix = "Costume/Set"
			dialog.set_min_max_values(1, 99)
			
	dialog.title = tr("Select " + title_prefix + " #" + str(real_id)) + " " + tr("value")
	dialog.set_min_max_values(0, 0)
	dialog.set_value(current_val)
	
	dialog.selected_value.connect(
		func(value: int):
			match current_tab:
				"Variable":
					GameManager.game_state.game_variables[real_id] = value
				"Item":
					var diff = value - GameManager.get_item_amount(real_id)
					if diff > 0: GameManager.add_item_amount(real_id, diff)
					elif diff < 0: GameManager.remove_item_amount(real_id, abs(diff))
				"Weapon":
					var diff = value - GameManager.get_weapon_amount(real_id)
					if diff > 0: GameManager.add_weapon_amount(real_id, diff)
					elif diff < 0: GameManager.remove_weapon_amount(real_id, abs(diff), false)
				"Armor":
					var diff = value - GameManager.get_armor_amount(real_id)
					if diff > 0: GameManager.add_armor_amount(real_id, diff)
					elif diff < 0: GameManager.remove_armor_amount(real_id, abs(diff), false)
				"Costume/Set":
					var diff = value - GameManager.get_costume_amount(real_id)
					if diff > 0: GameManager.add_costume_amount(real_id, diff)
					elif diff < 0: GameManager.remove_costume_amount(real_id, abs(diff), false)
			
			_load_data(true, current_tab, true)
	)



func _open_text_dialog(index: int) -> void:
	var path = "res://addons/CustomControls/Dialogs/select_text_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED)
	stylize_dialog(dialog)
	
	var real_id = current_data[index]
	dialog.title =  tr("Select Variable" + " #" + str([real_id])) + " " + tr("value")
	dialog.force_emit = true
	dialog.set_text(GameManager.game_state.game_text_variables[real_id])
	
	dialog.text_selected.connect(
		func(value: String):
			GameManager.game_state.game_text_variables[real_id] = value
			var data = GameManager.game_state.game_text_variables
			var real_data = RPGSYSTEM.system.text_variables
			fill_data(current_tab, data, real_data, index)
	)



func select_item_under_mouse() -> int:
	var node = %DataList
	var pos = node.get_local_mouse_position() - Vector2(0, node.get_item_rect(0).size.y)
	var index = node.get_item_at_position(pos)

	if index >= 0:
		node.select(index)
		node.item_selected.emit(index)

	backup_mouse_position = node.get_local_mouse_position()

	return index



func _on_close_button_pressed() -> void:
	end()



func _on_data_list_gui_input(event: InputEvent) -> void:
	if is_enabled:
		if event is InputEventMouseMotion:
			update_function_button()
		else:
			if event.is_action_pressed("ui_left", true):
				call_deferred("change_value", -1)
				get_viewport().set_input_as_handled()
			elif event.is_action_pressed("ui_right", true):
				call_deferred("change_value", 1)
				get_viewport().set_input_as_handled()
			elif event.is_action_pressed("ui_up", true) or event.is_action_pressed("ui_down", true):
				get_viewport().set_input_as_handled()



## Handles logic when an item in the data list is activated
func _on_data_list_item_activated(index: int) -> void:
	backup_mouse_position = %DataList.get_local_mouse_position()
	var real_index = index
	match current_tab:
		"Switch", "Quest", "Actor": change_value(null)
		"Variable", "Text Variable", "Item", "Weapon", "Armor", "Costume/Set": _edit_value(real_index)
		"Self Switch": change_self_switch(real_index)
		"Quest": change_value(null)



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



func _on_remove_value_pressed() -> void:
	var index = select_item_under_mouse()
	if current_data and index != -1:
		GameManager.game_state.game_self_switches.erase(current_data[index])
		var data = GameManager.game_state.game_self_switches
		var real_data = RPGSYSTEM.system.self_switches
		fill_data("Self Switch", data, real_data, index)



func _on_data_list_item_selected(index: int) -> void:
	backup_indexes[current_tab] = index
	%DataList.ensure_current_is_visible(index)



func _on_item_list_focus_entered() -> void:
	_config_hand_over_list()
	if current_data.size() == 0:
		var button = %TabContainer.get_child(0).button_group.get_pressed_button()
		button.grab_focus()


func _set_gold() -> void:
	if not RPGSYSTEM.database: return
	
	var icon_path: String = RPGSYSTEM.database.system.currency_info.get("icon", "")
	var icon_name: String = RPGSYSTEM.database.system.currency_info.get("name", "")
	if AssetManager.exists(icon_path):
		%GoldIcon.texture = load(icon_path)
	else:
		%GoldIcon.texture = null
	%GoldLabel.text = icon_name
	if GameManager.game_state and GameManager.game_state.current_gold:
		%GoldNumber.value = GameManager.game_state.current_gold
	else:
		%GoldNumber.value = 0

#endregion


func _on_gold_number_value_changed(value: float) -> void:
	GameManager.game_state.current_gold = value


func _on_set_all_values_value_changed(value: float) -> void:
	if current_tab == "Variable":
		for i in GameManager.game_state.game_variables.size():
			GameManager.game_state.game_variables[i] = value
	elif current_tab == "Item":
		for item in RPGSYSTEM.database.items:
			if item: GameManager.add_item_amount(item._uniq_id, value)
	elif current_tab == "Weapon":
		for item in RPGSYSTEM.database.weapons:
			if item: GameManager.add_weapon_amount(item._uniq_id, value)
	elif current_tab == "Armor":
		for item in RPGSYSTEM.database.armors:
			if item: GameManager.add_armor_amount(item._uniq_id, value)
	elif current_tab == "Costume/Set":
		for item in RPGSYSTEM.database.costumes:
			if item: GameManager.add_costume_amount(item._uniq_id, value)
	
	_load_data(true, current_tab, true)


func _on_set_all_values_button_pressed() -> void:
	_on_set_all_values_value_changed(%SetAllValues.value)
