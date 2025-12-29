extends MarginContainer

@export var scene_manipulator:  String = ""
@export var current_buttons: Array[SimpleFocusableControl] = []
@export var back_button: Control : set = _add_back_button
@export var tooltip_label: Control
@export var clip_container: Control
@export var early_tree_exited_timer: float = 0.15
@export var fx_preview: AudioStream

var current_options: RPGGameOptions
var current_button_selected: int = 0 : set = change_current_button_selected
var options_changed: bool = false
var fx_delay: float = 0.0
var busy: bool = false

signal starting_end()
signal end()
signal early_tree_exited()


func _ready() -> void:
	busy = true
	GameManager.set_fx_busy(true)
	_fill_locales()
	if not GameManager.current_game_options:
		_load_options()
	else:
		_get_options_from_game_manager()
	
	_setup_texts_and_buttons()
	
	tree_exiting.connect(
		func():
			if options_changed:
				var save_path = "user://game_options.res"
				ResourceSaver.save(current_options, save_path)
	)
	
	_config_hand_in_other_button()
	
	GameManager.force_show_cursor()

	await get_tree().process_frame
	%FullScreen.select()
	GameManager.force_hand_position_over_node(scene_manipulator)
	
	busy = false
	GameManager.set_fx_busy(false)


func change_current_button_selected(value: int) -> void:
	current_button_selected = value
	if current_button_selected >= 0 and current_buttons.size() > current_button_selected:
		var tooltip = current_buttons[current_button_selected].tooltip
		%TooltipLabel.text = RPGSYSTEM.database.terms.search_message(tooltip)
	else:
		%TooltipLabel.text = ""

func _config_hand_in_back_button() -> void:
	var manipulator = scene_manipulator
	GameManager.set_cursor_manipulator(manipulator)
	GameManager.set_hand_position(MainHandCursor.HandPosition.UP, manipulator)
	GameManager.set_cursor_offset(Vector2(0, 2), manipulator)
	GameManager.set_confin_area(Rect2(), manipulator)


func _config_hand_in_other_button() -> void:
	var manipulator = scene_manipulator
	GameManager.set_cursor_manipulator(manipulator)
	if not current_button_selected in [2, 9]:
		GameManager.set_hand_position(MainHandCursor.HandPosition.LEFT, manipulator)
	GameManager.set_cursor_offset(Vector2(0, 0), manipulator)
	if clip_container:
		GameManager.set_confin_area(clip_container.get_global_rect(), manipulator)
	else:
		GameManager.set_confin_area(Rect2(), manipulator)


func _fill_locales() -> void:
	var loaded_locales = TranslationServer.get_loaded_locales()
	if not "en" in loaded_locales:
		loaded_locales.append("en")
	
	%LanguageSelector.items.clear()
	for locale in loaded_locales:
		var item = SimpleItem.new(TranslationServer.get_language_name(locale), locale)
		%LanguageSelector.items.append(item)
	
	%LanguageSelector.update()


func _load_options() -> void:
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


func _get_options_from_game_manager() -> void:
	#await get_tree().process_frame
	#await get_tree().process_frame
	#await get_tree().process_frame
	
	current_options = GameManager.current_game_options
	
	set_initial_values()
	
	current_options.changed.connect(
		func():
			options_changed = true
			GameManager.set_options(current_options)
	)
	
	current_options.changed.emit()


func _setup_texts_and_buttons() -> void:
	var ids = [
		"Options General Title",
		"Options Sounds Title", "Options Language Title"
	]
	var titles = [%GeneralSeparator, %SoundsSeparator, %LanguageSeparator]
	for i in titles.size():
		titles[i].label_text = "  " + RPGSYSTEM.database.terms.search_message(ids[i]) + "  "
	
	ids = [
		"Fullscreen", "Vsync", "Max_fps", "Brightness", "Text Speed", "Master Volume",
		"Music Volume", "Sound Fx Volume","Ambient Volume", "Language", "Exit"
	]

	for i in current_buttons.size():
		var button = get_node(current_buttons[i].control)
		if not "selected" in button: continue
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
		
	
	current_button_selected = 0


