@tool
extends Control
class_name EditableRectControl

# Variables internas
var _rect_position: Vector2 = Vector2(50, 50)
var _rect_size: Vector2 = Vector2(200, 150)
var _margin: int = 10
var _is_updating_size: bool = false # Flag para evitar recursión en el setter
var flip_horizontal: bool = false :
	set(value):
		flip_horizontal = value
		queue_redraw()
var flip_vertical: bool = true :
	set(value):
		flip_vertical = value
		queue_redraw()

# --- PROPIEDADES CON SETTERS CORREGIDOS ---

@export var rect_position: Vector2 = Vector2(50, 50):
	set(value):
		_rect_position = value
		if is_inside_tree():
			_clamp_rect()
			queue_redraw()
	get:
		return _rect_position

@export var rect_size: Vector2 = Vector2(200, 150):
	set(value):
		# Si esta es una llamada recursiva para actualizar el otro componente,
		# simplemente actualizamos la variable interna y salimos.
		if _is_updating_size:
			_rect_size = value
			return

		var old_size = _rect_size
		_rect_size = value

		# --- LÓGICA DE ACTUALIZACIÓN DEL INSPECTOR CORREGIDA ---
		# Si estamos en el editor, con aspect ratio y el tamaño realmente cambió...
		if Engine.is_editor_hint() and keep_aspect_ratio and value != old_size:
			var img = _get_image()
			if img:
				_is_updating_size = true # Bloqueamos para la llamada recursiva
				var aspect_ratio = img.get_size().x / float(img.get_size().y)
				var new_size = value

				# Si el ancho cambió, calculamos el nuevo alto.
				if not is_equal_approx(value.x, old_size.x):
					new_size.y = value.x / aspect_ratio
				# Si el alto cambió, calculamos el nuevo ancho.
				elif not is_equal_approx(value.y, old_size.y):
					new_size.x = value.y * aspect_ratio
				
				# REASIGNAMOS EL VECTOR COMPLETO. Esto es crucial.
				# Dispara el setter de nuevo, pero _is_updating_size lo detendrá.
				rect_size = new_size
				notify_property_list_changed()
				
				_is_updating_size = false # Desbloqueamos

		# El clamp y redraw se ejecutan después de que el tamaño esté corregido.
		if is_inside_tree():
			_clamp_rect()
			queue_redraw()
	get:
		return _rect_size


@export_range(-20, 50, 1) var margin: int = 10:
	set(value):
		_margin = value
		if is_inside_tree():
			_clamp_rect()
			queue_redraw()
	get:
		return _margin

@export_group("Colors")
@export var rect_color: Color = Color(0.3, 0.5, 0.8, 0.3):
	set(value):
		rect_color = value
		if is_inside_tree(): queue_redraw()

@export var border_color: Color = Color(0.3, 0.5, 0.8, 1.0):
	set(value):
		border_color = value
		if is_inside_tree(): queue_redraw()

@export var handle_color: Color = Color(1.0, 1.0, 1.0, 1.0):
	set(value):
		handle_color = value
		if is_inside_tree(): queue_redraw()

@export var handle_border_color: Color = Color(0.2, 0.2, 0.2, 1.0):
	set(value):
		handle_border_color = value
		if is_inside_tree(): queue_redraw()

@export_group("Background")
@export var background_texture: Texture2D = null:
	set(value):
		background_texture = value
		if is_inside_tree(): queue_redraw()

