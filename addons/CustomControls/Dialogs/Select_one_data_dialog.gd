@tool
extends Window


var target: Callable
var data: Variant


func _ready() -> void:
	close_requested.connect(queue_free)


func set_data(_title : String, _data: Array, _real_ids: Array, selected_id: int, level: int, _target: Callable) -> void:
	target = _target
	title = _title.capitalize()
	%DataTitle.text = _title + ":"
	var selected_setted: bool = false
	
	var node = %Options
	node.clear()
	for i in _data.size():
		var item = _data[i]
		node.add_item(item)
		node.set_item_metadata(-1, _real_ids[i])
		if selected_id == _real_ids[i]:
			node.select(i)
			_on_options_item_selected(i)
			selected_setted = true
	
	%Level.value = level
	
	if not selected_setted:
		node.select(0)
		_on_options_item_selected(0)


func _on_ok_button_pressed() -> void:
	var id = %Options.get_selected_id()
	var real_id = %Options.get_item_metadata(id)
	if target:
		target.call(real_id, %Level.value)
	queue_free()


func _on_cancel_button_pressed() -> void:
	queue_free()


func _on_options_item_selected(index: int) -> void:
	if index == 0:
		%Level.set_disabled(true)
		%MaxLevels.text = ""
	else:
		%Level.set_disabled(false)
		var real_item = data[%Options.get_item_metadata(index)]
		if real_item.upgrades.max_levels == 1:
			%Level.max_value = 1
			%MaxLevels.text = " / 1"
		else:
			%Level.max_value = real_item.upgrades.max_levels
			%MaxLevels.text = " / " + str(real_item.upgrades.max_levels)
