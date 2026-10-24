@tool
class_name EventGraphEditor
extends Window

# Preloads
const SEARCH_POPUP_SCENE = preload("res://addons/CustomControls/Dialogs/EventGraphEditor/graph_command_search_popup.gd")
const BranchNodes = preload("res://addons/CustomControls/Dialogs/EventGraphEditor/branch_graph_nodes.gd")
const EventGraphConfigManager = preload("res://addons/CustomControls/Dialogs/EventGraphEditor/event_graph_config_manager.gd")
const ContainerGraphNode = preload("res://addons/CustomControls/Dialogs/EventGraphEditor/container_graph_node.gd")
const ReminderGraphNode = preload("res://addons/CustomControls/Dialogs/EventGraphEditor/reminder_graph_node.gd")

# Panel Scenes Preloads (.tscn layouts)
const CommandNodeScene = preload("res://addons/CustomControls/Dialogs/EventGraphEditor/Panels/command_graph_node.tscn")
const ConditionNodeScene = preload("res://addons/CustomControls/Dialogs/EventGraphEditor/Panels/condition_graph_node.tscn")
const ChoiceNodeScene = preload("res://addons/CustomControls/Dialogs/EventGraphEditor/Panels/choice_graph_node.tscn")
const LoopNodeScene = preload("res://addons/CustomControls/Dialogs/EventGraphEditor/Panels/loop_graph_node.tscn")
const BattleNodeScene = preload("res://addons/CustomControls/Dialogs/EventGraphEditor/Panels/battle_graph_node.tscn")
const StartNodeScene = preload("res://addons/CustomControls/Dialogs/EventGraphEditor/Panels/start_graph_node.tscn")
const ContainerNodeScene = preload("res://addons/CustomControls/Dialogs/EventGraphEditor/Panels/container_graph_node.tscn")
const ReminderNodeScene = preload("res://addons/CustomControls/Dialogs/EventGraphEditor/Panels/reminder_graph_node.tscn")

static func _instantiate_start_node() -> GraphNode:
	if StartNodeScene:
		return StartNodeScene.instantiate()
	return BranchNodes.StartGraphNode.new()

static func _instantiate_condition_node() -> GraphNode:
	if ConditionNodeScene:
		return ConditionNodeScene.instantiate()
	return BranchNodes.ConditionGraphNode.new()

static func _instantiate_choice_node() -> GraphNode:
	if ChoiceNodeScene:
		return ChoiceNodeScene.instantiate()
	return BranchNodes.ChoiceGraphNode.new()

static func _instantiate_loop_node() -> GraphNode:
	if LoopNodeScene:
		return LoopNodeScene.instantiate()
	return BranchNodes.LoopGraphNode.new()

static func _instantiate_battle_node() -> GraphNode:
	if BattleNodeScene:
		return BattleNodeScene.instantiate()
	return BranchNodes.BattleGraphNode.new()

static func _instantiate_command_node() -> GraphNode:
	if CommandNodeScene:
		return CommandNodeScene.instantiate()
	return CommandGraphNode.new()

static func _instantiate_container_node() -> ContainerGraphNode:
	if ContainerNodeScene:
		return ContainerNodeScene.instantiate()
	return ContainerGraphNode.new()

static func _instantiate_reminder_node() -> ReminderGraphNode:
	if ReminderNodeScene:
		return ReminderNodeScene.instantiate()
	return ReminderGraphNode.new()

# Nodes
var graph_edit: GraphEdit
var search_popup: GraphCommandSearchPopup
var status_label: Label
var edit_menu_button: MenuButton

enum EditMenuId {
	UNDO = 1,
	REDO = 2,
	CUT = 10,
	COPY = 11,
	PASTE = 12,
	DUPLICATE = 13,
	ADD_COMMAND = 20,
	GROUP_CONTAINER = 21,
	UNGROUP_CONTAINER = 22,
	ADD_NOTE = 23,
	AUTO_LAYOUT = 30,
	CLEAR_WIRES = 31
}

# Legacy button references (optional / backward compatibility)
var undo_button: Button
var redo_button: Button
var cut_button: Button
var copy_button: Button
var paste_button: Button
var duplicate_button: Button
var group_btn: Button
var note_btn: Button

# Undo / Redo & Clipboard State
var _undo_stack: Array[Dictionary] = []
var _redo_stack: Array[Dictionary] = []
var _is_restoring_state: bool = false
var _clipboard_data: Dictionary = {}
var _pre_drag_state: Dictionary = {}

# Containers & Reminders
var _containers: Array[ContainerGraphNode] = []
var _reminders: Array[ReminderGraphNode] = []
var _current_page_cfg: Dictionary = {}
var config_file_path: String = ""

# State
var original_commands: Array[RPGEventCommand] = []
var current_page: Resource = null
var current_event: RPGEvent = null
var parent_dialog: Window
var start_node: GraphNode

# Auto-incrementing node naming counter
var _node_counter: int = 0
var _pending_connect_from: StringName = ""
var _pending_connect_port: int = 0
var _pending_connect_to: StringName = ""
var _pending_connect_to_port: int = 0
var _active_dialog: Window = null

signal applied(new_commands: Array[RPGEventCommand])


func _ready() -> void:
	title = "Event Graph Editor"
	size = Vector2i(1200, 780)
	min_size = Vector2i(800, 500)
	wrap_controls = true
	
	close_requested.connect(_on_close_requested)
	_build_ui()


func _build_ui() -> void:
	for child in get_children():
		child.queue_free()
		
	var main_margin = MarginContainer.new()
	main_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main_margin.add_theme_constant_override("margin_left", 8)
	main_margin.add_theme_constant_override("margin_top", 8)
	main_margin.add_theme_constant_override("margin_right", 8)
	main_margin.add_theme_constant_override("margin_bottom", 8)
	
	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 6)
	
	# Top Toolbar
	var toolbar_panel = PanelContainer.new()
	var toolbar_hbox = HBoxContainer.new()
	toolbar_hbox.add_theme_constant_override("separation", 6)
	
	var apply_btn = Button.new()
	apply_btn.name = "ApplyButton"
	apply_btn.text = "💾 Apply & Close"
	apply_btn.tooltip_text = "[title]Aplicar y Cerrar[/title]\nGuarda los cambios del grafo y actualiza la lista de comandos del evento."
	apply_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	apply_btn.focus_mode = Control.FOCUS_NONE
	apply_btn.pressed.connect(_on_apply_pressed)
	toolbar_hbox.add_child(apply_btn)
	
	var cancel_btn = Button.new()
	cancel_btn.name = "CancelButton"
	cancel_btn.text = "❌ Cancel"
	cancel_btn.tooltip_text = "[title]Cancelar[/title]\nCierra el editor de grafo descartando los cambios no aplicados."
	cancel_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	cancel_btn.focus_mode = Control.FOCUS_NONE
	cancel_btn.pressed.connect(_on_close_requested)
	toolbar_hbox.add_child(cancel_btn)
	
	toolbar_hbox.add_child(VSeparator.new())
	
	# Edit MenuButton (consolidates undo, redo, cut, copy, paste, duplicate, add cmd, group, notes, layout, clear)
	edit_menu_button = MenuButton.new()
	edit_menu_button.name = "EditMenuButton"
	edit_menu_button.text = "✏️ Edit"
	edit_menu_button.tooltip_text = "[title]Menú Editar[/title]\nAccede a las operaciones del grafo (deshacer, rehacer, copiar, pegar, agrupar, etc.)."
	edit_menu_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	edit_menu_button.focus_mode = Control.FOCUS_NONE
	
	var edit_popup: PopupMenu = edit_menu_button.get_popup()
	edit_popup.add_theme_font_size_override("font_size", 16)
	edit_popup.add_theme_font_size_override("font_separator_size", 16)
	edit_popup.add_item("↩️ Undo (Ctrl+Z)", EditMenuId.UNDO)
	edit_popup.add_item("↪️ Redo (Ctrl+Y)", EditMenuId.REDO)
	edit_popup.add_separator()
	edit_popup.add_item("✂️ Cut (Ctrl+X)", EditMenuId.CUT)
	edit_popup.add_item("📋 Copy (Ctrl+C)", EditMenuId.COPY)
	edit_popup.add_item("📥 Paste (Ctrl+V)", EditMenuId.PASTE)
	edit_popup.add_item("👥 Duplicate (Ctrl+D)", EditMenuId.DUPLICATE)
	edit_popup.add_separator()
	edit_popup.add_item("➕ Add Command... (RMB)", EditMenuId.ADD_COMMAND)
	edit_popup.add_item("📦 Group Container (Ctrl+G)", EditMenuId.GROUP_CONTAINER)
	edit_popup.add_item("⏏ Ungroup Container (Ctrl+Shift+G)", EditMenuId.UNGROUP_CONTAINER)
	edit_popup.add_item("📝 Add Note", EditMenuId.ADD_NOTE)
	edit_popup.add_separator()
	edit_popup.add_item("📐 Auto Layout", EditMenuId.AUTO_LAYOUT)
	edit_popup.add_item("🧹 Clear Wires", EditMenuId.CLEAR_WIRES)
	
	edit_popup.about_to_popup.connect(_on_edit_popup_about_to_show)
	edit_popup.id_pressed.connect(_on_edit_menu_id_pressed)
	toolbar_hbox.add_child(edit_menu_button)
	
	# Ensure minimum font size across all controls in the graph editor is at least 16
	var base_theme = Theme.new()
	base_theme.default_font_size = 16
	base_theme.set_font_size("title_font_size", "GraphNode", 16)
	base_theme.set_font_size("font_size", "GraphNode", 16)
	base_theme.set_font_size("font_size", "Label", 16)
	base_theme.set_font_size("font_size", "Button", 16)
	base_theme.set_font_size("font_size", "LineEdit", 16)
	base_theme.set_font_size("font_size", "TextEdit", 16)
	base_theme.set_font_size("font_size", "SpinBox", 16)
	base_theme.set_font_size("font_size", "OptionButton", 16)
	base_theme.set_font_size("font_size", "PopupMenu", 16)
	base_theme.set_font_size("font_separator_size", "PopupMenu", 16)
	base_theme.set_font_size("font_size", "MenuButton", 16)
	base_theme.set_font_size("font_size", "Tree", 16)
	base_theme.set_font_size("font_size", "ItemList", 16)
	base_theme.set_font_size("font_size", "CheckBox", 16)
	theme = base_theme
	
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toolbar_hbox.add_child(spacer)
	
	status_label = Label.new()
	status_label.text = "💡 Ctrl+Z/Y: Undo/Redo | Ctrl+C/V/D: Copy/Paste/Dup | Ctrl+G: Group | RMB: Add"
	status_label.modulate = Color(0.8, 0.8, 0.8)
	status_label.add_theme_font_size_override("font_size", 16)
	toolbar_hbox.add_child(status_label)
	
	toolbar_panel.add_child(toolbar_hbox)
	main_vbox.add_child(toolbar_panel)
	
	# Center GraphEdit
	graph_edit = GraphEdit.new()
	graph_edit.name = "GraphEdit"
	graph_edit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	graph_edit.right_disconnects = true
	graph_edit.snapping_enabled = true
	graph_edit.snapping_distance = 20
	graph_edit.minimap_enabled = true
	
	# Connect GraphEdit Signals
	graph_edit.connection_request.connect(_on_connection_request)
	graph_edit.disconnection_request.connect(_on_disconnection_request)
	graph_edit.delete_nodes_request.connect(_on_delete_nodes_request)
	graph_edit.popup_request.connect(_on_popup_request)
	graph_edit.connection_to_empty.connect(_on_connection_to_empty)
	graph_edit.connection_from_empty.connect(_on_connection_from_empty)
	
	main_vbox.add_child(graph_edit)
	main_margin.add_child(main_vbox)
	add_child(main_margin)
	
	# Search Popup
	search_popup = SEARCH_POPUP_SCENE.new()
	search_popup.command_selected.connect(_on_command_selected_from_popup)
	search_popup.popup_hide.connect(_on_search_popup_closed)
	add_child(search_popup)
	_ensure_popup_font_sizes(self)


