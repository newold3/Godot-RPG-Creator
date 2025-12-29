@tool
extends Control

# Clase interna para manejar el estado de cada item
class ItemState:
	var data: Dictionary
	var rect: Rect2
	var scale: float = 1.0
	var target_scale: float = 1.0
	var is_hovered: bool = false
	var is_selected: bool = false
	var is_animating: bool = false
	var tween: Tween
	
	signal redraw_requested()
	
	func _init(item_data: Dictionary, item_rect: Rect2):
		data = item_data
		rect = item_rect
	
	func set_hover(hovered: bool, parent_node: Control):
		if is_hovered == hovered:
			return
			
		is_hovered = hovered
		# Hover solo aplica un ligero zoom si NO está seleccionado
		if not is_selected:
			target_scale = 1.05 if hovered else 1.0
			_animate_to_target(parent_node)
	
	func set_selected(selected: bool, parent_node: Control):
		if is_selected == selected:
			return
		is_selected = selected
		# Zoom más notorio en selección
		target_scale = 1.05 if is_selected else 1.0
		_animate_to_target(parent_node)
		redraw_requested.emit()
	
	func _animate_to_target(parent_node: Control):
		if tween:
			tween.kill()
		
		if abs(scale - target_scale) < 0.001:
			return
			
		is_animating = true
		tween = parent_node.create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tween.tween_method(_update_scale, scale, target_scale, 0.2)
		tween.tween_callback(_on_animation_finished)
	
	func _update_scale(new_scale: float):
		scale = new_scale
		redraw_requested.emit()
	
	func _on_animation_finished():
		is_animating = false
		scale = target_scale
	
	func _to_string() -> String:
		return "<ItemState %s>" % data


# Uniforms/Propiedades exportadas
@export_group("Layout")
@export_range(1, 12, 1) var max_columns: int = 3 : set = set_max_columns
@export var item_size: Vector2 = Vector2(120, 40) : set = set_item_size
@export var max_item_size: Vector2 = Vector2(210, 40) : set = set_max_item_size
@export var item_spacing: Vector2 = Vector2(8, 8) : set = set_item_spacing
@export var padding: Vector2 = Vector2(16, 16) : set = set_padding
@export var margin: int = 32 : set = set_margin
@export_enum("DRAW_LEVEL_AND_QUANTITY", "DRAW_LEVEL_ONLY", "DRAW_QUANTITY_ONLY") var display_mode: int = 0

@export_group("Styles")
@export var style_normal: StyleBox : set = set_style_normal
@export var style_hover: StyleBox : set = set_style_hover
@export var style_selected: StyleBox : set = set_style_selected
@export var style_disabled: StyleBox : set = set_style_disabled
@export var style_hover_disabled: StyleBox : set = set_style_hover_disabled
@export var style_hover_selected: StyleBox : set = set_style_hover_selected
@export var equip_icon: Texture2D : set = set_equip_icon

@export_group("Colors")
@export var color_disabled: Color = Color.GRAY : set = set_color_disabled
@export var color_quantity: Color = Color.YELLOW : set = set_color_quantity
@export var color_level: Color = Color.YELLOW : set = set_color_level
@export var color_hover: Color = Color.WHITE : set = set_color_hover

@export_group("Font")
@export var font: Font : set = set_font
@export var font_size: int = 12 : set = set_font_size

@export_group("Other")
@export var target_node_size: Control

# Variables internas
var item_states: Array[ItemState] = []
var hovered_index: int = -1
var selected_index: int = -1
var focus_control: Control
var scroll_parent: ScrollContainer
var visible_rect: Rect2
var last_position: Vector2
var busy: bool = true
var is_enabled: bool = false

var curren_equipped_item: Variant # GameWeapon or GameArmor


# Señales
signal item_selected(index: int, item: Dictionary)
signal item_hovered(index: int, item: Dictionary)
signal item_clicked(index: int, item: Dictionary)
signal cancel()


