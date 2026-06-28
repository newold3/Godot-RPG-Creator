@tool
class_name CustomFileDialog
extends Window


## Internal structure to manage file rendering data.
class FileStruct:
	var path: String
	var type: String # File, Directory
	var icon: String
	var is_empty: bool # only applied directory
	
	
	## Initializes the file structure data.
	func _init(p_path: String, p_type: String, p_icon: String = "", p_is_empty: bool = false) -> void:
		path = p_path
		type = p_type
		icon = p_icon
		is_empty = p_is_empty
	
	
	## Returns the string representation of the file structure.
	func _to_string() -> String:
		return "<FileStruct path=\"%s\" type=\"%s\" icon=\"%s\"" % [path, type, icon]


## Number of files to show per page to prevent Godot preview crashes.
@export var items_per_page: int = 50

## List of folder paths to ignore during traversal.
@export var ignore_folders: Array[String] = []

## Toggle to allow multiple file selection in the custom dialog UI.
@export var allow_multiple_selection: bool = false

## Slider reference for adjusting the icon size dynamically.
@export var icon_size_slider: Slider

var current_files_selected: PackedStringArray = []
var last_selected_node: Control = null
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
var filtered_files_pool: Array[FileStruct] = []
var current_page: int = 0
var auto_play_sounds: bool = false
var current_cache_key: Variant = null
var current_icon_size: int = 96
const MAX_CACHE_LAST_SELECTION_FILES = 20

enum FILE_MODE {
	ALL,
	NAVIGABLE
}

var file_mode: FILE_MODE = FILE_MODE.NAVIGABLE
var current_file_type: int = 0 # 0 = fill_files, 1 = fill_files_by_extension, 2 = fill_mix_files
var current_file_filters_data: Variant = ""
var current_regex_cache_ids: PackedStringArray = []
var cached_regex_results: Array[String] = []
var last_regex_pattern: String = ""
var favorite_button_enabled: bool = false
var all_button_enabled: bool = false
var _load_token: int = 0
var _was_all_mode_before_favorite: bool = false
static var cache_last_selection: Dictionary = {}
static var last_folder_visited: String = ""

@onready var expression = Expression.new()
@onready var scroll_container: ScrollContainer = %ScrollContainer
@onready var audio_preview_player: AudioStreamPlayer = %AudioStreamPlayer



#region Lifecycle Methods

## Called when the node enters the scene tree for the first time.
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
		if FileCache.options.has("file_dialog_icon_size"):
			current_icon_size = FileCache.options.file_dialog_icon_size
	if icon_size_slider:
		icon_size_slider.value_changed.connect(_on_icon_size_changed)
		icon_size_slider.value = current_icon_size


## Processes frame updates for timers and pagination.
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


#endregion
#region Core State & Setup

## Resets the state of the dialog and clears all selections.
func reset() -> void:
	_clear_current_files()
	set_dialog_mode(0)
	current_path = ""
	current_file_selected = ""
	current_files_selected.clear()
	last_selected_node = null
	current_directory = ""
	current_directory_selected = ""
	target_callable = skip
	destroy_on_hide = false
	file_count = 0
	last_regex_pattern = ""
	cached_regex_results.clear()
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


## Sets the dialog mode between file selection and directory selection.
func set_dialog_mode(id: int) -> void:
	dialog_mode = clamp(id, 0, 1)
	title = TranslationManager.tr("Select File") if dialog_mode == 0 else TranslationManager.tr("Select Directory")
	%FavoriteButton.visible = dialog_mode == 0
	%AllButton.visible = dialog_mode == 0
	_update_ui_controls()


## Placeholder callable function for unassigned target callbacks.
func skip(_path: String) -> void:
	pass


## Clears all current file nodes and resets pools.
func _clear_current_files() -> void:
	_load_token += 1
	for file in %FileContainer.get_children():
		file.queue_free()
	queue_files.clear()
	filtered_files_pool.clear()
	current_page = 0


## Saves the last visited folder to state when closing.
func _save_last_folder_visited() -> void:
	if not current_directory.is_empty() and current_directory != "res://":
		last_folder_visited = current_directory


#endregion
#region File Population & Generation