func _ensure_popup_font_sizes(root: Node) -> void:
	if not root:
		return
	if root is OptionButton:
		root.add_theme_font_size_override("font_size", 16)
		var p = root.get_popup()
		if p:
			p.add_theme_font_size_override("font_size", 16)
			p.add_theme_font_size_override("font_separator_size", 16)
	elif root is MenuButton:
		root.add_theme_font_size_override("font_size", 16)
		var p = root.get_popup()
		if p:
			p.add_theme_font_size_override("font_size", 16)
			p.add_theme_font_size_override("font_separator_size", 16)
	elif root is PopupMenu:
		root.add_theme_font_size_override("font_size", 16)
		root.add_theme_font_size_override("font_separator_size", 16)
	for child in root.get_children():
		_ensure_popup_font_sizes(child)


func setup(p_commands: Array[RPGEventCommand], p_page: Resource = null, p_parent: Window = null, p_event: RPGEvent = null) -> void:
	if not graph_edit:
		_build_ui()
	original_commands = p_commands
	current_page = p_page
	parent_dialog = p_parent
	current_event = p_event
	
	config_file_path = EventGraphConfigManager.get_config_file_path(current_event, current_page, parent_dialog)
	
	_undo_stack.clear()
	_redo_stack.clear()
	_update_undo_redo_buttons()
	build_graph_from_commands(original_commands)


func _get_current_event_id() -> String:
	if current_event:
		return str(current_event.id)
	return "0"


func _get_current_page_id() -> String:
	if current_event and current_page and "pages" in current_event:
		var idx = current_event.pages.find(current_page)
		if idx >= 0:
			return str(idx)
	if current_page:
		return str(current_page.get_instance_id())
	return "0"


#region Graph Building (List -> Graph)

func build_graph_from_commands(commands: Array[RPGEventCommand]) -> void:
	if not graph_edit:
		_build_ui()
	graph_edit.clear_connections()
	for child in graph_edit.get_children():
		if child is GraphNode:
			child.queue_free()
			
	_node_counter = 0
	_containers.clear()
	_reminders.clear()
	
	var event_id = _get_current_event_id()
	var page_id = _get_current_page_id()
	_current_page_cfg = EventGraphConfigManager.get_page_data(config_file_path, event_id, page_id)
	var has_saved_layout = not _current_page_cfg.is_empty()
	
	# 1. Create Start Node
	start_node = _instantiate_start_node()
	start_node.name = "StartNode"
	if has_saved_layout and _current_page_cfg.has("start_pos"):
		var sp = _current_page_cfg["start_pos"]
		if sp is Array and sp.size() >= 2:
			start_node.position_offset = Vector2(float(sp[0]), float(sp[1]))
	elif current_page and current_page.has_meta("graph_start_pos"):
		var sp = current_page.get_meta("graph_start_pos")
		if sp is Array and sp.size() >= 2:
			start_node.position_offset = Vector2(float(sp[0]), float(sp[1]))
			has_saved_layout = true
	else:
		start_node.position_offset = Vector2(80, 200)
	graph_edit.add_child(start_node)
	
	if commands.is_empty():
		return
		
	var res = _parse_block(commands, 0, [], -1)
	if res.first_node:
		graph_edit.connect_node(start_node.name, 0, res.first_node.name, 0)
		
	# Restore containers
	if has_saved_layout and _current_page_cfg.has("containers"):
		for c_data in _current_page_cfg["containers"]:
			var col = Color.from_string(c_data.get("color", "#2d3748"), Color("#2d3748"))
			var pos_arr = c_data.get("pos", [0, 0])
			var sz_arr = c_data.get("size", [360, 240])
			var members: Array[StringName] = []
			for m in c_data.get("member_nodes", []):
				members.append(StringName(m))
			_spawn_container(
				c_data.get("title", "Contenedor"),
				members,
				Vector2(pos_arr[0], pos_arr[1]),
				Vector2(sz_arr[0], sz_arr[1]),
				col,
				c_data.get("collapsed", false),
				c_data.get("id", "")
			)
			
	# Restore reminders
	if has_saved_layout and _current_page_cfg.has("reminders"):
		for r_data in _current_page_cfg["reminders"]:
			var col = Color.from_string(r_data.get("color", "#d69e2e"), Color("#d69e2e"))
			var pos_arr = r_data.get("pos", [0, 0])
			var sz_arr = r_data.get("size", [240, 160])
			add_reminder_node(
				r_data.get("text", ""),
				r_data.get("title", "Recordatorio"),
				Vector2(pos_arr[0], pos_arr[1]),
				Vector2(sz_arr[0], sz_arr[1]),
				col,
				r_data.get("id", "")
			)
		
	if not has_saved_layout:
		call_deferred("auto_layout")
	else:
		_layout_unpositioned_nodes()
		if _current_page_cfg.has("scroll"):
			graph_edit.scroll_offset = Vector2(_current_page_cfg["scroll"][0], _current_page_cfg["scroll"][1])
		elif current_page and current_page.has_meta("graph_scroll"):
			graph_edit.scroll_offset = current_page.get_meta("graph_scroll")
			
		if _current_page_cfg.has("zoom"):
			graph_edit.zoom = _current_page_cfg["zoom"]
		elif current_page and current_page.has_meta("graph_zoom"):
			graph_edit.zoom = current_page.get_meta("graph_zoom")


func _layout_unpositioned_nodes() -> void:
	for child in graph_edit.get_children():
		if child is GraphNode and child != start_node:
			if child.position_offset == Vector2.ZERO:
				for c in graph_edit.get_connection_list():
					var c_to = c.get("to_node", &"")
					if c_to == child.name:
						var parent_node = graph_edit.get_node_or_null(str(c.get("from_node", "")))
						if parent_node and parent_node is GraphNode:
							child.position_offset = parent_node.position_offset + Vector2(350, 0)
							break


func _parse_block(commands: Array[RPGEventCommand], start_idx: int, stop_codes: Array[int] = [], parent_indent: int = -1) -> Dictionary:
	var first_node: GraphNode = null
	var prev_node: GraphNode = null
	var prev_port: int = 0
	var i = start_idx
	
	while i < commands.size():
		var cmd = commands[i]
		
		# Check stop codes at parent indent
		if not stop_codes.is_empty() and cmd.code in stop_codes:
			if parent_indent == -1 or cmd.indent == parent_indent:
				break
				
		if cmd.code == 0:
			i += 1
			continue
			
		var current_node: GraphNode = null
		var next_out_node: GraphNode = null
		var next_out_port: int = 0
		
		# Condition (21)
		if cmd.code == 21:
			var cond_node = _create_node_for_command(cmd) as BranchNodes.ConditionGraphNode
			graph_edit.add_child(cond_node)
			current_node = cond_node
			
			var base_indent = cmd.indent
			i += 1
			
			# Parse True branch until Code 22 (Else) or Code 23 (End)
			var true_res = _parse_block(commands, i, [22, 23], base_indent)
			i = true_res.next_idx
			if true_res.first_node:
				graph_edit.connect_node(cond_node.name, 0, true_res.first_node.name, 0)
				
			# False branch (Else 22)
			if i < commands.size() and commands[i].code == 22 and commands[i].indent == base_indent:
				cond_node.has_else_branch = true
				cond_node.command.parameters["else_branch"] = true
				cond_node._build_ui()
				cond_node.update_visuals()
				i += 1
				var false_res = _parse_block(commands, i, [23], base_indent)
				i = false_res.next_idx
				if false_res.first_node:
					graph_edit.connect_node(cond_node.name, 1, false_res.first_node.name, 0)
					
			# End (23)
			if i < commands.size() and commands[i].code == 23 and commands[i].indent == base_indent:
				i += 1
				
			next_out_node = cond_node
			next_out_port = 2 if cond_node.has_else_branch else 1 # Continue / Merge
			
		# Show Choices (4)
		elif cmd.code == 4:
			var choice_node = _create_node_for_command(cmd) as BranchNodes.ChoiceGraphNode
			graph_edit.add_child(choice_node)
			current_node = choice_node
			
			var base_indent = cmd.indent
			var choice_idx = 0
			var sub_cmds: Array[RPGEventCommand] = []
			i += 1
			
			# Parse each Choice (Code 5)
			while i < commands.size() and commands[i].code == 5 and commands[i].indent == base_indent:
				var when_cmd = commands[i]
				sub_cmds.append(when_cmd)
				var this_slot = choice_idx
				choice_idx += 1
				i += 1
				var opt_res = _parse_block(commands, i, [5, 6, 7], base_indent)
				i = opt_res.next_idx
				if opt_res.first_node:
					graph_edit.connect_node(choice_node.name, this_slot, opt_res.first_node.name, 0)
					
			# Cancel (Code 6)
			var cancel_slot = choice_idx
			if i < commands.size() and commands[i].code == 6 and commands[i].indent == base_indent:
				sub_cmds.append(commands[i])
				i += 1
				var cancel_res = _parse_block(commands, i, [7], base_indent)
				i = cancel_res.next_idx
				if cancel_res.first_node:
					graph_edit.connect_node(choice_node.name, cancel_slot, cancel_res.first_node.name, 0)
					
			# End Choices (Code 7)
			if i < commands.size() and commands[i].code == 7 and commands[i].indent == base_indent:
				sub_cmds.append(commands[i])
				i += 1
				
			choice_node.setup(cmd, sub_cmds)
			next_out_node = choice_node
			next_out_port = choice_node.choice_labels.size() + 1 # Continue / Merge
			
		# Loop (24)
		elif cmd.code == 24:
			var loop_node = _create_node_for_command(cmd) as BranchNodes.LoopGraphNode
			graph_edit.add_child(loop_node)
			current_node = loop_node
			
			var base_indent = cmd.indent
			i += 1
			var body_res = _parse_block(commands, i, [25], base_indent)
			i = body_res.next_idx
			if body_res.first_node:
				graph_edit.connect_node(loop_node.name, 0, body_res.first_node.name, 0)
				
			if i < commands.size() and commands[i].code == 25 and commands[i].indent == base_indent:
				i += 1
				
			next_out_node = loop_node
			next_out_port = 1 # Exit
			
		# Battle (500)
		elif cmd.code == 500:
			var battle_node = _create_node_for_command(cmd) as BranchNodes.BattleGraphNode
			graph_edit.add_child(battle_node)
			current_node = battle_node
			var base_indent = cmd.indent
			i += 1
			
			# Win (501)
			if i < commands.size() and commands[i].code == 501 and commands[i].indent == base_indent:
				i += 1
				var win_res = _parse_block(commands, i, [502, 503, 504], base_indent)
				i = win_res.next_idx
				if win_res.first_node:
					graph_edit.connect_node(battle_node.name, 0, win_res.first_node.name, 0)
			# Escape (502)
			if i < commands.size() and commands[i].code == 502 and commands[i].indent == base_indent:
				i += 1
				var esc_res = _parse_block(commands, i, [503, 504], base_indent)
				i = esc_res.next_idx
				if esc_res.first_node:
					graph_edit.connect_node(battle_node.name, 1, esc_res.first_node.name, 0)
			# Defeat (503)
			if i < commands.size() and commands[i].code == 503 and commands[i].indent == base_indent:
				i += 1
				var def_res = _parse_block(commands, i, [504], base_indent)
				i = def_res.next_idx
				if def_res.first_node:
					graph_edit.connect_node(battle_node.name, 2, def_res.first_node.name, 0)
			if i < commands.size() and commands[i].code == 504 and commands[i].indent == base_indent:
				i += 1
				
			next_out_node = battle_node
			next_out_port = 3 # Continue
			
		else:
			# Multi-line commands & commands with subsidiary sub-commands:
			# Text (2->3), Scroll (10->11), Comment (31->32), Instant Text (34->35),
			# Profile (50->51), Movement Route (57->58), Show Shop (96->97), Class Upgrade Shop (201->97)
			var sub_cmds: Array[RPGEventCommand] = []
			var next_code = -1
			if cmd.code == 2: next_code = 3
			elif cmd.code == 10: next_code = 11
			elif cmd.code == 31: next_code = 32
			elif cmd.code == 34: next_code = 35
			elif cmd.code == 50: next_code = 51
			elif cmd.code == 57: next_code = 58
			elif cmd.code in [96, 201]: next_code = 97
			
			if next_code != -1:
				while i + 1 < commands.size() and commands[i + 1].code == next_code:
					i += 1
					sub_cmds.append(commands[i])
			elif cmd.code in [3, 11, 32, 35, 51, 58, 97]:
				# Orphan sub-command without its parent, skip to avoid creating broken phantom nodes
				i += 1
				continue
					
			var std_node = _create_node_for_command(cmd, sub_cmds)
			graph_edit.add_child(std_node)
			current_node = std_node
			next_out_node = std_node
			next_out_port = 0
			i += 1
			
		if not first_node:
			first_node = current_node
			
		if prev_node:
			graph_edit.connect_node(prev_node.name, prev_port, current_node.name, 0)
			
		prev_node = next_out_node
		prev_port = next_out_port
		
	return {
		"next_idx": i,
		"first_node": first_node,
		"last_node": prev_node,
		"last_port": prev_port
	}