@export var keep_aspect_ratio: bool = false:
	set(value):
		if keep_aspect_ratio == value: return
		keep_aspect_ratio = value
		if is_inside_tree():
			if value:
				# Al activar, ajustamos el rect_size respetando el lado mayor
				var img = _get_image()
				if img and img.get_size().y > 0:
					var aspect_ratio = img.get_size().x / float(img.get_size().y)
					var current_aspect = _rect_size.x / _rect_size.y
					var new_size = _rect_size
					
					# Determinar qué lado cambió más respecto al aspect ratio correcto
					# Si el aspect actual es mayor que el deseado, significa que el ancho es proporcionalmente mayor
					if current_aspect > aspect_ratio:
						# El ancho es el lado dominante, ajustar el alto
						new_size.y = new_size.x / aspect_ratio
					else:
						# El alto es el lado dominante, ajustar el ancho
						new_size.x = new_size.y * aspect_ratio
					
					# Mantener la posición del centro
					var center = _rect_position + _rect_size / 2.0
					_rect_size = new_size
					_rect_position = center - new_size / 2.0
					
					_clamp_rect()
			queue_redraw()

# El resto del script permanece igual...
var _target_image: Texture2D = null
const HANDLE_SIZE: int = 8
const BORDER_WIDTH: float = 2.0
enum DragMode { NONE, MOVE, RESIZE_TL, RESIZE_TR, RESIZE_BL, RESIZE_BR, RESIZE_T, RESIZE_B, RESIZE_L, RESIZE_R }
var current_drag_mode: DragMode = DragMode.NONE
var drag_start_pos: Vector2 = Vector2.ZERO
var rect_start_pos: Vector2 = Vector2.ZERO
var rect_start_size: Vector2 = Vector2.ZERO

func _get_image() -> Texture2D:
	return _target_image if _target_image != null else background_texture

func _get_visual_rect() -> Rect2:
	var img = _get_image()
	if keep_aspect_ratio and img != null and img.get_size().y > 0:
		var aspect_ratio = img.get_size().x / float(img.get_size().y)
		var center = _rect_position + _rect_size / 2.0
		var visual_size = Vector2(_rect_size.x, _rect_size.x / aspect_ratio)
		var visual_pos = center - visual_size / 2.0
		return Rect2(visual_pos, visual_size)
	else:
		return Rect2(_rect_position, _rect_size)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_clamp_rect()

func _draw() -> void:
	var visual_rect = _get_visual_rect()
	var image_to_draw = _get_image()
	if image_to_draw != null:
		var texture_rect = visual_rect
		if flip_horizontal: texture_rect.size.x *= -1
		if flip_vertical: texture_rect.size.y *= -1
		draw_texture_rect(image_to_draw, texture_rect, false)
	draw_rect(visual_rect, rect_color)
	draw_rect(visual_rect, border_color, false, BORDER_WIDTH)
	for mode in [DragMode.RESIZE_TL, DragMode.RESIZE_TR, DragMode.RESIZE_BL, DragMode.RESIZE_BR, DragMode.RESIZE_T, DragMode.RESIZE_B, DragMode.RESIZE_L, DragMode.RESIZE_R]:
		_draw_handle(_get_handle_rect(mode, visual_rect))

func _draw_handle(handle_rect: Rect2) -> void:
	draw_rect(handle_rect, handle_color)
	draw_rect(handle_rect, handle_border_color, false, 1.0)

func _get_handle_rect(mode: DragMode, base_rect: Rect2) -> Rect2:
	var half_size = HANDLE_SIZE / 2.0
	var pos = Vector2.ZERO
	match mode:
		DragMode.RESIZE_TL: pos = base_rect.position
		DragMode.RESIZE_TR: pos = base_rect.position + Vector2(base_rect.size.x, 0)
		DragMode.RESIZE_BL: pos = base_rect.position + Vector2(0, base_rect.size.y)
		DragMode.RESIZE_BR: pos = base_rect.position + base_rect.size
		DragMode.RESIZE_T:  pos = base_rect.position + Vector2(base_rect.size.x / 2, 0)
		DragMode.RESIZE_B:  pos = base_rect.position + Vector2(base_rect.size.x / 2, base_rect.size.y)
		DragMode.RESIZE_L:  pos = base_rect.position + Vector2(0, base_rect.size.y / 2)
		DragMode.RESIZE_R:  pos = base_rect.position + Vector2(base_rect.size.x, base_rect.size.y / 2)
	return Rect2(pos - Vector2.ONE * half_size, Vector2.ONE * HANDLE_SIZE)

