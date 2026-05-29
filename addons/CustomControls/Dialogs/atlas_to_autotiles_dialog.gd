@tool
extends Window

#region VARIABLES

## Maximum width for the generated atlas images
@export var max_atlas_width: int = 2048

## Maximum height for the generated atlas images
@export var max_atlas_height: int = 2048

## Container to display the selected animation frames
@export var anim_main_container: Control

## Container to display the selected animation frames
@export var anim_frames_container: Container

## Button to merge the selected frames into an animated autotile
@export var merge_anim_button: Button

## Button to clear the selected animation frames
@export var clear_anim_button: Button

## Button to close the animation panel and disable the animation mode
@export var close_anim_panel_button: BaseButton

## SpinBox widget that defines the playback speed in frames per second for animated tiles
@export var anim_speed_spinbox: SpinBox

## Reference to the newly added OptionButton for autotile actions
@export var autotile_action_options: OptionButton

## Container to display the selected alternative frames
@export var alt_main_container: Control

## Container holding the texture rects for alternative frames
@export var alt_frames_container: Container

## Button to confirm and append alternative frames to the selected tile
@export var merge_alt_button: Button

## Button to close the alternative panel and disable the alternative mode
@export var close_alt_panel_button: BaseButton

## Button to clear the selected alternative frames
@export var clear_alt_button: Button

## SpinBox to adjust the terrain probability of the selected alternative frames
@export var alt_prob_spinbox: SpinBox

## SpinBox to adjust the terrain probability of the resulting animated alternative tile
@export var anim_prob_spinbox: SpinBox

## Container for the animation probability spinbox
@export var anim_prob_main_container: Container

## OptionButton to select the target tile size for the generated TileSet
@export var target_tile_size_options: OptionButton

var atlas: Array = []
var autotiles: Array = []

@onready var canvas: AtlasSelectorCanvas = %Canvas
@onready var atlas_list: VBoxContainer = %AtlasList
@onready var auto_tiles_list: ItemList = %AutoTilesList
@onready var conversor: TilesetConversor = %Conversor

var refresh_time: float = 0.0
var save_dialog: EditorFileDialog
var image_dir_dialog: EditorFileDialog
var load_dialog: EditorFileDialog

var selected_image_dir: String = ""
var selected_tileset_path: String = ""
var current_editing_tileset_path: String = ""

var anim_frames_data: Array[Dictionary] = []
var selected_anim_frames: Array[TextureRect] = []
var draggin_animation_panel: bool = false
var is_animation_mode: bool = false

var is_alternative_mode: bool = false
var is_alternative_animated_mode: bool = false
var is_alternative_center_only: bool = false
var alt_frames_data: Array[Dictionary] = []
var selected_alt_frames: Array[TextureRect] = []

var clear_alt_popup: PopupMenu

var _pending_saves: Array[Dictionary] = []

var preview_is_animated: bool = false
var preview_frames: int = 1
var preview_current_frame: int = 0
var preview_timer: float = 0.0
var preview_autotile_mode: int = 0
var preview_base_image: Image
var preview_lpc_composite: Image

var TARGET_SIZES: Array[Vector2i] = [
	Vector2i.ZERO,
	Vector2i(16, 16),
	Vector2i(24, 24),
	Vector2i(32, 32),
	Vector2i(48, 48),
	Vector2i(64, 64),
	Vector2i(96, 96),
	Vector2i(128, 128),
	Vector2i(256, 256)
]

var atlas_painted_data: Dictionary = {}

#endregion



## Initializes the window, connects signals, loads cached preferences, and prepares the UI
func _ready() -> void:
	if not RPGDialogFunctions.there_are_any_dialog_open():
		set_process(false)
		return
		
	close_requested.connect(_exit)
	%MidColum.propagate_call("set_disabled", [true])
	%AutotilePreview.texture = null
	%RightColumn.propagate_call("set_disabled", [true])
	%LoadTileset.set_disabled(false)
	%LabelTerrainTileSelected.text = "-"
	%LabelTerrainTileSelected.set_disabled(true)
	%AnimationSpeed.get_line_edit().set("theme_override_colors/font_color", Color("bfe5dd"))
	%CurrentAnimationSpeedContainer.visible = false
	%CurrentAnimationSpeed.set("theme_override_colors/font_color", Color("bfe5dd"))
	
	%CurrentAnimationSpeed.value_changed.connect(_on_current_animation_speed_value_changed)
	
	var current_col_node: OptionButton = get_node_or_null("%CurrentCollision")
	if is_instance_valid(current_col_node):
		current_col_node.item_selected.connect(_on_current_collision_item_selected)
		
	CustomTooltipManager.plugin_replace_all_tooltips_with_custom(self)
	
	call_deferred("_load_cached_preferences")
	
	canvas.single_tiles_selected.connect(_on_canvas_single_tiles_selected)
	canvas.autotile_anim_frame_selected.connect(_on_canvas_anim_frame_selected)
	canvas.autotile_selected.connect(_on_canvas_autotile_selected)
	canvas.paint_tile_requested.connect(_on_canvas_paint_tile_requested)
	
	if is_instance_valid(auto_tiles_list):
		if not auto_tiles_list.item_moved.is_connected(_on_auto_tiles_list_item_moved):
			auto_tiles_list.item_moved.connect(_on_auto_tiles_list_item_moved)
			
	if is_instance_valid(merge_anim_button):
		merge_anim_button.pressed.connect(_on_merge_anim_frames_pressed)
		
	if is_instance_valid(clear_anim_button):
		clear_anim_button.pressed.connect(_clear_anim_frames)
		
	if is_instance_valid(close_anim_panel_button):
		close_anim_panel_button.pressed.connect(_on_close_anim_panel_pressed)
		
	if is_instance_valid(autotile_action_options):
		autotile_action_options.item_selected.connect(_on_autotile_action_selected)
		
	if is_instance_valid(merge_alt_button):
		merge_alt_button.pressed.connect(_on_merge_alt_frames_pressed)
		
	if is_instance_valid(clear_alt_button):
		clear_alt_button.pressed.connect(_clear_alt_frames)
		
	if is_instance_valid(close_alt_panel_button):
		close_alt_panel_button.pressed.connect(_on_close_alt_panel_pressed)
		
	if is_instance_valid(alt_prob_spinbox):
		alt_prob_spinbox.min_value = 0.0
		alt_prob_spinbox.max_value = 1.0
		alt_prob_spinbox.step = 0.01
		alt_prob_spinbox.value_changed.connect(_on_alt_prob_value_changed)
		
	if is_instance_valid(anim_prob_spinbox):
		anim_prob_spinbox.min_value = 0.0
		anim_prob_spinbox.max_value = 1.0
		anim_prob_spinbox.step = 0.01
		anim_prob_spinbox.value = 0.1
		
	if is_instance_valid(anim_speed_spinbox):
		anim_speed_spinbox.value_changed.connect(_on_anim_speed_value_changed)
		
	var add_col_node: OptionButton = get_node_or_null("%AddCollision")
	if is_instance_valid(add_col_node):
		add_col_node.item_selected.connect(_on_add_collision_item_selected)
		
	var terrain_node: LineEdit = get_node_or_null("%TerrainName")
	if is_instance_valid(terrain_node):
		terrain_node.text_changed.connect(_on_terrain_name_text_changed)
		
	var btn_paint_col: BaseButton = get_node_or_null("%PaintCollisionButton")
	if is_instance_valid(btn_paint_col):
		btn_paint_col.toggled.connect(_on_paint_collision_toggled)
		
	var btn_paint_ter: BaseButton = get_node_or_null("%PaintTerrainButton")
	if is_instance_valid(btn_paint_ter):
		btn_paint_ter.toggled.connect(_on_paint_terrain_toggled)
		
	clear_alt_popup = PopupMenu.new()
	clear_alt_popup.id_pressed.connect(_on_clear_alt_popup_id_pressed)
	add_child(clear_alt_popup)
	
	_apply_alt_panel_state(false)
	_update_anim_buttons_state()
	_update_alt_buttons_state()
	
	image_dir_dialog = EditorFileDialog.new()
	image_dir_dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_DIR
	image_dir_dialog.title = "Select folder for Atlas Textures"
	image_dir_dialog.current_dir = _get_cache_value("last_image_folder", "res://Assets/Images/Tilesets")
	image_dir_dialog.dir_selected.connect(_on_image_dir_selected)
	add_child(image_dir_dialog)
	
	save_dialog = EditorFileDialog.new()
	save_dialog.file_mode = EditorFileDialog.FILE_MODE_SAVE_FILE
	save_dialog.title = "Save TileSet Resource"
	save_dialog.add_filter("*.tres", "TileSet Resource")
	save_dialog.current_dir = _get_cache_value("last_tileset_folder", "res://Assets/Tilesets")
	save_dialog.file_selected.connect(_on_save_file_selected)
	add_child(save_dialog)
	
	load_dialog = EditorFileDialog.new()
	load_dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILE
	load_dialog.title = "Load Godot RPG Creator TileSet"
	load_dialog.add_filter("*.tres", "TileSet Resource")
	load_dialog.current_dir = _get_cache_value("last_tileset_folder", "res://Assets/Tilesets")
	load_dialog.file_selected.connect(_load_tileset_from_file)
	add_child(load_dialog)
	
	_populate_target_tile_sizes()
	set_process(true)



## Loads previously saved user preferences from the FileCache global dictionary and forces canvas updates
func _load_cached_preferences() -> void:
	if not FileCache.options.has("tile_conversor"):
		FileCache.options["tile_conversor"] = {}
		
	var cached_size: Vector2i = _get_cache_value("last_tile_size", Vector2i(32, 32))
	%Width.set_value_no_signal(cached_size.x)
	%Height.set_value_no_signal(cached_size.y)
	
	var cached_mode: int = _get_cache_value("last_mode_used", 0)
	%AutototileType.select(cached_mode)
	
	if is_instance_valid(anim_speed_spinbox):
		anim_speed_spinbox.set_value_no_signal(_get_cache_value("last_anim_speed", 5.0))
		
	var add_col_node: OptionButton = get_node_or_null("%AddCollision")
	if is_instance_valid(add_col_node):
		add_col_node.select(_get_cache_value("last_collision_mode", 0))
		
	var terrain_node: LineEdit = get_node_or_null("%TerrainName")
	if is_instance_valid(terrain_node):
		terrain_node.text = _get_cache_value("last_terrain_name", "")
		
	canvas.update_grid_and_mode(cached_size, cached_mode as AtlasSelectorCanvas.AutotileType)
	
	is_animation_mode = _get_cache_value("last_anim_mode_state", false)
	_apply_animation_mode_state()
	
	call_deferred("_restore_panel_position")
	
	var saved_atlases: Array = _get_cache_value("last_files_used", [])
	
	for path in saved_atlases:
		if FileAccess.file_exists(path):
			atlas.append(path)
			
	if atlas.size() > 0:
		_fill_atlas_list(0)



## Caches the animation speed when changed by the user
func _on_anim_speed_value_changed(value: float) -> void:
	_update_cache("last_anim_speed", value)



## Caches the collision mode when selected by the user
func _on_add_collision_item_selected(index: int) -> void:
	_update_cache("last_collision_mode", index)



## Caches the terrain name when typed by the user
func _on_terrain_name_text_changed(new_text: String) -> void:
	_update_cache("last_terrain_name", new_text)



## Safely retrieves a value from the FileCache dictionary, returning a default if not found
func _get_cache_value(key: String, default_value: Variant) -> Variant:
	var cache: Dictionary = FileCache.options.get("tile_conversor", {})
	
	return cache.get(key, default_value)



## Updates a specific key in the FileCache dictionary to persist user preferences
func _update_cache(key: String, value: Variant) -> void:
	if not FileCache.options.has("tile_conversor"):
		FileCache.options["tile_conversor"] = {}
		
	FileCache.options["tile_conversor"][key] = value



## Fills the option button with predefined target tile sizes and connects the caching signal
func _populate_target_tile_sizes() -> void:
	if not is_instance_valid(target_tile_size_options):
		return
		
	target_tile_size_options.clear()
	
	for size in TARGET_SIZES:
		if size == Vector2i.ZERO:
			target_tile_size_options.add_item("Source Size")
		else:
			target_tile_size_options.add_item(str(size.x) + "x" + str(size.y))
			
	target_tile_size_options.item_selected.connect(_on_target_tile_size_item_selected)
	
	var cached_idx: int = _get_cache_value("last_target_size_idx", 0)
	
	if cached_idx >= 0 and cached_idx < target_tile_size_options.item_count:
		target_tile_size_options.select(cached_idx)



