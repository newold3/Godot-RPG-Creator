@tool
extends Button

const MINI_PADLOCK_OPEN = preload("res://addons/CustomControls/Images/mini_padlock_open.png")
const MINI_PADLOCK = preload("res://addons/CustomControls/Images/mini_padlock.png")


func _ready() -> void:
	toggled.connect(_on_toggled)



func _on_toggled(value: bool) -> void:
	if value:
		%LockIcon.texture = MINI_PADLOCK
	else:
		%LockIcon.texture = MINI_PADLOCK_OPEN
	
	%CheckBox.set_pressed(value)
	
