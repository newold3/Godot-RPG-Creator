@tool
extends Control


## Color de la línea de la curva
@export var line_color: Color = Color(0.2, 0.7, 1.0)

## Color de la cuadrícula de fondo
@export var grid_color: Color = Color(0.3, 0.3, 0.3, 0.4)

## Grosor de la línea
@export var line_width: float = 2.0

var _data: Array = []


## Recibe el array de datos actualizados y solicita el repintado del control
func draw_curve(data: Array) -> void:
	_data = data
	queue_redraw()


func _draw() -> void:
	var rect_size: Vector2 = get_rect().size
	if rect_size.x <= 0 or rect_size.y <= 0:
		return
	
	# Dibujar fondo y marco
	draw_rect(Rect2(Vector2.ZERO, rect_size), Color(0.1, 0.1, 0.15, 0.8), true)
	draw_rect(Rect2(Vector2.ZERO, rect_size), grid_color, false, 1.0)
	
	# Dibujar cuadrícula de referencia (3 líneas horizontales y 3 verticales)
	for i in range(1, 4):
		var x: float = (rect_size.x / 4.0) * i
		var y: float = (rect_size.y / 4.0) * i
		draw_line(Vector2(x, 0), Vector2(x, rect_size.y), grid_color, 1.0)
		draw_line(Vector2(0, y), Vector2(rect_size.x, y), grid_color, 1.0)
	
	if _data.size() < 2:
		return
	
	var max_levels: int = _data.size() - 1
	var min_val: float = _data[0]
	var max_val: float = _data[max_levels]
	var range_val: float = max_val - min_val
	
	if range_val <= 0:
		range_val = 1.0
	
	# Construir los puntos en coordenadas del canvas (eje Y invertido)
	var points: PackedVector2Array = []
	for i in range(_data.size()):
		var t_x: float = float(i) / float(max_levels)
		var t_y: float = (_data[i] - min_val) / range_val
		
		var px: float = t_x * rect_size.x
		var py: float = rect_size.y - (t_y * rect_size.y)
		points.append(Vector2(px, py))
	
	# Dibujar la curva continua
	draw_polyline(points, line_color, line_width, true)
	
	# Dibujar puntos en cada nivel
	for pt in points:
		draw_circle(pt, 3.0, line_color)
