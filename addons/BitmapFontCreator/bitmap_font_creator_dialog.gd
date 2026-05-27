@tool
extends Window

const LETTER = preload("uid://cswl8dxfrxi2")

@onready var main_container: FlowContainer = %MainContainer
@onready var preview_line_edit: LineEdit = %PreviewText
@onready var preview_label: Label = %PreviewLabel

@onready var selection_option: OptionButton = %SelectionMode
@onready var align_x_spinbox: SpinBox = %AlignX
@onready var align_y_spinbox: SpinBox = %AlignY
@onready var space_width_spinbox: SpinBox = %SpaceLength
@onready var font_size_spinbox: SpinBox = %FontSize

@onready var auto_fill_button: Button = %AutoFillButton
@onready var save_button: Button = %SaveButton
@onready var import_button: Button = %ImportButton

@onready var clear_button: Button = %ClearButton

var custom_space_width: float = 0.0
var custom_font_size: int = 0

var current_base_texture: Texture2D
var current_preview_font: FontFile
var current_image_path: String = ""

const CACHE_KEY := "bitmap_to_font"


func _ready() -> void:
	if not RPGDialogFunctions.there_are_any_dialog_open(): return
	close_requested.connect(queue_free)
	preview_line_edit.text_changed.connect(_on_preview_text_changed)
	_on_preview_text_changed(tr("Preview Text"))
	%CommandConrtainer.propagate_call("set_disabled", [true])
	_setup_toolbar()


func _apply_cached_dir(file_dialog: FileDialog) -> void:
	if FileCache.options.has(CACHE_KEY):
		var dir: String = FileCache.options[CACHE_KEY]
		
		if DirAccess.dir_exists_absolute(dir):
			file_dialog.current_dir = dir


func _cache_dialog_path(path: String) -> void:
	FileCache.options[CACHE_KEY] = path.get_base_dir()


func _setup_toolbar() -> void:
	selection_option.add_item("Seleccionar...")
	selection_option.add_separator()
	selection_option.add_item("Seleccionar Todo")
	selection_option.add_item("Seleccionar Letras")
	selection_option.add_item("Seleccionar Números")
	selection_option.add_item("Seleccionar Minúsculas")
	selection_option.add_item("Seleccionar Mayúsculas")
	selection_option.add_separator()
	selection_option.add_item("Deseleccionar Todo")
	selection_option.add_item("Deseleccionar Letras")
	selection_option.add_item("Deseleccionar Números")
	selection_option.add_item("Deseleccionar Minúsculas")
	selection_option.add_item("Deseleccionar Mayúsculas")
	
	selection_option.item_selected.connect(_on_selection_option_selected)
	
	align_x_spinbox.value_changed.connect(_on_align_x_changed)
	align_y_spinbox.value_changed.connect(_on_align_y_changed)
	space_width_spinbox.value_changed.connect(_on_space_width_changed)
	font_size_spinbox.value_changed.connect(_on_font_size_changed)
	
	auto_fill_button.pressed.connect(_on_auto_fill_sequence_pressed)
	
	save_button.pressed.connect(_on_save_button_pressed)
	
	import_button.pressed.connect(_on_import_button_pressed)
	
	clear_button.pressed.connect(_on_clear_button_pressed)


func _on_clear_button_pressed() -> void:
	for child in main_container.get_children():
		if child.has_method("set_character_silent"):
			child.set_character_silent("")
			
		child.kernings.clear()
		
		if child.has_method("set_selected"):
			child.set_selected(false)
			
		child.glyph_offset = Vector2.ZERO
		child.glyph_advance = 0.0
		
	_update_preview_font()
	_update_auto_fill_button_state()


func _on_import_button_pressed() -> void:
	if main_container.get_child_count() <= 0:
		_open_import_file_dialog()
		return
		
	var confirm := ConfirmationDialog.new()
	
	confirm.exclusive = false
	confirm.dialog_text = "Are you sure you want to import a bitmap font?\nCurrent progress will be lost."
	
	add_child(confirm)
	
	confirm.confirmed.connect(func():
		confirm.queue_free()
		call_deferred("_open_import_file_dialog")
	)
	
	confirm.canceled.connect(func():
		confirm.queue_free()
	)
	
	confirm.popup_centered()


