@tool
class_name RPGSavedGamePreview
extends Resource

@export var current_party_ids: PackedInt32Array = []
@export var current_chapter_name: String = ""
@export var current_gold: int = 0
@export var play_time: float = 0.0


func _to_string() -> String:
	return "<RPGSavedGamePreview current_party=%s, chapter_name=%s, gold=%s, play_time=%s>" % [
		current_party_ids,
		current_chapter_name,
		current_gold,
		play_time
	]