## Caches the target size option selected by the user
func _on_target_tile_size_item_selected(index: int) -> void:
	_update_cache("last_target_size_idx", index)



## Retrieves the user selected target tile size falling back to zero vector if invalid
func _get_current_target_tile_size() -> Vector2i:
	if not is_instance_valid(target_tile_size_options):
		return Vector2i.ZERO
		
	var idx: int = target_tile_size_options.selected
	
	if idx >= 0 and idx < TARGET_SIZES.size():
		return TARGET_SIZES[idx]
		
	return Vector2i.ZERO



## Resolves the final effective tile size falling back to the source dimensions if needed
func _get_active_tile_size() -> Vector2i:
	var target_size: Vector2i = _get_current_target_tile_size()
	
	if target_size == Vector2i.ZERO:
		return Vector2i(%Width.value, %Height.value)
		
	return target_size



## Locks the target tile size selector if there are stored tiles preventing visual inconsistency
func _update_target_size_lock() -> void:
	if is_instance_valid(target_tile_size_options):
		target_tile_size_options.disabled = autotiles.size() > 0



## Reorders the internal autotiles array when a drag and drop happens in the list
func _on_auto_tiles_list_item_moved(old_index: int, new_index: int) -> void:
	var item: Dictionary = autotiles.pop_at(old_index)
	autotiles.insert(new_index, item)
	auto_tiles_list.select(new_index)
	auto_tiles_list.item_selected.emit(new_index)



## Updates the probability value for all currently selected alternative frames in the UI panel
func _on_alt_prob_value_changed(value: float) -> void:
	if selected_alt_frames.size() == 1:
		var idx: int = selected_alt_frames[0].get_index()
		if idx >= 0 and idx < alt_frames_data.size():
			alt_frames_data[idx]["probability"] = value



## Re-evaluates the array size to correctly disable or enable the merge and clear action buttons for alternatives
func _update_alt_buttons_state() -> void:
	var has_frames: bool = alt_frames_data.size() > 0
	var has_selection: bool = selected_alt_frames.size() == 1
	
	if is_instance_valid(merge_alt_button):
		merge_alt_button.disabled = not has_frames
		
	if is_instance_valid(clear_alt_button):
		clear_alt_button.disabled = not has_frames
		
	if is_instance_valid(alt_prob_spinbox):
		alt_prob_spinbox.editable = has_selection
		alt_prob_spinbox.set_block_signals(true)
		
		if has_selection:
			var idx: int = selected_alt_frames[0].get_index()
			alt_prob_spinbox.value = alt_frames_data[idx].get("probability", 0.1)
		else:
			alt_prob_spinbox.value = 0.1
			
		alt_prob_spinbox.set_block_signals(false)



## Catches key inputs dynamically to act as toggles for painting modes, animation mode, and handles frame deletion
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var focus_owner: Control = get_viewport().gui_get_focus_owner()
		var is_typing: bool = is_instance_valid(focus_owner) and (focus_owner is LineEdit or focus_owner is TextEdit)
		
		if event.keycode == KEY_ESCAPE:
			if canvas.is_painting_mode:
				var btn_col: BaseButton = get_node_or_null("%PaintCollisionButton")
				var btn_ter: BaseButton = get_node_or_null("%PaintTerrainButton")
				if is_instance_valid(btn_col): 
					btn_col.button_pressed = false
				if is_instance_valid(btn_ter): 
					btn_ter.button_pressed = false
		elif event.keycode == KEY_F1:
			if not is_typing and not is_alternative_mode:
				_toggle_animation_mode()
		elif event.keycode == KEY_DELETE or event.keycode == KEY_BACKSPACE:
			if is_typing:
				return
			if is_alternative_mode and not is_alternative_animated_mode:
				_delete_selected_alt_frames()
			elif is_animation_mode or is_alternative_animated_mode:
				_delete_selected_anim_frames()
		elif event.keycode == KEY_C:
			if not is_typing:
				var btn_col: BaseButton = get_node_or_null("%PaintCollisionButton")
				if is_instance_valid(btn_col): 
					btn_col.button_pressed = not btn_col.button_pressed
		elif event.keycode == KEY_T:
			if not is_typing:
				var btn_ter: BaseButton = get_node_or_null("%PaintTerrainButton")
				if is_instance_valid(btn_ter): 
					btn_ter.button_pressed = not btn_ter.button_pressed
		elif event.keycode == KEY_B:
			if not is_typing:
				var btn_col: BaseButton = get_node_or_null("%PaintCollisionButton")
				var btn_ter: BaseButton = get_node_or_null("%PaintTerrainButton")
				if is_instance_valid(btn_col) and is_instance_valid(btn_ter):
					var target_state: bool = not (btn_col.button_pressed and btn_ter.button_pressed)
					btn_col.button_pressed = target_state
					btn_ter.button_pressed = target_state



## Toggles the selection visually and logically of a clicked alternative frame thumbnail
func _on_alt_frame_gui_input(event: InputEvent, tex_rect: TextureRect) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var previously_selected: Array = selected_alt_frames.duplicate()
		
		if selected_alt_frames.has(tex_rect):
			selected_alt_frames.clear()
		else:
			selected_alt_frames.clear()
			selected_alt_frames.append(tex_rect)
			
		tex_rect.queue_redraw()
		
		for prev_rect in previously_selected:
			if is_instance_valid(prev_rect) and prev_rect != tex_rect:
				prev_rect.queue_redraw()
				
		_update_alt_buttons_state()



## Draws a custom high-contrast cursor over the texture if it is currently selected
func _on_tex_rect_draw(tex_rect: TextureRect) -> void:
	if selected_anim_frames.has(tex_rect) or selected_alt_frames.has(tex_rect):
		var w: float = tex_rect.size.x
		var h: float = tex_rect.size.y
		
		tex_rect.draw_rect(Rect2(0, 0, w, h), Color(1.0, 1.0, 0.4, 0.3), true)
		tex_rect.draw_rect(Rect2(1, 1, w - 2, h - 2), Color.BLACK, false, 2.0)
		tex_rect.draw_rect(Rect2(3, 3, w - 6, h - 6), Color.WHITE, false, 2.0)



## Handles the delayed refresh trigger and constantly enforces panel bounds if visible
func _process(delta: float) -> void:
	if refresh_time > 0.0:
		refresh_time -= delta
		
		if refresh_time <= 0.0:
			refresh_time = 0.0
			var tile_size = Vector2i(%Width.value, %Height.value)
			var autotile_mode = %AutototileType.get_selected_id() as AtlasSelectorCanvas.AutotileType
			canvas.update_grid_and_mode(tile_size, autotile_mode)
			
	if is_animation_mode:
		_clamp_panel_position()
		
	if preview_is_animated and is_instance_valid(%AutotilePreview) and %AutotilePreview.texture != null:
		var fps: float = 5.0
		
		if is_instance_valid(%CurrentAnimationSpeed) and %CurrentAnimationSpeedContainer.visible:
			fps = %CurrentAnimationSpeed.value
		elif is_instance_valid(anim_speed_spinbox):
			fps = anim_speed_spinbox.value
			
		preview_timer += delta
		var frame_duration: float = 1.0 / fps
		
		if preview_timer >= frame_duration:
			preview_timer -= frame_duration
			preview_current_frame = (preview_current_frame + 1) % preview_frames
			
			if %AutotilePreview.texture is AtlasTexture:
				var atlas_tex: AtlasTexture = %AutotilePreview.texture
				var frame_w: float = atlas_tex.atlas.get_width() / float(preview_frames)
				atlas_tex.region = Rect2(preview_current_frame * frame_w, 0, frame_w, atlas_tex.atlas.get_height())
			elif preview_autotile_mode == canvas.AutotileType.LPC_FULL_ANIMATED:
				if %AutotilePreview.texture is ImageTexture and preview_base_image != null and preview_lpc_composite != null:
					var tile_w: int = preview_base_image.get_width() / 8
					var frame_rect: Rect2i = Rect2i(preview_current_frame * tile_w, tile_w * 6, tile_w, tile_w)
					
					preview_lpc_composite.fill_rect(Rect2i(0, tile_w * 6, tile_w * 8, int(tile_w * 2.5)), Color.TRANSPARENT)
					preview_lpc_composite.blit_rect(preview_base_image, frame_rect, Vector2i(tile_w * 3, tile_w * 6 + int(tile_w * 0.5)))
					
					%AutotilePreview.texture.update(preview_lpc_composite)



## Toggles the internal animation mode flag, caches it, and forces UI updates
func _toggle_animation_mode() -> void:
	is_animation_mode = !is_animation_mode
	_update_cache("last_anim_mode_state", is_animation_mode)
	_apply_animation_mode_state()
	%AnimationSpeedContainer.visible = is_animation_mode



## Explicitly disables animation mode when the user clicks the UI close button and caches the state
func _on_close_anim_panel_pressed() -> void:
	_clear_anim_frames()
	is_animation_mode = false
	
	if is_alternative_mode:
		is_alternative_mode = false
		is_alternative_animated_mode = false
		is_alternative_center_only = false
		var cached_mode: int = _get_cache_value("last_mode_used", 0)
		canvas.is_anim_size_locked = false
		canvas.update_grid_and_mode(Vector2i(%Width.value, %Height.value), cached_mode as AtlasSelectorCanvas.AutotileType)
		
	_update_cache("last_anim_mode_state", is_animation_mode)
	_apply_animation_mode_state()



## Synchronizes the visibility and interactability of the UI panels based on the current mode
func _apply_animation_mode_state() -> void:
	canvas.is_animation_mode = is_animation_mode
	canvas._update_help_text()
	canvas.cursor_canvas.queue_redraw()
	
	if is_instance_valid(anim_main_container):
		anim_main_container.visible = is_animation_mode
		%AnimationSpeedContainer.visible = is_animation_mode
		
	%FloatingAnimationPanel.propagate_call("set_disabled", [not is_animation_mode])
	
	if is_instance_valid(anim_prob_spinbox):
		anim_prob_spinbox.visible = is_alternative_mode and is_alternative_animated_mode
		
		if is_instance_valid(anim_prob_main_container):
			anim_prob_main_container.visible = anim_prob_spinbox.visible 
			
	if is_animation_mode:
		%RightColumn.propagate_call("set_disabled", [true])
		%LoadTileset.set_disabled(false)
		call_deferred("_restore_panel_position")
		_update_anim_buttons_state()
	else:
		%RightColumn.propagate_call("set_disabled", [autotiles.size() == 0])
		%LoadTileset.set_disabled(false)



## Restores the panel position from cache safely or centers it at the bottom by default
func _restore_panel_position() -> void:
	if not is_inside_tree() or not has_node("%FloatingMainPanelContainer"):
		return
		
	var panel: Control = %FloatingMainPanelContainer
	var cached_panel_pos: Vector2 = _get_cache_value("last_anim_panel_pos", Vector2(-1, -1))
	
	if cached_panel_pos != Vector2(-1, -1):
		panel.global_position = cached_panel_pos
	else:
		var limit_size: Vector2 = Vector2(size)
		panel.global_position = Vector2((limit_size.x - panel.size.x) / 2.0, limit_size.y - panel.size.y - 50.0)



## Enforces window bounds on the floating panel keeping a margin, and updates cache if modified
func _clamp_panel_position() -> void:
	if not is_inside_tree() or not has_node("%FloatingMainPanelContainer"):
		return
		
	var panel: Control = %FloatingMainPanelContainer
	
	if not is_instance_valid(panel) or not panel.is_inside_tree():
		return
		
	var panel_size: Vector2 = panel.size
	
	if panel_size.x <= 0 or panel_size.y <= 0:
		return
			
	var margin: float = 10.0
	var limit_size: Vector2 = Vector2(size)
	
	var min_pos: Vector2 = Vector2(margin, margin)
	var max_pos: Vector2 = Vector2(limit_size.x - panel_size.x - margin, limit_size.y - panel_size.y - margin)
	
	if max_pos.x < min_pos.x:
		max_pos.x = min_pos.x
	if max_pos.y < min_pos.y:
		max_pos.y = min_pos.y
		
	var current_pos: Vector2 = panel.position
	var clamped_pos: Vector2 = Vector2(clampf(current_pos.x, min_pos.x, max_pos.x), clampf(current_pos.y, min_pos.y, max_pos.y))
	
	if current_pos != clamped_pos:
		panel.position = clamped_pos
		if not draggin_animation_panel:
			_update_cache("last_anim_panel_pos", clamped_pos)