#endregion


#region Node Instantiation

func _create_node_for_command(cmd: RPGEventCommand, sub_cmds: Array[RPGEventCommand] = []) -> GraphNode:
	_node_counter += 1
	var node_name = "Node_%d" % _node_counter
	var node: GraphNode = null
	
	if cmd.code == 21: # Condition
		var cond_node = _instantiate_condition_node()
		cond_node.name = node_name
		cond_node.setup(cmd, sub_cmds)
		_hook_node_signals(cond_node)
		node = cond_node
	elif cmd.code == 4: # Choices
		var choice_node = _instantiate_choice_node()
		choice_node.name = node_name
		if sub_cmds.is_empty():
			sub_cmds = [
				RPGEventCommand.new(5, 0, {"name": "Option 1"}),
				RPGEventCommand.new(5, 0, {"name": "Option 2"}),
				RPGEventCommand.new(7, 0, {})
			]
		choice_node.setup(cmd, sub_cmds)
		_hook_node_signals(choice_node)
		node = choice_node
	elif cmd.code == 24: # Loop
		var loop_node = _instantiate_loop_node()
		loop_node.name = node_name
		loop_node.setup(cmd, sub_cmds)
		_hook_node_signals(loop_node)
		node = loop_node
	elif cmd.code == 500: # Battle
		var battle_node = _instantiate_battle_node()
		battle_node.name = node_name
		battle_node.setup(cmd, sub_cmds)
		_hook_node_signals(battle_node)
		node = battle_node
	else:
		var std_node = _instantiate_command_node()
		std_node.name = node_name
		if cmd.code == 2 and sub_cmds.is_empty():
			sub_cmds = [RPGEventCommand.new(3, 0, {"line": ""})]
		std_node.setup(cmd, sub_cmds)
		_hook_node_signals(std_node)
		node = std_node
		
	var nodes_cfg = _current_page_cfg.get("nodes", {})
	if node and node_name in nodes_cfg:
		var n_cfg = nodes_cfg[node_name]
		if n_cfg.has("pos"):
			var p = n_cfg["pos"]
			if p is Array and p.size() >= 2:
				node.position_offset = Vector2(float(p[0]), float(p[1]))
		if n_cfg.has("collapsed") and node.has_method("set_collapsed"):
			node.set_collapsed(bool(n_cfg["collapsed"]), false)
	elif node and cmd.parameters.has("_graph_pos"):
		var p_pos = cmd.parameters["_graph_pos"]
		if p_pos is Array and p_pos.size() >= 2:
			node.position_offset = Vector2(float(p_pos[0]), float(p_pos[1]))
			
	return node


func _hook_node_signals(node: GraphNode) -> void:
	_ensure_popup_font_sizes(node)
	if node.has_signal("request_delete"):
		node.request_delete.connect(func(n):
			_push_undo_state()
			_delete_single_node(n)
		)
	if node.has_signal("request_edit_dialog"):
		node.request_edit_dialog.connect(func(n):
			call_deferred("_open_native_dialog", n)
		)
	if node.has_signal("collapse_changed"):
		node.collapse_changed.connect(func(_n, _c):
			_push_undo_state()
		)
	if node.has_signal("command_modified"):
		node.command_modified.connect(func(_n):
			_push_undo_state()
		)
	if node.has_signal("dragged"):
		node.dragged.connect(func(from: Vector2, to: Vector2):
			_on_node_drag_completed(node, from, to)
			if not _pre_drag_state.is_empty():
				_undo_stack.append(_pre_drag_state)
				if _undo_stack.size() > 50:
					_undo_stack.pop_front()
				_redo_stack.clear()
				_pre_drag_state = {}
				_update_undo_redo_buttons()
		)
	node.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			if event.is_pressed():
				if event.double_click:
					node.accept_event()
					_pre_drag_state = {}
					call_deferred("_open_native_dialog", node)
				else:
					_pre_drag_state = _serialize_graph_state()
	)

#endregion


#region Graph Compiling (Graph -> List)

func compile_graph_to_commands() -> Array[RPGEventCommand]:
	var result: Array[RPGEventCommand] = []
	var visited: Dictionary = {}
	
	if not start_node:
		return result
		
	_prune_duplicate_connections()
	_traverse_and_compile(start_node, 0, 0, result, visited)
	
	# Always ensure trailing command 0 at root indent 0
	_ensure_trailing_command_0(result, 0)
		
	return result


func _prune_duplicate_connections() -> void:
	var conns = graph_edit.get_connection_list()
	var seen_outputs: Dictionary = {}
	var seen_inputs: Dictionary = {}
	for c in conns:
		var c_from = c.get("from_node", &"")
		var c_fport = c.get("from_port", 0)
		var c_to = c.get("to_node", &"")
		var c_tport = c.get("to_port", 0)
		var out_key = "%s:%d" % [c_from, c_fport]
		var in_key = "%s:%d" % [c_to, c_tport]
		if out_key in seen_outputs or in_key in seen_inputs:
			graph_edit.disconnect_node(c_from, c_fport, c_to, c_tport)
		else:
			seen_outputs[out_key] = true
			seen_inputs[in_key] = true


func _ensure_trailing_command_0(cmd_list: Array[RPGEventCommand], expected_indent: int) -> void:
	if cmd_list.is_empty() or cmd_list[-1].code != 0:
		var cmd0 = RPGEventCommand.new()
		cmd0.code = 0
		cmd0.indent = expected_indent
		cmd0.parameters = {}
		cmd_list.append(cmd0)
	else:
		cmd_list[-1].indent = expected_indent


