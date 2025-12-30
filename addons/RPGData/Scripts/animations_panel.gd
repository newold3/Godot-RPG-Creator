@tool
extends BasePanelData


var is_recording: bool = false
var recording: bool = false
var is_playing: bool = false
var current_frame: float = 0
var refresh_sound_list_timer = 0.0
var refresh_flash_list_timer = 0.0
var refresh_shake_list_timer = 0.0
var frames: Array = []
var audio_player_index: int = 1

var flash_tween: Tween
var flash_total_duration: float
var shake_tween: Tween
var shake_total_duration: float

var last_shake_direction := Vector2.ZERO
var shake_seed := 0.0

static var current_animation_enemy_image: String = ""
static var current_animation_background_image: String = ""

@onready var objetive_menu_list: PopupMenu = %ObjetiveMenuList


func _ready() -> void:
	super()
	default_data_element = RPGAnimation.new()
	var itemlist = %SoundList.get_item_list()
	itemlist.gui_input.connect(_on_sound_list_gui_input)
	itemlist = %FlashList.get_item_list()
	itemlist.gui_input.connect(_on_flash_list_gui_input)
	itemlist = %ShakeList.get_item_list()
	itemlist.gui_input.connect(_on_shake_list_gui_input)
	current_animation_enemy_image = "res://Assets/Images/Other/training_dummy.png"
	current_animation_background_image = "res://Assets/Images/Other/default_animation_background.png"
	%Target.texture = load(current_animation_enemy_image)
	%TargetShadow.texture = %Target.texture
	%AnimationBackgroundSprite.texture = load(current_animation_background_image)


func get_data() -> RPGAnimation:
	if data.size() > current_selected_index and current_selected_index != -1:
		current_selected_index = max(1, min(current_selected_index, data.size() - 1))
		return data[current_selected_index]
	return null


func _on_visibility_changed() -> void:
	super()
	if !visible:
		_stop_animations()
	else:
		%PlayAnimationButton.set_disabled(false)
		%ChangeEnemyButton.set_disabled(false)
		%ChangeBackgroundButton.set_disabled(false)


func _stop_animations() -> void:
	is_playing = false
	audio_player_index = 1
	%AudioStreamPlayer1.stop()
	%AudioStreamPlayer2.stop()
	%AudioStreamPlayer3.stop()
	if %EffekseerEmitter2D.is_playing():
		%EffekseerEmitter2D.stop()
	for child in %SceneAnimations.get_children():
		child.queue_free()
	%PlayAnimationButton.set_disabled(false)
	%ChangeEnemyButton.set_disabled(false)
	%ChangeBackgroundButton.set_disabled(false)


func _process(delta: float) -> void:
	var current_data = get_data()
	
	if is_playing:
		_update_animation()
	
	if refresh_sound_list_timer > 0.0:
		refresh_sound_list_timer -= delta
		if refresh_sound_list_timer <= 0:
			refresh_sound_list_timer = 0.0
			var s = current_data.sounds.size() - 1
			fill_sound_list(s if s > 0 else -1)
	
	if refresh_flash_list_timer > 0.0:
		refresh_flash_list_timer -= delta
		if refresh_flash_list_timer <= 0:
			refresh_flash_list_timer = 0.0
			var s = current_data.flashes.size() - 1
			fill_flash_list(s if s > 0 else -1)
			
	if refresh_shake_list_timer > 0.0:
		refresh_shake_list_timer -= delta
		if refresh_shake_list_timer <= 0:
			refresh_shake_list_timer = 0.0
			var s = current_data.shakes.size() - 1
			fill_shake_list(s if s > 0 else -1)


func _update_animation() -> void:
	var current_data = get_data()
	
	for sound: RPGAnimationSound in current_data.sounds:
		if sound.frame == current_frame:
			if ResourceLoader.exists(sound.filename):
				var node: AudioStreamPlayer = get_node_or_null("%%AudioStreamPlayer%s" % audio_player_index)
				if node:
					node.stop()
					node.stream = ResourceLoader.load(sound.filename)
					node.pitch_scale = randf_range(sound.pitch_min, sound.pitch_max)
					node.volume_db = sound.volume_db
					node.play()
					audio_player_index = wrapi(audio_player_index + 1, 1, 4)
	
	for flash: RPGAnimationFlash in current_data.flashes:
		var current_target = %AnimationTarget if flash.target == 0 else %ScreenFlash
		if flash.frame == current_frame:
			var duration = flash.duration
			flash_total_duration = duration * 2 + 0.1
			flash_tween = create_tween()
			
			if flash.target == 0: # Animation On Target
				var original_modulate = current_target.modulate
				flash_tween.tween_property(current_target, "modulate", flash.color, duration)
				flash_tween.tween_property(current_target, "modulate", original_modulate, duration)
			else: # Flash On Screen
				current_target.get_material().blend_mode = flash.screen_blend_type
				var original_modulate = current_target.color
				flash_tween.tween_property(current_target, "color", flash.color, duration)
				flash_tween.tween_property(current_target, "color", original_modulate, duration)
					
	
	for shake: RPGAnimationShake in current_data.shakes:
		if shake.frame == current_frame:
			var target = %AnimationTarget if shake.target == 0 else %FitContainer
			var magnitude = shake.amplitude
			var frequency = shake.frequency
			var duration =  shake.duration
			shake_total_duration = duration * 2 + 0.1
			var start_position = target.position
			var callable = _animate_shake.bind(target, magnitude, frequency, start_position)
			shake_tween = create_tween()
			shake_tween.tween_method(callable, 0.0, 1.0, duration)

	current_frame += 1


