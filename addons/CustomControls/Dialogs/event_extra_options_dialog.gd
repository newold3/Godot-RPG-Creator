@tool
extends Window

var real_options: RPGEventPageOptions
var options: RPGEventPageOptions
var is_pressed_mode: bool = false

var _hot_reload_timer: Timer
var _udp_peer: PacketPeerUDP

signal OK(new_pressed_state: bool)


func _ready() -> void:
	close_requested.connect(queue_free)
	_fill_self_switches()
	_fill_trigger_lift_options()
	
	_udp_peer = PacketPeerUDP.new()
	_udp_peer.set_dest_address("127.0.0.1", 4242)
	
	_hot_reload_timer = Timer.new()
	_hot_reload_timer.wait_time = 0.1
	_hot_reload_timer.one_shot = true
	_hot_reload_timer.timeout.connect(_send_hot_reload_packet)
	add_child(_hot_reload_timer)
	
	await get_tree().process_frame
	CustomTooltipManager.replace_all_tooltips_with_custom.call_deferred(self)


func _send_hot_reload_packet() -> void:
	if not options: return
	
	var data: Dictionary
	
	if options.event_type == 1:
		data = {
			"type": "update_carry_offsets",
			"map_id": -1,
			"offsets": {
				"offset_left_x": options.type_params.get("offset_left_x", 0),
				"offset_left_y": options.type_params.get("offset_left_y", 0),
				"offset_right_x": options.type_params.get("offset_right_x", 0),
				"offset_right_y": options.type_params.get("offset_right_y", 0),
				"offset_up_x": options.type_params.get("offset_up_x", 0),
				"offset_up_y": options.type_params.get("offset_up_y", 0),
				"offset_down_x": options.type_params.get("offset_down_x", 0),
				"offset_down_y": options.type_params.get("offset_down_y", 0)
			},
			"fxs": {
				"lift_fx": options.type_params.get("lift_fx", {}),
				"throw_fx": options.type_params.get("throw_fx", {})
			},
			"throw_strength": options.type_params.throw_strength
		}
	elif options.event_type == 2:
		data = {
			"type": "update_push_offsets",
			"map_id": -1,
			"offsets": {
				"push_offset_left_x": options.type_params.get("push_offset_left_x", 0),
				"push_offset_left_y": options.type_params.get("push_offset_left_y", 0),
				"push_offset_right_x": options.type_params.get("push_offset_right_x", 0),
				"push_offset_right_y": options.type_params.get("push_offset_right_y", 0),
				"push_offset_up_x": options.type_params.get("push_offset_up_x", 0),
				"push_offset_up_y": options.type_params.get("push_offset_up_y", 0),
				"push_offset_down_x": options.type_params.get("push_offset_down_x", 0),
				"push_offset_down_y": options.type_params.get("push_offset_down_y", 0)
			},
			"fxs": {
				"push_fx": options.type_params.get("push_fx", {})
			}
		}
	
	if data:
		var json_string = JSON.stringify(data)
		_udp_peer.put_packet(json_string.to_utf8_buffer())


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


func _fill_trigger_lift_options() -> void:
	var node = %ActivationPageTrigger
	node.clear()
	
	node.add_item(tr("Never"), 0)
	
	var names = {
		1: tr("Pre-Lift"),
		2: tr("Post-Lift"),
		4: tr("Pre-Throw"),
		8: tr("Post-Throw")
	}
	
	var basics: Array = []
	var combos: Array = []
	
	for i in range(1, 16):
		var combo_name = ""
		var is_first = true
		var bits_count = 0
		
		for bit in [1, 2, 4, 8]:
			if (i & bit) != 0:
				bits_count += 1
				if not is_first:
					combo_name += " + "
				combo_name += names[bit]
				is_first = false
		
		if bits_count == 1:
			basics.append({"name": combo_name, "id": i})
		else:
			combos.append({"name": combo_name, "id": i})
			
	for opt in basics:
		node.add_item(opt.name, opt.id)
		
	combos.sort_custom(func(a, b): return a.name < b.name)
	
	for opt in combos:
		node.add_item(opt.name, opt.id)


