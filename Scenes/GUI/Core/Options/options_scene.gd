class_name GuiCoreGameOptions
extends MarginContainer

#region Exports & Signals
@export var scene_manipulator: String = ""
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
#endregion



#region Lifecycle & Initialization
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
			if GameManager.cursor_manager and GameManager.cursor_manager.hand_cursor:
				GameManager.cursor_manager.hand_cursor.hide_hand_when_mouse_over_focused = true
			GameManager.set_fx_busy(false)
			if options_changed:
				var save_path = "user://game_options.res"
				ResourceSaver.save(current_options, save_path)
	)
	
	if GameManager.cursor_manager and GameManager.cursor_manager.hand_cursor:
		GameManager.cursor_manager.hand_cursor.hide_hand_when_mouse_over_focused = false
	
	_config_hand_in_other_button()
	GameManager.force_show_cursor()

	await get_tree().process_frame
	if has_node("%FullScreen"):
		var fs = get_node("%FullScreen")
		if fs.has_method("select"):
			fs.select()
	GameManager.force_hand_position_over_node(scene_manipulator)
	
	busy = false
	GameManager.set_fx_busy(false)


func _process(delta: float) -> void:
	if GameManager.get_cursor_manipulator() == scene_manipulator:
		_check_button_pressed()
	
	if fx_delay > 0.0:
		fx_delay -= delta
#endregion



#region UI & Controller Configuration
func change_current_button_selected(value: int) -> void:
	current_button_selected = value
	if current_button_selected >= 0 and current_buttons.size() > current_button_selected:
		var tooltip = current_buttons[current_button_selected].tooltip
		if has_node("%TooltipLabel"):
			%TooltipLabel.text = RPGSYSTEM.database.terms.search_message(tooltip)
	else:
		if has_node("%TooltipLabel"):
			%TooltipLabel.text = ""


func _config_hand_in_back_button() -> void:
	var manipulator = scene_manipulator
	GameManager.set_cursor_manipulator(manipulator)
	GameManager.set_hand_position(MainHandCursor.HandPosition.UP, manipulator)
	GameManager.set_cursor_offset(Vector2(0, 2), manipulator)
	GameManager.set_confin_area(Rect2(), manipulator)
	GameManager.force_show_cursor()
	GameManager.force_hand_position_over_node(manipulator)


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


func _config_hand_in_slider_button() -> void:
	_config_hand_in_other_button()
	GameManager.force_show_cursor()


func _fill_locales() -> void:
	if not has_node("%LanguageSelector"):
		return
	var loaded_locales = TranslationServer.get_loaded_locales()
	if not "en" in loaded_locales:
		loaded_locales.append("en")
	
	var current_val = current_options.language if current_options else ""
	%LanguageSelector.items.clear()
	for locale in loaded_locales:
		var lang_name = TranslationServer.get_language_name(locale)
		if lang_name.is_empty():
			lang_name = locale.to_upper()
		var item = SimpleItem.new(lang_name, locale)
		%LanguageSelector.items.append(item)
	
	%LanguageSelector.update()
	if not current_val.is_empty():
		%LanguageSelector.set_value(current_val)


func _load_options() -> void:
	var path = "user://game_options.res"
	if AssetManager.exists(path):
		current_options = load(path)
		options_changed = false
		if current_options and current_options.sound_master <= 0.0 and current_options.sound_fx <= 0.0 and current_options.sound_music <= 0.0:
			current_options.sound_master = 1.0
			current_options.sound_music = 1.0
			current_options.sound_fx = 1.0
			current_options.sound_ambient = 1.0
			options_changed = true
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
	current_options = GameManager.current_game_options
	set_initial_values()
	current_options.changed.connect(
		func():
			options_changed = true
			GameManager.set_options(current_options)
	)
	current_options.changed.emit()


func _find_colum_name_label(button: Node) -> Node:
	if not button: return null
	var p = button.get_parent()
	while p and not (p is HBoxContainer):
		p = p.get_parent()
	if p:
		var col = p.get_node_or_null("Colum1/ColumName")
		if col: return col
		for child in p.get_children():
			if child.name == "Colum1":
				var c = child.get_node_or_null("ColumName")
				if c: return c
	return null