func _get_drag_mode_at_position(pos: Vector2) -> DragMode:
	var visual_rect = _get_visual_rect()
	for mode in [DragMode.RESIZE_TL, DragMode.RESIZE_TR, DragMode.RESIZE_BL, DragMode.RESIZE_BR, DragMode.RESIZE_T, DragMode.RESIZE_B, DragMode.RESIZE_L, DragMode.RESIZE_R]:
		if _get_handle_rect(mode, visual_rect).has_point(pos): return mode
	if visual_rect.has_point(pos): return DragMode.MOVE
	return DragMode.NONE

func _gui_input(event: InputEvent) -> void:
	# Manejo de la rueda del ratón para zoom proporcional centrado
	if event is InputEventMouseButton and (event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN):
		var visual_rect = _get_visual_rect()
		if visual_rect.has_point(event.position):
			var zoom_factor = 1.1 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 0.9
			
			# Calcular el centro actual del rect visual
			var center = visual_rect.position + visual_rect.size / 2.0
			
			# Calcular nuevo tamaño
			var new_size = _rect_size * zoom_factor
			new_size.x = max(new_size.x, 30.0)
			
			# Si keep_aspect_ratio está activo, ajustar el alto también
			if keep_aspect_ratio:
				var img = _get_image()
				if img and img.get_size().y > 0:
					var aspect_ratio = img.get_size().x / float(img.get_size().y)
					new_size.y = new_size.x / aspect_ratio
			else:
				new_size.y = max(new_size.y, 30.0)
			
			# Aplicar el nuevo tamaño (esto actualizará _rect_size y _rect_position para centrar)
			_rect_size = new_size
			_rect_position = center - new_size / 2.0
			
			_clamp_rect()
			queue_redraw()
			accept_event()
			return
	
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			current_drag_mode = _get_drag_mode_at_position(event.position)
			if current_drag_mode != DragMode.NONE:
				drag_start_pos = event.position
				rect_start_pos = _rect_position
				rect_start_size = _rect_size
		else:
			current_drag_mode = DragMode.NONE
	elif event is InputEventMouseMotion:
		if current_drag_mode != DragMode.NONE:
			var delta = event.position - drag_start_pos
			match current_drag_mode:
				DragMode.MOVE:    
					_rect_position = rect_start_pos + delta
				DragMode.RESIZE_TL: 
					_resize_from_corner(delta, true, true)
				DragMode.RESIZE_TR: 
					_resize_from_corner(delta, false, true)
				DragMode.RESIZE_BL: 
					_resize_from_corner(delta, true, false)
				DragMode.RESIZE_BR: 
					_resize_from_corner(delta, false, false)
				DragMode.RESIZE_T:  
					_resize_from_edge(delta, false, true)
				DragMode.RESIZE_B:  
					_resize_from_edge(delta, false, false)
				DragMode.RESIZE_L:  
					_resize_from_edge(delta, true, true)
				DragMode.RESIZE_R:  
					_resize_from_edge(delta, true, false)
			_clamp_rect()
			queue_redraw()
		else:
			mouse_default_cursor_shape = _get_cursor_shape(_get_drag_mode_at_position(event.position))

