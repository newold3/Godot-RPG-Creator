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
@export var anim_prob_main_container: Container

var atlas: Array = []
var autotiles: Array = []

@onready var canvas: AtlasSelectorCanvas = %Canvas
@onready var atlas_list: VBoxContainer = %AtlasList
@onready var auto_tiles_list: ItemList = %AutoTilesList
@onready var conversor: TilesetConversor = %Conversor

var refresh_time: float = 0.0
var save_dialog: EditorFileDialog
var image_dir_dialog: EditorFileDialog

var selected_image_dir: String = ""
var selected_tileset_path: String = ""

var anim_frames_data: Array[Dictionary] = []
var selected_anim_frames: Array[TextureRect] = []
var draggin_animation_panel: bool = false
var is_animation_mode: bool = false

var is_alternative_mode: bool = false
var is_alternative_animated_mode: bool = false
var alt_frames_data: Array[Dictionary] = []
var selected_alt_frames: Array[TextureRect] = []

var clear_alt_popup: PopupMenu

var _pending_saves: Array[Dictionary] = []

#endregion



#region CACHE_MANAGEMENT

## Loads previously saved user preferences from the FileCache global dictionary and forces canvas updates
func _load_cached_preferences() -> void:
	if not FileCache.options.has("tile_conversor"):
		FileCache.options["tile_conversor"] = {}
		
	var cached_size: Vector2i = _get_cache_value("last_tile_size", Vector2i(32, 32))
	%Width.set_value_no_signal(cached_size.x)
	%Height.set_value_no_signal(cached_size.y)
	
	var cached_mode: int = _get_cache_value("last_mode_used", 0)
	%AutototileType.select(cached_mode)
	
	canvas.update_grid_and_mode(cached_size, cached_mode as AtlasSelectorCanvas.AutotileType)
	
	is_animation_mode = _get_cache_value("last_anim_mode_state", false)
	_apply_animation_mode_state()
	
	_restore_panel_position.call_deferred()
	
	var saved_atlases: Array = _get_cache_value("last_files_used", [])
	
	for path in saved_atlases:
		if FileAccess.file_exists(path):
			atlas.append(path)
			
	if atlas.size() > 0:
		_fill_atlas_list(0)



## Safely retrieves a value from the FileCache dictionary, returning a default if not found
func _get_cache_value(key: String, default_value: Variant) -> Variant:
	var cache: Dictionary = FileCache.options.get("tile_conversor", {})
	
	return cache.get(key, default_value)



## Updates a specific key in the FileCache dictionary to persist user preferences
func _update_cache(key: String, value: Variant) -> void:
	if not FileCache.options.has("tile_conversor"):
		FileCache.options["tile_conversor"] = {}
		
	FileCache.options["tile_conversor"][key] = value

#endregion



#region INIT_AND_UI

## Initializes the window, connects signals, loads cached preferences, and prepares the UI
func _ready() -> void:
	if not RPGDialogFunctions.there_are_any_dialog_open():
		set_process(false)
		return

	close_requested.connect(_exit)
	%MidColum.propagate_call("set_disabled", [true])
	%AutotilePreview.texture = null
	%RightColumn.propagate_call("set_disabled", [true])
	%LabelTerrainTileSelected.text = "-"
	
	CustomTooltipManager.plugin_replace_all_tooltips_with_custom(self)
	
	_load_cached_preferences.call_deferred()
	
	canvas.single_tiles_selected.connect(_on_canvas_single_tiles_selected)
	canvas.autotile_anim_frame_selected.connect(_on_canvas_anim_frame_selected)
	canvas.autotile_selected.connect(_on_canvas_autotile_selected)
	
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
	
	set_process(true)


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


## Catches the Ctrl key input dynamically to act as a toggle for the animation mode and handles frame deletion
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_CTRL:
			_toggle_animation_mode()
		elif event.keycode == KEY_DELETE or event.keycode == KEY_BACKSPACE:
			var focus_owner: Control = get_viewport().gui_get_focus_owner()
			if is_instance_valid(focus_owner) and (focus_owner is LineEdit or focus_owner is TextEdit):
				return
			if is_alternative_mode and not is_alternative_animated_mode:
				_delete_selected_alt_frames()
			elif is_animation_mode or is_alternative_animated_mode:
				_delete_selected_anim_frames()


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