func _animate_shake(step: float, node: Node, magnitude: float, frequency: float, original_position: Vector2) -> void:
	shake_seed += 0.1
	
	var shake_amount = magnitude * (1.0 - step)
	
	var direction = Vector2.ZERO
	
	direction.x = sin(step * frequency * 15.7 + shake_seed * 3.3) * cos(step * frequency * 9.3 + shake_seed * 2.1)
	direction.y = cos(step * frequency * 12.2 + shake_seed * 4.7) * sin(step * frequency * 5.6 + shake_seed * 1.9)
	
	if direction.length() > 0.1:
		direction = direction.normalized()
	
	if last_shake_direction.dot(direction) > 0.7:
		direction = -direction
	
	var x_offset = sign(direction.x) * ceil(abs(direction.x * shake_amount))
	var y_offset = sign(direction.y) * ceil(abs(direction.y * shake_amount))
	
	var motion = Vector2(x_offset, y_offset)
	
	if "shake" in node:
		node.shake(motion)
	else:
		node.position = original_position + motion
	

	last_shake_direction = direction


func fill_sound_list(select_index: int = -1) -> void:
	var list = %SoundList
	list.clear()
	
	var current_data = get_data()
	
	for sound: RPGAnimationSound in current_data.sounds:
		var column = [
			str(sound.frame),
			sound.filename.get_file(),
			str(snapped(sound.volume_db, 0.01))
		]
		if sound.pitch_min == sound.pitch_max:
			column.append(str(snapped(sound.pitch_min, 0.01)))
		else:
			column.append("%s ~ %s" % [snapped(sound.pitch_min, 0.01), snapped(sound.pitch_max, 0.01)])

		list.add_column(column)
	
	if current_data.sounds.size() > select_index and select_index != -1:
		await list.columns_setted
		list.select(select_index)


func fill_flash_list(select_index: int = -1) -> void:
	var list = %FlashList
	list.clear()
	
	var current_data = get_data()
	
	for i in current_data.flashes.size():
		var flash: RPGAnimationFlash = current_data.flashes[i]
		var s = "s" if flash.duration != 1 else ""
		var column = [
			str(flash.frame),
			str(snapped(flash.duration, 0.01)) + " second%s" % s,
			"■ #" + flash.color.to_html()
		]
		if flash.target == 0:
			column.append("Objetive")
		else:
			var blend_type = ["Normal", "Add", "Subtract", "Multiply"][flash.screen_blend_type]
			column.append("Screen (%s)" % blend_type)
		var custom_row_column_key = str([i, 2])
		list.custom_row_column[custom_row_column_key] = flash.color
		list.add_column(column)
	
	if current_data.flashes.size() > select_index and select_index != -1:
		await list.columns_setted
		list.select(select_index)


func fill_shake_list(select_index: int = -1) -> void:
	var list = %ShakeList
	list.clear()
	
	var current_data = get_data()
	
	for i in current_data.shakes.size():
		var shake: RPGAnimationShake = current_data.shakes[i]
		var s = "s" if shake.duration != 1 else ""
		var column = [
			str(shake.frame),
			str(snapped(shake.amplitude, 0.01)),
			str(snapped(shake.frequency, 0.01)),
			str(snapped(shake.duration, 0.01)) + " second%s" % s
		]
		if shake.target == 0:
			column.append("Objetive")
		else:
			column.append("Screen")

		list.add_column(column)
	
	if current_data.shakes.size() > select_index and select_index != -1:
		await list.columns_setted
		list.select(select_index)


func start_record() -> void:
	%PlayAnimationButton.modulate.a = 0.5
	%PlayAnimationButton.pressed.emit()
	recording = true
	frames.clear()
	%RecordingPanel.visible = true


func _on_sound_list_gui_input(event: InputEvent) -> void:
	if !is_recording or busy2: return
	
	if event is InputEventKey:
		if event.is_pressed():
			if event.keycode == KEY_SPACE:
				if !recording:
					start_record()
				else:
					frames.append(["sound", current_frame])
				get_viewport().set_input_as_handled()


func _on_flash_list_gui_input(event: InputEvent) -> void:
	if !is_recording or busy2: return
	
	if event is InputEventKey:
		if event.is_pressed():
			if event.keycode == KEY_SPACE:
				if !recording:
					start_record()
				else:
					frames.append(["flash", current_frame])
				get_viewport().set_input_as_handled()