func set_page_options(_options: RPGEventPageOptions, _is_pressed: bool = false) -> void:
	real_options = _options
	options = _options.clone()
	is_pressed_mode = _is_pressed
		
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
	
	%OffsetLeftX.value = options.type_params.get("offset_left_x", -25)
	%OffsetLeftY.value = options.type_params.get("offset_left_y", 1)
	%OffsetRightX.value = options.type_params.get("offset_right_x", -25)
	%OffsetRightY.value = options.type_params.get("offset_right_y", 1)
	%OffsetUpX.value = options.type_params.get("offset_up_x", -25)
	%OffsetUpY.value = options.type_params.get("offset_up_y", 1)
	%OffsetDownX.value = options.type_params.get("offset_down_x", -25)
	%OffsetDownY.value = options.type_params.get("offset_down_y", 1)
	%LiftRotation.value = options.type_params.get("lift_rotation", 90)
	
	%PushOffsetLeftX.value = options.type_params.get("push_offset_left_x", -25)
	%PushOffsetLeftY.value = options.type_params.get("push_offset_left_y", 1)
	%PushOffsetRightX.value = options.type_params.get("push_offset_right_x", -25)
	%PushOffsetRightY.value = options.type_params.get("push_offset_right_y", 1)
	%PushOffsetUpX.value = options.type_params.get("push_offset_up_x", -25)
	%PushOffsetUpY.value = options.type_params.get("push_offset_up_y", 1)
	%PushOffsetDownX.value = options.type_params.get("push_offset_down_x", -25)
	%PushOffsetDownY.value = options.type_params.get("push_offset_down_y", 1)
	
	%AnimationType.select(options.type_params.get("animation_type", 0))
	%CanThrowOverObstacles.select(options.type_params.get("can_throw_over_obstacles", 0))
	
	var act_page_val = options.type_params.get("activation_page_type", 0)
	var act_page_idx = 0
	
	for i in range(%ActivationPageTrigger.item_count):
		if %ActivationPageTrigger.get_item_id(i) == act_page_val:
			act_page_idx = i
			break
	
	%ActivationPageTrigger.select(act_page_idx)
	
	%CanCarryToOtherMaps.select(
		0 if options.type_params.get("can_carry_to_other_maps", false) \
		else 1
	)
	
	lift_image_changed()
	
	_update_fx_text("lift_fx")
	_update_fx_text("throw_fx")
	_update_fx_text("push_fx")


func _setup_event_type_ui() -> void:
	%TypePickableEvent.tooltip_text = tr("Disables Pressed Mode.\nForces 'Action Button' trigger.\nForces NOT Passable.")
	%TypeMoveableEvent.tooltip_text = tr("Disables Pressed Mode.\nForces 'Action Button' trigger.\nForces NOT Passable.")
	%TypeNormalEvent.tooltip_text = tr("Standard Event Mode.")
	
	match options.event_type:
		0: %TypeNormalEvent.button_pressed = true
		1: %TypePickableEvent.button_pressed = true
		2: %TypeMoveableEvent.button_pressed = true

	_refresh_type_params_visibility()


func _refresh_type_params_visibility() -> void:
	%PickableParams.visible = (options.event_type == 1)
	%MoveableParams.visible = (options.event_type == 2)
	%NoParams.visible = (options.event_type == 0)
	
	var title_color = Color("#a2a2a2") if options.event_type == 0 else Color("#a0fec3")
	%ParamsTitle.set("theme_override_colors/font_color", title_color)
	
	size.y = 0


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

	OK.emit(is_pressed_mode)
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


func _on_type_lifttable_event_toggled(toggled_on: bool) -> void:
	if not toggled_on or not options: return
	options.event_type = 1
	is_pressed_mode = false
	_refresh_type_params_visibility()


func _on_type_moveable_event_toggled(toggled_on: bool) -> void:
	if not toggled_on or not options: return
	options.event_type = 2
	is_pressed_mode = false
	_refresh_type_params_visibility()


func _on_throw_strength_value_changed(value: float) -> void:
	if not options: return
	options.type_params.throw_strength = value
	_hot_reload_timer.start()


func _on_time_value_changed(value: float) -> void:
	if not options: return
	options.type_params.time = value


func _on_initial_delay_value_changed(value: float) -> void:
	if not options: return
	options.type_params.initial_delay = value


func _on_offset_left_x_value_changed(value: float) -> void:
	if not options: return
	options.type_params.offset_left_x = value
	_hot_reload_timer.start()


func _on_offset_left_y_value_changed(value: float) -> void:
	if not options: return
	options.type_params.offset_left_y = value
	_hot_reload_timer.start()


func _on_offset_right_x_value_changed(value: float) -> void:
	if not options: return
	options.type_params.offset_right_x = value
	_hot_reload_timer.start()


func _on_offset_right_y_value_changed(value: float) -> void:
	if not options: return
	options.type_params.offset_right_y = value
	_hot_reload_timer.start()


func _on_offset_up_x_value_changed(value: float) -> void:
	if not options: return
	options.type_params.offset_up_x = value
	_hot_reload_timer.start()


func _on_offset_up_y_value_changed(value: float) -> void:
	if not options: return
	options.type_params.offset_up_y = value
	_hot_reload_timer.start()


func _on_offset_down_x_value_changed(value: float) -> void:
	if not options: return
	options.type_params.offset_down_x = value
	_hot_reload_timer.start()


