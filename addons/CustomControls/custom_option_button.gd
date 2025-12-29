@tool
extends OptionButton

@export var enable_multi_selection: bool = false : set = _set_multi_selection
@export var multi_selection_prefix: String = ""
@export var can_select_item_with_button_wheel: bool = true
@export var can_click_with_button_middle: bool = true

# Multi-selection variables
var selected_items: PackedInt32Array = []
var custom_popup: PopupPanel
var item_list: ItemList
var is_popup_open: bool = false

# Signals
signal middle_click()
signal multi_selection_changed(selected_ids: Array[int])

func _ready() -> void:
	gui_input.connect(_on_gui_input)
	
	var popup = get_popup()
	popup.visibility_changed.connect(
		func():
			if popup.visible and not enable_multi_selection:
				await get_tree().process_frame
				await get_tree().process_frame
				await get_tree().process_frame
				var id = get_selected_id()
				if id >= 0:
					popup.scroll_to_item(id)
	)
	
	# Setup multi-selection if enabled
	_setup_multi_selection()
	
	for i in get_item_count():
		var t = _clean_item_name(get_item_text(i))
		set_item_text(i, t)

func _set_multi_selection(value: bool) -> void:
	enable_multi_selection = value
	if is_inside_tree():
		_setup_multi_selection()

func _setup_multi_selection() -> void:
	if enable_multi_selection:
		_create_custom_popup()
		# Interceptar el click del botón para mostrar nuestro popup personalizado
		if not pressed.is_connected(_on_button_pressed):
			pressed.connect(_on_button_pressed)
		
		selected_items.clear()
		_update_button_text()
	else:
		_destroy_custom_popup()
		# Desconectar el interceptor
		if pressed.is_connected(_on_button_pressed):
			pressed.disconnect(_on_button_pressed)

func _create_custom_popup() -> void:
	if custom_popup:
		_destroy_custom_popup()
	
	# Crear PopupPanel personalizado
	custom_popup = PopupPanel.new()
	custom_popup.name = "CustomMultiSelectPopup"
	add_child(custom_popup)
	
	# Crear ItemList
	item_list = preload("res://addons/CustomControls/custom_simple_item_list.tscn").instantiate()
	item_list.select_mode = ItemList.SELECT_MULTI
	item_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	item_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	item_list.theme = load("res://addons/RPGMap/Assets/Themes/dialog_theme.tres")
	item_list.position.y = size.y
	custom_popup.add_child(item_list)
	
	# Configurar tamaño del popup basado en el control padre
	custom_popup.size = Vector2(size.x, 200)
	
	# Conectar señales
	item_list.multi_selected.connect(_on_item_multi_selected)
	item_list.item_activated.connect(_on_item_double_clicked)
	custom_popup.popup_hide.connect(_on_custom_popup_hide)
	
	# Conectar señal para cerrar al hacer click fuera
	get_viewport().gui_focus_changed.connect(_on_focus_changed)
	
	# Copiar items del OptionButton original al ItemList
	_sync_items_to_list()

func _destroy_custom_popup() -> void:
	if custom_popup:
		# Desconectar señales antes de destruir
		if get_viewport().gui_focus_changed.is_connected(_on_focus_changed):
			get_viewport().gui_focus_changed.disconnect(_on_focus_changed)
		custom_popup.queue_free()
		custom_popup = null
		item_list = null

func _sync_items_to_list() -> void:
	if not item_list:
		return
	
	item_list.clear()
	var popup = get_popup()
	
	for i in popup.get_item_count():
		var text = popup.get_item_text(i)
		var icon = popup.get_item_icon(i)
		item_list.add_item(text, icon)
		
		# Mantener el estado de disabled
		if popup.is_item_disabled(i):
			item_list.set_item_disabled(i, true)
	
	# Restaurar selección actual
	item_list.deselect_all()
	for i in selected_items:
		if i < item_list.get_item_count():
			item_list.select(i, false) # false = no emitir señal

func _on_button_pressed() -> void:
	if not enable_multi_selection or not custom_popup:
		return
	
	# Evitar que se abra el popup original
	if is_popup_open:
		_hide_custom_popup()
	else:
		_show_custom_popup()

