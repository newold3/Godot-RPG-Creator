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

# Token to validate async operations and prevent race conditions
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
	#scroll_container.get_v_scroll_bar().value_changed.connect(set_all_files_visibility_timer)
	%FileContainer.item_rect_changed.connect(set_all_files_visibility_timer)
	
	if FileCache.options:
		var p_favorite_button_enabled = FileCache.options.get("file_dialog_favorite_toggled", false)
		%FavoriteButton.set_pressed_no_signal(p_favorite_button_enabled)
		var p_all_button_enabled = FileCache.options.get("file_dialog_all_files_toggled", false)
		#%AllButton.set_pressed_no_signal(p_all_button_enabled)
		%AllButton.set_pressed(p_all_button_enabled)
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
	if all_button_enabled and not favorite_button_enabled:
		%AllButton.set_pressed_no_signal(true)
	elif not all_button_enabled and favorite_button_enabled:
		%FavoriteButton.set_pressed_no_signal(true)


func set_dialog_mode(id: int) -> void:
	dialog_mode = clamp(id, 0, 1)
	var directory_controls_visible = (id == 1)
	%DirectoryExtraControls1.visible = directory_controls_visible
	#%DirectoryExtraControls2.visible = directory_controls_visible
	title = TranslationManager.tr("Select File") if dialog_mode == 0 else TranslationManager.tr("Select Directory")
	history.back.clear()
	history.next.clear()
	%FavoriteButton.visible = dialog_mode == 0
	%AllButton.visible = dialog_mode == 0


func hide_directory_extra_controls2() -> void:
	%DirectoryExtraControls2.visible = false


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
	if (history_id == "back" and current_directory != "res://") or not history[history_id].is_empty():
		button.set_disabled(false)
		button.modulate = Color.WHITE
	else:
		button.set_disabled(true)
		button.modulate = Color("#50505067")


func _clear_current_files() -> void:
	_load_token += 1 # Invalidate previous async operations
	%FilterLineEdit.text = ""
	for file in %FileContainer.get_children():
		file.queue_free()
	queue_files.clear()


func _get_files_in_cache(file_id: String) -> PackedStringArray:
	if file_id:
		if !FileCache.cache_setted:
			%Loading.visible = true
			FileCache.rescan_files()
			await FileCache.cache_ready
		if file_id in FileCache.cache:
			var files = FileCache.cache[file_id].keys()
			return files
	
	return []


func _get_files_recursive(path: String, extensions: Array) -> PackedStringArray:
	var found_files: PackedStringArray = []
	var dir = DirAccess.open(path)
	if dir == null:
		print(tr("Error: Could not open directory") + ": ", path)
		return []
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		var full_path = path.path_join(file_name)
		
		if dir.current_is_dir():
			found_files.append_array(_get_files_recursive(full_path, extensions))
		else:
			var file_extension = file_name.get_extension().to_lower()
			
			var lower_extensions: Array[String] = []
			for ext in extensions:
				lower_extensions.append(ext.to_lower())
			
			if file_extension in lower_extensions:
				found_files.append(full_path)
		
		file_name = dir.get_next()
	
	return found_files


func _get_folders(dir_path: String) -> PackedStringArray:
	if dir_path.is_empty():
		dir_path = "res://"
	
	var directories: PackedStringArray = []
	
	var dir = DirAccess.open(dir_path)
	
	if dir == null:
		push_error("Error accessing directory: " + dir_path)
		return []
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if dir.current_is_dir():
			directories.append(dir_path.path_join(file_name))
		file_name = dir.get_next()

	dir.list_dir_end()
	
	return directories


func _get_directory_selected() -> String:
	if dialog_mode == 1:
		if not current_directory_selected.is_empty():
			return current_directory_selected
		if not current_directory.is_empty():
			return current_directory

	if (dialog_mode == 0 and file_mode == FILE_MODE.NAVIGABLE) or dialog_mode == 1:
		if current_file_selected.is_empty():
			return "res://"
		elif FileAccess.file_exists(current_file_selected):
			return current_file_selected.get_base_dir()
		else:
			return current_file_selected

	return "" if not (dialog_mode == 0 and file_mode == FILE_MODE.NAVIGABLE) else "res://"


func _append_folders(dir_path: String) -> void:
	var folders = _get_folders(dir_path)
	for folder in folders:
		queue_files.append(FileStruct.new(folder, "directory", "", _is_directory_empty(folder)))
	
	current_directory = dir_path
	%CurrentPath.text = current_directory
	%DirectoryExtraControls1.visible = true


