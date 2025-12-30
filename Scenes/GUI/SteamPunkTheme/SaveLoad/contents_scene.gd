@tool
extends MarginContainer

enum MODE {LOAD, SAVE}

@export var main_parent_scene: Node
@export var title_container: Node
@export var back_button: Node
@export var confirm_dialog: Node
@export var scroll_container: Node
@export var help_label: Node
@export var tabs: Node
@export var current_mode: MODE = MODE.LOAD

const PANEL_SCENE = preload("uid://c8ca1gmcbbb86")
const MAX_SLOTS = 15

var current_button: Node

@onready var panel_container: VBoxContainer = %PanelContainer
@onready var slot_container: Control = %SlotContainer


signal partial_destroy()
signal destroy()


func _ready() -> void:
	if tabs:
		if current_mode == MODE.LOAD:
			tabs.hide()
		else:
			tabs.show()
			tabs.tab_selected.connect(set_new_mode)
			tabs.tab_selected.connect(title_container.start.unbind(1))
	
	set_saveload_current_mode(current_mode)
	
	GameManager.force_hide_cursor()
	GameManager.set_cursor_manipulator(GameManager.MANIPULATOR_MODES.NONE)
	
	if back_button:
		back_button.focus_entered.connect(_config_hand_in_back_button)
		back_button.pressed.connect(_end)
	
	if not Engine.is_editor_hint():
		ControllerManager.controller_changed.connect(_on_controlled_changed)
		_on_controlled_changed(ControllerManager.current_controller)
		
	_create_slots()


func _on_controlled_changed(type: ControllerManager.CONTROLLER_TYPE):
	if help_label:
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
		
		if tabs and tabs.visible:
			if type == ControllerManager.CONTROLLER_TYPE.Joypad:
				help += " L1/R1: Change tab"
			else:
				help += " Q/E: Change tab"
		
		
		%HelpLabel.text = tr(help)


func _change_mode() -> void:
	if tabs and tabs.visible:
		var index = wrapi(tabs.current_tab + 1, 0, tabs.tab_count)
		tabs.set_current_tab(index)
		GameManager.play_fx("cursor")


func set_new_mode(tab_index: int) -> void:
	if tab_index == 0:
		set_saveload_current_mode(MODE.SAVE)
	else:
		set_saveload_current_mode(MODE.LOAD)
	_on_controlled_changed(ControllerManager.current_controller)
	if panel_container.get_child_count() > 0:
		var slot = panel_container.get_child(1)
		if slot.slot_id == RPGSavedGameData.AUTO_SAVE_SLOT_ID:
			if current_mode == MODE.SAVE:
				slot.visible = false
			else:
				slot.visible = true
	


func set_saveload_current_mode(mode: MODE) -> void:
	current_mode = mode
	if mode == MODE.LOAD:
		update_title(tr("LOAD GAME"))
	else:
		update_title(tr("SAVE GAME"))
		


func _process(_delta: float) -> void:
	if GameManager.get_cursor_manipulator() == GameManager.MANIPULATOR_MODES.SAVELOAD:
		var direction = ControllerManager.get_pressed_direction()
		if direction:
			if direction in ["up", "down"]:
				_change_selected_control(direction)
			elif direction in ["left", "right"]:
				_change_selected_column()
		elif ControllerManager.is_confirm_just_pressed():
			if back_button and back_button.has_focus():
				_on_back_button_pressed()
			else:
				_on_slot_pressed()
		elif ControllerManager.is_cancel_just_pressed([KEY_0, KEY_KP_0]):
			_on_back_button_pressed()
		elif ControllerManager.is_action_just_pressed("Button L1") or  ControllerManager.is_action_just_pressed("Button R1"):
			_change_mode()
		elif ControllerManager.is_action_just_pressed("EraseKey"):
			_erase_slot()


func _on_back_button_pressed() -> void:
	_end()
	if back_button:
		if back_button.has_focus():
			back_button.release_focus()
		back_button.select()
		GameManager.set_cursor_manipulator(GameManager.MANIPULATOR_MODES.NONE)
		if "animation_finished" in back_button:
			await back_button.animation_finished
			await get_tree().create_timer(0.1).timeout
			if not is_instance_valid(self) or not is_inside_tree(): return


func _config_hand_in_slot() -> void:
	var manipulator = GameManager.MANIPULATOR_MODES.SAVELOAD
	GameManager.set_cursor_manipulator(manipulator)
	GameManager.set_hand_position(MainHandCursor.HandPosition.LEFT, manipulator)
	GameManager.set_cursor_offset(Vector2(48, 2), manipulator)
	GameManager.set_confin_area(scroll_container.get_global_rect(), manipulator)
	GameManager.force_show_cursor()


func _config_hand_in_back_button() -> void:
	var manipulator = GameManager.MANIPULATOR_MODES.SAVELOAD
	GameManager.set_cursor_manipulator(manipulator)
	GameManager.set_hand_position(MainHandCursor.HandPosition.UP, manipulator)
	GameManager.set_cursor_offset(Vector2(0, 2), manipulator)
	GameManager.set_confin_area(Rect2(), manipulator)


func _change_selected_control(direction: String) -> void:
	if back_button.has_focus():
		return
		
	var new_control = ControllerManager.get_closest_focusable_control(current_button, direction, true)
	if new_control:
		if new_control.has_method("select"):
			new_control.select()
		else:
			new_control.grab_focus()


func _change_selected_column() -> void:
	if back_button:
		if back_button.has_focus():
			current_button.select()
		else:
			back_button.select()


func update_title(title: String) -> void:
	if title_container:
		if "title" in title_container:
			title_container.title = title
		elif title_container.has_method("set_text"):
			title_container.text = title