func _on_shake_list_gui_input(event: InputEvent) -> void:
	if !is_recording or busy2: return
	
	if event is InputEventKey:
		if event.is_pressed():
			if event.keycode == KEY_SPACE:
				if !recording:
					start_record()
				else:
					frames.append(["shake", current_frame])
				get_viewport().set_input_as_handled()


func _update_data_fields() -> void:
	busy = true
	
	var current_data = get_data()
	if current_selected_index != -1:
		disable_all(false)
		%NameLineEdit.text = current_data.name
		%ScaleSpinBox.value = current_data.animation_scale
		%SpeedSpinBox.value = current_data.animation_speed
		if ResourceLoader.exists(current_data.filename):
			%FilenameButton.text = current_data.filename
		else:
			%FilenameButton.text = TranslationManager.tr("Select Animation File")
		%DisplayTypeOptions.select(current_data.display_type)
		%VerticalAlignOptions.select(current_data.vertical_align)
		%OffsetXSpinBox.value = current_data.offset.x
		%OffsetYSpinBox.value = current_data.offset.y
		%RotationXSpinBox.value = current_data.rotation.x
		%RotationYSpinBox.value = current_data.rotation.y
		%RotationZSpinBox.value = current_data.rotation.z
		%ColorPickerButton.set_pick_color(current_data.animation_color)
		%Notes.text = str(current_data.notes)
		fill_flash_list()
		fill_sound_list()
		fill_shake_list()
	else:
		disable_all(true)
		%NameLineEdit.text = ""
	
	busy = true


func _on_filename_button_middle_click_pressed() -> void:
	_stop_animations()
	%FilenameButton.text = TranslationManager.tr("Select Animation File")
	get_data().filename = ""


func _on_filename_button_pressed() -> void:
	_stop_animations()
	var path = "res://addons/CustomControls/Dialogs/select_animation_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)

	dialog.animation_selected.connect(_on_animation_file_selected)
	
	await get_tree().process_frame
	await get_tree().process_frame
	var current_data = get_data()
	dialog.set_data(current_data.filename, current_data.animation_scale, current_data.animation_speed)


func _on_animation_file_selected(_path: String, _scale: int, _animation_speed: float) -> void:
	var current_data = get_data()
	if ResourceLoader.exists(_path):
		current_data.filename = _path
	else:
		current_data.filename = ""
	%FilenameButton.text = TranslationManager.tr("Select Animation File") if !current_data.filename else current_data.filename
	%ScaleSpinBox.value = _scale
	%SpeedSpinBox.value = _animation_speed


func _on_scale_spin_box_value_changed(value: float) -> void:
	if not get_data(): return
	get_data().animation_scale = value


func _on_speed_spin_box_value_changed(value: float) -> void:
	if not get_data(): return
	get_data().animation_speed = value


func _on_display_type_options_item_selected(index: int) -> void:
	get_data().display_type = index


func _on_vertical_align_options_item_selected(index: int) -> void:
	get_data().vertical_align = index


func _on_offset_x_spin_box_value_changed(value: float) -> void:
	get_data().offset.x = value


func _on_offset_y_spin_box_value_changed(value: float) -> void:
	get_data().offset.y = value


func _on_rotation_x_spin_box_value_changed(value: float) -> void:
	get_data().rotation.x = value


func _on_rotation_y_spin_box_value_changed(value: float) -> void:
	get_data().rotation.y = value


func _on_rotation_z_spin_box_value_changed(value: float) -> void:
	get_data().rotation.z = value


func _on_play_animation_button_pressed() -> void:
	if (is_recording and recording) or is_playing:
		return
	propagate_call("apply")
	
	%PlayAnimationButton.set_disabled(true)
	%ChangeEnemyButton.set_disabled(true)
	%ChangeBackgroundButton.set_disabled(true)

	recording = false
	var current_data = get_data()
	var node1: EffekseerEmitter2D = %EffekseerEmitter2D
	if node1.is_playing():
		node1.stop()
	var node2: Control = %SceneAnimations
	for child in node2.get_children():
		child.queue_free()
	
	var base_position: Vector2
	var offset = current_data.offset * %Target.global_scale

	match current_data.vertical_align:
		0: # Top
			base_position = %Up.global_position
		1: # Center  
			base_position = %Up.global_position
			var mid_y = (%Down.global_position.y - %Up.global_position.y) / 2
			base_position.y += mid_y
		2: # Bottom
			base_position = %Down.global_position

	var animation_position = base_position + offset
	
	if ResourceLoader.exists(current_data.filename):
		if current_data.filename.get_extension().to_lower() == "tscn":
			var ins = load(current_data.filename).instantiate()
			ins.propagate_call("set_speed_scale", [current_data.animation_speed])
			var ins_scale = Vector2(current_data.animation_scale, current_data.animation_scale)
			ins.propagate_call("set_scale", [ins_scale])
			ins.modulate = current_data.animation_color
			ins.is_in_editor = true
			if ins.has_signal("tree_exiting"):
				ins.tree_exiting.connect(_on_animation_finished)
				ins.tree_exiting.connect(_clean_flashes)
			node2.add_child(ins)
			ins.global_position = animation_position
			ins.rotation = current_data.rotation.z
		else:
			var effect = load(current_data.filename)
			node1.set_effect(effect)
			node1.speed = current_data.animation_speed
			node1.scale = Vector2(current_data.animation_scale, current_data.animation_scale)
			node1.orientation = current_data.rotation
			node1.global_position = animation_position
			node1.modulate = current_data.animation_color
			node1.play()
	
		%PlayAnimationButton.modulate.a = 0.5
		current_frame = 0
		is_playing = true


