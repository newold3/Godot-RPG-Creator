@tool
class_name RPGTerms
extends  Resource


func get_class(): return "RPGTerms"


@export var messages: Array[RPGTerm]


func create_message(id: String, message: String, unselectable: bool = false, is_user_message: bool = false, force_insert: bool = false) -> RPGTerm:
	if !force_insert:
		for current_message in messages:
			if current_message.id == id:
				printerr("The message with the ID < %s > already exists. Aborting." % id)
				return null
			
	var new_message = RPGTerm.new()
	new_message.id = id
	new_message.text = message
	new_message.unselectable = unselectable
	new_message.is_user_message = is_user_message
	messages.append(new_message)
	
	return new_message


func update_message(id: int, new_message: String) -> void:
	if messages.size() > id:
		var message = messages[id]
		message.text = new_message


func get_message(id: Variant) -> String:
	if id is int:
		if messages.size() > id:
			return messages[id].text
	elif id is String:
		for message: RPGTerm in messages:
			if message.id == id:
				return message.text
	
	return ""


func get_message_obj(id: int) -> RPGTerm:
	if messages.size() > id:
		return messages[id]
	
	return null


func search_message(id: String) -> String:
	for message in messages:
		if message.id == id:
			return tr(message.text)
	
	return ""


func remove_message_at(id: int) -> void:
	if messages.size() > id:
		messages.remove_at(id)


func clone(value: bool = true) -> RPGTerms:
	var new_terms: RPGTerms = duplicate(value)
	
	for i in new_terms.messages.size():
		new_terms.messages[i] = new_terms.messages[i].clone(value)
	
	return new_terms
