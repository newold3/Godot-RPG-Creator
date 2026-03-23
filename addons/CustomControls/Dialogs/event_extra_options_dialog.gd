@tool
extends Window

## Reference to the original options object to apply changes
var real_options: RPGEventPageOptions
## Local copy of options for the dialog session
var options: RPGEventPageOptions
## Internal flag to check if the parent page is in 'Pressed' mode
var is_pressed_mode: bool = false

signal OK()


func _ready() -> void:
	close_requested.connect(queue_free)
	_fill_self_switches()
	
	await get_tree().process_frame
	CustomTooltipManager.replace_all_tooltips_with_custom.call_deferred(self)


func _fill_self_switches() -> void:
	var node1 = %EnableSelfSwitchOnHit
	var node2 = %EnableSelfSwitchOnDead
	node1.clear()
	node2.clear()
	
	node1.add_item(tr("None"))
	node2.add_item(tr("None"))
	
	var system = RPGSYSTEM.system
	if system:
		for key in system.self_switches.get_switch_names():
			node1.add_item("Switch %s" % key.to_upper())
			node2.add_item("Switch %s" % key.to_upper())


func set_page_options(_options: RPGEventPageOptions, _is_pressed: bool = false) -> void:
	real_options = _options
	options = _options.clone()
	is_pressed_mode = _is_pressed
	
	## If pressed mode is active, we force 'Normal' type in data immediately
	if is_pressed_mode:
		options.event_type = 0
		
	fill()


func fill() -> void:
	%UseExtraConfig.set_pressed_no_signal(options.use_extra_config)
	%IsInmortal.set_pressed_no_signal(options.is_inmortal)
	%HP.value = options.hp
	var id1 = clamp(int(options.enable_self_switch_on_hit_id + 1), 0,  RPGSYSTEM.system.self_switches.size())
	%EnableSelfSwitchOnHit.select(id1)
	var id2 = clamp(int(options.enable_self_switch_on_dead_id + 1), 0,  RPGSYSTEM.system.self_switches.size())
	%EnableSelfSwitchOnDead.select(id2)
	
	_disable_fields()
	
	%ShowNameInMap.set_pressed_no_signal(options.show_name_in_map)
	_update_name_config_text()
	%NameConfig.set_disabled(!options.show_name_in_map)
	
	_setup_event_type_ui()
	
	%ThrowStrength.value = options.type_params.get("throw_strength", 1)
	%Time.value = options.type_params.get("time", 0.15)
	%InitialDelay.value = options.type_params.get("initial_delay", 0.1)


func _setup_event_type_ui() -> void:
	# Setup interactive state based on Pressed mode
	if is_pressed_mode:
		%TypePickableEvent.set_disabled(true)
		%TypeMoveableEvent.set_disabled(true)
		var msg = tr("Not available in Pressed Mode (Traversable)")
		%TypePickableEvent.tooltip_text = msg
		%TypeMoveableEvent.tooltip_text = msg
		# Forcing Normal mode button: this triggers the 'toggled' signal and updates data
		%TypeNormalEvent.button_pressed = true
	else:
		%TypePickableEvent.set_disabled(false)
		%TypeMoveableEvent.set_disabled(false)
		%TypePickableEvent.tooltip_text = ""
		%TypeMoveableEvent.tooltip_text = ""
		
		# Activate the correct button from the ButtonGroup based on current data
		match options.event_type:
			0: %TypeNormalEvent.button_pressed = true
			1: %TypePickableEvent.button_pressed = true
			2: %TypeMoveableEvent.button_pressed = true
	
	_refresh_type_params_visibility()


func _refresh_type_params_visibility() -> void:
	# Handle visibility of parameter containers based on selected mode
	%PickableParams.visible = (options.event_type == 1)
	%MoveableParams.visible = (options.event_type == 2)
	%NoParams.visible = (options.event_type == 0)
	
	var title_color = Color("#a2a2a2") if options.event_type == 0 else Color("#a0fec3")
	%ParamsTitle.set("theme_override_colors/font_color", title_color)


