@tool
extends Control
class_name CustomTabsControl

# Propiedades exportadas básicas
@export_enum("left", "right", "up", "down") var mouse_hand_type: int = 0
@export var tab_names: PackedStringArray = [] : set = set_tab_names
@export var tab_icons: Array[Texture2D] = [] : set = set_tab_icons
@export var icon_position: IconPosition = IconPosition.LEFT : set = set_icon_position
@export var icon_size: Vector2 = Vector2(16, 16) : set = set_icon_size
@export var font: Font : set = set_font
@export var font_size: int = 16 : set = set_font_size
@export var outline_size: int = 6 : set = set_outline_size

enum IconPosition {
	LEFT,
	RIGHT
}

# Colores para los diferentes estados
@export_group("Tab Colors")
@export var unselected_color: Color = Color.LIGHT_GRAY : set = set_unselected_color
@export var selected_color: Color = Color.WHITE : set = set_selected_color
@export var hover_color: Color = Color.LIGHT_BLUE : set = set_hover_color
@export var disabled_color: Color = Color.DARK_GRAY : set = set_disabled_color

# StyleBox para los diferentes estados
@export_group("Tab StyleBoxes")
@export var main_panel_focused_stylebox: StyleBox
@export var unselected_stylebox: StyleBox : set = set_unselected_stylebox
@export var selected_stylebox: StyleBox : set = set_selected_stylebox
@export var hover_stylebox: StyleBox : set = set_hover_stylebox
@export var disabled_stylebox: StyleBox : set = set_disabled_stylebox

# Colores de texto
@export_group("Text Colors")
@export var unselected_text_color: Color = Color.DARK_GRAY : set = set_unselected_text_color
@export var selected_text_color: Color = Color.BLACK : set = set_selected_text_color
@export var hover_text_color: Color = Color.BLACK : set = set_hover_text_color
@export var disabled_text_color: Color = Color.GRAY : set = set_disabled_text_color
@export var outline_text_color: Color = Color.BLACK : set = set_outline_text_color

# Configuración de tabs
@export_group("Tab Layout")
@export var tab_height: int = 40 : set = set_tab_height
@export var tab_padding: int = 20 : set = set_tab_padding
@export var tab_spacing: int = 2 : set = set_tab_spacing
@export var disabled_tabs: PackedInt32Array = [] : set = set_disabled_tabs
@export var hidden_tabs: PackedInt32Array = [] : set = set_hidden_tabs

# Configuración de offsets Y (solo para dibujo, no afectan el tamaño del control)
@export_group("Tab Positioning")
@export var selected_offset_y: int = 0 : set = set_selected_offset_y
@export var unselected_offset_y: int = 5 : set = set_unselected_offset_y

# Configuración de animación
@export_group("Animation")
@export var enable_animation: bool = true : set = set_enable_animation
@export var animation_duration: float = 0.3 : set = set_animation_duration
@export var animation_easing: Tween.EaseType = Tween.EASE_OUT : set = set_animation_easing
@export var animation_transition: Tween.TransitionType = Tween.TRANS_CUBIC : set = set_animation_transition

# Configuracion manipulator para el cursor
@export_group("")
@export var hand_manipulator: String

# Variables internas
var selected_tab: int = 0
var previous_selected_tab: int = -1
var hovered_tab: int = -1
var cursor_focused_tab: int = -1
var tab_rects: Array[Rect2] = []  # Rects base sin offsets
var tab_animated_offsets: Array[float] = []  # Solo para animación de dibujo
var tween: Tween
var focusable_control: Control
var delay_start: float = 0.0
var can_draw_focusable_style: bool = true

signal request_focus_top_control() # Señal emitida al pulsar arriba
signal request_focus_bottom_control() # Señal emitida al pulsar abajo
signal tab_clicked(tab_id: int) # Señal que se emite cuando se hace click en un tab
signal tab_preselected(tab_id: int) # Señal que se emite cuando se selecciona un tab

# Setters para actualizar automáticamente
func set_tab_names(value: PackedStringArray):
	tab_names = value
	_update_tabs()