## Populates a specific file type by ID.
func fill_files(file_id: String, update_directory: bool = true, filter_text: String = "") -> void:
	file_type = file_id
	current_cache_key = file_id
	current_file_filters_data = current_cache_key
	current_file_type = 0
	
	if favorite_button_enabled:
		_fill_favorite_files(filter_text)
		return
	
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
			if not filter_text.is_empty() and not filter_text.to_lower() in file.get_file().to_lower():
				continue
			
			filtered_files_pool.append(FileStruct.new(file, "file"))
			
	_prioritize_recent_files()
	_paginate_next_batch()
	hide_loading()


## Fills the file pool mixing multiple file cache IDs securely avoiding loop awaits.
func fill_mix_files(file_ids: PackedStringArray, update_directory: bool = true, filter_text: String = "") -> void:
	current_cache_key = file_ids
	current_file_filters_data = current_cache_key
	current_file_type = 2
	
	if favorite_button_enabled:
		_fill_favorite_files(filter_text)
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
		
	if not FileCache.cache_setted:
		%Loading.visible = true
		FileCache.rescan_files()
		await StaticSignal.wait_for("_cache_ready")
		
	if current_token != _load_token: return
		
	for id in file_ids:
		if id in FileCache.cache:
			var files = FileCache.cache[id].keys()
			for file in files:
				if all_button_enabled or _clean_path(file.get_base_dir()) == base_dir:
					if not filter_text.is_empty() and not filter_text.to_lower() in file.get_file().to_lower():
						continue
					
					filtered_files_pool.append(FileStruct.new(file, "file"))
				
	_prioritize_recent_files()
	_paginate_next_batch()
	hide_loading()


## Fills the list gathering files specifically by their extensions.
func fill_files_by_extension(path: String = "res://", extensions: Array = [], update_directory: bool = true, filter_text: String = "")-> void:
	current_cache_key = extensions
	current_file_filters_data = current_cache_key
	current_file_type = 1
	
	if favorite_button_enabled:
		_fill_favorite_files(filter_text)
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
			if not filter_text.is_empty() and not filter_text.to_lower() in file.get_file().to_lower():
				continue
			
			filtered_files_pool.append(FileStruct.new(file, "file"))
			
	_prioritize_recent_files()
	_paginate_next_batch()
	hide_loading()


## Fills the file pool using a regex pattern search in the specified path.
func fill_files_by_regex(path: String, regex_pattern: String, cache_ids: PackedStringArray = PackedStringArray(), filter_text: String = "") -> void:
	current_file_type = 3
	current_cache_key = regex_pattern
	current_file_filters_data = current_cache_key
	current_regex_cache_ids = cache_ids
	
	if favorite_button_enabled:
		_fill_favorite_files(filter_text)
		return
	
	_clear_current_files()
	_update_ui_controls()
	var base_dir = path if not all_button_enabled else "res://"
	var current_token = _load_token
	if regex_pattern != last_regex_pattern:
		last_regex_pattern = regex_pattern
		cached_regex_results = await search_files_by_regex(base_dir, regex_pattern, cache_ids)
	if current_token != _load_token: return
	for file in cached_regex_results:
		if not filter_text.is_empty() and not filter_text.to_lower() in file.get_file().to_lower():
			continue
		filtered_files_pool.append(FileStruct.new(file, "file"))
	_prioritize_recent_files()
	_paginate_next_batch()
	hide_loading()


## Retrieves all favorited files mapping filter states.
func _fill_favorite_files(filter_text: String = "") -> void:
	_clear_current_files()
	_update_ui_controls()
	
	var options_cache = FileCache.options
	if options_cache and "favorite_files" in options_cache:
		var favorite_files = options_cache.favorite_files
		for file in favorite_files:
			var file_id = str(favorite_files[file])
			if file_id == str(current_file_filters_data):
				if not filter_text.is_empty() and not filter_text.to_lower() in file.get_file().to_lower():
					continue
				filtered_files_pool.append(FileStruct.new(file, "file"))
	
	_prioritize_recent_files()
	_paginate_next_batch()
	hide_loading()


## Slices the pending array to retrieve the next chunk of elements into the queue.
func _paginate_next_batch() -> void:
	var start = current_page * items_per_page
	if start >= filtered_files_pool.size(): return
	
	var end = min(start + items_per_page, filtered_files_pool.size())
	queue_files.append_array(filtered_files_pool.slice(start, end))
	current_page += 1


