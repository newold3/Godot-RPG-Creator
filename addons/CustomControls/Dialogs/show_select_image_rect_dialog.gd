@tool
extends Window

@export var texture: Texture2D


var grid_size: Vector2 = Vector2(16, 16)
var real_region: Rect2
var current_region: Rect2
var zoom = 1.0
var dragging = false
var resizing = false
var resize_handle = ""
var start_pos = Vector2.ZERO
var current_pos = Vector2.ZERO
var handle_size = 8
var offset = Vector2.ZERO
var dragging_canvas = false
var last_mouse_pos = Vector2.ZERO
var grid_adjustment: bool = true
var bak_grid_adjustment: bool = true


@onready var canvas_container: Control = %CanvasContainer
@onready var canvas_grid: Control = %CanvasGrid
@onready var canvas_rect: Control = %CanvasRect


func _ready() -> void:
	%CanvasGrid.draw.connect(_on_grid_draw)
	%CanvasRect.draw.connect(_on_rect_draw)
	close_requested.connect(queue_free)
	
	%StepX.value = grid_size.x
	%StepY.value = grid_size.y
	
	await get_tree().process_frame

	offset = canvas_grid.size / 2
	
	%CanvasGrid.queue_redraw()


func _on_grid_draw() -> void:

	# Draw Grid
	var grid_step = grid_size * zoom
	var grid_start = Vector2(0, 0)
	var grid_end = canvas_grid.size
	
	var grid_color = Color(1, 1, 1, 0.2)
	for x in range(grid_start.x, grid_end.x + grid_step.x, grid_step.x):
		canvas_grid.draw_line(Vector2(x, grid_start.y), Vector2(x, grid_end.y), grid_color)
	for y in range(grid_start.y, grid_end.y + grid_step.y, grid_step.y):
		canvas_grid.draw_line(Vector2(grid_start.x, y), Vector2(grid_end.x, y), grid_color)
	
	# Draw texture
	if texture:
		var texture_size = texture.get_size()
		var scaled_size = texture_size * zoom
		var pos = offset - scaled_size / 2
		
		var rect = Rect2(pos, scaled_size)
		if grid_adjustment:
			rect = snap_rect_to_grid(rect)
		canvas_grid.draw_texture_rect(texture, rect, false)
		canvas_grid.draw_rect(rect, Color.WHITE, false)


func _on_rect_draw() -> void:
	pass


func snap_rect_to_grid(rect: Rect2) -> Rect2:
	rect.position.x = floor(rect.position.x / grid_size.x) * grid_size.x
	rect.position.y = floor(rect.position.y / grid_size.y) * grid_size.y

	rect.size.x = ceil(rect.size.x / grid_size.x) * grid_size.x
	rect.size.y = ceil(rect.size.y / grid_size.y) * grid_size.y

	return rect


func _on_step_x_value_changed(value: float) -> void:
	grid_size.x = value
	canvas_grid.queue_redraw()


func _on_step_y_value_changed(value: float) -> void:
	grid_size.y = value
	canvas_grid.queue_redraw()


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.pressed:
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				_zoom_at(event.position, zoom * 1.1)
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				_zoom_at(event.position, zoom * 0.9)
			elif event.button_index == MOUSE_BUTTON_MIDDLE:
				dragging_canvas = true
				last_mouse_pos = event.position
				bak_grid_adjustment = grid_adjustment
				grid_adjustment = false
		else:
			dragging_canvas = false
			grid_adjustment = bak_grid_adjustment

	elif event is InputEventMouseMotion and dragging_canvas:
		var delta = event.position - last_mouse_pos
		offset += delta
		last_mouse_pos = event.position
		canvas_grid.queue_redraw()


func _zoom_at(mouse_pos: Vector2, new_zoom: float) -> void:
	var old_zoom = zoom

	zoom = max(0.1, min(new_zoom, 25))
	
	var mouse_offset = mouse_pos - offset

	offset = mouse_pos - (mouse_offset * (zoom/old_zoom))
	
	canvas_grid.queue_redraw()
