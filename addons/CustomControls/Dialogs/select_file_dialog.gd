@tool
class_name CustomFileDialog
extends Window


## Internal structure to manage file rendering data.
class FileStruct:
	var path: String
	var type: String # File, Directory
	var icon: String
	var is_empty: bool # only applied directory
	
	func _init(p_path: String, p_type: String, p_icon: String = "", p_is_empty: bool = false) -> void:
		path = p_path
		type = p_type
		icon = p_icon
		is_empty = p_is_empty
	
	func _to_string() -> String:
		return "<FileStruct path=\"%s\" type=\"%s\" icon=\"%s\"" % [path, type, icon]


## Number of files to show per page to prevent Godot preview crashes.
@export var items_per_page: int = 50

@export var ignore_folders: Array[String] = []


var target_callable: Callable

var current_path: String = ""
var current_file_selected: String = ""
var current_directory: String = ""
var current_directory_selected: String = ""
var current_directory_count: int = 0

const FILE_SELECTOR = preload("res://addons/CustomControls/file_selector.tscn")
const FOLDER_ICON = preload("res://addons/CustomControls/Images/folder_icon.png")
const EMPTY_FOLDER_ICON = preload("res://addons/CustomControls/Images/empty_folder_icon.png")

var filter_delay_timer: float = 0
var refresh_delay_timer: float = 0

var dialog_mode = 0 # 0 = files, 1 = folder

var file_type: String
var file_type_arr: PackedStringArray

var destroy_on_hide: bool = false

var file_count: int = 0

var history: Dictionary = {
	"back": [],
	"next": []
}

var queue_files: Array[FileStruct] = []

## Complete list of files to be paginated.
var filtered_files_pool: Array[FileStruct] = []

var current_page: int = 0

var auto_play_sounds: bool = false

var current_cache_key: Variant = null


const MAX_CACHE_LAST_SELECTION_FILES = 20

enum FILE_MODE {
	ALL,
	NAVIGABLE
}

var file_mode: FILE_MODE = FILE_MODE.NAVIGABLE

var current_file_type: int = 0 # 0 = fill_files, 1 = fill_files_by_extension, 2 = fill_mix_files
var current_file_filters_data: Variant = ""

var favorite_button_enabled: bool = false
var all_button_enabled: bool = false

var _load_token: int = 0

static var cache_last_selection: Dictionary = {}
static var last_folder_visited: String = ""

@onready var expression = Expression.new()
@onready var scroll_container: ScrollContainer = %ScrollContainer


func _ready() -> void:
	%CurrentPath.set_disabled(true)
	%Loading.visible = true
	%AnimatedSprite2D.play("default")
	visibility_changed.connect(_on_visibility_changed)
	tree_exiting.connect(_save_last_folder_visited)
	close_requested.connect(_on_cancel_button_pressed)
	%FileContainer.item_rect_changed.connect(set_all_files_visibility_timer)
	
	if FileCache.options:
		var p_favorite_button_enabled = FileCache.options.get("file_dialog_favorite_toggled", false)
		%FavoriteButton.set_pressed_no_signal(p_favorite_button_enabled)
		var p_all_button_enabled = FileCache.options.get("file_dialog_all_files_toggled", false)
		%AllButton.set_pressed_no_signal(p_all_button_enabled)
		favorite_button_enabled = p_favorite_button_enabled
		all_button_enabled = p_all_button_enabled


func skip(_path: String) -> void:
	pass


func reset() -> void:
	_clear_current_files()
	set_dialog_mode(0)
	current_path = ""
	current_file_selected = ""
	current_directory = ""
	current_directory_selected = ""
	target_callable = skip
	destroy_on_hide = false
	file_count = 0
	%Loading.visible = true
	%NoFilesFound.visible = false
	%OKButton.set_disabled(false)
	history.back.clear()
	history.next.clear()
	%Filename.text = ""
	%FilterLineEdit.text = ""
	_update_label_path_selected()
	
	if all_button_enabled:
		%AllButton.set_pressed_no_signal(true)
	elif favorite_button_enabled:
		%FavoriteButton.set_pressed_no_signal(true)


