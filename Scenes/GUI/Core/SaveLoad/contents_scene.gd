@tool
class_name GuiCoreSaveLoadMenu
extends MarginContainer

#region Enums & Exports
enum MODE {LOAD, SAVE}

@export var slot_panel_scene: PackedScene
@export var main_parent_scene: Node
@export var title_container: Node
@export var back_button: Node
@export var confirm_dialog: Node
@export var scroll_container: Node
@export var help_label: Node
@export var tabs: Node
@export var current_mode: MODE = MODE.LOAD
@export var max_slots: int = 15

var current_button: Node

@onready var panel_container: VBoxContainer = %PanelContainer if has_node("%PanelContainer") else null
@onready var slot_container: Control = %SlotContainer if has_node("%SlotContainer") else null

signal partial_destroy()
signal destroy()
#endregion

#region VirtualGetters
func get_panel_container() -> Control:
	if not panel_container and has_node("%PanelContainer"):
		panel_container = %PanelContainer
	return panel_container


func get_slot_container() -> Control:
	if not slot_container and has_node("%SlotContainer"):
		slot_container = %SlotContainer
	return slot_container


func get_scroll_container() -> Node:
	if scroll_container: return scroll_container
	if has_node("%MainScrollContainer"): return get_node("%MainScrollContainer")
	return null


func get_title_container() -> Node:
	if title_container: return title_container
	if has_node("%TitleContainer"): return get_node("%TitleContainer")
	return null


func get_back_button() -> Node:
	if back_button: return back_button
	if has_node("%BackButton"): return get_node("%BackButton")
	return null


func get_confirm_dialog() -> Node:
	if confirm_dialog: return confirm_dialog
	if has_node("%ConfirmDialog"): return get_node("%ConfirmDialog")
	return null


func get_tabs() -> Node:
	if tabs: return tabs
	if has_node("%MenuTabs"): return get_node("%MenuTabs")
	return null


func get_help_label() -> Node:
	if help_label: return help_label
	if has_node("%HelpLabel"): return get_node("%HelpLabel")
	return null
#endregion

#region VirtualHooks
func _config_hand_in_slot() -> void:
	var manipulator = GameManager.MANIPULATOR_MODES.SAVELOAD
	GameManager.set_cursor_manipulator(manipulator)
	GameManager.set_hand_position(MainHandCursor.HandPosition.LEFT, manipulator)
	GameManager.set_cursor_offset(Vector2(48, 2), manipulator)
	var scr = get_scroll_container()
	if scr and scr is Control:
		GameManager.set_confin_area(scr.get_global_rect(), manipulator)
	GameManager.force_show_cursor()


func _config_hand_in_back_button() -> void:
	var manipulator = GameManager.MANIPULATOR_MODES.SAVELOAD
	GameManager.set_cursor_manipulator(manipulator)
	GameManager.set_hand_position(MainHandCursor.HandPosition.UP, manipulator)
	GameManager.set_cursor_offset(Vector2(0, 2), manipulator)
	GameManager.set_confin_area(Rect2(), manipulator)


func _play_ui_sound(sound_name: String) -> void:
	GameManager.play_fx(sound_name)


func _update_title_visual(title_text: String) -> void:
	var tc = get_title_container()
	if tc:
		if "title" in tc:
			tc.title = title_text
		elif tc.has_method("set_text"):
			tc.text = title_text


func _set_help_text(text: String) -> void:
	var hl = get_help_label()
	if hl and "text" in hl:
		hl.text = tr(text)


func _get_slot_scene() -> PackedScene:
	return slot_panel_scene
#endregion