## Toggles the internal animation mode flag, caches it, and forces UI updates
func _toggle_animation_mode() -> void:
	is_animation_mode = !is_animation_mode
	_update_cache("last_anim_mode_state", is_animation_mode)
	_apply_animation_mode_state()



## Explicitly disables animation mode when the user clicks the UI close button and caches the state
func _on_close_anim_panel_pressed() -> void:
	_clear_anim_frames()
	is_animation_mode = false
	_update_cache("last_anim_mode_state", is_animation_mode)
	_apply_animation_mode_state()



## Synchronizes the visibility and interactability of the UI panels based on the current mode
func _apply_animation_mode_state() -> void:
	canvas.is_animation_mode = is_animation_mode
	canvas._update_help_text()
	canvas.cursor_canvas.queue_redraw()
	
	if is_instance_valid(anim_main_container):
		anim_main_container.visible = is_animation_mode
		
	%FloatingAnimationPanel.propagate_call("set_disabled", [not is_animation_mode])
	
	if is_instance_valid(anim_prob_spinbox):
		anim_prob_spinbox.visible = is_alternative_mode and is_alternative_animated_mode
		
		if is_instance_valid(anim_prob_main_container):
			anim_prob_main_container.visible = anim_prob_spinbox.visible 
	
	if is_animation_mode:
		%RightColumn.propagate_call("set_disabled", [true])
		_restore_panel_position.call_deferred()
		_update_anim_buttons_state()
	else:
		%RightColumn.propagate_call("set_disabled", [autotiles.size() == 0])



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


## Evaluates if an atlas exists at the requested index or opens the dialog to load a new one
func _on_atlas_list_item_activated(index: int) -> void:
	if index >= 0 and atlas.size() > index:
		return
	else:
		_select_new_atlas()



## Opens the RPG Creator file dialog centered on the mouse to let the user pick an image
func _select_new_atlas() -> void:
	var path = "res://addons/CustomControls/Dialogs/select_file_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	
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
	var list = atlas_list
	list.clear()
	
	%MidColum.propagate_call("set_disabled", [true])
	%AutotilePreview.texture = null
	%RightColumn.propagate_call("set_disabled", [true])
	%LabelTerrainTileSelected.text = "-"
	
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
		%LabelTerrainTileSelected.text = "-"



## Loads the image file into memory and pushes it to the canvas rendering logic
func _on_atlas_list_item_selected(index: int) -> void:
	if atlas.size() > index:
		var path: String = atlas[index]
		
		if not FileAccess.file_exists(path):
			return
			
		var tex = load(path)
		
		canvas.set_texture(tex)
		%MidColum.propagate_call("set_disabled", [false])



## Updates the preview texture using the dictionary image data
func _on_auto_tiles_list_item_selected(index: int) -> void:
	if index >= 0 and autotiles.size() > index:
		%AutotilePreview.texture = autotiles[index]["image"]
		var terrain = "-" if autotiles[index]["terrain"].is_empty() else autotiles[index]["terrain"]
		%LabelTerrainTileSelected.text = terrain



## Caches the target tile and triggers the appropriate mode or deletes the tile based on selection
func _on_autotile_action_selected(index: int) -> void:
	var selected_items: PackedInt32Array = auto_tiles_list.get_selected_items()
	
	if selected_items.is_empty() or index == 0:
		autotile_action_options.select(0)
		return
		
	match index:
		1:
			_on_auto_tiles_list_delete_pressed(selected_items)
		2:
			_prepare_alternative_mode(false, selected_items[0])
		3:
			_prepare_alternative_mode(true, selected_items[0])
		4:
			_show_clear_alt_popup(selected_items[0])
			
	autotile_action_options.select(0)



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
func _prepare_alternative_mode(animated: bool, target_index: int) -> void:
	var target_tile: Dictionary = autotiles[target_index]
	
	canvas.update_grid_and_mode(Vector2i(%Width.value, %Height.value), target_tile["mode"])
	is_alternative_mode = true
	is_alternative_animated_mode = animated
	
	if target_tile["mode"] == canvas.AutotileType.SINGLE:
		var w: int = target_tile["image"].get_width()
		var h: int = target_tile["image"].get_height()
		var frames: int = target_tile.get("frames", 1)
		var base_w_tiles: int = maxi(1, (w / frames) / %Width.value)
		var base_h_tiles: int = maxi(1, h / %Height.value)
		
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
		_update_alt_buttons_state()
	else:
		%RightColumn.propagate_call("set_disabled", [autotiles.size() == 0])



