@tool
extends CommandBaseDialog


var image_selected: String = ""
var current_variables: Vector2i = Vector2i.ONE


func _ready() -> void:
	super()
	parameter_code = 75


func set_data() -> void:
	var image_id = parameters[0].parameters.get("index", 1)
	image_selected = parameters[0].parameters.get("path", "")
	var image_type = parameters[0].parameters.get("image_type", 0)
	var origin = parameters[0].parameters.get("origin", 0)
	var position_type = parameters[0].parameters.get("position_type", 0)
	var pos: Vector2
	if position_type == 0:
		pos = parameters[0].parameters.get("position", Vector2.ZERO)
	else:
		pos = parameters[0].parameters.get("position", Vector2.ONE)
	var image_size = parameters[0].parameters.get("scale", Vector2.ONE) * 100
	var image_rotation = parameters[0].parameters.get("rotation", 0)
	var image_modulate = parameters[0].parameters.get("modulate", Color.WHITE)
	var image_blend_mix = parameters[0].parameters.get("blend_type", 0)
	
	var start_animation = parameters[0].parameters.get("start_animation", 0)
	var start_duration = parameters[0].parameters.get("start_animation_duration", 0.25)
	var end_animation = parameters[0].parameters.get("end_animation", 0)
	var end_duration = parameters[0].parameters.get("end_animation_duration", 0.25)
	
	var z_index = parameters[0].parameters.get("z_index", 1)
	var sort = parameters[0].parameters.get("enable_sort", true)
	
	%ImageID.value = image_id
	%ImagePath.text = image_selected.get_file() if image_selected else "Select Image"
	%ImageType.select(image_type if %ImageType.get_item_count() > image_type else 0)
	%Origin.select(origin if %Origin.get_item_count() > origin else 0)
	if position_type == 0:
		%ManualSettings.set_pressed(true)
		%PositionX.value = pos.x
		%PositionY.value = pos.y
	else:
		%VariableSettings.set_pressed(true)
		current_variables = Vector2i(pos)
	%SizeX.value = image_size.x
	%SizeY.value = image_size.y
	%Rotation.value = image_rotation
	%Modulate.set_color(image_modulate)
	%BlendMix.select(image_blend_mix if %BlendMix.get_item_count() > image_blend_mix else 0)
	
	%StartAnimation.select(start_animation if %StartAnimation.get_item_count() > start_animation else 0)
	%EndAnimation.select(end_animation if %EndAnimation.get_item_count() > end_animation else 0)
	
	%StartAnimationDuration.value = start_duration
	%EndAnimationDuration.value = end_duration
	
	%ZIndex.value = z_index
	%EnableSort.set_pressed(sort)
	
	%ZIndex.set_disabled(image_type == 1)
	%EnableSort.set_disabled(image_type == 1)
	
	update_variable_names()


func build_command_list() -> Array[RPGEventCommand]:
	var commands: Array[RPGEventCommand] = super()

	commands[-1].parameters.index = %ImageID.value
	commands[-1].parameters.path = image_selected
	commands[-1].parameters.image_type = %ImageType.get_selected_id()
	commands[-1].parameters.origin = %Origin.get_selected_id()
	commands[-1].parameters.position_type = 0 if %ManualSettings.is_pressed() else 1
	if commands[-1].parameters.position_type == 0:
		commands[-1].parameters.position = Vector2(%PositionX.value, %PositionY.value)
	else:
		commands[-1].parameters.position = current_variables
	commands[-1].parameters.scale = Vector2(%SizeX.value, %SizeY.value) / 100.0
	commands[-1].parameters.rotation = %Rotation.value
	commands[-1].parameters.modulate = %Modulate.get_color()
	commands[-1].parameters.blend_type = %BlendMix.get_selected_id()
	commands[-1].parameters.start_animation = %StartAnimation.get_selected_id()
	commands[-1].parameters.end_animation = %EndAnimation.get_selected_id()
	commands[-1].parameters.start_animation_duration = %StartAnimationDuration.value
	commands[-1].parameters.end_animation_duration = %EndAnimationDuration.value
	commands[-1].parameters.z_index = %ZIndex.value
	commands[-1].parameters.enable_sort = %EnableSort.is_pressed()
	
	return commands


func _on_image_path_pressed() -> void:
	var path = "res://addons/CustomControls/Dialogs/select_file_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	
	await get_tree().process_frame
	
	dialog.destroy_on_hide = true
	dialog.target_callable = _update_image
	dialog.set_file_selected(image_selected)
	dialog.set_dialog_mode(0)
	
	dialog.fill_mix_files(["images"])


func _update_image(path: String) -> void:
	image_selected = path
	%ImagePath.text = path.get_file()


func _on_manual_settings_toggled(toggled_on: bool) -> void:
	%ManualPositionContainer.propagate_call("set_disabled", [!toggled_on])


func _on_variable_settings_toggled(toggled_on: bool) -> void:
	%VariablePositionContainer.propagate_call("set_disabled", [!toggled_on])