#region Lifecycle & Initialization
func _ready() -> void:
	var tb = get_tabs()
	var tc = get_title_container()
	var bb = get_back_button()
	if tb:
		if current_mode == MODE.LOAD:
			tb.hide()
		else:
			tb.show()
			tb.tab_selected.connect(set_new_mode)
			if tc and tc.has_method("start"):
				tb.tab_selected.connect(tc.start.unbind(1))
	
	set_saveload_current_mode(current_mode)
	
	if GameManager.cursor_manager and GameManager.cursor_manager.hand_cursor:
		GameManager.cursor_manager.hand_cursor.hide_hand_when_mouse_over_focused = false
	
	GameManager.force_hide_cursor()
	GameManager.set_cursor_manipulator(GameManager.MANIPULATOR_MODES.NONE)
	
	if bb:
		bb.focus_entered.connect(_config_hand_in_back_button)
		if bb.has_signal("selected"):
			bb.selected.connect(_config_hand_in_back_button)
		if bb.has_signal("mouse_entered"):
			bb.mouse_entered.connect(func():
				if not bb.has_focus() and bb.has_method("grab_focus"):
					bb.grab_focus()
				_config_hand_in_back_button()
			)
		if bb.has_signal("pressed"):
			bb.pressed.connect(_end)
	
	if not Engine.is_editor_hint():
		ControllerManager.controller_changed.connect(_on_controlled_changed)
		_on_controlled_changed(ControllerManager.current_controller)
		
	_create_slots()


func _on_controlled_changed(type: ControllerManager.CONTROLLER_TYPE) -> void:
	var help: String = ""
	if current_mode == MODE.LOAD:
		if type == ControllerManager.CONTROLLER_TYPE.Joypad:
			help = "D-Pad: Selection  A: Load  B: Exit  Y: Delete File"
		else:
			help = "W/A/S/D: Selection  Space: Load  Escape: Exit  R: Delete File"
	else:
		if type == ControllerManager.CONTROLLER_TYPE.Joypad:
			help = "D-Pad: Selection  A: Save  B: Exit  Y: Delete File"
		else:
			help = "W/A/S/D: Selection  Space: Save  Escape: Exit  R: Delete File"
	
	var tb = get_tabs()
	if tb and tb.visible:
		if type == ControllerManager.CONTROLLER_TYPE.Joypad:
			help += " L1/R1: Change tab"
		else:
			help += " Q/E: Change tab"
	
	_set_help_text(help)


func _change_mode() -> void:
	var tb = get_tabs()
	if tb and tb.visible:
		var index = wrapi(tb.current_tab + 1, 0, tb.tab_count)
		tb.set_current_tab(index)
		_play_ui_sound("cursor")


func set_new_mode(tab_index: int) -> void:
	if tab_index == 0:
		set_saveload_current_mode(MODE.SAVE)
	else:
		set_saveload_current_mode(MODE.LOAD)
	_on_controlled_changed(ControllerManager.current_controller)
	var pc = get_panel_container()
	if pc and pc.get_child_count() > 1:
		var slot = pc.get_child(1)
		if "slot_id" in slot and slot.slot_id == RPGSavedGameData.AUTO_SAVE_SLOT_ID:
			slot.visible = (current_mode != MODE.SAVE)


func set_saveload_current_mode(mode: MODE) -> void:
	current_mode = mode
	if mode == MODE.LOAD:
		update_title(tr("LOAD GAME"))
	else:
		update_title(tr("SAVE GAME"))


func set_save_mode() -> void:
	set_saveload_current_mode(MODE.SAVE)
	var tb = get_tabs()
	if tb:
		tb.visible = false


func _process(_delta: float) -> void:
	if GameManager.get_cursor_manipulator() == GameManager.MANIPULATOR_MODES.SAVELOAD:
		var direction = ControllerManager.get_pressed_direction()
		if direction:
			if direction in ["up", "down"]:
				_change_selected_control(direction)
			elif direction in ["left", "right"]:
				_change_selected_column()
		elif ControllerManager.is_confirm_just_pressed():
			var bb = get_back_button()
			if bb and bb.has_focus():
				_on_back_button_pressed()
			else:
				_on_slot_pressed()
		elif ControllerManager.is_cancel_just_pressed([KEY_0, KEY_KP_0]):
			_on_back_button_pressed()
		elif ControllerManager.is_action_just_pressed("Button L1") or ControllerManager.is_action_just_pressed("Button R1"):
			_change_mode()
		elif ControllerManager.is_action_just_pressed("EraseKey"):
			_erase_slot()
