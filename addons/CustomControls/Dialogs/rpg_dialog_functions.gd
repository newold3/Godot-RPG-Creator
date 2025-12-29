@tool
extends Node

enum OPEN_MODE {CENTERED, CENTERED_ON_MOUSE}

var current_opened_dialogs: Array

var busy: bool = false

var initial_delay: float

var audio_player: AudioStreamPlayer
var play_audio_when_focus_inactive_window: bool = true # Play buzzer fx when click in inactive window

var buzzer_tween: Tween

var current_dialog_is_disabled: bool = false
var current_dialog_exclusive: bool = false

var main_window: Window

static var _current_dialogs: Array
static var _game_embbedded_popup: PopupMenu
static var _embbedded_popup_checkeds: Dictionary

const APPLICATION_ICON = preload("res://icon.png")


func _ready() -> void:
	if Engine.is_editor_hint():
		audio_player = AudioStreamPlayer.new()
		audio_player.stream = preload("res://addons/CustomControls/Audio/window_buzzer.ogg")
		add_child(audio_player)
		var image = APPLICATION_ICON.get_image()
		if image.is_compressed():
			image.decompress()
		DisplayServer.set_icon(image)
		get_tree().root.focus_entered.connect(_on_root_focus_entered)
		_game_embbedded_popup = _find_game_embbedded_menu()
		main_window = get_window()


func _find_game_embbedded_menu() -> PopupMenu:
	var root = EditorInterface.get_base_control()
	var game_view = root.find_child("*GameView*", true, false)
	var popups = game_view.find_children("*PopupMenu*", "", true, false)
	for popup in popups:
		if popup.get_item_count() == 2:
			var s = popup.get_signal_connection_list("id_pressed")[0]
			if str(s.callable) == "GameView::_embed_options_menu_menu_id_pressed":
				return popup
			
	
	return null


func _is_valid_window(window) -> bool:
	return window and is_instance_valid(window) and window is Window and window.get_window_id() != -1


func preview_commands_in_action(commands: Array[RPGEventCommand]) -> void:
	var res = TestCommandEvent.new()
	res.commands = commands
	var _test_commands_file_path = "res://addons/RPGMap/Temp/_temp_event_commands.res"
	ResourceSaver.save(res, _test_commands_file_path)
	EditorInterface.call_deferred("play_custom_scene", "res://addons/RPGMap/Scenes/event_command_testing.tscn")
	disable_dialog()
	embbedded_game_window()


func finish_preview_commands_in_action() -> void:
	var _test_commands_file_path = "res://addons/RPGMap/Temp/_temp_event_commands.res"
	enable_dialog()
	restore_embbedded_game_window()
	if ResourceLoader.exists(_test_commands_file_path):
		var global_path = ProjectSettings.globalize_path(_test_commands_file_path)
		DirAccess.remove_absolute(global_path)
		var editor_fs = EditorInterface.get_resource_filesystem()
		editor_fs.filesystem_changed


func embbedded_game_window() -> void:
	if not _game_embbedded_popup:
		_game_embbedded_popup = _find_game_embbedded_menu()
		
	if _game_embbedded_popup:
		var item_checked1 = _game_embbedded_popup.is_item_checked(0)
		var item_checked2 = _game_embbedded_popup.is_item_checked(1)
		
		_embbedded_popup_checkeds = {"item1": item_checked1, "item2": item_checked2}
		if not item_checked1:
			_game_embbedded_popup.id_pressed.emit(4) # current index for this godot version (4.5.1)
		if item_checked2:
			_game_embbedded_popup.id_pressed.emit(5) # current index for this godot version (4.5.1)


func restore_embbedded_game_window() -> void:
	if not _game_embbedded_popup:
		_game_embbedded_popup = _find_game_embbedded_menu()
		
	if _game_embbedded_popup and _embbedded_popup_checkeds:
		if _embbedded_popup_checkeds.item1 != _game_embbedded_popup.is_item_checked(0):
			_game_embbedded_popup.id_pressed.emit(4) # current index for this godot version (4.5.1)
		if _embbedded_popup_checkeds.item2 != _game_embbedded_popup.is_item_checked(1):
			_game_embbedded_popup.id_pressed.emit(5) # current index for this godot version (4.5.1)
	
	_embbedded_popup_checkeds.clear()


func enable_dialog() -> void:
	if current_dialog_is_disabled and _current_dialogs:
		var last_dialog = _current_dialogs[-1]
		last_dialog.exclusive = current_dialog_exclusive
		for dialog in _current_dialogs:
			open_dialog(dialog)

	current_dialog_is_disabled = false
	_current_dialogs.clear()


