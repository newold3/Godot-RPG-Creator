extends Control

signal end()
signal started()

var _is_closing: bool = false


func start() -> void:
	visible = true
	modulate.a = 0.0
	var t = create_tween()
	t.tween_property(self, "modulate:a", 1.0, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	if has_node("%MainMenuScene") and %MainMenuScene.has_method("restart"):
		%MainMenuScene.restart()
		
	started.emit()


func destroy() -> void:
	if _is_closing: return
	_is_closing = true
	var t = create_tween()
	t.tween_property(self, "modulate:a", 0.0, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_callback(func():
		_is_closing = false
		queue_free()
	)