func _on_offset_down_y_value_changed(value: float) -> void:
	if not options: return
	options.type_params.offset_down_y = value
	_hot_reload_timer.start()


func _on_lift_rotation_value_changed(value: float) -> void:
	if not options: return
	options.type_params.lift_rotation = value
	_hot_reload_timer.start()


func _on_lift_image_clicked() -> void:
	var path = "res://addons/CustomControls/Dialogs/select_icon_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	
	var img: RPGIcon
	if options.type_params.has("lift_image"):
		img = options.type_params.lift_image
	else:
		img = RPGIcon.new()
		options.type_params.lift_image = img
		
	dialog.set_data(img)
	
	dialog.icon_changed.connect(lift_image_changed)


func lift_image_changed() -> void:
	var icon = options.type_params.get("lift_image", RPGIcon.new())
	%LiftImage.set_icon(icon.path, icon.region)


func _on_lift_image_paste_requested(icon: String, region: Rect2) -> void:
	var img = RPGIcon.new(icon, region)
	options.type_params.lift_image = img
	%LiftImage.set_icon(img.path, img.region)


func _on_lift_image_remove_requested() -> void:
	options.type_params.lift_image = RPGIcon.new()
	%LiftImage.clear()


func _on_animation_type_item_selected(index: int) -> void:
	options.type_params.animation_type = index


func _on_can_throw_over_obstacles_item_selected(index: int) -> void:
	options.type_params.can_throw_over_obstacles = index


func open_sound_dialog(id: String) -> void:
	var path = "res://addons/CustomControls/Dialogs/select_sound_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	
	var sound: Dictionary = options.type_params.get(id, {})
	
	var commands: Array[RPGEventCommand]
	var command = RPGEventCommand.new(0, 0, sound)
	commands.append(command)
	dialog.enable_random_pitch()
	dialog.set_parameters(commands)
	dialog.set_data()
	
	dialog.command_changed.connect(
		func(commands: Array[RPGEventCommand]):
			var c = commands[0].parameters
			_on_sound_selected(c.path, c.volume, c.pitch, c.pitch2, id)
	)


func _on_sound_selected(path: String, volume: float, pitch: float, pitch2: float, id: String) -> void:
	options.type_params[id] = {"path": path, "volume": volume, "pitch": pitch, "pitch2": pitch2}
	
	_update_fx_text(id)
	_hot_reload_timer.start()


func _update_fx_text(id: String) -> void:
	var fx = options.type_params.get(id, {})
	var f = fx.get("path", "")
	var node: Control
	if id == "lift_fx":
		node = %LiftFx
	elif id == "throw_fx":
		node = %ThrowFx
	elif id == "push_fx":
		node = %PushFx
	if node:
		node.text = tr("Select file") if f.is_empty() else f.get_file()


func _on_lift_fx_pressed() -> void:
	open_sound_dialog("lift_fx")


func _on_throw_fx_pressed() -> void:
	open_sound_dialog("throw_fx")


func _on_push_offset_left_x_value_changed(value: float) -> void:
	if not options: return
	options.type_params.push_offset_left_x = value
	_hot_reload_timer.start()


func _on_push_offset_left_y_value_changed(value: float) -> void:
	if not options: return
	options.type_params.push_offset_left_y = value
	_hot_reload_timer.start()


func _on_push_offset_right_x_value_changed(value: float) -> void:
	if not options: return
	options.type_params.push_offset_right_x = value
	_hot_reload_timer.start()


func _on_push_offset_right_y_value_changed(value: float) -> void:
	if not options: return
	options.type_params.push_offset_right_y = value
	_hot_reload_timer.start()


func _on_push_offset_up_x_value_changed(value: float) -> void:
	if not options: return
	options.type_params.push_offset_up_x = value
	_hot_reload_timer.start()


func _on_push_offset_up_y_value_changed(value: float) -> void:
	if not options: return
	options.type_params.push_offset_up_y = value
	_hot_reload_timer.start()


func _on_push_offset_down_x_value_changed(value: float) -> void:
	if not options: return
	options.type_params.push_offset_down_x = value
	_hot_reload_timer.start()


func _on_push_offset_down_y_value_changed(value: float) -> void:
	if not options: return
	options.type_params.push_offset_down_y = value
	_hot_reload_timer.start()


func _on_push_fx_pressed() -> void:
	open_sound_dialog("push_fx")


func _on_activation_page_trigger_item_selected(index: int) -> void:
	options.type_params.activation_page_type = %ActivationPageTrigger.get_item_id(index)


func _on_can_carry_to_other_maps_item_selected(index: int) -> void:
	if not options: return
	options.type_params.can_carry_to_other_maps = index == 0