func _traverse_and_compile(node: GraphNode, from_port: int, current_indent: int, out_list: Array[RPGEventCommand], visited: Dictionary) -> void:
	if not node:
		return
		
	var node_key = "%s_%d" % [node.name, from_port]
	if node_key in visited:
		return # Avoid infinite loops
	visited[node_key] = true
	
	# 1. Process Current Node
	if node is BranchNodes.StartGraphNode:
		var next_target = _get_connected_target(node.name, 0)
		if next_target.node:
			_traverse_and_compile(next_target.node, next_target.port, current_indent, out_list, visited)
		return
		
	elif node is BranchNodes.ConditionGraphNode:
		var conds = node.conditions if ("conditions" in node and not node.conditions.is_empty()) else [node.command.parameters.duplicate()]
		var num_conds = conds.size()
		var false_target = _get_connected_target(node.name, 1)
		
		for k in range(num_conds):
			var cond_p = conds[k].duplicate()
			cond_p["else_branch"] = (k == 0 and (false_target.node != null or node.has_else_branch))
			var c = RPGEventCommand.new(21, current_indent + k, cond_p)
			out_list.append(c)
		
		# Slot 0: True branch (executed if all conditions pass)
		var true_target = _get_connected_target(node.name, 0)
		if true_target.node:
			_traverse_and_compile(true_target.node, true_target.port, current_indent + num_conds, out_list, visited)
		_ensure_trailing_command_0(out_list, current_indent + num_conds)
		
		# Close inner condition branches (from num_conds - 1 down to 1)
		for k in range(num_conds - 1, 0, -1):
			out_list.append(RPGEventCommand.new(23, current_indent + k, {}))
			
		# Slot 1: False branch (Else) on the root condition
		if false_target.node or node.has_else_branch:
			out_list.append(RPGEventCommand.new(22, current_indent, {})) # Code 22 = Else
			if false_target.node:
				_traverse_and_compile(false_target.node, false_target.port, current_indent + 1, out_list, visited)
			_ensure_trailing_command_0(out_list, current_indent + 1)
			
		out_list.append(RPGEventCommand.new(23, current_indent, {})) # Code 23 = Branch End
		
		# Slot 2 (or 1 if no else): Continue / Merge
		var cont_port = 2 if (false_target.node != null or node.has_else_branch) else 1
		var cont_target = _get_connected_target(node.name, cont_port)
		if cont_target.node:
			_traverse_and_compile(cont_target.node, cont_target.port, current_indent, out_list, visited)
		return
		
	elif node is BranchNodes.ChoiceGraphNode:
		var cmd = node.command.clone()
		cmd.indent = current_indent
		out_list.append(cmd)
		
		for i in range(node.choice_labels.size()):
			var when_cmd = RPGEventCommand.new(5, current_indent, {"name": node.choice_labels[i]})
			out_list.append(when_cmd)
			var opt_target = _get_connected_target(node.name, i)
			if opt_target.node:
				_traverse_and_compile(opt_target.node, opt_target.port, current_indent + 1, out_list, visited)
			_ensure_trailing_command_0(out_list, current_indent + 1)
				
		var cancel_slot = node.choice_labels.size()
		var cancel_target = _get_connected_target(node.name, cancel_slot)
		if cancel_target.node:
			out_list.append(RPGEventCommand.new(6, current_indent, {})) # Code 6 = When Cancel
			_traverse_and_compile(cancel_target.node, cancel_target.port, current_indent + 1, out_list, visited)
			_ensure_trailing_command_0(out_list, current_indent + 1)
			
		out_list.append(RPGEventCommand.new(7, current_indent, {})) # Code 7 = End Choices
		
		var merge_slot = cancel_slot + 1
		var merge_target = _get_connected_target(node.name, merge_slot)
		if merge_target.node:
			_traverse_and_compile(merge_target.node, merge_target.port, current_indent, out_list, visited)
		return
		
	elif node is BranchNodes.LoopGraphNode:
		var cmd = node.command.clone()
		cmd.indent = current_indent
		out_list.append(cmd)
		
		# Slot 0: Body
		var body_target = _get_connected_target(node.name, 0)
		if body_target.node:
			_traverse_and_compile(body_target.node, body_target.port, current_indent + 1, out_list, visited)
		_ensure_trailing_command_0(out_list, current_indent + 1)
			
		out_list.append(RPGEventCommand.new(25, current_indent, {})) # Code 25 = Repeat Above
		
		# Slot 1: Break / Exit
		var exit_target = _get_connected_target(node.name, 1)
		if exit_target.node:
			_traverse_and_compile(exit_target.node, exit_target.port, current_indent, out_list, visited)
		return
		
	elif node is BranchNodes.BattleGraphNode:
		var cmd = node.command.clone()
		cmd.indent = current_indent
		out_list.append(cmd)
		
		# Slot 0: Win
		var win_target = _get_connected_target(node.name, 0)
		if win_target.node:
			out_list.append(RPGEventCommand.new(501, current_indent, {}))
			_traverse_and_compile(win_target.node, win_target.port, current_indent + 1, out_list, visited)
			_ensure_trailing_command_0(out_list, current_indent + 1)
			
		# Slot 1: Escape
		var esc_target = _get_connected_target(node.name, 1)
		if esc_target.node:
			out_list.append(RPGEventCommand.new(502, current_indent, {}))
			_traverse_and_compile(esc_target.node, esc_target.port, current_indent + 1, out_list, visited)
			_ensure_trailing_command_0(out_list, current_indent + 1)
			
		# Slot 2: Lose
		var def_target = _get_connected_target(node.name, 2)
		if def_target.node:
			out_list.append(RPGEventCommand.new(503, current_indent, {}))
			_traverse_and_compile(def_target.node, def_target.port, current_indent + 1, out_list, visited)
			_ensure_trailing_command_0(out_list, current_indent + 1)
			
		out_list.append(RPGEventCommand.new(504, current_indent, {}))
		
		# Slot 3: Continue
		var cont_target = _get_connected_target(node.name, 3)
		if cont_target.node:
			_traverse_and_compile(cont_target.node, cont_target.port, current_indent, out_list, visited)
		return
		
	elif node is CommandGraphNode:
		var cmd = node.command.clone()
		cmd.indent = current_indent
		out_list.append(cmd)
		
		for sub in node.sub_commands:
			var sc = sub.clone()
			sc.indent = current_indent
			out_list.append(sc)
			
		var next_target = _get_connected_target(node.name, 0)
		if next_target.node:
			_traverse_and_compile(next_target.node, next_target.port, current_indent, out_list, visited)
		return


func _get_connected_target(from_node: StringName, from_port: int) -> Dictionary:
	var conns = graph_edit.get_connection_list()
	for c in conns:
		var c_from = c.get("from_node", &"")
		var c_fport = c.get("from_port", 0)
		if c_from == from_node and c_fport == from_port:
			var target = graph_edit.get_node_or_null(str(c.get("to_node", "")))
			if target and target is GraphNode:
				return {"node": target, "port": c.get("to_port", 0)}
	return {"node": null, "port": 0}

#endregion


#region Auto Layout

func auto_layout() -> void:
	if not start_node:
		return
	if not _is_restoring_state and not _undo_stack.is_empty():
		_push_undo_state()
		
	var col_x: float = 60.0
	var col_spacing: float = 350.0
	var row_spacing: float = 190.0
	
	var levels: Dictionary = {} # node -> int column
	var visited: Dictionary = {}
	
	# BFS to determine column depth
	var queue: Array = [{"node": start_node, "level": 0}]
	levels[start_node] = 0
	
	while not queue.is_empty():
		var curr = queue.pop_front()
		var n: GraphNode = curr.node
		var lvl: int = curr.level
		
		var conns = graph_edit.get_connection_list()
		for c in conns:
			if c.from_node == n.name:
				var to_n = graph_edit.get_node_or_null(str(c.to_node))
				if to_n and to_n is GraphNode:
					if not to_n in levels or levels[to_n] < lvl + 1:
						levels[to_n] = lvl + 1
						queue.append({"node": to_n, "level": lvl + 1})
						
	# Group nodes by level
	var by_level: Dictionary = {}
	for n in levels:
		var lvl = levels[n]
		if not lvl in by_level:
			by_level[lvl] = []
		by_level[lvl].append(n)
		
	# Place any unreached / floating nodes in extra columns
	var all_nodes = []
	for child in graph_edit.get_children():
		if child is GraphNode:
			all_nodes.append(child)
			
	var max_lvl = 0
	for lvl in by_level.keys():
		if lvl > max_lvl: max_lvl = lvl
		
	var unreached = []
	for n in all_nodes:
		if not n in levels:
			unreached.append(n)
			
	if not unreached.is_empty():
		by_level[max_lvl + 1] = unreached
		
	# Position nodes neatly
	for lvl in by_level:
		var list = by_level[lvl]
		var total_height = 0.0
		for n in list:
			total_height += max(n.size.y, 80.0) + 30.0
			
		var start_y = max(80.0, 300.0 - (total_height / 2.0))
		var current_y = start_y
		for idx in range(list.size()):
			var node: GraphNode = list[idx]
			node.position_offset = Vector2(col_x + lvl * col_spacing, current_y)
			current_y += max(node.size.y, 80.0) + 30.0

#endregion


#region Signals & Connections

func _on_connection_request(from_node: StringName, from_port: int, to_node: StringName, to_port: int) -> void:
	# Avoid connecting to self
	if from_node == to_node:
		return
		
	var fn = graph_edit.get_node_or_null(NodePath(from_node)) as GraphNode
	var tn = graph_edit.get_node_or_null(NodePath(to_node)) as GraphNode
	if not fn or not tn:
		return
	if from_port >= fn.get_output_port_count() or to_port >= tn.get_input_port_count():
		return
		
	_push_undo_state()
	
	# Enforce single-wire execution flow:
	# 1. An output port (from_node, from_port) can only connect to ONE target node.
	# 2. An input port (to_node, to_port) can only receive ONE incoming connection.
	var conns = graph_edit.get_connection_list()
	for c in conns:
		var c_from = c.get("from_node", &"")
		var c_fport = c.get("from_port", 0)
		var c_to = c.get("to_node", &"")
		var c_tport = c.get("to_port", 0)
		if (c_from == from_node and c_fport == from_port) or (c_to == to_node and c_tport == to_port):
			graph_edit.disconnect_node(c_from, c_fport, c_to, c_tport)
			
	graph_edit.connect_node(from_node, from_port, to_node, to_port)


func _on_disconnection_request(from_node: StringName, from_port: int, to_node: StringName, to_port: int) -> void:
	_push_undo_state()
	graph_edit.disconnect_node(from_node, from_port, to_node, to_port)


func _on_delete_nodes_request(nodes: Array[StringName]) -> void:
	_push_undo_state()
	for node_name in nodes:
		var node = graph_edit.get_node_or_null(str(node_name))
		if node and node != start_node:
			_delete_single_node(node)


func _delete_single_node(node: GraphNode) -> void:
	if node == start_node:
		return
	if node is ContainerGraphNode:
		_containers.erase(node)
	elif node is ReminderGraphNode:
		_reminders.erase(node)
	else:
		for c in _containers:
			if is_instance_valid(c):
				if c.member_node_names.has(node.name):
					c.remove_member(node.name)
					c.recalculate_bounds()
	# Remove connections
	var conns = graph_edit.get_connection_list()
	for c in conns:
		if c.from_node == node.name or c.to_node == node.name:
			graph_edit.disconnect_node(c.from_node, c.from_port, c.to_node, c.to_port)
	node.queue_free()


func _on_search_popup_closed() -> void:
	_pending_connect_from = ""
	_pending_connect_port = 0
	_pending_connect_to = ""
	_pending_connect_to_port = 0


func _on_popup_request(at_position: Vector2) -> void:
	_pending_connect_from = ""
	_pending_connect_port = 0
	_pending_connect_to = ""
	_pending_connect_to_port = 0
	var graph_pos = (at_position + graph_edit.scroll_offset) / graph_edit.zoom
	var screen_pos = get_window().position + Vector2i(graph_edit.get_global_mouse_position())
	search_popup.popup_at_position(screen_pos, graph_pos)


func _on_connection_to_empty(from_node: StringName, from_port: int, release_position: Vector2) -> void:
	_pending_connect_from = from_node
	_pending_connect_port = from_port
	_pending_connect_to = ""
	_pending_connect_to_port = 0
	var graph_pos = (release_position + graph_edit.scroll_offset) / graph_edit.zoom
	var screen_pos = get_window().position + Vector2i(graph_edit.get_global_mouse_position())
	search_popup.popup_at_position(screen_pos, graph_pos)


func _on_connection_from_empty(to_node: StringName, to_port: int, release_position: Vector2) -> void:
	_pending_connect_from = ""
	_pending_connect_port = 0
	_pending_connect_to = to_node
	_pending_connect_to_port = to_port
	var graph_pos = (release_position + graph_edit.scroll_offset) / graph_edit.zoom
	var screen_pos = get_window().position + Vector2i(graph_edit.get_global_mouse_position())
	search_popup.popup_at_position(screen_pos, graph_pos)


func _on_add_command_toolbar_pressed() -> void:
	_pending_connect_from = ""
	_pending_connect_port = 0
	_pending_connect_to = ""
	_pending_connect_to_port = 0
	var center_graph = (graph_edit.size / 2.0 + graph_edit.scroll_offset) / graph_edit.zoom
	var screen_pos = get_window().position + Vector2i(get_window().size / 2) - Vector2i(170, 240)
	search_popup.popup_at_position(screen_pos, center_graph)


func _on_edit_popup_about_to_show() -> void:
	_update_edit_menu_state()


