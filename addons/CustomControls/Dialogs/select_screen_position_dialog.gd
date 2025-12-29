@tool
extends Window

static var grid_mode: bool = false
static var grid_cell_size: float = 50.0
static var default_timer: float


@onready var use_grid: CheckBox = %UseGrid
@onready var grid_size: SpinBox = %GridSize
@onready var canvas1: Control = %Canvas1
@onready var canvas2: Control = %Canvas2
@onready var position_label: Label = %PositionLabel

signal position_selected(pos: Vector2, wait_time: float)


func _ready():
	close_requested.connect(queue_free)
	canvas1.draw.connect(_on_canvas1_draw)
	canvas2.draw.connect(_on_canvas2_draw)
	canvas2.gui_input.connect(_on_canvas2_gui_input)
	canvas2.mouse_exited.connect(canvas2.queue_redraw)

	use_grid.set_pressed(grid_mode)
	grid_size.value = grid_cell_size
	
	%GridSize.set_disabled(!grid_mode)
	%Time.value = default_timer


func set_data(time: float) -> void:
	%Time.value = time
	default_timer = time


func _on_canvas1_draw():
	if grid_mode:
		var canvas_size = canvas1.size
		
		var grid_color = Color(0.7, 0.7, 0.7, 0.5)
		
		# Dibujar líneas verticales
		for x in range(0, int(canvas_size.x), int(grid_cell_size)):
			canvas1.draw_line(Vector2(x, 0), Vector2(x, canvas_size.y), grid_color, 1.0)
		
		# Dibujar líneas horizontales
		for y in range(0, int(canvas_size.y), int(grid_cell_size)):
			canvas1.draw_line(Vector2(0, y), Vector2(canvas_size.x, y), grid_color, 1.0)


func _on_canvas2_draw():
	if not canvas2.get_global_rect().has_point(canvas2.get_global_mouse_position()):
		return
		
	var mouse_pos = canvas2.get_local_mouse_position()
	
	if grid_mode:
		mouse_pos = snap_to_grid(mouse_pos)
	
	var cross_color = Color.RED
	var cross_length = 10
	
	canvas2.draw_line(
		Vector2(mouse_pos.x - cross_length, mouse_pos.y),
		Vector2(mouse_pos.x + cross_length, mouse_pos.y),
		cross_color,
		2.0
	)
	
	canvas2.draw_line(
		Vector2(mouse_pos.x, mouse_pos.y - cross_length),
		Vector2(mouse_pos.x, mouse_pos.y + cross_length),
		cross_color,
		2.0
	)

func snap_to_grid(pos: Vector2) -> Vector2:
	return Vector2(
		floor(pos.x / grid_cell_size) * grid_cell_size,
		floor(pos.y / grid_cell_size) * grid_cell_size
	) + Vector2(grid_cell_size, grid_cell_size) * 0.5


func _update_canvas_draw() -> void:
	var pos = canvas2.get_local_mouse_position()
	var pos_str = str(Vector2i(pos if not grid_mode else snap_to_grid(pos)))
	position_label.text = "Position: %s" % pos_str
	canvas2.queue_redraw()


func _on_canvas2_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_update_canvas_draw()
	elif event.is_action_pressed("Mouse Left"):
		propagate_call("apply")
		var pos = canvas2.get_local_mouse_position()
		var final_pos = pos if not grid_mode else snap_to_grid(pos)
		position_selected.emit(final_pos, default_timer)
		queue_free()


func _on_use_grid_toggled(toggled_on: bool) -> void:
	grid_mode = toggled_on
	%GridSize.set_disabled(!grid_mode)
	canvas1.queue_redraw()


func _on_grid_size_value_changed(value: float) -> void:
	grid_cell_size = value
	canvas1.queue_redraw()


func _on_time_value_changed(value: float) -> void:
	default_timer = value