## Re-evaluates the array size to correctly disable or enable the merge and clear action buttons
func _update_anim_buttons_state() -> void:
	var has_frames: bool = anim_frames_data.size() > 0
	
	if is_instance_valid(merge_anim_button):
		merge_anim_button.disabled = not has_frames
		
	if is_instance_valid(clear_anim_button):
		clear_anim_button.disabled = not has_frames
		
	if is_instance_valid(canvas):
		canvas.is_anim_size_locked = has_frames
		if not has_frames and canvas.current_autotile_type == canvas.AutotileType.SINGLE:
			canvas.locked_anim_size = Vector2i(1, 1)
		canvas.cursor_canvas.queue_redraw()



## Toggles the selection visually and logically of a clicked animation frame thumbnail
func _on_anim_frame_gui_input(event: InputEvent, tex_rect: TextureRect) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var previously_selected: Array = selected_anim_frames.duplicate()
		
		if selected_anim_frames.has(tex_rect):
			selected_anim_frames.clear()
		else:
			selected_anim_frames.clear()
			selected_anim_frames.append(tex_rect)
			
		tex_rect.queue_redraw()
		
		for prev_rect in previously_selected:
			if is_instance_valid(prev_rect) and prev_rect != tex_rect:
				prev_rect.queue_redraw()
				
		_update_anim_buttons_state()



## Removes safely from memory and UI all user-selected animation frames
func _delete_selected_anim_frames() -> void:
	if selected_anim_frames.is_empty():
		return
		
	var indices: Array[int] = []
	for tex_rect in selected_anim_frames:
		if is_instance_valid(tex_rect):
			indices.append(tex_rect.get_index())
			
	indices.sort()
	indices.reverse()
	
	for idx in indices:
		anim_frames_data.remove_at(idx)
		var child: Node = anim_frames_container.get_child(idx)
		if is_instance_valid(child):
			child.queue_free()
			
	selected_anim_frames.clear()
	_update_anim_buttons_state()



## Removes safely from memory and UI all user-selected alternative frames
func _delete_selected_alt_frames() -> void:
	if selected_alt_frames.is_empty():
		return
		
	var indices: Array[int] = []
	for tex_rect in selected_alt_frames:
		if is_instance_valid(tex_rect):
			indices.append(tex_rect.get_index())
			
	indices.sort()
	indices.reverse()
	
	for idx in indices:
		alt_frames_data.remove_at(idx)
		var child: Node = alt_frames_container.get_child(idx)
		if is_instance_valid(child):
			child.queue_free()
			
	selected_alt_frames.clear()
	_update_alt_buttons_state()



## Flushes all stored animation data and visually removes the thumbnails
func _clear_anim_frames() -> void:
	anim_frames_data.clear()
	selected_anim_frames.clear()
	
	if is_instance_valid(anim_frames_container):
		for child in anim_frames_container.get_children():
			child.queue_free()
			
	if is_instance_valid(anim_prob_spinbox):
		anim_prob_spinbox.value = 0.1
			
	_update_anim_buttons_state()



## Flushes all stored alternative frame data and visually removes the thumbnails
func _clear_alt_frames() -> void:
	alt_frames_data.clear()
	selected_alt_frames.clear()
	
	if is_instance_valid(alt_frames_container):
		for child in alt_frames_container.get_children():
			child.queue_free()
			
	_update_alt_buttons_state()



## Opens the dialog to load an existing RPG Creator tileset
func _on_load_tileset_pressed() -> void:
	load_dialog.popup_centered_ratio(0.5)



## Evaluates if an atlas exists at the requested index or opens the dialog to load a new one
func _on_atlas_list_item_activated(index: int) -> void:
	if index >= 0 and atlas.size() > index:
		return
	else:
		_select_new_atlas()



## Opens the RPG Creator file dialog centered on the mouse to let the user pick an image
func _select_new_atlas() -> void:
	var path: String = "res://addons/CustomControls/Dialogs/select_file_dialog.tscn"
	var dialog: Node = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	
	await get_tree().process_frame
	
	dialog.destroy_on_hide = true
	dialog.target_callable = _add_new_atlas
	dialog.set_dialog_mode(0)
	dialog.fill_files("images")



## Callback from the dialog appending the selected image to the memory array and updating cache
func _add_new_atlas(path: String) -> void:
	atlas.append(path)
	_update_cache("last_files_used", atlas)
	_fill_atlas_list(atlas.size() - 1)



## Rebuilds the visual list of available atlases and selects the target index
func _fill_atlas_list(_selected_id: int = -1) -> void:
	var list: VBoxContainer = atlas_list
	list.clear()
	
	%MidColum.propagate_call("set_disabled", [true])
	%AutotilePreview.texture = null
	%RightColumn.propagate_call("set_disabled", [true])
	%LoadTileset.set_disabled(false)
	%LabelTerrainTileSelected.text = "-"
	%LabelTerrainTileSelected.set_disabled(true)
	
	for path in atlas:
		list.add_column([path.get_file().replace(path.get_extension(), "")])
		
	if atlas.size() > 0:
		await list.columns_setted
		
		if _selected_id >= 0 and atlas.size() > _selected_id:
			list.select(_selected_id)
			list.item_selected.emit(_selected_id)
		elif _selected_id >= 0:
			_selected_id = atlas.size()
			list.select(_selected_id)
			list.item_selected.emit(_selected_id)
		elif atlas.size() > 0:
			list.select(0)
			list.item_selected.emit(0)
	else:
		canvas.clear()
		list.select(0)



## Rebuilds the visual list of extracted autotiles and selects the target index
func _fill_autotiles_list(_selected_id: int = -1) -> void:
	var list: ItemList = auto_tiles_list
	list.clear()
	
	for tile in autotiles:
		list.add_item(tile.name)
		
	if autotiles.size() > 0:
		if _selected_id >= 0 and autotiles.size() > _selected_id:
			list.select(_selected_id)
			list.item_selected.emit(_selected_id)
		elif _selected_id >= 0:
			_selected_id = autotiles.size() - 1
			list.select(_selected_id)
			list.item_selected.emit(_selected_id)
		elif autotiles.size() > 0:
			list.select(0)
			list.item_selected.emit(0)
			
		if not is_animation_mode:
			%RightColumn.propagate_call("set_disabled", [false])
	else:
		%AutotilePreview.texture = null
		%RightColumn.propagate_call("set_disabled", [true])
		%LoadTileset.set_disabled(false)
		%LabelTerrainTileSelected.text = "-"
		%LabelTerrainTileSelected.set_disabled(true)



## Loads the image file into memory and pushes it to the canvas rendering logic
func _on_atlas_list_item_selected(index: int) -> void:
	if atlas.size() > index:
		var path: String = atlas[index]
		
		if not FileAccess.file_exists(path):
			return
			
		var tex: Texture2D = load(path)
		
		canvas.set_texture(tex)
		canvas.current_atlas_path = path
		canvas.painted_data_ref = atlas_painted_data
		
		%MidColum.propagate_call("set_disabled", [false])



## Updates the stored animation speed value for the currently selected animated tile
func _on_current_animation_speed_value_changed(value: float) -> void:
	var selected_items: PackedInt32Array = auto_tiles_list.get_selected_items()
	
	if selected_items.size() > 0:
		var target_idx: int = selected_items[0]
		autotiles[target_idx]["anim_speed"] = value



## Updates the stored collision mode value for the currently selected tile
func _on_current_collision_item_selected(index: int) -> void:
	var selected_items: PackedInt32Array = auto_tiles_list.get_selected_items()
	
	if selected_items.size() > 0:
		var target_idx: int = selected_items[0]
		autotiles[target_idx]["collision_mode"] = index



## Updates the preview texture using the dictionary image data, displays the specific animation speed, and toggles alternative options
func _on_auto_tiles_list_item_selected(index: int) -> void:
	if index >= 0 and autotiles.size() > index:
		var tile_data: Dictionary = autotiles[index]
		var img_texture: Texture2D = tile_data["image"]
		var is_anim: bool = tile_data.get("is_animated", false)
		var mode: AtlasSelectorCanvas.AutotileType = tile_data.get("mode", canvas.AutotileType.SINGLE)
		
		preview_autotile_mode = mode
		
		if is_anim:
			preview_is_animated = true
			preview_frames = tile_data.get("frames", 1)
			preview_current_frame = 0
			preview_timer = 0.0
			
			var atlas_tex: AtlasTexture = AtlasTexture.new()
			atlas_tex.atlas = img_texture
			var frame_w: int = img_texture.get_width() / preview_frames
			atlas_tex.region = Rect2(0, 0, frame_w, img_texture.get_height())
			%AutotilePreview.texture = atlas_tex
		elif mode == canvas.AutotileType.LPC_FULL_ANIMATED:
			preview_is_animated = true
			preview_frames = 3
			preview_current_frame = 0
			preview_timer = 0.0
			
			preview_base_image = img_texture.get_image()
			var tile_w: int = preview_base_image.get_width() / 8
			
			preview_lpc_composite = Image.create(tile_w * 8, int(tile_w * 8.5), false, preview_base_image.get_format())
			preview_lpc_composite.blit_rect(preview_base_image, Rect2i(0, 0, tile_w * 8, tile_w * 6), Vector2i(0, 0))
			
			var frame_rect: Rect2i = Rect2i(0, tile_w * 6, tile_w, tile_w)
			preview_lpc_composite.blit_rect(preview_base_image, frame_rect, Vector2i(tile_w * 3, tile_w * 6 + int(tile_w * 0.5)))
			
			%AutotilePreview.texture = ImageTexture.create_from_image(preview_lpc_composite)
		else:
			preview_is_animated = false
			%AutotilePreview.texture = img_texture
			
		if is_anim or mode == canvas.AutotileType.LPC_FULL_ANIMATED:
			%CurrentAnimationSpeedContainer.visible = true
			%CurrentAnimationSpeed.set_value_no_signal(tile_data.get("anim_speed", 5.0))
			
			var anim_mode_node: OptionButton = get_node_or_null("%AnimationMode")
			if is_instance_valid(anim_mode_node):
				anim_mode_node.visible = true
				anim_mode_node.select(tile_data.get("anim_mode", 0))
				
				if not anim_mode_node.item_selected.is_connected(_on_animation_mode_item_selected):
					anim_mode_node.item_selected.connect(_on_animation_mode_item_selected)
		else:
			%CurrentAnimationSpeedContainer.visible = false
			var anim_mode_node: OptionButton = get_node_or_null("%AnimationMode")
			if is_instance_valid(anim_mode_node):
				anim_mode_node.visible = false
				
		if is_instance_valid(autotile_action_options):
			var disable_static_alt: bool = is_anim or mode == canvas.AutotileType.LPC_FULL_ANIMATED
			autotile_action_options.set_item_disabled(2, disable_static_alt)
			
			var disable_center: bool = mode == canvas.AutotileType.SINGLE
			if autotile_action_options.item_count > 4:
				autotile_action_options.set_item_disabled(4, disable_center)
			if autotile_action_options.item_count > 5:
				autotile_action_options.set_item_disabled(5, disable_center)
				
		var terrain: String = "-" if tile_data["terrain"].is_empty() else tile_data["terrain"]
		%LabelTerrainTileSelected.set_disabled(false)
		%LabelTerrainTileSelected.set_deferred("text", terrain)
		%LabelTerrainTileSelected.set_meta("selected_index", index)
		
		var current_col_node: OptionButton = get_node_or_null("%CurrentCollision")
		if is_instance_valid(current_col_node):
			current_col_node.select(tile_data.get("collision_mode", 0))



## Updates the animation mode for the currently selected tile in the dictionary
func _on_animation_mode_item_selected(index: int) -> void:
	var selected: PackedInt32Array = auto_tiles_list.get_selected_items()
	
	if selected.size() > 0:
		var tile_idx: int = selected[0]
		autotiles[tile_idx]["anim_mode"] = index