func set_dialog_mode(id: int) -> void:
	dialog_mode = clamp(id, 0, 1)
	title = TranslationManager.tr("Select File") if dialog_mode == 0 else TranslationManager.tr("Select Directory")
	%FavoriteButton.visible = dialog_mode == 0
	%AllButton.visible = dialog_mode == 0
	_update_ui_controls()


func _update_ui_controls() -> void:
	var is_navigable = (dialog_mode == 1) or (dialog_mode == 0 and not all_button_enabled and not favorite_button_enabled)
	%DirectoryExtraControls1.visible = is_navigable
	%Back.visible = is_navigable
	%Next.visible = is_navigable


func set_file_selected(path: String) -> void:
	current_path = path
	_update_label_path_selected()
	current_file_selected = path
	%CurrentPath.text = path
	
	if dialog_mode == 1:
		var absolute_path = ProjectSettings.globalize_path(current_path)
		if !DirAccess.dir_exists_absolute(absolute_path):
			DirAccess.make_dir_recursive_absolute(absolute_path)


func set_directory_selected(path: String) -> void:
	current_directory_selected = path


func set_directory_filename(_name: String) -> void:
	%Filename.text = _name
	%Filename.set_caret_column(_name.length())
	%Filename.select_all()


func _process(delta: float) -> void:
	if filter_delay_timer > 0:
		filter_delay_timer -= delta
		if filter_delay_timer <= 0:
			filter_delay_timer = 0
			apply_filter(%FilterLineEdit.text)
			_check_all_nodes_visibility()
	
	if refresh_delay_timer > 0:
		refresh_delay_timer -= delta
		if refresh_delay_timer <= 0:
			refresh_delay_timer = 0
			_check_all_nodes_visibility()
	
	_change_state_button(%Back, "back")
	_change_state_button(%Next, "next")
	
	if queue_files:
		populate_files()


func _change_state_button(button: TextureButton, history_id: String) -> void:
	var can_navigate = false
	
	if history_id == "back":
		can_navigate = not history.back.is_empty() or current_directory != "res://"
	elif history_id == "next":
		can_navigate = not history.next.is_empty()
		
	if can_navigate:
		button.set_disabled(false)
		button.modulate = Color.WHITE
	else:
		button.set_disabled(true)
		button.modulate = Color("#50505067")


func _clear_current_files() -> void:
	_load_token += 1
	%FilterLineEdit.text = ""
	for file in %FileContainer.get_children():
		file.queue_free()
	queue_files.clear()
	filtered_files_pool.clear()
	current_page = 0


func _get_files_in_cache(file_id: String) -> PackedStringArray:
	if file_id:
		if !FileCache.cache_setted:
			%Loading.visible = true
			FileCache.rescan_files()
			await FileCache.cache_ready
		if file_id in FileCache.cache:
			return FileCache.cache[file_id].keys()
	return []


func _get_files_recursive(path: String, extensions: Array) -> PackedStringArray:
	var found_files: PackedStringArray = []
	var dir = DirAccess.open(path)
	if dir == null: return []
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		var full_path = path.path_join(file_name)
		if dir.current_is_dir():
			found_files.append_array(_get_files_recursive(full_path, extensions))
		else:
			var ext = file_name.get_extension().to_lower()
			if extensions.any(func(e): return e.to_lower() == ext):
				found_files.append(full_path)
		file_name = dir.get_next()
	
	return found_files


func _get_folders(dir_path: String) -> PackedStringArray:
	dir_path = _clean_path(dir_path)
	
	var directories: PackedStringArray = []
	var dir = DirAccess.open(dir_path)
	
	if dir == null: return []
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if dir.current_is_dir() and not file_name.begins_with("."):
			directories.append(dir_path.path_join(file_name))
		file_name = dir.get_next()
	return directories


func _append_folders(dir_path: String) -> void:
	var folders = _get_folders(dir_path)
	current_directory_count = folders.size()
	for folder in folders:
		queue_files.append(FileStruct.new(folder, "directory", "", _is_directory_empty(folder)))
	
	current_directory = dir_path
	%CurrentPath.text = current_directory