func _open_import_file_dialog() -> void:
	var file_dialog := FileDialog.new()
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	file_dialog.add_filter("*.fnt", "BMFont")
	file_dialog.use_native_dialog = true
	
	_apply_cached_dir(file_dialog)
	
	add_child(file_dialog)
	
	file_dialog.file_selected.connect(func(path: String):
		_cache_dialog_path(path)
		_import_bitmap_font(path)
	)
	
	file_dialog.visibility_changed.connect(func():
		if not file_dialog.visible:
			file_dialog.queue_free()
	)
	
	file_dialog.popup_centered(Vector2i(800, 600))


func _import_bitmap_font(fnt_path: String) -> void:
	for child in main_container.get_children():
		child.queue_free()
		
	var lines := FileAccess.get_file_as_string(fnt_path).split("\n")
	
	var image_file := ""
	var chars: Array = []
	var kernings: Array = []
	var line_height := 0
	var base := 0
	
	for line in lines:
		line = line.strip_edges()
		
		if line.begins_with("common "):
			var regex_line := RegEx.new()
			regex_line.compile("lineHeight=(\\d+)")
			
			var line_result := regex_line.search(line)
			
			if line_result:
				line_height = line_result.get_string(1).to_int()
				
			var regex_base := RegEx.new()
			regex_base.compile("base=(\\d+)")
			
			var base_result := regex_base.search(line)
			
			if base_result:
				base = base_result.get_string(1).to_int()
				
		elif line.begins_with("page "):
			var regex := RegEx.new()
			regex.compile("file=\"([^\"]+)\"")
			
			var result := regex.search(line)
			
			if result:
				image_file = result.get_string(1)
				
		elif line.begins_with("char "):
			chars.append(_parse_bmfont_line(line))
			
		elif line.begins_with("kerning "):
			kernings.append(_parse_bmfont_line(line))
			
	if base <= 0:
		base = line_height
			
	if image_file.is_empty():
		return
		
	var image_path := fnt_path.get_base_dir() + "/" + image_file
	
	current_image_path = image_path
	
	var img := Image.load_from_file(image_path)
	
	if img == null or img.is_empty():
		return
		
	current_base_texture = ImageTexture.create_from_image(img)
	
	var char_map := {}
	
	for data in chars:
		if not data.has("id"):
			continue
			
		var char_id: int = int(data["id"])
		
		if char_id == 32:
			custom_space_width = float(data.get("xadvance", 0))
			continue
			
		var rect := Rect2i(
			Vector2i(
				int(data.get("x", 0)),
				int(data.get("y", 0))
			),
			Vector2i(
				int(data.get("width", 0)),
				int(data.get("height", 0))
			)
		)
		
		var letter_instance = LETTER.instantiate()
		letter_instance.name = "Letter #%s" % (main_container.get_child_count() + 1)
		
		main_container.add_child(letter_instance)
		
		var atlas := AtlasTexture.new()
		atlas.atlas = current_base_texture
		atlas.region = rect
		
		letter_instance.set_image(atlas)
		
		var char_str := String.chr(char_id)
		
		letter_instance.set_character_silent(char_str)
		
		letter_instance.glyph_offset = Vector2(
			float(data.get("xoffset", 0)),
			float(data.get("yoffset", 0)) - base + rect.size.y
		)
		
		letter_instance.glyph_advance = float(
			data.get("xadvance", rect.size.x)
		)
		
		letter_instance.char_changed.connect(_on_letter_char_changed)
		letter_instance.kerning_dialog_request.connect(_on_kerning_dialog_request)
		
		char_map[char_id] = letter_instance
		
	for kerning_data in kernings:
		var first: int = int(kerning_data.get("first", 0))
		var second: int = int(kerning_data.get("second", 0))
		var amount: int = int(kerning_data.get("amount", 0))
		
		if char_map.has(first):
			char_map[first].kernings[second] = amount
			
	custom_font_size = line_height
	
	space_width_spinbox.set_value_no_signal(custom_space_width)
	font_size_spinbox.set_value_no_signal(custom_font_size)
	
	%CommandConrtainer.propagate_call("set_disabled", [false])
	
	_update_preview_font()
	_update_auto_fill_button_state()
	
	if main_container.get_child_count() > 0:
		main_container.get_child(0).select.call_deferred()


