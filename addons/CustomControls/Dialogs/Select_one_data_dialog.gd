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
		var real_id = _real_ids[i]
		node.set_item_metadata(-1, real_id)
		
		var is_sep = false
		if real_id != -1 and data is Array:
			for item_obj in data:
				if item_obj and item_obj.get("_uniq_id") == real_id:
					if "separator" in item_obj and item_obj.separator != null:
						is_sep = true
					break
		if is_sep:
			node.set_item_disabled(node.get_item_count() - 1, true)
			
		if selected_id == real_id:
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
	var real_item = data[index]
	if real_item:
		%Level.set_disabled(false)
		if real_item.upgrades.max_levels == 1:
			%Level.max_value = 1
			%MaxLevels.text = " / 1"
		else:
			%Level.max_value = real_item.upgrades.max_levels
			%MaxLevels.text = " / " + str(real_item.upgrades.max_levels)
	else:
		%Level.set_disabled(true)
		%MaxLevels.text = ""
