@tool
extends Window


signal items_selected(list: PackedInt32Array)


func _ready() -> void:
	close_requested.connect(queue_free)


func set_texts(_title: String = "", _sub_title: String = "", _help: String = "") -> void:
	title = _title
	%Subtitle.text = _sub_title
	%Info.tooltip_text = _help
	CustomTooltipManager.replace_all_tooltips_with_custom(%Info)


func fill_data(data: PackedStringArray, selected_ids: PackedInt32Array = [], offset_index: int = 0) -> void:
	var node = %DataList
	node.clear()
	
	for i in data.size():
		var text = data[i]
		node.add_item(text)
		var real_index = i + offset_index
		node.set_item_metadata(-1, real_index)
		if real_index in selected_ids:
			node.select(i, false)


func _on_ok_button_pressed() -> void:
	var items = %DataList.get_selected_items()
	var real_ids: PackedInt32Array = []
	for i in items:
		real_ids.append(%DataList.get_item_metadata(i))

	if items.size() > 0:
		items_selected.emit(real_ids)
		
	queue_free()


func setup_single_mode() -> void:
	%DataList.select_mode = ItemList.SelectMode.SELECT_SINGLE


func _on_cancel_button_pressed() -> void:
	queue_free()


func _on_event_list_item_activated(index: int) -> void:
	if %DataList.select_mode == ItemList.SelectMode.SELECT_SINGLE:
		_on_ok_button_pressed()
