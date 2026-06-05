@tool
class_name AutotileEditorDialog
extends Window

## ItemList on the left containing the base autotile and alternatives
@export var items_list: ItemList

## Container for terrain and collision configuration tools
@export var tools_container: Control

## Container for animation speed and mode controls
@export var animation_container: Control

## ScrollContainer enclosing the responsive drawing canvas
@export var canvas_scroll: ScrollContainer

## Responsive Control node used to draw and paint individual tile states
@export var editor_canvas: Control

## SpinBox widget controlling the playback speed of the animation frames
@export var anim_speed_spinbox: SpinBox

## OptionButton widget controlling the animation playback mode loop
@export var anim_mode_options: OptionButton

## OptionButton widget choosing the collision configuration type
@export var collision_options: OptionButton

## LineEdit widget assigning custom terrain names to specific tiles
@export var terrain_name_input: LineEdit

## Button toggling the paint collision interaction mode
@export var paint_collision_button: BaseButton

## Button toggling the paint terrain interaction mode
@export var paint_terrain_button: BaseButton

## Label to display contextual help based on current tool states
@export var canvas_help_label: Label


var autotile_data: Dictionary = {}
var active_tile_size: Vector2i = Vector2i(32, 32)
var is_painting_collision: bool = false
var is_painting_terrain: bool = false
var zoom_level: float = 1.0
var snapped_mouse_pos: Vector2i = Vector2i(-1, -1)
var is_mouse_inside: bool = false



## Initializes the dialog controls and connects input/drawing signals
func _ready() -> void:
	close_requested.connect(_exit)
	
	if is_instance_valid(items_list):
		items_list.fixed_icon_size = Vector2i(48, 48)
		items_list.item_selected.connect(_on_item_selected)
		
	if is_instance_valid(editor_canvas):
		editor_canvas.draw.connect(_on_canvas_draw)
		editor_canvas.gui_input.connect(_on_canvas_gui_input)
		editor_canvas.mouse_entered.connect(_on_canvas_mouse_entered)
		editor_canvas.mouse_exited.connect(_on_canvas_mouse_exited)
		
	if is_instance_valid(paint_collision_button):
		paint_collision_button.toggled.connect(_on_paint_collision_toggled)
		
	if is_instance_valid(paint_terrain_button):
		paint_terrain_button.toggled.connect(_on_paint_terrain_toggled)
		
	if is_instance_valid(anim_speed_spinbox):
		anim_speed_spinbox.value_changed.connect(_on_anim_speed_changed)
		
	if is_instance_valid(anim_mode_options):
		anim_mode_options.item_selected.connect(_on_anim_mode_selected)



## Configures the internal data bindings and populates the items list
func setup_dialog(data: Dictionary, tile_size: Vector2i) -> void:
	autotile_data = data
	active_tile_size = tile_size
	zoom_level = 1.0
	
	items_list.clear()
	items_list.add_item(autotile_data.get("name", "Base Autotile"), autotile_data.get("image"))
	
	var alts: Array = autotile_data.get("alternatives", [])
	for i in alts.size():
		var alt_name: String = "Alternative " + str(i + 1)
		items_list.add_item(alt_name, alts[i].get("image"))
		
	if is_instance_valid(terrain_name_input):
		terrain_name_input.text = autotile_data.get("terrain", "")
		
	items_list.select(0)
	_on_item_selected(0)



## Evaluates global inputs for keyboard shortcuts ignoring events while typing
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var focus_owner: Control = get_viewport().gui_get_focus_owner()
		var is_typing: bool = is_instance_valid(focus_owner) and (focus_owner is LineEdit or focus_owner is TextEdit)
		
		if is_typing:
			return
			
		if event.keycode == KEY_C:
			if is_instance_valid(paint_collision_button):
				paint_collision_button.button_pressed = not paint_collision_button.button_pressed
		elif event.keycode == KEY_T:
			if is_instance_valid(paint_terrain_button):
				paint_terrain_button.button_pressed = not paint_terrain_button.button_pressed
		elif event.keycode == KEY_B:
			if is_instance_valid(paint_collision_button) and is_instance_valid(paint_terrain_button):
				var target_state: bool = not (paint_collision_button.button_pressed and paint_terrain_button.button_pressed)
				paint_collision_button.button_pressed = target_state
				paint_terrain_button.button_pressed = target_state



## Retrieves the corresponding texture mapped to the provided list index
func _get_texture_for_index(index: int) -> Texture2D:
	if index == 0:
		return autotile_data.get("image")
		
	var alts: Array = autotile_data.get("alternatives", [])
	if index - 1 < alts.size():
		return alts[index - 1].get("image")
		
	return null