func _parse_bmfont_line(line: String) -> Dictionary:
	var result := {}
	var regex := RegEx.new()
	
	regex.compile("(\\w+)=((\"[^\"]+\")|[^\\s]+)")
	
	var matches := regex.search_all(line)
	
	for match in matches:
		var key := match.get_string(1)
		var value := match.get_string(2).replace("\"", "")
		
		result[key] = value
		
	return result


func _on_auto_fill_sequence_pressed() -> void:
	var current_unicode: int = -1
	var updated: bool = false
	
	for child in main_container.get_children():
		if not child.current_character.is_empty():
			current_unicode = child.current_character.unicode_at(0)
		elif current_unicode != -1:
			current_unicode += 1
			if child.has_method("set_character_silent"):
				child.set_character_silent(String.chr(current_unicode))
				updated = true
				
	if updated:
		_on_preview_text_changed(preview_line_edit.text)
		_update_preview_font()
		_update_auto_fill_button_state()


func _on_selection_option_selected(index: int) -> void:
	if index == 0 or index == 1 or index == 7:
		return
		
	var is_selecting: bool = index < 7
	
	for child in main_container.get_children():
		if child.current_character.is_empty():
			continue
			
		var char_str: String = child.current_character
		var match_found: bool = false
		
		if index == 2 or index == 8:
			match_found = true
		elif index == 3 or index == 9:
			match_found = char_str.to_upper() != char_str.to_lower()
		elif index == 4 or index == 10:
			match_found = char_str.is_valid_int()
		elif index == 5 or index == 11:
			match_found = char_str == char_str.to_lower() and char_str != char_str.to_upper()
		elif index == 6 or index == 12:
			match_found = char_str == char_str.to_upper() and char_str != char_str.to_lower()
			
		if is_selecting:
			child.set_selected(match_found)
		else:
			if match_found:
				child.set_selected(false)
				
	selection_option.select(0)


func _on_align_x_changed(value: float) -> void:
	var updated: bool = false
	
	for child in main_container.get_children():
		if child.is_selected:
			child.glyph_offset.x = value
			updated = true
			
	if updated:
		_update_preview_font()


func _on_align_y_changed(value: float) -> void:
	var updated: bool = false
	
	for child in main_container.get_children():
		if child.is_selected:
			child.glyph_offset.y = value
			updated = true
			
	if updated:
		_update_preview_font()


func _on_space_width_changed(value: float) -> void:
	custom_space_width = value
	_update_preview_font()


func _on_font_size_changed(value: float) -> void:
	custom_font_size = int(value)
	_update_preview_font()


func _on_select_new_image_pressed() -> void:
	if main_container.get_child_count() > 0:
		var confirm := ConfirmationDialog.new()
		confirm.dialog_text = "Are you sure you want to load a new image?\nCurrent progress will be lost."
		add_child(confirm)
		
		confirm.confirmed.connect(_open_image_file_dialog)
		confirm.visibility_changed.connect(func():
			if not confirm.visible:
				confirm.queue_free()
		)
		
		confirm.popup_centered()
	else:
		_open_image_file_dialog()


func _open_image_file_dialog() -> void:
	var file_dialog := FileDialog.new()
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	file_dialog.add_filter("*.png", "PNG Images")
	file_dialog.use_native_dialog = true
	
	_apply_cached_dir(file_dialog)
	
	add_child(file_dialog)
	
	file_dialog.file_selected.connect(func(path: String):
		_cache_dialog_path(path)
		_process_image(path)
	)
	
	file_dialog.visibility_changed.connect(func():
		if not file_dialog.visible:
			file_dialog.queue_free()
	)
	
	file_dialog.popup_centered(Vector2i(800, 600))