func _get_base_directory_with_last_visited(default_path: String) -> String:
	if (default_path == "res://" or default_path.is_empty()) and not last_folder_visited.is_empty():
		return last_folder_visited
	return default_path


func _fill_favorite_files() -> void:
	%DirectoryExtraControls1.visible = false
	_clear_current_files()
	
	var options_cache = FileCache.options
	if options_cache:
		if "favorite_files" in options_cache:
			var favorite_files = options_cache.favorite_files
			for file in favorite_files:
				var file_id = str(favorite_files[file])
				if file_id == str(current_file_filters_data):
					queue_files.append(FileStruct.new(file, "file"))
				elif current_file_filters_data is Array or current_file_filters_data is PackedStringArray:
					var ext = file.get_extension()
					for id in current_file_filters_data:
						if ext == str(id):
							queue_files.append(FileStruct.new(file, "file"))
							break
	
	hide_loading()


func fill_files(file_id: String, update_directory: bool = true) -> void:
	current_cache_key = file_id
	current_file_filters_data = current_cache_key
	current_file_type = 0
	
	if favorite_button_enabled:
		_fill_favorite_files()
		return
	
	_clear_current_files()
	var current_token = _load_token
	
	# Add directories
	var base_dir = _get_directory_selected() if update_directory else current_directory
	if all_button_enabled:
		base_dir = ""
	if not base_dir.is_empty():
		base_dir = _get_base_directory_with_last_visited(base_dir) if update_directory else base_dir
		_append_folders(base_dir)
	else:
		%DirectoryExtraControls1.visible = false
		
	# Add Files
	var files = await _get_files_in_cache(file_id)
	
	# Race condition check
	if current_token != _load_token:
		return
		
	hide_loading()
	for file in files:
		if not base_dir.is_empty():
			if file.get_base_dir() == base_dir:
				queue_files.append(FileStruct.new(file, "file"))
		else:
			queue_files.append(FileStruct.new(file, "file"))


func fill_mix_files(file_ids: PackedStringArray, update_directory: bool = true) -> void:
	current_cache_key = file_ids
	current_file_filters_data = current_cache_key
	current_file_type = 2
	
	if favorite_button_enabled:
		_fill_favorite_files()
		return
		
	_clear_current_files()
	var current_token = _load_token
	
	# Add directories
	var base_dir = _get_directory_selected() if update_directory else current_directory
	if all_button_enabled:
		base_dir = ""
	if not base_dir.is_empty():
		base_dir = _get_base_directory_with_last_visited(base_dir) if update_directory else base_dir
		_append_folders(base_dir)
	else:
		%DirectoryExtraControls1.visible = false
		
	# Add Files
	for file_id in file_ids:
		var files = await _get_files_in_cache(file_id)
		
		if current_token != _load_token:
			return
			
		hide_loading()
		for file in files:
			if not base_dir.is_empty():
				if file.get_base_dir() == base_dir:
					queue_files.append(FileStruct.new(file, "file"))
			else:
				queue_files.append(FileStruct.new(file, "file"))


func fill_files_by_extension(path: String = "res://", extensions: Array = [], update_directory: bool = true)-> void:
	current_cache_key = extensions
	current_file_filters_data = current_cache_key
	current_file_type = 1
	
	if favorite_button_enabled:
		_fill_favorite_files()
		return
		
	_clear_current_files()
	# No await here, but good practice to maintain consistency if recursive search becomes async
	var current_token = _load_token 
	
	if not path.is_empty() and not path == "res://":
		current_path = path
		current_file_selected = path
		_update_label_path_selected()
	
	# Add directories
	var base_dir = path.get_base_dir() if update_directory else current_directory
	if all_button_enabled:
		base_dir = ""
	if not base_dir.is_empty():
		base_dir = _get_base_directory_with_last_visited(base_dir) if update_directory else base_dir
		_append_folders(base_dir)
	else:
		%DirectoryExtraControls1.visible = false
		
	# Add Files
	var files = _get_files_recursive(base_dir, extensions)
	
	if current_token != _load_token:
		return
		
	hide_loading()
	for file in files:
		if not base_dir.is_empty():
			if file.get_base_dir() == base_dir:
				queue_files.append(FileStruct.new(file, "file"))
		else:
			queue_files.append(FileStruct.new(file, "file"))


