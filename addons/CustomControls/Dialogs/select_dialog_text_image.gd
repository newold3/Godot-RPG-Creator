@tool
extends Window


var current_image: RPGIcon
static var chain_size: bool = true
var busy: bool = false
var need_fix_size_timer: float = 0.0


signal image_selected(img: Dictionary)


func _ready() -> void:
	close_requested.connect(queue_free)
	%ChainSize.set_pressed(chain_size)
	%PasteParameters.set_disabled(StaticEditorVars.CLIPBOARD.get("text_image_configuration", null) == null)


func _process(delta: float) -> void:
	if need_fix_size_timer > 0:
		need_fix_size_timer -= delta
		if need_fix_size_timer <= 0:
			need_fix_size_timer = 0


func set_data(img: Dictionary) -> void:
	var current_file
	busy = true

	if "image_type" in img:
		img.image_type = clamp(img.image_type, 0, %ImageType.get_item_count() - 1)
		%ImageType.select(img.image_type)
		%ImageType.item_selected.emit(img.image_type)
		%ExtraControls0.visible = img.image_type == 0
		%ExtraControls1.visible = img.image_type == 1
		%ExtraControls2.visible = true
		%ExtraControls3.visible = img.image_type == 0 or img.image_type == 1
		
	if "path" in img:
		current_image = img.path if img.path is RPGIcon else RPGIcon.new()
		%Filename.text = TranslationManager.tr("Select Image File") if !current_image.path else current_image.path
		if ResourceLoader.exists(current_image.path):
			current_file = ResourceLoader.load(current_image.path)
			if current_file is PackedScene:
				current_file = current_file.instantiate()
				if current_file is TextureRect:
					current_file = current_file.texture
				else:
					current_file = null
	else:
		current_image = RPGIcon.new()
			
	if "image_id" in img: %ImageID.value = img.image_id
	
	if "start_position" in img:
		img.start_position = clamp(img.start_position, 0, %ImagePosition.get_item_count() - 1)
		%ImagePosition.select(img.start_position)
	else:
		%ImagePosition.select(0)
	
	if "image_offset" in img:
		%OffsetX.value = img.image_offset.x
		%OffsetY.value = img.image_offset.y
	else:
		%OffsetX.value = 0
		%OffsetY.value = 0
	
	if "idle_animation" in img:
		img.idle_animation = clamp(img.idle_animation, 0, %IdleAnimation.get_item_count() - 1)
		%IdleAnimation.select(img.idle_animation)
	else:
		%IdleAnimation.select(0)
		
	if "face_position" in img:
		img.face_position = clamp(img.face_position, 0, %FacePosition.get_item_count() - 1)
		%FacePosition.select(img.face_position)
	else:
		%FacePosition.select(0)
		
	if "width" in img:
		if img.width == 0 and current_file:
			%Width.value = current_file.get_width()
		else:
			%Width.value = img.width
	elif current_file:
		%Width.value = current_file.get_width()
		
	if "height" in img:
		if img.height == 0 and current_file:
			%Height.value = current_file.get_height()
		else:
			%Height.value = img.height
	elif current_file:
		%Height.value = current_file.get_height()
	
	var t = %CharacterTransitionType if "image_type" in img and img.image_type == 1 else %FaceTransitionType
	if "trans_type" in img:
		img.trans_type = clamp(img.trans_type, 0, t.get_item_count() - 1)
		t.select(img.trans_type)
	else:
		t.select(1)
	
	if "trans_type_end" in img and img.image_type == 1:
		t = %CharacterEndTransitionType
		img.trans_type_end = clamp(img.get("trans_type_end", 0), 0, t.get_item_count() - 1)
		t.select(img.trans_type_end)
	
	%TransitionEndTime.value = img.get("trans_end_time", 0)
	
	if "trans_time" in img: %TransitionTime.value = img.trans_time
	
	if "trans_wait" in img: %Wait.set_pressed(img.trans_wait == 1)
	
	%HorizontalFlip.set_pressed(img.get("flip_h", 0) == 1)
	%VerticalFlip.set_pressed(img.get("flip_v", 0) == 1)
	
	if "image_type" in img:
		%EraseDefaultConfig.set_disabled(img.image_type != 1 or not _has_default_config())
	else:
		%EraseDefaultConfig.set_disabled(true)
	
	if "character_linked_to" in img:
		var character_linked_to = clamp(img.character_linked_to, 0, %CharacterLinkedTo.get_item_count() - 1)
		%CharacterLinkedTo.select(character_linked_to)
	else:
		%CharacterLinkedTo.select(0)
	
	busy = false