## Closes the alternative panel and resets the alternative mode flags
func _on_close_alt_panel_pressed() -> void:
	_clear_alt_frames()
	is_alternative_mode = false
	is_alternative_animated_mode = false
	_apply_alt_panel_state(false)
	
	var cached_mode: int = _get_cache_value("last_mode_used", 0)
	canvas.is_anim_size_locked = false
	canvas.update_grid_and_mode(Vector2i(%Width.value, %Height.value), cached_mode as AtlasSelectorCanvas.AutotileType)



## Evaluates if the current canvas selection should go to the main list, animation panel, or alternative panel
func _on_canvas_autotile_selected(region: Rect2i) -> void:
	if not canvas.current_texture:
		return
		
	if is_alternative_mode and not is_alternative_animated_mode:
		_add_to_alternative_panel(region)
		return
		
	var source_image: Image = canvas.current_texture.get_image()
	var region_image: Image = source_image.get_region(region)
	var final_image: Image
	
	if canvas.current_autotile_type == canvas.AutotileType.SINGLE:
		final_image = region_image
	else:
		var region_texture: ImageTexture = ImageTexture.create_from_image(region_image)
		match canvas.current_autotile_type:
			canvas.AutotileType.EXTENDED:
				final_image = conversor.extract_extended_autotile(region_texture)
			canvas.AutotileType.COMPACT:
				final_image = conversor.extract_compact_autotile(region_texture)
			canvas.AutotileType.WALL:
				final_image = conversor.extract_wall_autotile(region_texture)
			
	if final_image:
		var final_tex: ImageTexture = ImageTexture.create_from_image(final_image)
		var base_name: String = "Tile " if canvas.current_autotile_type == canvas.AutotileType.SINGLE else "Autotile "
		var autotile_name: String = base_name + str(autotiles.size() + 1)
		
		var autotile_data: Dictionary = {
			"image": final_tex,
			"name": autotile_name,
			"mode": canvas.current_autotile_type,
			"terrain": %TerrainName.text if not %TerrainName.text.is_empty() else "floor",
			"is_animated": false,
			"frames": 1,
			"alternatives": []
		}
		
		autotiles.append(autotile_data)
		auto_tiles_list.add_item(autotile_name)
		
		var item_selected: int = autotiles.size() - 1
		auto_tiles_list.select(item_selected)
		auto_tiles_list.item_selected.emit(item_selected)
		if not is_animation_mode:
			%RightColumn.propagate_call("set_disabled", [false])



## Generates the preview rect in the alternative floating panel
func _add_to_alternative_panel(rect: Rect2i) -> void:
	if not canvas.current_texture or not is_instance_valid(alt_frames_container):
		return
		
	var source_image: Image = canvas.current_texture.get_image()
	alt_frames_data.append({"rect": rect, "image": source_image, "probability": 0.1})
	
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
	
	for region in rects:
		var region_image: Image = source_image.get_region(region)
		var final_tex: ImageTexture = ImageTexture.create_from_image(region_image)
		var autotile_name: String = "Tile " + str(autotiles.size() + 1)
		
		var autotile_data: Dictionary = {
			"image": final_tex,
			"name": autotile_name,
			"mode": canvas.AutotileType.SINGLE,
			"terrain": %TerrainName.text if not %TerrainName.text.is_empty() else "floor",
			"is_animated": false,
			"frames": 1,
			"alternatives": []
		}
		
		autotiles.append(autotile_data)
		auto_tiles_list.add_item(autotile_name)
		
	var item_selected: int = autotiles.size() - 1
	auto_tiles_list.select(item_selected)
	auto_tiles_list.item_selected.emit(item_selected)
	if not is_animation_mode:
		%RightColumn.propagate_call("set_disabled", [false])