func _process_image(path: String) -> void:
	for child in main_container.get_children():
		child.queue_free()
		main_container.remove_child(child)
		
	var img := Image.load_from_file(path)
	
	if img == null or img.is_empty():
		return
	
	current_image_path = path
	
	%CommandConrtainer.propagate_call("set_disabled", [false])
		
	current_base_texture = ImageTexture.create_from_image(img)
	var bitmap := BitMap.new()
	bitmap.create_from_image_alpha(img)
	
	var rect := Rect2i(Vector2i.ZERO, bitmap.get_size())
	var polygons := bitmap.opaque_to_polygons(rect)
	var bounding_boxes: Array[Dictionary] = []
	var max_h: int = 1
	
	for polygon in polygons:
		var bound := _get_bounding_box(polygon)
		max_h = max(max_h, int(bound.size.y))
		bounding_boxes.append({
			"polygon": polygon,
			"bound": bound
		})
		
	bounding_boxes.sort_custom(_sort_spatially)
	
	for data in bounding_boxes:
		var bound: Rect2i = data.bound
		var letter_instance = LETTER.instantiate()
		
		main_container.add_child(letter_instance)
		
		var atlas := AtlasTexture.new()
		atlas.atlas = current_base_texture
		atlas.region = bound
		
		if letter_instance.has_method("set_image"):
			letter_instance.set_image(atlas)
			
		letter_instance.char_changed.connect(_on_letter_char_changed)
		letter_instance.kerning_dialog_request.connect(_on_kerning_dialog_request)
		
	var default_space: float = max(4.0, max_h * 0.35)
	space_width_spinbox.set_value_no_signal(default_space)
	custom_space_width = default_space
	
	font_size_spinbox.set_value_no_signal(max_h)
	custom_font_size = max_h
	
	_update_auto_fill_button_state()
	
	if main_container.get_child_count() > 0:
		main_container.get_child(0).select.call_deferred()


func _sort_spatially(a: Dictionary, b: Dictionary) -> bool:
	var rect_a: Rect2i = a.bound
	var rect_b: Rect2i = b.bound
	var tolerance: int = max(10, int(rect_a.size.y * 0.5))
	
	if abs(rect_a.position.y - rect_b.position.y) <= tolerance:
		return rect_a.position.x < rect_b.position.x
		
	return rect_a.position.y < rect_b.position.y


func _get_bounding_box(polygon: PackedVector2Array) -> Rect2i:
	var min_point := Vector2i(polygon[0])
	var max_point := Vector2i(polygon[0])
	
	for point in polygon:
		min_point.x = min(min_point.x, int(point.x))
		min_point.y = min(min_point.y, int(point.y))
		max_point.x = max(max_point.x, int(point.x))
		max_point.y = max(max_point.y, int(point.y))
		
	return Rect2i(min_point, max_point - min_point)


func _on_letter_char_changed(index: int, char: String) -> void:
	_update_preview_font()
	_update_auto_fill_button_state()
	
	var next_index := index + 1
	
	if next_index < main_container.get_child_count():
		var next_letter = main_container.get_child(next_index)
		
		if next_letter.has_method("select"):
			next_letter.select()


func _update_auto_fill_button_state() -> void:
	var has_empty: bool = false
	
	for child in main_container.get_children():
		if child.current_character.is_empty():
			has_empty = true
			break
			
	if auto_fill_button != null:
		auto_fill_button.disabled = !has_empty


func _on_preview_text_changed(new_text: String) -> void:
	preview_label.text = new_text


