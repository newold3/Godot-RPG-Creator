@tool
extends Window


@onready var formatter: Node = %Formatter
@onready var canvas: Control = %Canvas

## Dictionary containing the color palette for command formatting
@export var color_theme: Dictionary = {
	"color1": Color("#ffffff"),
	"color4": Color("#00ffff"),
	"color13": Color("#ffff00"),
	"disable_text": Color("#888888")
}


func _ready() -> void:
	close_requested.connect(_on_close_requested)


## Updates commands and schedules a deferred resize to ensure correct dimensions
func show_preview(commands: Array, pos: Vector2i, config: Dictionary = {}) -> void:
	if config.has("color_theme") and not config.color_theme.is_empty():
		color_theme = config.color_theme
	
	formatter.set_config({"color_theme": color_theme})
	canvas.setup_commands(commands, formatter)
	
	if not visible:
		position = pos
		size = Vector2i(300, 150)
	
	visible = true
	call_deferred("_adjust_window_size")


## Calculates and applies the window size based on the canvas minimum size
func _adjust_window_size() -> void:
	if not is_instance_valid(canvas): return
	
	var content_size = canvas.custom_minimum_size
	
	var final_w = clamp(content_size.x + 40, 300, 640)
	var final_h = clamp(content_size.y + 40, 150, 480)
	
	size = Vector2i(final_w, final_h)


func _on_close_requested() -> void:
	visible = false