func _ready():
	last_position = global_position
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	item_selected.connect(_on_item_selected)
	
	# Crear control de foco
	focus_control = Control.new()
	focus_control.focus_mode = Control.FOCUS_NONE
	focus_control.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	focus_control.size = Vector2(10, 10)
	focus_control.visible = false
	add_child(focus_control)
	
	# Buscar ScrollContainer padre
	_find_scroll_parent()
	
	#fill_test_data()
	
	busy = false
	_update_layout()


func _find_scroll_parent():
	var parent = get_parent()
	while parent:
		if parent is ScrollContainer:
			scroll_parent = parent
			scroll_parent.get_v_scroll_bar().value_changed.connect(queue_redraw.unbind(1))
			scroll_parent.get_h_scroll_bar().value_changed.connect(queue_redraw.unbind(1))
			#scroll_parent.single_target_focus = focus_control
			break
		parent = parent.get_parent()


func _get_visible_range(columns: int) -> Vector2i:
	if not scroll_parent:
		return Vector2i(0, item_states.size() - 1)
	
	var scroll_top = scroll_parent.scroll_vertical
	var scroll_bottom = scroll_top + scroll_parent.size.y
	
	var row_height = item_size.y + item_spacing.y
	var extra_files = 5 # 5 filas extra arriba y abajo
	var first_row = max(0, int((scroll_top - padding.y) / row_height) - extra_files)
	var last_row = int((scroll_bottom - padding.y) / row_height) + extra_files
	
	var start_index = first_row * columns
	var end_index = min(item_states.size() - 1, (last_row + 1) * columns - 1)
	return Vector2i(start_index, end_index)


func _draw():
	if item_states.is_empty():
		return
	
	var range_indexes = _get_visible_range(1)

	# Solo dibujar items visibles
	for i in range(range_indexes.x, range_indexes.y + 1, 1):
		var item_state = item_states[i]
		
		var item = item_state.data
		var rect = item_state.rect
		var item_scale = item_state.scale
		
		# Calcular el pivot centrado y aplicar escalado
		var pivot_center = rect.get_center()
		var scaled_size = rect.size * item_scale
		var scaled_rect = Rect2(
			pivot_center - scaled_size * 0.5,
			scaled_size
		)
		
		# Determinar estilo y color
		var style: StyleBox
		var text_color: Color
		
		if item.get("disabled", false):
			if i == selected_index:
				style = style_hover_selected
			elif i == hovered_index:
				style = style_hover_disabled
			else:
				style = style_disabled
			text_color = color_disabled
		elif i == selected_index:
			style = style_selected
			text_color = item.get("color", Color.WHITE)
		elif i == hovered_index:
			style = style_hover
			text_color = color_hover
		else:
			style = style_normal
			text_color = item.get("color", Color.WHITE)
		
		# Dibujar estilo de fondo
		if style:
			style.draw(get_canvas_item(), scaled_rect)
		
		# Calcular áreas de contenido
		var content_rect = scaled_rect
		
		_draw_item_content(item, content_rect, text_color, i)


func _is_item_visible(item_state: ItemState) -> bool:
	if not scroll_parent:
		return true
	
	return visible_rect.intersects(item_state.rect)

