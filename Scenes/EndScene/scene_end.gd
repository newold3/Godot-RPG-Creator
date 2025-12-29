class_name SCENE_END
extends Control


func _ready() -> void:
	GameManager.hand_cursor.visible = false
	var t = create_tween()
	
	t.tween_property(%TopBlack, "color", Color.BLACK, 1.5)
	t.tween_callback(get_tree().quit)