## Caches the target tile and triggers the appropriate mode or deletes the tile based on selection
func _on_autotile_action_selected(index: int) -> void:
	if index == 7:
		_show_tileset_preview()
		autotile_action_options.select(0)
		return
		
	var selected_items: PackedInt32Array = auto_tiles_list.get_selected_items()
	
	if selected_items.is_empty() or index == 0:
		autotile_action_options.select(0)
		return
		
	match index:
		1:
			_on_auto_tiles_list_delete_pressed(selected_items)
		2:
			var target_tile: Dictionary = autotiles[selected_items[0]]
			if target_tile.get("is_animated", false) or target_tile.get("mode") == canvas.AutotileType.LPC_FULL_ANIMATED:
				_prepare_alternative_mode(true, selected_items[0])
			else:
				_prepare_alternative_mode(false, selected_items[0])
		3:
			_prepare_alternative_mode(true, selected_items[0])
		4:
			_prepare_alternative_mode(false, selected_items[0], true)
		5:
			_prepare_alternative_mode(true, selected_items[0], true)
		6:
			_show_clear_alt_popup(selected_items[0])
			
	autotile_action_options.select(0)



## Generates temporary atlases in memory and displays them in a scrollable popup
func _show_tileset_preview() -> void:
	if autotiles.is_empty():
		return
		
	var atlases: Array[Image] = _build_atlases_images()
	var popup: AcceptDialog = AcceptDialog.new()
	popup.title = "Tileset Final Preview"
	
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(800, 600)
	
	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 20)
	
	for img in atlases:
		var tex_rect: TextureRect = TextureRect.new()
		tex_rect.texture = ImageTexture.create_from_image(img)
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP
		vbox.add_child(tex_rect)
		
	scroll.add_child(vbox)
	popup.add_child(scroll)
	
	add_child(popup)
	popup.popup_centered(Vector2(850, 650))
	popup.visibility_changed.connect(func(): if not popup.visible: popup.queue_free())



## Builds the dynamic PopupMenu positioning it exactly at the global mouse coordinates
func _show_clear_alt_popup(tile_index: int) -> void:
	clear_alt_popup.clear()
	
	var alts: Array = autotiles[tile_index].get("alternatives", [])
	
	if alts.is_empty():
		clear_alt_popup.add_item("No Alternatives Available")
		clear_alt_popup.set_item_disabled(0, true)
	else:
		clear_alt_popup.add_item("Clear All Alternatives", 0)
		clear_alt_popup.add_separator()
		
		for i in alts.size():
			var alt_data: Dictionary = alts[i]
			var icon: Texture2D = alt_data["image"]
			var item_name: String = "Clear alternative " + str(i + 1)
			
			clear_alt_popup.add_icon_item(icon, item_name, i + 1)
			
			var item_idx: int = clear_alt_popup.get_item_count() - 1
			var img: Image = icon.get_image()
			
			if img:
				img.resize(24, 24, Image.INTERPOLATE_NEAREST)
				clear_alt_popup.set_item_icon(item_idx, ImageTexture.create_from_image(img))
				
	clear_alt_popup.position = DisplayServer.mouse_get_position()
	clear_alt_popup.popup()



## Evaluates the selected index in the alternatives popup to delete one or all stored frames
func _on_clear_alt_popup_id_pressed(id: int) -> void:
	var selected_items: PackedInt32Array = auto_tiles_list.get_selected_items()
	
	if selected_items.is_empty():
		return
		
	var tile_idx: int = selected_items[0]
	var alts: Array = autotiles[tile_idx].get("alternatives", [])
	
	if id == 0:
		alts.clear()
	elif id > 0:
		var alt_idx: int = id - 1
		if alt_idx >= 0 and alt_idx < alts.size():
			alts.remove_at(alt_idx)



## Initializes the canvas locks and opens the proper panel for the requested alternative generation
func _prepare_alternative_mode(animated: bool, target_index: int, center_only: bool = false) -> void:
	var target_tile: Dictionary = autotiles[target_index]
	
	is_alternative_mode = true
	is_alternative_animated_mode = animated
	is_alternative_center_only = center_only
	
	if center_only:
		canvas.update_grid_and_mode(Vector2i(%Width.value, %Height.value), canvas.AutotileType.SINGLE)
		canvas.is_anim_size_locked = true
		canvas.locked_anim_size = Vector2i(1, 1)
	else:
		canvas.update_grid_and_mode(Vector2i(%Width.value, %Height.value), target_tile["mode"])
		if target_tile["mode"] == canvas.AutotileType.SINGLE:
			var w: int = target_tile["image"].get_width()
			var h: int = target_tile["image"].get_height()
			var frames: int = target_tile.get("frames", 1)
			var t_size: Vector2i = _get_active_tile_size()
			var base_w_tiles: int = maxi(1, (w / frames) / t_size.x)
			var base_h_tiles: int = maxi(1, h / t_size.y)
			
			canvas.is_anim_size_locked = true
			canvas.locked_anim_size = Vector2i(base_w_tiles, base_h_tiles)
		else:
			canvas.is_anim_size_locked = false
			
	if animated:
		_toggle_animation_mode()
	else:
		_apply_alt_panel_state(true)



## Synchronizes the visibility of the alternative UI panel
func _apply_alt_panel_state(state: bool) -> void:
	if is_instance_valid(alt_main_container):
		alt_main_container.visible = state
		
	if state:
		%RightColumn.propagate_call("set_disabled", [true])
		%LoadTileset.set_disabled(false)
		_update_alt_buttons_state()
	else:
		%RightColumn.propagate_call("set_disabled", [autotiles.size() == 0])
		%LoadTileset.set_disabled(false)



## Extracts the final visual image from a raw region depending on the autotile mode requested
func _extract_frame_image(region_image: Image, mode: AtlasSelectorCanvas.AutotileType) -> Image:
	var final_image: Image
	
	if mode == canvas.AutotileType.SINGLE:
		final_image = region_image.duplicate()
	else:
		var region_texture: ImageTexture = ImageTexture.create_from_image(region_image)
		
		match mode:
			canvas.AutotileType.EXTENDED:
				final_image = conversor.extract_extended_autotile(region_texture)
			canvas.AutotileType.COMPACT:
				final_image = conversor.extract_compact_autotile(region_texture)
			canvas.AutotileType.WALL:
				final_image = conversor.extract_wall_autotile(region_texture)
			canvas.AutotileType.NINE_SLICE:
				final_image = conversor.extract_nine_slice_autotile(region_texture)
			canvas.AutotileType.WATERFALL:
				final_image = conversor.extract_waterfall_autotile(region_texture)
			canvas.AutotileType.LPC_FULL, canvas.AutotileType.LPC_FULL_ANIMATED, canvas.AutotileType.LPC_BASIC:
				final_image = conversor.extract_lpc_autotile(region_texture)
				
	var target_size: Vector2i = _get_current_target_tile_size()
	
	if target_size != Vector2i.ZERO:
		var source_size: Vector2i = Vector2i(%Width.value, %Height.value)
		
		if source_size != target_size and source_size.x > 0 and source_size.y > 0:
			var scale_x: float = float(target_size.x) / float(source_size.x)
			var scale_y: float = float(target_size.y) / float(source_size.y)
			var new_w: int = roundi(final_image.get_width() * scale_x)
			var new_h: int = roundi(final_image.get_height() * scale_y)
			
			if new_w > 0 and new_h > 0:
				final_image.resize(new_w, new_h, Image.INTERPOLATE_NEAREST)
				
	return final_image



## Evaluates if the current canvas selection should go to the main list, animation panel, or alternative panel
func _on_canvas_autotile_selected(region: Rect2i) -> void:
	if not canvas.current_texture:
		return
		
	if is_alternative_mode and not is_alternative_animated_mode:
		_add_to_alternative_panel(region)
		return
		
	var source_image: Image = canvas.current_texture.get_image()
	var region_image: Image = source_image.get_region(region)
	var final_image: Image = _extract_frame_image(region_image, canvas.current_autotile_type)
			
	if final_image:
		var final_tex: ImageTexture = ImageTexture.create_from_image(final_image)
		var base_name: String = "Tile " if canvas.current_autotile_type == canvas.AutotileType.SINGLE else "Autotile "
		var autotile_name: String = base_name + str(autotiles.size() + 1)
		
		var col_mode: int = 0
		var add_col_node: OptionButton = get_node_or_null("%AddCollision")
		if is_instance_valid(add_col_node):
			col_mode = add_col_node.selected
			
		var autotile_data: Dictionary = {
			"image": final_tex,
			"name": autotile_name,
			"mode": canvas.current_autotile_type,
			"terrain": %TerrainName.text if not %TerrainName.text.is_empty() else "floor",
			"is_animated": false,
			"frames": 1,
			"collision_mode": col_mode,
			"source_atlas_path": canvas.current_texture.resource_path,
			"source_rect": region,
			"alternatives": []
		}
		
		autotiles.append(autotile_data)
		auto_tiles_list.add_item(autotile_name)
		
		var item_selected: int = autotiles.size() - 1
		auto_tiles_list.select(item_selected)
		auto_tiles_list.item_selected.emit(item_selected)
		
		if not is_animation_mode:
			%RightColumn.propagate_call("set_disabled", [false])
			
		_update_target_size_lock()



## Generates the preview rect in the alternative floating panel
func _add_to_alternative_panel(rect: Rect2i) -> void:
	if not canvas.current_texture or not is_instance_valid(alt_frames_container):
		return
		
	var source_image: Image = canvas.current_texture.get_image()
	alt_frames_data.append({
		"rect": rect, 
		"image": source_image, 
		"probability": 0.1,
		"source_atlas_path": canvas.current_texture.resource_path
	})
	
	var preview_img: Image = source_image.get_region(rect)
	var tex_rect: TextureRect = TextureRect.new()
	tex_rect.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	tex_rect.texture = ImageTexture.create_from_image(preview_img)
	tex_rect.custom_minimum_size = Vector2(64, 64)
	tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	tex_rect.gui_input.connect(_on_alt_frame_gui_input.bind(tex_rect))
	tex_rect.draw.connect(_on_tex_rect_draw.bind(tex_rect))
	
	alt_frames_container.add_child(tex_rect)
	
	var previously_selected: Array = selected_alt_frames.duplicate()
	selected_alt_frames.clear()
	selected_alt_frames.append(tex_rect)
	
	tex_rect.queue_redraw()
	
	for prev_rect in previously_selected:
		if is_instance_valid(prev_rect):
			prev_rect.queue_redraw()
			
	_update_alt_buttons_state()



## Receives the array of 1x1 selected areas from a drag drop and registers each as a SINGLE tile or intercepts for alternatives
func _on_canvas_single_tiles_selected(rects: Array[Rect2i]) -> void:
	if not canvas.current_texture:
		return
		
	if is_alternative_mode and not is_alternative_animated_mode:
		for region in rects:
			_add_to_alternative_panel(region)
		return
		
	var source_image: Image = canvas.current_texture.get_image()
	var col_mode: int = 0
	var add_col_node: OptionButton = get_node_or_null("%AddCollision")
	
	if is_instance_valid(add_col_node):
		col_mode = add_col_node.selected
		
	for region in rects:
		var region_image: Image = source_image.get_region(region)
		var extracted_image: Image = _extract_frame_image(region_image, canvas.AutotileType.SINGLE)
		var final_tex: ImageTexture = ImageTexture.create_from_image(extracted_image)
		var autotile_name: String = "Tile " + str(autotiles.size() + 1)
		
		var autotile_data: Dictionary = {
			"image": final_tex,
			"name": autotile_name,
			"mode": canvas.AutotileType.SINGLE,
			"terrain": %TerrainName.text if not %TerrainName.text.is_empty() else "floor",
			"is_animated": false,
			"frames": 1,
			"collision_mode": col_mode,
			"source_atlas_path": canvas.current_texture.resource_path,
			"source_rect": region,
			"alternatives": []
		}
		
		autotiles.append(autotile_data)
		auto_tiles_list.add_item(autotile_name)
		
	var item_selected: int = autotiles.size() - 1
	auto_tiles_list.select(item_selected)
	auto_tiles_list.item_selected.emit(item_selected)
	
	if not is_animation_mode:
		%RightColumn.propagate_call("set_disabled", [false])
		
	_update_target_size_lock()



