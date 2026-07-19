@tool
extends Window


var current_text: String
var current_config: Dictionary

var old_text: String
var old_config: String

@onready var instant_text_scene: NinePatchRect = %InstantTextScene
@onready var scene_container: Control = %SceneContainer



func _ready() -> void:
	close_requested.connect(queue_free)


func set_data(text: String, config: Dictionary) -> void:
	if current_text == text and str(current_config) == old_config:
		return
	old_text = text
	old_config = str(config)
	current_text = text
	current_config = config
	start()


func _on_ok_button_pressed() -> void:
	queue_free()


func _on_cancel_button_pressed() -> void:
	queue_free()


func start() -> void:
	var scene_path = current_config.get("instant_scene", "res://Scenes/DialogTemplates/instant_text_scene1.tscn")
	if !scene_path:
		scene_path = "res://Scenes/DialogTemplates/instant_text_scene1.tscn"
	if ResourceLoader.exists(scene_path):
		var change_scene = false
		if is_instance_valid(instant_text_scene):
			if scene_path != str(instant_text_scene.get_scene_file_path()):
				change_scene = true
		else:
			change_scene = true
		if change_scene:
			var node = scene_container
			for child in node.get_children():
				node.remove_child(child)
				child.queue_free()
			var scene = load(scene_path).instantiate()
			node.add_child(scene)
			instant_text_scene = scene
		else:
			instant_text_scene.reset()
		
	var node = instant_text_scene
	node.set_config(current_config)
	node.set_text(current_text)
	node.start.call_deferred()


func _on_repeat_button_pressed() -> void:
	start()
