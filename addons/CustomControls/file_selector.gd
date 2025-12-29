@tool
class_name FileSelector
extends MarginContainer


signal double_click(path: String)
signal selected(node: FileSelector)
signal select_other(index: int, direction: int) # Direction -> 0 up, 1 left, 2 down, 3 right
signal add_to_favorite_requested(path: String)
signal remove_from_favorite_requested(path: String)

var path: String
var preview: String
var is_selected: bool = false
var is_enabled: bool = false
var is_hidden: bool = false

var cache_image: Texture2D

@onready var cursor: ColorRect = %Cursor
@onready var label: RichTextLabel = %Label
@onready var icon: TextureRect = %Icon




func _ready() -> void:
	set_process_input(false)
	gui_input.connect(_on_gui_input)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	cursor.visible = false


func _input(event: InputEvent) -> void:
	if !is_selected:
		set_process_input(false)
		return
	
	if event is InputEventKey:
		if event.is_pressed():
			if event.keycode == KEY_UP:
				select_other.emit(get_index(), 0)
			elif event.keycode == KEY_LEFT:
				select_other.emit(get_index(), 1)
			elif event.keycode == KEY_DOWN:
				select_other.emit(get_index(), 2)
			elif event.keycode == KEY_RIGHT:
				select_other.emit(get_index(), 3)


func set_path(_path: String, _preview: String = "", _name = "") -> void:
	var base_name: String
	if !_name:
		base_name = _path.get_basename().get_file()
		label.text = "[center]" + _path.get_basename().get_file() + "[/center]"
	else:
		base_name = _name
	
	label.text = "[center]" + base_name + "[/center]"
		
	path = _path
	preview = _preview
	tooltip_text = "[title]File: “%s”[/title]\n\"Full Path:\" [color=YELLOW_GREEN]%s[/color]" % [base_name.strip_edges(), path]
	CustomTooltipManager.replace_all_tooltips_with_custom(self)


func _request_update_preview(_preview: String) -> void:
	while FileCache.main_scene.preview_counter > FileCache.MAX_SIMULTANEOUS_PREVIEWS:
		await get_tree().process_frame
	FileCache.main_scene.preview_counter += 1
	
	if _preview and ResourceLoader.exists(_preview):
		var img = load(_preview)
		_update_image("", img, img, true)
	else:
		var preview_path = path.get_basename() + "_preview.png"
		if ResourceLoader.exists(preview_path):
			var s = load(preview_path)
			if s is Texture:
				_update_image("", s, s, true)
		else:
			if path.get_extension() == "tscn" and FileCache.cache.images.has(path):
				var s = load(path).instantiate()
				var img = s.texture
				s.queue_free()
				_update_image("", img, img, true)
			elif path.get_extension() == "tres" and FileCache.cache.images.has(path):
				var img = load(path)
				_update_image("", img, img, true)
			else:
				var main_database = get_tree().get_nodes_in_group("main_database")
				if main_database:
					main_database = main_database[0]
					main_database.get_child(0).resource_previewer.queue_resource_preview(path, self, "_update_image", true)
				else:
					var event_editor = get_tree().get_nodes_in_group("event_editor")
					if event_editor:
						event_editor = event_editor[0]
						event_editor.resource_previewer.queue_resource_preview(path, self, "_update_image", true)


func set_directory(_path: String, img: Texture2D) -> void:
	label.text = "[center]" + _path.get_file() + "[/center]"
	path = _path
	_update_image(path, img, null, false)


func _update_image(_path: String, preview: Texture, thumbnail_preview, using_counter: bool = false) -> void:
	if preview is Texture:
		icon.texture = preview
		cache_image = preview
	elif thumbnail_preview:
		icon.texture = thumbnail_preview
		cache_image = thumbnail_preview
	
	if using_counter:
		FileCache.main_scene.preview_counter -=1


func _on_mouse_entered() -> void:
	cursor.visible = true


func _on_mouse_exited() -> void:
	if !is_selected:
		cursor.visible = false


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.is_double_click():
				double_click.emit(path)
			elif event.is_pressed():
				if !is_selected:
					selected.emit(self)
					select()


func select() -> void:
	is_selected = true
	cursor.visible = true
	grab_focus()
	set_process_input(true)


func deselect() -> void:
	is_selected = false
	cursor.visible = false
	set_process_input(false)


func disable() -> void:
	is_enabled = false
	icon.texture = null


func enable() -> void:
	is_enabled = true
	if not cache_image:
		_request_update_preview(preview)
	else:
		icon.texture = cache_image


func show_favorite_button() -> void:
	%FavoriteButton.visible = true
	var options_cache = FileCache.options
	if options_cache and "favorite_files" in options_cache:
		%FavoriteButton.set_pressed_no_signal(path in options_cache.favorite_files)


func set_text_selected(selected_text: String) -> void:
	var label_text = label.get_parsed_text()
	if not selected_text.is_empty():
		# Convertimos ambos textos a minúsculas para la comparación
		var label_text_lower = label_text.to_lower()
		var selected_text_lower = selected_text.to_lower()
		
		# Buscamos la posición de inicio
		var start_pos = label_text_lower.find(selected_text_lower)
		
		if start_pos != -1:
			# Extraemos el texto exacto que coincide (preservando mayúsculas/minúsculas)
			var current_text = label_text.substr(start_pos, selected_text.length())
			
			# Creamos el texto con formato
			var formatted_text = "[fgcolor=195bda4d]%s[/fgcolor]" % current_text
			
			# Reemplazamos el texto original con el texto formateado
			label_text = label_text.substr(0, start_pos) + formatted_text + label_text.substr(start_pos + selected_text.length())
	
	label.text = "[center]%s[/center]" % label_text


func _on_favorite_button_toggled(toggled_on: bool) -> void:
	if toggled_on:
		add_to_favorite_requested.emit(path)
	else:
		remove_from_favorite_requested.emit(path)