func _process(delta: float) -> void:
	if GameManager.get_cursor_manipulator() == scene_manipulator:
		_check_button_pressed()
	
	if fx_delay > 0.0:
		fx_delay -= delta


func _check_button_pressed() -> void:
	if busy: return
	
	if back_button and not back_button.has_focus():
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
			"left", "right":
				if current_button_selected in [0, 1]:
					_select_button(current_buttons.size() - 1)
				elif current_button_selected == current_buttons.size() - 1:
					if direction == "left":
						_select_button(current_buttons.size() - 2)
					else:
						_select_button(0)
					
	elif ControllerManager.is_action_just_pressed("FullScreen"):
		var selected_button: CustomDrawButton = get_node(current_buttons[0].control)
		selected_button.set_pressed_no_signal(current_options.fullscreen)
		
	
	elif ControllerManager.is_confirm_just_pressed():
		if current_button_selected in [0, 1]:
			var selected_button: CustomDrawButton = get_node(current_buttons[current_button_selected].control)
			selected_button.select(true)
		elif current_button_selected == 10:
			_on_back_button_pressed()
		
	elif ControllerManager.is_cancel_just_pressed():
		_on_back_button_pressed()


func _select_button(button_id: int) -> void:
	current_button_selected = button_id
	var selected_button = get_node(current_buttons[current_button_selected].control)
	if  selected_button:
		if "select" in selected_button:
			selected_button.select()
		elif "grab_focus" in selected_button:
			selected_button.grab_focus()


func _move_to_button(direction: int) -> void:
	current_button_selected = wrapi(current_button_selected + direction, 0, current_buttons.size())
	var selected_button = get_node(current_buttons[current_button_selected].control)
	if  selected_button:
		if "select" in selected_button:
			selected_button.select()
		elif "grab_focus" in selected_button:
			selected_button.grab_focus()


func _add_back_button(button: Control) -> void:
	var s = SimpleFocusableControl.new()
	s.control = get_path_to(button)
	s.tooltip = "Options Exit Help"
	s.cursor_position = 2
	current_buttons.append(s)
	back_button = button
	button.pressed.connect(_on_back_button_pressed)


func _on_back_button_pressed() -> void:
	busy = true
	starting_end.emit()

	GameManager.play_fx("cancel")
	GameManager.set_fx_busy(true)
	
	if early_tree_exited_timer > 0.0:
		var t = create_tween()
		t.tween_interval(early_tree_exited_timer)
		t.tween_callback(func(): early_tree_exited.emit())
	
	if back_button:
		if back_button.has_focus():
			back_button.release_focus()
		back_button.select()
		if "animation_finished" in back_button:
			await back_button.animation_finished
			await get_tree().create_timer(0.1).timeout
		
	end.emit()


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
	if fx_preview and fx_delay <= 0.0 and not busy:
		GameManager.play_se(fx_preview)
		fx_delay = 0.15


func _on_me_volume_changed(value: float) -> void:
	%MeVolumeLabel.text = "%.1f%%" % remap(value, -80.0, 0.0, 0.0, 100.0)
	current_options.sound_ambient = remap(value, -80.0, 0.0, 0.0, 1.0)
	current_options.changed.emit()
	if fx_preview and fx_delay <= 0.0 and not busy:
		GameManager.play_bgs(fx_preview)
		fx_delay = 0.15


func _on_full_screen_pressed() -> void:
	current_options.fullscreen = !current_options.fullscreen
	current_options.changed.emit()


func _on_v_sync_pressed() -> void:
	current_options.vsync = !current_options.vsync
	current_options.changed.emit()


func _on_fps_selector_item_changed(value: Variant) -> void:
	current_options.max_fps = int(value)
	current_options.changed.emit()


func _on_language_selector_item_changed(value: Variant) -> void:
	current_options.language = str(value)
	current_options.changed.emit()
