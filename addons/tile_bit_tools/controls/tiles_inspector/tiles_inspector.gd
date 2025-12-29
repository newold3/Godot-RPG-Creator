@tool
extends Control

const TBTPlugin := preload("res://addons/tile_bit_tools/controls/tbt_plugin_control/tbt_plugin_control.gd")

var tbt : TBTPlugin

var ready_complete := false

@onready var save_button: Button = %SaveButton

func _ready() -> void:
	ready_complete = true


func _tbt_ready() -> void:
	if tbt.context.bit_data.has_terrain_set():
		save_button.disabled = false
		save_button.tooltip_text = ""
	else:
		save_button.disabled = true
		save_button.tooltip_text = "No terrain data to save in selected tiles"



func _on_save_button_pressed() -> void:
	tbt.save_template_requested.emit()


