func _clean_flashes() -> void:
	%ScreenFlash.color = Color.TRANSPARENT
	%AnimationTarget.modulate = Color.WHITE


func _on_color_picker_button_color_changed(color: Color) -> void:
	get_data().animation_color = color
	%EffekseerEmitter2D.color = color
	for child in %SceneAnimations.get_children():
		child.modulate = color


func _on_animation_finished() -> void:
	recording = false
	is_playing = false
	%PlayAnimationButton.modulate.a = 1.0
	%RecordingPanel.visible = false
	if frames.size() > 0:
		for frame in frames:
			if frame[0] == "sound":
				var sound: RPGAnimationSound = RPGAnimationSound.new()
				sound.frame = frame[1]
				get_data().sounds.append(sound)
				refresh_sound_list_timer = 0.25
			elif frame[0] == "flash":
				var flash: RPGAnimationFlash = RPGAnimationFlash.new()
				flash.frame = frame[1]
				get_data().flashes.append(flash)
				refresh_flash_list_timer = 0.25
			elif frame[0] == "shake":
				var shake: RPGAnimationShake = RPGAnimationShake.new()
				shake.frame = frame[1]
				get_data().shakes.append(shake)
				refresh_shake_list_timer = 0.25
		frames.clear()
	
	busy2 = true
	await get_tree().create_timer(0.06).timeout
	if not is_instance_valid(self) or not is_inside_tree(): return
	busy2 = false
	
	%PlayAnimationButton.set_disabled(false)
	%ChangeEnemyButton.set_disabled(false)
	%ChangeBackgroundButton.set_disabled(false)
	


func _on_texture_button_toggled(toggled_on: bool) -> void:
	is_recording = toggled_on


func _on_sound_list_copy_requested(indexes: PackedInt32Array) -> void:
	var copy_animations: Array[RPGAnimationSound]
	var sound_list = get_data().sounds
	for index in indexes:
		if index > sound_list.size() or index < 0:
			continue
		copy_animations.append(sound_list[index].clone(true))
		
	StaticEditorVars.CLIPBOARD["animation_sounds"] = copy_animations


func _on_sound_list_cut_requested(indexes: PackedInt32Array) -> void:
	var copy_sounds: Array[RPGAnimationSound]
	var remove_sounds: Array[RPGAnimationSound]
	var sound_list = get_data().sounds
	for index in indexes:
		if index > sound_list.size():
			continue
		if sound_list.size() > index and index >= 0:
			copy_sounds.append(sound_list[index].clone(true))
			remove_sounds.append(sound_list[index])
	for item in remove_sounds:
		sound_list.erase(item)

	StaticEditorVars.CLIPBOARD["animation_sounds"] = copy_sounds
	
	var item_selected = max(-1, indexes[0])
	fill_sound_list(item_selected)


func _on_sound_list_delete_pressed(indexes: PackedInt32Array) -> void:
	var remove_sounds: Array[RPGAnimationSound] = []
	var sound_list = get_data().sounds
	for index in indexes:
		if index >= 0 and sound_list.size() > index:
			remove_sounds.append(sound_list[index])
	for obj in remove_sounds:
		sound_list.erase(obj)
	fill_sound_list(indexes[0])


func _on_sound_list_paste_requested(index: int) -> void:
	var sound_list = get_data().sounds
	var indexes = []
	
	if StaticEditorVars.CLIPBOARD.has("animation_sounds"):
		for i in StaticEditorVars.CLIPBOARD["animation_sounds"].size():
			var mat1: RPGAnimationSound = StaticEditorVars.CLIPBOARD["animation_sounds"][i].clone()
			var real_index = index + i
			if real_index < sound_list.size():
				sound_list.insert(real_index, mat1)
				indexes.append(real_index)
			else:
				sound_list.append(mat1)
				indexes.append(sound_list.size() - 1)
	else:
		return
	
	fill_sound_list(min(index, sound_list.size() - 1))
	
	var list = %SoundList
	await list.columns_setted
	await get_tree().process_frame
	await get_tree().process_frame
	list.deselect_all()
	for i in indexes:
		list.select(i, false)


func _on_flash_list_copy_requested(indexes: PackedInt32Array) -> void:
	var copy_flashes: Array[RPGAnimationFlash]
	var flashes_list = get_data().flashes
	for index in indexes:
		if index > flashes_list.size() or index < 0:
			continue
		copy_flashes.append(flashes_list[index].clone(true))
		
	StaticEditorVars.CLIPBOARD["animation_flashes"] = copy_flashes