func _clean_path(path: String) -> String:
	if path.is_empty(): return "res://"
	path = path.replace("\\", "/")
	if path.length() > 6 and path.ends_with("/"):
		path = path.left(-1)
	return path


func _fill_favorite_files() -> void:
	_clear_current_files()
	_update_ui_controls()
	
	var options_cache = FileCache.options
	if options_cache and "favorite_files" in options_cache:
		var favorite_files = options_cache.favorite_files
		for file in favorite_files:
			var file_id = str(favorite_files[file])
			if file_id == str(current_file_filters_data):
				filtered_files_pool.append(FileStruct.new(file, "file"))
	
	_paginate_next_batch()
	hide_loading()


func fill_files(file_id: String, update_directory: bool = true) -> void:
	file_type = file_id
	current_cache_key = file_id
	current_file_filters_data = current_cache_key
	current_file_type = 0
	
	_clear_current_files()
	_update_ui_controls()
	
	var base_dir = ""
	if not all_button_enabled or dialog_mode == 1:
		if update_directory:
			if not current_directory.is_empty(): base_dir = current_directory
			elif not last_folder_visited.is_empty(): base_dir = last_folder_visited
			else: base_dir = "res://"
			
			current_directory = _clean_path(base_dir)
			%CurrentPath.text = current_directory
		else:
			base_dir = current_directory
		_append_folders(base_dir)
	
	if dialog_mode == 1:
		hide_loading()
		return

	
	var current_token = _load_token
	var files = await _get_files_in_cache(file_id)
	if current_token != _load_token: return
	
	for file in files:
		if all_button_enabled or _clean_path(file.get_base_dir()) == base_dir:
			filtered_files_pool.append(FileStruct.new(file, "file"))
			
	_paginate_next_batch()
	hide_loading()


func fill_mix_files(file_ids: PackedStringArray, update_directory: bool = true) -> void:
	current_cache_key = file_ids
	current_file_filters_data = current_cache_key
	current_file_type = 2
	
	if favorite_button_enabled:
		_fill_favorite_files()
		return
		
	_clear_current_files()
	_update_ui_controls()
	
	var current_token = _load_token
	var base_dir = ""
	if not all_button_enabled or dialog_mode == 1:
		base_dir = current_directory if not update_directory else (last_folder_visited if not last_folder_visited.is_empty() else "res://")
		_append_folders(base_dir)
	
	if dialog_mode == 1:
		hide_loading()
		return
		
	for id in file_ids:
		var files = await _get_files_in_cache(id)
		if current_token != _load_token: return
		for file in files:
			if all_button_enabled or file.get_base_dir() == base_dir:
				filtered_files_pool.append(FileStruct.new(file, "file"))
				
	_paginate_next_batch()
	hide_loading()


func fill_files_by_extension(path: String = "res://", extensions: Array = [], update_directory: bool = true)-> void:
	current_cache_key = extensions
	current_file_filters_data = current_cache_key
	current_file_type = 1
	
	if favorite_button_enabled:
		_fill_favorite_files()
		return
		
	_clear_current_files()
	_update_ui_controls()
	
	var base_dir = path if !all_button_enabled else "res://"
	if !all_button_enabled or dialog_mode == 1:
		_append_folders(base_dir)
	
	if dialog_mode == 1:
		hide_loading()
		return
		
	var files = _get_files_recursive(base_dir, extensions)
	for file in files:
		if all_button_enabled or file.get_base_dir() == base_dir:
			filtered_files_pool.append(FileStruct.new(file, "file"))
			
	_paginate_next_batch()
	hide_loading()


func _paginate_next_batch() -> void:
	var start = current_page * items_per_page
	if start >= filtered_files_pool.size(): return
	
	var end = min(start + items_per_page, filtered_files_pool.size())
	queue_files.append_array(filtered_files_pool.slice(start, end))
	current_page += 1