## Triggers the temporary preview panel for building animated autotiles and links input handling
func _on_canvas_anim_frame_selected(rect: Rect2i) -> void:
	if not canvas.current_texture or not is_instance_valid(anim_frames_container):
		return
		
	var source_image: Image = canvas.current_texture.get_image()
	anim_frames_data.append({"rect": rect, "image": source_image})
	
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
	
	for data in anim_frames_data:
		var source_image: Image = data["image"]
		var rect: Rect2i = data["rect"]
		var region_image: Image = source_image.get_region(rect)
		var region_texture: ImageTexture = ImageTexture.create_from_image(region_image)
		var extracted_frame: Image
		
		if canvas.current_autotile_type == canvas.AutotileType.SINGLE:
			extracted_frame = region_image
		else:
			match canvas.current_autotile_type:
				canvas.AutotileType.EXTENDED:
					extracted_frame = conversor.extract_extended_autotile(region_texture)
				canvas.AutotileType.COMPACT:
					extracted_frame = conversor.extract_compact_autotile(region_texture)
				canvas.AutotileType.WALL:
					extracted_frame = conversor.extract_wall_autotile(region_texture)
				
		frame_images.append(extracted_frame)
		
	var base_w: int = frame_images[0].get_width()
	var base_h: int = frame_images[0].get_height()
	var final_width: int = base_w * frames_count
	var final_height: int = base_h
	
	var merged_image: Image = Image.create(final_width, final_height, false, frame_images[0].get_format())
	
	if canvas.current_autotile_type == canvas.AutotileType.SINGLE:
		for f in range(frames_count):
			var src_rect: Rect2i = Rect2i(0, 0, base_w, base_h)
			var dest_pos: Vector2i = Vector2i(f * base_w, 0)
			merged_image.blit_rect(frame_images[f], src_rect, dest_pos)
	else:
		var t_w: int = %Width.value
		var t_h: int = %Height.value
		var cols: int = base_w / t_w
		var rows: int = base_h / t_h
		
		for y in range(rows):
			for x in range(cols):
				for f in range(frames_count):
					var src_rect: Rect2i = Rect2i(x * t_w, y * t_h, t_w, t_h)
					var dest_pos: Vector2i = Vector2i((x * frames_count + f) * t_w, y * t_h)
					merged_image.blit_rect(frame_images[f], src_rect, dest_pos)
			
	var final_tex: ImageTexture = ImageTexture.create_from_image(merged_image)
	var is_truly_animated: bool = frames_count > 1
	
	if is_alternative_mode and is_alternative_animated_mode:
		var target_idx: int = auto_tiles_list.get_selected_items()[0]
		var prob_val: float = 0.1
		
		if is_instance_valid(anim_prob_spinbox):
			prob_val = anim_prob_spinbox.value
			
		var alt_data: Dictionary = {
			"image": final_tex,
			"is_animated": is_truly_animated,
			"frames": frames_count,
			"probability": prob_val
		}
		
		if not autotiles[target_idx].has("alternatives"):
			autotiles[target_idx]["alternatives"] = []
			
		autotiles[target_idx]["alternatives"].append(alt_data)
		is_alternative_mode = false
		is_alternative_animated_mode = false
	else:
		var prefix: String = ""
		if canvas.current_autotile_type == canvas.AutotileType.SINGLE:
			prefix = "Anim Tile " if is_truly_animated else "Tile "
		else:
			prefix = "Anim Autotile " if is_truly_animated else "Autotile "
			
		var autotile_name: String = prefix + str(autotiles.size() + 1)
		
		var autotile_data: Dictionary = {
			"image": final_tex,
			"name": autotile_name,
			"mode": canvas.current_autotile_type,
			"terrain": %TerrainName.text,
			"is_animated": is_truly_animated,
			"frames": frames_count,
			"alternatives": []
		}
		
		autotiles.append(autotile_data)
		auto_tiles_list.add_item(autotile_name)
		
		var item_selected: int = autotiles.size() - 1
		auto_tiles_list.select(item_selected)
		auto_tiles_list.item_selected.emit(item_selected)
		
	_clear_anim_frames()
	_on_close_anim_panel_pressed()


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
		
		if canvas.current_autotile_type == canvas.AutotileType.SINGLE:
			extracted_frame = region_image
		else:
			var region_texture: ImageTexture = ImageTexture.create_from_image(region_image)
			match canvas.current_autotile_type:
				canvas.AutotileType.EXTENDED:
					extracted_frame = conversor.extract_extended_autotile(region_texture)
				canvas.AutotileType.COMPACT:
					extracted_frame = conversor.extract_compact_autotile(region_texture)
				canvas.AutotileType.WALL:
					extracted_frame = conversor.extract_wall_autotile(region_texture)
					
		var final_tex: ImageTexture = ImageTexture.create_from_image(extracted_frame)
		var alt_data: Dictionary = {
			"image": final_tex,
			"is_animated": false,
			"frames": 1,
			"probability": data.get("probability", 0.1)
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

#endregion



#region GENERATION_AND_SAVING

## Checks directories and opens the dialog to select where textures will be saved
func _on_generate_tileset_pressed() -> void:
	if autotiles.is_empty():
		return
		
	var dir: DirAccess = DirAccess.open("res://")
	
	if not dir.dir_exists("Assets/Images/Tilesets"):
		dir.make_dir_recursive("Assets/Images/Tilesets")
		
	if not dir.dir_exists("Assets/Tilesets"):
		dir.make_dir_recursive("Assets/Tilesets")
		
	image_dir_dialog.popup_centered_ratio(0.5)



## Stores and caches the selected image directory and prompts for the tileset save location
func _on_image_dir_selected(dir: String) -> void:
	selected_image_dir = dir
	_update_cache("last_image_folder", dir)
	save_dialog.popup_centered_ratio(0.5)



## Main execution flow handler that caches the target path
func _on_save_file_selected(path: String) -> void:
	selected_tileset_path = path
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


## Processes images and builds the TileSet in memory with robust terrain ID indexing to avoid out of bounds crashes
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
	var current_atlas_idx: int = 0
	var current_x: int = 0
	var current_y: int = 0
	var row_height: int = 0
	var actual_w: int = 0
	var actual_h: int = 0
	var current_image: Image = Image.create(max_atlas_width, max_atlas_height, false, Image.FORMAT_RGBA8)
	var generated_atlases: Array[Dictionary] = []
	
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
			
			var grid_w: int = ceil(float(w) / %Width.value) * %Width.value
			var grid_h: int = ceil(float(h) / %Height.value) * %Height.value
			
			if current_x + grid_w > max_atlas_width:
				current_x = 0
				current_y += row_height
				row_height = 0
				
			if current_y + grid_h > max_atlas_height:
				var expected_atlas_path: String = selected_image_dir.path_join(base_name + "_atlas_" + str(current_atlas_idx) + ".png")
				var atlas_path: String = expected_atlas_path
				var cropped_image: Image = current_image.get_region(Rect2i(0, 0, maxi(1, actual_w), maxi(1, actual_h)))
				
				_pending_saves.append({"type": "image", "path": atlas_path, "data": cropped_image})
				generated_atlases.append({"path": atlas_path, "image": cropped_image})
				
				current_atlas_idx += 1
				current_x = 0
				current_y = 0
				row_height = 0
				actual_w = 0
				actual_h = 0
				current_image = Image.create(max_atlas_width, max_atlas_height, false, Image.FORMAT_RGBA8)
				
			current_image.blit_rect(img, Rect2i(0, 0, w, h), Vector2i(current_x, current_y))
			element["atlas_idx"] = current_atlas_idx
			element["rect"] = Rect2i(current_x, current_y, w, h)
			
			current_x += grid_w
			row_height = maxi(row_height, grid_h)
			actual_w = maxi(actual_w, current_x)
			actual_h = maxi(actual_h, current_y + grid_h)
			
	var last_path: String = selected_image_dir.path_join(base_name + "_atlas_" + str(current_atlas_idx) + ".png")
	var cropped_last: Image = current_image.get_region(Rect2i(0, 0, maxi(1, actual_w), maxi(1, actual_h)))
	
	_pending_saves.append({"type": "image", "path": last_path, "data": cropped_last})
	generated_atlases.append({"path": last_path, "image": cropped_last})
	
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
		else:
			tileset = TileSet.new()
			tileset.take_over_path(selected_tileset_path)
	else:
		tileset = TileSet.new()
		tileset.take_over_path(selected_tileset_path)
		
	tileset.tile_size = Vector2i(%Width.value, %Height.value)
	tileset.add_terrain_set(0)
	tileset.set_terrain_set_mode(0, TileSet.TERRAIN_MODE_MATCH_CORNERS_AND_SIDES)
	
	tileset.add_custom_data_layer(0)
	tileset.set_custom_data_layer_name(0, "TerrainName")
	tileset.set_custom_data_layer_type(0, TYPE_PACKED_STRING_ARRAY)
	
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
			
			if is_single:
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
					source.set_tile_animation_speed(start_coord, anim_fps)
				
				var single_data: TileData = source.get_tile_data(start_coord, 0)
				if single_data:
					var t_name: String = autotile["terrain"] if autotile["terrain"] != "" else "floor"
					single_data.set_custom_data("TerrainName", [t_name] as PackedStringArray)
					single_data.probability = element.get("probability", 1.0)
					single_data.terrain_set = 0
					single_data.terrain = terrain_id
				continue
				
			var real_img: Image = generated_atlases[atlas_idx]["image"]
			var tex_size: Vector2i = real_img.get_size()
			var valid_masks: Array[int] = _get_valid_masks(mode)
			var columns: int = 8 if mode != AtlasSelectorCanvas.AutotileType.WALL else 4
			
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
					source.set_tile_animation_speed(tile_coord, anim_fps)
					
				_apply_peering_bits(source, tile_coord, valid_masks[t], terrain_id, mode)
				
				var tile_data: TileData = source.get_tile_data(tile_coord, 0)
				if tile_data:
					tile_data.probability = element.get("probability", 1.0)
				
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
								alt_data.probability = element.get("probability", 1.0) * 0.05
								
							if is_animated and frames > 1:
								source.set_tile_animation_columns(alt_tile_coord, frames)
								source.set_tile_animation_frames_count(alt_tile_coord, frames)
								source.set_tile_animation_separation(alt_tile_coord, Vector2i.ZERO)
								source.set_tile_animation_speed(alt_tile_coord, anim_fps)
								
	_pending_saves.append({"type": "resource", "path": selected_tileset_path, "data": tileset})


## Returns an array with the specific 8-bit masks valid for the requested autotile mode
func _get_valid_masks(mode: AtlasSelectorCanvas.AutotileType) -> Array[int]:
	var valid_masks: Array[int] = []
	
	if mode == AtlasSelectorCanvas.AutotileType.WALL:
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
	
	if mode == AtlasSelectorCanvas.AutotileType.WALL:
		if (mask & 1) != 0: 
			tile_data.set_terrain_peering_bit(TileSet.CELL_NEIGHBOR_TOP_SIDE, terrain_id)
		if (mask & 2) != 0: 
			tile_data.set_terrain_peering_bit(TileSet.CELL_NEIGHBOR_RIGHT_SIDE, terrain_id)
		if (mask & 4) != 0: 
			tile_data.set_terrain_peering_bit(TileSet.CELL_NEIGHBOR_BOTTOM_SIDE, terrain_id)
		if (mask & 8) != 0: 
			tile_data.set_terrain_peering_bit(TileSet.CELL_NEIGHBOR_LEFT_SIDE, terrain_id)
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

#endregion