func set_tab_icons(value: Array[Texture2D]):
	tab_icons = value
	_update_tabs()

func set_icon_position(value: IconPosition):
	icon_position = value
	_update_tabs()

func set_font(value: Font):
	font = value
	_update_tabs()

func set_font_size(value: int):
	font_size = value
	_update_tabs()

func set_outline_size(value: int):
	outline_size = value
	_update_tabs()


func set_unselected_color(value: Color):
	unselected_color = value
	_update_tabs()

func set_selected_color(value: Color):
	selected_color = value
	_update_tabs()

func set_hover_color(value: Color):
	hover_color = value
	_update_tabs()

func set_disabled_color(value: Color):
	disabled_color = value
	_update_tabs()

func set_unselected_stylebox(value: StyleBox):
	unselected_stylebox = value
	_update_tabs()

func set_selected_stylebox(value: StyleBox):
	selected_stylebox = value
	_update_tabs()

func set_hover_stylebox(value: StyleBox):
	hover_stylebox = value
	_update_tabs()

func set_disabled_stylebox(value: StyleBox):
	disabled_stylebox = value
	_update_tabs()

func set_unselected_text_color(value: Color):
	unselected_text_color = value
	_update_tabs()

func set_selected_text_color(value: Color):
	selected_text_color = value
	_update_tabs()

func set_hover_text_color(value: Color):
	hover_text_color = value
	_update_tabs()

func set_disabled_text_color(value: Color):
	disabled_text_color = value
	_update_tabs()

func set_outline_text_color(value: Color):
	outline_text_color = value
	_update_tabs()

func set_tab_height(value: int):
	tab_height = value
	_update_tabs()

func set_tab_padding(value: int):
	tab_padding = value
	_update_tabs()

func set_tab_spacing(value: int):
	tab_spacing = value
	_update_tabs()

func set_icon_size(value: Vector2):
	icon_size = value
	_update_tabs()

func set_disabled_tabs(value: PackedInt32Array):
	disabled_tabs = value
	_update_tabs()

func set_hidden_tabs(value: PackedInt32Array):
	hidden_tabs = value
	_update_tabs()

func set_selected_offset_y(value: int):
	selected_offset_y = value
	_reinitialize_offsets()
	_update_tabs()

func set_unselected_offset_y(value: int):
	unselected_offset_y = value
	_reinitialize_offsets()
	_update_tabs()

func set_enable_animation(value: bool):
	enable_animation = value
	_update_tabs()

func set_animation_duration(value: float):
	animation_duration = value

func set_animation_easing(value: Tween.EaseType):
	animation_easing = value

func set_animation_transition(value: Tween.TransitionType):
	animation_transition = value

func set_hand_manipulator(manipulator: String) -> void:
	hand_manipulator = manipulator

func set_tab_icon(tab_id: int, icon: Texture2D) -> void:
	if tab_id >= tab_icons.size():
		tab_icons.resize(tab_id + 1)
	
	tab_icons[tab_id] = icon


func _update_tabs():
	if is_inside_tree():
		_calculate_tab_rects()
		queue_redraw()

func _reinitialize_offsets():
	# Reinicializar los offsets animados con los nuevos valores
	for i in range(tab_animated_offsets.size()):
		if i == selected_tab:
			tab_animated_offsets[i] = float(selected_offset_y)
		else:
			tab_animated_offsets[i] = float(unselected_offset_y)

func _ready():
	_initialize_tab_offsets()
	_setup_tween()
	# Solo usar tab_height para el tamaño del control
	custom_minimum_size.y = tab_height
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	tab_clicked.connect(_select_control)
	_calculate_tab_rects()
	cursor_focused_tab = selected_tab
	_create_focusable_control()

func _process(delta: float) -> void:
	_update_cursor_position(delta)
	
	if delay_start > 0.0:
		delay_start -= delta
		return
		
	if focusable_control.has_focus():
		_handle_controller_input()