func _show_custom_popup() -> void:
	if not custom_popup or is_popup_open:
		return
	
	is_popup_open = true
	
	# Ajustar el ancho del popup al del control padre
	custom_popup.size = Vector2(size.x, 200)
	
	# Sincronizar items antes de mostrar
	_sync_items_to_list()
	
	# Posicionar el popup
	var global_pos = global_position
	var popup_pos = Vector2(global_pos.x, global_pos.y + size.y)
	
	# Ajustar si se sale de la pantalla
	var screen_size = get_viewport().get_visible_rect().size
	if popup_pos.y + custom_popup.size.y > screen_size.y:
		popup_pos.y = global_pos.y - custom_popup.size.y
	
	custom_popup.popup_on_parent(Rect2i(popup_pos, custom_popup.size))
	
	# Focus en el ItemList
	item_list.grab_focus()

func _hide_custom_popup() -> void:
	if custom_popup and is_popup_open:
		custom_popup.hide()

func _on_custom_popup_hide() -> void:
	is_popup_open = false
	# Desconectar la señal de focus cuando se oculta el popup
	if get_viewport().gui_focus_changed.is_connected(_on_focus_changed):
		get_viewport().gui_focus_changed.disconnect(_on_focus_changed)
	
	# Actualizar selected_items basado en la selección actual del ItemList
	_update_selection_from_itemlist()

func _update_selection_from_itemlist() -> void:
	if not item_list:
		return
	
	# Obtener la selección actual del ItemList
	var new_selection: PackedInt32Array = []
	for i in item_list.get_item_count():
		if item_list.is_selected(i):
			new_selection.append(i)
	
	# Solo actualizar si la selección ha cambiado
	if new_selection != selected_items:
		selected_items = new_selection
		_update_button_text()
		multi_selection_changed.emit(selected_items.duplicate())

func _on_focus_changed(control: Control) -> void:
	# Si el foco va a un control que no es parte de nuestro popup, cerrarlo
	if is_popup_open and custom_popup and control:
		if not _is_control_part_of_popup(control):
			_hide_custom_popup()

func _is_control_part_of_popup(control: Control) -> bool:
	# Verificar si el control es parte del popup o del OptionButton
	var current = control
	while current:
		if current == custom_popup or current == item_list or current == self:
			return true
		current = current.get_parent()
	return false

func _on_item_multi_selected(index: int, selected: bool) -> void:
	selected_items = item_list.get_selected_items()
	
	_update_button_text()
	multi_selection_changed.emit(selected_items.duplicate())

func _on_item_double_clicked(index: int) -> void:
	# Doble click: seleccionar solo ese item
	selected_items.clear()
	selected_items.append(index)
	
	# Actualizar ItemList para reflejar la selección única
	item_list.deselect_all()
	item_list.select(index, false)
	
	_update_button_text()
	multi_selection_changed.emit(selected_items.duplicate())
	
	# Cerrar el popup después del doble click
	_hide_custom_popup()

func _update_button_text() -> void:
	if not enable_multi_selection:
		return
		
	if selected_items.is_empty():
		text = tr("No Selection")
	elif selected_items.size() == 1:
		var popup = get_popup()
		if selected_items[0] < popup.get_item_count():
			text = popup.get_item_text(selected_items[0])
		else:
			text = tr("1 selected item")
	else:
		# Mostrar los IDs de los items seleccionados
		var ids_text = ""
		for i in range(selected_items.size()):
			ids_text += str(selected_items[i])
			if i < selected_items.size() - 1:
				ids_text += ", "
		text = multi_selection_prefix + "[" + ids_text + "]"

# Override para interceptar add_item cuando está en modo multi
func add_item(label: String, id: int = -1) -> void:
	label = _clean_item_name(label)
	super(label, id)
	
	# Si está en modo multi-selección, sincronizar con ItemList
	if enable_multi_selection and item_list:
		_sync_items_to_list()