## Triggers the temporary preview panel for building animated autotiles and links input handling
func _on_canvas_anim_frame_selected(rect: Rect2i) -> void:
	if not canvas.current_texture or not is_instance_valid(anim_frames_container):
		return
		
	var source_image: Image = canvas.current_texture.get_image()
	anim_frames_data.append({
		"rect": rect, 
		"image": source_image,
		"source_atlas_path": canvas.current_texture.resource_path
	})
	
	var preview_img: Image = source_image.get_region(rect)
	var tex_rect: TextureRect = TextureRect.new()
	tex_rect.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	tex_rect.texture = ImageTexture.create_from_image(preview_img)
	tex_rect.custom_minimum_size = Vector2(64, 64)
	tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	tex_rect.gui_input.connect(_on_anim_frame_gui_input.bind(tex_rect))
	tex_rect.draw.connect(_on_tex_rect_draw.bind(tex_rect))
	
	anim_frames_container.add_child(tex_rect)
	
	var previously_selected: Array = selected_anim_frames.duplicate()
	selected_anim_frames.clear()
	selected_anim_frames.append(tex_rect)
	
	tex_rect.queue_redraw()
	
	for prev_rect in previously_selected:
		if is_instance_valid(prev_rect):
			prev_rect.queue_redraw()
			
	_update_anim_buttons_state()



## Merges all stored temporary frames horizontally into a single autotile data dictionary or appends to target alternative
func _on_merge_anim_frames_pressed() -> void:
	if anim_frames_data.size() == 0:
		return
		
	var frame_images: Array[Image] = []
	var frames_count: int = anim_frames_data.size()
	var source_rects: Array = []
	
	for data in anim_frames_data:
		var source_image: Image = data["image"]
		var rect: Rect2i = data["rect"]
		var region_image: Image = source_image.get_region(rect)
		
		var mode_to_extract: int = canvas.AutotileType.SINGLE if is_alternative_center_only else canvas.current_autotile_type
		var extracted_frame: Image = _extract_frame_image(region_image, mode_to_extract as AtlasSelectorCanvas.AutotileType)
				
		frame_images.append(extracted_frame)
		source_rects.append({
			"path": data.get("source_atlas_path", ""),
			"rect": rect
		})
		
	var base_w: int = frame_images[0].get_width()
	var base_h: int = frame_images[0].get_height()
	var final_width: int = base_w * frames_count
	var final_height: int = base_h
	
	var merged_image: Image = Image.create(final_width, final_height, false, frame_images[0].get_format())
	
	if canvas.current_autotile_type == canvas.AutotileType.SINGLE or is_alternative_center_only:
		for f in range(frames_count):
			var src_rect: Rect2i = Rect2i(0, 0, base_w, base_h)
			var dest_pos: Vector2i = Vector2i(f * base_w, 0)
			merged_image.blit_rect(frame_images[f], src_rect, dest_pos)
	else:
		var t_size: Vector2i = _get_active_tile_size()
		var t_w: int = t_size.x
		var t_h: int = t_size.y
		var cols: int = base_w / t_w
		var rows: int = base_h / t_h
		var is_lpc_anim: bool = canvas.current_autotile_type == canvas.AutotileType.LPC_FULL_ANIMATED
		
		for y in range(rows):
			for x in range(cols):
				for f in range(frames_count):
					var src_rect: Rect2i = Rect2i(x * t_w, y * t_h, t_w, t_h)
					var dest_pos: Vector2i
					
					if is_lpc_anim and y == 6 and x < 3:
						dest_pos = Vector2i(((f * 3) + x) * t_w, y * t_h)
					else:
						dest_pos = Vector2i((x * frames_count + f) * t_w, y * t_h)
						
					merged_image.blit_rect(frame_images[f], src_rect, dest_pos)
			
	var final_tex: ImageTexture = ImageTexture.create_from_image(merged_image)
	var is_truly_animated: bool = frames_count > 1
	var current_anim_fps: float = anim_speed_spinbox.value if is_instance_valid(anim_speed_spinbox) else 5.0
	
	if is_alternative_mode and is_alternative_animated_mode:
		var target_idx: int = auto_tiles_list.get_selected_items()[0]
		var prob_val: float = 0.1
		
		if is_instance_valid(anim_prob_spinbox):
			prob_val = anim_prob_spinbox.value
			
		var alt_data: Dictionary = {
			"image": final_tex,
			"is_animated": is_truly_animated,
			"frames": frames_count,
			"probability": prob_val,
			"anim_speed": current_anim_fps,
			"anim_mode": 0,
			"is_center_only": is_alternative_center_only,
			"source_rects": source_rects
		}
		
		if not autotiles[target_idx].has("alternatives"):
			autotiles[target_idx]["alternatives"] = []
			
		autotiles[target_idx]["alternatives"].append(alt_data)
		is_alternative_mode = false
		is_alternative_animated_mode = false
		is_alternative_center_only = false
	else:
		var prefix: String = ""
		if canvas.current_autotile_type == canvas.AutotileType.SINGLE:
			prefix = "Anim Tile " if is_truly_animated else "Tile "
		else:
			prefix = "Anim Autotile " if is_truly_animated else "Autotile "
			
		var autotile_name: String = prefix + str(autotiles.size() + 1)
		
		var col_mode: int = 0
		var add_col_node: OptionButton = get_node_or_null("%AddCollision")
		if is_instance_valid(add_col_node):
			col_mode = add_col_node.selected
			
		var autotile_data: Dictionary = {
			"image": final_tex,
			"name": autotile_name,
			"mode": canvas.current_autotile_type,
			"terrain": %TerrainName.text,
			"is_animated": is_truly_animated,
			"frames": frames_count,
			"collision_mode": col_mode,
			"anim_speed": current_anim_fps,
			"anim_mode": 0,
			"source_rects": source_rects,
			"alternatives": []
		}
		
		autotiles.append(autotile_data)
		auto_tiles_list.add_item(autotile_name)
		
		var item_selected: int = autotiles.size() - 1
		auto_tiles_list.select(item_selected)
		auto_tiles_list.item_selected.emit(item_selected)
		
	_clear_anim_frames()
	_on_close_anim_panel_pressed()
	_update_target_size_lock()



## Configures the required collision layer (physics or passability object) on a target TileData
func _apply_collision_data(tile_data: TileData, col_mode: int, tile_size: Vector2i) -> void:
	if col_mode == 0:
		return
		
	if col_mode == 1:
		var hw: float = tile_size.x / 2.0
		var hh: float = tile_size.y / 2.0
		var poly: PackedVector2Array = PackedVector2Array([Vector2(-hw, -hh), Vector2(hw, -hh), Vector2(hw, hh), Vector2(-hw, hh)])
		tile_data.add_collision_polygon(0)
		tile_data.set_collision_polygon_points(0, 0, poly)
		return
		
	var passability_uids: Array[String] = [
		"uid://bhkyl2nefh0vw",
		"uid://dh13f2nbimgdk",
		"uid://dvbf7nj3d1pqi",
		"uid://ctj5rixmpxmh",
		"uid://cswt1yiv64ii5",
		"uid://bj7q3uwkrex11",
		"uid://dd5dkqrcsm3ot",
		"uid://fmedhw832qkr",
		"uid://drbkoriiny12k",
		"uid://c5bhm1ifci6fm",
		"uid://co1crjt1oeegv",
		"uid://dy7v82dul0mms",
		"uid://d4gn0ppkrr5jh",
		"uid://cfinb3hqtr715",
		"uid://bnf5ocksurqmm"
	]
	
	var resource_index: int = col_mode - 3
	
	if resource_index >= 0 and resource_index < passability_uids.size():
		var passability_res: Resource = load(passability_uids[resource_index])
		if passability_res != null:
			tile_data.set_custom_data("Passability", passability_res)



## Processes the static alternative frames and assigns them to the target base tile
func _on_merge_alt_frames_pressed() -> void:
	if alt_frames_data.size() == 0:
		return
		
	var selected_items: PackedInt32Array = auto_tiles_list.get_selected_items()
	
	if selected_items.is_empty():
		return
		
	var target_idx: int = selected_items[0]
	
	for data in alt_frames_data:
		var source_image: Image = data["image"]
		var rect: Rect2i = data["rect"]
		var region_image: Image = source_image.get_region(rect)
		
		var extracted_frame: Image
		if is_alternative_center_only:
			extracted_frame = _extract_frame_image(region_image, canvas.AutotileType.SINGLE)
		else:
			extracted_frame = _extract_frame_image(region_image, canvas.current_autotile_type)
					
		var final_tex: ImageTexture = ImageTexture.create_from_image(extracted_frame)
		var alt_data: Dictionary = {
			"image": final_tex,
			"is_animated": false,
			"frames": 1,
			"probability": data.get("probability", 0.1),
			"is_center_only": is_alternative_center_only,
			"source_atlas_path": data.get("source_atlas_path", ""),
			"source_rect": rect
		}
		
		if not autotiles[target_idx].has("alternatives"):
			autotiles[target_idx]["alternatives"] = []
			
		autotiles[target_idx]["alternatives"].append(alt_data)
		
	_clear_alt_frames()
	_on_close_alt_panel_pressed()



## Triggers a delayed canvas refresh and caches the width parameter
func _on_width_value_updated(old_value: float, new_value: float) -> void:
	refresh_time = 0.15
	_update_cache("last_tile_size", Vector2i(%Width.value, %Height.value))



## Triggers a delayed canvas refresh and caches the height parameter
func _on_height_value_changed(value: float) -> void:
	refresh_time = 0.15
	_update_cache("last_tile_size", Vector2i(%Width.value, %Height.value))



## Triggers a delayed canvas refresh and caches the custom option button selection
func _on_custom_option_button_item_selected(index: int) -> void:
	refresh_time = 0.15
	_update_cache("last_mode_used", index)



## Removes selected atlases from memory, caches the array, and refreshes the visual list
func _on_atlas_list_delete_pressed(indexes: PackedInt32Array) -> void:
	var new_atlases: Array = []
	
	for i in atlas.size():
		if not i in indexes:
			new_atlases.append(atlas[i])
			
	atlas = new_atlases
	_update_cache("last_files_used", atlas)
	_fill_atlas_list(indexes[-1])



## Removes selected autotiles from memory and refreshes the visual list
func _on_auto_tiles_list_delete_pressed(indexes: PackedInt32Array) -> void:
	var new_autotiles: Array = []
	
	for i in autotiles.size():
		if not i in indexes:
			new_autotiles.append(autotiles[i])
			
	autotiles = new_autotiles
	_fill_autotiles_list(indexes[-1])
	_update_target_size_lock()



## Toggles the collision painting mode on the canvas
func _on_paint_collision_toggled(button_pressed: bool) -> void:
	canvas.is_painting_collision = button_pressed
	canvas.is_painting_mode = canvas.is_painting_collision or canvas.is_painting_terrain



## Toggles the terrain painting mode on the canvas
func _on_paint_terrain_toggled(button_pressed: bool) -> void:
	canvas.is_painting_terrain = button_pressed
	canvas.is_painting_mode = canvas.is_painting_collision or canvas.is_painting_terrain



## Processes a paint request from the canvas and updates the internal painted data dictionary
func _on_canvas_paint_tile_requested(coord: Vector2i, erase: bool) -> void:
	if not canvas.current_texture:
		return
		
	var path: String = canvas.current_texture.resource_path
	
	if not atlas_painted_data.has(path):
		atlas_painted_data[path] = {}
		
	if not atlas_painted_data[path].has(coord):
		atlas_painted_data[path][coord] = {}
		
	var modified: bool = false
	
	if canvas.is_painting_collision:
		if erase:
			if atlas_painted_data[path][coord].has("col"):
				atlas_painted_data[path][coord].erase("col")
				modified = true
		else:
			var col_node: OptionButton = get_node_or_null("%AddCollision")
			var current_col: int = col_node.selected if is_instance_valid(col_node) else 0
			
			if current_col == 0:
				if atlas_painted_data[path][coord].has("col"):
					atlas_painted_data[path][coord].erase("col")
					modified = true
			else:
				atlas_painted_data[path][coord]["col"] = current_col
				modified = true
				
	if canvas.is_painting_terrain:
		if erase:
			if atlas_painted_data[path][coord].has("ter"):
				atlas_painted_data[path][coord].erase("ter")
				modified = true
		else:
			var ter_node: LineEdit = get_node_or_null("%TerrainName")
			var current_ter: String = ter_node.text if is_instance_valid(ter_node) else ""
			
			if current_ter == "":
				if atlas_painted_data[path][coord].has("ter"):
					atlas_painted_data[path][coord].erase("ter")
					modified = true
			else:
				atlas_painted_data[path][coord]["ter"] = current_ter
				modified = true
				
	if atlas_painted_data[path][coord].is_empty():
		atlas_painted_data[path].erase(coord)
		
	if modified:
		canvas.painted_data_ref = atlas_painted_data
		canvas.cursor_canvas.queue_redraw()