## Updates the canvas minimum size based on current zoom and texture dimensions
func _update_canvas_size() -> void:
	var selected_items: PackedInt32Array = items_list.get_selected_items()
	if selected_items.is_empty():
		return
		
	var tex: Texture2D = _get_texture_for_index(selected_items[0])
	
	if tex:
		var new_size: Vector2 = tex.get_size() * zoom_level
		editor_canvas.custom_minimum_size = new_size
		editor_canvas.size = new_size



## Modifies the canvas scale variable enforcing sane limits
func _update_zoom(new_zoom: float) -> void:
	zoom_level = clampf(new_zoom, 0.5, 5.0)
	_update_canvas_size()
	editor_canvas.queue_redraw()



## Toggles the layout visibility and reactivity states based on current selection
func _update_layout(index: int) -> void:
	var target_data: Dictionary = autotile_data
	if index > 0:
		var alts: Array = autotile_data.get("alternatives", [])
		if index - 1 < alts.size():
			target_data = alts[index - 1]
			
	var is_anim: bool = target_data.get("is_animated", false)
	
	if is_instance_valid(tools_container):
		tools_container.visible = (index == 0)
		
	if is_instance_valid(animation_container):
		animation_container.visible = is_anim
		
		if is_anim:
			anim_speed_spinbox.set_value_no_signal(target_data.get("anim_speed", 5.0))
			anim_mode_options.select(target_data.get("anim_mode", 0))
			
	if index == 0:
		editor_canvas.mouse_filter = Control.MOUSE_FILTER_STOP
	else:
		editor_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
		
	_update_help_text()



## Refreshes the contextual help text dynamically informing the user of possible interactions
func _update_help_text() -> void:
	if not is_instance_valid(canvas_help_label):
		return
		
	var selected_items: PackedInt32Array = items_list.get_selected_items()
	if selected_items.is_empty():
		return
		
	if selected_items[0] > 0:
		canvas_help_label.text = "Canvas locked for alternatives. Use the properties panel to adjust animation settings."
		return
		
	var modes: Array[String] = []
	if is_painting_collision: modes.append("Collision")
	if is_painting_terrain: modes.append("Terrain")
	
	var mode_str: String = "None"
	if modes.size() > 0:
		mode_str = " + ".join(modes)
		
	canvas_help_label.text = "Painting: " + mode_str + "  |  Left Click: Paint  |  Right Click: Erase  |  C/T/B: Toggles  |  Ctrl+Wheel: Zoom"



## Handles item selection changes inside the left listing container
func _on_item_selected(index: int) -> void:
	_update_layout(index)
	_update_canvas_size()
	editor_canvas.queue_redraw()



## Draws the grid lines, painted custom data overlay, and blinking cursor applying current transforms
func _on_canvas_draw() -> void:
	var selected_items: PackedInt32Array = items_list.get_selected_items()
	if selected_items.is_empty():
		return
		
	var idx: int = selected_items[0]
	var tex: Texture2D = _get_texture_for_index(idx)
	
	if not tex:
		return
		
	editor_canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2(zoom_level, zoom_level))
	editor_canvas.draw_texture(tex, Vector2.ZERO)
	
	if idx != 0:
		editor_canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return
		
	var line_thickness: float = 1.0 / zoom_level
	var tex_size: Vector2 = tex.get_size()
	
	for x in range(0, int(tex_size.x) + 1, active_tile_size.x):
		editor_canvas.draw_line(Vector2(x, 0), Vector2(x, tex_size.y), Color(1.0, 1.0, 1.0, 0.3), line_thickness)
		
	for y in range(0, int(tex_size.y) + 1, active_tile_size.y):
		editor_canvas.draw_line(Vector2(0, y), Vector2(tex_size.x, y), Color(1.0, 1.0, 1.0, 0.3), line_thickness)
		
	var p_data: Dictionary = autotile_data.get("per_tile_data", {})
	for coord in p_data:
		var tile_rect: Rect2 = Rect2(Vector2(coord) * Vector2(active_tile_size), Vector2(active_tile_size))
		var data: Dictionary = p_data[coord]
		
		if data.get("col", 0) > 0:
			editor_canvas.draw_rect(tile_rect, Color(1.0, 0.2, 0.2, 0.4), true)
			editor_canvas.draw_rect(tile_rect, Color(1.0, 0.2, 0.2, 0.8), false, line_thickness)
			
		if not data.get("ter", "").is_empty():
			var inner_rect: Rect2 = tile_rect.grow(-4)
			editor_canvas.draw_rect(inner_rect, Color(0.2, 1.0, 0.2, 0.8), false, line_thickness)
			
	if is_mouse_inside and snapped_mouse_pos.x >= 0 and snapped_mouse_pos.y >= 0:
		var max_tiles: Vector2i = Vector2i(tex.get_width() / active_tile_size.x, tex.get_height() / active_tile_size.y)
		if snapped_mouse_pos.x < max_tiles.x and snapped_mouse_pos.y < max_tiles.y:
			var cursor_rect: Rect2 = Rect2(Vector2(snapped_mouse_pos) * Vector2(active_tile_size), Vector2(active_tile_size))
			editor_canvas.draw_rect(cursor_rect, Color(1.0, 0.8, 0.0, 0.8), false, 2.0 / zoom_level)
			editor_canvas.draw_rect(cursor_rect, Color(1.0, 0.8, 0.0, 0.2), true)
			
	editor_canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)



