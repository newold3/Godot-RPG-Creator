@tool
class_name GraphCommandSearchPopup
extends PopupPanel

var filter_line_edit: LineEdit
var command_tree: Tree
var spawn_graph_position: Vector2 = Vector2.ZERO

signal command_selected(code: int, button_id: int, position: Vector2)


func _ready() -> void:
	size = Vector2i(340, 480)
	_build_ui()


func _build_ui() -> void:
	for child in get_children():
		child.queue_free()
		
	var main_vbox = VBoxContainer.new()
	main_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main_vbox.add_theme_constant_override("separation", 6)
	
	# Header
	var header_hbox = HBoxContainer.new()
	var title_lbl = Label.new()
	title_lbl.text = "➕ Add Event Command"
	title_lbl.add_theme_font_size_override("font_size", 13)
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_hbox.add_child(title_lbl)
	main_vbox.add_child(header_hbox)
	
	# Search LineEdit
	filter_line_edit = LineEdit.new()
	filter_line_edit.placeholder_text = "Search command... (e.g. switch, message)"
	filter_line_edit.clear_button_enabled = true
	filter_line_edit.text_changed.connect(_on_filter_changed)
	main_vbox.add_child(filter_line_edit)
	
	# Tree
	command_tree = Tree.new()
	command_tree.hide_root = true
	command_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	command_tree.item_activated.connect(_on_item_activated)
	main_vbox.add_child(command_tree)
	
	add_child(main_vbox)
	_populate_tree("")


func popup_at_position(screen_pos: Vector2, graph_pos: Vector2) -> void:
	spawn_graph_position = graph_pos
	position = Vector2i(screen_pos)
	popup()
	if filter_line_edit:
		filter_line_edit.text = ""
		_populate_tree("")
		filter_line_edit.grab_focus.call_deferred()


func _populate_tree(filter: String) -> void:
	if not command_tree:
		return
		
	command_tree.clear()
	var root = command_tree.create_item()
	var lower_filter = filter.to_lower().strip_edges()
	var has_filter = not lower_filter.is_empty()
	
	for cat in GraphCommandData.ALL_CATEGORIES:
		var items = GraphCommandData.ALL_CATEGORIES[cat]
		var cat_item: TreeItem = null
		var matching_count = 0
		
		for item in items:
			var text = item.get("text", "")
			var tooltip = item.get("tooltip", "")
			
			var matches = true
			if has_filter:
				var in_text = text.to_lower().contains(lower_filter)
				var in_tool = tooltip.to_lower().contains(lower_filter)
				var in_cat = cat.to_lower().contains(lower_filter)
				matches = in_text or in_tool or in_cat
				
			if matches:
				if cat_item == null:
					cat_item = command_tree.create_item(root)
					cat_item.set_text(0, "📂 " + cat)
					cat_item.set_selectable(0, false)
					cat_item.set_custom_color(0, GraphCommandData.get_category_color(cat))
					
				var cmd_item = command_tree.create_item(cat_item)
				cmd_item.set_text(0, "   " + text)
				cmd_item.set_tooltip_text(0, tooltip)
				cmd_item.set_metadata(0, {
					"code": item.get("code", 0),
					"button_id": item.get("button_id", 0),
					"text": text
				})
				matching_count += 1
				
		if cat_item != null:
			cat_item.collapsed = not has_filter


func _on_filter_changed(new_text: String) -> void:
	_populate_tree(new_text)


func _on_item_activated() -> void:
	var selected = command_tree.get_selected()
	if not selected:
		return
	var meta = selected.get_metadata(0)
	if meta and meta is Dictionary:
		var code = meta.get("code", 0)
		var button_id = meta.get("button_id", 0)
		command_selected.emit(code, button_id, spawn_graph_position)
		hide()
