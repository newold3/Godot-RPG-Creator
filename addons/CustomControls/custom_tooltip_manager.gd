@tool
class_name MainTooltipManager
extends Control

@export var use_default_tooltip: bool = true

## Main tooltip manager that handles custom tooltip creation and lifecycle management.
## Replaces standard Godot tooltips with custom styled tooltips that support rich text formatting.
## Manages tooltip visibility based on dialog states and provides keyboard shortcuts for toggling.

const CUSTOM_TOOLTIP = preload("res://addons/CustomControls/custom_tooltip.tscn")
const TWEEN_INTERVAL: float = 0.35
const MAX_TOOLTIPS: int = 10
var TOOLTIP_COLORS = PackedColorArray([
	Color.CORAL, Color.AQUA, Color.CHARTREUSE, Color.CYAN, 
	Color.DEEP_PINK, Color.DEEP_SKY_BLUE, Color.GHOST_WHITE, 
	Color.FUCHSIA, Color.KHAKI, Color.RED
])

## Currently active tooltip window instance
var current_tooltip: Window

## Node that is currently showing a tooltip
var current_node_showing_tooltip: Node

## Global flag to disable all tooltips temporarily
var no_tooltips_enabled: bool = false

## Tween animation for tooltip display timing
var tooltip_tween: Tween

var busy: bool = false # Externally controlled by some scripts

var tooltip_list: Array[Window] = []
var tooltip_count: int = 0

var tooltip_regex: Dictionary = {}

var _delay_to_show_tooltip_timer: float = 0.0
var _max_delay_to_show_tooltip_timer: float = 0.1
var _current_tooltip_to_show: Node

## Emitted to destroy all active tooltips
signal destroy_all_tooltips()


## Initialize the tooltip manager and set up node monitoring
func _ready() -> void:
	destroy_all_tooltips.connect(_on_destroy_all_tooltips)
	get_tree().node_added.connect(_on_node_added)
	set_process_input(true)
	
	tooltip_regex = {
		"filter1": RegEx.new(), # Title
		"filter2": RegEx.new(), # Colors
		"filter3": RegEx.new(), # Numbers
		"filter4": RegEx.new()  # Quotes
	}
	
	tooltip_regex.filter1.compile("\\[title](.+)\\[/title]")
	tooltip_regex.filter2.compile('\\[(\\d*) *([^\\]]+) *\\]')
	tooltip_regex.filter3.compile("(?<!\\[)(-?\\s*\\b\\d+\\b\\s*%?)(?![\\]])")
	tooltip_regex.filter4.compile('(?<!\\[)\\"([^\\"]+)\\"(?!\\])')


func _process(delta: float) -> void:
	if _delay_to_show_tooltip_timer > 0.0:
		_delay_to_show_tooltip_timer -= delta
		if _delay_to_show_tooltip_timer <= 0.0:
			if is_instance_valid(_current_tooltip_to_show) and _current_tooltip_to_show.is_inside_tree() and _current_tooltip_to_show.is_visible_in_tree():
				var w = _current_tooltip_to_show.get_window()
				if is_instance_valid(w) and w.has_focus():
					_on_node_mouse_entered(_current_tooltip_to_show, false)
			else:
				# Reset if invalid
				_current_tooltip_to_show = null


func _on_destroy_all_tooltips() -> void:
	if tooltip_tween:
		tooltip_tween.kill()


## Handle keyboard shortcuts for toggling tooltips in editor
func _unhandled_key_input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		if event is InputEventKey and event.is_pressed() and not event.is_echo() and event.keycode == KEY_T and event.is_ctrl_pressed():
			FileCache.options.force_no_tooltips_enabled = !FileCache.options.get("force_no_tooltips_enabled", false)
			if FileCache.options.force_no_tooltips_enabled:
				print("🚫" + tr("Tooltips DISABLED") + ".")
			else:
				print("💡" + tr("Tooltips ENABLED") + ".")
			get_viewport().set_input_as_handled()


## Set the global tooltip disable state
func set_no_tooltips(mode: bool) -> void:
	no_tooltips_enabled = mode
	if no_tooltips_enabled:
		destroy_all_tooltips.emit()


