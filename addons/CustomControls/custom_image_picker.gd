@tool
extends Control

func get_class(): return "CustomimagePicker"

@export var clipboard_key = "image_with_region"
@export var custom_copy_and_paste_enabled: bool = false


@export var expand_mode: TextureRect.ExpandMode = TextureRect.ExpandMode.EXPAND_IGNORE_SIZE
@export var stretch_mode: TextureRect.StretchMode = TextureRect.StretchMode.STRETCH_KEEP_ASPECT_CENTERED


signal clicked()
signal remove_requested()
signal paste_requested(icon: String, region: Rect2)
signal custom_copy(node: Control, clipboard_key: String)
signal custom_paste(node: Control, clipboard_key: String)



var disabled: bool = false

func _ready() -> void:
	%MainImage.stretch_mode = stretch_mode
	%MainImage.expand_mode = expand_mode
	mouse_entered.connect(show_cursor.bind(true))
	mouse_exited.connect(show_cursor.bind(false))
	gui_input.connect(_on_gui_input)


func set_blend_color(color: Color) -> void:
	%MainImage.modulate = color


func set_icon(path: String, rect: Rect2 = Rect2()) -> void:
	var preview_path = path.get_basename() + "_preview.png"
	var preview_found = false
	if ResourceLoader.exists(preview_path):
		var res = ResourceLoader.load(preview_path)
		if res is Texture:
			set_main_texture(res, rect)
			preview_found = true
			
	if !preview_found and ResourceLoader.exists(path):
		var res = ResourceLoader.load(path)
		if res is PackedScene:
			var ins = res.instantiate()
			if ins is TextureRect:
				set_main_texture(ins.texture, rect)
			else:
				%MainImage.texture = null
			ins.queue_free()
		elif res is Texture:
			set_main_texture(res, rect)
		else:
			%MainImage.texture = null
	elif !preview_found:
		%MainImage.texture = null


func clear() -> void:
	set_icon("")


func set_main_texture(texture, region) -> void:
	%MainImage.texture = AtlasTexture.new()
	%MainImage.texture.atlas = texture
	%MainImage.texture.region = region
	if texture is SpritesetAnimationTexture:
		#texture._init()
		if not texture.frame_changed.is_connected(_update_main_image_texture_from_animated_texture):
			texture.frame_changed.connect(_update_main_image_texture_from_animated_texture.bind(texture), CONNECT_DEFERRED)


func _update_main_image_texture_from_animated_texture(texture: SpritesetAnimationTexture) -> void:
	if %MainImage.texture:
		%MainImage.texture.changed.emit()
	else:
		texture.frame_changed.disconnect(_update_main_image_texture_from_animated_texture)


func get_main_texture() -> Texture:
	return %MainImage.texture


func show_cursor(value: bool) -> void:
	if !disabled:
		%Cursor.set_visible(value)
	else:
		%Cursor.set_visible(false)


func _on_gui_input(event: InputEvent) -> void:
	if disabled: return
	
	if event is InputEventMouseButton and event.is_pressed():
		if event.button_index == MOUSE_BUTTON_LEFT:
			clicked.emit()
		elif event.button_index == MOUSE_BUTTON_MIDDLE:
			remove_requested.emit()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			var condition1 = not %MainImage.texture is AtlasTexture or %MainImage.texture.atlas == null
			var condition2 = not StaticEditorVars.CLIPBOARD.has(clipboard_key)
			%MainPopup.set_item_disabled(0, condition1)
			%MainPopup.set_item_disabled(2, condition1)
			%MainPopup.set_item_disabled(5, condition1)
			%MainPopup.set_item_disabled(3, condition2)
			
			if condition1 and condition2:
				return
				
			%MainPopup.position = Vector2i(
				Vector2(get_viewport().position) + 
				get_global_position() +
				get_local_mouse_position() -
				Vector2(%MainPopup.size.x * 0.5, 0)
			)
			%MainPopup.popup()


func set_disabled(value: bool) -> void:
	disabled = value
	if value:
		set_process_mode(Node.PROCESS_MODE_DISABLED)
		modulate.a = 0.6
	else:
		set_process_mode(Node.PROCESS_MODE_INHERIT)
		modulate.a = 1.0
	set_process_input(!value)


func _on_main_popup_index_pressed(index: int) -> void:
	if index == 0: clicked.emit() # change image
	elif index == 2: copy_image() # copy image
	elif index == 3: paste_image() # paste image
	elif index == 5: remove_requested.emit() # remove image


func copy_image() -> void:
	if custom_copy_and_paste_enabled:
		custom_copy.emit(self, clipboard_key)
	else:
		if %MainImage.texture is AtlasTexture:
			if %MainImage.texture.atlas:
				var clipboard = StaticEditorVars.CLIPBOARD
				clipboard[clipboard_key] = {"icon": %MainImage.texture.atlas, "region": %MainImage.texture.region}


func paste_image() -> void:
	if custom_copy_and_paste_enabled:
		custom_paste.emit(self, clipboard_key)
	else:
		var clipboard = StaticEditorVars.CLIPBOARD
		if clipboard and clipboard_key in clipboard:
			if "icon" in clipboard[clipboard_key] and "region" in clipboard[clipboard_key]:
				paste_requested.emit(clipboard[clipboard_key].icon.get_path(), clipboard[clipboard_key].region)
			elif "path" in clipboard[clipboard_key] and clipboard[clipboard_key].path is RPGIcon:
				paste_requested.emit(clipboard[clipboard_key].path.path, clipboard[clipboard_key].path.region)