## Instantiates UI node items from the queued file sequence.
func populate_files() -> void:
	if queue_files.is_empty(): return
	%Loading.visible = false
	%NoFilesFound.visible = false
	var folders = queue_files.filter(func(f): return f.type == "directory")
	folders.sort_custom(func(a, b): return a.path.naturalnocasecmp_to(b.path) < 0)
	for i in range(min(15, queue_files.size())):
		if queue_files.is_empty(): break
		var file = queue_files.pop_front()
		var file_selector = FILE_SELECTOR.instantiate()
		%FileContainer.add_child(file_selector)
		file_selector.set_icon_size(current_icon_size)
		if file.type == "file":
			_setup_file_node(file_selector, file.path)
		else:
			file_selector.set_directory(file.path, EMPTY_FOLDER_ICON if file.is_empty else FOLDER_ICON)
			file_selector.double_click.connect(navigate_to_directory)
			file_selector.selected.connect(_on_directory_selected)
			if !all_button_enabled:
				%FileContainer.move_child(file_selector, 0)
	refresh_delay_timer = 0.05


## Gets the specific file keys tied to an existing valid cache ID.
func _get_files_in_cache(file_id: String) -> PackedStringArray:
	if file_id:
		if !FileCache.cache_setted:
			%Loading.visible = true
			FileCache.rescan_files()
			await StaticSignal.wait_for("_cache_ready")
		if file_id in FileCache.cache:
			return FileCache.cache[file_id].keys()
	return []


## Retrieves files within a physical path via media loader matching specific extensions.
func _get_files_recursive(path: String, extensions: Array) -> PackedStringArray:
	var results = ZipMediaLoader.get_files_in_path(path, extensions, true)
	return PackedStringArray(results)


## Retrieves local and virtual folders related to a target directory.
func _get_folders(dir_path: String) -> PackedStringArray:
	dir_path = _clean_path(dir_path)
	var directories: PackedStringArray = []
	
	var dir = DirAccess.open(dir_path)
	if dir != null:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if dir.current_is_dir() and not file_name.begins_with("."):
				directories.append(dir_path.path_join(file_name))
			file_name = dir.get_next()
			
	if not ZipMediaLoader._initialized:
		ZipMediaLoader._mount_system()
		
	var clean_base = dir_path.replace("res://", "")
	if clean_base != "" and not clean_base.ends_with("/"):
		clean_base += "/"
		
	for path in ZipMediaLoader._files_index.keys():
		if path.begins_with(clean_base):
			var sub_path = path.replace(clean_base, "")
			var slash_idx = sub_path.find("/")
			
			if slash_idx != -1:
				var virtual_folder = dir_path.path_join(sub_path.left(slash_idx))
				if not directories.has(virtual_folder):
					directories.append(virtual_folder)
					
	return directories


## Populates virtual and physical directories internally targeting the path string.
func _append_folders(dir_path: String) -> void:
	var folders = _get_folders(dir_path)
	current_directory_count = folders.size()
	for folder in folders:
		queue_files.append(FileStruct.new(folder, "directory", "", _is_directory_empty(folder)))
	
	current_directory = dir_path
	%CurrentPath.text = current_directory