func _update_preview_font() -> void:
	if current_base_texture == null:
		return
		
	var max_height: int = 1
	
	for child in main_container.get_children():
		if child.current_character.is_empty() or child.atlas_texture == null:
			continue
		max_height = max(max_height, int(child.atlas_texture.region.size.y))
		
	var font := FontFile.new()
	
	font.fixed_size = max_height
	font.allow_system_fallback = false
	font.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	
	var cache_v := Vector2i(max_height, 0)
	var cache_i := max_height
	
	font.set_cache_ascent(0, cache_i, max_height)
	font.set_cache_descent(0, cache_i, 0)
	font.set_texture_image(0, cache_v, 0, current_base_texture.get_image())
	
	var has_space := false
	
	for child in main_container.get_children():
		if child.current_character.is_empty() or child.atlas_texture == null:
			continue
			
		var char_id = child.current_character.unicode_at(0)
		if char_id == 32:
			has_space = true
			
		var rect: Rect2i = child.atlas_texture.region
		
		font.set_glyph_texture_idx(0, cache_v, char_id, 0)
		font.set_glyph_uv_rect(0, cache_v, char_id, rect)
		font.set_glyph_size(0, cache_v, char_id, rect.size)
		
		var offset_y = -rect.size.y + child.glyph_offset.y
		font.set_glyph_offset(0, cache_v, char_id, Vector2(child.glyph_offset.x, offset_y))
		
		var advance_x: float = child.glyph_advance if child.glyph_advance > 0.0 else rect.size.x + 1.0
		font.set_glyph_advance(0, cache_i, char_id, Vector2(advance_x, 0))
		
	if not has_space:
		var space_w: float = custom_space_width if custom_space_width > 0 else max(4.0, max_height * 0.35)
		font.set_glyph_advance(0, cache_i, 32, Vector2(space_w, 0))
		
	for child in main_container.get_children():
		if child.current_character.is_empty():
			continue
			
		var char_id = child.current_character.unicode_at(0)
		
		for next_char_id in child.kernings.keys():
			var kerning_value: int = child.kernings[next_char_id]
			font.set_kerning(0, cache_i, Vector2i(char_id, next_char_id), Vector2(kerning_value, 0))
			
	current_preview_font = font
	
	var display_size: int = custom_font_size if custom_font_size > 0 else max_height
	
	preview_label.texture_filter = Control.TEXTURE_FILTER_NEAREST
	preview_label.add_theme_font_size_override("font_size", display_size)
	preview_label.add_theme_font_override("font", current_preview_font)
	
	var force_update_text := preview_label.text
	preview_label.text = ""
	preview_label.text = force_update_text


func _on_kerning_dialog_request(character: String, letter_node: PanelContainer) -> void:
	var path = "res://addons/BitmapFontCreator/kerning_dialog.tscn"
	var kerning_window = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	
	var all_chars: Array[String] = []
	
	for child in main_container.get_children():
		if not child.current_character.is_empty():
			all_chars.append(child.current_character)
			
	kerning_window.set_data(character, letter_node, current_preview_font, all_chars)
	kerning_window.kerning_updated.connect(_update_preview_font)
	kerning_window.popup_centered()


func _on_save_button_pressed() -> void:
	if current_image_path.is_empty() or main_container.get_child_count() == 0:
		return
		
	var file_dialog := FileDialog.new()
	file_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	file_dialog.add_filter("*.fnt", "BMFont")
	file_dialog.use_native_dialog = true
	
	_apply_cached_dir(file_dialog)
	
	add_child(file_dialog)
	
	file_dialog.file_selected.connect(func(path: String):
		_cache_dialog_path(path)
		_on_save_file_selected(path)
	)
	
	file_dialog.visibility_changed.connect(func():
		if not file_dialog.visible:
			file_dialog.queue_free()
	)
	
	file_dialog.popup_centered(Vector2i(800, 600))



func _on_save_file_selected(path: String) -> void:
	var img_dest_path: String = path.get_base_dir() + "/" + path.get_file().get_basename() + ".png"
	
	if FileAccess.file_exists(path) or FileAccess.file_exists(img_dest_path):
		var confirm := ConfirmationDialog.new()
		confirm.dialog_text = "The font file or the image already exists in this directory.\nDo you want to overwrite them?"
		add_child(confirm)
		
		confirm.confirmed.connect(func():
			_save_font_to_disk(path, img_dest_path)
		)
		confirm.visibility_changed.connect(func():
			if not confirm.visible:
				confirm.queue_free()
		)
		
		confirm.popup_centered()
	else:
		_save_font_to_disk(path, img_dest_path)