func set_face_mode() -> void:
	title = "Select Face Image"
	%ImageType.select(0)
	_on_image_type_item_selected(0)
	%ImageType.set_disabled(true)
	%ImageType.get_parent().visible = false


func set_character_mode() -> void:
	title = "Select Character Image"
	%ImageType.select(1)
	_on_image_type_item_selected(1)
	%ImageType.set_disabled(true)
	%ImageType.get_parent().visible = false


func _on_ok_button_pressed() -> void:
	busy = true
	propagate_call("apply")
	busy = false
	var t = %CharacterTransitionType if %ImageType.get_selected_id() == 1 else %FaceTransitionType
	var img = {
		"image_type": %ImageType.get_selected_id(),
		"path": current_image,
		"image_id": %ImageID.value,
		"start_position": %ImagePosition.get_selected_id(),
		"image_offset": Vector2i(%OffsetX.value, %OffsetY.value),
		"idle_animation": %IdleAnimation.get_selected_id(),
		"width": %Width.value if %ExtraControls2.visible else 0,
		"height": %Height.value if %ExtraControls2.visible else 0,
		"face_position": %FacePosition.get_selected_id(),
		"trans_type": t.get_selected_id(),
		"trans_type_end": %CharacterEndTransitionType.get_selected_id(),
		"trans_end_time": %TransitionEndTime.value,
		"trans_time": %TransitionTime.value,
		"trans_wait": 1 if %Wait.is_pressed() else 0,
		"flip_h": 1 if %HorizontalFlip.is_pressed() else 0,
		"flip_v": 1 if %VerticalFlip.is_pressed() else 0,
		"character_linked_to": %CharacterLinkedTo.get_selected_id()
	}
	if ResourceLoader.exists(img.path.path):
		var file = ResourceLoader.load(img.path.path)
		if file is PackedScene:
			file = file.instantiate()
			if file is TextureRect:
				file = file.texture
			else:
				file = null
		if file and img.width == file.get_width() and img.height == file.get_height():
			img.width = 0
			img.height = 0
	image_selected.emit(img)
	queue_free()


func _on_cancel_button_pressed() -> void:
	queue_free()


func _on_filename_pressed() -> void:
	if not current_image:
		current_image = RPGIcon.new()
	if %ImageType.get_selected_id() == 0:
		var path = "res://addons/CustomControls/Dialogs/select_icon_dialog.tscn"
		var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
		dialog.set_data(current_image)
		
		dialog.icon_changed.connect(update_face)
	else:
		open_file_dialog(_on_image_selected, current_image.path)


func hide_size() -> void:
	%ExtraControls2.visible = false


func update_face() -> void:
	%Filename.text = TranslationManager.tr("Select Image File") if !current_image.path else current_image.path


func _on_image_selected(path: String) -> void:
	current_image.path = path
	%Filename.text = TranslationManager.tr("Select Image File") if !path else path
	if ResourceLoader.exists(path):
		var file = ResourceLoader.load(path)
		if file is PackedScene:
			file = file.instantiate()
			if file is TextureRect:
				file = file.texture
			else:
				file = null
		if file:
			busy = true
			_restore_default_config()
			busy = false