## Checks directories and opens the dialog to select where textures will be saved or preselects the edit path
func _on_generate_tileset_pressed() -> void:
	if autotiles.is_empty():
		return
		
	var dir: DirAccess = DirAccess.open("res://")
	
	if not dir.dir_exists("Assets/Images/Tilesets"):
		dir.make_dir_recursive("Assets/Images/Tilesets")
		
	if not dir.dir_exists("Assets/Tilesets"):
		dir.make_dir_recursive("Assets/Tilesets")
		
	if current_editing_tileset_path != "":
		save_dialog.current_dir = current_editing_tileset_path.get_base_dir()
		save_dialog.current_file = current_editing_tileset_path.get_file()
		save_dialog.popup_centered_ratio(0.5)
	else:
		image_dir_dialog.popup_centered_ratio(0.5)



## Stores and caches the selected image directory and prompts for the tileset save location
func _on_image_dir_selected(dir: String) -> void:
	selected_image_dir = dir
	_update_cache("last_image_folder", dir)
	save_dialog.popup_centered_ratio(0.5)



## Main execution flow handler that caches the target path
func _on_save_file_selected(path: String) -> void:
	selected_tileset_path = path
	current_editing_tileset_path = path
	_update_cache("last_tileset_folder", path.get_base_dir())
	call_deferred("_generate_everything")



## Forces the editor to release any previous reference to the file before writing new data
func _force_cache_cleanup(path: String) -> void:
	if ResourceLoader.has_cached(path):
		var ghost_resource: Resource = ResourceLoader.load(path)
		if is_instance_valid(ghost_resource):
			ghost_resource.take_over_path("")
			
	var fs: EditorFileSystem = EditorInterface.get_resource_filesystem()
	fs.update_file(path)



## Returns a completely new file path appending a numeric ID if the original already exists
func _get_unique_path(original_path: String) -> String:
	if not FileAccess.file_exists(original_path):
		return original_path
		
	var dir: String = original_path.get_base_dir()
	var file: String = original_path.get_file()
	var base_name: String = file.get_basename()
	var ext: String = file.get_extension()
	var counter: int = 1
	var new_path: String = original_path
	
	while FileAccess.file_exists(new_path):
		new_path = dir.path_join(base_name + "_" + str(counter) + "." + ext)
		counter += 1
		
	return new_path



## Processes images entirely in memory respecting the dynamic layout constraints and returns the atlas segments
func _build_atlases_images() -> Array[Image]:
	var current_atlas_idx: int = 0
	var current_x: int = 0
	var current_y: int = 0
	var row_height: int = 0
	var actual_w: int = 0
	var actual_h: int = 0
	var current_image: Image = null
	var result_images: Array[Image] = []
	var t_size: Vector2i = _get_active_tile_size()
	
	for i in autotiles.size():
		var elements_to_pack: Array = [autotiles[i]]
		
		if autotiles[i].has("alternatives"):
			elements_to_pack.append_array(autotiles[i]["alternatives"])
			
		for element in elements_to_pack:
			var img: Image = element["image"].get_image()
			
			if img.get_format() != Image.FORMAT_RGBA8:
				img.convert(Image.FORMAT_RGBA8)
				
			var w: int = img.get_width()
			var h: int = img.get_height()
			var grid_w: int = ceil(float(w) / t_size.x) * t_size.x
			var grid_h: int = ceil(float(h) / t_size.y) * t_size.y
			
			if current_x > 0 and current_x + grid_w > max_atlas_width:
				current_x = 0
				current_y += row_height
				row_height = 0
				
			if current_y > 0 and current_y + grid_h > max_atlas_height:
				var cropped_image: Image = current_image.get_region(Rect2i(0, 0, maxi(1, actual_w), maxi(1, actual_h)))
				result_images.append(cropped_image)
				
				current_atlas_idx += 1
				current_x = 0
				current_y = 0
				row_height = 0
				actual_w = 0
				actual_h = 0
				current_image = null
				
			if current_image == null:
				var req_w: int = maxi(max_atlas_width, grid_w)
				var req_h: int = maxi(max_atlas_height, grid_h)
				current_image = Image.create(req_w, req_h, false, Image.FORMAT_RGBA8)
				
			current_image.blit_rect(img, Rect2i(0, 0, w, h), Vector2i(current_x, current_y))
			element["atlas_idx"] = current_atlas_idx
			element["rect"] = Rect2i(current_x, current_y, w, h)
			
			current_x += grid_w
			row_height = maxi(row_height, grid_h)
			actual_w = maxi(actual_w, current_x)
			actual_h = maxi(actual_h, current_y + grid_h)
			
	if current_image != null:
		var cropped_last: Image = current_image.get_region(Rect2i(0, 0, maxi(1, actual_w), maxi(1, actual_h)))
		result_images.append(cropped_last)
		
	return result_images