func disable_dialog() -> void:
	if current_opened_dialogs.size() == 0:
		return
		
	_current_dialogs = current_opened_dialogs.duplicate()
	
	var dialog = current_opened_dialogs[-1]
	if dialog.visibility_changed.is_connected(dialog_visibility_changed):
		dialog.visibility_changed.disconnect(dialog_visibility_changed.bind(dialog))
	current_dialog_exclusive = dialog.exclusive
	dialog.exclusive = false
	dialog.visible = false
	current_dialog_is_disabled = true


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		
		if current_dialog_is_disabled:
			if not EditorInterface.is_playing_scene():
				finish_preview_commands_in_action()
				
		if not current_opened_dialogs.is_empty() and current_opened_dialogs[-1].is_input_disabled():
			current_opened_dialogs[-1].set_disable_input.call_deferred(false)
		elif main_window.is_input_disabled():
			main_window.set_disable_input.call_deferred(false)
		
	if initial_delay > 0.0:
		initial_delay -= delta
	
	_check_window_focus()


func _on_root_focus_entered() -> void:
	select_last_dialog()


func select_last_dialog() -> void:
	var to_erase = []
	for dialog in current_opened_dialogs:
		if not _is_valid_window(dialog):
			to_erase.append(dialog)
	
	for dialog in to_erase:
		current_opened_dialogs.erase(dialog)
		
	if current_opened_dialogs.size() > 0:
		current_opened_dialogs[-1].set_disable_input.call_deferred(false)
		current_opened_dialogs[-1].grab_focus()
	else:
		var main_dialog = get_window()
		main_dialog.set_disable_input.call_deferred(false)
		main_dialog.grab_focus()


func show_file_dialog(callback: Callable, base_types: Array[StringName] = []) -> void: # use integrated quick dialog
	if Engine.is_editor_hint():
		if RPGSYSTEM.editor_interface:
			RPGSYSTEM.editor_interface.popup_quick_open(callback, base_types)


func open_dialog(path: Variant, mode: OPEN_MODE = OPEN_MODE.CENTERED_ON_MOUSE, dialog_size = null, disable_exclusive_flag: bool = false, enable_transition: bool = true) -> Window:
	if (path is String and !ResourceLoader.exists(path)) and not path is Window:
		return null
	
	var dialog: Window
	
	if path is String:
		dialog = load(path).instantiate()
	else:
		dialog = path
		
	TranslationManager.translate(dialog)
	dialog.set_transparent_background(true)
	dialog.visible = false
	if disable_exclusive_flag:
		dialog.exclusive = false
	else:
		dialog.exclusive = true

	var dialog_parent = get_viewport()
	if current_opened_dialogs.size() > 0:
		dialog_parent = current_opened_dialogs[-1]
		
	if enable_transition:
		dialog.transient = true
		dialog.transient_to_focused = true
	
	if dialog_parent != dialog and not dialog.is_inside_tree():
		dialog_parent.add_child(dialog)
	
	show_dialog(dialog, mode, dialog_size)
	
	return dialog


func _update_file_cache_activity() -> void:
	if FileCache.main_scene:
		var should_be_active = current_opened_dialogs.is_empty()
		if FileCache.main_scene.is_processing() != should_be_active:
			FileCache.main_scene.set_process(should_be_active)