func _on_flash_list_cut_requested(indexes: PackedInt32Array) -> void:
	var copy_flashes: Array[RPGAnimationFlash]
	var remove_flashes: Array[RPGAnimationFlash]
	var flashes_list = get_data().flashes
	for index in indexes:
		if index > flashes_list.size():
			continue
		if flashes_list.size() > index and index >= 0:
			copy_flashes.append(flashes_list[index].clone(true))
			remove_flashes.append(flashes_list[index])
	for item in remove_flashes:
		flashes_list.erase(item)

	StaticEditorVars.CLIPBOARD["animation_flashes"] = copy_flashes
	
	var item_selected = max(-1, indexes[0])
	fill_flash_list(item_selected)


func _on_flash_list_delete_pressed(indexes: PackedInt32Array) -> void:
	var remove_flashes: Array[RPGAnimationFlash] = []
	var flashes_list = get_data().flashes
	for index in indexes:
		if index >= 0 and flashes_list.size() > index:
			remove_flashes.append(flashes_list[index])
	for obj in remove_flashes:
		flashes_list.erase(obj)
	fill_flash_list(indexes[0])


func _on_flash_list_paste_requested(index: int) -> void:
	var flashes_list = get_data().flashes
	var indexes = []
	
	if StaticEditorVars.CLIPBOARD.has("animation_flashes"):
		for i in StaticEditorVars.CLIPBOARD["animation_flashes"].size():
			var mat1: RPGAnimationFlash = StaticEditorVars.CLIPBOARD["animation_flashes"][i].clone()
			var real_index = index + i
			if real_index < flashes_list.size():
				flashes_list.insert(real_index, mat1)
				indexes.append(real_index)
			else:
				flashes_list.append(mat1)
				indexes.append(flashes_list.size() - 1)
	else:
		return
	
	fill_flash_list(min(index, flashes_list.size() - 1))
	
	var list = %FlashList
	await list.columns_setted
	await get_tree().process_frame
	await get_tree().process_frame
	list.deselect_all()
	for i in indexes:
		list.select(i, false)


func _on_sound_list_item_activated(index: int) -> void:
	if is_recording: return
	
	var current_data = get_data()
	var sound: RPGAnimationSound
	if current_data.sounds.size() > index:
		sound = current_data.sounds[index]
	else:
		sound = RPGAnimationSound.new()
		index = -1
	
	var path = "res://addons/CustomControls/Dialogs/animation_select_sound_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	dialog.set_data(index, sound)
	
	dialog.value_changed.connect(_on_sound_selected)


func _on_sound_selected(selected_index: int, sound: RPGAnimationSound) -> void:
	var current_data = get_data()
	if selected_index != -1:
		current_data.sounds[selected_index].frame = sound.frame
		current_data.sounds[selected_index].filename = sound.filename
		current_data.sounds[selected_index].volume_db = sound.volume_db
		current_data.sounds[selected_index].pitch_min = sound.pitch_min
		current_data.sounds[selected_index].pitch_max = sound.pitch_max
		
		fill_sound_list(selected_index)
	else:
		current_data.sounds.append(sound)
		selected_index = current_data.sounds.size() - 1
		fill_sound_list(selected_index)



func custom_sort_list(a, b) -> bool:
	return a.frame < b.frame


func _on_order_sound_list_pressed() -> void:
	if is_recording: return
	get_data().sounds.sort_custom(custom_sort_list)
	fill_sound_list()


func _on_remove_duplicate_sounds_pressed() -> void:
	if is_recording: return
	var sounds = get_data().sounds
	var frames = []
	var remove_sounds = []
	for sound: RPGAnimationSound in sounds:
		if !frames.has(sound.frame):
			frames.append(sound.frame)
		else:
			remove_sounds.append(sound)
	for sound in remove_sounds:
		sounds.erase(sound)
	fill_sound_list()


func _on_clear_sound_list_pressed() -> void:
	if is_recording: return
	get_data().sounds.clear()
	fill_sound_list()


func _on_order_flash_list_pressed() -> void:
	if is_recording: return
	get_data().flashes.sort_custom(custom_sort_list)
	fill_flash_list()


func _on_remove_duplicate_flashes_pressed() -> void:
	if is_recording: return
	var flashes = get_data().flashes
	var frames = []
	var remove_flashes = []
	for flash: RPGAnimationFlash in flashes:
		if !frames.has(flash.frame):
			frames.append(flash.frame)
		else:
			remove_flashes.append(flash)
	for flash in remove_flashes:
		flashes.erase(flash)
	fill_flash_list()


func _on_clear_flash_list_pressed() -> void:
	if is_recording: return
	get_data().flashes.clear()
	fill_flash_list()