## Set the force disable tooltips option and destroy active tooltips if enabled
func set_force_no_tooltips_enabled(mode: bool) -> void:
	FileCache.options.force_no_tooltips_enabled = mode
	if mode:
		destroy_all_tooltips.emit()


## Handle newly added nodes by setting up tooltip behavior based on dialog state
func _on_node_added(node: Node) -> void:
	if not RPGDialogFunctions or node is PopupMenu or node is Window or node is Node2D:
		return
		
	var any_dialog_active: bool = RPGDialogFunctions.there_are_any_dialog_open()

	if !any_dialog_active:
		if "tooltip_text" in node and node.has_meta("current_tooltip") and node.get_meta("current_tooltip").length() > 0:
			node.tooltip_text = node.get_meta("current_tooltip")
			node.remove_meta("current_tooltip")
		if node.has_signal("mouse_entered"):
			if node.mouse_entered.is_connected(_on_node_mouse_entered):
				node.mouse_entered.disconnect(_on_node_mouse_entered)
			node.mouse_entered.connect(_on_node_mouse_entered.bind(node))
		if node.has_signal("mouse_exited"):
			if node.mouse_exited.is_connected(_on_node_mouse_exited):
				node.mouse_exited.disconnect(_on_node_mouse_exited)
			node.mouse_exited.connect(_on_node_mouse_exited.bind(node))
		return
	else:
		if "tooltip_text" in node:
			if node.tooltip_text.length() > 0:
				var tooltip = node.tooltip_text
				node.set_meta("current_tooltip", tooltip)
				node.tooltip_text = ""
				if node.mouse_entered.is_connected(_show_custom_tooltip_text_for_node):
					node.mouse_entered.disconnect(_show_custom_tooltip_text_for_node)
				node.mouse_entered.connect(_show_custom_tooltip_text_for_node.bind(node))
				if node is SpinBox:
					if not tooltip.begins_with("[title]"):
						tooltip = "[title]%s[/title]%s" % [node.name.to_pascal_case(), tooltip]
					var line_edit = node.get_line_edit()
					if is_instance_valid(line_edit):
						line_edit.tooltip_text = tooltip
						replace_all_tooltips_with_custom(line_edit)
			elif node.has_meta("current_tooltip") and node.get_meta("current_tooltip").length() > 0:
				if node.mouse_entered.is_connected(_show_custom_tooltip_text_for_node):
					node.mouse_entered.disconnect(_show_custom_tooltip_text_for_node)
				node.mouse_entered.connect(_show_custom_tooltip_text_for_node.bind(node))
			elif node.mouse_entered.is_connected(_show_custom_tooltip_text_for_node):
				node.mouse_entered.disconnect(_show_custom_tooltip_text_for_node)


## Replace all standard tooltips with custom tooltips recursively for a node and its children
func replace_all_tooltips_with_custom(node: Node) -> void:
	if node is PopupMenu: return
	
	_on_node_added(node)
	
	for child in node.get_children():
		replace_all_tooltips_with_custom(child)


func plugin_replace_all_tooltips_with_custom(node: Node) -> void:
	if "tooltip_text" in node:
		if node.tooltip_text.length() > 0:
			var tooltip = node.tooltip_text
			node.set_meta("current_tooltip", tooltip)
			node.tooltip_text = ""
			if node.mouse_entered.is_connected(_show_custom_tooltip_text_for_node):
				node.mouse_entered.disconnect(_show_custom_tooltip_text_for_node)
			node.mouse_entered.connect(_show_custom_tooltip_text_for_node.bind(node))
			if node is SpinBox:
				if not tooltip.begins_with("[title]"):
					tooltip = "[title]%s[/title]%s" % [node.name.to_pascal_case(), tooltip]
				var line_edit = node.get_line_edit()
				if is_instance_valid(line_edit):
					line_edit.tooltip_text = tooltip
					plugin_replace_all_tooltips_with_custom(line_edit)
				return
		elif node.has_meta("current_tooltip") and node.get_meta("current_tooltip").length() > 0:
			if node.mouse_entered.is_connected(_show_custom_tooltip_text_for_node):
				node.mouse_entered.disconnect(_show_custom_tooltip_text_for_node)
			node.mouse_entered.connect(_show_custom_tooltip_text_for_node.bind(node))
		elif node.mouse_entered.is_connected(_show_custom_tooltip_text_for_node):
			node.mouse_entered.disconnect(_show_custom_tooltip_text_for_node)
	
	for child in node.get_children():
		plugin_replace_all_tooltips_with_custom(child)