func show_dialog(dialog: Window, mode: OPEN_MODE = OPEN_MODE.CENTERED_ON_MOUSE, dialog_size = null) -> void:
	if dialog in current_opened_dialogs:
		if dialog.get_parent() != null:
			dialog.get_parent().remove_child(dialog)
		current_opened_dialogs.erase(dialog)
		
	if not dialog.is_inside_tree():
		if current_opened_dialogs.size() > 0:
			current_opened_dialogs[-1].add_child(dialog)
		else:
			get_viewport().add_child(dialog)
	
	#dialog.get_parent().unfocusable = true
	
	if dialog_size:
		dialog.set_deferred("size", dialog_size)
	
	if dialog.visibility_changed.is_connected(dialog_visibility_changed):
		dialog.visibility_changed.disconnect(dialog_visibility_changed)
	dialog.visibility_changed.connect(dialog_visibility_changed.bind(dialog))
	
	if dialog.tree_exiting.is_connected(_on_dialog_tree_exiting):
		dialog.tree_exiting.disconnect(_on_dialog_tree_exiting)
	dialog.tree_exiting.connect(_on_dialog_tree_exiting.bind(dialog))
	
	if dialog.window_input.is_connected(_on_dialog_window_input):
		dialog.window_input.disconnect(_on_dialog_window_input)
	dialog.window_input.connect(_on_dialog_window_input.bind(dialog))
	
	if dialog.mouse_entered.is_connected(_on_dialog_mouse_entered):
		dialog.mouse_entered.disconnect(_on_dialog_mouse_entered)
	dialog.mouse_entered.connect(_on_dialog_mouse_entered.bind(dialog))
	
	if mode == OPEN_MODE.CENTERED:
		dialog.popup_centered()
	else:
		var mouse_position = Vector2(DisplayServer.mouse_get_position())
		var p: Vector2 = mouse_position - dialog.size * 0.5
		var margin = 64
		var screen_size = Vector2(DisplayServer.screen_get_size())
		if p.x < margin:
			p.x = margin
		elif p.x > screen_size.x - margin - dialog.size.x:
			p.x = screen_size.x - margin - dialog.size.x
		if p.y < margin:
			p.y = margin
		elif p.y > screen_size.y - margin - dialog.size.y:
			p.y = screen_size.y - margin - dialog.size.y
		if (
			p.x + dialog.size.x < 0 or
			p.x > get_viewport().size.x or
			p.y + dialog.size.y < 0 or
			p.y > get_viewport().size.y
		):
			p = get_viewport().size * 0.5
		var rect: Rect2 = Rect2(p, dialog.size)
		dialog.popup(rect)
		dialog.position = p

	if current_opened_dialogs.size() > 0:
		current_opened_dialogs[-1].set_disable_input.call_deferred(true)
	else:
		get_viewport().set_disable_input.call_deferred(true)
	current_opened_dialogs.append(dialog)
	initial_delay = 0.1
	_update_file_cache_activity()
	await get_tree().process_frame
	if _is_valid_window(dialog):
		dialog.grab_focus.call_deferred()

	busy = false
	
	#prints("Añadido dialogo ", dialog, "lista de dialogos abiertos = ", current_opened_dialogs)


func _check_window_focus() -> void:
	return # May cause engine bricking; currently disabled.
	if current_opened_dialogs.size() > 0 and not current_opened_dialogs[-1].has_focus():
		var window = current_opened_dialogs[-1]
		var pos = current_opened_dialogs[-1].get_mouse_position()
		var rect = Rect2i(Vector2i.ZERO, window.size)
		if rect.has_point(pos):
			var active_popup_id = DisplayServer.window_get_active_popup()
			if not active_popup_id > 0:
				#var uid = DisplayServer.window_get_attached_instance_id(active_popup_id)
				#var obj = instance_from_id(uid)
				window.grab_focus()


func _on_dialog_mouse_entered(dialog: Window, force_focus: bool = false) -> void:
	return # May cause engine bricking; currently disabled.
	var active_popup : int = DisplayServer.window_get_active_popup()
	if active_popup != -1:
		return
	
	if CustomColorDialog.instance and CustomColorDialog.is_opened:
		CustomColorDialog.instance.grab_focus()
		return
		
	if (force_focus or current_opened_dialogs.size() > 0 and current_opened_dialogs[-1] == dialog and not dialog.has_focus()):
		dialog.grab_focus()


func show_dialog_center_in_mouse(dialog: Window) -> void:
	var mouse_position = Vector2(DisplayServer.mouse_get_position())
	var p: Vector2 = mouse_position - dialog.size * 0.5
	var margin = 64
	var screen_size = Vector2(DisplayServer.screen_get_size())
	if p.x < margin:
		p.x = margin
	elif p.x > screen_size.x - margin - dialog.size.x:
		p.x = screen_size.x - margin - dialog.size.x
	if p.y < margin:
		p.y = margin
	elif p.y > screen_size.y - margin - dialog.size.y:
		p.y = screen_size.y - margin - dialog.size.y
	if (
		p.x + dialog.size.x < 0 or
		p.x > get_viewport().size.x or
		p.y + dialog.size.y < 0 or
		p.y > get_viewport().size.y
	):
		p = get_viewport().size * 0.5
	var rect: Rect2 = Rect2(p, dialog.size)
	dialog.popup(rect)
	dialog.position = p