## Processes images and builds the TileSet dynamically scaling the atlas limits if a sequence exceeds them
func _generate_everything() -> void:
	if Engine.is_editor_hint():
		var inspector: EditorInspector = EditorInterface.get_inspector()
		
		if is_instance_valid(inspector):
			var edited_obj: Object = inspector.get_edited_object()
			
			if edited_obj is TileSet and edited_obj.resource_path == selected_tileset_path:
				var alert: AcceptDialog = AcceptDialog.new()
				alert.title = "File locked!"
				alert.dialog_text = "The TileSet file you're trying to overwrite is open in the Inspector.\n\nTo prevent unexpected crashes, select another node in your scene to release the file, and then click Save again."
				add_child(alert)
				alert.popup_centered()
				alert.visibility_changed.connect(func(): if not alert.visible: alert.queue_free())
				return
				
	var anim_fps: float = 5.0
	
	if is_instance_valid(anim_speed_spinbox):
		anim_fps = anim_speed_spinbox.value
		
	var base_name: String = selected_tileset_path.get_file().get_basename()
	var generated_atlases: Array[Dictionary] = []
	var atlases_images: Array[Image] = _build_atlases_images()
	
	for i in atlases_images.size():
		var img: Image = atlases_images[i]
		var path: String = selected_image_dir.path_join(base_name + "_atlas_" + str(i) + ".png")
		
		_pending_saves.append({"type": "image", "path": path, "data": img})
		generated_atlases.append({"path": path, "image": img})
		
	var tileset: TileSet
	
	if FileAccess.file_exists(selected_tileset_path):
		tileset = load(selected_tileset_path)
		if is_instance_valid(tileset):
			while tileset.get_source_count() > 0:
				tileset.remove_source(tileset.get_source_id(0))
			while tileset.get_terrain_sets_count() > 0:
				tileset.remove_terrain_set(0)
			while tileset.get_custom_data_layers_count() > 0:
				tileset.remove_custom_data_layer(0)
			while tileset.get_physics_layers_count() > 0:
				tileset.remove_physics_layer(0)
		else:
			tileset = TileSet.new()
			tileset.take_over_path(selected_tileset_path)
	else:
		tileset = TileSet.new()
		tileset.take_over_path(selected_tileset_path)
		
	tileset.tile_size = _get_active_tile_size()
	
	tileset.add_terrain_set(0)
	tileset.set_terrain_set_mode(0, TileSet.TERRAIN_MODE_MATCH_CORNERS_AND_SIDES)
	
	tileset.add_custom_data_layer(0)
	tileset.set_custom_data_layer_name(0, "TerrainName")
	tileset.set_custom_data_layer_type(0, TYPE_PACKED_STRING_ARRAY)
	
	tileset.add_custom_data_layer(1)
	tileset.set_custom_data_layer_name(1, "Passability")
	tileset.set_custom_data_layer_type(1, TYPE_OBJECT)
	
	tileset.add_physics_layer(0)
	
	var atlas_sources: Dictionary = {}
	
	for i in generated_atlases.size():
		var path: String = generated_atlases[i]["path"]
		var img: Image = generated_atlases[i]["image"]
		
		var tex: ImageTexture = ImageTexture.create_from_image(img)
		tex.take_over_path(path)
		
		var source: TileSetAtlasSource = TileSetAtlasSource.new()
		source.texture = tex
		source.texture_region_size = tileset.tile_size
		tileset.add_source(source, i)
		atlas_sources[i] = source
		
	for i in autotiles.size():
		var autotile: Dictionary = autotiles[i]
		var mode: AtlasSelectorCanvas.AutotileType = autotile["mode"]
		var is_single: bool = mode == canvas.AutotileType.SINGLE
		var col_mode: int = autotile.get("collision_mode", 0)
		
		tileset.add_terrain(0, -1)
		var terrain_id: int = tileset.get_terrains_count(0) - 1
		var terrain_name: String = autotile["name"] if autotile["terrain"].is_empty() else autotile["terrain"] + str(i + 1)
		tileset.set_terrain_name(0, terrain_id, terrain_name)
		
		var elements_to_configure: Array = [autotile]
		if autotile.has("alternatives"):
			elements_to_configure.append_array(autotile["alternatives"])
			
		for element in elements_to_configure:
			var atlas_idx: int = element["atlas_idx"]
			var source: TileSetAtlasSource = atlas_sources[atlas_idx]
			var start_coord: Vector2i = element["rect"].position / tileset.tile_size
			var is_animated: bool = element.get("is_animated", false)
			var frames: int = element.get("frames", 1)
			var current_anim_fps: float = element.get("anim_speed", anim_fps)
			var current_anim_mode: int = element.get("anim_mode", 0)
			var is_center_only: bool = element.get("is_center_only", false)
			var atlas_path: String = element.get("source_atlas_path", "")
			var painted_for_atlas: Dictionary = atlas_painted_data.get(atlas_path, {})
			var base_coord_in_source: Vector2i = element.get("source_rect", Rect2i()).position / tileset.tile_size
			
			if is_single or is_center_only:
				var frame_w_px: int = element["rect"].size.x / frames
				var frame_h_px: int = element["rect"].size.y
				var size_in_atlas: Vector2i = Vector2i(frame_w_px / tileset.tile_size.x, frame_h_px / tileset.tile_size.y)
				size_in_atlas = Vector2i(maxi(1, size_in_atlas.x), maxi(1, size_in_atlas.y))
				
				if not source.has_tile(start_coord):
					source.create_tile(start_coord, size_in_atlas)
					
				if is_animated and frames > 1:
					source.set_tile_animation_columns(start_coord, frames)
					source.set_tile_animation_frames_count(start_coord, frames)
					source.set_tile_animation_separation(start_coord, Vector2i.ZERO)
					source.set_tile_animation_speed(start_coord, current_anim_fps)
					source.set_tile_animation_mode(start_coord, current_anim_mode)
					
				var p_data: Dictionary = painted_for_atlas.get(base_coord_in_source, {})
				var single_col: int = col_mode
				
				if p_data.has("col"):
					single_col = p_data["col"]
					
				var single_ter: String = element.get("terrain", autotile.get("terrain", ""))
				if p_data.has("ter") and p_data["ter"] != "":
					single_ter = p_data["ter"]
				if single_ter == "":
					single_ter = "floor"
					
				var single_data: TileData = source.get_tile_data(start_coord, 0)
				if single_data:
					single_data.set_custom_data("TerrainName", [single_ter] as PackedStringArray)
					single_data.probability = element.get("probability", 1.0)
					single_data.terrain_set = 0
					single_data.terrain = terrain_id
					_apply_collision_data(single_data, single_col, tileset.tile_size)
					
					if is_center_only:
						var center_mask: int = 15 if (mode == canvas.AutotileType.WALL or mode == canvas.AutotileType.WATERFALL) else 255
						_apply_peering_bits(source, start_coord, center_mask, terrain_id, mode)
				continue
				
			var real_img: Image = generated_atlases[atlas_idx]["image"]
			var tex_size: Vector2i = real_img.get_size()
			var valid_masks: Array[int] = _get_valid_masks(mode)
			var columns: int = 4 if (mode == canvas.AutotileType.WALL or mode == canvas.AutotileType.WATERFALL) else 8
			
			for t in valid_masks.size():
				var local_coord: Vector2i = Vector2i((t % columns) * frames, t / columns) if is_animated else Vector2i(t % columns, t / columns)
				var tile_coord: Vector2i = start_coord + local_coord
				var pixel_pos: Vector2i = tile_coord * tileset.tile_size
				
				if pixel_pos.x >= tex_size.x or pixel_pos.y >= tex_size.y:
					continue
					
				if not source.has_tile(tile_coord):
					source.create_tile(tile_coord)
					
				if is_animated and frames > 1:
					source.set_tile_animation_columns(tile_coord, frames)
					source.set_tile_animation_frames_count(tile_coord, frames)
					source.set_tile_animation_separation(tile_coord, Vector2i.ZERO)
					source.set_tile_animation_speed(tile_coord, current_anim_fps)
					source.set_tile_animation_mode(tile_coord, current_anim_mode)
					
				_apply_peering_bits(source, tile_coord, valid_masks[t], terrain_id, mode)
				
				var source_local_tile: Vector2i = Vector2i.ZERO
				match mode:
					canvas.AutotileType.EXTENDED:
						source_local_tile = conversor.EXTENDED_TL_STATES[conversor._get_tl_state_47(valid_masks[t])] / 2
					canvas.AutotileType.COMPACT:
						source_local_tile = conversor.COMPACT_TL_STATES[conversor._get_tl_state_47(valid_masks[t])] / 2
					canvas.AutotileType.WALL:
						source_local_tile = conversor.WALL_TL_STATES[conversor._get_tl_state_16(valid_masks[t])] / 2
					canvas.AutotileType.NINE_SLICE:
						source_local_tile = conversor.NINE_SLICE_TL_STATES[conversor._get_tl_state_47(valid_masks[t])] / 2
					canvas.AutotileType.WATERFALL:
						source_local_tile = conversor.WATERFALL_TL_STATES[conversor._get_tl_state_16(valid_masks[t])] / 2
					canvas.AutotileType.LPC_FULL, canvas.AutotileType.LPC_FULL_ANIMATED, canvas.AutotileType.LPC_BASIC:
						source_local_tile = conversor.LPC_TL_STATES[conversor._get_tl_state_47(valid_masks[t])] / 2
						
				var check_coord: Vector2i = base_coord_in_source + source_local_tile
				var p_data: Dictionary = painted_for_atlas.get(check_coord, {})
				var final_col: int = col_mode
				
				if p_data.has("col"):
					final_col = p_data["col"]
					
				var final_ter: String = autotile.get("terrain", "")
				if p_data.has("ter") and p_data["ter"] != "":
					final_ter = p_data["ter"]
				
				var tile_data: TileData = source.get_tile_data(tile_coord, 0)
				if tile_data:
					if final_ter != "":
						tile_data.set_custom_data("TerrainName", [final_ter] as PackedStringArray)
						
					if mode == canvas.AutotileType.LPC_FULL_ANIMATED and valid_masks[t] == 255:
						tile_data.probability = 0.0
					else:
						tile_data.probability = element.get("probability", 1.0)
						
					_apply_collision_data(tile_data, final_col, tileset.tile_size)
					
			if mode == canvas.AutotileType.EXTENDED:
				var alt_local_coord: Vector2i = Vector2i(7 * frames, 5) if is_animated else Vector2i(7, 5)
				var alt_tile_coord: Vector2i = start_coord + alt_local_coord
				
				if not source.has_tile(alt_tile_coord):
					var alt_pixel_pos: Vector2i = alt_tile_coord * tileset.tile_size
					
					if alt_pixel_pos.x < tex_size.x and alt_pixel_pos.y < tex_size.y:
						var alt_img: Image = real_img.get_region(Rect2i(alt_pixel_pos, tileset.tile_size))
						if not conversor._is_image_rect_empty(alt_img, Rect2i(Vector2i.ZERO, tileset.tile_size)):
							source.create_tile(alt_tile_coord)
							_apply_peering_bits(source, alt_tile_coord, 255, terrain_id, mode)
							
							var alt_data: TileData = source.get_tile_data(alt_tile_coord, 0)
							if alt_data:
								var check_coord: Vector2i = base_coord_in_source + Vector2i(1, 1)
								var p_data: Dictionary = painted_for_atlas.get(check_coord, {})
								var final_col: int = p_data.get("col", col_mode)
								var final_ter: String = p_data.get("ter", autotile.get("terrain", ""))
								
								if final_ter != "":
									alt_data.set_custom_data("TerrainName", [final_ter] as PackedStringArray)
									
								alt_data.probability = element.get("probability", 1.0) * 0.05
								_apply_collision_data(alt_data, final_col, tileset.tile_size)
								
							if is_animated and frames > 1:
								source.set_tile_animation_columns(alt_tile_coord, frames)
								source.set_tile_animation_frames_count(alt_tile_coord, frames)
								source.set_tile_animation_separation(alt_tile_coord, Vector2i.ZERO)
								source.set_tile_animation_speed(alt_tile_coord, current_anim_fps)
								source.set_tile_animation_mode(alt_tile_coord, current_anim_mode)
								
			if mode in [canvas.AutotileType.LPC_FULL, canvas.AutotileType.LPC_FULL_ANIMATED, canvas.AutotileType.LPC_BASIC]:
				var alt_iso_coord: Vector2i = start_coord + (Vector2i(7 * frames, 5) if is_animated else Vector2i(7, 5))
				
				if not source.has_tile(alt_iso_coord):
					var alt_pixel_pos: Vector2i = alt_iso_coord * tileset.tile_size
					
					if alt_pixel_pos.x < tex_size.x and alt_pixel_pos.y < tex_size.y:
						var alt_img: Image = real_img.get_region(Rect2i(alt_pixel_pos, tileset.tile_size))
						if not conversor._is_image_rect_empty(alt_img, Rect2i(Vector2i.ZERO, tileset.tile_size)):
							source.create_tile(alt_iso_coord)
							_apply_peering_bits(source, alt_iso_coord, 0, terrain_id, mode)
							
							var alt_iso_data: TileData = source.get_tile_data(alt_iso_coord, 0)
							if alt_iso_data:
								var check_coord: Vector2i = base_coord_in_source + Vector2i(0, 1)
								var p_data: Dictionary = painted_for_atlas.get(check_coord, {})
								var final_col: int = p_data.get("col", col_mode)
								var final_ter: String = p_data.get("ter", autotile.get("terrain", ""))
								
								if final_ter != "":
									alt_iso_data.set_custom_data("TerrainName", [final_ter] as PackedStringArray)
									
								alt_iso_data.probability = element.get("probability", 1.0) * 0.1
								_apply_collision_data(alt_iso_data, final_col, tileset.tile_size)
								
							if is_animated and frames > 1:
								source.set_tile_animation_columns(alt_iso_coord, frames)
								source.set_tile_animation_frames_count(alt_iso_coord, frames)
								source.set_tile_animation_separation(alt_iso_coord, Vector2i.ZERO)
								source.set_tile_animation_speed(alt_iso_coord, current_anim_fps)
								source.set_tile_animation_mode(alt_iso_coord, current_anim_mode)
						
				if mode == canvas.AutotileType.LPC_FULL_ANIMATED:
					var anim_center_coord: Vector2i = start_coord + Vector2i(0, 6)
					
					if not source.has_tile(anim_center_coord):
						source.create_tile(anim_center_coord)
						
					_apply_peering_bits(source, anim_center_coord, 255, terrain_id, mode)
					
					var anim_data: TileData = source.get_tile_data(anim_center_coord, 0)
					if anim_data:
						var check_coord: Vector2i = base_coord_in_source + Vector2i(1, 3)
						var p_data: Dictionary = painted_for_atlas.get(check_coord, {})
						var final_col: int = p_data.get("col", col_mode)
						var final_ter: String = p_data.get("ter", autotile.get("terrain", ""))
						
						if final_ter != "":
							anim_data.set_custom_data("TerrainName", [final_ter] as PackedStringArray)
							
						anim_data.probability = element.get("probability", 1.0)
						_apply_collision_data(anim_data, final_col, tileset.tile_size)
						
					var final_frames: int = frames * 3 if is_animated else 3
					if final_frames > 1:
						source.set_tile_animation_columns(anim_center_coord, final_frames)
						source.set_tile_animation_frames_count(anim_center_coord, final_frames)
						source.set_tile_animation_separation(anim_center_coord, Vector2i.ZERO)
						source.set_tile_animation_speed(anim_center_coord, current_anim_fps)
						source.set_tile_animation_mode(anim_center_coord, current_anim_mode)
						
				elif mode == canvas.AutotileType.LPC_FULL:
					var max_alts: int = 1 if is_animated else 3
					
					for alt_idx in range(max_alts):
						var alt_c_coord: Vector2i = start_coord + (Vector2i(alt_idx * frames, 6) if is_animated else Vector2i(alt_idx, 6))
						
						if not source.has_tile(alt_c_coord):
							source.create_tile(alt_c_coord)
							
						_apply_peering_bits(source, alt_c_coord, 255, terrain_id, mode)
						
						var c_data: TileData = source.get_tile_data(alt_c_coord, 0)
						if c_data:
							var check_coord: Vector2i = base_coord_in_source + Vector2i(1, 3)
							var p_data: Dictionary = painted_for_atlas.get(check_coord, {})
							var final_col: int = p_data.get("col", col_mode)
							var final_ter: String = p_data.get("ter", autotile.get("terrain", ""))
							
							if final_ter != "":
								c_data.set_custom_data("TerrainName", [final_ter] as PackedStringArray)
								
							c_data.probability = element.get("probability", 1.0) * 0.1
							_apply_collision_data(c_data, final_col, tileset.tile_size)
							
						if is_animated and frames > 1:
							source.set_tile_animation_columns(alt_c_coord, frames)
							source.set_tile_animation_frames_count(alt_c_coord, frames)
							source.set_tile_animation_separation(alt_c_coord, Vector2i.ZERO)
							source.set_tile_animation_speed(alt_c_coord, current_anim_fps)
							source.set_tile_animation_mode(alt_c_coord, current_anim_mode)
								
	_inject_metadata_to_tileset(tileset)
	_pending_saves.append({"type": "resource", "path": selected_tileset_path, "data": tileset})



## Packages current configuration into a lightweight dictionary and injects it into the TileSet metadata before saving
func _inject_metadata_to_tileset(tileset: TileSet) -> void:
	var clean_autotiles_data: Array = []
	
	for tile in autotiles:
		var safe_tile: Dictionary = {
			"name": tile["name"],
			"mode": tile["mode"],
			"terrain": tile["terrain"],
			"is_animated": tile["is_animated"],
			"frames": tile["frames"],
			"collision_mode": tile["collision_mode"],
			"anim_speed": tile.get("anim_speed", 5.0),
			"anim_mode": tile.get("anim_mode", 0),
			"source_atlas_path": tile.get("source_atlas_path", ""),
			"source_rect": tile.get("source_rect", Rect2i()),
			"source_rects": tile.get("source_rects", [])
		}
		
		var safe_alts: Array = []
		if tile.has("alternatives"):
			for alt in tile["alternatives"]:
				safe_alts.append({
					"is_animated": alt["is_animated"],
					"frames": alt["frames"],
					"probability": alt["probability"],
					"anim_speed": alt.get("anim_speed", 5.0),
					"anim_mode": alt.get("anim_mode", 0),
					"is_center_only": alt.get("is_center_only", false),
					"source_atlas_path": alt.get("source_atlas_path", ""),
					"source_rect": alt.get("source_rect", Rect2i()),
					"source_rects": alt.get("source_rects", [])
				})
				
		safe_tile["alternatives"] = safe_alts
		clean_autotiles_data.append(safe_tile)
		
	var tool_data: Dictionary = {
		"version": "1.0",
		"tile_width": %Width.value,
		"tile_height": %Height.value,
		"target_tile_width": _get_active_tile_size().x,
		"target_tile_height": _get_active_tile_size().y,
		"images_export_folder": selected_image_dir,
		"painted_data": atlas_painted_data,
		"autotiles": clean_autotiles_data
	}
	
	tileset.set_meta("rpg_creator_data", tool_data)