func _save_font_to_disk(fnt_path: String, img_path: String) -> void:
	DirAccess.copy_absolute(current_image_path, img_path)
	
	var font_name: String = fnt_path.get_file().get_basename()
	var img_filename: String = img_path.get_file()
	
	var max_height: int = 1
	var valid_children: Array[PanelContainer] = []
	var kernings_count: int = 0
	var has_space: bool = false
	var texture_size: Vector2i = current_base_texture.get_size()
	
	for child in main_container.get_children():
		if child.current_character.is_empty() or child.atlas_texture == null:
			continue
			
		max_height = max(max_height, int(child.atlas_texture.region.size.y))
		valid_children.append(child)
		kernings_count += child.kernings.size()
		
		if child.current_character.unicode_at(0) == 32:
			has_space = true
			
	var line_height: int = custom_font_size if custom_font_size > 0 else max_height
	var base: int = max_height
	var total_chars: int = valid_children.size()
	
	if not has_space:
		total_chars += 1
		
	var font_data: String = ""
	
	font_data += "info face=\"%s\" size=%d bold=0 italic=0 charset=\"\" unicode=1 stretchH=100 smooth=0 aa=0 padding=0,0,0,0 spacing=1,1\n" % [font_name, line_height]
	font_data += "common lineHeight=%d base=%d scaleW=%d scaleH=%d pages=1 packed=0\n" % [
		line_height,
		base,
		texture_size.x,
		texture_size.y
	]
	font_data += "page id=0 file=\"%s\"\n" % img_filename
	font_data += "chars count=%d\n" % total_chars
	
	for child in valid_children:
		var char_id: int = child.current_character.unicode_at(0)
		var rect: Rect2i = child.atlas_texture.region
		
		var xoffset: int = int(child.glyph_offset.x)
		var yoffset: int = int(base - rect.size.y + child.glyph_offset.y)
		
		var xadvance: int = int(
			child.glyph_advance
			if child.glyph_advance > 0.0
			else rect.size.x + 1.0
		)
		
		font_data += "char id=%d x=%d y=%d width=%d height=%d xoffset=%d yoffset=%d xadvance=%d page=0 chnl=15\n" % [
			char_id,
			rect.position.x,
			rect.position.y,
			rect.size.x,
			rect.size.y,
			xoffset,
			yoffset,
			xadvance
		]
		
	if not has_space:
		var space_w: int = int(
			custom_space_width
			if custom_space_width > 0
			else max(4.0, max_height * 0.35)
		)
		
		font_data += "char id=32 x=0 y=0 width=0 height=0 xoffset=0 yoffset=%d xadvance=%d page=0 chnl=15\n" % [
			base,
			space_w
		]
		
	if kernings_count > 0:
		font_data += "kernings count=%d\n" % kernings_count
		
		for child in valid_children:
			var char_id: int = child.current_character.unicode_at(0)
			
			for next_char_id in child.kernings.keys():
				var amount: int = child.kernings[next_char_id]
				
				font_data += "kerning first=%d second=%d amount=%d\n" % [
					char_id,
					next_char_id,
					amount
				]
				
	var file := FileAccess.open(fnt_path, FileAccess.WRITE)
	
	if file:
		file.store_string(font_data)
		file.close()
		
		var accept := AcceptDialog.new()
		accept.dialog_text = "Font saved successfully!"
		add_child(accept)
		
		accept.popup_centered()
		accept.visibility_changed.connect(
			func():
				if not accept.visible:
					accept.queue_free()
		)
	else:
		push_error("BitmapFontCreator: Failed to save font to " + fnt_path)


func _on_visual_editor_button_pressed() -> void:
	if current_base_texture == null:
		return
		
	var path = "res://addons/BitmapFontCreator/edit_glyph_rectangles_dialog.tscn"
	var editor_window = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	
	editor_window.set_data(current_base_texture, main_container.get_children(), LETTER, main_container)
	editor_window.rects_changed.connect(_update_preview_font)
	
	editor_window.new_letter_created.connect(func(node: PanelContainer):
		if not node.char_changed.is_connected(_on_letter_char_changed):
			node.char_changed.connect(_on_letter_char_changed)
			
		if not node.kerning_dialog_request.is_connected(_on_kerning_dialog_request):
			node.kerning_dialog_request.connect(_on_kerning_dialog_request)
	)
	
	editor_window.popup_centered(Vector2i(1000, 700))


func _on_cancel_button_pressed() -> void:
	queue_free()