func _draw_item_content(item: Dictionary, rect: Rect2, text_color: Color, _index: int):
	var icon_texture: Texture2D
	var icon_size = Vector2.ZERO
	var has_icon = false
	
	# Cargar icono si existe
	icon_texture = item.get("icon", null)
	if icon_texture:
		has_icon = true
		icon_size = Vector2(rect.size.y * 0.8, rect.size.y * 0.8)
	
	var name_text = str(item.get("name", ""))
	var level = item.get("level", 1) if "level" in item else 0
	var quantity = item.get("quantity", 0)
	var has_level = "level" in item and level > 0
	var has_quantity = quantity > 0
	
	# Determinar qué mostrar basado en el modo
	var show_level = false
	var show_quantity = false
	var level_in_name = false  # Para el modo DRAW_LEVEL_AND_QUANTITY
	
	match display_mode:
		0:
			show_level = has_level
			show_quantity = has_quantity
			level_in_name = has_level  # El level va después del nombre
		1:
			show_level = has_level
			show_quantity = false
		2:
			show_level = false
			show_quantity = has_quantity
	
	# Construir el texto del nombre (con level si corresponde)
	var display_name = name_text
	if level_in_name:
		var level_abbr = RPGSYSTEM.database.terms.search_message("Level (abbr)")
		display_name += " (" + level_abbr + " " + str(level) + ")"
	
	# Construir el texto que va justificado a la derecha
	var right_text = ""
	if show_level and not level_in_name:
		right_text = "Lv " + str(level)
	elif show_quantity:
		right_text = "x " + str(quantity)
	
	var current_font = font if font else ThemeDB.fallback_font
	var current_font_size = font_size
	
	# Posiciones y tamaños con margen aplicado
	var icon_pos = Vector2.ZERO
	var name_pos = Vector2.ZERO
	var right_text_pos = Vector2.ZERO
	var available_width = rect.size.x - (margin * 2)  # Aplicar margen horizontal
	
	if has_icon:
		# Con icono: icono + nombre + texto derecha
		icon_pos = Vector2(rect.position.x + margin, rect.position.y + (rect.size.y - icon_size.y) * 0.5)
		# Centrar verticalmente el nombre con respecto al icono
		var icon_center_y = icon_pos.y + icon_size.y * 0.5 + font.get_ascent()
		name_pos = Vector2(icon_pos.x + icon_size.x + 4, icon_center_y)
		
		# Calcular ancho disponible para texto
		var right_text_width = 0
		if right_text != "":
			right_text_width = current_font.get_string_size(right_text, HORIZONTAL_ALIGNMENT_LEFT, -1, current_font_size).x
		available_width = rect.size.x - margin - icon_size.x - 8 - right_text_width - margin
		
		if right_text != "":
			right_text_pos = Vector2(rect.position.x + rect.size.x - right_text_width - margin, icon_center_y)
	else:
		# Sin icono: nombre + texto derecha
		var text_center_y = rect.position.y + rect.size.y * 0.5 + font.get_ascent()
		name_pos = Vector2(rect.position.x + margin, text_center_y)
		
		# Calcular ancho disponible para texto
		var right_text_width = 0
		if right_text != "":
			right_text_width = current_font.get_string_size(right_text, HORIZONTAL_ALIGNMENT_LEFT, -1, current_font_size).x
		available_width = rect.size.x - (margin * 2) - right_text_width
		if right_text != "":
			available_width -= 8  # Espacio entre nombre y texto derecha
		
		if right_text != "":
			right_text_pos = Vector2(rect.position.x + rect.size.x - right_text_width - margin, text_center_y)
	
	# Dibujar icono
	if has_icon and icon_texture:
		var icon_rect = Rect2(icon_pos, icon_size)
		draw_texture_rect(icon_texture, icon_rect, false, text_color if item.get("disabled", false) else Color.WHITE)
	
	# Dibujar nombre (con level incluido si corresponde) - centrado verticalmente
	var name_size = current_font.get_string_size(display_name, HORIZONTAL_ALIGNMENT_LEFT, available_width, current_font_size)
	var name_draw_pos = name_pos - Vector2(0, name_size.y * 0.5)
	draw_string(current_font, name_draw_pos, display_name, HORIZONTAL_ALIGNMENT_LEFT, available_width, current_font_size, text_color)
	
	# Dibujar icono de equipo si coincide con el item equipado
	if _index > 0 and equip_icon and item.current_item and curren_equipped_item and item.current_item.id == curren_equipped_item.id and item.current_item.type == curren_equipped_item.type and item.current_item.current_level == curren_equipped_item.current_level:
		var equip_icon_size = Vector2(rect.size.y * 0.6, rect.size.y * 0.6)
		var equip_icon_pos = Vector2(
			name_draw_pos.x + name_size.x + 4,
			rect.position.y + rect.size.y * 0.5 - equip_icon_size.y * 0.5
		)
		var equip_icon_rect = Rect2(equip_icon_pos, equip_icon_size)
		draw_texture_rect(equip_icon, equip_icon_rect, false, text_color if item.get("disabled", false) else Color.WHITE)
	
	# Dibujar texto justificado a la derecha - centrado verticalmente
	if right_text != "":
		var right_text_draw_pos = right_text_pos - Vector2(0, current_font.get_height(current_font_size) * 0.5)
		var right_color = color_level if show_level and not level_in_name else color_quantity
		draw_string(current_font, right_text_draw_pos, right_text, HORIZONTAL_ALIGNMENT_LEFT, -1, current_font_size, right_color)
	
	if item.get("is_new_item", false):
		var radius = 4.0
		var offset = Vector2(-radius - 4, radius + 4) # margen desde la esquina
		var circle_pos = rect.position + Vector2(rect.size.x, 0) + offset
		draw_circle(circle_pos, radius, Color.RED)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_handle_mouse_motion(event.position)
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_handle_mouse_click(event.position)