## Opens a selected TileSet file, validates its origin, filters missing textures, and reconstructs the UI state
func _load_tileset_from_file(path: String) -> void:
	var loaded_tileset: TileSet = ResourceLoader.load(path)
	
	if not is_instance_valid(loaded_tileset) or not loaded_tileset.has_meta("rpg_creator_data"):
		var alert: AcceptDialog = AcceptDialog.new()
		alert.title = "Invalid TileSet"
		alert.dialog_text = "This TileSet was not generated by Godot RPG Creator or is missing its configuration metadata."
		add_child(alert)
		alert.popup_centered()
		alert.visibility_changed.connect(func(): if not alert.visible: alert.queue_free())
		return
		
	var tool_data: Dictionary = loaded_tileset.get_meta("rpg_creator_data")
	
	_clear_anim_frames()
	_clear_alt_frames()
	autotiles.clear()
	atlas.clear()
	
	%Width.value = tool_data.get("tile_width", 32)
	%Height.value = tool_data.get("tile_height", 32)
	selected_image_dir = tool_data.get("images_export_folder", "res://Assets/Images/Tilesets")
	current_editing_tileset_path = path
	atlas_painted_data = tool_data.get("painted_data", {})
	
	if is_instance_valid(canvas):
		canvas.painted_data_ref = atlas_painted_data
		
	var t_w: int = tool_data.get("target_tile_width", tool_data.get("tile_width", 32))
	var t_h: int = tool_data.get("target_tile_height", tool_data.get("tile_height", 32))
	var loaded_target: Vector2i = Vector2i(t_w, t_h)
	var source_size: Vector2i = Vector2i(tool_data.get("tile_width", 32), tool_data.get("tile_height", 32))
	
	if is_instance_valid(target_tile_size_options):
		var target_idx: int = 0
		if loaded_target != source_size:
			for i in TARGET_SIZES.size():
				if TARGET_SIZES[i] == loaded_target:
					target_idx = i
					break
		target_tile_size_options.select(target_idx)
	
	for tile_data in tool_data.get("autotiles", []):
		var reconstructed_tile: Dictionary = _reconstruct_tile_from_metadata(tile_data)
		var base_mode: int = tile_data.get("mode", 0)
		
		if reconstructed_tile.is_empty():
			continue
			
		reconstructed_tile["alternatives"] = []
		
		if tile_data.has("alternatives"):
			for alt_data in tile_data["alternatives"]:
				var reconstructed_alt: Dictionary = _reconstruct_tile_from_metadata(alt_data, base_mode)
				
				if not reconstructed_alt.is_empty():
					reconstructed_tile["alternatives"].append(reconstructed_alt)
					
		autotiles.append(reconstructed_tile)
		
	_update_target_size_lock()
	_update_cache("last_files_used", atlas)
	_fill_atlas_list(0)
	_fill_autotiles_list(0)



## Returns an array with the specific 8-bit masks valid for the requested autotile mode
func _get_valid_masks(mode: AtlasSelectorCanvas.AutotileType) -> Array[int]:
	var valid_masks: Array[int] = []
	
	if mode == AtlasSelectorCanvas.AutotileType.WALL or mode == AtlasSelectorCanvas.AutotileType.WATERFALL:
		for mask in 16:
			valid_masks.append(mask)
		return valid_masks
		
	var unique_hashes: Array[String] = []
	
	for mask in 256:
		var tl: int = conversor._get_tl_state_47(mask)
		var tr: int = conversor._get_tr_state_47(mask)
		var bl: int = conversor._get_bl_state_47(mask)
		var br: int = conversor._get_br_state_47(mask)
		var tile_hash: String = str(tl) + str(tr) + str(bl) + str(br)
		
		if not unique_hashes.has(tile_hash):
			unique_hashes.append(tile_hash)
			valid_masks.append(mask)
			
	return valid_masks



## Configures the TileData peering bits safely enforcing the grid integrity
func _apply_peering_bits(source: TileSetAtlasSource, coords: Vector2i, mask: int, terrain_id: int, mode: AtlasSelectorCanvas.AutotileType) -> void:
	var tile_data: TileData = source.get_tile_data(coords, 0)
	
	if not tile_data: 
		return
		
	tile_data.terrain_set = 0
	tile_data.terrain = terrain_id
	
	if mode == AtlasSelectorCanvas.AutotileType.WALL or mode == AtlasSelectorCanvas.AutotileType.WATERFALL:
		if (mask & 1) != 0: 
			tile_data.set_terrain_peering_bit(TileSet.CELL_NEIGHBOR_TOP_SIDE, terrain_id)
		if (mask & 2) != 0: 
			tile_data.set_terrain_peering_bit(TileSet.CELL_NEIGHBOR_RIGHT_SIDE, terrain_id)
		if (mask & 4) != 0: 
			tile_data.set_terrain_peering_bit(TileSet.CELL_NEIGHBOR_BOTTOM_SIDE, terrain_id)
		if (mask & 8) != 0: 
			tile_data.set_terrain_peering_bit(TileSet.CELL_NEIGHBOR_LEFT_SIDE, terrain_id)
			
		if (mask & 1) != 0 and (mask & 2) != 0:
			tile_data.set_terrain_peering_bit(TileSet.CELL_NEIGHBOR_TOP_RIGHT_CORNER, terrain_id)
		if (mask & 2) != 0 and (mask & 4) != 0:
			tile_data.set_terrain_peering_bit(TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_CORNER, terrain_id)
		if (mask & 4) != 0 and (mask & 8) != 0:
			tile_data.set_terrain_peering_bit(TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_CORNER, terrain_id)
		if (mask & 8) != 0 and (mask & 1) != 0:
			tile_data.set_terrain_peering_bit(TileSet.CELL_NEIGHBOR_TOP_LEFT_CORNER, terrain_id)
	else:
		if (mask & 1) != 0: 
			tile_data.set_terrain_peering_bit(TileSet.CELL_NEIGHBOR_TOP_SIDE, terrain_id)
		if (mask & 2) != 0: 
			tile_data.set_terrain_peering_bit(TileSet.CELL_NEIGHBOR_TOP_RIGHT_CORNER, terrain_id)
		if (mask & 4) != 0: 
			tile_data.set_terrain_peering_bit(TileSet.CELL_NEIGHBOR_RIGHT_SIDE, terrain_id)
		if (mask & 8) != 0: 
			tile_data.set_terrain_peering_bit(TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_CORNER, terrain_id)
		if (mask & 16) != 0: 
			tile_data.set_terrain_peering_bit(TileSet.CELL_NEIGHBOR_BOTTOM_SIDE, terrain_id)
		if (mask & 32) != 0: 
			tile_data.set_terrain_peering_bit(TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_CORNER, terrain_id)
		if (mask & 64) != 0: 
			tile_data.set_terrain_peering_bit(TileSet.CELL_NEIGHBOR_LEFT_SIDE, terrain_id)
		if (mask & 128) != 0: 
			tile_data.set_terrain_peering_bit(TileSet.CELL_NEIGHBOR_TOP_LEFT_CORNER, terrain_id)



## Rebuilds the visual texture from the raw stored paths handling animated merging and single tiles
func _reconstruct_tile_from_metadata(data: Dictionary, parent_mode: int = -1) -> Dictionary:
	var result: Dictionary = data.duplicate(true)
	var mode_int: int = data.get("mode", parent_mode)
	
	if mode_int == -1: 
		mode_int = canvas.AutotileType.SINGLE
		
	if data.get("is_center_only", false):
		mode_int = canvas.AutotileType.SINGLE
		
	var mode: AtlasSelectorCanvas.AutotileType = mode_int as AtlasSelectorCanvas.AutotileType
	
	if data.get("is_animated", false) and data.has("source_rects") and data["source_rects"].size() > 0:
		var frame_images: Array[Image] = []
		var frames_count: int = data["source_rects"].size()
		
		for frame_data in data["source_rects"]:
			var path: String = frame_data.get("path", "")
			var rect: Rect2i = frame_data.get("rect", Rect2i())
			
			if not FileAccess.file_exists(path):
				printerr("Missing animation frame at ", path)
				return {}
				
			if not atlas.has(path):
				atlas.append(path)
				
			var s_tex: Texture2D = load(path)
			var s_img: Image = s_tex.get_image()
			var r_img: Image = s_img.get_region(rect)
			var extracted: Image = _extract_frame_image(r_img, mode)
			frame_images.append(extracted)
			
		var base_w: int = frame_images[0].get_width()
		var base_h: int = frame_images[0].get_height()
		var merged_image: Image = Image.create(base_w * frames_count, base_h, false, frame_images[0].get_format())
		
		if mode == canvas.AutotileType.SINGLE:
			for f in range(frames_count):
				merged_image.blit_rect(frame_images[f], Rect2i(0, 0, base_w, base_h), Vector2i(f * base_w, 0))
		else:
			var t_size: Vector2i = _get_active_tile_size()
			var t_w: int = t_size.x
			var t_h: int = t_size.y
			var cols: int = base_w / t_w
			var rows: int = base_h / t_h
			var is_lpc_anim: bool = mode == canvas.AutotileType.LPC_FULL_ANIMATED
			
			for y in range(rows):
				for x in range(cols):
					for f in range(frames_count):
						var src_rect: Rect2i = Rect2i(x * t_w, y * t_h, t_w, t_h)
						var dest_pos: Vector2i
						
						if is_lpc_anim and y == 6 and x < 3:
							dest_pos = Vector2i(((f * 3) + x) * t_w, y * t_h)
						else:
							dest_pos = Vector2i((x * frames_count + f) * t_w, y * t_h)
							
						merged_image.blit_rect(frame_images[f], src_rect, dest_pos)
						
		result["image"] = ImageTexture.create_from_image(merged_image)
	else:
		var path: String = data.get("source_atlas_path", "")
		var rect: Rect2i = data.get("source_rect", Rect2i())
		
		if not FileAccess.file_exists(path):
			printerr("Missing tile source at ", path)
			return {}
			
		if not atlas.has(path):
			atlas.append(path)
			
		var s_tex: Texture2D = load(path)
		var s_img: Image = s_tex.get_image()
		var r_img: Image = s_img.get_region(rect)
		var extracted: Image = _extract_frame_image(r_img, mode)
		
		result["image"] = ImageTexture.create_from_image(extracted)
		
	return result



## Triggers the manual exit workflow
func _on_close_button_pressed() -> void:
	_exit()



## Cleans up active textures and frees the window instance securely
func _exit() -> void:
	if canvas:
		canvas.set_texture(null)
		
	if _pending_saves.size() > 0:
		for item in _pending_saves:
			if item["type"] == "image":
				var img: Image = item["data"]
				img.take_over_path("")
				img.save_png(item["path"])
			elif item["type"] == "resource":
				var res: Resource = item["data"]
				ResourceSaver.save(res, item["path"])
				
		var efs: EditorFileSystem = EditorInterface.get_resource_filesystem()
		efs.scan()
			
		_pending_saves.clear()
		
	queue_free()



## Saves the position of the floating panel when the user finishes dragging it and restricts it to window bounds
func _on_floating_animation_handle_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.is_pressed():
				draggin_animation_panel = true
			else:
				draggin_animation_panel = false
				_update_cache("last_anim_panel_pos", %FloatingMainPanelContainer.global_position)
	elif draggin_animation_panel and event is InputEventMouseMotion:
		%FloatingMainPanelContainer.global_position += event.relative


## Closes the alternative panel and resets the alternative mode flags
func _on_close_alt_panel_pressed() -> void:
	_clear_alt_frames()
	is_alternative_mode = false
	is_alternative_animated_mode = false
	is_alternative_center_only = false
	_apply_alt_panel_state(false)
	
	var cached_mode: int = _get_cache_value("last_mode_used", 0)
	canvas.is_anim_size_locked = false
	canvas.update_grid_and_mode(Vector2i(%Width.value, %Height.value), cached_mode as AtlasSelectorCanvas.AutotileType)


## Saves the updated terrain name label mapping it internally to the selected autotile
func _on_label_terrain_tile_selected_text_changed(new_text: String) -> void:
	if %LabelTerrainTileSelected.has_meta("selected_index"):
		var index: int = %LabelTerrainTileSelected.get_meta("selected_index")
		autotiles[index]["terrain"] = new_text
