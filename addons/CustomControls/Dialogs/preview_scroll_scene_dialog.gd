@tool
extends Window


var current_text: String
var current_config: Dictionary

var old_text: String
var old_config: String

@onready var scroll_scene: NinePatchRect = %ScrollScene1


func _ready() -> void:
	close_requested.connect(queue_free)


func set_data(text: String, config: Dictionary) -> void:
	if current_text == old_text and str(current_config) == old_config:
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
	var scene_path = current_config.get("scroll_scene", "res://Scenes/DialogTemplates/scroll_scene_1.tscn")
	if !scene_path:
		scene_path = "res://Scenes/DialogTemplates/scroll_scene_1.tscn"
	if ResourceLoader.exists(scene_path):
		var change_scene = false
		if is_instance_valid(scroll_scene):
			if scene_path != str(scroll_scene.get_scene_file_path()):
				change_scene = true
		else:
			change_scene = true
		if change_scene:
			var node = %SceneContainer
			for child in node.get_children():
				node.remove_child(child)
				node.queue_free()
			var scene = load(scene_path).instantiate()
			node.add_child(scene)
			scroll_scene = scene
		else:
			scroll_scene.reset()
		
	var node = scroll_scene
	node.set_config(current_config)
	node.set_text(current_text)
	node.start()


func _on_repeat_button_pressed() -> void:
	start()
