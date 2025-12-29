extends WindowBase


@export var current_buttons: Array[SimpleFocusableControl] = []

var current_options: RPGGameOptions
var current_button_selected: int = 0
var options_changed: bool = false


func _ready() -> void:
	GameManager.manage_cursor(self)
	
	fill_locales()
	if not GameManager.current_game_options:
		load_options()
	else:
		get_options_from_game_manager()
	
	GameManager.set_text_config(self)
	
	setup_texts_and_buttons()
	
	tree_exiting.connect(
		func():
			if options_changed:
				var save_path = "user://game_options.res"
				ResourceSaver.save(current_options, save_path)
	)
	
	start()


func fill_locales() -> void:
	var loaded_locales = TranslationServer.get_loaded_locales()
	if not "en" in loaded_locales:
		loaded_locales.append("en")
	
	%LanguageSelector.items.clear()
	for locale in loaded_locales:
		var item = SimpleItem.new(TranslationServer.get_language_name(locale), locale)
		%LanguageSelector.items.append(item)
	
	%LanguageSelector.update()


func load_options() -> void:
	var path = "user://game_options.res"
	if ResourceLoader.exists(path):
		current_options = load(path)
		options_changed = false
	else:
		current_options = RPGGameOptions.new()
		options_changed = true
	
	set_initial_values()
	
	current_options.changed.connect(
		func():
			options_changed = true
			GameManager.set_options(current_options)
	)
	
	current_options.changed.emit()


func get_options_from_game_manager() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	
	current_options = GameManager.current_game_options
	
	set_initial_values()
	
	current_options.changed.connect(
		func():
			options_changed = true
			GameManager.set_options(current_options)
	)
	
	current_options.changed.emit()
	


func set_initial_values() -> void:
	%FullScreen.set_value(current_options.fullscreen)
	%VSync.set_value(current_options.vsync)
	%FpsSelector.set_value(current_options.max_fps)
	%Brightness.set_value(current_options.brightness)
	%TextSpeed.set_value(current_options.text_speed)
	%MasterVolume.set_value(remap(current_options.sound_master, 0.0, 1.0, -80.0, 0.0))
	%MusicVolume.set_value(remap(current_options.sound_music, 0.0, 1.0, -80.0, 0.0))
	%SeVolume.set_value(remap(current_options.sound_fx, 0.0, 1.0, -80.0, 0.0))
	%MeVolume.set_value(remap(current_options.sound_ambient, 0.0, 1.0, -80.0, 0.0))
	%LanguageSelector.set_value(current_options.language)
	


func setup_texts_and_buttons() -> void:
	var ids = [
		"Options Title", "Options Screen Title",
		"Options Sounds Title", "Options Language Title"
	]
	var titles = [%OptionsTitle, %SectionNameScreen, %SectionNameSounds, %SectionNameLanguage]
	for i in titles.size():
		titles[i].text = "  " + RPGSYSTEM.database.terms.search_message(ids[i]) + "  "
	
	ids = [
		"Fullscreen", "Vsync", "Max_fps", "Brightness", "Text Speed", "Master Volume",
		"Music Volume", "Sound Fx Volume","Ambient Volume", "Language", "Exit"
	]

	for i in current_buttons.size():
		var button = get_node(current_buttons[i].control)
		button.selected.connect(
			func(_arg = null):
				var tooltip = current_buttons[i].tooltip
				%TooltipLabel.text = RPGSYSTEM.database.terms.search_message(tooltip)
		)
		button.mouse_entered.connect(
			func():
				var tooltip = current_buttons[i].tooltip
				%TooltipLabel.text = RPGSYSTEM.database.terms.search_message(tooltip)
		)
		button.focus_entered.connect(
			func():
				current_button_selected = i
				if current_button_selected != current_buttons.size() - 1:
					_config_hand_in_other_button()
					if not busy:
						GameManager.play_fx("cursor")
				else:
					_config_hand_in_back_button()
					
		)
		var label = button.get_parent().get_child(0)
		if label is Label:
			label.text = RPGSYSTEM.database.terms.search_message("Options " + ids[i]) 
		
	
	%MainContainer.scroll_vertical = 0
	current_button_selected = 0


func start() -> void:
	var node3 = %BackButton
	
	node3.visible = false
	node3.modulate.a = 0
	
	super()
	
	main_tween.tween_callback(node3.set.bind("visible", true))
	main_tween.tween_property(node3, "modulate:a", 1.0, 0.8)
	main_tween.tween_callback(
		func():
			_config_hand_in_other_button()
	)
	
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	
	%MainContainer.get_v_scroll_bar().value = 0
	get_node(current_buttons[0].control).select()


