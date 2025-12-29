@tool
extends Node

var translations: Translation

func _enter_tree() -> void:
	var path = "res://translations/translations.po"
	if FileAccess.file_exists(path):
		translations = load(path)
	#get_tree().node_added.connect(_on_node_added)


func translate(node: Node) -> void:
	if !translations or !node:
		return
		
	translate_node(node)
	for child in node.get_children():
		translate(child)

func tr(original_text: StringName, context: StringName = &"") -> String:
	return original_text # TODO
	if original_text == null:
		return ""
	var translated_text = translations.get_message(original_text)
	if !translated_text:
		translated_text = original_text
	
	return translated_text


func translate_node(node: Node) -> void:
	if !node:
		return
		
	if Engine.is_editor_hint():
		var properties = ["text", "tooltip_text", "itemlist_tooltip", "names"]
		for p in properties:
			if p in node:
				if not node.has_meta("ORIGINAL_TEXT_" + p):
					node.set_meta("ORIGINAL_TEXT_" + p, node.get(p))
				var default_text = node.get_meta("ORIGINAL_TEXT_" + p)
				if p != "names":
					var original_text = default_text
					var translated_text = translations.get_message(original_text)
					if !translated_text:
						translated_text = original_text
					node.set(p, translated_text)
				else:
					var property = default_text
					if property is PackedStringArray:
						for i in property.size():
							var original_text = property[i]
							var translated_text = translations.get_message(original_text)
							if !translated_text:
								translated_text = original_text
							node.set(p, translated_text)
