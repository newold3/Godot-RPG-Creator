@tool
extends Node

## ⚠️ Code Format is a very long script, Godot might load it as non-tool
## script if loaded alone without this wrapper script

@export var parser: RichTextLabel


var code_format: RPGEventCommandFormat


func _load_formats() -> void:
	var sc = load("res://addons/CustomControls/code_format.gd")
	code_format = sc.new()

func set_config(config: Dictionary) -> void:
	if not code_format: _load_formats()
	if code_format:
		code_format.set_config(config)


func get_formatted_code(command: RPGEventCommand, font: Font, font_size: int, align: HorizontalAlignment, v_separation: int, index: int) -> Dictionary:
	if not code_format: _load_formats()
	if code_format:
		return code_format.get_formatted_code(command, font, font_size, align, v_separation, index)
		
	return {}
