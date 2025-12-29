@tool
class_name FitContainer
extends Container

## Contenedor especial que encaja los hijos al contenedor (cambiando su escala
## si hace falta manteniendo un aspect_ratio, permite hacer zoom al ratón y
## cambiar la posicion de sus hijos moviendo el ratón con la rueda del raton pulsada

## Define si el contenedor debe mantener una relación de aspecto específica
@export var maintain_aspect_ratio: bool = true
## Relación de aspecto deseada (ancho:alto)
@export_range(0.1, 10.0, 0.01) var aspect_ratio: float = 16.0 / 9.0
## Habilita la manipulación interactiva (zoom, pan)
@export var enable_manipulation: bool = false
## Velocidad del zoom con la rueda del ratón
@export_range(0.01, 1.0, 0.01) var zoom_speed: float = 0.1
## Escala mínima permitida
@export_range(0.1, 1.0, 0.01) var min_scale: float = 0.1
## Escala máxima permitida
@export_range(1.0, 10.0, 0.1) var max_scale: float = 5.0

# Variables para el manejo de la interacción
var _dragging: bool = false
var _last_mouse_pos: Vector2 = Vector2.ZERO
var _custom_scale: float = 1.0
var _offset: Vector2 = Vector2.ZERO

func _ready() -> void:
	# Asegurar que el contenedor pueda recibir eventos de entrada
	if enable_manipulation:
		mouse_filter = Control.MOUSE_FILTER_STOP
	else:
		mouse_filter = Control.MOUSE_FILTER_PASS
	
	gui_input.connect(_on_gui_input)
	
	set_process_input(enable_manipulation)

func reset() -> void:
	_custom_scale = 1.0
	_offset = Vector2.ZERO
	queue_sort()

func _notification(what: int) -> void:
	if what == NOTIFICATION_SORT_CHILDREN:
		_update_children()
	elif what == NOTIFICATION_VISIBILITY_CHANGED:
		# Actualizar el filtro de ratón cuando cambia la visibilidad
		if enable_manipulation:
			mouse_filter = Control.MOUSE_FILTER_STOP
		else:
			mouse_filter = Control.MOUSE_FILTER_PASS

func _update_children() -> void:
	for child in get_children():
		# Calcular la escala necesaria para mantener la relación de aspecto
		var target_size = Vector2(size)
		
		if maintain_aspect_ratio:
			# Calcular dimensiones con relación de aspecto 16:9
			var current_ratio = size.x / size.y
			
			if current_ratio > aspect_ratio:
				# Demasiado ancho, ajustar por altura
				target_size.x = size.y * aspect_ratio
			else:
				# Demasiado alto, ajustar por ancho
				target_size.y = size.x / aspect_ratio
		
		# Calcular la escala para el hijo
		var scale_factor = Vector2.ONE
		
		if child.size.x > 0 and child.size.y > 0:
			scale_factor = target_size / child.size
			
			# Usar la escala más pequeña para asegurar que quepa completo
			if scale_factor.x < scale_factor.y:
				scale_factor.y = scale_factor.x
			else:
				scale_factor.x = scale_factor.y
		
		# Aplicar el zoom personalizado
		scale_factor *= _custom_scale
		
		# Aplicar la escala
		child.scale = scale_factor
		
		# Calcular el tamaño escalado del hijo
		var child_size_scaled = child.size * scale_factor
		
		# Limitar el offset para que el contenido no salga del contenedor
		_clamp_offset(child_size_scaled)
		
		# Centrar el hijo en el contenedor con el offset de desplazamiento
		child.position = (size - child_size_scaled) / 2.0 + _offset

func _clamp_offset(child_size_scaled: Vector2) -> void:
	# Si el zoom es <= 1, no permitir desplazamiento
	if _custom_scale <= 1.0:
		_offset = Vector2.ZERO
		return
	
	# Calcular los límites máximos de desplazamiento
	var max_offset = (child_size_scaled - size) / 2.0
	
	# Si el hijo es más pequeño que el contenedor en alguna dimensión,
	# no permitir desplazamiento en esa dimensión
	if child_size_scaled.x <= size.x:
		_offset.x = 0
	else:
		_offset.x = clamp(_offset.x, -max_offset.x, max_offset.x)
	
	if child_size_scaled.y <= size.y:
		_offset.y = 0
	else:
		_offset.y = clamp(_offset.y, -max_offset.y, max_offset.y)

func _on_gui_input(event: InputEvent) -> void:
	if not enable_manipulation:
		return
	
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			# Zoom in
			_zoom_at_position(1.0 + zoom_speed, event.position)
			get_viewport().set_input_as_handled()
		
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			# Zoom out
			_zoom_at_position(1.0 - zoom_speed, event.position)
			get_viewport().set_input_as_handled()
		
		elif event.button_index == MOUSE_BUTTON_MIDDLE:
			# Iniciar/detener arrastre con botón central
			_dragging = event.pressed
			_last_mouse_pos = event.position
			get_viewport().set_input_as_handled()
	
	elif event is InputEventMouseMotion and _dragging:
		# Solo permitir arrastre si el zoom es > 1
		if _custom_scale > 1.0:
			# Calcular el desplazamiento
			var delta = event.position - _last_mouse_pos
			_offset += delta
			_last_mouse_pos = event.position
			
			# Actualizar los hijos con el nuevo offset (con limitaciones)
			queue_sort()
			get_viewport().set_input_as_handled()
		else:
			# Si el zoom es <= 1, no permitir desplazamiento
			_last_mouse_pos = event.position

func _zoom_at_position(zoom_factor: float, mouse_pos: Vector2) -> void:
	# Calcular la posición relativa del ratón respecto al centro del contenedor
	var viewport_center = size / 2.0
	var mouse_from_center = mouse_pos - viewport_center - _offset
	
	# Guardar la escala anterior para cálculos
	var old_scale = _custom_scale
	
	# Calcular la nueva escala, limitada por min_scale y max_scale
	_custom_scale *= zoom_factor
	_custom_scale = clamp(_custom_scale, min_scale, max_scale)
	
	# Ajustar el offset para que el zoom sea relativo a la posición del ratón
	if old_scale != _custom_scale:  # Solo si la escala realmente cambió
		var zoom_offset = mouse_from_center * (1.0 - (_custom_scale / old_scale))
		_offset += zoom_offset
	
	# Actualizar los hijos (esto también aplicará las limitaciones de offset)
	queue_sort()

# Método para resetear la manipulación (zoom y pan)
func reset_manipulation() -> void:
	_custom_scale = 1.0
	_offset = Vector2.ZERO
	queue_sort()

# Actualiza la configuración de manipulación en tiempo de ejecución
func set_manipulation_enabled(enabled: bool) -> void:
	enable_manipulation = enabled
	if enable_manipulation:
		mouse_filter = Control.MOUSE_FILTER_STOP
	else:
		mouse_filter = Control.MOUSE_FILTER_PASS
	set_process_input(enable_manipulation)
	
	# Resetear si se desactiva
	if not enable_manipulation:
		reset_manipulation()
