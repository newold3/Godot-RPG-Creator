@tool
extends Control

@export var title: String : set = set_title

@onready var title_container: PanelContainer = %TitleContainer
@onready var scene_title: Label = %SceneTitle
@onready var gear_gear: Control = %GearGear

var main_tween: Tween



func _ready() -> void:
	GameManager.set_text_config(self)
	set_title(title)


func set_title(value: String):
	title = value
	if scene_title:
		scene_title.text = value


func start() -> void:
	if main_tween:
		main_tween.kill()
	
	title_container.position.x = 0
	title_container.size.x = 0
	gear_gear.rotation = 0.0
	
	main_tween = create_tween()
	main_tween.set_parallel(true)
	main_tween.tween_property(title_container, "position:x", 81, 0.74).set_trans(Tween.TRANS_EXPO)
	main_tween.tween_property(title_container, "size:x", 317, 0.6).set_trans(Tween.TRANS_SINE)
	main_tween.tween_property(gear_gear, "rotation", PI/2, 0.74).set_trans(Tween.TRANS_BACK)


func end() -> void:
	if main_tween:
		main_tween.kill()
	
	main_tween = create_tween()
	main_tween.set_parallel(true)
	main_tween.tween_property(title_container, "position:x", 0, 0.3).set_trans(Tween.TRANS_SINE)
	main_tween.tween_property(gear_gear, "rotation", 0.0, 0.2).set_trans(Tween.TRANS_BACK)
