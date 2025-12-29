@tool
extends VideoStreamPlayer

func _ready() -> void:
	loop = true
	play()


func _process(_delta: float) -> void:
	if not is_playing():
		play()