## Evaluates mouse clicks, zooming, and coordinate positioning to record painted tile details
func _on_canvas_gui_input(event: InputEvent) -> void:
	var selected_items: PackedInt32Array = items_list.get_selected_items()
	if selected_items.is_empty() or selected_items[0] != 0:
		return
		
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.ctrl_pressed and event.pressed:
			_update_zoom(zoom_level + 0.25)
			get_viewport().set_input_as_handled()
			return
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.ctrl_pressed and event.pressed:
			_update_zoom(zoom_level - 0.25)
			get_viewport().set_input_as_handled()
			return
			
	var scaled_pos: Vector2 = event.position / zoom_level
	var tile_coord: Vector2i = Vector2i(floor(scaled_pos.x / active_tile_size.x), floor(scaled_pos.y / active_tile_size.y))
	
	if event is InputEventMouseMotion:
		if tile_coord != snapped_mouse_pos:
			snapped_mouse_pos = tile_coord
			editor_canvas.queue_redraw()
			
	if event is InputEventMouseMotion or event is InputEventMouseButton:
		var tex: Texture2D = _get_texture_for_index(0)
		if not tex:
			return
			
		var max_tiles: Vector2i = Vector2i(tex.get_width() / active_tile_size.x, tex.get_height() / active_tile_size.y)
		if tile_coord.x < 0 or tile_coord.x >= max_tiles.x or tile_coord.y < 0 or tile_coord.y >= max_tiles.y:
			return
			
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed):
			if not autotile_data.has("per_tile_data"):
				autotile_data["per_tile_data"] = {}
				
			if not autotile_data["per_tile_data"].has(tile_coord):
				autotile_data["per_tile_data"][tile_coord] = {}
				
			if is_painting_collision:
				autotile_data["per_tile_data"][tile_coord]["col"] = collision_options.selected
				
			if is_painting_terrain:
				autotile_data["per_tile_data"][tile_coord]["ter"] = terrain_name_input.text
				
			editor_canvas.queue_redraw()
			
		elif Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) or (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed):
			if autotile_data.has("per_tile_data") and autotile_data["per_tile_data"].has(tile_coord):
				if is_painting_collision:
					autotile_data["per_tile_data"][tile_coord].erase("col")
					
				if is_painting_terrain:
					autotile_data["per_tile_data"][tile_coord].erase("ter")
					
				if autotile_data["per_tile_data"][tile_coord].is_empty():
					autotile_data["per_tile_data"].erase(tile_coord)
					
				editor_canvas.queue_redraw()



## Triggers internal logic when the cursor enters the rendering boundaries
func _on_canvas_mouse_entered() -> void:
	is_mouse_inside = true
	editor_canvas.queue_redraw()



## Triggers internal logic hiding the cursor when it leaves the rendering boundaries
func _on_canvas_mouse_exited() -> void:
	is_mouse_inside = false
	snapped_mouse_pos = Vector2i(-1, -1)
	editor_canvas.queue_redraw()



## Updates the internal painting flag state for collisions and refreshes UI feedback
func _on_paint_collision_toggled(button_pressed: bool) -> void:
	is_painting_collision = button_pressed
	_update_help_text()



## Updates the internal painting flag state for terrains and refreshes UI feedback
func _on_paint_terrain_toggled(button_pressed: bool) -> void:
	is_painting_terrain = button_pressed
	_update_help_text()



## Synchronizes the updated animation playback speed back to the data dictionary
func _on_anim_speed_changed(value: float) -> void:
	var selected_items: PackedInt32Array = items_list.get_selected_items()
	if selected_items.is_empty():
		return
		
	if selected_items[0] == 0:
		autotile_data["anim_speed"] = value
	else:
		var alts: Array = autotile_data.get("alternatives", [])
		var idx: int = selected_items[0] - 1
		if idx < alts.size():
			alts[idx]["anim_speed"] = value



## Synchronizes the updated animation playback mode loop parameter
func _on_anim_mode_selected(index: int) -> void:
	var selected_items: PackedInt32Array = items_list.get_selected_items()
	if selected_items.is_empty():
		return
		
	if selected_items[0] == 0:
		autotile_data["anim_mode"] = index
	else:
		var alts: Array = autotile_data.get("alternatives", [])
		var idx: int = selected_items[0] - 1
		if idx < alts.size():
			alts[idx]["anim_mode"] = index



## Standard manual dialog destruction wrapper
func _exit() -> void:
	queue_free()