func _is_directory_empty(dir_path: String) -> bool:
	var dir: DirAccess = DirAccess.open(dir_path)
	
	if DirAccess.get_open_error() != OK:
		return true
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		if !file_name.begins_with("."):
			return false
		file_name = dir.get_next()
	
	return true


func set_directories(path: String, step: int = 0) -> void:
	var current_token = _load_token # Capture token from caller context if possible, or assume current
	if step == 0:
		_clear_current_files()
		current_token = _load_token # Get the new token after clear
	
	var dir: DirAccess = DirAccess.open(path)
	current_directory_count = 0
	
	if DirAccess.get_open_error() == OK:
		current_directory = path
		%CurrentPath.text = current_directory
		
		dir.list_dir_begin()
		
		var file_name = dir.get_next()
		
		while file_name != "":
			if current_token != _load_token: return # Cancel if navigated away
			
			if dir.current_is_dir() and !file_name.begins_with("."):
				var dir_path = dir.get_current_dir().path_join(file_name)
				queue_files.append(FileStruct.new(dir_path, "directory", "", _is_directory_empty(dir_path)))
				current_directory_count += 1
			
			file_name = dir.get_next()
			
			file_count += 1
			if file_count % 30 == 0:
				await get_tree().process_frame

	if step == 0:
		hide_loading()


func hide_loading() -> void:
	%Loading.visible = false
	if %FileContainer.get_child_count() == 0 and queue_files.size() == 0 and dialog_mode == 0:
		%NoFilesFound.visible = true
		#%OKButton.set_disabled(true)


func populate_files() -> void:
	if queue_files.is_empty():
		return

	%Loading.visible = false
	%NoFilesFound.visible = false
	
	# Sorting logic here...
	var folders = queue_files.filter(func(f): return f.type == "directory")
	folders.sort_custom(func(a, b): return a.path.naturalnocasecmp_to(b.path) < 0)

	var keys = cache_last_selection.get(current_cache_key, [])
	var cache_files = queue_files.filter(func(f): return f.type != "directory" and keys.has(f.path))
	cache_files.sort_custom(func(a, b): return keys.find(a.path) > keys.find(b.path))

	var other_files = queue_files.filter(func(f): return f.type != "directory" and not keys.has(f.path))
	other_files.sort_custom(func(a, b): return a.path.naturalnocasecmp_to(b.path) > 0)
	
	queue_files = folders + cache_files + other_files

	var filter_node = %FilterLineEdit

	# Process chunk
	for i in range(min(40, queue_files.size())):
		if queue_files.is_empty(): break
		
		var file: FileStruct = queue_files.pop_back()
		var path = file.path
		
		if ignore_folders.any(func(ignore_path): return path.begins_with(ignore_path)):
			continue
			
		if (
			(dialog_mode == 0 and not FileAccess.file_exists(path)) or
			(dialog_mode == 1 and not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(path)))
		):
			if not (dialog_mode == 0 and file_mode == FILE_MODE.NAVIGABLE and file.type == "directory"):
				continue
			
		var file_selector = FILE_SELECTOR.instantiate()
		file_selector.select_other.connect(_select_other_file)
		
		%FileContainer.add_child(file_selector)
		if file.type == "file":
			if path in FileCache.cache.characters:
				if path.get_extension() != "tres":
					file_selector.queue_free()
					continue
				var res = load(path)
				if res is RPGLPCCharacter:
					file_selector.set_path(path, res.character_preview,
					path.replace("_data.%s" % path.get_extension(), "").get_file())
				else:
					file_selector.queue_free()
					continue
			elif path in FileCache.cache.equipment_parts:
				var res: RPGLPCEquipmentPart = load(path)
				file_selector.set_path(res.name, res.equipment_preview)
				file_selector.path = path
			elif path in FileCache.cache.events:
				var res: RPGLPCCharacter = load(path)
				file_selector.set_path(path, res.event_preview,
				path.replace("_data.%s" % path.get_extension(), "").get_file())
			else:
				file_selector.set_path(path)
			file_selector.selected.connect(_on_file_selected)
			file_selector.double_click.connect(select_file)
			file_selector.add_to_favorite_requested.connect(_add_to_favorite)
			file_selector.remove_from_favorite_requested.connect(_remove_from_favorite)
			file_selector.show_favorite_button()
		elif file.type == "directory":
			if file.is_empty:
				file_selector.set_directory(path, EMPTY_FOLDER_ICON)
			else:
				file_selector.set_directory(path, FOLDER_ICON)
			file_selector.selected.connect(_on_directory_selected)
			file_selector.double_click.connect(
				func(p_path: String):
					navigate_to_directory(p_path)
					history.next.clear()
			)
			if file_selector.get_index() >= current_directory_count:
				%FileContainer.move_child(file_selector, 0)

		if path.to_lower() == current_file_selected.to_lower():
			try_select_current_file(file_selector)
		
		file_selector.visible = filter_node.text.length() == 0 or file_selector.path.to_lower().find(filter_node.text.to_lower()) != -1
		file_selector.is_hidden = !file_selector.visible
		
		var current_cache = cache_last_selection.get(current_cache_key, [])
		var file_is_in_cache = current_cache.has(file_selector.path)
		if file_is_in_cache and file.type == "file":
			%FileContainer.move_child(file_selector, current_directory_count)
		
	var t = get_tree().create_timer(0.03)
	t.timeout.connect(set_all_files_visibility_timer)


