class_name OptionsManager
extends Node


var sound_volume_mapping: VolumeMapping


func _ready() -> void:
	sound_volume_mapping = VolumeMapping.new()


func set_options(options: RPGGameOptions) -> void:
	GameManager.current_game_options = options
	
	TranslationServer.set_locale(options.language)
	Engine.set_max_fps(options.max_fps)
	
	if sound_volume_mapping:
		sound_volume_mapping.set_volume_from_slider(AudioServer.get_bus_index("Master"), options.sound_master)
		sound_volume_mapping.set_volume_from_slider(AudioServer.get_bus_index("BGM"), options.sound_music)
		sound_volume_mapping.set_volume_from_slider(AudioServer.get_bus_index("SE"), options.sound_fx)
		sound_volume_mapping.set_volume_from_slider(AudioServer.get_bus_index("Ambient"), options.sound_ambient)
	
	DisplayServer.window_set_vsync_mode(
		DisplayServer.VSYNC_ENABLED if options.vsync
		else DisplayServer.VSYNC_DISABLED
	)
	
	if DisplayServer.window_get_mode() != (DisplayServer.WindowMode.WINDOW_MODE_FULLSCREEN if options.fullscreen else DisplayServer.WindowMode.WINDOW_MODE_WINDOWED):
		if not Engine.is_embedded_in_editor():
			DisplayServer.window_set_mode(
				DisplayServer.WindowMode.WINDOW_MODE_FULLSCREEN if options.fullscreen
				else DisplayServer.WindowMode.WINDOW_MODE_WINDOWED
			)
	
	if GameManager.main_scene:
		GameManager.main_scene.set_canvas_modulate_color(GameManager.main_scene.get_canvas_modulate_color())
	if GameManager.starting_menu:
		GameManager.starting_menu.set_brightness()


func save_options() -> void:
	if GameManager.current_game_options:
		var save_path = "user://game_options.res"
		ResourceSaver.save(GameManager.current_game_options, save_path)


func toggle_fullscreen() -> void:
	if not Engine.is_embedded_in_editor():
		if DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_WINDOWED:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			if GameManager.current_game_options:
				GameManager.current_game_options.fullscreen = false
				save_options()
		else:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
			if GameManager.current_game_options:
				GameManager.current_game_options.fullscreen = true
				save_options()
	else:
		printerr("Cannot maximize the screen when running the game embedded in the editor")