func open_file_dialog(callable: Callable, file_selected_path: String = "", type: Variant = "") -> Window:
	var path = "res://addons/CustomControls/Dialogs/select_file_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	await get_tree().process_frame
	
	dialog.destroy_on_hide = true
	dialog.target_callable = callable
	dialog.set_dialog_mode(0)
	
	if file_selected_path:
		dialog.set_file_selected(file_selected_path)
	
	dialog.fill_files("images")
	
	return dialog


func _on_image_type_item_selected(index: int) -> void:
	%ExtraControls0.visible = index == 0
	%ExtraControls1.visible = index == 1
	%ExtraControls2.visible = index != 0
	%ExtraControls3.visible = index == 0 or index == 1
	%CharacterTransitionType.visible = index == 1
	%EndTransitionContainer.visible = index == 1
	%FaceTransitionType.visible = index == 0
	size.y = 0
	need_fix_size_timer = 0.04


func _on_chain_size_toggled(toggled_on: bool) -> void:
	chain_size = toggled_on


func _on_width_value_updated(old_value: float, new_value: float) -> void:
	if busy: return
	if chain_size:
		busy = true
		if old_value != 0 and %Height.value != 0:
			var ratio: float = new_value / old_value
			%Height.value = %Height.value * ratio
		elif %Height.value == 0:
			%Height.value = %Width.value
		busy = false


func _on_height_value_updated(old_value: float, new_value: float) -> void:
	if busy: return
	if chain_size:
		busy = true
		if old_value != 0 and %Width.value != 0:
			var ratio: float = new_value / old_value
			%Width.value = %Width.value * ratio
		elif %Width.value == 0:
			%Width.value = %Height.value
		busy = false


func _on_copy_parameters_pressed() -> void:
	busy = true
	propagate_call("apply")
	busy = false
	
	var t = %CharacterTransitionType if %ImageType.get_selected_id() == 1 else %FaceTransitionType
	var img = {
		"image_type": %ImageType.get_selected_id(),
		"path": current_image,
		"image_id": %ImageID.value,
		"start_position": %ImagePosition.get_selected_id(),
		"image_offset": Vector2i(%OffsetX.value, %OffsetY.value),
		"idle_animation": %IdleAnimation.get_selected_id(),
		"width": %Width.value,
		"height": %Height.value,
		"face_position": %FacePosition.get_selected_id(),
		"trans_type": t.get_selected_id(),
		"trans_type_end": %CharacterEndTransitionType.get_selected_id(),
		"trans_end_time": %TransitionEndTime.value,
		"trans_time": %TransitionTime.value,
		"trans_wait": 1 if %Wait.is_pressed() else 0,
		"flip_h": 1 if %HorizontalFlip.is_pressed() else 0,
		"flip_v": 1 if %VerticalFlip.is_pressed() else 0,
		"character_linked_to": %CharacterLinkedTo.get_selected_id()
	}
	
	StaticEditorVars.CLIPBOARD.text_image_configuration = img
	%PasteParameters.set_disabled(false)


func _on_paste_parameters_pressed() -> void:
	var img = StaticEditorVars.CLIPBOARD.get("text_image_configuration", null)
	if img:
		set_data(img)


