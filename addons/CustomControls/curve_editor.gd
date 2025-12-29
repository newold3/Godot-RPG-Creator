@tool
extends Control

var curve : Curve = Curve.new()
var bake_resolution : int = 100
var max_value : float = 1.0
var min_value : float = 0.0

var curve_button = preload("res://addons/CustomControls/curve_editor_button.tscn")

var points : Array = []
var current_point : int

@onready var canvas: Control = %Canvas
@onready var canvas_buttons: Control = %CanvasButtons

signal point_updated(index : int)
signal point_removed(index : int)
signal point_selected(index : int)
signal point_added(index : int)



func _ready() -> void:
	canvas.draw.connect(_on_canvas_draw)
	canvas_buttons.gui_input.connect(_on_canvas_buttons_gui_input)
	item_rect_changed.connect(update_all)


func set_data(_points : Array, _min_value : float, _max_value : float, _bake_resolution : int) -> void:
	points = _points
	min_value = _min_value
	max_value = _max_value
	bake_resolution = _bake_resolution
	
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	
	update_all()


func add_points(_points : Array) -> void:
	points = _points


func request_update_all() -> void:
	update_all()


func update_all(index : int = -1):
	create_buttons()
	update_curve_points()
	refresh_all()
	if index != -1:
		select_point(index)


func refresh_all() -> void:
	queue_redraw()
	canvas.queue_redraw()


func create_buttons(current_point : Dictionary = {}) -> int:
	for child in canvas_buttons.get_children():
		child.queue_free()
	
	var s = canvas_buttons.size
	var t = Vector2(10, 10) # button mid size
	var current_index = -1
	points.sort_custom(_sort_points)
	var n = points.size()
	for i in n:
		var point : Vector2 = points[i].point
		var left : float = points[i].left
		var right : float = points[i].right
		var x = point.x * s.x - t.x
		var y = s.y - point.y * s.y - t.y
		var real_point = Vector2(x, y)
		var button = curve_button.instantiate()
		canvas_buttons.add_child(button)
		button.set_data(i, real_point, left, right, n)
		button.position_changed.connect(_on_button_position_changed)
		button.remove_point.connect(_on_remove_point)
		button.point_selected.connect(_on_curve_point_selected)
		button.name = "Button%s" % (i+1)
		if points[i].has("dragging"):
			points[i].erase("dragging")
			button.forcing_dragging = true
			button.click_position = button.position
			button.grab_focus()
			call_deferred("set_default_cursor_shape", Control.CURSOR_POINTING_HAND)
		
		if points[i] == current_point:
			current_index = i
	
	return current_index


func _on_remove_point(index : int) -> void:
	points.remove_at(index)
	create_buttons()
	update_curve_points()
	refresh_all()
	
	point_removed.emit(index)


func _on_curve_point_selected(index : int) -> void:
	var button = %CanvasButtons.get_child(index)
	point_selected.emit(index)


func _on_button_position_changed(index : int, position : Vector2, tangent_left : float, tangent_right : float) -> void:
	var s = canvas_buttons.size
	var x = remap(position.x, 0, canvas_buttons.size.x, min_value, max_value)
	var y = remap(s.y - position.y, 0, canvas_buttons.size.y, min_value, max_value)
	curve.set_point_value(index, y)
	curve.set_point_left_tangent(index, tangent_left)
	curve.set_point_right_tangent(index, tangent_right)
	points[index].point = Vector2(x, y)
	points[index].left = tangent_left
	points[index].right = tangent_right

	fix_buttons()
	update_curve_points()
	refresh_all()
	
	point_updated.emit(index)


func fix_buttons() -> void:
	points.sort_custom(_sort_points)
	var buttons = canvas_buttons.get_children()
	buttons.sort_custom(buttons_sort_points)
	for i in buttons.size():
		buttons[i].index = i
		canvas_buttons.move_child(buttons[i], i)


func _sort_points(a, b) -> bool:
	return a.point.x < b.point.x


func buttons_sort_points(a, b) -> bool:
	return a.position.x < b.position.x 


func _on_canvas_buttons_gui_input(event : InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
		insert_point_in(event.position)


func insert_point_in(position : Vector2) -> void:
	var n = points.size()
	var s = canvas_buttons.size
	var t = Vector2(10, 10) # button mid size
	var current_position = 0
	var last_min_distance : float = INF
	for i in n:
		var point = curve.get_point_position(i)
		var x = point.x * s.x - t.x
		var y = s.y - point.y * s.y - t.y
		var real_point = Vector2(x, y)
		var p = real_point.distance_squared_to(position)
		if p <= last_min_distance:
			last_min_distance = p
			current_position = i
	
	var x = remap(position.x, 0, canvas_buttons.size.x, min_value, max_value)
	var y = remap(s.y - position.y, 0, canvas_buttons.size.y, min_value, max_value)
	var new_point = {
		"point" : Vector2(x, y),
		"left" : 0.0,
		"right" : 0.0,
		"dragging" : true
	}
	points.insert(current_position, new_point)
	
	current_position = create_buttons(new_point)
	
	update_curve_points()
	
	point_added.emit(current_position)


func update_curve_points() -> void:
	var n = points.size()
	var s = canvas_buttons.size
	var t = Vector2(10, 10) # button mid size
	
	curve.clear_points()
	for i in n:
		curve.add_point(points[i].point, points[i].left, points[i].right)
	
	refresh_all()


func _on_canvas_draw() -> void:
	var v = PackedVector2Array()
	var s = canvas.size
	var t = Vector2(10, 10) # button mid size
	curve.bake()
	for i in range(0, 101):
		var offset : float = i / 100.0
		var value = curve.sample(offset)
		var x = remap(i, 0, 100, t.x, s.x - t.x)
		var y = s.y - remap(value, min_value, max_value, 0, s.y)
		v.append(Vector2(x, y))
	canvas.draw_polyline(v, Color.WHITE, 2)


func select_point(index : int) -> void:
	for button in canvas_buttons.get_children():
		if button.index == index:
			button.grab_focus()
			break