#endregion

#region Navigation & Focus
func _on_back_button_pressed() -> void:
	_end()
	var bb = get_back_button()
	if bb:
		if bb.has_focus():
			bb.release_focus()
		if bb.has_method("select"):
			bb.select()
		GameManager.set_cursor_manipulator(GameManager.MANIPULATOR_MODES.NONE)
		if "animation_finished" in bb:
			await bb.animation_finished
			await get_tree().create_timer(0.1).timeout


func _change_selected_control(direction: String) -> void:
	var bb = get_back_button()
	if bb and bb.has_focus():
		return
	var new_control = ControllerManager.get_closest_focusable_control(current_button, direction, true)
	if new_control:
		if new_control.has_method("select"):
			new_control.select()
		else:
			new_control.grab_focus()


func _change_selected_column() -> void:
	var bb = get_back_button()
	if bb and current_button:
		if bb.has_focus():
			if current_button.has_method("select"):
				current_button.select()
			else:
				current_button.grab_focus()
		else:
			if bb.has_method("select"):
				bb.select()
			else:
				bb.grab_focus()


func update_title(title_text: String) -> void:
	_update_title_visual(title_text)
#endregion

#region Slot Creation & Actions
func _create_slots() -> void:
	var pc = get_panel_container()
	var sc = get_slot_container()
	var scr = get_scroll_container()
	if not pc: return
	for child in pc.get_children():
		child.queue_free()
		pc.remove_child(child)
	
	var most_recent_file = {"index": GameManager.current_save_slot, "date": 0}
	var c = Control.new()
	c.size = Vector2.ZERO
	c.custom_minimum_size = Vector2(0, 32)
	pc.add_child(c)
	
	var slot_scene_res = _get_slot_scene()
	if not slot_scene_res:
		return
	
	if RPGSavedGameData.has_autosave():
		var auto_panel = slot_scene_res.instantiate()
		auto_panel.name = "AutoSave"
		auto_panel.slot_container = sc
		auto_panel.initialize_slot(RPGSavedGameData.AUTO_SAVE_SLOT_ID)
		auto_panel.modulate.a = 0.0
		if scr:
			auto_panel.scroll_container = scr
		pc.add_child(auto_panel)
		auto_panel.focus_entered.connect(
			func():
				GameManager.current_save_slot = auto_panel.get_index()
		)
		if auto_panel.has_method("end"):
			partial_destroy.connect(auto_panel.end)
		if current_mode == MODE.SAVE:
			auto_panel.visible = false
		auto_panel.add_to_group("slot_panel")
		if GameManager.current_save_slot == -1:
			var file_date = SaveLoadManager.get_slot_save_date(RPGSavedGameData.AUTO_SAVE_SLOT_ID)
			if file_date > most_recent_file.date:
				most_recent_file.index = RPGSavedGameData.AUTO_SAVE_SLOT_ID
				most_recent_file.date = file_date
	
	for i in max_slots:
		var panel = slot_scene_res.instantiate()
		var index = RPGSavedGameData.AUTO_SAVE_SLOT_ID + i + 1
		if not Engine.is_editor_hint():
			if GameManager.current_save_slot == -1:
				var file_date = SaveLoadManager.get_slot_save_date(index)
				if file_date > most_recent_file.date:
					most_recent_file.index = index
					most_recent_file.date = file_date
		panel.name = "SaveLoadPanel%s" % index
		panel.slot_container = sc
		panel.initialize_slot(index)
		panel.modulate.a = 0.0
		if scr:
			panel.scroll_container = scr
		pc.add_child(panel)
		panel.focus_entered.connect(
			func():
				current_button = panel
				_config_hand_in_slot()
				_play_ui_sound("cursor")
		)
		if panel.has_method("end"):
			partial_destroy.connect(panel.end)
		panel.add_to_group("slot_panel")
	
	c = c.duplicate()
	pc.add_child(c)
	
	if main_parent_scene and main_parent_scene is BaseAnimatableWindow:
		await main_parent_scene.started
	
	if most_recent_file.index >= 0:
		GameManager.current_save_slot = most_recent_file.index
	
	for child in pc.get_children():
		if child.is_in_group("slot_panel"):
			child.start()