func _update_cursor_position(delta: float) -> void:
	if focusable_control and tab_rects:
		var target_tab = cursor_focused_tab if cursor_focused_tab != -1 else selected_tab
		if target_tab < tab_rects.size():
			var current_rect = tab_rects[target_tab]
			var p = current_rect.position + Vector2(3, current_rect.size.y * 0.5)
			focusable_control.position = focusable_control.position.lerp(p, delta * 16.0)

func _create_focusable_control() -> void:
	focusable_control = Control.new()
	focusable_control.name = "TrackCursor"
	focusable_control.size = Vector2.ZERO
	focusable_control.focus_mode = Control.FOCUS_CLICK
	focusable_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	focusable_control.focus_entered.connect(_update_hand_cursor)
	focusable_control.focus_exited.connect(
		func():
			cursor_focused_tab = -1
			queue_redraw()
	)
	add_child(focusable_control)

func _initialize_tab_offsets():
	tab_animated_offsets.clear()
	for i in range(tab_names.size()):
		if i == selected_tab:
			tab_animated_offsets.append(float(selected_offset_y))
		else:
			tab_animated_offsets.append(float(unselected_offset_y))

func _setup_tween():
	tween = create_tween()
	tween.tween_callback(_on_tween_step).set_delay(0.01)

func _calculate_tab_rects():
	tab_rects.clear()
	var current_x = 0.0
	var icon_spacing = 8  # Espacio entre icono y texto
	
	# Asegurar que tenemos offsets para todos los tabs
	while tab_animated_offsets.size() < tab_names.size():
		tab_animated_offsets.append(float(unselected_offset_y))
	
	for i in range(tab_names.size()):
		# Si el tab está oculto, añadir un rect vacío pero mantener el índice
		if _is_tab_hidden(i):
			tab_rects.append(Rect2())
			continue
			
		var tab_name = tab_names[i]
		var tab_icon = tab_icons[i] if i < tab_icons.size() else null
		var text_width = 0.0
		var icon_width = 0.0
		var total_content_width = 0.0
		
		# Calcular ancho del texto
		if tab_name != "":
			if font:
				text_width = font.get_string_size(tab_name, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
			else:
				text_width = get_theme_default_font().get_string_size(tab_name, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		
		# Calcular ancho del icono
		if tab_icon:
			icon_width = icon_size.x
		
		# Calcular ancho total del contenido
		if tab_icon and tab_name != "":
			total_content_width = text_width + icon_width + icon_spacing
		elif tab_icon:
			total_content_width = icon_width
		elif tab_name != "":
			total_content_width = text_width
		
		var tab_width = total_content_width + (tab_padding * 2)
		# Los tab_rects se crean en la posición base (Y = 0), los offsets se aplican solo al dibujar
		var tab_rect = Rect2(current_x, 0, tab_width, tab_height)
		tab_rects.append(tab_rect)
		
		current_x += tab_width + tab_spacing
	
	# Actualizar solo el ancho mínimo del control (solo tabs visibles)
	custom_minimum_size.x = int(current_x - tab_spacing) if current_x > 0 else 0
	size.x = custom_minimum_size.x

func _animate_tab_selection(new_selected: int):
	if not enable_animation:
		_set_tab_offsets_immediately(new_selected)
		return
	
	# Crear nuevo tween
	if tween:
		tween.kill()
	tween = create_tween()
	
	var animations_count = 0
	
	# Animar tab anteriormente seleccionado hacia posición unselected
	if previous_selected_tab >= 0 and previous_selected_tab < tab_animated_offsets.size():
		var start_offset = tab_animated_offsets[previous_selected_tab]
		var end_offset = float(unselected_offset_y)
		if start_offset != end_offset:
			animations_count += 1
			var old_tab_index = previous_selected_tab
			tween.parallel().tween_method(
				func(value): _set_tab_offset(old_tab_index, value),
				start_offset,
				end_offset,
				animation_duration
			).set_ease(animation_easing).set_trans(animation_transition)
	
	# Animar nuevo tab seleccionado hacia posición selected
	if new_selected >= 0 and new_selected < tab_animated_offsets.size():
		var start_offset = tab_animated_offsets[new_selected]
		var end_offset = float(selected_offset_y)
		if start_offset != end_offset:
			animations_count += 1
			tween.parallel().tween_method(
				func(value): _set_tab_offset(new_selected, value),
				start_offset,
				end_offset,
				animation_duration
			).set_ease(animation_easing).set_trans(animation_transition)
	
	# Si no hay animaciones, actualizar inmediatamente
	if animations_count == 0:
		_set_tab_offsets_immediately(new_selected)

func _set_tab_offsets_immediately(new_selected: int):
	for i in range(tab_animated_offsets.size()):
		if i == new_selected:
			tab_animated_offsets[i] = float(selected_offset_y)
		else:
			tab_animated_offsets[i] = float(unselected_offset_y)
	queue_redraw()

func _set_tab_offset(tab_index: int, offset: float):
	if tab_index >= 0 and tab_index < tab_animated_offsets.size():
		tab_animated_offsets[tab_index] = offset
		queue_redraw()

func _on_tween_step():
	queue_redraw()

func _is_tab_disabled(tab_id: int) -> bool:
	return tab_id in disabled_tabs

func _get_tab_state(tab_id: int) -> String:
	if _is_tab_disabled(tab_id):
		return "disabled"
	elif tab_id == selected_tab:
		return "selected"
	elif tab_id == hovered_tab or tab_id == cursor_focused_tab:
		return "hover"
	else:
		return "unselected"

func _get_stylebox_for_state(state: String) -> StyleBox:
	match state:
		"selected":
			return selected_stylebox
		"hover":
			return hover_stylebox
		"disabled":
			return disabled_stylebox
		_:
			return unselected_stylebox

func _get_color_for_state(state: String) -> Color:
	match state:
		"selected":
			return selected_color
		"hover":
			return hover_color
		"disabled":
			return disabled_color
		_:
			return unselected_color

func _get_text_color_for_state(state: String) -> Color:
	match state:
		"selected":
			return selected_text_color
		"hover":
			return hover_text_color
		"disabled":
			return disabled_text_color
		_:
			return unselected_text_color

func _draw():
	if tab_names.size() == 0:
		return
	
	var icon_spacing = 8  # Espacio entre icono y texto
	
	for i in range(tab_names.size()):
		# Saltar tabs ocultos
		if _is_tab_hidden(i):
			continue
			
		var base_tab_rect = tab_rects[i]  # Rect base sin offset
		var tab_name = tab_names[i]
		var tab_icon = tab_icons[i] if i < tab_icons.size() else null
		var state = _get_tab_state(i)
		
		# Aplicar offset Y solo para el dibujo
		var draw_offset_y = int(tab_animated_offsets[i]) if i < tab_animated_offsets.size() else int(unselected_offset_y)
		var tab_rect = Rect2(
			base_tab_rect.position.x, 
			base_tab_rect.position.y + draw_offset_y, 
			base_tab_rect.size.x, 
			base_tab_rect.size.y
		)
		
		# Obtener estilo según el estado
		var stylebox = _get_stylebox_for_state(state)
		var bg_color = _get_color_for_state(state)
		var text_color = _get_text_color_for_state(state)
		
		# Dibujar StyleBox si está disponible, sino usar color sólido
		if stylebox:
			if i == hovered_tab:
				if is_tab_disabled(i):
					disabled_stylebox.draw(get_canvas_item(), tab_rect)
				elif get_selected_tab() == i:
					selected_stylebox.draw(get_canvas_item(), tab_rect)
				else:
					unselected_stylebox.draw(get_canvas_item(), tab_rect)
			stylebox.draw(get_canvas_item(), tab_rect)
		else:
			draw_rect(tab_rect, bg_color)
		
		# Calcular posiciones de contenido
		var content_start_x = tab_rect.position.x + tab_padding
		var content_y = tab_rect.position.y + tab_rect.size.y / 2

		# Obtener dimensiones
		var text_font = font if font else get_theme_default_font()
		var text_size = Vector2.ZERO
		
		if tab_name != "":
			text_size = text_font.get_string_size(tab_name, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		
		# Dibujar contenido según la posición del icono
		if tab_icon and tab_name != "":
			# Hay tanto icono como texto
			if icon_position == IconPosition.LEFT:
				# Icono a la izquierda
				var icon_pos = Vector2(content_start_x, content_y - icon_size.y / 2)
				var text_pos = Vector2(content_start_x + icon_size.x + icon_spacing, content_y / 2 + text_font.get_ascent())
				
				#draw_texture(tab_icon, icon_pos)
				draw_texture_rect(tab_icon, Rect2(icon_pos, icon_size), false)
				if outline_size > 0:
					draw_string_outline(text_font, text_pos, tab_name, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, outline_size, outline_text_color)
				draw_string(text_font, text_pos, tab_name, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, text_color)
			else:
				# Icono a la derecha
				var text_pos = Vector2(content_start_x, content_y + text_size.y / 2)
				var icon_pos = Vector2(content_start_x + text_size.x + icon_spacing, content_y - icon_size.y / 2)
				
				if outline_size > 0:
					draw_string_outline(text_font, text_pos, tab_name, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, outline_size, outline_text_color)
				draw_string(text_font, text_pos, tab_name, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, text_color)
				draw_texture(tab_icon, icon_pos)
		elif tab_icon:
			# Solo icono
			var icon_pos = Vector2(
				tab_rect.position.x + (tab_rect.size.x - icon_size.x) / 2,
				content_y - icon_size.y / 2
			)
			draw_texture(tab_icon, icon_pos)
		elif tab_name != "":
			# Solo texto
			var text_pos = Vector2(
				tab_rect.position.x + (tab_rect.size.x - text_size.x) / 2,
				content_y + text_size.y / 2
			)
			
			if outline_size > 0:
				draw_string_outline(text_font, text_pos, tab_name, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, outline_size, outline_text_color)
			draw_string(text_font, text_pos, tab_name, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, text_color)
			
	if focusable_control and focusable_control.has_focus() and main_panel_focused_stylebox and can_draw_focusable_style:
		var rect = Rect2(0, 0, size.x, size.y)
		main_panel_focused_stylebox.draw(get_canvas_item(), rect)

func _gui_input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			var clicked_tab = _get_tab_at_position(event.position)
			if clicked_tab != -1 and not _is_tab_disabled(clicked_tab):
				previous_selected_tab = selected_tab
				var emit_signal_enabled: bool = false
				if selected_tab == clicked_tab:
					enable_animation = false
				else:
					selected_tab = clicked_tab
					emit_signal_enabled = true
				_animate_tab_selection(selected_tab)
				enable_animation = true
				if emit_signal_enabled:
					tab_clicked.emit(clicked_tab)
	
	elif event is InputEventMouseMotion:
		var hovered = _get_tab_at_position(event.position)
		if hovered != hovered_tab:
			hovered_tab = hovered
			queue_redraw()
		
		if hovered == -1:
			mouse_default_cursor_shape = Control.CURSOR_ARROW
		else:
			mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

func _handle_controller_input() -> void:
	if focusable_control and focusable_control.has_focus():
		var direction = ControllerManager.get_pressed_direction()
		var new_cursor_tab: int = -1
		
		if direction == "left":
			new_cursor_tab = cursor_focused_tab
			# Buscar el tab anterior válido
			for i in range(tab_rects.size()):
				#new_cursor_tab = wrapi(new_cursor_tab - 1, 0, tab_rects.size()) # use wrap
				new_cursor_tab = max(0, new_cursor_tab - 1) # no use wrap
				if not _is_tab_disabled(new_cursor_tab) and not _is_tab_hidden(new_cursor_tab):
					break
			
		elif direction == "right":
			new_cursor_tab = cursor_focused_tab
			# Buscar el tab siguiente válido
			for i in range(tab_rects.size()):
				#new_cursor_tab = wrapi(new_cursor_tab + 1, 0, tab_rects.size()) # use wrap
				new_cursor_tab = min(new_cursor_tab + 1, tab_rects.size() - 1) # no use wrap
				if not _is_tab_disabled(new_cursor_tab) and not _is_tab_hidden(new_cursor_tab):
					break
		
		elif direction == "up":
			request_focus_top_control.emit()
			return
		
		elif direction == "down":
			request_focus_bottom_control.emit()
			return
		
		# Si se movió el cursor, actualizar posición
		if new_cursor_tab != -1 and not direction.is_empty() and new_cursor_tab != cursor_focused_tab:
			pre_select_tab(new_cursor_tab)
		
		# Detectar botón de aceptar para seleccionar tab
		elif ControllerManager.is_confirm_pressed(false, [KEY_KP_ENTER]):
			if cursor_focused_tab != -1 and cursor_focused_tab != selected_tab:
				previous_selected_tab = selected_tab
				selected_tab = cursor_focused_tab
				_animate_tab_selection(selected_tab)
				tab_clicked.emit(selected_tab)
			else:
				tab_clicked.emit(selected_tab)
			get_viewport().set_input_as_handled()
			
			#GameManager.play_fx("select")


func pre_select_tab(new_cursor_tab: int) -> void:
	cursor_focused_tab = new_cursor_tab
	queue_redraw()
	get_viewport().set_input_as_handled()
	GameManager.play_fx("cursor")
	tab_preselected.emit(cursor_focused_tab)


func _select_control(_tab_selected_index: int) -> void:
	focusable_control.grab_focus()
	# Inicializar cursor_focused_tab con el tab seleccionado
	cursor_focused_tab = selected_tab

func _update_hand_cursor() -> void:
	GameManager.set_cursor_manipulator(hand_manipulator)
	GameManager.set_confin_area(Rect2(), hand_manipulator)
	match mouse_hand_type:
		0: GameManager.set_hand_position(MainHandCursor.HandPosition.LEFT, hand_manipulator)
		1: GameManager.set_hand_position(MainHandCursor.HandPosition.RIGHT, hand_manipulator)
		2: GameManager.set_hand_position(MainHandCursor.HandPosition.UP, hand_manipulator)
		3: GameManager.set_hand_position(MainHandCursor.HandPosition.DOWN, hand_manipulator)
	queue_redraw()


func _get_tab_at_position(pos: Vector2) -> int:
	# Usar los rects base para detectar clicks, no los offseteados
	for i in range(tab_rects.size()):
		# Saltar tabs ocultos
		if _is_tab_hidden(i):
			continue
			
		# Expandir el área de click para incluir el offset
		var click_rect = tab_rects[i]
		var max_offset = max(abs(selected_offset_y), abs(unselected_offset_y))
		click_rect = Rect2(
			click_rect.position.x,
			click_rect.position.y - max_offset,
			click_rect.size.x,
			click_rect.size.y + max_offset * 2
		)
		if click_rect.has_point(pos):
			return i
	return -1

func _on_mouse_entered():
	pass

func _on_mouse_exited():
	if hovered_tab != -1:
		hovered_tab = -1
		queue_redraw()

# Funciones públicas para controlar los tabs programáticamente
func set_selected_tab(tab_id: int, animate: bool = true, emit_signal_enabled: bool = false):
	if tab_id >= 0 and tab_id < tab_names.size() and not _is_tab_disabled(tab_id):
		delay_start = 0.03
		previous_selected_tab = selected_tab
		selected_tab = tab_id
		if animate and enable_animation and selected_tab != tab_id:
			_animate_tab_selection(selected_tab)
		else:
			_set_tab_offsets_immediately(selected_tab)
		if emit_signal_enabled:
			tab_clicked.emit(selected_tab)
		else:
			_select_control(selected_tab)

func next_tab() -> void:
	var new_tab = min(selected_tab + 1, tab_rects.size() - 1)
	if _is_tab_hidden(new_tab) and new_tab != tab_rects.size() - 1:
		next_tab()
		return
	if new_tab != selected_tab and not _is_tab_hidden(new_tab):
		set_selected_tab(new_tab, true, true)

func previous_tab() -> void:
	var new_tab = max(0, selected_tab - 1)
	if _is_tab_hidden(new_tab) and new_tab != 0:
		previous_tab()
		return
	if new_tab != selected_tab and not _is_tab_hidden(new_tab):
		set_selected_tab(new_tab, true, true)

func get_selected_tab() -> int:
	return selected_tab

func add_tab(tab_name: String, tab_icon: Texture2D = null):
	var new_names = tab_names.duplicate()
	new_names.append(tab_name)
	set_tab_names(new_names)
	
	# Añadir icono si se proporciona
	if tab_icon:
		var new_icons = tab_icons.duplicate()
		new_icons.append(tab_icon)
		set_tab_icons(new_icons)
	
	# Añadir offset para el nuevo tab
	tab_animated_offsets.append(float(unselected_offset_y))

func remove_tab(tab_id: int):
	if tab_id >= 0 and tab_id < tab_names.size():
		var new_names = tab_names.duplicate()
		new_names.remove_at(tab_id)
		
		# Remover icono si existe
		if tab_id < tab_icons.size():
			var new_icons = tab_icons.duplicate()
			new_icons.remove_at(tab_id)
			set_tab_icons(new_icons)
		
		# Remover offset del tab eliminado
		if tab_id < tab_animated_offsets.size():
			tab_animated_offsets.remove_at(tab_id)
		
		# Ajustar tabs deshabilitados
		var new_disabled = disabled_tabs.duplicate()
		for i in range(new_disabled.size() - 1, -1, -1):
			if new_disabled[i] == tab_id:
				new_disabled.remove_at(i)
			elif new_disabled[i] > tab_id:
				new_disabled[i] -= 1
		
		# Ajustar el tab seleccionado si es necesario
		if selected_tab >= new_names.size():
			selected_tab = max(0, new_names.size() - 1)
		elif selected_tab > tab_id:
			selected_tab -= 1
		
		set_disabled_tabs(new_disabled)
		set_tab_names(new_names)

func clear_tabs():
	set_tab_names(PackedStringArray())
	set_tab_icons([])
	set_disabled_tabs(PackedInt32Array())
	tab_animated_offsets.clear()
	selected_tab = 0
	hovered_tab = -1

func set_tab_disabled(tab_id: int, disabled: bool):
	if tab_id < 0 or tab_id >= tab_names.size():
		return
		
	var new_disabled = disabled_tabs.duplicate()
	var index = new_disabled.find(tab_id)
	
	if disabled and index == -1:
		new_disabled.append(tab_id)
	elif not disabled and index != -1:
		new_disabled.remove_at(index)
	
	set_disabled_tabs(new_disabled)

func is_tab_disabled(tab_id: int) -> bool:
	return _is_tab_disabled(tab_id)

func hide_tab(tab_index: int, value: bool):
	if tab_index < 0 or tab_index >= tab_names.size():
		return
		
	var new_hidden = hidden_tabs.duplicate()
	var index = new_hidden.find(tab_index)
	
	if value and index == -1:
		# Ocultar tab
		new_hidden.append(tab_index)
		# Si el tab seleccionado se oculta, seleccionar el siguiente visible
		if selected_tab == tab_index:
			var next_visible = _get_next_visible_tab(selected_tab)
			if next_visible != -1:
				set_selected_tab(next_visible, false)
	elif not value and index != -1:
		# Mostrar tab
		new_hidden.remove_at(index)
	
	set_hidden_tabs(new_hidden)

func _get_next_visible_tab(from_index: int) -> int:
	# Buscar el siguiente tab visible
	for i in range(tab_names.size()):
		var next_index = (from_index + i + 1) % tab_names.size()
		if not _is_tab_hidden(next_index) and not _is_tab_disabled(next_index):
			return next_index
	return -1


func is_tab_hidden(tab_index: int) -> bool:
	return _is_tab_hidden(tab_index)

func _is_tab_hidden(tab_id: int) -> bool:
	return tab_id in hidden_tabs

func get_tab_count() -> int:
	return tab_names.size()

func stop_animations():
	if tween:
		tween.kill()
		tween = null

func get_tab_rect(tab_id: int) -> Rect2:
	if tab_id >= 0 and tab_id < tab_rects.size():
		return tab_rects[tab_id]
	return Rect2()

func get_max_tabs() -> int:
	return tab_rects.size()