func populate_files() -> void:
	if queue_files.is_empty(): return
	
	%Loading.visible = false
	%NoFilesFound.visible = false
	
	# Priority: Folders first
	var folders = queue_files.filter(func(f): return f.type == "directory")
	folders.sort_custom(func(a, b): return a.path.naturalnocasecmp_to(b.path) < 0)
	
	# Process batch limit for frames
	for i in range(min(15, queue_files.size())):
		if queue_files.is_empty(): break
		var file = queue_files.pop_front()
		
		var file_selector = FILE_SELECTOR.instantiate()
		%FileContainer.add_child(file_selector)
		
		if file.type == "file":
			_setup_file_node(file_selector, file.path)
		else:
			file_selector.set_directory(file.path, EMPTY_FOLDER_ICON if file.is_empty else FOLDER_ICON)
			file_selector.double_click.connect(navigate_to_directory)
			file_selector.selected.connect(_on_directory_selected)
			if !all_button_enabled: 
				%FileContainer.move_child(file_selector, 0)

	refresh_delay_timer = 0.05


func _setup_file_node(node: Control, path: String) -> void:
	# Specific logic for RPG Godot Creator Character previews
	if path in FileCache.cache.characters:
		var res = load(path)
		if res is RPGLPCCharacter:
			var preview = res.character_preview
			node.set_path(path, preview, path.replace("_data.%s" % path.get_extension(), "").get_file())
		else:
			node.set_path(path)
	elif path in FileCache.cache.events:
		var res = load(path)
		if res is RPGLPCCharacter:
			var preview = res.event_preview
			node.set_path(path, preview, path.replace("_data.%s" % path.get_extension(), "").get_file())
		else:
			node.set_path(path)
	else:
		node.set_path(path)
		
	node.selected.connect(_on_file_selected)
	node.double_click.connect(select_file)
	node.add_to_favorite_requested.connect(_add_to_favorite)
	node.show_favorite_button()
	if path.to_lower() == current_file_selected.to_lower():
		node.select()


func _check_all_nodes_visibility() -> void:
	var children = %FileContainer.get_children()
	for child in children:
		var global_rect = child.get_global_rect()
		var view_rect = scroll_container.get_global_rect()
		if view_rect.intersects(global_rect):
			if child.has_method("enable"): child.enable()
		else:
			if child.has_method("disable"): child.disable()
			
	# Trigger next page if scroll is near bottom
	var scroll = scroll_container.get_v_scroll_bar()
	if scroll.value > (scroll.max_value - scroll.page - 100):
		if (current_page * items_per_page) < filtered_files_pool.size():
			_paginate_next_batch()


func navigate_to_directory(path: String, add_to_history: bool = true) -> void:
	path = _clean_path(path)
	
	if path == current_directory:
		return

	if add_to_history:
		if not current_directory.is_empty():
			history.back.append(current_directory)
		history.next.clear()
	
	current_directory = path
	current_page = 0
	
	current_file_selected = ""
	current_directory_selected = ""
	%CurrentPath.text = current_directory
	_update_label_path_selected()
	_update_history_buttons()
	_refresh_view()


func _refresh_view() -> void:
	match current_file_type:
		0: fill_files(current_file_filters_data, false)
		1: fill_files_by_extension(current_directory, current_file_filters_data, false)
		2: fill_mix_files(current_file_filters_data, false)


func _on_all_button_toggled(toggled_on: bool) -> void:
	all_button_enabled = toggled_on
	
	if toggled_on:
		favorite_button_enabled = false
		%FavoriteButton.set_pressed_no_signal(false)
	
	if not toggled_on:
		if current_directory.is_empty():
			if not last_folder_visited.is_empty():
				current_directory = last_folder_visited
			else:
				current_directory = "res://"
		
		current_directory = _clean_path(current_directory)
		
		%CurrentPath.text = current_directory
		
		_update_history_buttons()
	
	if FileCache.options:
		FileCache.options.file_dialog_all_files_toggled = toggled_on
		
	_refresh_view()


