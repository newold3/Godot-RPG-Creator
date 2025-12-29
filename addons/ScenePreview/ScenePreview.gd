@tool
extends EditorPlugin

const PREVIEW_SIZE := 400  # Godot's default preview size
const UPDATE_INTERVAL := 0.5

var preview_button: Button
var preview_window: Window
var preview_texture_rect: TextureRect
var update_timer: Timer
var saving_scene: Node2D

func _enter_tree() -> void:
	_setup_saving_scene()
	_setup_preview_button()
	_setup_preview_window()
	_setup_update_timer()


func _exit_tree() -> void:
	update_timer.stop()
	preview_button.queue_free()
	preview_window.queue_free()
	saving_scene.queue_free()


func _setup_saving_scene() -> void:
	saving_scene = preload("res://addons/ScenePreview/saving_preview.tscn").instantiate()
	add_child(saving_scene)


func _setup_preview_button() -> void:
	preview_button = Button.new()
	preview_button.toggle_mode = true
	preview_button.text = "Scene Preview"
	preview_button.pressed.connect(_on_preview_button_pressed)
	preview_button.theme = load("res://addons/CustomControls/Resources/Themes/editor_buitton_themes.tres")
	preview_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	preview_button.tooltip_text = "[title]Scene Preview[/title]\nDisplays a live preview of the current scene."
	
	add_control_to_container(EditorPlugin.CONTAINER_CANVAS_EDITOR_MENU, preview_button)
	CustomTooltipManager.plugin_replace_all_tooltips_with_custom(preview_button)


func _setup_preview_window() -> void:
	preview_window = Window.new()
	preview_window.title = "Scene Preview"
	preview_window.size = Vector2(PREVIEW_SIZE, PREVIEW_SIZE)
	preview_window.visible = false
	preview_window.unresizable = true
	preview_window.always_on_top = true
	preview_window.close_requested.connect(_on_preview_window_close)
	preview_window.mouse_entered.connect(func(): preview_window.grab_focus())
	preview_window.mouse_exited.connect(
		func():
			if preview_window.has_focus():
				get_viewport().grab_focus()
	)
	
	# Position window bottom right
	var screen_size := DisplayServer.screen_get_size()
	preview_window.position = Vector2(
		screen_size.x - preview_window.size.x - 20,
		screen_size.y - preview_window.size.y - 100
	)
	
	preview_texture_rect = TextureRect.new()
	preview_texture_rect.custom_minimum_size = preview_window.size
	preview_texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview_texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview_texture_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	
	preview_window.add_child(preview_texture_rect)
	add_child(preview_window)
	
	var button = preload("res://addons/CustomControls/custom_button.tscn").instantiate()
	button.text = tr("Generate Preview")
	button.name = tr("SavePreview")
	button.tooltip_text = tr("Generate a preview image with the same name as the scene, plus \"_preview\", and save it in the same folder as the scene")
	button.pressed.connect(_save_preview)
	preview_window.add_child(button)
	button.position = preview_window.size - Vector2i(button.size) - Vector2i(10, 10)
	CustomTooltipManager.replace_all_tooltips_with_custom(button)


func _setup_update_timer() -> void:
	update_timer = Timer.new()
	update_timer.wait_time = UPDATE_INTERVAL
	update_timer.one_shot = true
	update_timer.timeout.connect(_update_preview)
	preview_window.add_child(update_timer)


func _on_preview_button_pressed() -> void:
	if preview_button.button_pressed:
		_update_preview()
		preview_window.visible = true
		get_viewport().grab_focus()
		update_timer.start()
	else:
		update_timer.stop()
		preview_window.visible = false


func _on_preview_window_close() -> void:
	preview_button.button_pressed = false
	update_timer.stop()
	preview_window.visible = false


func _update_preview() -> void:
	var viewport := get_editor_interface().get_editor_viewport_2d()
	if not viewport:
		return
		
	var viewport_texture := viewport.get_texture()
	var preview_image := viewport_texture.get_image()
	var x = viewport_texture.get_width() * 0.5 - preview_window.size.x * 0.5
	var y = viewport_texture.get_height() * 0.5 - preview_window.size.y * 0.5
	var region = preview_image.get_region(Rect2(Vector2(x, y), preview_window.size))
	preview_texture_rect.texture = ImageTexture.create_from_image(region)
	preview_texture_rect.size = preview_window.size
	
	update_timer.start()


func _save_preview() -> void:
	if preview_texture_rect.texture:
		var scene_path = get_editor_interface().get_edited_scene_root().scene_file_path
		if scene_path:
			saving_scene.save_texture(scene_path, preview_texture_rect.texture)