func _update_texts() -> void:
	var ids = [
		"Options General Title",
		"Options Sounds Title", "Options Language Title"
	]
	var titles = []
	if has_node("%GeneralSeparator"): titles.append(%GeneralSeparator)
	if has_node("%SoundsSeparator"): titles.append(%SoundsSeparator)
	if has_node("%LanguageSeparator"): titles.append(%LanguageSeparator)
	
	for i in titles.size():
		if i < ids.size():
			var sep_text = RPGSYSTEM.database.terms.search_message(ids[i])
			if sep_text.is_empty(): sep_text = ids[i]
			titles[i].label_text = "  " + sep_text + "  "
	
	var opt_term_ids = [
		"Options Fullscreen", "Options Vsync", "Options Max_fps", "Options Brightness", "Options Text Speed",
		"Options Master Volume", "Options Music Volume", "Options Sound Fx Volume", "Options Ambient Volume", "Options Language"
	]

	for i in range(mini(opt_term_ids.size(), current_buttons.size())):
		var button = get_node_or_null(current_buttons[i].control)
		if not button: continue
		var col_label = _find_colum_name_label(button)
		if col_label:
			var opt_text = RPGSYSTEM.database.terms.search_message(opt_term_ids[i])
			if opt_text.is_empty():
				opt_text = opt_term_ids[i]
			if not opt_text.ends_with(":"):
				opt_text += ":"
			if "label_text" in col_label:
				col_label.label_text = opt_text.to_upper()
			elif col_label is Label:
				col_label.text = opt_text.to_upper()
		else:
			var label = button.get_parent().get_child(0)
			if label is Label:
				label.text = RPGSYSTEM.database.terms.search_message(opt_term_ids[i])

	var title_node = null
	if has_node("%TitleContainer"):
		title_node = get_node("%TitleContainer")
	elif get_parent() and get_parent().has_node("%TitleContainer"):
		title_node = get_parent().get_node("%TitleContainer")
	elif has_node("../../../../MainContainer/Title/TitleContainer"):
		title_node = get_node("../../../../MainContainer/Title/TitleContainer")
	elif has_node("../../Title/TitleContainer"):
		title_node = get_node("../../Title/TitleContainer")

	if title_node and "title" in title_node:
		var t_name = RPGSYSTEM.database.terms.search_message("Options Title")
		if t_name.is_empty(): t_name = tr("OPTIONS")
		title_node.title = t_name

	if current_button_selected >= 0 and current_buttons.size() > current_button_selected:
		var tooltip = current_buttons[current_button_selected].tooltip
		var tt_text = RPGSYSTEM.database.terms.search_message(tooltip)
		if has_node("%TooltipLabel"):
			%TooltipLabel.text = tt_text
		elif tooltip_label and "text" in tooltip_label:
			tooltip_label.text = tt_text


func _setup_texts_and_buttons() -> void:
	_update_texts()

	for i in current_buttons.size():
		var button = get_node(current_buttons[i].control)
		if not button: continue
		var on_select = func():
			var changed_selection = (current_button_selected != i)
			current_button_selected = i
			if current_button_selected != current_buttons.size() - 1:
				_config_hand_in_other_button()
				if not busy and changed_selection:
					GameManager.play_fx("cursor")
			else:
				_config_hand_in_back_button()

		if not button.focus_entered.is_connected(on_select):
			button.focus_entered.connect(on_select)
		if not button.mouse_entered.is_connected(on_select):
			button.mouse_entered.connect(on_select)
		if "slide_button" in button and button.slide_button:
			if not button.slide_button.focus_entered.is_connected(on_select):
				button.slide_button.focus_entered.connect(on_select)
			if not button.slide_button.mouse_entered.is_connected(on_select):
				button.slide_button.mouse_entered.connect(on_select)
	
	if back_button:
		var back_idx = current_buttons.size() - 1
		var on_back_hover = func():
			current_button_selected = back_idx
			if not back_button.has_focus() and back_button.has_method("grab_focus"):
				back_button.grab_focus()
			_config_hand_in_back_button()
		if not back_button.mouse_entered.is_connected(on_back_hover):
			back_button.mouse_entered.connect(on_back_hover)
		if back_button.has_signal("selected") and not back_button.selected.is_connected(_config_hand_in_back_button):
			back_button.selected.connect(_config_hand_in_back_button)

	current_button_selected = 0
#endregion



#region Input & Selection
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
		if current_buttons.size() > 0:
			var selected_button: CustomDrawButton = get_node(current_buttons[0].control)
			if selected_button:
				selected_button.set_pressed_no_signal(current_options.fullscreen)
	
	elif ControllerManager.is_confirm_just_pressed(true):
		if current_button_selected in [0, 1]:
			var selected_button: CustomDrawButton = get_node(current_buttons[current_button_selected].control)
			if selected_button:
				selected_button.select(true)
		elif current_button_selected == current_buttons.size() - 1:
			_on_back_button_pressed()
		
	elif ControllerManager.is_cancel_just_pressed():
		_on_back_button_pressed()