func _on_select_position_and_size_pressed() -> void:
	var path = "res://addons/CustomControls/Dialogs/fit_rect_in_screen_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	
	var rect = Rect2(%OffsetX.value, %OffsetY.value, %Width.value, %Height.value)
	var tex = null if not ResourceLoader.exists(current_image.path) else load(current_image.path)
	if tex and current_image.region:
		var atlas_tex := AtlasTexture.new()
		atlas_tex.atlas = tex
		atlas_tex.region = current_image.region_rect
		tex = atlas_tex
		
	
	var margin = 20
	var max_area = Vector2(1152, 640)
	
	if rect.size == Vector2.ZERO and tex:
		rect.size = tex.get_size()
		if rect.size.x > max_area.x or rect.size.y > max_area.y:
			var scale_x = max_area.x / rect.size.x
			var scale_y = max_area.y / rect.size.y
			var scale = min(scale_x, scale_y)
			rect.size = rect.size * scale
	
	if rect.position.x < -margin:
		rect.position.x = -margin
	elif rect.position.x > max_area.x + margin:
		rect.position.x = max_area.x + margin

	if rect.position.y < -margin:
		rect.position.y = -margin
	elif rect.position.y > max_area.y + margin:
		rect.position.y = max_area.y + margin
	
	dialog.set_flips(%HorizontalFlip.is_pressed(), %VerticalFlip.is_pressed())
	dialog.set_rect(rect)
	dialog.set_image(tex)
	dialog.set_aspect_ratio(chain_size)
	
	dialog.rect_changed.connect(
		func(rect: Rect2, horizontal_flip: bool, vertical_flip: bool, aspect_ratio: bool):
			var old_chain_size = chain_size
			chain_size = false
			%OffsetX.value = rect.position.x
			%OffsetY.value = rect.position.y
			%Width.value = rect.size.x
			%Height.value = rect.size.y
			%HorizontalFlip.set_pressed(horizontal_flip)
			%VerticalFlip.set_pressed(vertical_flip)
			%ChainSize.set_pressed(aspect_ratio)
			%ImagePosition.select(%ImagePosition.get_item_count() - 1)
			chain_size = old_chain_size
	)


func _has_default_config() -> bool:
	var path = current_image.path
	var data = RPGSYSTEM.database.system.message_image_positions
	return path in data


func _on_set_default_config_pressed() -> void:
	var path = current_image.path
	if ResourceLoader.exists(path):
		var data = RPGSYSTEM.database.system.message_image_positions
		data[path] = {
			"horizontal_flip": %HorizontalFlip.is_pressed(),
			"Vertical_flip": %VerticalFlip.is_pressed(),
			"start_position": %ImagePosition.get_selected_id(),
			"offset": {"x": %OffsetX.value, "y": %OffsetY.value},
			"idle_animation": %IdleAnimation.get_selected_id(),
			"size": {"x": %Width.value, "y": %Height.value},
			"start_transition": %CharacterTransitionType.get_selected_id(),
			"transition_start_time": %TransitionTime.value,
			"end_transition": %CharacterEndTransitionType.get_selected_id(),
			"transition_end_time": %TransitionEndTime.value,
			"wait_to_finish": %Wait.is_pressed()
		}
	%EraseDefaultConfig.set_disabled(false)


func _restore_default_config() -> void:
	var path = current_image.path
	var data = RPGSYSTEM.database.system.message_image_positions
	if path in data:
		var config = data[path]
		busy = true

		%HorizontalFlip.set_pressed_no_signal(config.get("horizontal_flip", false))
		%VerticalFlip.set_pressed_no_signal(config.get("Vertical_flip", false))
		%ImagePosition.select(config.get("start_position", 0))
		
		var offset = config.get("offset", {"x": 0, "y": 0})
		%OffsetX.value = offset.get("x", 0)
		%OffsetY.value = offset.get("y", 0)
		
		%IdleAnimation.select(config.get("idle_animation", 0))
		
		var size = config.get("size", {"x": 64, "y": 64})
		%Width.value = size.get("x", 64)
		%Height.value = size.get("y", 64)
		
		%CharacterTransitionType.select(config.get("start_transition", 0))
		%TransitionTime.value = config.get("transition_start_time", 0.0)
		
		%CharacterEndTransitionType.select(config.get("end_transition", 0))
		%TransitionEndTime.value = config.get("transition_end_time", 0.0)
		
		%Wait.set_pressed_mo_signal(config.get("wait_to_finish", false))
		
		busy = false
		%EraseDefaultConfig.set_disabled(false)
	else:
		%EraseDefaultConfig.set_disabled(true)


func _on_erase_default_config_pressed() -> void:
	var path = current_image.path
	var data = RPGSYSTEM.database.system.message_image_positions
	if path in data:
		data.erase(path)
	%EraseDefaultConfig.set_disabled(true)