func _resize_from_corner(delta: Vector2, left: bool, top: bool) -> void:
	var min_size = 30.0
	
	if keep_aspect_ratio:
		var img = _get_image()
		if img and img.get_size().y > 0:
			var aspect_ratio = img.get_size().x / float(img.get_size().y)
			
			# Calcular el punto de pivote (esquina opuesta)
			var pivot = Vector2.ZERO
			if left:
				pivot.x = rect_start_pos.x + rect_start_size.x
			else:
				pivot.x = rect_start_pos.x
			if top:
				pivot.y = rect_start_pos.y + rect_start_size.y
			else:
				pivot.y = rect_start_pos.y
			
			# Determinar cuál dimensión está cambiando más
			var horizontal_change = abs(delta.x)
			var vertical_change = abs(delta.y)
			
			var new_width: float
			var new_height: float
			
			# Usar el cambio dominante para calcular el nuevo tamaño
			if horizontal_change > vertical_change:
				# Cambio horizontal es dominante
				if left:
					new_width = rect_start_size.x - delta.x
				else:
					new_width = rect_start_size.x + delta.x
				new_width = max(new_width, min_size)
				new_height = new_width / aspect_ratio
			else:
				# Cambio vertical es dominante
				if top:
					new_height = rect_start_size.y - delta.y
				else:
					new_height = rect_start_size.y + delta.y
				new_height = max(new_height, min_size)
				new_width = new_height * aspect_ratio
			
			# Actualizar tamaño
			_rect_size = Vector2(new_width, new_height)
			
			# Actualizar posición basándose en el pivote
			if left:
				_rect_position.x = pivot.x - new_width
			else:
				_rect_position.x = pivot.x
			if top:
				_rect_position.y = pivot.y - new_height
			else:
				_rect_position.y = pivot.y
			
			return
	
	# Modo sin aspect ratio (código original)
	if left:
		var new_x = rect_start_pos.x + delta.x
		_rect_position.x = new_x
		_rect_size.x = rect_start_pos.x + rect_start_size.x - _rect_position.x
		if _rect_size.x < min_size: 
			_rect_size.x = min_size
			_rect_position.x = rect_start_pos.x + rect_start_size.x - min_size
	else:
		_rect_size.x = max(rect_start_size.x + delta.x, min_size)
	
	if top:
		var new_y = rect_start_pos.y + delta.y
		_rect_position.y = new_y
		_rect_size.y = rect_start_pos.y + rect_start_size.y - _rect_position.y
		if _rect_size.y < min_size: 
			_rect_size.y = min_size
			_rect_position.y = rect_start_pos.y + rect_start_size.y - min_size
	else:
		_rect_size.y = max(rect_start_size.y + delta.y, min_size)

func _resize_from_edge(delta: Vector2, horizontal: bool, negative_side: bool) -> void:
	var min_size = 30.0
	
	if keep_aspect_ratio:
		var img = _get_image()
		if img and img.get_size().y > 0:
			var aspect_ratio = img.get_size().x / float(img.get_size().y)
			
			# Calcular el centro original
			var center = rect_start_pos + rect_start_size / 2.0
			
			var new_width: float
			var new_height: float
			
			if horizontal:
				# Cambio horizontal
				if negative_side: # Left
					new_width = rect_start_size.x - delta.x
				else: # Right
					new_width = rect_start_size.x + delta.x
				new_width = max(new_width, min_size)
				new_height = new_width / aspect_ratio
			else:
				# Cambio vertical
				if negative_side: # Top
					new_height = rect_start_size.y - delta.y
				else: # Bottom
					new_height = rect_start_size.y + delta.y
				new_height = max(new_height, min_size)
				new_width = new_height * aspect_ratio
			
			# Actualizar tamaño
			_rect_size = Vector2(new_width, new_height)
			
			# Mantener el centro
			_rect_position = center - _rect_size / 2.0
			
			return
	
	# Modo sin aspect ratio (código original)
	if horizontal:
		if negative_side: # Left
			var new_x = rect_start_pos.x + delta.x
			_rect_position.x = new_x
			_rect_size.x = rect_start_pos.x + rect_start_size.x - _rect_position.x
			if _rect_size.x < min_size: 
				_rect_size.x = min_size
				_rect_position.x = rect_start_pos.x + rect_start_size.x - min_size
		else: # Right
			_rect_size.x = max(rect_start_size.x + delta.x, min_size)
	else:
		if negative_side: # Top
			var new_y = rect_start_pos.y + delta.y
			_rect_position.y = new_y
			_rect_size.y = rect_start_pos.y + rect_start_size.y - _rect_position.y
			if _rect_size.y < min_size: 
				_rect_size.y = min_size
				_rect_position.y = rect_start_pos.y + rect_start_size.y - min_size
		else: # Bottom
			_rect_size.y = max(rect_start_size.y + delta.y, min_size)