## Restore all standard tooltips for a node and its children
func restore_all_tooltips_for(node: Node) -> void:
	if node.has_meta("current_tooltip"):
		node.tooltip_text = node.get_meta("current_tooltip")
		node.remove_meta("current_tooltip")
		if node.mouse_entered.is_connected(_show_custom_tooltip_text_for_node):
			node.mouse_entered.disconnect(_show_custom_tooltip_text_for_node)
	
	for child in node.get_children():
		restore_all_tooltips_for(child)


## Display a custom tooltip for a node with delay and formatting
func _show_custom_tooltip_text_for_node(node: Node) -> void:
	if not is_instance_valid(node): return
	var w = node.get_window()
	if not is_instance_valid(w) or not w.has_focus(): return
	
	if no_tooltips_enabled or FileCache.options.get("force_no_tooltips_enabled", false): return
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT): return
	if node.has_meta("current_tooltip"):
		destroy_all_tooltips.emit()
		var title: String = node.name
		var contents: String
		if node.has_method("get_custom_tooltip"):
			contents = node.get_custom_tooltip()
			if contents.length() == 0:
				return
			if node.has_signal("tooltip_changed"):
				if not node.tooltip_changed.is_connected(_show_custom_tooltip_text_for_node):
					node.tooltip_changed.connect(_show_custom_tooltip_text_for_node.bind(node))
		else:
			contents = node.get_meta("current_tooltip")
			
		if tooltip_tween:
			tooltip_tween.kill()

		tooltip_tween = create_tween()
		tooltip_tween.tween_interval(TWEEN_INTERVAL)
		tooltip_tween.tween_callback(show_tooltip.bind(title, contents, node))


func show_tooltip(title: String, contents: String, parent_node) -> void:
	call_deferred("_create_tooltip", title, contents, parent_node)


func show_tooltip_from_node(node: Node) -> void:
	_show_custom_tooltip_text_for_node(node)