func _on_dialog_grab_focus(dialog) -> void:
	if busy or true: return # disabled cause godot error

	if !_is_valid_window(dialog) or current_opened_dialogs.size() == 0:
		return
	
	var current_dialog = get_current_dialog()
		
	if dialog != current_dialog and current_opened_dialogs.size() > 0:
		# Animate focused window
		if initial_delay <= 0:
			if current_dialog.has_meta("shake_tween"):
				var t: Tween = current_dialog.get_meta("shake_tween")
				current_dialog.remove_meta("shake_tween")
				if t and t.is_valid() and t.is_running():
					t.kill()
				
			var position = current_dialog.position
			var t = current_dialog.create_tween()
			for i in 3:
				var x = randi_range(-3, 3)
				var y = randi_range(-3, 3)
				t.tween_property(current_dialog, "position", position + Vector2i(x, y), 0.05)
			t.tween_property(current_dialog, "position", position, 0.1)
			current_dialog.set_meta("shake_tween", t)
		
		current_opened_dialogs[-1].grab_focus()
		
		if play_audio_when_focus_inactive_window:
			play_buzzer_fx(dialog)


func play_buzzer_fx(dialog) -> void:
	if buzzer_tween:
		buzzer_tween.kill()
		
	buzzer_tween = create_tween()
	buzzer_tween.tween_interval(0.04)
	buzzer_tween.tween_callback(_play_buzzer_fx.bind(dialog))


func _play_buzzer_fx(dialog) -> void:
	if current_opened_dialogs.size() > 0 and _is_valid_window(dialog) and dialog != current_opened_dialogs[-1]:
		audio_player.play() # Play buzzer fx


func dialog_visibility_changed(dialog: Window) -> void:
	if !dialog.visible:
		if dialog.focus_entered.is_connected(_on_dialog_grab_focus):
			dialog.focus_entered.disconnect(_on_dialog_grab_focus)
		if current_opened_dialogs.has(dialog):
			current_opened_dialogs.erase(dialog)
			select_last_dialog()
		_update_file_cache_activity()
	else:
		if not dialog.focus_entered.is_connected(_on_dialog_grab_focus):
			dialog.focus_entered.connect(_on_dialog_grab_focus.bind(dialog))
		var parent = dialog.get_parent()
		if _is_valid_window(parent):
			if not parent.focus_entered.is_connected(_on_dialog_grab_focus):
				parent.focus_entered.connect(_on_dialog_grab_focus.bind(parent))


func _on_dialog_tree_exiting(dialog: Window) -> void:
	if current_opened_dialogs.has(dialog):
		current_opened_dialogs.erase(dialog)
		#prints("Saliendo del dialogo ", dialog, "lista de dialogos abiertos = ", current_opened_dialogs)
		select_last_dialog()
	_update_file_cache_activity()


func _on_dialog_window_input(event: InputEvent, dialog: Window) -> void:
	if event is InputEventKey:
		if event.is_pressed():
			if event.keycode == KEY_ESCAPE:
				if "_on_cancel_button_pressed" in dialog:
					dialog._on_cancel_button_pressed()
					get_viewport().set_input_as_handled()
			elif event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
				var focus_owner = dialog.gui_get_focus_owner()
				if focus_owner:
					if focus_owner is TextEdit and !event.is_ctrl_pressed():
						return
					if focus_owner is ItemList and !event.is_ctrl_pressed():
						return
					elif focus_owner is LineEdit and focus_owner.get_parent() is SpinBox:
						focus_owner.get_parent().apply()
						focus_owner.release_focus()
						await get_tree().process_frame
						focus_owner.deselect()
						return
					elif focus_owner.get_class() == "SpecialItemList" and focus_owner.get_parent().lock_enter and !event.is_ctrl_pressed():
						return
				if "_on_ok_button_pressed" in dialog:
					dialog._on_ok_button_pressed()
					get_viewport().set_input_as_handled()
			# Close all dialog opened
			elif event.keycode == KEY_F and event.is_ctrl_pressed() and event.is_alt_pressed():
				for i in range(current_opened_dialogs.size() - 1, -1, -1):
					var d = current_opened_dialogs[i]
					if "_on_cancel_button_pressed" in d:
						d._on_cancel_button_pressed()


func get_current_dialog() -> Node:
	if current_opened_dialogs.size() > 0:
		for i in range(current_opened_dialogs.size() - 1, -1, -1):
			if _is_valid_window(current_opened_dialogs[i]):
				return current_opened_dialogs[i]

	return get_viewport()


func there_are_any_dialog_open() -> bool:
	return current_opened_dialogs.size() > 0