func _on_flash_list_item_activated(index: int) -> void:
	if is_recording: return
	
	var current_data = get_data()
	var flash: RPGAnimationFlash
	if current_data.flashes.size() > index:
		flash = current_data.flashes[index]
	else:
		flash = RPGAnimationFlash.new()
		index = -1
	
	var path = "res://addons/CustomControls/Dialogs/animation_select_flash_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	dialog.set_data(index, flash)
	
	dialog.value_changed.connect(_on_flash_selected)


func _on_flash_selected(selected_index: int, flash: RPGAnimationFlash) -> void:
	var current_data = get_data()
	if selected_index != -1:
		current_data.flashes[selected_index].frame = flash.frame
		current_data.flashes[selected_index].duration = flash.duration
		current_data.flashes[selected_index].color = flash.color
		current_data.flashes[selected_index].target = flash.target
		current_data.flashes[selected_index].screen_blend_type = flash.screen_blend_type
		fill_flash_list(selected_index)
	else:
		current_data.flashes.append(flash)
		selected_index = current_data.flashes.size() - 1
		fill_flash_list(selected_index)



func _on_order_shake_list_pressed() -> void:
	if is_recording: return
	get_data().shakes.sort_custom(custom_sort_list)
	fill_shake_list()


func _on_remove_duplicate_shakes_pressed() -> void:
	if is_recording: return
	var shakes = get_data().shakes
	var frames = []
	var remove_shakes = []
	for shake: RPGAnimationShake in shakes:
		if !frames.has(shake.frame):
			frames.append(shake.frame)
		else:
			remove_shakes.append(shake)
	for shake in remove_shakes:
		shakes.erase(shake)
	fill_shake_list()


func _on_clear_shake_list_pressed() -> void:
	if is_recording: return
	get_data().shakes.clear()
	fill_shake_list()


func _on_shake_list_copy_requested(indexes: PackedInt32Array) -> void:
	var copy_shakes: Array[RPGAnimationShake]
	var shakes_list = get_data().shakes
	for index in indexes:
		if index > shakes_list.size() or index < 0:
			continue
		copy_shakes.append(shakes_list[index].clone(true))
		
	StaticEditorVars.CLIPBOARD["animation_shakes"] = copy_shakes


func _on_shake_list_cut_requested(indexes: PackedInt32Array) -> void:
	var copy_shakes: Array[RPGAnimationShake]
	var remove_shakes: Array[RPGAnimationShake]
	var shakes_list = get_data().shakes
	for index in indexes:
		if index > shakes_list.size():
			continue
		if shakes_list.size() > index and index >= 0:
			copy_shakes.append(shakes_list[index].clone(true))
			remove_shakes.append(shakes_list[index])
	for item in remove_shakes:
		shakes_list.erase(item)

	StaticEditorVars.CLIPBOARD["animation_shakes"] = copy_shakes
	
	var item_selected = max(-1, indexes[0])
	fill_shake_list(item_selected)


func _on_shake_list_delete_pressed(indexes: PackedInt32Array) -> void:
	var remove_shakes: Array[RPGAnimationShake] = []
	var shakes_list = get_data().shakes
	for index in indexes:
		if index >= 0 and shakes_list.size() > index:
			remove_shakes.append(shakes_list[index])
	for obj in remove_shakes:
		shakes_list.erase(obj)
	fill_shake_list(indexes[0])


func _on_shake_list_item_activated(index: int) -> void:
	if is_recording: return
	
	var current_data = get_data()
	var shake: RPGAnimationShake
	if current_data.shakes.size() > index:
		shake = current_data.shakes[index]
	else:
		shake = RPGAnimationShake.new()
		index = -1
	
	var path = "res://addons/CustomControls/Dialogs/animation_select_shake_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	dialog.set_data(index, shake)
	
	dialog.value_changed.connect(_on_shake_selected)


func _on_shake_list_paste_requested(index: int) -> void:
	var shakes_list = get_data().shakes
	var indexes = []
	
	if StaticEditorVars.CLIPBOARD.has("animation_shakes"):
		for i in StaticEditorVars.CLIPBOARD["animation_shakes"].size():
			var mat1: RPGAnimationShake = StaticEditorVars.CLIPBOARD["animation_shakes"][i].clone()
			var real_index = index + i
			if real_index < shakes_list.size():
				shakes_list.insert(real_index, mat1)
				indexes.append(real_index)
			else:
				shakes_list.append(mat1)
				indexes.append(shakes_list.size() - 1)
	else:
		return
	
	fill_shake_list(min(index, shakes_list.size() - 1))
	
	var list = %ShakeList
	await list.columns_setted
	await get_tree().process_frame
	await get_tree().process_frame
	list.deselect_all()
	for i in indexes:
		list.select(i, false)


func _on_shake_selected(selected_index: int, shake: RPGAnimationShake) -> void:
	var current_data = get_data()
	if selected_index != -1:
		current_data.shakes[selected_index].frame = shake.frame
		current_data.shakes[selected_index].amplitude = shake.amplitude
		current_data.shakes[selected_index].frequency = shake.frequency
		current_data.shakes[selected_index].target = shake.target
		current_data.shakes[selected_index].duration = shake.duration
		fill_shake_list(selected_index)
	else:
		current_data.shakes.append(shake)
		selected_index = current_data.shakes.size() - 1
		fill_shake_list(selected_index)