func _add_to_favorite(path: String) -> void:
	var options_cache = FileCache.options
	if options_cache:
		if not "favorite_files" in options_cache:
			options_cache.favorite_files = {}
		options_cache.favorite_files[path] = current_file_filters_data


func _remove_from_favorite(path: String) -> void:
	var options_cache = FileCache.options
	if options_cache and "favorite_files" in options_cache:
		options_cache.favorite_files.erase(path)


func _check_node_visibility(file_selector: FileSelector) -> void:
	if file_selector.is_hidden:
		return
		
	var global_rect = file_selector.get_global_rect()
	var scroll_container_global_rect = scroll_container.get_global_rect()
	var intersection = scroll_container_global_rect.intersects(global_rect, true)

	if not file_selector.is_enabled and intersection:
		file_selector.enable()
	elif file_selector.is_enabled and not intersection:
		file_selector.disable()


func _check_all_nodes_visibility() -> void:
	for child: FileSelector in %FileContainer.get_children():
		_check_node_visibility(child)


func set_all_files_visibility_timer(_param: float = 0.0) -> void:
	refresh_delay_timer = 0.01


func _select_other_file(index: int, direction: int) -> void:
	# Direction -> 0 up, 1 left, 2 down, 3 right
	var current_selection = null
	var children = %FileContainer.get_children()
	if direction == 0:
		for i in range(index - 1, -1, -1):
			if children[i].global_position.x ==  children[index].global_position.x:
				children[i].select()
				current_selection = children[i]
				break
	elif direction == 2:
		for i in range(index + 1, children.size(), 1):
			if children[i].global_position.x ==  children[index].global_position.x:
				children[i].select()
				current_selection = children[i]
				break
	elif direction == 1:
		if index - 1 >= 0:
			children[index - 1].select()
			current_selection = children[index - 1]
	elif direction == 3:
		if index + 1 < children.size():
			children[index + 1].select()
			current_selection = children[index + 1]
	
	if !current_selection:
		if direction == 0:
			for i in range(children.size() - 1, index, -1):
				if children[i].global_position.x ==  children[index].global_position.x:
					children[i].select()
					current_selection = children[i]
					break
		elif direction == 2:
			for i in range(0, index, 1):
				if children[i].global_position.x ==  children[index].global_position.x:
					children[i].select()
					current_selection = children[i]
					break
		elif direction == 1:
			children[-1].select()
			current_selection = children[-1]
		elif direction == 3:
			children[0].select()
			current_selection = children[0]
	
	if current_selection:
		current_selection.selected.emit(current_selection)


func try_select_current_file(file_selector: FileSelector) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	if visible and is_instance_valid(file_selector):
		file_selector.select()
		%OKButton.set_disabled(false)
		await get_tree().process_frame
		if visible:
			%FilterLineEdit.grab_focus()


func _on_file_selected(current_file: FileSelector) -> void:
	for file in %FileContainer.get_children():
		file.deselect()
		
	current_file.select()
	
	current_path = current_file.path
	current_file_selected = current_file.path
	current_directory_selected = ""
	_update_label_path_selected()
	
	if auto_play_sounds and ["wav", "ogg", "mp3"].has(current_path.get_extension().to_lower()):
		var player: AudioStreamPlayer = %AudioStreamPlayer
		player.stop()
		player.stream = load(current_path)
		player.play()
	
	await get_tree().process_frame
	%FilterLineEdit.grab_focus()
	%OKButton.set_disabled(false)