func _disable_fields() -> void:
	%ExtraConfigContainer.propagate_call("set_disabled", [!options.use_extra_config])
	var is_disabled = options.is_inmortal or !options.use_extra_config
	%HP.set_disabled(is_disabled)
	%EnableSelfSwitchOnDead.set_disabled(is_disabled)


func _on_ok_button_pressed() -> void:
	propagate_call("apply")
	
	var keys = [
		"show_name_in_map", "name_config_path", "event_type", "type_params",
		"use_extra_config", "is_inmortal", "hp", "enable_self_switch_on_hit_id",
		"enable_self_switch_on_dead_id"
	]
	
	for key in keys:
		real_options[key] = options[key]

	OK.emit()
	queue_free()


func _on_cancel_button_pressed() -> void:
	queue_free()


func _on_use_extra_config_toggled(toggled_on: bool) -> void:
	options.use_extra_config = toggled_on
	_disable_fields()


func _on_is_inmortal_toggled(toggled_on: bool) -> void:
	options.is_inmortal = toggled_on
	_disable_fields()


func _on_hp_value_changed(value: float) -> void:
	options.hp = value


func _on_enable_self_switch_on_hit_item_selected(index: int) -> void:
	options.enable_self_switch_on_hit_id = index - 1


func _on_enable_self_switch_on_dead_item_selected(index: int) -> void:
	options.enable_self_switch_on_dead_id = index - 1


func _on_show_name_in_map_toggled(toggled_on: bool) -> void:
	options.show_name_in_map = toggled_on
	%NameConfig.set_disabled(!toggled_on)


func _on_name_config_pressed() -> void:
	var path = "res://addons/CustomControls/Dialogs/select_file_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	
	await get_tree().process_frame
	
	var current_path: String = options.name_config_path
	
	dialog.destroy_on_hide = true
	dialog.target_callable = _update_name_config
	dialog.set_file_selected(current_path)
	dialog.set_dialog_mode(0)
	dialog.fill_mix_files(["label_settings"])


func _update_name_config(path: String) -> void:
	options.name_config_path = path
	_update_name_config_text()


func _update_name_config_text() -> void:
	var node = %NameConfig
	if options.name_config_path:
		var path = options.name_config_path.get_file().replace(
			"." + options.name_config_path.get_extension(),
			""
		)
		node.text = path
	else:
		node.text = tr("Select Config")


func _on_save_general_config_pressed() -> void:
	FileCache.options.event_general_options = {
		"show_name_in_map": options.show_name_in_map,
		"name_config_path": options.name_config_path
	}
	RPGEditorToast.show_message("Event general options setted as default")


func _on_save_extra_config_pressed() -> void:
	FileCache.options.event_extra_options = {
		"use_extra_config": options.use_extra_config,
		"is_inmortal": options.is_inmortal,
		"hp": options.hp,
		"enable_self_switch_on_hit_id": options.enable_self_switch_on_hit_id,
		"enable_self_switch_on_dead_id": options.enable_self_switch_on_dead_id
	}
	RPGEditorToast.show_message("Event extra options setted as default")


func _on_type_normal_event_toggled(toggled_on: bool) -> void:
	if not toggled_on or not options: return
	options.event_type = 0
	_refresh_type_params_visibility()


func _on_type_pickable_event_toggled(toggled_on: bool) -> void:
	if not toggled_on or not options: return
	options.event_type = 1
	_refresh_type_params_visibility()


func _on_type_moveable_event_toggled(toggled_on: bool) -> void:
	if not toggled_on or not options: return
	options.event_type = 2
	_refresh_type_params_visibility()


func _on_throw_strength_value_changed(value: float) -> void:
	if not options: return
	options.type_params.throw_strength = value


func _on_time_value_changed(value: float) -> void:
	if not options: return
	options.type_params.speed = value


func _on_initial_delay_value_changed(value: float) -> void:
	if not options: return
	options.type_params.initial_delay = value