func _process(_delta: float) -> void:
	if is_enabled:
		if last_position != global_position:
			last_position = global_position
			if target_node_size:
				GameManager.set_confin_area(target_node_size.get_global_rect(), GameManager.get_cursor_manipulator())
			else:
				GameManager.set_confin_area(get_global_rect(), GameManager.get_cursor_manipulator())
			
		if GameManager.get_cursor_manipulator() == GameManager.MANIPULATOR_MODES.EQUIP_MENU_SUB_MENU:
			var direction = ControllerManager.get_pressed_direction()
			if direction and direction in ["up", "down"]:
				_update_selected(-1 if direction == "up" else 1)
			elif ControllerManager.is_cancel_just_pressed([KEY_0, KEY_KP_0]):
				GameManager.play_fx("cancel")
				cancel.emit()
			elif ControllerManager.is_confirm_pressed(false, [KEY_KP_ENTER]):
				item_clicked.emit(selected_index, item_states[selected_index].data)


func _update_selected(amount: int) -> void:
	if selected_index >= 0:
		item_states[selected_index].set_selected(false, self)
	
	var last_index = selected_index
	var clicked_index = wrapi(selected_index + amount, 0, item_states.size())
	
	selected_index = clicked_index
	item_states[selected_index].set_selected(true, self)
	_update_focus_control()
	item_selected.emit(selected_index, item_states[selected_index].data)
	if last_index != clicked_index:
		GameManager.play_fx("cursor")
	queue_redraw()


func _on_item_selected(_index: int, item: Dictionary) -> void:
	_untick_new_label(item)


func _untick_new_label(item: Dictionary) -> void:
	if item.get("is_new_item", false):
		item.is_new_item = false
		if "current_item" in item and item.current_item and "newly_added" in item.current_item:
			item.current_item.newly_added = false


func _handle_mouse_motion(pos: Vector2):
	var new_hovered = _get_item_at_position(pos)
	
	var item = item_states[hovered_index].data
	_untick_new_label(item)
	
	if new_hovered != hovered_index:
		var old_hovered = hovered_index
		hovered_index = new_hovered
		item = item_states[hovered_index].data
		
		# Cambiar cursor
		if hovered_index >= 0:
			mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			item_hovered.emit(hovered_index, item)
		else:
			mouse_default_cursor_shape = Control.CURSOR_ARROW
		
		# Actualizar estados de hover
		if old_hovered >= 0:
			item_states[old_hovered].set_hover(false, self)
		if hovered_index >= 0:
			item_states[new_hovered].set_hover(true, self)

		select_item(new_hovered)
		queue_redraw()
	else:
		item_hovered.emit(hovered_index, item)