func _on_favorite_button_toggled(toggled_on: bool) -> void:
	favorite_button_enabled = toggled_on
	if toggled_on:
		all_button_enabled = false
		%AllButton.set_pressed_no_signal(false)
		
	if FileCache.options:
		FileCache.options.file_dialog_favorite_toggled = toggled_on
		
	_refresh_view()


func _on_visibility_changed() -> void:
	if visible:
		_refresh_view()


func _on_ok_button_pressed() -> void:
	if dialog_mode == 1:
		if not current_directory_selected.is_empty():
			select_file(current_directory_selected)
		else:
			select_file(current_directory)
			
	else:
		if not current_file_selected.is_empty():
			select_file(current_file_selected)
		elif not current_directory_selected.is_empty():
			navigate_to_directory(current_directory_selected)


func select_file(path: String) -> void:
	if target_callable: target_callable.call(path)
	hide()


func _on_file_selected(node: Control) -> void:
	for child in %FileContainer.get_children(): child.deselect()
	node.select()
	current_file_selected = node.path
	current_path = node.path
	_update_label_path_selected()


func _on_directory_selected(node: Control) -> void:
	for child in %FileContainer.get_children():
		if child != node: child.deselect()
	
	current_directory_selected = node.path
	current_path = node.path
	_update_label_path_selected()


func _update_label_path_selected() -> void:
	var text_to_show = ""
	
	if not current_file_selected.is_empty():
		text_to_show = current_file_selected
	elif not current_directory_selected.is_empty():
		text_to_show = current_directory_selected
	else:
		text_to_show = current_directory
		
	%PathSelected.text = " " + text_to_show if not text_to_show.is_empty() else " -"


func set_all_files_visibility_timer(_p=null) -> void:
	refresh_delay_timer = 0.05


func hide_loading() -> void:
	%Loading.visible = false
	%NoFilesFound.visible = (%FileContainer.get_child_count() == 0 and queue_files.is_empty() and filtered_files_pool.is_empty())


func _on_cancel_button_pressed() -> void:
	hide()


func _is_directory_empty(path: String) -> bool:
	var dir = DirAccess.open(path)
	if !dir: return true
	dir.list_dir_begin()
	var first = dir.get_next()
	return first == "" or first == "."


func apply_filter(filter_text: String) -> void:
	for child in %FileContainer.get_children():
		child.visible = filter_text.is_empty() or child.path.get_file().to_lower().contains(filter_text.to_lower())


func _on_custom_line_edit_text_changed(new_text: String) -> void:
	filter_delay_timer = 0.25


func _save_last_folder_visited() -> void:
	if not current_directory.is_empty() and current_directory != "res://": 
		last_folder_visited = current_directory


func _update_history_buttons() -> void:
	var can_back = not history.back.is_empty() or (_clean_path(current_directory) != "res://")
	%Back.set_disabled(not can_back)
	%Back.modulate = Color.WHITE if can_back else Color(0.5, 0.5, 0.5, 0.5)
	
	var can_next = not history.next.is_empty()
	%Next.set_disabled(not can_next)
	%Next.modulate = Color.WHITE if can_next else Color(0.5, 0.5, 0.5, 0.5)


func _on_back_button_pressed() -> void:
	var prev: String
	if not history.back.is_empty():
		prev = history.back.pop_back()
	else:
		prev = current_directory.get_base_dir()
	history.next.append(current_directory)
	navigate_to_directory(prev, false)
	_update_history_buttons()


func _on_next_button_pressed() -> void:
	if not history.next.is_empty():
		var next_path = history.next.pop_back()
		history.back.append(current_directory)
		navigate_to_directory(next_path, false)
		_update_history_buttons()


func _select_other_file(_i, _d): pass


func _add_to_favorite(path: String) -> void:
	var options_cache = FileCache.options
	if options_cache:
		if not "favorite_files" in options_cache:
			options_cache.favorite_files = {}
		options_cache.favorite_files[path] = current_file_filters_data


func hide_directory_extra_controls2() -> void:
	var node = %DirectoryExtraControls2
	if node:
		node.visible = false


func _on_rebuild_cache_pressed() -> void:
	FileCache.rebuild(true)
	await FileCache.cache_setted
	_refresh_view()