## Create and configure a new custom tooltip with rich text formatting
func _create_tooltip(title: String, contents: String, parent_node) -> void:
	if not is_instance_valid(parent_node):
		return
	
	# Prevent duplicate tooltips for same node
	if parent_node.has_meta("current_tooltip_node"):
		var existing = parent_node.get_meta("current_tooltip_node")
		if is_instance_valid(existing):
			return
		else:
			# Cleanup dead reference
			parent_node.remove_meta("current_tooltip_node")
	
	var tooltip: Window
	var is_new_tooltip: bool = false
	
	# --- Robust Pooling Logic ---
	# First, clean invalid entries from list
	for i in range(tooltip_list.size() - 1, -1, -1):
		if not is_instance_valid(tooltip_list[i]):
			tooltip_list.remove_at(i)
			tooltip_count = max(0, tooltip_count - 1)
	
	if tooltip_count < MAX_TOOLTIPS:
		tooltip = CUSTOM_TOOLTIP.instantiate()
		tooltip.inactive_tooltip.connect(_on_tooltip_inactive)
		tooltip.set_meta("is_in_pool", false)
		tooltip_count += 1
		is_new_tooltip = true
	else:
		# Search in valid pool
		for i in range(tooltip_list.size() - 1, -1, -1):
			var t = tooltip_list[i]
			if is_instance_valid(t):
				if t.get_meta("is_in_pool", false):
					tooltip = t
					tooltip_list.erase(t)
					tooltip.set_meta("is_in_pool", false)
					break
			else:
				tooltip_list.remove_at(i)
		
		# If pool was full but no available tooltips (all busy), make a temporary overflow one
		if not tooltip:
			tooltip = CUSTOM_TOOLTIP.instantiate()
			tooltip.inactive_tooltip.connect(_on_tooltip_inactive)
			tooltip.set_meta("is_in_pool", false)
			is_new_tooltip = true
	
	if not is_instance_valid(tooltip):
		return
	
	if not is_new_tooltip:
		tooltip.busy = true
	
	tooltip.size = Vector2i.ONE
	
	# --- Formatting Cache & RegEx Logic ---
	
	var final_title: String
	var final_contents: String
	
	var new_original_key = title + "::" + contents
	var cached_original_key = parent_node.get_meta("_tooltip_manager_cache_original_key", "")
	
	if new_original_key == cached_original_key:
		# Cache HIT
		final_title = parent_node.get_meta("_tooltip_manager_cache_title", title)
		final_contents = parent_node.get_meta("_tooltip_manager_cache_contents", contents)
		
	else:
		# Cache MISS: Format text using pre-compiled regex
		var formatted_title = title
		var formatted_contents = contents
		
		# filter1: Title
		var result = tooltip_regex.filter1.search(formatted_contents)
		if result:
			formatted_title = result.get_string(1)
			formatted_contents = tooltip_regex.filter1.sub(formatted_contents, "", true)
		
		formatted_title = formatted_title.strip_edges()
		formatted_contents = formatted_contents.strip_edges()
		
		if formatted_contents.length() > 0 and not formatted_contents.ends_with(".") and not formatted_contents.ends_with("]"):
			formatted_contents += "."
		
		# filter2: Colors
		result = tooltip_regex.filter2.search_all(formatted_contents)
		for m in result:
			var color_index = m.get_string(1)
			var current_color = "#46f714"
			if color_index and TOOLTIP_COLORS.size() > int(color_index):
				current_color = TOOLTIP_COLORS[int(color_index)].to_html()
			var t = m.get_string()
			if !"table=" in t and !"color=" in t and !"[cell]" in t and !"[ul]" in t and !"[/" in t:
				var t2 = m.get_string(2)
				formatted_contents = formatted_contents.replace(t, "[color=%s]%s[/color]" % [current_color, t2])

		# filter3: Numbers
		formatted_contents = tooltip_regex.filter3.sub(formatted_contents, "[color=#f0a20c]$1[/color]", true)
		
		# filter4: Quotes
		formatted_contents = tooltip_regex.filter4.sub(formatted_contents, "[color=#ff512f]$1[/color]", true)

		final_title = formatted_title
		final_contents = formatted_contents
		
		# Save results to cache
		parent_node.set_meta("_tooltip_manager_cache_original_key", new_original_key)
		parent_node.set_meta("_tooltip_manager_cache_title", final_title)
		parent_node.set_meta("_tooltip_manager_cache_contents", final_contents)
	
	# --- End of Formatting Logic ---

	if not destroy_all_tooltips.is_connected(tooltip.end):
		destroy_all_tooltips.connect(tooltip.end)
	
	tooltip.visible = false
	tooltip.position = get_window().get_mouse_position()

	# Defer final setup to avoid race conditions
	call_deferred(
		"_finalize_tooltip_setup", 
		tooltip, 
		parent_node, 
		final_title, 
		final_contents, 
		is_new_tooltip
	)


func _finalize_tooltip_setup(
	tooltip: Window, 
	parent_node: Node, 
	title: String, 
	contents: String, 
	is_new: bool
) -> void:
	
	# Validate EVERYTHING again since we are deferred
	if not is_instance_valid(tooltip):
		return
	
	if not is_instance_valid(parent_node) or not parent_node.is_inside_tree() or parent_node.is_queued_for_deletion():
		tooltip.visible = false
		tooltip.set_meta("is_in_pool", true)
		if not tooltip in tooltip_list:
			tooltip_list.append(tooltip) # Return to pool instead of killing if possible
		return

	if not tooltip.tree_exiting.is_connected(_on_tooltip_tree_exiting):
		tooltip.tree_exiting.connect(_on_tooltip_tree_exiting.bind(tooltip))

	if tooltip.get_parent() != parent_node:
		if tooltip.get_parent():
			tooltip.reparent(parent_node)
		else:
			parent_node.add_child(tooltip)
	
	if not is_new:
		tooltip.restart()
	
	parent_node.set_meta("current_tooltip_node", tooltip)
	tooltip.set_data(title, contents)
	
	current_tooltip = tooltip
	current_node_showing_tooltip = parent_node


