@tool
class_name SelectAnimationDialog
extends Window

var files: Array = []
var current_animation: String = ""
var filter_need_apply_timer: float = 0.0

var min_scale: int = 1
var max_scale: int = 500
var current_scale: int = 125
var current_animation_speed: float = 1.0

var file_count: int = 0


signal animation_selected(path: String, scale: int, animation_speed: float)
signal files_setted()


func _ready() -> void:
	close_requested.connect(queue_free)
	await get_tree().process_frame
	%MainList.grab_focus()


func set_data(_current_animation: String, _current_scale:int, _current_animation_speed: float) -> void:
	current_animation = _current_animation
	%ScaleSpinBox.value = _current_scale
	%AnimationSpeedSpinBox.value = _current_animation_speed
	fill_files()


func _process(delta: float) -> void:
	if filter_need_apply_timer > 0.0:
		filter_need_apply_timer -= delta
		if filter_need_apply_timer <= 0:
			filter_need_apply_timer = 0
			apply_filter()


func fill_files() -> void:
	%UpdatingCache.visible = true
	%UpdatingCache2.visible = true
	
	files.clear()
	
	if !FileCache.cache_setted:
		FileCache.rescan_files()
		await FileCache.cache_setted
	var file_id = "animations"
	if file_id in FileCache.cache:
		files.append_array(FileCache.cache[file_id].keys())

	var list = %MainList
	list.clear()
	
	var selection_found: bool = false
	var selected_index = 0
	
	files.sort()
	
	for i in files.size():
		var file = files[i]
		list.add_item(file.get_file())
		list.set_item_metadata(i, i)
		if file == current_animation:
			selected_index = i
	
	if files.size() > selected_index:
		list.select(selected_index)
		list.item_selected.emit(selected_index)
		list.ensure_current_is_visible()
	
	%UpdatingCache.visible = false
	%UpdatingCache2.visible = false


func get_resource_type(file_name : String) -> String:
	var f = FileAccess.open(file_name, FileAccess.READ)
	var text := f.get_as_text()

	for line in text.split("\n"):
		line = line.rstrip("\r")
		if line.find("[gd_resource") == 0 and line.find("]") == line.length()-1:
			line = line.substr("[gd_resource".length(), line.length()-2).lstrip(" ").rstrip(" ")
			var entries = line.split(" ")
			for entry in entries:
				var pair = entry.split("=")
				if pair[0] == "type":
					var value = pair[1].lstrip("\"").rstrip("\"")
					return value

	return "unknown"


func _on_main_list_item_selected(index: int) -> void:
	var real_index = %MainList.get_item_metadata(index)
	current_animation = files[real_index]
	play_animation()


func _on_effekseer_emitter_2d_finished() -> void:
	play_animation()


func play_animation() -> void:
	var node1: EffekseerEmitter2D = %EffekseerEmitter2D
	if node1.is_playing():
		node1.stop()
	var node2: Control = %SceneAnimations
	for child in node2.get_children():
		child.queue_free()
	if visible and current_animation:
		if ResourceLoader.exists(current_animation):
			if current_animation.get_extension().to_lower() == "tscn":
				var ins = load(current_animation).instantiate()
				if ins.has_signal("animation_finished"):
					ins.animation_finished.connect(play_animation)
				ins.propagate_call("set_speed_scale", [current_animation_speed])
				var ins_scale = Vector2(current_scale, current_scale)
				ins.propagate_call("set_scale", [ins_scale])
				node2.add_child(ins)
			else:
				var animation: EffekseerEffect = load(current_animation)
				if animation:
					node1.set_effect(animation)
					node1.play()


func _on_ok_button_pressed() -> void:
	animation_selected.emit(current_animation, current_scale, current_animation_speed)
	queue_free()


func _on_cancel_button_pressed() -> void:
	queue_free()


func _on_animations_background_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.is_pressed():
			if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				if !event.is_ctrl_pressed():
					%ScaleSpinBox.apply()
					%ScaleSpinBox.set_value(max(min_scale, current_scale - 1))
				else:
					%AnimationSpeedSpinBox.apply()
					%AnimationSpeedSpinBox.set_value(max(0.1, current_animation_speed - 0.01))
			elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
				if !event.is_ctrl_pressed():
					%ScaleSpinBox.apply()
					%ScaleSpinBox.set_value(min(max_scale, current_scale + 1))
				else:
					%AnimationSpeedSpinBox.apply()
					%AnimationSpeedSpinBox.set_value(min(5.0, current_animation_speed + 0.01))


func _on_filter_text_changed(_new_text: String) -> void:
	filter_need_apply_timer = 0.25


func apply_filter() -> void:
	var current_filter: String = %Filter.text.to_lower()
	var list: ItemList = %MainList
	var current_selected_item: int = -1
	list.clear()
	var n: int = 0
	for i in files.size():
		var file = files[i].get_file()
		var item_is_visible = current_filter.length() == 0 or file.to_lower().find(current_filter) != -1
		if item_is_visible:
			list.add_item(file)
			list.set_item_metadata(n, i)
			if files[i] == current_animation:
				current_selected_item = n
			n += 1
		elif files[i] == current_animation:
			current_selected_item = 0
	
	if list.get_item_count() > current_selected_item and current_selected_item > -1:
		list.select(current_selected_item)
		list.item_selected.emit(current_selected_item)
	elif list.get_item_count() > 0:
		list.select(0)
		list.item_selected.emit(0)
	list.ensure_current_is_visible()


func _on_scale_spin_box_value_changed(value: float) -> void:
	current_scale = value
	var sc = Vector2(current_scale, current_scale)
	%EffekseerEmitter2D.scale = sc
	%EffekseerEmitter2D.position = Vector2.ZERO
	for child in %SceneAnimations.get_children():
		child.scale = sc
		child.position = Vector2.ZERO


func _on_animation_speed_spin_box_value_changed(value: float) -> void:
	current_animation_speed = value
	%EffekseerEmitter2D.speed = value
	for child in %SceneAnimations.get_children():
		child.propagate_call("set_speed_scale", [value])


func _on_clear_filter_button_pressed() -> void:
	%Filter.text = ""
	%Filter.text_changed.emit("")


func _on_main_list_item_activated(_index: int) -> void:
	_on_ok_button_pressed()
