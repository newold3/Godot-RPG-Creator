@tool
extends TextureButton


@export var text_color_on_mouse_enter: Color = Color.ORANGE
@export var text_color_on_mouse_exit: Color = Color.WHITE

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)


func _on_mouse_entered() -> void:
	%Label1.set("theme_override_colors/font_color", text_color_on_mouse_enter)
	%Label2.set("theme_override_colors/font_color", text_color_on_mouse_enter)


func _on_mouse_exited() -> void:
	%Label1.set("theme_override_colors/font_color", text_color_on_mouse_exit)
	%Label2.set("theme_override_colors/font_color", text_color_on_mouse_exit)
