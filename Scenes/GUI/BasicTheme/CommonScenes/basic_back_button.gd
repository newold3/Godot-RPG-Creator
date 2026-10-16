extends Button

signal selected()


func set_disabled(value: bool) -> void:
	disabled = value
	mouse_filter = Control.MOUSE_FILTER_IGNORE if value else Control.MOUSE_FILTER_STOP


func _ready() -> void:
	focus_entered.connect(_on_focus_entered)


func _on_focus_entered() -> void:
	selected.emit()