func _handle_mouse_click(pos: Vector2):
	var clicked_index = _get_item_at_position(pos)
	
	if clicked_index >= 0 and not item_states[clicked_index].data.get("disabled", false):
		if selected_index >= 0:
			item_states[selected_index].set_selected(false, self)
		
		selected_index = clicked_index
		item_states[selected_index].set_selected(true, self)
		_update_focus_control()
		item_selected.emit(selected_index, item_states[selected_index].data)
		queue_redraw()


func _get_item_at_position(pos: Vector2) -> int:
	for i in range(item_states.size()):
		var item_state = item_states[i]
		var pivot_center = item_state.rect.get_center()
		var scaled_size = item_state.rect.size * item_state.scale
		var scaled_rect = Rect2(pivot_center - scaled_size * 0.5, scaled_size)
		
		if scaled_rect.has_point(pos):
			return i
			
	return -1


func _update_layout():
	if busy: return
	
	custom_minimum_size = Vector2.ZERO
	await get_tree().process_frame
	
	
	if item_states.is_empty():
		return
	
	busy = true
	
	var s = size.x if not target_node_size else target_node_size.size.x
	
	var available_width = s - padding.x * 2
	var num_items = item_states.size()
	
	# Calcular cuántas columnas pueden entrar
	var columns = min(max_columns, num_items)
	while columns > 1:
		var test_width = (available_width - (columns - 1) * item_spacing.x) / columns
		if test_width >= item_size.x:
			break
			
		columns -= 1
	
	# Ancho final del item
	var item_width = max(item_size.x, (available_width - (columns - 1) * item_spacing.x) / columns, max_item_size.x)
	var item_height = item_size.y
	var current_size = Vector2(item_width, item_height)
	
	# Posicionar items
	var start_pos = padding
	var current_pos = start_pos
	var col = 0
	var row = 0
	
	for i in range(num_items):
		var item_state = item_states[i]
		item_state.rect = Rect2(current_pos, current_size)
		
		col += 1
		if col >= columns:
			col = 0
			row += 1
			current_pos.x = start_pos.x
			current_pos.y = start_pos.y + row * (current_size.y + item_spacing.y)
		else:
			current_pos.x += current_size.x + item_spacing.x
	
	# Calcular alto total requerido
	var total_rows = ceil(float(num_items) / columns)
	var required_size = Vector2(
		padding.x * 2 + columns * current_size.x + (columns - 1) * item_spacing.x,
		padding.y * 2 + total_rows * current_size.y + (total_rows - 1) * item_spacing.y
	)
	custom_minimum_size = required_size
	
	_update_focus_control()
	queue_redraw()
	busy = false


func _update_focus_control():
	if not focus_control.focus_mode != Control.FOCUS_NONE:
		focus_control.visible = false
	else:
		if selected_index >= 0 and selected_index < item_states.size():
			var item_rect = item_states[selected_index].rect
			focus_control.position = item_rect.position
			focus_control.size = item_rect.size
			focus_control.visible = true
			if focus_control.has_focus():
				focus_control.release_focus()
			focus_control.grab_focus()
		else:
			focus_control.visible = false

func _on_mouse_entered():
	pass

func _on_mouse_exited():
	if hovered_index >= 0:
		item_states[hovered_index].set_hover(false, self)
		hovered_index = -1
		mouse_default_cursor_shape = Control.CURSOR_ARROW
		queue_redraw()

# Funciones para actualizar propiedades
func set_max_columns(value: int):
	max_columns = max(1, value)
	if is_inside_tree():
		_update_layout()

func set_item_size(value: Vector2):
	item_size = value
	if busy: return
	if is_inside_tree():
		_update_layout()

func set_max_item_size(value: Vector2):
	max_item_size = value
	if busy: return
	if is_inside_tree():
		_update_layout()


func set_item_spacing(value: Vector2):
	item_spacing = value
	if is_inside_tree():
		_update_layout()

func set_padding(value: Vector2):
	padding = value
	if is_inside_tree():
		_update_layout()

func set_margin(value: int):
	margin = value
	if is_inside_tree():
		queue_redraw()