func _on_tooltip_inactive(tooltip: Window) -> void:
	if not is_instance_valid(tooltip): return
	
	var parent = tooltip.get_parent()
	if is_instance_valid(parent):
		_remove_tooltip_for(parent, tooltip)
	
	tooltip.visible = false
	
	# Safe reparent to manager to keep it alive
	if tooltip.get_parent() != self:
		tooltip.reparent(self)
	
	tooltip.position = Vector2i(-1000000, -1000000)
	tooltip.set_meta("is_in_pool", true)
	
	# Add to pool if valid and not duplicate
	if not tooltip in tooltip_list and tooltip_list.size() < MAX_TOOLTIPS:
		tooltip_list.append(tooltip)
	elif tooltip not in tooltip_list:
		# If pool is full, just kill the extra tooltip
		tooltip.queue_free()


## Remove tooltip reference and disconnect signals when tooltip is destroyed
func _remove_tooltip_for(node: Node, original_tooltip) -> void:
	if is_instance_valid(node) and node.has_meta("current_tooltip_node"):
		var tooltip = node.get_meta("current_tooltip_node")
		if tooltip == original_tooltip:
			node.remove_meta("current_tooltip_node")
			if destroy_all_tooltips.is_connected(tooltip.end):
				destroy_all_tooltips.disconnect(tooltip.end)
			if current_tooltip == tooltip:
				current_tooltip = null
				current_node_showing_tooltip = null


## Handle mouse entering a node to set up tooltip behavior based on dialog state
func _on_node_mouse_entered(node: Node, show_delayed: bool = true) -> void:
	if not RPGDialogFunctions or busy:
		return

	var any_dialog_active: bool = RPGDialogFunctions.there_are_any_dialog_open()
	if !any_dialog_active or node.has_meta("current_tooltip"): return
	
	if show_delayed:
		_delay_to_show_tooltip_timer = _max_delay_to_show_tooltip_timer
		_current_tooltip_to_show = node
		return

	if "tooltip_text" in node:
		if node.tooltip_text.length() > 0:
			node.set_meta("current_tooltip", node.tooltip_text)
			node.tooltip_text = ""
			if !node.mouse_entered.is_connected(_show_custom_tooltip_text_for_node):
				node.mouse_entered.connect(_show_custom_tooltip_text_for_node.bind(node))
		elif node.has_meta("current_tooltip") and node.get_meta("current_tooltip").length() > 0:
			if !node.mouse_entered.is_connected(_show_custom_tooltip_text_for_node):
				node.mouse_entered.connect(_show_custom_tooltip_text_for_node.bind(node))
		elif node.mouse_entered.is_connected(_show_custom_tooltip_text_for_node):
			node.mouse_entered.disconnect(_show_custom_tooltip_text_for_node)

	if node.has_meta("current_tooltip"):
		node.mouse_entered.disconnect(_on_node_mouse_entered)
		call_deferred("_show_custom_tooltip_text_for_node", node)


func _on_node_mouse_exited(node: Node) -> void:
	if _current_tooltip_to_show == node:
		_current_tooltip_to_show = null
		_delay_to_show_tooltip_timer = 0.0


## CRITICAL FIX: Cleanup handler for when a tooltip is destroyed forcefully
func _on_tooltip_tree_exiting(tooltip_instance: Window) -> void:
	if current_tooltip == tooltip_instance:
		current_tooltip = null
		if tooltip_tween:
			tooltip_tween.kill()
	
	if tooltip_instance in tooltip_list:
		tooltip_list.erase(tooltip_instance)
		tooltip_count = max(0, tooltip_count - 1)
