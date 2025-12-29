@tool
class_name CustomColorDialog
extends Window

var destroy_on_hide: bool = true
var original_color: Color

static var instance: CustomColorDialog = null
static var is_opened: bool = false


signal color_selected(color: Color)
signal preview_color(color: Color)


func _ready() -> void:
	instance = self
	visibility_changed.connect(_on_visibility_changed)
	close_requested.connect(_on_cancel_button_pressed)


func _on_visibility_changed() -> void:
	is_opened = visible


func set_color(color: Color) -> void:
	%ColorPicker.set_pick_color(color)
	original_color = color


func _on_ok_button_pressed() -> void:
	color_selected.emit(%ColorPicker.get_pick_color())
	destroy()


func _on_cancel_button_pressed() -> void:
	color_selected.emit(original_color)
	destroy()


func destroy() -> void:
	if destroy_on_hide:
		queue_free()
	else:
		hide()


func _on_color_picker_color_changed(color: Color) -> void:
	preview_color.emit(color)