func set_style_normal(value: StyleBox):
	style_normal = value
	if is_inside_tree():
		queue_redraw()

func set_style_hover(value: StyleBox):
	style_hover = value
	if is_inside_tree():
		queue_redraw()

func set_style_hover_disabled(value: StyleBox):
	style_hover_disabled = value
	if is_inside_tree():
		queue_redraw()

func set_style_hover_selected(value: StyleBox):
	style_hover_selected = value
	if is_inside_tree():
		queue_redraw()

func set_equip_icon(value: Texture2D):
	equip_icon = value
	if is_inside_tree():
		queue_redraw()

func set_style_selected(value: StyleBox):
	style_selected = value
	if is_inside_tree():
		queue_redraw()

func set_style_disabled(value: StyleBox):
	style_disabled = value
	if is_inside_tree():
		queue_redraw()

func set_color_disabled(value: Color):
	color_disabled = value
	if is_inside_tree():
		queue_redraw()

func set_color_quantity(value: Color):
	color_quantity = value
	if is_inside_tree():
		queue_redraw()

func set_color_level(value: Color):
	color_level = value
	if is_inside_tree():
		queue_redraw()


func set_color_hover(value: Color):
	color_hover = value
	if is_inside_tree():
		queue_redraw()

func set_font(value: Font):
	font = value
	if is_inside_tree():
		queue_redraw()

func set_font_size(value: int):
	font_size = max(8, value)
	if is_inside_tree():
		queue_redraw()

# Funciones públicas
func set_items(new_items: Array[Dictionary]):
	# Limpiar estados anteriores
	for item_state in item_states:
		if item_state.tween:
			item_state.tween.kill()
	
	item_states.clear()
	selected_index = -1
	hovered_index = -1
	
	# Crear nuevos estados
	for item in new_items:
		var item_state = ItemState.new(item, Rect2())
		item_state.redraw_requested.connect(queue_redraw)
		item_states.append(item_state)
	
	if item_states.size() > 0:
		select_item(0)
	
	_update_layout()

func get_selected_item() -> Dictionary:
	if selected_index >= 0 and selected_index < item_states.size():
		return item_states[selected_index].data
	return {}


func get_selected_index() -> int:
	return selected_index


func select_item(index: int):
	if index >= 0 and index < item_states.size():
		if selected_index >= 0:
			item_states[selected_index].set_selected(false, self)
		
		selected_index = index
		item_states[selected_index].set_selected(true, self)
		_untick_new_label(item_states[selected_index].data)
		_update_focus_control()
		queue_redraw()
		
		item_selected.emit(selected_index, item_states[selected_index].data)

func clear_selection():
	if selected_index >= 0:
		item_states[selected_index].set_selected(false, self)
		selected_index = -1
		_update_focus_control()
		queue_redraw()


func enabled() -> void:
	is_enabled = true
	var hand_manipulator = GameManager.MANIPULATOR_MODES.EQUIP_MENU_SUB_MENU
	GameManager.set_cursor_manipulator(hand_manipulator)
	if target_node_size:
		GameManager.set_confin_area(target_node_size.get_global_rect(), hand_manipulator)
	else:
		GameManager.set_confin_area(get_global_rect(), hand_manipulator)
	GameManager.set_hand_position(MainHandCursor.HandPosition.LEFT, hand_manipulator)
	GameManager.set_cursor_offset(Vector2(5, 0), hand_manipulator)
	focus_control.focus_mode = Control.FOCUS_ALL
	_update_focus_control()
	GameManager.force_hand_position_over_node(hand_manipulator)
	GameManager.force_show_cursor()


func disabled() -> void:
	is_enabled = false
	focus_control.focus_mode = Control.FOCUS_NONE
	GameManager.set_cursor_manipulator(GameManager.MANIPULATOR_MODES.NONE)


func emit_selected_item() -> void:
	if selected_index >= 0 and selected_index < item_states.size():
		item_selected.emit(selected_index, item_states[selected_index].data)