# Override para interceptar clicks del mouse cuando está en multi-selección
func _gui_input(event: InputEvent) -> void:
	if enable_multi_selection and event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_on_button_pressed()
			accept_event() # Evitar que se procese el click normal
			return
	
	# Continuar con el procesamiento normal
	_on_gui_input(event)

# Manejo de input para Enter cuando el popup está abierto
func _unhandled_key_input(event: InputEvent) -> void:
	if is_popup_open and event is InputEventKey:
		if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
			if event.pressed:
				# Capturar la selección ANTES de cerrar el popup
				if item_list:
					var new_selection: PackedInt32Array = []
					for i in item_list.get_item_count():
						if item_list.is_selected(i):
							new_selection.append(i)
					
					# Actualizar la selección
					if new_selection != selected_items:
						selected_items = new_selection
						_update_button_text()
						multi_selection_changed.emit(selected_items.duplicate())
				
				# Cerrar el popup
				_hide_custom_popup()
				get_viewport().set_input_as_handled()

# Agregar manejo de clicks fuera del popup
func _input(event: InputEvent) -> void:
	if is_popup_open and event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			# Verificar si el click fue fuera del popup
			var mouse_pos = get_global_mouse_position()
			var popup_rect = Rect2(custom_popup.position, custom_popup.size)
			var button_rect = Rect2(global_position, size)
			
			if not popup_rect.has_point(mouse_pos) and not button_rect.has_point(mouse_pos):
				_hide_custom_popup()
				get_viewport().set_input_as_handled()

func _clean_item_name(item: String) -> String:
	var regex = RegEx.new()
	regex.compile("\\b(\\w+)\\b")
	var formatted_text = item.capitalize()
	
	var all_lower_words = ["and", "but", "for", "nor", "so", "as", "with", "about", "from", "plus", "con", "por", "para", "sobre", "entre", "the"]
	var all_upper_words = ["id", "hp", "mp", "tp"]
	var matches = regex.search_all(formatted_text)
	
	# Procesar de atrás hacia adelante para evitar problemas de posición
	for i in range(matches.size() - 1, -1, -1):
		var m = matches[i]
		var chain = m.get_string(1).to_lower()
		var start_pos = m.get_start(1)
		var end_pos = m.get_end(1)
		
		if chain in all_upper_words:
			formatted_text = formatted_text.substr(0, start_pos) + chain.to_upper() + formatted_text.substr(end_pos)
		elif chain in all_lower_words:
			formatted_text = formatted_text.substr(0, start_pos) + chain + formatted_text.substr(end_pos)
	
	return formatted_text

func set_disabled(value: bool) -> void:
	modulate.a = 1.0 if !value else 0.6
	if value:
		if not has_meta("original_focus_mode"):
			set_meta("original_focus_mode", focus_mode)
		if not has_meta("original_mouse_filer"):
			set_meta("original_mouse_filer", mouse_filter)
		focus_mode = Control.FOCUS_NONE
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	else:
		if has_meta("original_focus_mode"):
			focus_mode = get_meta("original_focus_mode")
		else:
			focus_mode = Control.FOCUS_ALL
		if has_meta("original_mouse_filer"):
			mouse_filter = get_meta("original_mouse_filer")
		else:
			mouse_filter = Control.MOUSE_FILTER_STOP
			
	super.set_disabled(value)

func _on_gui_input(event: InputEvent) -> void:
	if is_disabled(): return
	if event is InputEventMouseButton:
		if event.is_pressed():
			if event.button_index == MOUSE_BUTTON_WHEEL_DOWN and can_select_item_with_button_wheel:
				change_index(1)
			elif event.button_index == MOUSE_BUTTON_WHEEL_UP and can_select_item_with_button_wheel:
				change_index(-1)
			elif event.button_index == MOUSE_BUTTON_MIDDLE and can_click_with_button_middle:
				middle_click.emit()