func _update_edit_menu_state() -> void:
	if not edit_menu_button:
		return
	var popup: PopupMenu = edit_menu_button.get_popup()
	if not popup:
		return
		
	var has_selection: bool = false
	var has_container_selected: bool = false
	if graph_edit:
		for child in graph_edit.get_children():
			if child is GraphNode and child.selected and child != start_node:
				has_selection = true
				if child is ContainerGraphNode:
					has_container_selected = true
					
	var idx: int
	idx = popup.get_item_index(EditMenuId.UNDO)
	if idx >= 0:
		popup.set_item_disabled(idx, _undo_stack.is_empty())
		
	idx = popup.get_item_index(EditMenuId.REDO)
	if idx >= 0:
		popup.set_item_disabled(idx, _redo_stack.is_empty())
		
	idx = popup.get_item_index(EditMenuId.CUT)
	if idx >= 0:
		popup.set_item_disabled(idx, not has_selection)
		
	idx = popup.get_item_index(EditMenuId.COPY)
	if idx >= 0:
		popup.set_item_disabled(idx, not has_selection)
		
	idx = popup.get_item_index(EditMenuId.PASTE)
	if idx >= 0:
		popup.set_item_disabled(idx, _clipboard_data.is_empty() or not _clipboard_data.has("nodes"))
		
	idx = popup.get_item_index(EditMenuId.DUPLICATE)
	if idx >= 0:
		popup.set_item_disabled(idx, not has_selection)
		
	idx = popup.get_item_index(EditMenuId.GROUP_CONTAINER)
	if idx >= 0:
		popup.set_item_disabled(idx, not has_selection)
		
	idx = popup.get_item_index(EditMenuId.UNGROUP_CONTAINER)
	if idx >= 0:
		popup.set_item_disabled(idx, not has_container_selected)


func _on_edit_menu_id_pressed(id: int) -> void:
	match id:
		EditMenuId.UNDO:
			undo()
		EditMenuId.REDO:
			redo()
		EditMenuId.CUT:
			cut_selected()
		EditMenuId.COPY:
			copy_selected()
		EditMenuId.PASTE:
			paste()
		EditMenuId.DUPLICATE:
			duplicate_selected()
		EditMenuId.ADD_COMMAND:
			_on_add_command_toolbar_pressed()
		EditMenuId.GROUP_CONTAINER:
			group_selected_into_container()
		EditMenuId.UNGROUP_CONTAINER:
			ungroup_selected_container()
		EditMenuId.ADD_NOTE:
			add_reminder_node()
		EditMenuId.AUTO_LAYOUT:
			auto_layout()
		EditMenuId.CLEAR_WIRES:
			_push_undo_state()
			graph_edit.clear_connections()


func _on_command_selected_from_popup(code: int, button_id: int, spawn_pos: Vector2) -> void:
	_push_undo_state()
	var default_params = _get_default_parameters_for_code(code)
	if code == 53:
		if button_id == 41:
			default_params["target"] = 1
		elif button_id == 42:
			default_params["target"] = 2
		else:
			default_params["target"] = 0
	var new_cmd = RPGEventCommand.new(code, 0, default_params)
	var sub_cmds: Array[RPGEventCommand] = []
	if code == 2:
		sub_cmds.append(RPGEventCommand.new(3, 0, {"line": ""}))
	elif code == 10:
		sub_cmds.append(RPGEventCommand.new(11, 0, {"line": ""}))
	elif code == 31:
		sub_cmds.append(RPGEventCommand.new(32, 0, {"line": ""}))
	elif code == 34:
		sub_cmds.append(RPGEventCommand.new(35, 0, {"line": ""}))
	elif code == 50:
		sub_cmds.append(RPGEventCommand.new(51, 0, {"line": ""}))
		
	var new_node = _create_node_for_command(new_cmd, sub_cmds)
	if new_node:
		new_node.position_offset = spawn_pos
		graph_edit.add_child(new_node)
		
		# Auto connect if spawned from dragging wire to empty space
		if not _pending_connect_from.is_empty():
			# Disconnect any existing connection from this output port (single wire out)
			var conns = graph_edit.get_connection_list()
			for c in conns:
				var c_from = c.get("from_node", &"")
				var c_fport = c.get("from_port", 0)
				if c_from == _pending_connect_from and c_fport == _pending_connect_port:
					graph_edit.disconnect_node(c_from, c_fport, c.get("to_node", &""), c.get("to_port", 0))
					
			graph_edit.connect_node(_pending_connect_from, _pending_connect_port, new_node.name, 0)
			_pending_connect_from = ""
			_pending_connect_port = 0
		elif not _pending_connect_to.is_empty():
			# Disconnect any existing connection to this input port (single wire in)
			var conns = graph_edit.get_connection_list()
			for c in conns:
				var c_to = c.get("to_node", &"")
				var c_tport = c.get("to_port", 0)
				if c_to == _pending_connect_to and c_tport == _pending_connect_to_port:
					graph_edit.disconnect_node(c.get("from_node", &""), c.get("from_port", 0), c_to, c_tport)
					
			graph_edit.connect_node(new_node.name, 0, _pending_connect_to, _pending_connect_to_port)
			_pending_connect_to = ""
			_pending_connect_to_port = 0

#endregion


#region Dialogs & Helpers

func _open_native_dialog(node: GraphNode) -> void:
	if not node or not "command" in node or not node.command:
		return
	if _active_dialog and is_instance_valid(_active_dialog):
		_active_dialog.grab_focus()
		return
	var code = node.command.code
	var info = GraphCommandData.get_info_for_code(code)
	var dialog_name = info.get("dialog", "")
	if dialog_name.is_empty():
		return
		
	var path = "res://addons/CustomControls/Dialogs/CommandEvents/%s.tscn" % dialog_name
	if not ResourceLoader.exists(path):
		var alt_path = "res://addons/CustomControls/Dialogs/%s.tscn" % dialog_name
		if ResourceLoader.exists(alt_path):
			path = alt_path
		
	if not ResourceLoader.exists(path):
		printerr("EventGraphEditor: Dialog does not exist at ", path)
		return
		
	var dialog: Window = null
	var dialog_mgr = get_node_or_null("/root/RPGDialogFunctions")
	if dialog_mgr and dialog_mgr.has_method("open_dialog"):
		dialog = dialog_mgr.open_dialog(path, 1) # 1 = CENTERED_ON_MOUSE
	else:
		var scn = load(path)
		if scn:
			dialog = scn.instantiate()
			if get_tree() and get_tree().root:
				get_tree().root.add_child(dialog)
			else:
				add_child(dialog)
			dialog.popup_centered()
			
	if not dialog:
		return
		
	_active_dialog = dialog
	var on_dialog_closed = func():
		if _active_dialog == dialog:
			_active_dialog = null
	dialog.tree_exited.connect(on_dialog_closed)
		
	var params_to_send: Array[RPGEventCommand] = [node.command]
	if "sub_commands" in node and not node.sub_commands.is_empty():
		params_to_send.append_array(node.sub_commands)
		
	if code == 2:
		var sys = get_node_or_null("/root/RPGSYSTEM")
		if sys and "editor_interface" in sys and sys.editor_interface:
			var edited_scene = sys.editor_interface.get_edited_scene_root()
			if edited_scene and "events" in edited_scene and edited_scene.events.has_method("get_events"):
				dialog.set_events(edited_scene.events.get_events())
	elif code == 10:
		if dialog.has_method("set_scroll_mode_dialog"):
			dialog.set_scroll_mode_dialog()
	elif code == 34:
		if dialog.has_method("set_instant_text_mode_dialog"):
			dialog.set_instant_text_mode_dialog()
	elif code == 53:
		var sys = get_node_or_null("/root/RPGSYSTEM")
		if sys and "editor_interface" in sys and sys.editor_interface:
			var edited_scene = sys.editor_interface.get_edited_scene_root()
			if edited_scene and edited_scene is RPGMap:
				if "current_map_id" in dialog:
					dialog.current_map_id = edited_scene.internal_id
				if "events" in edited_scene and edited_scene.events.has_method("get_events"):
					if dialog.has_method("set_events"):
						dialog.set_events(edited_scene.events.get_events())
						var cur_evt = edited_scene.get("current_event")
						if cur_evt and "title" in dialog:
							dialog.title += ": %s: %s" % [cur_evt.id, cur_evt.name]
		var tgt_mode = node.command.parameters.get("target", 0)
		if tgt_mode == 0 and dialog.has_method("set_player_transfer_mode"):
			dialog.set_player_transfer_mode()
		elif tgt_mode == 1 and dialog.has_method("set_vehicle_transfer_mode"):
			dialog.set_vehicle_transfer_mode()
		elif tgt_mode == 2 and dialog.has_method("set_event_transfer_mode"):
			dialog.set_event_transfer_mode()
	elif code == 57:
		var movement_route = RPGMovementRoute.new()
		movement_route.target = node.command.parameters.get("target", 0)
		movement_route.repeat = node.command.parameters.get("loop", true)
		movement_route.skippable = node.command.parameters.get("skippable", false)
		movement_route.wait = node.command.parameters.get("wait", false)
		if "sub_commands" in node:
			for sub in node.sub_commands:
				if sub.code == 58:
					var m_cmd = sub.parameters.get("movement_command", RPGMovementCommand.new())
					movement_route.list.append(m_cmd)
		var cur_page: RPGEventPage = RPGEventPage.new()
		cur_page.movement_route = movement_route.clone(true)
		if dialog.has_method("set_current_page"):
			dialog.set_current_page(cur_page)
		var sys = get_node_or_null("/root/RPGSYSTEM")
		if sys and "editor_interface" in sys and sys.editor_interface:
			var edited_scene = sys.editor_interface.get_edited_scene_root()
			if edited_scene and edited_scene is RPGMap:
				if "current_event" in dialog:
					dialog.current_event = edited_scene.current_event
				if "events" in edited_scene and edited_scene.events.has_method("get_events"):
					if dialog.has_method("set_targets"):
						dialog.set_targets(edited_scene.events.get_events())
		if dialog.has_signal("apply"):
			dialog.apply.connect(func(new_route: RPGMovementRoute):
				_push_undo_state()
				node.command.parameters.target = new_route.target
				node.command.parameters.loop = new_route.repeat
				node.command.parameters.skippable = new_route.skippable
				node.command.parameters.wait = new_route.wait
				var new_subs: Array[RPGEventCommand] = []
				for step in new_route.list:
					var sc = RPGEventCommand.new()
					sc.code = 58
					sc.indent = node.command.indent
					sc.parameters.movement_command = step
					new_subs.append(sc)
				node.sub_commands = new_subs
				if node.has_method("setup"):
					node.setup(node.command, node.sub_commands)
				elif node.has_method("update_visuals"):
					node.update_visuals()
				_ensure_popup_font_sizes(node)
			)
	
	if "parameter_code" in dialog:
		dialog.parameter_code = code
		
	if dialog.has_method("set_parameters"):
		dialog.set_parameters(params_to_send)
		
	if dialog.has_signal("command_changed"):
		dialog.command_changed.connect(func(new_commands: Array[RPGEventCommand]):
			if new_commands.is_empty():
				return
			_push_undo_state()
				
			var target_code = node.command.code
			var main_cmd: RPGEventCommand = null
			
			# Locate the main command matching node's code
			for c in new_commands:
				if c.code == target_code:
					main_cmd = c
					break
			if not main_cmd:
				# Fallback for dialogs where the main command is at the end or start
				main_cmd = new_commands[-1] if target_code in [2, 4, 10, 21, 31, 34, 50, 96, 201] else new_commands[0]
				
			var subs: Array[RPGEventCommand] = []
			if target_code in [2, 10, 31, 34, 50, 96, 201]:
				for c in new_commands:
					if c != main_cmd:
						subs.append(c)
				subs.reverse()
			elif target_code == 4:
				var when_cmds: Array[RPGEventCommand] = []
				var other_cmds: Array[RPGEventCommand] = []
				for c in new_commands:
					if c.code == 5:
						when_cmds.append(c)
					elif c != main_cmd:
						other_cmds.append(c)
				when_cmds.reverse()
				subs.append_array(when_cmds)
				subs.append_array(other_cmds)
			else:
				for c in new_commands:
					if c != main_cmd:
						subs.append(c)
						
			if node is BranchNodes.ChoiceGraphNode:
				_refresh_choice_node(node, main_cmd, subs)
			else:
				node.command = main_cmd
				if "sub_commands" in node:
					node.sub_commands = subs
				if node is BranchNodes.ConditionGraphNode:
					var has_else = false
					for c in new_commands:
						if c.code == 22:
							has_else = true
							break
					node.has_else_branch = has_else
				if node.has_method("setup") and node is CommandGraphNode:
					node.setup(node.command, node.sub_commands)
				elif node.has_method("update_visuals"):
					node.update_visuals()
				_ensure_popup_font_sizes(node)
		)