func _create_slots() -> void:
	for child in panel_container.get_children():
		child.queue_free()
		panel_container.remove_child(child)
	
	var most_recent_file = {"index": GameManager.current_save_slot, "date": 0}
	var c = Control.new()
	c.size = Vector2.ZERO
	c.custom_minimum_size = Vector2(0, 32)
	panel_container.add_child(c)
	
	if RPGSavedGameData.has_autosave():
		var auto_panel = PANEL_SCENE.instantiate()
		auto_panel.name = "AutoSave"
		auto_panel.slot_container = slot_container
		auto_panel.initialize_slot(RPGSavedGameData.AUTO_SAVE_SLOT_ID)
		auto_panel.modulate.a = 0.0
		if scroll_container:
			auto_panel.scroll_container = scroll_container
		panel_container.add_child(auto_panel)
		auto_panel.focus_entered.connect(
			func():
				GameManager.current_save_slot = auto_panel.get_index()
		)
		partial_destroy.connect(panel_container.end)
		if current_mode == MODE.SAVE:
			auto_panel.visible = false
		auto_panel.add_to_group("slot_panel")
		if GameManager.current_save_slot == -1:
			var file_date = SaveLoadManager.get_slot_save_date(RPGSavedGameData.AUTO_SAVE_SLOT_ID)
			if file_date > most_recent_file.date:
				most_recent_file.index = RPGSavedGameData.AUTO_SAVE_SLOT_ID
				most_recent_file.date = file_date
	
	for i in MAX_SLOTS:
		var panel = PANEL_SCENE.instantiate()
		var index = RPGSavedGameData.AUTO_SAVE_SLOT_ID + i + 1
		if not Engine.is_editor_hint():
			if GameManager.current_save_slot == -1:
				var file_date = SaveLoadManager.get_slot_save_date(index)
				if file_date > most_recent_file.date:
					most_recent_file.index = index
					most_recent_file.date = file_date
		panel.name = "SaveLoadPanel%s" % index
		panel.slot_container = slot_container
		panel.initialize_slot(index)
		panel.modulate.a = 0.0
		if scroll_container:
			panel.scroll_container = scroll_container
		panel_container.add_child(panel)
		panel.focus_entered.connect(
			func():
				current_button = panel
				_config_hand_in_slot()
				GameManager.play_fx("cursor")
		)
		partial_destroy.connect(panel.end)
		panel.add_to_group("slot_panel")

	c = c.duplicate()
	
	panel_container.add_child(c)
	
	if main_parent_scene and main_parent_scene is BaseAnimatableWindow:
		await main_parent_scene.started
	
	if most_recent_file.index >= 0:
		GameManager.current_save_slot = most_recent_file.index
	
	for child in panel_container.get_children():
		if child.is_in_group("slot_panel"):
			child.modulate.a = 1.0
			child.start()


func _on_slot_pressed() -> void:
	if confirm_dialog and confirm_dialog.visible: return
	if current_button:
		if current_mode == MODE.SAVE:
			var refresh_panel: bool = false
			if not current_button.is_disabled:
				if confirm_dialog:
					GameManager.play_fx("ok")
					current_button.set_meta("action_mode", "save")
					confirm_dialog.contents = tr("Overwrite file?")
					confirm_dialog.start()
					await confirm_dialog.visibility_changed
					GameManager.set_fx_busy(true)
					current_button.select()
					GameManager.force_hand_position_over_node(GameManager.get_cursor_manipulator())
					GameManager.set_fx_busy(false)
				else:
					SaveLoadManager.save_game(current_button.slot_id)
					refresh_panel = true
			else:
				GameManager.play_fx("Save")
				SaveLoadManager.save_game(current_button.slot_id)
				refresh_panel = true
			if refresh_panel:
				current_button.refresh()
				current_button.select()
				current_button.highlight()
		else:
			if current_button and current_button.is_disabled:
				GameManager.play_fx("error")
				return
			
			if GameManager.game_started:
				GameManager.play_fx("ok")
				current_button.set_meta("action_mode", "load game")
				confirm_dialog.contents = tr("Exit the current game?")
				confirm_dialog.start()
			else:
				_load_game()


func _load_game() -> void:
	if current_button and not current_button.is_disabled:
		current_button.highlight()
		await get_tree().create_timer(0.1).timeout
		if not is_instance_valid(self) or not is_inside_tree(): return
		GameManager.play_fx("load")
		GameManager.load_game(current_button.slot_id)
	else:
		GameManager.play_fx("error")


func _erase_slot() -> void:
	if confirm_dialog and not confirm_dialog.visible:
		if confirm_dialog.is_visible(): return
		if not current_button or current_button.is_disabled: return
		
		GameManager.play_fx("ok")
		current_button.set_meta("action_mode", "erase file")
		var slot_id = current_button.slot_id
		
		confirm_dialog.contents = tr("Erase Slot %s?" % slot_id)
		confirm_dialog.start()


func confirm_dialog_ok() -> void:
	GameManager.set_fx_busy(false)
	if current_button:
		var action = current_button.get_meta("action_mode")
		current_button.remove_meta("action_mode")
		if action == "save":
			SaveLoadManager.save_game(current_button.slot_id)
			GameManager.play_fx("Save")
		elif action == "erase file":
			var slot_id = current_button.slot_id
			SaveLoadManager.remove_game(slot_id)
			GameManager.play_fx("Erase Save")
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
	GameManager.play_fx("cancel")
	GameManager.set_cursor_manipulator(GameManager.MANIPULATOR_MODES.NONE)
	partial_destroy.emit()
	await get_tree().create_timer(0.25).timeout
	if not is_instance_valid(self) or not is_inside_tree(): return
	destroy.emit()
