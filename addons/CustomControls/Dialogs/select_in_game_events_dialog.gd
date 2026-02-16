@tool
extends Window


signal events_selected(list: PackedInt64Array)


func _ready() -> void:
	close_requested.connect(queue_free)


func fill_events(events: Array, disabled_event: int = -1) -> void:
	var node = %EventList
	node.clear()
	
	for ev: Dictionary in events:
		node.add_item("%s: %s" % [ev.id, ev.name])
		node.set_item_metadata(-1, ev.uniq_id)
		if ev.uniq_id == disabled_event:
			node.set_item_disabled(-1, true)


func select_events(items: PackedInt64Array) -> void:
	var node: ItemList = %EventList
	node.deselect_all()
	for i in node.get_item_count():
		var ev_id = node.get_item_metadata(i)
		if ev_id in items:
			node.select(i, false)


func _on_ok_button_pressed() -> void:
	var items = %EventList.get_selected_items()
	var real_ids: PackedInt64Array = []
	
	for i in items:
		real_ids.append(%EventList.get_item_metadata(i))

	if items.size() > 0:
		events_selected.emit(real_ids)
	queue_free()


func _on_cancel_button_pressed() -> void:
	queue_free()


func _on_event_list_item_activated(index: int) -> void:
	_on_ok_button_pressed()