func _clamp_rect() -> void:
	var min_s = Vector2(30, 30)
	_rect_size.x = max(_rect_size.x, min_s.x)
	_rect_size.y = max(_rect_size.y, min_s.y)
	
	# Calcular el rect visual (el que realmente se muestra)
	var visual_rect = _get_visual_rect()
	
	# Límites del área disponible
	var max_x = size.x - _margin
	var max_y = size.y - _margin
	
	# Ajustar posición basándose en el rect visual
	var visual_left = visual_rect.position.x
	var visual_top = visual_rect.position.y
	var visual_right = visual_rect.position.x + visual_rect.size.x
	var visual_bottom = visual_rect.position.y + visual_rect.size.y
	
	# Calcular el desplazamiento necesario
	var offset = Vector2.ZERO
	
	if visual_left < _margin:
		offset.x = _margin - visual_left
	elif visual_right > max_x:
		offset.x = max_x - visual_right
	
	if visual_top < _margin:
		offset.y = _margin - visual_top
	elif visual_bottom > max_y:
		offset.y = max_y - visual_bottom
	
	# Aplicar el desplazamiento a _rect_position
	_rect_position += offset
	
	notify_property_list_changed()

func _get_cursor_shape(mode: DragMode) -> Control.CursorShape:
	match mode:
		DragMode.MOVE: return Control.CURSOR_MOVE
		DragMode.RESIZE_TL, DragMode.RESIZE_BR: return Control.CURSOR_FDIAGSIZE
		DragMode.RESIZE_TR, DragMode.RESIZE_BL: return Control.CURSOR_BDIAGSIZE
		DragMode.RESIZE_T, DragMode.RESIZE_B: return Control.CURSOR_VSIZE
		DragMode.RESIZE_L, DragMode.RESIZE_R: return Control.CURSOR_HSIZE
		_: return Control.CURSOR_ARROW

func set_preset(preset: Dictionary) -> void:
	if preset.is_empty():
		return

	if preset.has("enable_aspect_ratio"):
		keep_aspect_ratio = preset.enable_aspect_ratio

	if preset.has("flip_horizontal"):
		flip_horizontal = preset.flip_horizontal

	if preset.has("flip_vertical"):
		flip_vertical = preset.flip_vertical

	if preset.has("width") and preset.has("height"):
		rect_size = Vector2(preset.width, preset.height)

	if preset.has("x") and preset.has("y"):
		rect_position = Vector2(preset.x, preset.y)

	if is_inside_tree():
		_clamp_rect()
		queue_redraw()


func get_preset() -> Dictionary:
	return {
		"x": _rect_position.x,
		"y": _rect_position.y,
		"width": _rect_size.x,
		"height": _rect_size.y,
		"flip_horizontal": flip_horizontal,
		"flip_vertical": flip_vertical,
		"enable_aspect_ratio": keep_aspect_ratio,
		"margins": {
			"left": 0,
			"right": 0,
			"top": 0,
			"bottom": 0,
		}
	}


# API Pública
func get_final_rect() -> Rect2: return Rect2(_rect_position, _rect_size)
func set_final_rect(rect: Rect2): self.rect_position = rect.position; self.rect_size = rect.size
func set_target_image(texture: Texture2D): _target_image = texture; queue_redraw()
func clear_target_image(): _target_image = null; queue_redraw()
func set_keep_aspect_ratio(enabled: bool): self.keep_aspect_ratio = enabled
func get_keep_aspect_ratio() -> bool: return keep_aspect_ratio
func get_flips() -> Dictionary: return {"horizontal": flip_horizontal, "vertical": flip_vertical}