func _on_change_enemy_button_pressed() -> void:
	open_image_dialog(current_animation_enemy_image, 0)


func _on_change_background_button_pressed() -> void:
	open_image_dialog(current_animation_background_image, 1)


func open_image_dialog(current_path: String, type: int) -> void:
	var path = "res://addons/CustomControls/Dialogs/select_file_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	await get_tree().process_frame
	
	dialog.set_dialog_mode(0)
	dialog.destroy_on_hide = true
	dialog.target_callable = change_animation_preview_image.bind(type)
	dialog.set_file_selected(current_path)
	
	dialog.fill_files("images")


func change_animation_preview_image(path: String, type: int) -> void:
	if type == 0:
		%Target.texture = load(path)
		%TargetShadow.texture = %Target.texture
		%Target.position = Vector2(-%Target.texture.get_width() / 2.0, -%Target.texture.get_height())
		%Up.position = Vector2(%Target.texture.get_width() / 2.0, 0)
		%Down.position = Vector2(%Target.texture.get_width() / 2.0, %Target.texture.get_height())
		%TargetShadow.position = Vector2(%Target.texture.get_width() / 2.0, %Target.texture.get_height())
		%TargetShadow.offset = -%TargetShadow.position
		current_animation_enemy_image = path
	else:
		%AnimationBackgroundSprite.texture = load(path)
		current_animation_background_image = path


func _on_list_button_right_pressed(indexes: PackedInt32Array, list_id: int) -> void:
	var popup_list: PopupMenu = %CommandMenuList
	popup_list.clear()
	
	var commands = []
	
	match list_id:
		0: # Sound List
			commands = ["Sound Commands", "Change Filename", "Change Volume", "Change Pitch"]
		1: # Flash List
			commands = ["Flash Commands", "Change Duration", "Change Color"]
		2: # Shake List
			commands = ["Shake Commands", "Change Amplitude", "Change Frequency", "Change Duration"]
	
	for i in commands.size():
		var item = commands[i]
		popup_list.add_item(item)
		if i == 0:
			popup_list.set_item_disabled(0, true)
	
	if list_id > 0:
		if objetive_menu_list.is_inside_tree():
			objetive_menu_list.get_parent().remove_child(objetive_menu_list)
		popup_list.add_submenu_node_item("Change Target", objetive_menu_list)
	
	if popup_list.index_pressed.is_connected(_on_command_menu_list_item_selected):
		popup_list.index_pressed.disconnect(_on_command_menu_list_item_selected)
	popup_list.index_pressed.connect(_on_command_menu_list_item_selected.bind(indexes, list_id), CONNECT_ONE_SHOT)
	
	if objetive_menu_list.index_pressed.is_connected(_on_objetive_list_item_selected):
		objetive_menu_list.index_pressed.disconnect(_on_objetive_list_item_selected)
	objetive_menu_list.index_pressed.connect(_on_objetive_list_item_selected.bind(indexes, list_id), CONNECT_ONE_SHOT)
	
	popup_list.popup()
	var mouse_position = Vector2(DisplayServer.mouse_get_position())
	var p: Vector2 = mouse_position - popup_list.size * 0.5
	popup_list.position = p


func _on_command_menu_list_item_selected(index_selected: int, indexes: PackedInt32Array, list_id: int) -> void:
	match list_id:
		0: # Sound List
			match index_selected:
				1: # Change Filename
					_change_fx_for("Change FX Sound", index_selected, indexes, list_id)
				2: # Change Volume
					_change_value_for("Change Volume", -80, 24, 0.01, index_selected, indexes, list_id)
				3: # Change Pitch
					_change_value_for("Change Pitch", 0.01, 4, 0.01, index_selected, indexes, list_id)
		1: # Flash List
			match index_selected:
				1: # Change Duration
					_change_value_for("Change Duration", 0.01, 500, 0.01, index_selected, indexes, list_id)
				2: # Change Color
					_change_color_for("Change Flash Color", index_selected, indexes, list_id)
		2: # Shake List
			match index_selected:
				1: # Change Amplitude
					_change_value_for("Change Amplitude", 0, 500, 0.01, index_selected, indexes, list_id)
				2: # Change Frequency
					_change_value_for("Change Frequency", 0, 500, 0.01, index_selected, indexes, list_id)
				3: # Change Duration
					_change_value_for("Change Duration", 0.01, 500, 0.01, index_selected, indexes, list_id)


func _on_objetive_list_item_selected(index_selected: int, indexes: PackedInt32Array, list_id: int) -> void:
	var current_data = get_data()
	for i in indexes:
		if list_id == 1: # Flash List
			current_data.flashes[i].target = index_selected
		elif list_id == 2: # Shake List
			current_data.shakes[i].target = index_selected
	
	if list_id == 1: # Flash List
		fill_flash_list()
		await %FlashList.columns_setted
		%FlashList.set_selected_items(indexes)
	elif list_id == 2: # Shake List
		fill_shake_list()
		await %ShakeList.columns_setted
		%ShakeList.set_selected_items(indexes)


