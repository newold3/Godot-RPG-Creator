@tool
extends MarginContainer


var busy: bool = false
var current_path: String = ""

@onready var palette_conversor: PaletteConverter = %PaletteConverter


func _ready() -> void:
	_fill_conversion_mode_options()

	palette_conversor.conversion_completed.connect(_update_converted_image)
	palette_conversor.conversion_progress.connect(_update_progress)
	
	%BrowseContainer.dropped_image.connect(_on_image_dropped)
	%MainTextureContainer.dropped_image.connect(_on_image_dropped)
	
	%BrowseContainer.visible = true
	%MainTextureContainer.visible = false
	%ProgressConversorContainer.visible = false
	%ConvertedTextureContainer.visible = false
	%ProgressConversorContainer.visible = false


func enable_plugin_mode() -> void:
	CustomTooltipManager.replace_all_tooltips_with_custom(self)


func _fill_conversion_mode_options() -> void:
	var node = %ConversionMode
	node.clear()
	
	var options = PaletteConverter.DistanceMethod.keys()
	var selected_index = 0
	
	for i in options.size():
		var key = options[i]
		node.add_item(key)
		if key == "LAB":
			selected_index = i
	
	node.select(selected_index)


func _on_image_dropped(tex: Texture) -> void:
	current_path = tex.get_path()
	%MainTexture.texture = tex.duplicate()
	var image_size = tex.get_image().get_size()
	var container_size = Vector2i(%MainTextureContainer.size) - Vector2i(
		%MainTextureContainer.get("theme_override_constants/margin_left") + %MainTextureContainer.get("theme_override_constants/margin_right"),
		%MainTextureContainer.get("theme_override_constants/margin_top") + %MainTextureContainer.get("theme_override_constants/margin_bottom")
	)
	if image_size < container_size:
		%MainTexture.custom_minimum_size = image_size
	else:
		%MainTexture.custom_minimum_size = container_size
	%MainTexture.size = %MainTexture.custom_minimum_size
	
	%BrowseContainer.visible = false
	%MainTextureContainer.visible = true
	%ConvertedTexture.texture = null
	%ProgressConversorContainer.visible = false
	%ConvertedTextureContainer.visible = false
	
	%SavePath.text = current_path.get_basename() + ".png"


func _update_converted_image(image: Image) -> void:
	var tex = ImageTexture.create_from_image(image)
	%ConvertedTexture.texture = tex
	var image_size = image.get_size()
	var container_size = Vector2i(%ConvertedTextureContainer.size) - Vector2i(
		%ConvertedTextureContainer.get("theme_override_constants/margin_left") + %ConvertedTextureContainer.get("theme_override_constants/margin_right"),
		%ConvertedTextureContainer.get("theme_override_constants/margin_top") + %ConvertedTextureContainer.get("theme_override_constants/margin_bottom")
	)
	if image_size < container_size:
		%ConvertedTexture.custom_minimum_size = image_size
	else:
		%ConvertedTexture.custom_minimum_size = container_size
	%ConvertedTexture.size = %ConvertedTexture.custom_minimum_size
	
	%BrowseContainer.visible = false
	%MainTextureContainer.visible = true
	
	%ConvertedTextureContainer.visible = true
	%ProgressConversorContainer.visible = false
	
	busy = false
	%ConversionMode.set_disabled(false)


func _update_progress(value: float) -> void:
	%ProgressBar.value = value


func open_file_dialog() -> Window:
	var path = "res://addons/CustomControls/Dialogs/select_file_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	dialog.destroy_on_hide = true
	await get_tree().process_frame
	
	dialog.set_dialog_mode(0)
	
	return dialog


func open_image_dialog(target_callable: Callable, default_path: String = "", filter: String = "images") -> void:
	var dialog = await open_file_dialog()
	
	dialog.target_callable = target_callable
	dialog.set_file_selected(default_path)
	
	dialog.fill_files(filter)


func _on_select_image_button_pressed() -> void:
	if not busy:
		open_image_dialog(_select_image)


func _select_image(path: String) -> void:
	var tex = load(path)
	_on_image_dropped(tex)


func _on_convert_palette_button_pressed() -> void:
	if not busy:
		if %MainTexture.texture:
			busy = true
			%ConvertedTextureContainer.visible = false
			%ProgressConversorContainer.visible = true
			%ProgressBar.value = 0.0
			%ConversionMode.set_disabled(true)
			palette_conversor.clear()
			palette_conversor.convert_image_async(%MainTexture.texture)


func _on_conversion_mode_item_selected(index: int) -> void:
	if not busy:
		palette_conversor.set_distance_method(index)


func _on_save_image_button_pressed() -> void:
	if %ConvertedTexture.texture:
		var file_path = %SavePath.get_text()
		if ResourceLoader.exists(file_path):
			_confirm_save()
		else:
			_save_image()


func _confirm_save() -> void:
	var file_path = %SavePath.get_text()
	var path = "res://addons/CustomControls/Dialogs/confirm_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	Color(1.0, 0.736, 0.99)
	dialog.title = tr("File overwrite")
	dialog.set_text("File already exists, overwrite\n\n\"[color=#ffbcfc]%s[/color]\" ?" % file_path)
	dialog.OK.connect(_save_image)


func _save_image() -> void:
	if %ConvertedTexture.texture:
		var file_path: String  = %SavePath.get_text()
		var image: Image = %ConvertedTexture.texture.get_image()
		image.save_png(file_path)
		
		var editor_fs = EditorInterface.get_resource_filesystem()
		editor_fs.scan()
		editor_fs.scan_sources()


func _on_restore_image_button_pressed() -> void:
	if %MainTexture.texture:
		var file_path: String  = current_path
		var image: Image = %MainTexture.texture.get_image()
		var extension: String = file_path.get_extension().to_lower()
		var err := OK

		match extension:
			"png":
				err = image.save_png(file_path)
			"jpg", "jpeg":
				err = image.save_jpg(file_path)
			"exr":
				err = image.save_exr(file_path)
			"webp":
				err = image.save_webp(file_path)
			_:
				push_error("Unsupported file format: %s. using png format" % extension)
				file_path = file_path.get_basename() + ".png"
				err = image.save_png(file_path)
				
		var editor_fs = EditorInterface.get_resource_filesystem()
		editor_fs.scan()
		editor_fs.scan_sources()
