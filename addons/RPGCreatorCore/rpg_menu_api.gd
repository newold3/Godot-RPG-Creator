@tool
class_name RPGMenuAPI
extends RefCounted


#region VARIABLES
static var _popup: PopupPanel = null
static var _panel: PanelContainer = null
static var _vbox: VBoxContainer = null
static var _queued_items: Array[Control] = []
#endregion



## Recibe cualquier nodo de interfaz (Control) y lo inyecta o lo pone en cola
static func add_menu_item(item: Control) -> void:
	if item.has_signal("pressed"):
		if _popup and not item.pressed.is_connected(_hide_popup):
			item.pressed.connect(_hide_popup)
			
	if not item.tree_exiting.is_connected(_on_item_tree_exiting):
		item.tree_exiting.connect(_on_item_tree_exiting.bind(item))
		
	if is_instance_valid(_vbox):
		_vbox.add_child(item)
	else:
		if not _queued_items.has(item):
			_queued_items.append(item)



static func _hide_popup() -> void:
	if _popup: _popup.hide()



static func _on_item_tree_exiting(item: Control) -> void:
	remove_menu_item(item)



## Elimina un nodo Control del menú de forma segura
static func remove_menu_item(item: Control) -> void:
	# Desconexión condicional
	if item.has_signal("pressed"):
		if _popup and item.pressed.is_connected(_hide_popup):
			item.pressed.disconnect(_hide_popup)
			
	if item.tree_exiting.is_connected(_on_item_tree_exiting):
		item.tree_exiting.disconnect(_on_item_tree_exiting)
		
	if is_instance_valid(_vbox) and item.get_parent() == _vbox:
		_vbox.remove_child(item)
	elif _queued_items.has(item):
		_queued_items.erase(item)



## Permite a cualquier plugin cambiar el estilo visual del panel contenedor
static func set_panel_style(style: StyleBox) -> void:
	if is_instance_valid(_panel):
		_panel.add_theme_stylebox_override("panel", style)



## Cierra el menú desplegable (tu escena compleja llamará a esto cuando lo necesite)
static func close_menu() -> void:
	if is_instance_valid(_popup):
		_popup.hide()



## Llamado exclusivamente por el Plugin Maestro para inicializar la estructura
static func attach_menu(popup: PopupPanel, panel: PanelContainer, vbox: VBoxContainer) -> void:
	_popup = popup
	_panel = panel
	_vbox = vbox
	
	for item in _queued_items:
		if is_instance_valid(item) and not item.get_parent():
			_vbox.add_child(item)
			
	_queued_items.clear()



## Llamado exclusivamente por el Plugin Maestro al desactivarse
static func detach_menu() -> void:
	if _vbox:
		var children = _vbox.get_children()
		for child in children:
			_queued_items.append(child)
			_vbox.remove_child(child)
		
	_popup = null
	_panel = null
	_vbox = null
