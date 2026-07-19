@tool
extends InstantText

var tween: Tween


func start() -> void:
	if tween: tween.kill()
	
	tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)
	
	await tween.finished
	
	super()


func end() -> void:
	if tween: tween.kill()
	
	tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)
	
	await tween.finished
	
	super()