func _on_modulate_pressed() -> void:
	var path = "res://addons/CustomControls/Dialogs/select_color.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	
	dialog.title = TranslationManager.tr("Select Image Modulation Color")
	dialog.color_selected.connect(_on_modulate_color_selected)
	dialog.set_color(%Modulate.get_color())


func _on_modulate_color_selected(color: Color) -> void:
	%Modulate.set_color(color)


func select_variable_dialog(target: String) -> void:
	var path = "res://addons/CustomControls/Dialogs/switch_variable_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	dialog.data_type = 0
	dialog.target = target
	dialog.selected.connect(select_variable)
	dialog.variable_or_switch_name_changed.connect(update_variable_names)
	var id_selected: int = current_variables.x if target == "x" else current_variables.y
	dialog.setup(id_selected)


func select_variable(id: int, target: String) -> void:
	if target == "x":
		current_variables.x = id
	else:
		current_variables.y = id
	update_variable_names()


func update_variable_names() -> void:
	var variable_x_name = "%s:%s" % [
		str(current_variables.x).pad_zeros(4),
		RPGSYSTEM.system.variables.get_item_name(current_variables.x)
	]
	var variable_y_name = "%s:%s" % [
		str(current_variables.y).pad_zeros(4),
		RPGSYSTEM.system.variables.get_item_name(current_variables.y)
	]
	%VariableX.text = variable_x_name
	%VariableY.text = variable_y_name


func _on_variable_x_pressed() -> void:
	select_variable_dialog("x")


func _on_variable_y_pressed() -> void:
	select_variable_dialog("y")


func _on_start_animation_item_selected(index: int) -> void:
	%StartAnimationDuration.set_disabled(index == 0)


func _on_end_animation_item_selected(index: int) -> void:
	%EndAnimationDuration.set_disabled(index == 0)


func _on_image_type_item_selected(index: int) -> void:
	%ZIndex.set_disabled(index == 1)
	%EnableSort.set_disabled(index == 1)


func _on_visual_config_pressed() -> void:
	if %ImageType.get_selected_id() == 0: # Map Image
		_select_coord_in_map()
	else:
		_select_coord_in_screen()


func _select_coord_in_screen() -> void:
	var path = "res://addons/CustomControls/Dialogs/fit_rect_in_screen_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	
	var rect = Rect2(%PositionX.value, %PositionY.value, 32, 32)
	var tex = null if not ResourceLoader.exists(image_selected) else load(image_selected)
	
	var margin = 20
	var max_area = Vector2(1152, 640)
	
	if tex:
		rect.size = tex.get_size() * Vector2(%SizeX.value / 100.0, %SizeY.value / 100.0)
		if rect.size.x > max_area.x or rect.size.y > max_area.y:
			var scale_x = max_area.x / rect.size.x
			var scale_y = max_area.y / rect.size.y
			var scale = min(scale_x, scale_y)
			rect.size = rect.size * scale
	
	if %Origin.get_selected_id() == 0: # is centered
		rect.position.x -= rect.size.x / 2.0
		rect.position.y -= rect.size.y / 2.0
	
	if rect.position.x < -margin:
		rect.position.x = -margin
	elif rect.position.x > max_area.x + margin:
		rect.position.x = max_area.x + margin

	if rect.position.y < -margin:
		rect.position.y = -margin
	elif rect.position.y > max_area.y + margin:
		rect.position.y = max_area.y + margin
	
	dialog.hide_top_container()
	dialog.set_rect(rect)
	dialog.set_image(tex)
	dialog.set_flips(false, false)
	dialog.set_aspect_ratio(true)
	
	dialog.rect_changed.connect(
		func(rect: Rect2, _horizontal_flip: bool, _vertical_flip: bool, _aspect_ratio: bool):
			%PositionX.value = rect.position.x
			%PositionY.value = rect.position.y
			if %Origin.get_selected_id() == 0: # is centered
				%PositionX.value += rect.size.x / 2
				%PositionY.value += rect.size.y / 2
			if tex:
				%SizeX.value = rect.size.x / tex.get_width() * 100.0
				%SizeY.value = rect.size.y / tex.get_height() * 100.0
	)


func _select_coord_in_map() -> void:
	var map_id: int
	var tile_size: Vector2i
	if Engine.is_editor_hint() and EditorInterface.get_edited_scene_root() is RPGMap:
		var map: RPGMap = EditorInterface.get_edited_scene_root()
		map_id = map.internal_id
		tile_size = map.tile_size
	else:
		printerr("To select the position on the map, you must be in an RPGMap scene.")
		return
		
	var path = "res://addons/CustomControls/Dialogs/CommandEvents/select_map_position_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	
	dialog.restrict_position_to_terrain.clear()
	dialog.set_terrain_restrictions(PackedStringArray([]))
	
	var initial_position = Vector2i(%PositionX.value, %PositionY.value)
	initial_position /= tile_size
	var map_path = RPGMapsInfo.get_map_by_id(map_id)
	dialog.set_start_map(map_path, initial_position)
	dialog.hide_map_list()

	dialog.cell_selected.connect(
		func(_map_id: int, cell_position: Vector2i):
			%PositionX.value = cell_position.x * tile_size.x
			%PositionY.value = cell_position.y * tile_size.y
	)