func _refresh_choice_node(node: BranchNodes.ChoiceGraphNode, new_command: RPGEventCommand, new_subs: Array[RPGEventCommand]) -> void:
	var old_choice_count = node.choice_labels.size()
	
	# Save outgoing connections
	var old_conns = []
	for c in graph_edit.get_connection_list():
		if c.from_node == node.name:
			old_conns.append(c)
			graph_edit.disconnect_node(c.from_node, c.from_port, c.to_node, c.to_port)
			
	node.command = new_command
	node.sub_commands = new_subs
	node.update_visuals()
	
	var new_choice_count = node.choice_labels.size()
	
	# Remap connections to the updated ports
	for c in old_conns:
		var p = c.from_port
		var new_p = p
		if p < old_choice_count:
			if p < new_choice_count:
				new_p = p
			else:
				continue # this choice was deleted
		elif p == old_choice_count:
			new_p = new_choice_count # cancel
		elif p == old_choice_count + 1:
			new_p = new_choice_count + 1 # continue / merge
			
		graph_edit.connect_node(node.name, new_p, c.to_node, c.to_port)


func _get_default_parameters_for_code(code: int) -> Dictionary:
	match code:
		1: return {
			"scene_path": "res://Scenes/DialogTemplates/dialog_scene_1.tscn",
			"text_box_position": 0,
			"text_box_margin_left": 0.0,
			"text_box_margin_right": 0.0,
			"text_box_margin_top": 0.0,
			"text_box_margin_bottom": 0.0,
			"font": "",
			"text_color": Color.WHITE,
			"text_size": 16.0,
			"outline_size": 0.0,
			"outline_color": Color.BLACK,
			"shadow_offset": Vector2.ZERO,
			"shadow_color": Color(0, 0, 0, 0.5),
			"text_align": 0,
			"max_width": 0.0,
			"max_lines": 4.0,
			"character_delay": 0.03,
			"dot_delay": 0.2,
			"comma_delay": 0.1,
			"paragraph_delay": 0.3,
			"skip_mode": 0,
			"skip_speed": 1.0,
			"start_animation": 0,
			"start_animation_duration": 0.3,
			"start_animation_trans_type": 0,
			"start_animation_ease_type": 0,
			"end_animation": 0,
			"end_animation_duration": 0.3,
			"end_animation_trans_type": 0,
			"end_animation_ease_type": 0,
			"text_transition": 0,
			"text_transition_parameters": {"length": 0.0, "fade_time": 0.3},
			"fx_path": "",
			"fx_volume": 0.0,
			"fx_pitch_min": 1.0,
			"fx_pitch_max": 1.0,
			"letter_by_letter_mode": 0
		}
		2: return {
			"character_name": {"type": 0, "value": ""},
			"face": RPGIcon.new(),
			"height": 0.0,
			"is_floating_dialog": false,
			"position": 0,
			"width": 0.0,
			"ignore_letter_by_letter": false,
			"no_wait_for_input": false
		}
		4: return {
			"scene_path": "res://Scenes/DialogTemplates/choice_scene_1.tscn",
			"max_choices": 6,
			"cancel": 0,
			"default": 0,
			"position": 0,
			"move_fx": {"path": "res://Assets/Sounds/SE/button_hover_se.wav", "volume": 0, "pitch": 1},
			"select_fx": {"path": "res://Assets/Sounds/SE/button_click_se.wav", "volume": 0, "pitch": 1},
			"cancel_fx": {"path": "res://Assets/Sounds/SE/button_cancel_se.wav", "volume": 0, "pitch": 1}
		}
		8: return {
			"type": 0,
			"variable_id": 1,
			"digits": 1,
			"position": 0,
			"use_message_bounds": false,
			"offset": Vector2.ZERO,
			"scene_path": "res://Scenes/DialogTemplates/select_digits_scene.tscn",
			"text_format": {},
			"move_fx": {},
			"select_fx": {},
			"remove_fx": {}
		}
		9: return {"variable_id": 1, "item_type": 1}
		10: return {
			"character_name": {"type": 0, "value": ""},
			"face": RPGIcon.new(),
			"height": 0.0,
			"is_floating_dialog": false,
			"position": 0,
			"width": 0.0
		}
		12: return {"operation_type": 0, "value_type": 0, "value": 1}
		13: return {"operation_type": 0, "value_type": 0, "value": 1, "item_id": 1}
		14, 15: return {"operation_type": 0, "value_type": 0, "value": 1, "item_id": 1, "include_equipment": false, "level": 1}
		16: return {"operation_type": 0, "actor_id": 1, "initialize": false}
		17: return {"from": 1, "to": 1, "operation_type": 0}
		18: return {"from": 1, "to": 1, "operation_type": 0, "operand_type": 0, "value1": 0}
		19: return {"event_id": 0, "operation_type": 0, "switch_id": 0}
		20: return {"operation_type": 0, "minutes": 0, "seconds": 30, "timer_id": 0, "timer_title": "", "timer_scene": "res://Scenes/TimerScenes/default_timer_scene.tscn"}
		21: return {"item_selected": 0, "value1": 1, "value2": 0, "value3": null, "value4": null, "value5": null, "value6": null, "else_branch": false}
		28: return {"id": 1}
		29, 30: return {"text": "Label"}
		31: return {"first_line": "Comment"}
		33: return {"duration": 1.0, "is_local": false}
		34: return {
			"character_name": {"type": 0, "value": ""},
			"face": RPGIcon.new(),
			"height": 0.0,
			"is_floating_dialog": false,
			"position": 0,
			"width": 0.0
		}
		36: return {"leader_id": 1, "is_locked": false}
		37, 38, 39, 42, 43, 44: return {"actor_type": 0, "actor_id": 0, "operand": 0, "operand_type": 0, "operand_value": 1, "show_level_up": false, "parameter_id": 1}
		40: return {"actor_type": 0, "actor_id": 0, "operand": 0, "state_id": 1}
		41: return {"actor_type": 0, "actor_id": 0}
		45: return {"actor_type": 0, "actor_id": 0, "operand": 0, "skill_id": 1}
		46: return {"actor_id": 1, "equipment_type_id": 0, "item_id": 0}
		47: return {"actor_id": 1, "name": ""}
		48: return {"actor_id": 1, "class_id": 1, "keep_level": false}
		49: return {"actor_id": 1, "nickname": ""}
		50: return {"actor_id": 1}
		52: return {"type": 0, "duration": 0.5}
		53: return {
			"target": 0,
			"type": 0,
			"direction": 0,
			"delay_transfer": false,
			"wait_animation": true,
			"value": {"assigned_map_id": 0, "assigned_x": 0, "assigned_y": 0, "event_id": 0},
			"transfer_animation": {"exit_animation": 0, "exit_time": 0.5, "entry_animation": 0, "entry_time": 0.5}
		}
		54: return {"type": 0, "direction": 0, "distance": 1, "speed": 1.0, "wait": true}
		57: return {"target": 0, "loop": true, "skippable": false, "wait": false}
		59: return {}
		60: return {"type": 0}
		61: return {"variable_id": 1, "operation_type": 0, "value_type": 0, "value": ""}
		62: return {"actor_id": 0, "type": 0, "trait": RPGTrait.new()}
		63, 64: return {"duration": 0.5}
		65, 66: return {"color": Color.WHITE, "duration": 0.5, "wait": false, "remove": false}
		67: return {"power": 4500, "duration": 0.5}
		68: return {"type": 0, "id": 1, "is_persistent": true, "scene": ""}
		69: return {"value": 1.0}
		70, 71: return {"value": true}
		72: return {"target": 0, "animation_id": 1, "wait": false}
		73: return {"target": 0, "balloon_id": 1, "wait": false}
		74: return {"target": 0, "action": 0}
		75: return {"id": 1, "path": "", "origin": 0, "position_type": 0, "x": 0, "y": 0, "scale_x": 100, "scale_y": 100, "opacity": 255, "blend_mode": 0}
		76: return {"id": 1, "duration": 0.5, "wait": false}
		77: return {"id": 1, "speed": 0}
		78: return {"id": 1, "scale_x": 100, "scale_y": 100, "duration": 0.5, "wait": false}
		79: return {"id": 1, "color": Color.WHITE, "duration": 0.5, "wait": false}
		80: return {"id": 1}
		81: return {"id": 1, "path": ""}
		82: return {"id": 1}
		83, 87: return {"path": "", "volume": 0.0, "pitch": 1.0, "fadein": 0.25}
		84, 88, 93: return {"duration": 0.0}
		89: return {"path": "", "volume": 0.0, "pitch": 1.0}
		90: return {"path": "", "volume": 0.0, "pitch": 1.0, "pitch2": 1.0}
		92: return {"path": ""}
		96, 201: return {
			"sales_mode": 0,
			"purchase_ratio": 100,
			"sales_ratio": 30,
			"shop_name": "SHOP" if code == 96 else "Class Upgrade Shop",
			"shop_scene": "res://Scenes/ShopScene/scene_shop_1.tscn",
			"shop_keeper": "res://Assets/Images/SceneShop/base_shopkeeper.png",
			"can_restock": true,
			"restock_timer": 300,
			"buy_list": []
		}
		98: return {"actor_id": 1, "max_characters": 8}
		103, 113, 114, 116, 210, 211: return {"value": true}
		104, 105: return {"path": ""}
		106: return {"variable_id": 1, "info_type": 0, "target_type": 0, "x": 0, "y": 0}
		110, 111, 112, 121: return {"path": "", "volume": 0.0, "pitch": 1.0}
		115: return {"value": 100.0}
		117: return {"value": 1.0}
		118, 119: return {"target_id": 1, "path": ""}
		120: return {"locale": "en"}
		123: return {"type": 0, "target_id": 0}
		124: return {"id": 1, "method": "", "args": []}
		125: return {"layer": 0, "coords": Vector2i.ZERO, "disabled": true}
		126: return {"quest_id": 1, "action": 0}
		127: return {"actor_id": 1, "set_id": 1}
		202: return {"tileset_id": 1}
		300: return {"type": 1, "profession_id": 1, "action_type": 0, "level": 1, "reset_level": false}
		301: return {"profession_id": 1}
		302: return {"parameter_id": 1, "operand": 0, "operand_type": 0, "operand_value": 0}
		303: return {"stat_id": 1, "operand": 0, "operand_type": 0, "operand_value": 0}
		500: return {"troop_id": 1, "can_escape": true, "can_lose": false}
		5000: return {"script": ""}
		_: return {}


