@tool
extends Window

#region Signals & Variables
signal item_selected(index: int)
signal selected(id: int, target: Variant)


var data
var database: RPGDATA
var target

var busy: bool = false
var animation_type: int = -1
var destroy_on_hide: bool = false
var use_uniq_ids: bool = false
#endregion



#region Lifecycle
## Handles cancel on close and resets busy state on visibility change.
func _ready() -> void:
	close_requested.connect(_on_cancel_button_pressed)
	visibility_changed.connect(func(): busy = false)


## Ensures Effekseer animations keep looping if the emitter is active.
func _process(delta: float) -> void:
	if animation_type == 1 and not %EffekseerEmitter2D.is_playing():
		%EffekseerEmitter2D.play()
#endregion



#region Main Setup
## Configures the dialog data, calculates pagination, and triggers initial animation if needed.
func setup(_data, id_selected: int, _title: String, _target: Variant) -> void:
	if !database: return
	
	data = _data
	target = _target
	
	set_label(_title)

	var index1: int = id_selected / 20
	var index2: int = id_selected % 20 - 1
	
	fill_list1(index1, index2)
	
	await get_tree().process_frame
	
	if %AnimationsBackground.visible and %List2.is_anything_selected():
		_play_animation(%List2.get_selected_items()[0])
	
	%List2.grab_focus()


## Activates the animation preview UI and connects selection signals.
func set_animation_mode() -> void:
	%AnimationsBackground.visible = true
	
	if not %List2.item_selected.is_connected(_play_animation):
		%List2.item_selected.connect(_play_animation)
	
	%List2.allow_reselect = true
	
	if %List2.is_anything_selected():
		await get_tree().process_frame
		_play_animation(%List2.get_selected_items()[0])
		
	_on_h_slider_value_changed(0.4)
#endregion



#region Animation Logic
## Instantiates or plays the selected animation based on file type (.tscn or Effekseer).
func _play_animation(index: int) -> void:
	var node1: EffekseerEmitter2D = %EffekseerEmitter2D
	if node1.is_playing():
		node1.stop()
		
	var node2: Control = %SceneAnimations
	for child in node2.get_children():
		child.queue_free()
		
	var index1 = %List1.get_selected_items()[0] * 20
	var index2 = index + 1
	var animation_id = index1 + index2
	
	animation_type = -1
	var current_animation = RPGSYSTEM.database.animations[animation_id] if RPGSYSTEM.database.animations.size() > animation_id else null
	
	if current_animation:
		if ResourceLoader.exists(current_animation.filename):
			if current_animation.filename.get_extension().to_lower() == "tscn":
				var ins = load(current_animation.filename).instantiate()
				if ins.has_signal("animation_finished"):
					ins.animation_finished.connect(_play_animation.bind(index))
				node2.add_child(ins)
				animation_type = 0
			else:
				var animation: EffekseerEffect = load(current_animation.filename)
				if animation:
					node1.set_effect(animation)
					node1.speed = current_animation.animation_speed
					node1.play()
					animation_type = 1
#endregion



#region List Management
## Clears all current data and lists.
func clear_all() -> void:
	data = null
	%List1.clear()
	%List2.clear()


## Sets the window title and the internal simple label.
func set_label(_title: String) -> void:
	title = _title.to_camel_case()
	%SimpleLabel.set_title(_title)


## Fills the pagination list (List1) and selects the appropriate range.
func fill_list1(index: int, index2: int) -> void:
	var list = %List1
	list.clear()
	if data.size() == 0:
		disable_list2()
		return
	
	var data_size = data.size()
	var s: int = ceil(data_size / 20.0) if data_size >= 20 else 1

	list.busy = true
	for i in range(s):
		var from = (i * 20) + 1
		var to = min(from + 19, data_size - 1)
		var item = "[%s - %s]" % [str(from).pad_zeros(s-1), str(to).pad_zeros(s-1)]
		list.add_item(item)
	list.busy = false
	list.queue_redraw()
	
	if index < list.item_count and index >= 0:
		list.select(index)
		fill_list2(index, index2)
	elif list.item_count > 0:
		if index == -1:
			list.select(0)
		else:
			index = list.item_count - 1
			list.select(index)
		fill_list2(index, index2)
	else:
		disable_list2()


## Fills the items list (List2) based on the selected page in List1.
func fill_list2(lis1_index: int, list2_index: int) -> void:
	var list = %List2
	list.clear()
	
	var data_size = data.size()
	var s = ceil(data_size / 20.0) if data_size >= 20 else 1
	var from = (lis1_index * 20) + 1
	var to = min(from + 20, data_size)
	
	list.busy = true
	for i in range(from, to):
		var item_name = data[i].name
		var item = "%s:%s" % [str(i).pad_zeros(s-1), item_name]
		list.add_item(item)
	list.busy = false
	list.queue_redraw()
	
	if list2_index < list.item_count and list2_index >= 0:
		list.select(list2_index)
	elif list.item_count > 0:
		list.select(0)


## Clears the items list.
func disable_list2() -> void:
	%List2.clear()
#endregion



#region UI Handlers
## Refreshes List2 when a different page is selected.
func _on_list_1_item_selected(index: int) -> void:
	fill_list2(index, 0)


## Logic for item selection in List2 (currently handled by set_animation_mode signal).
func _on_list_2_item_selected(index2: int) -> void:
	pass


## Emits the selected ID and closes/hides the dialog.
func _on_ok_button_pressed() -> void:
	if busy: return
	busy = true
	var index1 = %List1.get_selected_items()[0] * 20
	var index2 = %List2.get_selected_items()[0] + 1
	var index = index1 + index2
	selected.emit(index, target)
	if !destroy_on_hide:
		hide()
	else:
		queue_free()


## Handles the cancel action.
func _on_cancel_button_pressed() -> void:
	if !destroy_on_hide:
		hide()
	else:
		queue_free()


## Emits the item selected signal and confirms choice.
func _on_list_2_item_activated(index2: int) -> void:
	var index1 = %List1.get_selected_items()[0] * 20
	var index = index1 + index2 + 1
	item_selected.emit(index)
	_on_ok_button_pressed()


## Confirms choice from the page list.
func _on_list_1_item_activated(index: int) -> void:
	var index1 = index * 20
	var index2 = %List2.get_selected_items()[0] + 1
	var final_index = index1 + index2
	item_selected.emit(final_index)
	_on_ok_button_pressed()


## Updates the preview scale for the animations.
func _on_h_slider_value_changed(value: float) -> void:
	%AnimationMainContainer.scale = Vector2(value, value)
	%Scale.text = "%0.3f" % value
#endregion
