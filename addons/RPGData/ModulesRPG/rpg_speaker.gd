@tool
class_name RPGSpeaker
extends  Resource


func get_class(): return "RPGSpeaker"

@export var name: Dictionary = {}
@export var face: Dictionary = {}
@export var character: Dictionary = {}
@export var character_position: int = 0
@export var text_fx: RPGSound = RPGSound.new("res://Assets/Sounds/typewrite2.ogg", 0.0, 0.7, 1.1)
@export var text_color: Color = Color.WHITE
@export var font_name: String = ""
@export var font_size: int = 22
@export var text_bold: bool = false
@export var text_italic: bool = false
@export var wait_on_finish: float = 0.15
## Additional notes about this common event.
@export var notes: String = ""


func clear() -> void:
	for obj in [name, face, character]: obj.clear()
	character_position = 0
	font_size = 22
	wait_on_finish = 0.15
	text_fx = RPGSound.new("res://Assets/Sounds/typewrite2.ogg", 0.0, 0.7, 1.1)
	text_color = Color.WHITE
	font_name = ""
	notes = ""
	text_bold = false
	text_italic = false


func clone(value: bool = true) -> RPGSpeaker:
	var new_speaker = duplicate(value)
	new_speaker.text_fx = new_speaker.text_fx.clone(true)
	if "path" in face and face.path is RPGIcon:
		face.path = face.path.clone(value)
	return new_speaker