func _change_value_for(window_title: String, min_value: float, max_value: float, step: float,
	type: int, indexes: PackedInt32Array, list_id: int) -> void:
	var current_data = get_data()
	
	var path = "res://addons/CustomControls/Dialogs/select_number_value_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)

	dialog.set_title_and_contents(window_title, tr("Value"))
	dialog.set_min_max_values(min_value, max_value, step)
	
	if (list_id == 1 and type == 1) or (list_id == 2 and type == 3):
		dialog.set_suffix("second/s")
	
	var current_list
	
	match list_id:
		0: # Sound List
			current_list = current_data.sounds
			match type:
				2: # Change Volume
					dialog.set_value(current_list[indexes[0]].volume_db)
					pass
				3: # Change Pitch
					dialog.set_value(current_list[indexes[0]].pitch_min)
		1: # Flash List
			current_list = current_data.flashes
			match type:
				1: # Change Duration
					dialog.set_value(current_list[indexes[0]].duration)
		2: # Shake List
			current_list = current_data.shakes
			match type:
				1: # Change Amplitude
					dialog.set_value(current_list[indexes[0]].amplitude)
				2: # Change Frequency
					dialog.set_value(current_list[indexes[0]].frequency)
				3: # Change Duration
					dialog.set_value(current_list[indexes[0]].duration)
	
	dialog.selected_value.connect(
		func(value: float) -> void:
			var value_changed: bool = false
			for index in indexes:
				match list_id:
					0: # Sound List
						match type:
							2: # Change Volume
								current_list[index].volume_db = value
								value_changed = true
							3: # Change Pitch
								current_list[index].pitch_min = value
								current_list[index].pitch_max = value
								value_changed = true
					1: # Flash List
						match type:
							1: # Change Duration
								current_list[index].duration = value
								value_changed = true
					2: # Shake List
						match type:
							1: # Change Amplitude
								current_list[index].amplitude = value
								value_changed = true
							2: # Change Frequency
								current_list[index].frequency = value
								value_changed = true
							3: # Change Duration
								current_list[index].duration = value
								value_changed = true
			
			if value_changed:
				match list_id:
					0: # Sound List
						fill_sound_list()
						await %SoundList.columns_setted
						%SoundList.set_selected_items(indexes)
					1: # Flash List
						fill_flash_list()
						await %FlashList.columns_setted
						%FlashList.set_selected_items(indexes)
					2: # Shake List
						fill_shake_list()
						await %ShakeList.columns_setted
						%ShakeList.set_selected_items(indexes)
	)


func _change_color_for(window_title: String, type: int, indexes: PackedInt32Array, list_id: int) -> void:
	var current_data = get_data()
	var path = "res://addons/CustomControls/Dialogs/select_color.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	dialog.title = window_title
	
	var current_list
	
	match list_id:
		1: # Flash List
			match type:
				2: # Change Color
					current_list = current_data.flashes
					dialog.set_color(current_list[indexes[0]].color)
	
	dialog.color_selected.connect(
		func(color: Color) -> void:
			var value_changed: bool = false
			for index in indexes:
				match list_id:
					1: # Flash List
						match type:
							2: # Change Color
								current_list[index].color = color
								value_changed = true
			
			if value_changed:
				match list_id:
					1: # Flash List
						fill_flash_list()
						await %FlashList.columns_setted
						%FlashList.set_selected_items(indexes)
	)


func _change_fx_for(window_title: String, type: int, indexes: PackedInt32Array, list_id: int) -> void:
	var path = "res://addons/CustomControls/Dialogs/select_file_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	dialog.title = window_title
	
	await get_tree().process_frame
	
	var current_list
	var current_data = get_data()
	
	match list_id:
		0: # Sound List
			match type:
				1: # Change Filename
					current_list = current_data.sounds
					dialog.set_file_selected(current_list[indexes[0]].filename)
					
	var callable = func(new_path: String) -> void:
		var value_changed: bool = false
		for index in indexes:
			match list_id:
				0: # Sound List
					match type:
						1: # Change Filename
							current_list[index].filename = new_path
							value_changed = true
		
		if value_changed:
			match list_id:
				0: # Sound List
					fill_sound_list()
					await %SoundList.columns_setted
					%SoundList.set_selected_items(indexes)
	
	dialog.destroy_on_hide = true
	dialog.auto_play_sounds = true
	dialog.set_dialog_mode(0)
	dialog.fill_files("sounds")
	dialog.target_callable = callable


func _on_reset_preiew_animation_pressed() -> void:
	%FitContainer.reset()


func _on_notes_text_changed() -> void:
	get_data().notes = %Notes.text


func _on_config_data_tabs_tab_changed(index: int) -> void:
	var node_path = "%%Tab%s" % (index + 1)
	var node = get_node_or_null(node_path)
	if node:
		for child in node.get_parent().get_children():
			child.visible = false
		node.visible = true