## Recursively retrieves all file paths from a given directory.
func _get_all_files_recursive(path: String) -> Array[String]:
	var files: Array[String] = []
	var dir = DirAccess.open(path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if dir.current_is_dir():
				if file_name != "." and file_name != "..":
					files.append_array(_get_all_files_recursive(path + "/" + file_name))
			else:
				files.append(path + "/" + file_name)
			file_name = dir.get_next()
	return files


## Searches for files matching a regex pattern securely preventing internal yield blocking loops.
func search_files_by_regex(directory_path: String, regex_pattern: String, cache_ids: PackedStringArray = PackedStringArray()) -> Array[String]:
	var result_paths: Array[String] = []
	var regex = RegEx.new()
	regex.compile(regex_pattern)
	var all_files: Array[String] = []
	
	if not cache_ids.is_empty():
		if not FileCache.cache_setted:
			%Loading.visible = true
			FileCache.rescan_files()
			await StaticSignal.wait_for("_cache_ready")
			
		for id in cache_ids:
			if id in FileCache.cache:
				var cache_files = FileCache.cache[id].keys()
				all_files.append_array(Array(cache_files))
				
	if all_files.is_empty():
		all_files = _get_all_files_recursive(directory_path)
		
	for file_path in all_files:
		var file_name = file_path.get_file()
		var match_result = regex.search(file_name)
		if match_result:
			result_paths.append(file_path)
			
	return result_paths


## Validates whether an indicated directory path is physically and virtually empty.
func _is_directory_empty(path: String) -> bool:
	var dir = DirAccess.open(path)
	var physical_empty = true
	
	if dir:
		dir.list_dir_begin()
		var first = dir.get_next()
		physical_empty = (first == "" or first == ".")
		
	if not physical_empty:
		return false
		
	var clean_base = path.replace("res://", "")
	if clean_base != "" and not clean_base.ends_with("/"):
		clean_base += "/"
		
	for zip_path in ZipMediaLoader._files_index.keys():
		if zip_path.begins_with(clean_base):
			return false
			
	return true


#endregion
#region Navigation & Filtering

## Modifies current directory and resets visual contexts for exploration.
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
	
	%FilterLineEdit.text = ""
	
	current_file_selected = ""
	current_directory_selected = ""
	%CurrentPath.text = current_directory
	_update_label_path_selected()
	_update_history_buttons()
	_refresh_view()


## Restores the directory state and UI when leaving a global view (All/Favorites).
func _restore_directory_state() -> void:
	if not current_file_selected.is_empty() and current_file_selected != "res://":
		current_directory = _clean_path(current_file_selected.get_base_dir())
	elif current_directory.is_empty() or current_directory == "res://":
		if not last_folder_visited.is_empty():
			current_directory = last_folder_visited
		else:
			current_directory = "res://"
			
	current_directory = _clean_path(current_directory)
	
	if %CurrentPath:
		%CurrentPath.text = current_directory
		
	_update_history_buttons()
	_update_label_path_selected()


## Refreshes the current view based on the active file type and filters.
func _refresh_view() -> void:
	var filter = %FilterLineEdit.text
	match current_file_type:
		0: fill_files(current_file_filters_data, false, filter)
		1: fill_files_by_extension(current_directory, current_file_filters_data, false, filter)
		2: fill_mix_files(current_file_filters_data, false, filter)
		3: fill_files_by_regex(current_directory, current_file_filters_data, current_regex_cache_ids, filter)


## Fires external filter refresh based on string changes.
func apply_filter(filter_text: String) -> void:
	_refresh_view()


## Ensures standard path layout trimming invalid tail characters and replacing slashes.
func _clean_path(path: String) -> String:
	if path.is_empty(): return "res://"
	path = path.replace("\\", "/")
	if path.length() > 6 and path.ends_with("/"):
		path = path.left(-1)
	return path


#endregion
#region UI Control & Styling

## Synchronizes available navigation button states reflecting state.
func _update_ui_controls() -> void:
	var is_navigable = (dialog_mode == 1) or (dialog_mode == 0 and not all_button_enabled and not favorite_button_enabled)
	%DirectoryExtraControls1.visible = is_navigable
	%Back.visible = is_navigable
	%Next.visible = is_navigable


## Updates the UI label to reflect the current selection count or path.
func _update_label_path_selected() -> void:
	var text_to_show = ""
	if current_files_selected.size() > 1:
		text_to_show = str(current_files_selected.size()) + " selected files"
	elif not current_file_selected.is_empty():
		text_to_show = current_file_selected
	elif not current_directory_selected.is_empty():
		text_to_show = current_directory_selected
	else:
		text_to_show = current_directory
	%PathSelected.text = " " + text_to_show if not text_to_show.is_empty() else " -"


## Refreshes color and accessibility of dynamic navigation elements mapping constraints.
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


## Ensures appropriate button visualization and locking states for navigation.
func _update_history_buttons() -> void:
	var can_back = not history.back.is_empty() or (_clean_path(current_directory) != "res://")
	%Back.set_disabled(not can_back)
	%Back.modulate = Color.WHITE if can_back else Color(0.5, 0.5, 0.5, 0.5)
	
	var can_next = not history.next.is_empty()
	%Next.set_disabled(not can_next)
	%Next.modulate = Color.WHITE if can_next else Color(0.5, 0.5, 0.5, 0.5)


## Disables items outside container visibility bounds reducing overhead.
func _check_all_nodes_visibility() -> void:
	var children = %FileContainer.get_children()
	for child in children:
		var global_rect = child.get_global_rect()
		var view_rect = scroll_container.get_global_rect()
		if view_rect.intersects(global_rect):
			if child.has_method("enable"): child.enable()
		else:
			if child.has_method("disable"): child.disable()
			
	var scroll = scroll_container.get_v_scroll_bar()
	if scroll.value > (scroll.max_value - scroll.page - 100):
		if (current_page * items_per_page) < filtered_files_pool.size():
			_paginate_next_batch()


## Connects logic triggers for file instantiation setting dynamic data overlays.
func _setup_file_node(node: Control, path: String) -> void:
	var is_zipped: bool = not FileAccess.file_exists(path)
	var zip_prefix: String = "📦\u00A0" if is_zipped else ""
	var display_name: String = path.get_file().get_basename()
	if path in FileCache.cache.characters:
		var res = load(path)
		if res is RPGLPCCharacter:
			var preview = res.character_preview
			var custom_name = path.replace("_data.%s" % path.get_extension(), "").get_file()
			node.set_path(path, preview, zip_prefix + custom_name)
		else:
			node.set_path(path, "", zip_prefix + display_name)
	elif path in FileCache.cache.events:
		var res = load(path)
		if res is RPGLPCCharacter:
			var preview = res.event_preview
			var custom_name = path.replace("_data.%s" % path.get_extension(), "").get_file()
			node.set_path(path, preview, zip_prefix + custom_name)
		else:
			node.set_path(path, "", zip_prefix + display_name)
	elif path in FileCache.cache.sets:
		var res = load(path)
		if res is IngameGearSet:
			var preview = res.set_preview
			var custom_name = path.replace("_data.%s" % path.get_extension(), "").get_file()
			node.set_path(path, preview, zip_prefix + custom_name)
		else:
			node.set_path(path, "", zip_prefix + display_name)
	else:
		node.set_path(path, "", zip_prefix + display_name)
	node.selected.connect(_on_file_selected)
	node.double_click.connect(select_file)
	node.add_to_favorite_requested.connect(_add_to_favorite)
	node.remove_from_favorite_requested.connect(_remove_from_favorite)
	node.show_favorite_button()
	if path in current_files_selected:
		node.select()
	elif path.to_lower() == current_file_selected.to_lower():
		node.select()


## Registers delay frame layout to prevent visibility glitches when setting timers.
func set_all_files_visibility_timer(_p=null) -> void:
	refresh_delay_timer = 0.05


## Resolves loading screens checking available states.
func hide_loading() -> void:
	%Loading.visible = false
	%NoFilesFound.visible = (%FileContainer.get_child_count() == 0 and queue_files.is_empty() and filtered_files_pool.is_empty())


## Disables additional unused UI containers contextually.
func hide_directory_extra_controls2() -> void:
	var node = %DirectoryExtraControls2
	if node:
		node.visible = false


#endregion
#region Selections

## Sets a specific file as visually and logically selected.
func set_file_selected(path: String) -> void:
	current_path = path
	current_file_selected = path
	current_files_selected = [path]
	_update_label_path_selected()
	%CurrentPath.text = path
	if dialog_mode == 1:
		var absolute_path = ProjectSettings.globalize_path(current_path)
		if !DirAccess.dir_exists_absolute(absolute_path):
			DirAccess.make_dir_recursive_absolute(absolute_path)


## Sets a default context directly over a specific directory string layout.
func set_directory_selected(path: String) -> void:
	current_directory_selected = path


## Adjusts visual selection limits and parameters targeting the internal text bar.
func set_directory_filename(_name: String) -> void:
	%Filename.text = _name
	%Filename.set_caret_column(_name.length())
	%Filename.select_all()


## Performs the single target confirmation wrapping history states.
func select_file(path: String) -> void:
	if target_callable: target_callable.call(path)
	if FileCache.options:
		if not "recent_files" in FileCache.options:
			FileCache.options.recent_files = []
		
		var recent: Array = FileCache.options.recent_files

		if path in recent:
			recent.erase(path)
		
		recent.push_front(path)
		
		if recent.size() > MAX_CACHE_LAST_SELECTION_FILES:
			recent.resize(MAX_CACHE_LAST_SELECTION_FILES)
	
	if audio_preview_player: audio_preview_player.stop()
	hide()


## Processes the final selection of multiple files and closes the dialog.
func select_multiple_files(paths: PackedStringArray) -> void:
	if target_callable:
		target_callable.call(paths)
	if FileCache.options:
		if not "recent_files" in FileCache.options:
			FileCache.options.recent_files = []
		var recent: Array = FileCache.options.recent_files
		for path in paths:
			if path in recent:
				recent.erase(path)
			recent.push_front(path)
		if recent.size() > MAX_CACHE_LAST_SELECTION_FILES:
			recent.resize(MAX_CACHE_LAST_SELECTION_FILES)
	if audio_preview_player:
		audio_preview_player.stop()
	hide()


## Ensures the currently selected file is moved to the top of the list preventing lazy loading conflicts.
func _prioritize_selected_file() -> void:
	if current_file_selected.is_empty() or filtered_files_pool.is_empty():
		return

	for i in range(filtered_files_pool.size()):
		if filtered_files_pool[i].path == current_file_selected:
			var file = filtered_files_pool.pop_at(i)
			filtered_files_pool.push_front(file)
			break


## Moves selected file AND recent files to the top of the list.
func _prioritize_recent_files() -> void:
	if filtered_files_pool.is_empty():
		return

	var recent_list: Array = []
	if FileCache.options and "recent_files" in FileCache.options:
		recent_list = FileCache.options.recent_files

	if current_file_selected.is_empty() and recent_list.is_empty():
		return

	var selected_items: Array[FileStruct] = []
	var recent_items: Array[FileStruct] = []
	var normal_items: Array[FileStruct] = []
	
	var recent_dict = {}
	for i in range(recent_list.size()):
		recent_dict[recent_list[i]] = i
		
	for file in filtered_files_pool:
		if file.path == current_file_selected:
			selected_items.append(file)
		elif file.path in recent_dict:
			recent_items.append(file)
		else:
			normal_items.append(file)
			
	if not recent_items.is_empty():
		recent_items.sort_custom(func(a, b): 
			return recent_dict[a.path] < recent_dict[b.path]
		)
	
	filtered_files_pool.clear()
	filtered_files_pool.append_array(selected_items)
	filtered_files_pool.append_array(recent_items)
	filtered_files_pool.append_array(normal_items)


## Evaluates valid streams for automatic audio playback targeting standard audio structures.
func _try_play_audio_preview(path: String) -> void:
	if not audio_preview_player: return
	
	audio_preview_player.stop()
	
	var ext = path.get_extension().to_lower()
	if not ext in ["wav", "ogg", "mp3"]:
		return

	if ResourceLoader.exists(path):
		var stream = load(path)
		if stream is AudioStream:
			audio_preview_player.stream = stream
			audio_preview_player.play()


#endregion
#region Signals & External Connectors

## Evaluates slider input data cascading grid scale overrides.
func _on_icon_size_changed(value: float) -> void:
	current_icon_size = int(value)
	if FileCache.options != null:
		FileCache.options.file_dialog_icon_size = current_icon_size
	for child in %FileContainer.get_children():
		if child.has_method("set_icon_size"):
			child.set_icon_size(current_icon_size)
	_check_all_nodes_visibility()


## Relays the interaction toggle state updating all-files filters.
func _on_all_button_toggled(toggled_on: bool) -> void:
	all_button_enabled = toggled_on
	
	if toggled_on:
		favorite_button_enabled = false
		%FavoriteButton.set_pressed_no_signal(false)
		_was_all_mode_before_favorite = false 
	
	if not toggled_on:
		_restore_directory_state()
	
	if FileCache.options:
		FileCache.options.file_dialog_all_files_toggled = toggled_on
		
	_refresh_view()


## Relays the interaction toggle state updating favorites filters.
func _on_favorite_button_toggled(toggled_on: bool) -> void:
	favorite_button_enabled = toggled_on
	
	if toggled_on:
		_was_all_mode_before_favorite = all_button_enabled
		all_button_enabled = false
		%AllButton.set_pressed_no_signal(false)
	else:
		if _was_all_mode_before_favorite:
			all_button_enabled = true
			%AllButton.set_pressed_no_signal(true)
		else:
			_restore_directory_state()
		
		_was_all_mode_before_favorite = false
		
	if FileCache.options:
		FileCache.options.file_dialog_favorite_toggled = toggled_on
		
	_refresh_view()


## Re-generates view states when parent visibility contexts modify.
func _on_visibility_changed() -> void:
	if visible:
		_refresh_view()


## Handles the logic when the OK button is pressed considering multiple selection.
func _on_ok_button_pressed() -> void:
	if dialog_mode == 1:
		if not current_directory_selected.is_empty():
			select_file(current_directory_selected)
		else:
			select_file(current_directory)
	else:
		if allow_multiple_selection and current_files_selected.size() > 0:
			select_multiple_files(current_files_selected)
		elif not current_file_selected.is_empty():
			select_file(current_file_selected)
		elif not current_directory_selected.is_empty():
			navigate_to_directory(current_directory_selected)


## Aborts active procedures disabling audio.
func _on_cancel_button_pressed() -> void:
	if audio_preview_player: audio_preview_player.stop()
	hide()


## Handles file selection and multi-selection logic based on keyboard modifiers.
func _on_file_selected(node: Control, shift_pressed: bool = false, ctrl_pressed: bool = false) -> void:
	if allow_multiple_selection and dialog_mode == 0:
		if shift_pressed and last_selected_node != null:
			var children = %FileContainer.get_children()
			var start_idx = children.find(last_selected_node)
			var end_idx = children.find(node)
			if start_idx != -1 and end_idx != -1:
				current_files_selected.clear()
				for child in children:
					child.deselect()
				var step = 1 if start_idx <= end_idx else -1
				for i in range(start_idx, end_idx + step, step):
					var child = children[i]
					child.select()
					current_files_selected.append(child.path)
		elif ctrl_pressed:
			if node.path in current_files_selected:
				node.deselect()
				var idx = current_files_selected.find(node.path)
				if idx != -1:
					current_files_selected.remove_at(idx)
				if last_selected_node == node:
					last_selected_node = null
			else:
				node.select()
				current_files_selected.append(node.path)
				last_selected_node = node
		else:
			current_files_selected.clear()
			for child in %FileContainer.get_children():
				child.deselect()
			node.select()
			current_files_selected.append(node.path)
			last_selected_node = node
	else:
		for child in %FileContainer.get_children():
			child.deselect()
		node.select()
		current_files_selected = [node.path]
		last_selected_node = node
	if current_files_selected.size() > 0:
		current_file_selected = current_files_selected[-1]
		current_path = current_file_selected
	else:
		current_file_selected = ""
		current_path = current_directory
	_update_label_path_selected()
	if auto_play_sounds and not current_file_selected.is_empty():
		_try_play_audio_preview(current_file_selected)


## Handles directory selection updating its style.
func _on_directory_selected(node: Control, _shift_pressed: bool = false, _ctrl_pressed: bool = false) -> void:
	for child in %FileContainer.get_children():
		if child != node: child.deselect()
	current_directory_selected = node.path
	current_path = node.path
	_update_label_path_selected()


## Connects explicit external signals avoiding line edit text delay bounds.
func _on_custom_line_edit_text_changed(new_text: String) -> void:
	filter_delay_timer = 0.25


## Pops the preceding historical dictionary value enabling layout backtracking.
func _on_back_button_pressed() -> void:
	var prev: String
	if not history.back.is_empty():
		prev = history.back.pop_back()
	else:
		prev = current_directory.get_base_dir()
	history.next.append(current_directory)
	navigate_to_directory(prev, false)
	_update_history_buttons()


## Steps forwards retrieving internal sequential records.
func _on_next_button_pressed() -> void:
	if not history.next.is_empty():
		var next_path = history.next.pop_back()
		history.back.append(current_directory)
		navigate_to_directory(next_path, false)
		_update_history_buttons()


## Nulls dummy callable connections preventing exceptions.
func _select_other_file(_i, _d): pass


## Inserts designated internal dictionary keys storing string routes to memory lists.
func _add_to_favorite(path: String) -> void:
	var options_cache = FileCache.options
	if options_cache:
		if not "favorite_files" in options_cache:
			options_cache.favorite_files = {}
		options_cache.favorite_files[path] = current_file_filters_data


## Erases paths safely detaching targets from custom memory collections.
func _remove_from_favorite(path: String) -> void:
	var options_cache = FileCache.options
	if options_cache and "favorite_files" in options_cache:
		options_cache.favorite_files.erase(path)


## Triggers standard re-scans updating general layout arrays completely.
func _on_rebuild_cache_pressed() -> void:
	FileCache.rebuild(true)
	await FileCache.cache_setted
	_refresh_view()


#endregion