func select_file(path: String) -> void:
	if not path.is_empty() and not path == "res://":
		if target_callable:
			target_callable.call(path)
	if !destroy_on_hide:
		hide()
	else:
		queue_free()
	if not current_cache_key in cache_last_selection:
		cache_last_selection[current_cache_key] = []
	if path in cache_last_selection[current_cache_key]:
		cache_last_selection[current_cache_key].erase(path)
	if cache_last_selection[current_cache_key].size() > MAX_CACHE_LAST_SELECTION_FILES:
		cache_last_selection[current_cache_key].pop_front()
	cache_last_selection[current_cache_key].append(path)


func _on_directory_selected(current_file: FileSelector) -> void:
	current_directory_selected = current_file.path
	current_path = current_file.path if dialog_mode == 1 else ""
	current_file_selected = ""
	_update_label_path_selected()
	for file in %FileContainer.get_children():
		file.deselect()
	
	await get_tree().process_frame
	%Filename.grab_focus()
	%OKButton.set_disabled(false)


func navigate_to_directory(path: String) -> void:
	current_directory = path
	current_directory = current_directory.trim_suffix("/")
	
	if current_directory == "res:/":
		current_directory = "res://"
		
	current_directory_selected = ""
	current_path = ""
	current_file_selected = ""
	
	if dialog_mode == 0:
		%OKButton.set_disabled(true)
	else:
		%OKButton.set_disabled(false)
		current_directory_selected = path
		current_path = path
		# Update label immediately to reflect navigation
		_update_label_path_selected()
	
	if dialog_mode == 1:
		_clear_current_files() # Clear before refilling to avoid visual glitches
		_append_folders(current_directory)
		hide_loading()
	elif dialog_mode == 0 and file_mode == FILE_MODE.NAVIGABLE:
		match current_file_type:
			0:
				await fill_files(current_file_filters_data, false)
				return
			1:
				fill_files_by_extension(current_directory, current_file_filters_data, false)
				return
			2:
				await fill_mix_files(current_file_filters_data, false)
				return
	
	await get_tree().process_frame
	%Filename.grab_focus()


func _on_ok_button_pressed() -> void:
	if %OKButton.is_disabled():
		if !destroy_on_hide:
			hide()
		else:
			queue_free()
	else:
		var path: String
		if dialog_mode == 0:
			if file_mode == FILE_MODE.NAVIGABLE and current_file_selected.is_empty() and not current_directory_selected.is_empty():
				navigate_to_directory(current_directory_selected)
				return
			elif not current_path.is_empty():
				path = current_file_selected
		else:
			path = current_directory_selected

		if !path.begins_with("res://"):
			path = ProjectSettings.localize_path(path)
		
		select_file(path)


func _on_cancel_button_pressed() -> void:
	if !destroy_on_hide:
		hide()
	else:
		queue_free()


func _on_custom_line_edit_text_changed(new_text: String) -> void:
	if new_text.length() != 0:
		%FilterLineEdit.right_icon = ResourceLoader.load("res://addons/CustomControls/Images/filter_reset.png")
	else:
		%FilterLineEdit.right_icon = ResourceLoader.load("res://addons/CustomControls/Images/magnifying_glass.png")
	filter_delay_timer = 0.25


func apply_filter(filter_text) -> void:
	for child in %FileContainer.get_children():
		child.visible = filter_text.length() == 0 or child.path.get_file().to_lower().find(filter_text.to_lower()) != -1
		if child.visible:
			child.set_text_selected(filter_text)
		else:
			child.set_text_selected("")


func _on_filter_line_edit_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.is_pressed():
			if event.button_index == MOUSE_BUTTON_LEFT:
				if %FilterLineEdit.text.length() > 0:
					if event.position.x >= %FilterLineEdit.size.x - 22:
						%FilterLineEdit.text = ""
						_on_custom_line_edit_text_changed("")
	elif event is InputEventMouseMotion:
		if event.position.x >= %FilterLineEdit.size.x - 22:
			%FilterLineEdit.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		else:
			%FilterLineEdit.mouse_default_cursor_shape = Control.CURSOR_IBEAM


func _on_visibility_changed() -> void:
	if visible:
		await get_tree().process_frame
		if visible:
			reset()
			%FilterLineEdit.grab_focus()
	else:
		_save_last_folder_visited()