#region Undo / Redo & Clipboard

func _serialize_graph_state() -> Dictionary:
	var state: Dictionary = {
		"nodes": [],
		"containers": [],
		"reminders": [],
		"connections": graph_edit.get_connection_list().duplicate(true),
		"scroll_offset": graph_edit.scroll_offset,
		"zoom": graph_edit.zoom
	}
	
	for c in _containers:
		if is_instance_valid(c):
			state["containers"].append(c.to_dict())
	for r in _reminders:
		if is_instance_valid(r):
			state["reminders"].append(r.to_dict())
	
	for child in graph_edit.get_children():
		if child is GraphNode and not (child is ContainerGraphNode) and not (child is ReminderGraphNode):
			var n_data: Dictionary = {
				"name": String(child.name),
				"position_offset": child.position_offset,
				"selected": child.selected,
				"is_collapsed": child.is_collapsed if ("is_collapsed" in child) else false
			}
			if child is BranchNodes.StartGraphNode:
				n_data["type"] = "start"
			elif child is BranchNodes.ConditionGraphNode:
				n_data["type"] = "condition"
				n_data["command"] = child.command.clone()
				n_data["conditions"] = child.conditions.duplicate(true)
				n_data["has_else_branch"] = child.has_else_branch
			elif child is BranchNodes.ChoiceGraphNode:
				n_data["type"] = "choice"
				n_data["command"] = child.command.clone()
				var subs: Array[RPGEventCommand] = []
				for s in child.sub_commands:
					subs.append(s.clone())
				n_data["sub_commands"] = subs
			elif child is BranchNodes.LoopGraphNode:
				n_data["type"] = "loop"
				n_data["command"] = child.command.clone()
			elif child is BranchNodes.BattleGraphNode:
				n_data["type"] = "battle"
				n_data["command"] = child.command.clone()
			elif child is CommandGraphNode:
				n_data["type"] = "command"
				n_data["command"] = child.command.clone()
				var subs: Array[RPGEventCommand] = []
				for s in child.sub_commands:
					subs.append(s.clone())
				n_data["sub_commands"] = subs
			state["nodes"].append(n_data)
			
	return state


func _deserialize_graph_state(state: Dictionary) -> void:
	_is_restoring_state = true
	graph_edit.clear_connections()
	
	for child in graph_edit.get_children():
		if child is GraphNode:
			child.queue_free()
			
	start_node = null
	_containers.clear()
	_reminders.clear()
	
	# Instantiate nodes
	for n_data in state.get("nodes", []):
		var n_type = n_data.get("type", "")
		var node: GraphNode = null
		if n_type == "start":
			node = _instantiate_start_node()
			start_node = node
		elif n_type == "condition":
			var cond_node = _instantiate_condition_node()
			cond_node.setup(n_data["command"], [])
			cond_node.conditions = n_data.get("conditions", [n_data["command"].parameters.duplicate()])
			cond_node.has_else_branch = n_data.get("has_else_branch", false)
			cond_node._build_ui()
			cond_node.update_visuals()
			_hook_node_signals(cond_node)
			node = cond_node
		elif n_type == "choice":
			var choice_node = _instantiate_choice_node()
			choice_node.setup(n_data["command"], n_data.get("sub_commands", []))
			_hook_node_signals(choice_node)
			node = choice_node
		elif n_type == "loop":
			var loop_node = _instantiate_loop_node()
			loop_node.setup(n_data["command"])
			_hook_node_signals(loop_node)
			node = loop_node
		elif n_type == "battle":
			var battle_node = _instantiate_battle_node()
			battle_node.setup(n_data["command"])
			_hook_node_signals(battle_node)
			node = battle_node
		elif n_type == "command":
			var cmd_node = _instantiate_command_node()
			cmd_node.setup(n_data["command"], n_data.get("sub_commands", []))
			_hook_node_signals(cmd_node)
			node = cmd_node
			
		if node:
			node.name = n_data["name"]
			node.position_offset = n_data["position_offset"]
			node.selected = n_data.get("selected", false)
			if n_data.get("is_collapsed", false) and node.has_method("set_collapsed"):
				node.set_collapsed(true, false)
			graph_edit.add_child(node)
			
	# Restore containers
	for c_data in state.get("containers", []):
		var col = Color.from_string(c_data.get("color", "#2d3748"), Color("#2d3748"))
		var pos_arr = c_data.get("pos", [0, 0])
		var sz_arr = c_data.get("size", [360, 240])
		var members: Array[StringName] = []
		for m in c_data.get("member_nodes", []):
			members.append(StringName(m))
		_spawn_container(
			c_data.get("title", "Contenedor"),
			members,
			Vector2(pos_arr[0], pos_arr[1]),
			Vector2(sz_arr[0], sz_arr[1]),
			col,
			c_data.get("collapsed", false),
			c_data.get("id", "")
		)
		
	# Restore reminders
	for r_data in state.get("reminders", []):
		var col = Color.from_string(r_data.get("color", "#d69e2e"), Color("#d69e2e"))
		var pos_arr = r_data.get("pos", [0, 0])
		var sz_arr = r_data.get("size", [240, 160])
		add_reminder_node(
			r_data.get("text", ""),
			r_data.get("title", "Recordatorio"),
			Vector2(pos_arr[0], pos_arr[1]),
			Vector2(sz_arr[0], sz_arr[1]),
			col,
			r_data.get("id", "")
		)
			
	# Restore connections
	for c in state.get("connections", []):
		graph_edit.connect_node(c["from_node"], c["from_port"], c["to_node"], c["to_port"])
		
	if state.has("scroll_offset"):
		graph_edit.scroll_offset = state["scroll_offset"]
	if state.has("zoom"):
		graph_edit.zoom = state["zoom"]
		
	_is_restoring_state = false
	_update_undo_redo_buttons()


func _push_undo_state() -> void:
	if _is_restoring_state:
		return
	var state = _serialize_graph_state()
	_undo_stack.append(state)
	if _undo_stack.size() > 50:
		_undo_stack.pop_front()
	_redo_stack.clear()
	_update_undo_redo_buttons()


func undo() -> void:
	if _undo_stack.is_empty():
		return
	var current_state = _serialize_graph_state()
	_redo_stack.append(current_state)
	if _redo_stack.size() > 50:
		_redo_stack.pop_front()
	var prev_state = _undo_stack.pop_back()
	_deserialize_graph_state(prev_state)
	_update_undo_redo_buttons()


func redo() -> void:
	if _redo_stack.is_empty():
		return
	var current_state = _serialize_graph_state()
	_undo_stack.append(current_state)
	if _undo_stack.size() > 50:
		_undo_stack.pop_front()
	var next_state = _redo_stack.pop_back()
	_deserialize_graph_state(next_state)
	_update_undo_redo_buttons()


func _update_undo_redo_buttons() -> void:
	if undo_button:
		undo_button.disabled = _undo_stack.is_empty()
	if redo_button:
		redo_button.disabled = _redo_stack.is_empty()
	if paste_button:
		paste_button.disabled = _clipboard_data.is_empty() or not _clipboard_data.has("nodes")
	_update_edit_menu_state()


func copy_selected() -> void:
	var selected_nodes: Array[GraphNode] = []
	for child in graph_edit.get_children():
		if child is GraphNode and child.selected and child != start_node and not (child is ContainerGraphNode) and not (child is ReminderGraphNode):
			selected_nodes.append(child)
			
	if selected_nodes.is_empty():
		return
		
	var selected_names: Dictionary = {}
	var min_pos = Vector2(INF, INF)
	for n in selected_nodes:
		selected_names[n.name] = true
		min_pos.x = min(min_pos.x, n.position_offset.x)
		min_pos.y = min(min_pos.y, n.position_offset.y)
		
	var clip_nodes: Array[Dictionary] = []
	for n in selected_nodes:
		var n_data: Dictionary = {
			"old_name": String(n.name),
			"rel_pos": n.position_offset - min_pos
		}
		if n is BranchNodes.ConditionGraphNode:
			n_data["type"] = "condition"
			n_data["command"] = n.command.clone()
			n_data["conditions"] = n.conditions.duplicate(true)
			n_data["has_else_branch"] = n.has_else_branch
		elif n is BranchNodes.ChoiceGraphNode:
			n_data["type"] = "choice"
			n_data["command"] = n.command.clone()
			var subs: Array[RPGEventCommand] = []
			for s in n.sub_commands:
				subs.append(s.clone())
			n_data["sub_commands"] = subs
		elif n is BranchNodes.LoopGraphNode:
			n_data["type"] = "loop"
			n_data["command"] = n.command.clone()
		elif n is BranchNodes.BattleGraphNode:
			n_data["type"] = "battle"
			n_data["command"] = n.command.clone()
		elif n is CommandGraphNode:
			n_data["type"] = "command"
			n_data["command"] = n.command.clone()
			var subs: Array[RPGEventCommand] = []
			for s in n.sub_commands:
				subs.append(s.clone())
			n_data["sub_commands"] = subs
		clip_nodes.append(n_data)
		
	var clip_conns: Array[Dictionary] = []
	for c in graph_edit.get_connection_list():
		if c["from_node"] in selected_names and c["to_node"] in selected_names:
			clip_conns.append({
				"from_node": c["from_node"],
				"from_port": c["from_port"],
				"to_node": c["to_node"],
				"to_port": c["to_port"]
			})
			
	_clipboard_data = {
		"nodes": clip_nodes,
		"connections": clip_conns,
		"min_pos": min_pos
	}
	_update_undo_redo_buttons()


func cut_selected() -> void:
	copy_selected()
	_push_undo_state()
	var to_delete: Array[GraphNode] = []
	for child in graph_edit.get_children():
		if child is GraphNode and child.selected and child != start_node:
			to_delete.append(child)
	for n in to_delete:
		_delete_single_node(n)