func change_index(mod: int) -> void:
	var bak = can_select_item_with_button_wheel
	can_select_item_with_button_wheel = false
	if enable_multi_selection:
		# En modo multi-selección, comportamiento especial
		if selected_items.is_empty():
			# Si no hay selección, comportarse como normal
			var index = 0
			index = wrapi(index + mod, 0, get_item_count())
			var count = 0
			while true:
				if !is_item_disabled(index):
					selected_items.append(index)
					_update_button_text()
					multi_selection_changed.emit(selected_items.duplicate())
					break
				else:
					index = wrapi(index + mod, 0, get_item_count())
					count += 1
				
				if count >= get_item_count():
					break
		elif selected_items.size() == 1:
			# Si hay un solo item seleccionado, comportarse como el original
			var current_index = selected_items[0]
			var new_index = current_index + mod
			new_index = wrapi(new_index, 0, get_item_count())
			var count = 0
			while true:
				if !is_item_disabled(new_index):
					selected_items.clear()
					selected_items.append(new_index)
					_update_button_text()
					multi_selection_changed.emit(selected_items.duplicate())
					break
				else:
					new_index = wrapi(new_index + mod, 0, get_item_count())
					count += 1
				
				if count >= get_item_count():
					break
		else:
			# Si hay múltiples items seleccionados
			var reference_index: int
			if mod > 0:
				# Avanzar: usar el índice mayor
				reference_index = Array(selected_items).max()
			else:
				# Retroceder: usar el índice menor
				reference_index = Array(selected_items).min()
			
			var new_index = reference_index + mod
			new_index = wrapi(new_index, 0, get_item_count())
			var count = 0
			while true:
				if !is_item_disabled(new_index):
					selected_items.clear()
					selected_items.append(new_index)
					_update_button_text()
					multi_selection_changed.emit(selected_items.duplicate())
					break
				else:
					new_index = wrapi(new_index + mod, 0, get_item_count())
					count += 1
				
				if count >= get_item_count():
					break
		return
		
	# Comportamiento original para modo no-multi
	var index = get_selected_id() + mod
	index = wrapi(index, 0, get_item_count())
	var count = 0
	while true:
		if !is_item_disabled(index):
			select(index)
			item_selected.emit(index)
			break
		else:
			index = wrapi(index + mod, 0, get_item_count())
			count += 1
		
		if count >= get_item_count():
			break
	
	call_deferred("set", "can_select_item_with_button_wheel", bak)

# ===== FUNCIONES PARA MULTI-SELECCIÓN =====

# Obtener los IDs de los items seleccionados
func get_selected_items() -> Array[int]:
	return selected_items.duplicate()

# Obtener los textos de los items seleccionados
func get_selected_texts() -> Array[String]:
	var texts: Array[String] = []
	var popup = get_popup()
	for id in selected_items:
		if id < popup.get_item_count():
			texts.append(popup.get_item_text(id))
	return texts

# Seleccionar/deseleccionar un item programáticamente
func set_item_selected(id: int, selected: bool = true) -> void:
	if not enable_multi_selection:
		return
		
	var popup = get_popup()
	if id < 0 or id >= popup.get_item_count():
		return
		
	if selected and id not in selected_items:
		selected_items.append(id)
	elif not selected and id in selected_items:
		selected_items.erase(id)
	
	# Sincronizar con ItemList si existe
	if item_list:
		if selected:
			item_list.select(id, false)
		else:
			item_list.deselect(id)
	
	_update_button_text()
	multi_selection_changed.emit(selected_items.duplicate())

# Limpiar toda la selección
func clear_selection() -> void:
	if not enable_multi_selection:
		return
	
	selected_items.clear()
	
	if item_list:
		item_list.deselect_all()
	
	_update_button_text()
	multi_selection_changed.emit(selected_items.duplicate())

# Seleccionar todos los items no deshabilitados
func select_all() -> void:
	if not enable_multi_selection or not item_list:
		return
		
	selected_items.clear()
	
	for i in item_list.get_item_count():
		if not item_list.is_item_disabled(i):
			selected_items.append(i)
			item_list.select(i, false)
	
	_update_button_text()
	multi_selection_changed.emit(selected_items.duplicate())

# Verificar si un item está seleccionado
func is_item_selected(id: int) -> bool:
	return id in selected_items
