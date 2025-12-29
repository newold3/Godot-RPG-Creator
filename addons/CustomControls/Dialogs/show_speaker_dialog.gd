@tool
extends Window


var is_disabled: bool = false


signal speaker_selected(index: int)


func _ready() -> void:
	close_requested.connect(queue_free)
	fill_speakers()


func fill_speakers() -> void:
	var node = %Speaker
	node.clear()
	var speakers = RPGSYSTEM.database.speakers
	if speakers.size() > 1:
		for i in range(1, speakers.size(), 1):
			node.add_item("Select Speaker #%s %s" % [i, get_character_name(speakers[i].name)])
		is_disabled = false
		%Speaker.set_disabled(false)
	else:
		node.add_item("No Speaker Created in Database")
		node.select(0)
		%Speaker.set_disabled(true)
		is_disabled = true


func get_character_name(current_name: Dictionary) -> String:
	var id = int(current_name.get("type", 0))
	var final_name_string = ""
	if id == 0:
		final_name_string = str(current_name.get("val", ""))
	elif id == 1:
		var actor_id = int(current_name.get("val", 1))
		if RPGSYSTEM.database.actors.size() > actor_id:
			final_name_string = RPGSYSTEM.database.actors[actor_id].name
	elif id == 2:
		var enemy_id =  int(current_name.get("val", 1))
		if RPGSYSTEM.database.enemies.size() > enemy_id:
			final_name_string = RPGSYSTEM.database.enemies[enemy_id].name
		
	return final_name_string


func set_selected(id: int) -> void:
	id = clamp(id - 1, 0, %Speaker.get_item_count() - 1)
	%Speaker.select(id)



func _on_ok_button_pressed() -> void:
	if !is_disabled:
		speaker_selected.emit(%Speaker.get_selected_id() + 1)
	queue_free()


func _on_cancel_button_pressed() -> void:
	queue_free()