func _save_last_folder_visited() -> void:
	var folder_to_save = ""
	if dialog_mode == 0:
		if not current_file_selected.is_empty() and FileAccess.file_exists(current_file_selected):
			folder_to_save = current_file_selected.get_base_dir()
		elif not current_directory.is_empty() and current_directory != "res://":
			folder_to_save = current_directory
	elif dialog_mode == 1:
		if not current_directory_selected.is_empty() and current_directory_selected != "res://":
			folder_to_save = current_directory_selected
		elif not current_directory.is_empty() and current_directory != "res://":
			folder_to_save = current_directory
	if not folder_to_save.is_empty() and folder_to_save != "res://":
		if not folder_to_save.begins_with("res://"):
			folder_to_save = "res://" + folder_to_save
		last_folder_visited = folder_to_save
	else:
		last_folder_visited = ""


func _on_back_button_pressed() -> void:
	var path: String

	if history.back.size() > 0:
		path = history.back.pop_back()
		if !history.next.has(path):
			history.next.append(path)
	elif current_directory != "res://":
		if !history.next.has(current_directory):
			history.next.append(current_directory)
		var path_arr = Array(current_directory.trim_suffix("/").split("/"))
		path_arr.pop_back()
		path = "/".join(path_arr)
		
	if path.is_empty():
		path = "res://"
	if path == "res:/": path = "res://"
	if !path.ends_with("/"): path += "/"

	navigate_to_directory(path)
	
	if history.back.has(current_directory):
		history.back.erase(current_directory)
	if history.next.has(current_directory):
		history.next.erase(current_directory)
	
	await get_tree().process_frame
	%Filename.grab_focus()


func _on_next_button_pressed() -> void:
	if history.next.size() > 0:
		var path = history.next.pop_back()
		if !history.back.has(path):
			history.back.append(path)
		navigate_to_directory(path)
	
	if history.back.has(current_directory):
		history.back.erase(current_directory)
	if history.next.has(current_directory):
		history.next.erase(current_directory)
	
	await get_tree().process_frame
	%Filename.grab_focus()


func _on_create_folder_pressed() -> void:
	var path = "res://addons/CustomControls/Dialogs/select_text_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	dialog.title = TranslationManager.tr("New Folder name")
	dialog.text_selected.connect(_create_new_folder)


func _create_new_folder(text: String) -> void:
	current_directory = current_directory.path_join(text)
	_update_label_path_selected()
	var absolute_path = ProjectSettings.globalize_path(current_directory)
	if !DirAccess.dir_exists_absolute(absolute_path):
		DirAccess.make_dir_recursive_absolute(absolute_path)
		
	navigate_to_directory(current_directory)


func _update_label_path_selected() -> void:
	if not current_path.is_empty():
		%PathSelected.text = " " + current_path
	else:
		%PathSelected.text = " -"


func clear_files() -> void:
	for file in %FileContainer.get_children():
		file.queue_free()


func _on_rebuild_cache_pressed() -> void:
	clear_files()
	%Loading.visible = true
	FileCache.rebuild()
	await FileCache.main_scene.cache_ready
	%Loading.visible = false
	if file_type_arr:
		fill_mix_files(file_type_arr)
	else:
		fill_files(file_type)


func _on_favorite_button_toggled(toggled_on: bool) -> void:
	favorite_button_enabled = toggled_on
	if FileCache.options:
		FileCache.options.file_dialog_favorite_toggled = favorite_button_enabled
	if favorite_button_enabled: # Show items saved in favorites
		%AllButton.set_pressed_no_signal(false)
		_fill_favorite_files()
	else:
		navigate_to_directory(current_directory)
		if all_button_enabled:
			%AllButton.set_pressed_no_signal(true)
			%DirectoryExtraControls1.visible = false
		else:
			%DirectoryExtraControls1.visible = true


func _on_all_button_toggled(toggled_on: bool) -> void:
	all_button_enabled = toggled_on
	if FileCache.options:
		FileCache.options.file_dialog_all_files_toggled = all_button_enabled
	var dir = "res://" if current_directory.is_empty() and last_folder_visited.is_empty() \
		else current_directory if not current_directory.is_empty() \
		else last_folder_visited
	if all_button_enabled: # Show all items without folders
		%FavoriteButton.set_pressed_no_signal(false)
		favorite_button_enabled = false
		navigate_to_directory(dir)
		%DirectoryExtraControls1.visible = false
	else:
		navigate_to_directory(dir)
		%DirectoryExtraControls1.visible = true