func paste(offset_delta: Vector2 = Vector2(40, 40)) -> void:
	if _clipboard_data.is_empty() or not _clipboard_data.has("nodes"):
		return
		
	_push_undo_state()
	
	for child in graph_edit.get_children():
		if child is GraphNode:
			child.selected = false
			
	var name_map: Dictionary = {}
	var base_pos = _clipboard_data.get("min_pos", Vector2.ZERO) + offset_delta
	
	for n_data in _clipboard_data["nodes"]:
		_node_counter += 1
		var new_name = "Node_%d" % _node_counter
		name_map[n_data["old_name"]] = new_name
		
		var node: GraphNode = null
		var n_type = n_data["type"]
		if n_type == "condition":
			var cond_node = _instantiate_condition_node()
			cond_node.name = new_name
			cond_node.setup(n_data["command"].clone(), [])
			cond_node.conditions = n_data["conditions"].duplicate(true)
			cond_node.has_else_branch = n_data["has_else_branch"]
			cond_node._build_ui()
			cond_node.update_visuals()
			_hook_node_signals(cond_node)
			node = cond_node
		elif n_type == "choice":
			var choice_node = _instantiate_choice_node()
			choice_node.name = new_name
			var subs: Array[RPGEventCommand] = []
			for s in n_data.get("sub_commands", []):
				subs.append(s.clone())
			choice_node.setup(n_data["command"].clone(), subs)
			_hook_node_signals(choice_node)
			node = choice_node
		elif n_type == "loop":
			var loop_node = _instantiate_loop_node()
			loop_node.name = new_name
			loop_node.setup(n_data["command"].clone())
			_hook_node_signals(loop_node)
			node = loop_node
		elif n_type == "battle":
			var battle_node = _instantiate_battle_node()
			battle_node.name = new_name
			battle_node.setup(n_data["command"].clone())
			_hook_node_signals(battle_node)
			node = battle_node
		elif n_type == "command":
			var cmd_node = _instantiate_command_node()
			cmd_node.name = new_name
			var subs: Array[RPGEventCommand] = []
			for s in n_data.get("sub_commands", []):
				subs.append(s.clone())
			cmd_node.setup(n_data["command"].clone(), subs)
			_hook_node_signals(cmd_node)
			node = cmd_node
			
		if node:
			node.position_offset = base_pos + n_data["rel_pos"]
			node.selected = true
			graph_edit.add_child(node)
			
	for c in _clipboard_data.get("connections", []):
		if c["from_node"] in name_map and c["to_node"] in name_map:
			graph_edit.connect_node(name_map[c["from_node"]], c["from_port"], name_map[c["to_node"]], c["to_port"])
			
	_clipboard_data["min_pos"] += Vector2(30, 30)


func duplicate_selected() -> void:
	copy_selected()
	paste(Vector2(40, 40))


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if _handle_shortcut_event(event):
		get_viewport().set_input_as_handled()


func _unhandled_key_input(event: InputEvent) -> void:
	if not visible:
		return
	if _handle_shortcut_event(event):
		get_viewport().set_input_as_handled()


func _handle_shortcut_event(event: InputEvent) -> bool:
	if not (event is InputEventKey):
		return false
	if not event.is_pressed() or event.is_echo():
		return false
	if search_popup and search_popup.visible:
		return false
		
	var focused = get_viewport().gui_get_focus_owner()
	if focused and (focused is LineEdit or focused is TextEdit):
		return false
		
	var is_cmd_ctrl: bool = event.is_command_or_control_pressed() if event.has_method("is_command_or_control_pressed") else (("ctrl_pressed" in event and event.ctrl_pressed) or ("meta_pressed" in event and event.meta_pressed))
	var is_shift: bool = event.is_shift_pressed() if event.has_method("is_shift_pressed") else ("shift_pressed" in event and event.shift_pressed)
	var code = event.keycode
	if code == 0 and "key_label" in event and event.key_label != 0:
		code = event.key_label
	if code == 0:
		code = event.physical_keycode
	
	if is_cmd_ctrl:
		match code:
			KEY_Z:
				if is_shift:
					redo()
				else:
					undo()
				return true
			KEY_Y:
				redo()
				return true
			KEY_C:
				copy_selected()
				return true
			KEY_X:
				cut_selected()
				return true
			KEY_V:
				paste()
				return true
			KEY_D:
				duplicate_selected()
				return true
			KEY_G:
				if is_shift:
					ungroup_selected_container()
				else:
					group_selected_into_container()
				return true
	elif code == KEY_DELETE or code == KEY_BACKSPACE:
		var selected: Array[StringName] = []
		for child in graph_edit.get_children():
			if child is GraphNode and child.selected and child != start_node:
				selected.append(child.name)
		if not selected.is_empty():
			_on_delete_nodes_request(selected)
			return true
			
	return false

#endregion


#region Container & Reminder Management

func group_selected_into_container() -> void:
	var selected_nodes: Array[GraphNode] = []
	for child in graph_edit.get_children():
		if child is GraphNode and child.selected and child != start_node and not (child is ContainerGraphNode) and not (child is ReminderGraphNode):
			selected_nodes.append(child)
			
	if selected_nodes.is_empty():
		var center_pos = graph_edit.scroll_offset + (graph_edit.size / 2.0) / graph_edit.zoom
		_spawn_container("📦 Contenedor", [], center_pos, Vector2(360, 240))
		return
		
	var min_pos = Vector2(INF, INF)
	var max_pos = Vector2(-INF, -INF)
	var member_names: Array[StringName] = []
	
	for n in selected_nodes:
		member_names.append(n.name)
		min_pos.x = min(min_pos.x, n.position_offset.x)
		min_pos.y = min(min_pos.y, n.position_offset.y)
		max_pos.x = max(max_pos.x, n.position_offset.x + n.size.x)
		max_pos.y = max(max_pos.y, n.position_offset.y + n.size.y)
		
	const MARGIN_LEFT: float = 30.0
	const MARGIN_RIGHT: float = 30.0
	const MARGIN_TOP: float = 65.0
	const MARGIN_BOTTOM: float = 30.0
	
	var cont_pos = Vector2(min_pos.x - MARGIN_LEFT, min_pos.y - MARGIN_TOP)
	var cont_size = Vector2(
		max((max_pos.x - min_pos.x) + MARGIN_LEFT + MARGIN_RIGHT, 320.0),
		max((max_pos.y - min_pos.y) + MARGIN_TOP + MARGIN_BOTTOM, 200.0)
	)
	
	_push_undo_state()
	_spawn_container("📦 Contenedor", member_names, cont_pos, cont_size)


func ungroup_selected_container() -> void:
	for child in graph_edit.get_children():
		if child is ContainerGraphNode and child.selected:
			_push_undo_state()
			for m_name in child.member_node_names:
				var n = graph_edit.get_node_or_null(NodePath(m_name))
				if n and n is GraphNode:
					n.visible = true
			_containers.erase(child)
			child.queue_free()
			return


func _spawn_container(p_title: String, p_members: Array[StringName], p_pos: Vector2, p_size: Vector2, p_color: Color = Color("#2d3748"), p_collapsed: bool = false, p_id: String = "") -> ContainerGraphNode:
	var cont = _instantiate_container_node()
	if p_id.is_empty():
		p_id = "cont_%d" % Time.get_ticks_msec()
	cont.name = p_id
	cont.setup_container(p_id, p_title, p_members, p_pos, p_size, p_color, p_collapsed)
	
	cont.ungroup_requested.connect(func(c):
		_push_undo_state()
		for m_name in c.member_node_names:
			var n = graph_edit.get_node_or_null(NodePath(m_name))
			if n and n is GraphNode:
				n.visible = true
		_containers.erase(c)
		c.queue_free()
	)
	cont.delete_requested.connect(func(c):
		_push_undo_state()
		for m_name in c.member_node_names:
			var n = graph_edit.get_node_or_null(NodePath(m_name))
			if n and n is GraphNode:
				n.visible = true
		_containers.erase(c)
		c.queue_free()
	)
	cont.member_dragged_outside.connect(func(_c, dropped_node):
		_on_node_drag_completed(dropped_node, Vector2.ZERO, dropped_node.position_offset)
	)
	cont.container_modified.connect(func(_c):
		pass
	)
	
	_containers.append(cont)
	graph_edit.add_child(cont)
	return cont


func _on_node_drag_completed(node: GraphNode, _from: Vector2, _to: Vector2) -> void:
	if node is ContainerGraphNode or node is ReminderGraphNode or node == start_node:
		return
		
	var node_rect = Rect2(node.position_offset, node.size)
	var current_container: ContainerGraphNode = null
	for c in _containers:
		if is_instance_valid(c) and c.member_node_names.has(node.name):
			current_container = c
			break
			
	var target_container: ContainerGraphNode = null
	
	# First check if node still touches current_container (even slightly)
	if current_container != null and is_instance_valid(current_container) and not current_container.is_collapsed:
		var c_rect = Rect2(current_container.position_offset, current_container.size)
		if c_rect.intersects(node_rect, true):
			target_container = current_container
			
	# If not touching current_container (or node was not in any), check other containers
	if target_container == null:
		for c in _containers:
			if is_instance_valid(c) and not c.is_collapsed:
				var c_rect = Rect2(c.position_offset, c.size)
				if c_rect.intersects(node_rect, true):
					target_container = c
					break
					
	if current_container != null and current_container != target_container:
		current_container.remove_member(node.name)
		
	if target_container != null:
		if not target_container.member_node_names.has(node.name):
			target_container.add_member(node.name)
		target_container.recalculate_bounds()
	elif current_container != null and current_container == target_container:
		current_container.recalculate_bounds()


func add_reminder_node(p_text: String = "", p_title: String = "📝 Recordatorio", p_pos: Vector2 = Vector2.ZERO, p_size: Vector2 = Vector2(240, 160), p_color: Color = Color("#d69e2e"), p_id: String = "") -> ReminderGraphNode:
	_push_undo_state()
	var rem = _instantiate_reminder_node()
	if p_id.is_empty():
		p_id = "rem_%d" % Time.get_ticks_msec()
	if p_pos == Vector2.ZERO:
		p_pos = graph_edit.scroll_offset + Vector2(100, 100)
	rem.name = p_id
	rem.setup_reminder(p_id, p_title, p_text, p_pos, p_size, p_color)
	
	rem.delete_requested.connect(func(r):
		_push_undo_state()
		_reminders.erase(r)
		r.queue_free()
	)
	rem.reminder_modified.connect(func(_r):
		pass
	)
	
	_reminders.append(rem)
	graph_edit.add_child(rem)
	return rem

#endregion


func _on_apply_pressed() -> void:
	var compiled = compile_graph_to_commands()
	
	# Save page graph layout to map JSON configuration
	var event_id = _get_current_event_id()
	var page_id = _get_current_page_id()
	
	var nodes_data: Dictionary = {}
	for child in graph_edit.get_children():
		if child is GraphNode and child != start_node and not (child is ContainerGraphNode) and not (child is ReminderGraphNode):
			var n_dict: Dictionary = {
				"pos": [child.position_offset.x, child.position_offset.y],
				"collapsed": child.is_collapsed if ("is_collapsed" in child) else false
			}
			if "command" in child and child.command:
				n_dict["code"] = child.command.code
			nodes_data[String(child.name)] = n_dict
			
	var containers_data: Array[Dictionary] = []
	for c in _containers:
		if is_instance_valid(c):
			containers_data.append(c.to_dict())
			
	var reminders_data: Array[Dictionary] = []
	for r in _reminders:
		if is_instance_valid(r):
			reminders_data.append(r.to_dict())
			
	var page_data: Dictionary = {
		"start_pos": [start_node.position_offset.x, start_node.position_offset.y] if start_node else [80, 200],
		"scroll": [graph_edit.scroll_offset.x, graph_edit.scroll_offset.y],
		"zoom": graph_edit.zoom,
		"nodes": nodes_data,
		"containers": containers_data,
		"reminders": reminders_data
	}
	
	EventGraphConfigManager.set_page_data(config_file_path, event_id, page_id, page_data)
	EventGraphConfigManager.clean_scene_and_page_metadata(current_page, compiled)
	
	applied.emit(compiled)
	hide()
	queue_free()


func _on_close_requested() -> void:
	hide()
	queue_free()