func _on_slot_pressed() -> void:
	var cd = get_confirm_dialog()
	if cd and cd.visible: return
	if current_button:
		if current_mode == MODE.SAVE:
			var refresh_panel: bool = false
			if not current_button.is_disabled:
				if cd:
					_play_ui_sound("ok")
					current_button.set_meta("action_mode", "save")
					cd.contents = tr("Overwrite file?")
					cd.start()
					await cd.visibility_changed
					GameManager.set_fx_busy(true)
					current_button.select()
					GameManager.force_hand_position_over_node(GameManager.get_cursor_manipulator())
					GameManager.set_fx_busy(false)
				else:
					SaveLoadManager.save_game(current_button.slot_id)
					refresh_panel = true
			else:
				_play_ui_sound("Save")
				SaveLoadManager.save_game(current_button.slot_id)
				refresh_panel = true
			if refresh_panel:
				current_button.refresh()
				current_button.select()
				current_button.highlight()
		else:
			if current_button and current_button.is_disabled:
				_play_ui_sound("error")
				return
			
			if GameManager.game_started:
				_play_ui_sound("ok")
				current_button.set_meta("action_mode", "load game")
				if cd:
					cd.contents = tr("Exit the current game?")
					cd.start()
			else:
				_load_game()


func _load_game() -> void:
	if current_button and not current_button.is_disabled:
		current_button.highlight()
		await get_tree().create_timer(0.1).timeout
		if not is_instance_valid(self) or not is_inside_tree(): return
		_play_ui_sound("load")
		GameManager.load_game(current_button.slot_id)
	else:
		_play_ui_sound("error")


func _erase_slot() -> void:
	var cd = get_confirm_dialog()
	if cd and not cd.visible:
		if cd.is_visible(): return
		if not current_button or current_button.is_disabled: return
		
		_play_ui_sound("ok")
		current_button.set_meta("action_mode", "erase file")
		var slot_id = current_button.slot_id
		cd.contents = tr("Erase Slot %s?" % slot_id)
		cd.start()


func confirm_dialog_ok() -> void:
	GameManager.set_fx_busy(false)
	if current_button:
		var action = current_button.get_meta("action_mode")
		current_button.remove_meta("action_mode")
		if action == "save":
			SaveLoadManager.save_game(current_button.slot_id)
			_play_ui_sound("Save")
		elif action == "erase file":
			var slot_id = current_button.slot_id
			SaveLoadManager.remove_game(slot_id)
			_play_ui_sound("Erase Save")
		elif action == "load game":
			_load_game()
			return
			
		GameManager.set_fx_busy(true)
		current_button.refresh()
		current_button.select()
		current_button.highlight()
		GameManager.force_hand_position_over_node(GameManager.get_cursor_manipulator())
		GameManager.force_show_cursor.call_deferred()
	
	GameManager.set_fx_busy(false)


func confirm_dialog_cancel() -> void:
	if current_button:
		GameManager.set_fx_busy(true)
		current_button.select()
		GameManager.set_fx_busy(false)
		GameManager.force_hand_position_over_node(GameManager.get_cursor_manipulator())
		GameManager.force_show_cursor.call_deferred()


func _end() -> void:
	if GameManager.cursor_manager and GameManager.cursor_manager.hand_cursor:
		GameManager.cursor_manager.hand_cursor.hide_hand_when_mouse_over_focused = true
	_play_ui_sound("cancel")
	GameManager.set_cursor_manipulator(GameManager.MANIPULATOR_MODES.NONE)
	partial_destroy.emit()
	await get_tree().create_timer(0.25).timeout
	if not is_instance_valid(self) or not is_inside_tree(): return
	destroy.emit()
#endregion
