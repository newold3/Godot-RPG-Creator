@tool
extends Button


const TBTPlugin := preload("res://addons/tile_bit_tools/controls/tbt_plugin_control/tbt_plugin_control.gd")

## property name from icons.gd
@export var icon_name : String

## string of icon name from editor theme
@export var editor_name : String

var tbt : TBTPlugin

func _tbt_ready() -> void:
	if icon_name != "":
		icon = tbt.icons.get_icon_by_name(icon_name)
	elif editor_name != "":
		icon = tbt.icons.get_icon_by_editor_name(editor_name)
