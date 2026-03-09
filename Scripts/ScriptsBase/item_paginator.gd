@tool
class_name ItemPaginator
extends PanelContainer

## Emitted when the user selects a new page
signal page_changed(page: int)

## Number of items per page. Set to 0 to show all items (disables pagination).
@export var items_per_page: int = 500:
	set(value):
		items_per_page = max(0, value)
		if is_node_ready():
			setup_pagination(total_items)
## Background style for the outer pagination panel
@export var panel_style: StyleBox:
	set(value):
		panel_style = value
		if panel_style:
			add_theme_stylebox_override("panel", panel_style)
## Background style for the centered inner pagination panel
@export var inner_panel_style: StyleBox:
	set(value):
		inner_panel_style = value
		if is_instance_valid(inner_panel):
			inner_panel.add_theme_stylebox_override("panel", inner_panel_style)
## Custom button scene for normal pages. Must have a 'text' property or 'set_text' method, and a 'pressed' signal.
@export var custom_button: PackedScene:
	set(value):
		custom_button = value
		if is_node_ready():
			setup_pagination(total_items)
## Custom button scene for the previous page button (<).
@export var custom_prev_button: PackedScene:
	set(value):
		custom_prev_button = value
		if is_node_ready():
			setup_pagination(total_items)
## Custom button scene for the next page button (>).
@export var custom_next_button: PackedScene:
	set(value):
		custom_next_button = value
		if is_node_ready():
			setup_pagination(total_items)
## Margins for the previous button container (Left, Top, Right, Bottom).
@export var prev_button_margin: Vector4i = Vector4i(0, 0, 0, 0):
	set(value):
		prev_button_margin = value
		if is_node_ready():
			setup_pagination(total_items)
## Margins for the next button container (Left, Top, Right, Bottom).
@export var next_button_margin: Vector4i = Vector4i(0, 0, 0, 0):
	set(value):
		next_button_margin = value
		if is_node_ready():
			setup_pagination(total_items)

var current_page: int = 0
var total_items: int = 0
var inner_panel: PanelContainer
var hbox: HBoxContainer

var manipulator = GameManager.MANIPULATOR_MODES.PAGINATOR1


## Configures the internal layout container structure
func _ready() -> void:
	inner_panel = PanelContainer.new()
	inner_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	inner_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	add_child(inner_panel)
	if inner_panel_style:
		inner_panel.add_theme_stylebox_override("panel", inner_panel_style)
	if panel_style:
		add_theme_stylebox_override("panel", panel_style)
	hbox = HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	inner_panel.add_child(hbox)


## Receives the total amount of items, calculates limits, and rebuilds the UI
func setup_pagination(total: int) -> void:
	total_items = max(0, total)
	var total_pages = 1
	if items_per_page > 0:
		total_pages = max(1, int(ceil(total_items / float(items_per_page))))
	current_page = clampi(current_page, 0, total_pages - 1)
	_build_buttons(total_pages)


## Handles the internal page assignment and emits the signal to external listeners
func _set_page(page: int) -> void:
	var total_pages = 1
	if items_per_page > 0:
		total_pages = max(1, int(ceil(total_items / float(items_per_page))))
	var new_page = clampi(page, 0, total_pages - 1)
	if current_page != new_page:
		current_page = new_page
		_build_buttons(total_pages)
		page_changed.emit(current_page)


## Instantiates the appropriate button dynamically and maps its events
func _create_button(txt: String, target_page: int, is_disabled: bool) -> void:
	var btn: Node
	if custom_button:
		btn = custom_button.instantiate()
		if btn.has_method("set_text"):
			btn.call("set_text", txt)
		elif "text" in btn:
			btn.set("text", txt)
	else:
		btn = Button.new()
		btn.set("text", txt)
		btn.set("mouse_default_cursor_shape", Control.CURSOR_POINTING_HAND)
	if "disabled" in btn:
		btn.set("disabled", is_disabled)
	if btn.has_signal("pressed"):
		btn.connect("pressed", _set_page.bind(target_page))
	hbox.add_child(btn)


## Instantiates a navigation button wrapped in a zero-size Control and a full-rect MarginContainer forcing expansion
func _create_nav_button(txt: String, target_page: int, is_disabled: bool, custom_scene: PackedScene, margins: Vector4i) -> void:
	var ctrl = Control.new()
	var mc = MarginContainer.new()
	mc.set_anchors_preset(Control.PRESET_FULL_RECT)
	mc.add_theme_constant_override("margin_left", margins.x)
	mc.add_theme_constant_override("margin_top", margins.y)
	mc.add_theme_constant_override("margin_right", margins.z)
	mc.add_theme_constant_override("margin_bottom", margins.w)
	var btn: Node
	if custom_scene:
		btn = custom_scene.instantiate()
		if btn.has_method("set_text"):
			btn.call("set_text", txt)
		elif "text" in btn:
			btn.set("text", txt)
	else:
		btn = Button.new()
		btn.set("text", txt)
		btn.set("mouse_default_cursor_shape", Control.CURSOR_POINTING_HAND)
	if "disabled" in btn:
		btn.set("disabled", is_disabled)
	if btn.has_signal("pressed"):
		btn.connect("pressed", _set_page.bind(target_page))
	btn.set("size_flags_horizontal", Control.SIZE_EXPAND_FILL)
	btn.set("size_flags_vertical", Control.SIZE_EXPAND_FILL)
	mc.add_child(btn)
	ctrl.add_child(mc)
	hbox.add_child(ctrl)


## Computes the visible pagination sequence and clears old children
func _build_buttons(total_pages: int) -> void:
	while not hbox:
		await RenderingServer.frame_post_draw
	for c in hbox.get_children():
		c.queue_free()
	if total_pages <= 1:
		hide()
		return
	show()
	_create_nav_button("<", current_page - 1, current_page == 0, custom_prev_button, prev_button_margin)
	var start_p = max(0, current_page - 2)
	var end_p = min(total_pages - 1, current_page + 2)
	if end_p - start_p < 4:
		if start_p == 0:
			end_p = min(total_pages - 1, start_p + 4)
		elif end_p == total_pages - 1:
			start_p = max(0, end_p - 4)
	if start_p > 0:
		_create_button("1..", 0, false)
	for p in range(start_p, end_p + 1):
		_create_button(str(p + 1), p, p == current_page)
	if end_p < total_pages - 1:
		_create_button(".." + str(total_pages), total_pages - 1, false)
	_create_nav_button(">", current_page + 1, current_page == total_pages - 1, custom_next_button, next_button_margin)