func _select_button(button_id: int) -> void:
	current_button_selected = button_id
	var selected_button = get_node(current_buttons[current_button_selected].control)
	if selected_button:
		if "select" in selected_button:
			selected_button.select()
		elif "grab_focus" in selected_button:
			selected_button.grab_focus()


func _move_to_button(direction: int) -> void:
	current_button_selected = wrapi(current_button_selected + direction, 0, current_buttons.size())
	var selected_button = get_node(current_buttons[current_button_selected].control)
	if selected_button:
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

	if GameManager.cursor_manager and GameManager.cursor_manager.hand_cursor:
		GameManager.cursor_manager.hand_cursor.hide_hand_when_mouse_over_focused = true

	GameManager.play_fx("cancel")
	GameManager.set_fx_busy(true)
	
	if early_tree_exited_timer > 0.0:
		var t = create_tween()
		t.tween_interval(early_tree_exited_timer)
		t.tween_callback(func(): early_tree_exited.emit())
	
	if back_button:
		if back_button.has_focus():
			back_button.release_focus()
		if back_button.has_method("select"):
			back_button.select()
		if "animation_finished" in back_button:
			await back_button.animation_finished
			if not is_instance_valid(self) or not is_inside_tree(): return
			await get_tree().create_timer(0.1).timeout
			if not is_instance_valid(self) or not is_inside_tree(): return
		
	end.emit()
#endregion



#region Option Setters & Callbacks
func set_initial_values() -> void:
	if has_node("%FullScreen"): %FullScreen.set_value(current_options.fullscreen)
	if has_node("%VSync"): %VSync.set_value(current_options.vsync)
	if has_node("%FpsSelector"): %FpsSelector.set_value(current_options.max_fps)
	if has_node("%Brightness"): %Brightness.set_value(current_options.brightness)
	if has_node("%TextSpeed"): %TextSpeed.set_value(current_options.text_speed)
	if has_node("%MasterVolume"): %MasterVolume.set_value(remap(current_options.sound_master, 0.0, 1.0, -80.0, 0.0))
	if has_node("%MusicVolume"): %MusicVolume.set_value(remap(current_options.sound_music, 0.0, 1.0, -80.0, 0.0))
	if has_node("%SeVolume"): %SeVolume.set_value(remap(current_options.sound_fx, 0.0, 1.0, -80.0, 0.0))
	if has_node("%MeVolume"): %MeVolume.set_value(remap(current_options.sound_ambient, 0.0, 1.0, -80.0, 0.0))
	if has_node("%LanguageSelector"): %LanguageSelector.set_value(current_options.language)


func _on_brightness_changed(value: float) -> void:
	if has_node("%BrightnessLabel"): %BrightnessLabel.text = "x %.2f" % value
	current_options.brightness = value
	current_options.changed.emit()


func _on_text_speed_changed(value: float) -> void:
	if has_node("%TextSpeedLabel"): %TextSpeedLabel.text = "x %.2f" % value
	current_options.text_speed = value
	current_options.changed.emit()


func _on_master_volume_changed(value: float) -> void:
	if has_node("%MasterVolumeLabel"): %MasterVolumeLabel.text = "%.1f%%" % remap(value, -80.0, 0.0, 0.0, 100.0)
	current_options.sound_master = remap(value, -80.0, 0.0, 0.0, 1.0)
	current_options.changed.emit()


func _on_music_volume_changed(value: float) -> void:
	if has_node("%MusicVolumeLabel"): %MusicVolumeLabel.text = "%.1f%%" % remap(value, -80.0, 0.0, 0.0, 100.0)
	current_options.sound_music = remap(value, -80.0, 0.0, 0.0, 1.0)
	current_options.changed.emit()


func _on_se_volume_changed(value: float) -> void:
	if has_node("%SeVolumeLabel"): %SeVolumeLabel.text = "%.1f%%" % remap(value, -80.0, 0.0, 0.0, 100.0)
	current_options.sound_fx = remap(value, -80.0, 0.0, 0.0, 1.0)
	current_options.changed.emit()
	if fx_preview and fx_delay <= 0.0 and not busy:
		GameManager.play_se(fx_preview)
		fx_delay = 0.15


func _on_me_volume_changed(value: float) -> void:
	if has_node("%MeVolumeLabel"): %MeVolumeLabel.text = "%.1f%%" % remap(value, -80.0, 0.0, 0.0, 100.0)
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
	_update_texts()
	_fill_locales()
#endregion
