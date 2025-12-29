@tool
class_name RPGGameOptions
extends Resource

func get_class(): return "RPGGameOptions"


@export var fullscreen: bool = false
@export var vsync: bool = true
@export var max_fps: int = 60
@export var brightness: float = 1.0
@export var text_speed: float = 1.0
@export var sound_master: float = 0.0
@export var sound_music: float = 0.0
@export var sound_fx: float = 0.0
@export var sound_ambient: float = 0.0
@export var language: String = "en"