func end() -> void:
	super()
	
	%BackButton.visible = false
	
	GameManager.hide_cursor(false, self)


func _process(_delta: float) -> void:
	if GameManager.get_cursor_manipulator() == scene_manipulator:
		_check_button_pressed()


func _config_hand_in_back_button() -> void:
	var manipulator = scene_manipulator
	GameManager.set_cursor_manipulator(manipulator)
	GameManager.set_hand_position(MainHandCursor.HandPosition.UP, manipulator)
	GameManager.set_cursor_offset(Vector2(0, 2), manipulator)
	GameManager.set_confin_area(Rect2(), manipulator)
	GameManager.force_show_cursor()


func _config_hand_in_other_button() -> void:
	var manipulator = scene_manipulator
	GameManager.set_cursor_manipulator(manipulator)
	GameManager.set_hand_position(MainHandCursor.HandPosition.LEFT, manipulator)
	GameManager.set_cursor_offset(Vector2(0, 0), manipulator)
	GameManager.set_confin_area(Rect2(), manipulator)
	GameManager.force_show_cursor()


func _check_button_pressed() -> void:
	if busy: return
	
	if not %BackButton.has_focus():
		_config_hand_in_other_button()
	else:
		_config_hand_in_back_button()
	
	var direction = ControllerManager.get_pressed_direction()
	if direction:
		match direction:
			"up":
				_move_to_button(-1)
			"down":
				_move_to_button(1)
	elif Input.is_action_pressed("FullScreen"):
		_on_full_screen_pressed()
		%FullScreen.set_pressed(current_options.fullscreen)
		get_viewport().set_input_as_handled()
	elif ControllerManager.is_cancel_pressed():
		ControllerManager.remove_last_action_registered()
		get_viewport().set_input_as_handled()
		%BackButton.select(true)
		%BackButton._on_pressed()


func _move_to_button(direction: int) -> void:
	
	current_button_selected = wrapi(current_button_selected + direction, 0, current_buttons.size())
	GameManager.set_hand_position(current_buttons[current_button_selected].cursor_position)
	
	var selected_button = get_node(current_buttons[current_button_selected].control)
	await get_tree().process_frame
	selected_button.select()


func _on_full_screen_pressed() -> void:
	current_options.fullscreen = !current_options.fullscreen
	current_options.changed.emit()


func _on_v_sync_pressed() -> void:
	current_options.vsync = !current_options.vsync
	current_options.changed.emit()


func _on_brightness_changed(value: float) -> void:
	%BrightnessLabel.text = "x %.2f" % value
	current_options.brightness = value
	current_options.changed.emit()


func _on_text_speed_changed(value: float) -> void:
	%TextSpeedLabel.text = "x %.2f" % value
	current_options.text_speed = value
	current_options.changed.emit()


func _on_master_volume_changed(value: float) -> void:
	%MasterVolumeLabel.text = "%.1f%%" % remap(value, -80.0, 0.0, 0.0, 100.0)
	current_options.sound_master = remap(value, -80.0, 0.0, 0.0, 1.0)
	current_options.changed.emit()


func _on_music_volume_changed(value: float) -> void:
	%MusicVolumeLabel.text = "%.1f%%" % remap(value, -80.0, 0.0, 0.0, 100.0)
	current_options.sound_music = remap(value, -80.0, 0.0, 0.0, 1.0)
	current_options.changed.emit()


func _on_se_volume_changed(value: float) -> void:
	%SeVolumeLabel.text = "%.1f%%" % remap(value, -80.0, 0.0, 0.0, 100.0)
	current_options.sound_fx = remap(value, -80.0, 0.0, 0.0, 1.0)
	current_options.changed.emit()


func _on_me_volume_changed(value: float) -> void:
	%MeVolumeLabel.text = "%.1f%%" % remap(value, -80.0, 0.0, 0.0, 100.0)
	current_options.sound_ambient = remap(value, -80.0, 0.0, 0.0, 1.0)
	current_options.changed.emit()


func _on_fps_selector_item_changed(value: Variant) -> void:
	current_options.max_fps = int(value)
	current_options.changed.emit()


func _on_language_selector_item_changed(value: Variant) -> void:
	current_options.language = str(value)
	current_options.changed.emit()


func _on_back_button_begin_click() -> void:
	if busy: return
	busy = true
	var t = create_tween()
	t.set_parallel(true)
	t.tween_property(%Contents, "modulate:a", 0.75, 0.5)
	t.tween_property(%Contents, "scale", Vector2(1.04, 1.01), 0.5).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)


func _on_back_button_end_click() -> void:
	end()
